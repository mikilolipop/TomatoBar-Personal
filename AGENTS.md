# AGENTS.md

本文件是**稳定层**：项目架构、约定、命令与红线。给所有 AI 助手（Codex / Claude Code / 其他）阅读。

易变状态（当前进度、下一步、已否决方案）见 [`docs/HANDOFF.md`](docs/HANDOFF.md)。
已知问题清单见 [`docs/BACKLOG.md`](docs/BACKLOG.md)。
匿名用户反馈与产品决策见 [`docs/USER_FEEDBACK.md`](docs/USER_FEEDBACK.md)。

---

## 项目定位

macOS 菜单栏番茄钟，是 [ivoronin/TomatoBar](https://github.com/ivoronin/TomatoBar)（MIT）的**个人定制 fork**。

| 项 | 值 |
|---|---|
| 产品名 | TomatoBar Personal |
| Bundle ID | `com.dilyar.TomatoBarPersonal`（与上游共存，不迁移原版数据） |
| 当前版本 | 3.9.0（对外称 V1.3） |
| 默认分支 | `feature/personal-focus` |
| `main` 分支 | 上游基线 `90a77d6`，仅用于对比 diff，**不要在上面开发** |
| `origin` | `mikilolipop/TomatoBar-Personal`（**public**，2026-09-29 GitHub API 实测确认） |
| `upstream` | `ivoronin/TomatoBar` |

与上游的核心差异：**完全无声**（删除 Player.swift 与三个 wav）、事件记录 + 标签、暂停/继续、
到时**无声置顶提醒窗**（不依赖系统通知权限）、持久化历史、原生主窗口日/周/月复盘。

界面文案为**硬编码中文字面量**。`*.lproj/Localizable.strings` 是上游遗留死文件（见 BACKLOG P4）。

---

## 架构

### 领域层（可脱离 UI 编译，测试只覆盖这一层）

| 文件 | 职责 |
|---|---|
| `TomatoBar/State.swift` | `FocusPhase` 五态机、`FocusRecord`、`FocusSegment`、`FocusState`。纯值类型 |
| `TomatoBar/Log.swift` | `FocusStore`：sessions.json 读写、原子写入、旧格式迁移备份 |
| `TomatoBar/Analytics.swift` | `FocusPeriod`、`FocusSummary`、`CategoryTotal`、`FocusDay`、`focusDuration()` |

### UI / 桥接层（不在测试编译范围内）

| 文件 | 职责 |
|---|---|
| `TomatoBar/Timer.swift` | `TBTimer`（ObservableObject 桥接）、`FocusHistory`、`WindowActivity`。依赖 SwiftUI + KeyboardShortcuts；默认领域测试不编译，另有 `scripts/test-bridge.sh` 链接真实依赖检查 |
| `TomatoBar/LaunchContext.swift` | AppKit 启动事件分类；两个启动回调采样，不修改计时或登录注册 |
| `TomatoBar/App.swift` | `TBStatusItem`（NSApplicationDelegate）：菜单栏、popover、主窗口、睡眠暂停、退出保护、URL scheme |
| `TomatoBar/View.swift` | 菜单栏 popover（350pt）、`RecordEditor` |
| `TomatoBar/MainWindow.swift` | 主窗口：概览/历史页、`TimerCard`、`ExpandedTimer`、`MainSettings` |
| `TomatoBar/FocusCharts.swift` | `Garden` 配色、`GardenArt` 像素动画、`FocusChart`（日色块流/周堆叠柱/月热力日历） |
| `TomatoBar/Notifications.swift` | `TBReminder`：无声浮动提醒面板 |

**已知架构边界**：`scripts/test.sh` 只编译领域层，不覆盖 `TBTimer` 和 SwiftUI 交互。
构建后可运行 `scripts/test-bridge.sh`，它编译真实桥接/UI 源文件与 SwiftPM 依赖，在 QA13 临时子目录检查存储事务，
但不启动界面、不覆盖 alert/布局。`scripts/test-launch-context.sh` 只验证合成事件，不代替真人登录。

---

## 必须遵守的不变量

改计时相关代码前请先理解这些，它们都有对应测试：

1. **所有 `FocusState` 的变更方法都接受显式 `now: Date` 参数**。`State.swift` 内**不得调用 `Date()`** —— 这是暂停、完成、恢复可测试的前提。
2. **计时基于 segment**。暂停 = 关闭当前 segment，所以**暂停时间、休息时间、离线时间永不计入专注**。
3. **`closeSegment` 以 `deadline` 封顶**（`min(now, deadline ?? now)`），防止 tick 延迟导致多算。
4. **`recover()` 恢复为「暂停在 checkpoint」**，不是继续计时。运行中每 5 秒存一次 checkpoint，异常中断最多少记约 5 秒。
5. **第一个标签 = 统计分类**（`FocusRecord.category` = `tags.first ?? "未分类"`）。每段时长只计入一个分类，多标签不会重复计数。
6. **周从周一开始**（`firstWeekday = 2`, `minimumDaysInFirstWeek = 4`）。月份和夏令时使用系统日历边界。
7. **存储安全**：原子写入；文件损坏时**保留原文件**并阻止新计时（`loadFailed`）；编辑**先落盘成功再更新内存**。

---

## 命令

```sh
scripts/test.sh     # 领域检查（当前 214 项，**以末行 PASS 数为准**，历轮修复一直在加）
scripts/dev-run.sh  # 一键开发闭环：优雅退出旧实例 → 测试闸门 → build.sh → 从 /tmp 启动新版。
                    # **改完代码想看效果统一跑它**（人和所有 AI 都是）。不要自己拼
                    # killall + xcodebuild：进程名带空格（"TomatoBar Personal"）杀不干净，
                    # CODE_SIGNING_ALLOWED=NO 会打死沙盒，SIGTERM 强杀会绕过
                    # 「专注记录尚未保存」退出闸门。有未落盘记录时它会中止并保留现场。
                    # 它只从 /tmp 起开发实例，/Applications 正式版不动；SKIP_TESTS=1 跳闸门。
scripts/test-launch-context.sh # 8 项 AppKit 合成启动事件检查，不访问用户数据
scripts/test-bridge.sh # 先 build.sh，再运行真实 TBTimer 检查（当前 40 项）；只使用 QA13 新建临时子目录
scripts/build.sh    # Release 构建到 /tmp/TomatoBar-personal-build。Widget 轮起用项目自带
                    # Automatic 签名（免费 Personal Team，profile 由 -allowProvisioningUpdates
                    # 自动续期），产物过 codesign --verify --deep --strict。CI 上无账号，
                    # 走「不签名构建 + ad-hoc 重签」编译门路线，产物不可当运行版。
scripts/seed-qa.py  # 只写入隔离的 QA12 沙盒，运行前先退出该 App
scripts/compare-design.py
scripts/deploy-site.sh # 把 site/ 发布到 gh-pages 分支（GitHub Pages）；幂等，用临时 worktree 不碰工作区
```

`scripts/test.sh` **不需要 Xcode 项目、不需要签名、几秒跑完**。没有 XCTest target，
`Tests/main.swift` 是顶层脚本，用自定义 `check()` 断言，失败即 `fatalError`。

---

## 约定

- **测试数据用内联构造的 Swift 记录**（见 `Tests/main.swift` 里的 `statsRecord()` / `day()` / `legacyRecord()` 辅助函数），**不加载 JSON fixture**。理由：数值与断言并排可见，无文件 IO、无解析失败、无路径依赖。
- **不要为一次性转换写脚本进仓库**。先例：原版 TomatoBar 的 transition log 只有 965 字节且输入已冻结（原版 App 已废弃），当时决定直接把真实数据内联进测试，而不是写导入脚本。
- `docs/**/*.png` 已被 gitignore（16MB 二进制，永不 diff）。QA 截图留在磁盘和 `TomatoBarBuildBackups/` 快照里。
- **不要修改历史验收记录**：`design-qa.md`、`docs/V1.x更新说明.md`、`docs/个人版使用与验证.md` 都是带日期的时点证据。数字过时也不改，新版本另写一份。
- 提交信息用英文正文即可，中文术语（如「未命名专注」「提前结束」）保持原样。

---

## 红线

- 🚫 **`scripts/test.sh` 不绿不得提交。**
- 🚫 **绝不执行 `git checkout .` / `git clean -fd` / `git reset --hard`**，除非用户明确要求。
  这三个版本的全部源码曾长期只存在于工作区（HEAD 停在上游 `90a77d6`），一条命令就能归零且不可恢复。
- 🚫 **会话结束不得留下未提交的工作。** 提交并推送。
- 🚫 **不要向 `upstream` 推送任何东西。** `origin` 才是本项目的远程。
- 🚫 **仓库现为 public**（2026-09-29 用户决定并实测确认；曾为私有）。**不要把真实个人使用数据
  提交进仓库**（文档、测试、截图里的分类/事件名注意脱敏）；可见性再变更必须用户明确决定。
- 🚫 **公开仓库中的外部用户反馈必须匿名化。** 只保留产品需求、可复现行为和决策；不要提交反馈者姓名、账号、联系方式、个人习惯、健康/生活信息或其他可识别背景。原话如含这些信息，先改写成最小必要的匿名描述再进入 `docs/USER_FEEDBACK.md`。
- 🚫 不要动 `~/Library/Containers/com.github.ivoronin.TomatoBar`（原版数据，用户明确保留作为后续测试数据源）。

---

## UI 自动化与 QA 隔离

改动 UI 层时，`scripts/test.sh` **完全覆盖不到**（它只编译领域层 3 个文件）。
验收方式是构建一个隔离 QA 变体：

```sh
xcodebuild -project TomatoBar.xcodeproj -scheme TomatoBar -configuration Release \
  -derivedDataPath /tmp/TomatoBar-QA13-build \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  PRODUCT_BUNDLE_IDENTIFIER=com.dilyar.TomatoBarPersonal.QA13 ONLY_ACTIVE_ARCH=NO build
```

只覆盖 `PRODUCT_BUNDLE_IDENTIFIER` 即可隔离容器。**不要覆盖 `PRODUCT_NAME`** ——
会与 LaunchAtLogin 的登录辅助 bundle 冲突（`Multiple commands produce …`）。

数据写在
`~/Library/Containers/com.dilyar.TomatoBarPersonal.QA13/Data/Library/Application Support/TomatoBarPersonal/sessions.json`
（`scripts/seed-qa.py` 是同类做法，只是它写的是 QA12）。

### 🚨 同名进程陷阱（会静默操作到用户真实数据）

因为不能覆盖 `PRODUCT_NAME`，QA 变体与正式版的**进程名相同**（都是 `TomatoBar Personal`）。
此时 System Events 的定位不可靠，实测：

- `first process whose bundle identifier is "…QA13"` → 返回**正式版**的 pid
- `first process whose unix id is <QA13 的 pid>` → 读回的 `bundle identifier` 是**正式版的**

**所以做 UI 自动化前必须**：

1. 确认只剩一个同名进程，或先退出正式版
2. **操作真实用户数据前先快照** `sessions.json`，事后逐条比对
3. 每次交互前读回界面文本核验身份（QA 数据与真实数据必须能一眼区分）；
   看到意料之外的数值立刻停手
4. 交付时明确区分「已实机验证」与「未验证」，**不得把领域测试通过说成 UI 验收完成**

### 本机环境限制

- **无屏幕录制权限** → `screencapture` 失败，**视觉验收做不了**，只能靠辅助功能树 + 落盘数据比对
- 有辅助功能权限 → System Events 可枚举与点击，但 NSPopover（`.transient`）打不开：
  状态栏项只支持 `AXPress`，执行后 popover 不出现，坐标点击同样无效
- SwiftUI 的 `LazyVStack` 只实体化可见行，`count of menu buttons` 之类按类计数会随渲染时机波动；
  遍历 `every UI element` 判断 `class of e` 更可靠
- 短中文字面量在 Swift 里可能是 small string，**不进 cstring 区**，`strings` 搜不到；
  用 `grep -a` 搜 UTF-8 字节 + `nm` 找符号，并**先用一个已知存在的旧值校准方法**

---

## 多 AI 协作

本项目由多个 AI 助手接力开发，**彼此之间没有直接通信通道**。唯一的媒介是仓库产物：
本文件、`docs/HANDOFF.md`、`docs/BACKLOG.md`、提交信息、测试。

**会话开始**：
```sh
git status                 # 工作区脏 → 停下来问用户，不要接着改
git log --oneline -5       # 上一个 AI 做了什么
./scripts/test.sh          # 确认基线是绿的
```
然后读 `AGENTS.md`（本文件）+ `docs/HANDOFF.md`。

**会话结束**：
```sh
./scripts/test.sh          # 必须全绿
# 更新 docs/HANDOFF.md：当前状态 / 进行中 / 下一步 / 刚做完 / 已否决方案
git add -A && git commit && git push
```

**「已否决的方案」必须写进 HANDOFF.md** —— 这是防止另一个 AI 重走已排除路径的关键。

分工原则：额度有限的一方用于设计决策、第二意见与交叉评审；本地额度充裕的一方用于
大量实现、探索与重构。**交叉评审回报最高**：一方提交后，把 commit hash 或 diff 交给另一方审。

**不要并行改同一个工作目录** —— 两个 AI 操作的是同一份文件。需要并行时用分支前缀隔离
（`codex/*`、`claude/*`），各自 push 后再合。
