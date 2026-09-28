# HANDOFF.md

**易变层** —— 每次会话结束时更新。稳定约定见 [`../AGENTS.md`](../AGENTS.md)，问题清单见 [`BACKLOG.md`](BACKLOG.md)。

最后更新：2026-09-28，by Claude Code（Opus 5）· 复核 Codex 评审 `d01bc20`

---

## 当前状态

| 项 | 值 |
|---|---|
| 已安装版本 | **3.8.0（V1.2）**，`/Applications/TomatoBar Personal.app`，此前 Claude 会话构建并安装；Codex 评审轮只读确认进程正在运行，未重装 |
| HEAD | `d01bc20`（Codex 交叉评审，仅文档）← `1f43359`（协作结构）← `8fb1e74`（首次提交 V1.0–V1.2）← `90a77d6`（上游基线） |
| 工作区 | 干净，与 `origin/feature/personal-focus` 一致 |
| 测试 | `scripts/test.sh` → **55 项全绿**（Claude 与 Codex 两轮各自独立复跑确认） |
| 远程 | `origin` = `mikilolipop/TomatoBar-Personal`（私有，默认分支 `feature/personal-focus`）；`upstream` = `ivoronin/TomatoBar` |
| 用户真实数据 | 此前 Claude 会话记录为 **1 条**、phase=idle；本轮未重新读取 sessions.json，未触碰数据 |
| git 身份 | 本仓库 `--local`：`mikilolipop <207336577+mikilolipop@users.noreply.github.com>`（全局仍未设置） |

### 原版 TomatoBar 已退役

`/Applications/TomatoBar.app`（v3.6.1，`com.github.ivoronin.TomatoBar`）本次会话中**移入废纸篓**
（重命名为 `TomatoBar (原版 v3.6.1).app`，可恢复）。菜单栏现在只有一个图标。

其容器数据 **`~/Library/Containers/com.github.ivoronin.TomatoBar` 按用户要求原样保留**，
作为下一版的测试数据源。归档副本（逐字节校验一致）：
`~/Library/Application Support/TomatoBarBuildBackups/original-container-20260928/`

> 注意：该容器受 macOS TCC 保护，普通终端读不到（`cat`/`cp` 均 Operation not permitted，
> 只有 `stat` 可用）。本会话已通过给 VS Code 授予「完全磁盘访问权限」解决。
> 若后续 AI 读不到，先检查宿主进程的 FDA 授权，并**优先使用上面的归档副本**（不受 TCC 限制）。

### 备份链（四重）

```
git 提交 8fb1e74 + 私有远程 origin
~/Library/Application Support/TomatoBarBuildBackups/
  ├── TomatoBar Personal-v1.0.app          旧版应用（二进制）
  ├── TomatoBar Personal-v1.1.app          旧版应用（二进制，本次会话新增）
  ├── original-container-20260928/         原版容器完整副本
  ├── sessions-v1.1-20260928-144502.json   V1.1 时期数据快照
  └── TomatoBar-source-snapshot-20260928-180504.tar.gz   19MB 源码快照（含被 gitignore 的 QA 截图）
```

tarball 是首次提交前的应急措施。有了 git + 远程后必要性下降，但**它是唯一含 16MB QA 截图的副本**，删除前需确认。

---

## 进行中

**P1–P7 交叉评审已完成，代码未改。** 结论见 BACKLOG 每条「评审意见（Codex）」。
新增 P8（登录恢复提醒仍抢焦点）和 P9（读取失败时重试按钮无效）。等待用户决定实施范围。
P7 的 main 首次零运行根因仍未证实，不得当成已解决；feature 分支过滤原因已确定。

---

## 下一步

1. 用户审阅评审后，再决定修哪些问题；本轮没有实施授权，不沿用旧「10–15 行即可」估计。
2. 方案 B 方向保留：P1 + P2 **须包含 P8**；继续 LSUIElement=YES，主窗口打开时 regular、真正关闭时 accessory。
   登录来源优先检查 Apple 启动事件标记；NSApplication.launchedAsHidden 在当前 SDK 不存在，
   LaunchAtLogin 5.0.2 也没有来源 API。真实 macOS 27 登录/手动启动/重开/恢复/提醒/设置 sheet 验收待做。
3. P3 不应靠休息分钟数相等判断类型；若要求设置变化与重启后稳定，需保存本次休息类型、兼容旧 JSON 并补测。
4. P4 / P6 降低优先级；本地化有 variant group + Resources 引用，不能只删文件。
   Icons 是源素材与工具，至少保留两张脚本依赖源图及来源说明，不能整体判死。
5. P7 后续宜替换上游发布 workflow 为正确匹配开发分支的无 secret 测试流程，构建 smoke check 可单独考虑。
   本轮确认 Actions enabled、workflows=0、runs=0、secrets=0；不能保证未来 main/tag 不触发旧发布操作。
6. P5 继续暂不修；原 13 次 / 416 趟估算撤回，500 条卡顿推断无依据；未来按 UI 实测主线程成本排期，
   保持 history/timer 观察分层，缓存不能仅用 records.count。
7. P9 可在后续错误恢复体验改动中处理，保留 loadFailed 阻止覆盖原文件的保护。

### V1.3 候选（尚未规划）

- 往 `scripts/seed-qa.py` 加几段**亚分钟记录**，用于视觉验证 `FocusCharts.tileWidth` 的
  `max(44, …)` 最小宽度分支。该分支在 UI 层，`scripts/test.sh` 编译不进去，**只能靠眼睛看**。
  注意：QA12 沙盒容器还在，但 **QA12 的 .app 本体已不存在**，需先造一个 QA12 bundle ID 的构建变体。

---

## 刚做完（2026-09-28，Claude Code 复核 Codex 评审）

对 `d01bc20` 的每条反驳做了**独立验证**，不直接采信。结论：**Codex 全部正确，Claude 原分析有三处事实错误。**

| 我原来的判断 | 实测结果 |
|---|---|
| P4「`lproj` 只出现 3 次 → 并非以独立 build file 形式引用，清理牵连面小」 | ❌ **错**。`project.pbxproj:16` 是 `PBXBuildFile /* Localizable.strings in Resources */`，`:169` 在 Resources build phase，`:217-226` 是 `PBXVariantGroup`，`:33/:36/:37` 是三种语言子引用。我的 `grep -c "lproj"` 只匹配到 path 属性行，**漏掉了全部按 UUID 的间接引用**。只删磁盘文件会破坏构建 |
| P5「每次构造 32 趟**全量**记录扫描，月视图 31 天 → 416 趟」 | ❌ **错两处**。(a) `Analytics.swift:54,59` 的 `Self.totals(records: self.records, …)` 用的是 `:50-53` **筛选并排序后**的 `self.records`（M 条），不是入参全库（N 条）。(b) 九月是 **30** 天不是 31 天。416 是错误假设下的算术，不是实测 |
| P6「保留 `convert.sh` + 一张源图即可」 | ❌ **错**。`Icons/convert.sh:3` `APPICON_SRC=TomatoBar.png`、`:5` `BARICON_SRC=tomato-filled.png` —— **两张源图各服务一个入口**，只留一张会破坏其中一个 |

另外确认 Codex 的三条新发现成立：

- **P1**：我提议的 `NSApp.launchedAsHidden` **在当前 SDK 不存在** —— `xcrun swift -e` 实测报
  `value of type 'NSApplication' has no member 'launchedAsHidden'`。我用问句提出，但若直接实施就是编译错误
- **P7**：我漏了 `.github/workflows/main.yml:53-54` 硬编码 `TomatoBar.app`，而
  `project.pbxproj:372,407` 的 `PRODUCT_NAME = "TomatoBar Personal"` —— **即使 secrets 齐全，Build 步骤也会因产物名不符而失败**
- **P9**：真实 bug，我读过 `retrySave()` 却没发现问题。`Timer.swift:108` 是
  `if !loadFailed { persist() }`，而读盘失败路径（`:37`）恰恰会设 `loadFailed = true` **并且**设 `storageError`；
  `View.swift:50` 与 `MainWindow.swift:221` 又在 `storageError != nil` 时无条件显示该按钮
  → **在读错误场景下按钮 100% 是死的**，用户即使在外部修好了文件也点不动，只能重启

**P8 是最重要的发现**：我提的方案 B 只包住 `App.swift:43` 的 `showMainWindow()`，但
`App.swift:44` 的 `reminder.show()` 同样会在登录时触发，而 `Notifications.swift:22` 里也有
`NSApp.activate(ignoringOtherApps: true)` → **按我原方案实施，登录时仍会抢焦点**。方案 B 不完整。

已确认 Codex 遵守协议：`git show --stat d01bc20` = 仅 `docs/BACKLOG.md` + `docs/HANDOFF.md`，
未碰任何代码；两轮 55 项测试均绿；远程一致。

---

## 刚做完（本次会话，2026-09-28）

1. **完整通读并理解项目**（约 1300 行 Swift + 全部文档）
2. **构建 + 安装 V1.2**：Release 构建通过，签名严格校验通过，v1.1 已备份
3. **移除原版** TomatoBar v3.6.1 → 废纸篓
4. **归档原版容器数据**（脱离 Caches 清理风险 + 脱离 TCC 限制）
5. **补测 `focusDuration()`**：41 → **55 项**。该函数被 6 处引用（含主窗口 46pt 累计总时长），此前**零测试**。`Analytics.swift` 本就在 test.sh 编译列表内，零基建成本
6. **真实数据回归**：把原版 log 里 4 段真实记录（含一段 1.5 秒误触）用原始 epoch 值内联进 `Tests/main.swift`，注明来源与归档路径
7. **变异检验**：注入 3 个错误（`% 60 == 0`→`== 1`、截断→四舍五入、`< 60`→`< 59`），**全部被对应断言抓到**，源码已还原并 diff 确认逐字节一致
8. **`.gitignore` 增加 `docs/**/*.png`**：26 张 16MB QA 截图不进 git，已验证 `tests.txt`、上游 `screenshot.png`、构建必需的 imageset PNG 均未被误伤
9. **首次提交整个个人版 fork**（`8fb1e74`，41 文件，+1684/−782）。此前 HEAD 停在上游 `90a77d6`，**V1.0–V1.2 三个版本的全部源码只存在于工作区**
10. **建私有远程并推送**：`mikilolipop/TomatoBar-Personal`，两个分支，默认分支设为 `feature/personal-focus`；`origin`/`upstream` 分离，消除误推上游风险
11. **修正提交作者**：原被 git 自动填成 `dilyar@dilyardeMacBook-Air.local`（主机名），已 `--amend --reset-author`
12. **建立多 AI 协作结构**：`AGENTS.md`（稳定层）、`CLAUDE.md`（指针）、`docs/HANDOFF.md`（本文件）、`docs/BACKLOG.md`

---

## 刚做完（2026-09-28，Codex 交叉评审）

- 独立核对 P1–P7 的源码、资源、Xcode 引用、传统登录项查询；基线和提交前均跑 55 项测试。
- 只读确认在用应用 activationPolicy=regular；没有关窗、登录切换或宣称端到端焦点验收。
- 核对锁定 LaunchAtLogin 5.0.2 与 SDK/Apple 官方 API，否定 launchedAsHidden 猜测。
- 领域层 `swiftc -O` 月汇总基准：1 / 500 / 5000 条约 0.020 / 1.231 / 5.854 ms（单次，非整页）；
  可复跑脚本写在 BACKLOG，另已执行文档里的脚本验证可用。
- 编码/解码/恢复探针复现 workFinished 仍 needsAttention，形成 P8；静态确认 P9。
- GitHub REST 实查：私有、fork=false、enabled=true，但 workflows/runs/secrets 均 0；
  两个远程分支 workflow blob 相同。事件列表不完整，main 首次未触发原因继续标未证实。
- 修改仅限 BACKLOG / HANDOFF；未改 Swift、测试、CI、设置、历史验收文档或用户数据。
- 不翻案任何原已否决方案；追加两条由评审排除的具体修法，避免接力时误用。

---

## 已否决的方案（**请勿重走**）

| 方案 | 否决理由 |
|---|---|
| 写 `scripts/import-original-log.py` 导入脚本 | 原版 App 已退役，那份 log 冻结在 965 字节 / 10 行，永不增长。为一次性动作留一个需长期维护的脚本是过度工程 —— 直接内联进测试即可 |
| 用 JSON fixture 喂测试 | 违背仓库既有约定（`Tests/main.swift` 全部内联构造 Swift 记录）。会引入文件 IO、解析失败、路径依赖三种新失败模式，换不到好处 |
| 把 V1.0/V1.1/V1.2 拆成三个提交 | 文件是累积修改的，只能靠猜分配 hunk，**那是编造历史**，比一个诚实的快照提交更糟。已在提交信息中说明是 squashed snapshot |
| 只用原版真实数据做测试输入 | 4 段最长 30 分钟，`focusDuration()` 的「小时」两个分支**真实数据永远够不着**。必须补合成值才能全覆盖 |
| 把 16MB QA 截图提交进 git | 永不 diff 的二进制，每次 clone 都要背。已 gitignore，磁盘和 tarball 里有副本 |
| 修改 `design-qa.md` 里的「41 项检查」 | 那是带日期的 V1.2 验收记录，改它等于篡改历史证据。数字过时也保留，V1.3 另写一份 |
| 现在就优化 P5（FocusSummary 重复构造） | 保留否决。此前记录为 1 条；Codex 已纠正原静态估算，后续按 UI profile 排期，不把旧估算称为精确成本 |
| 开启 GitHub Issues 做 backlog | 单人 + 两个 AI，`docs/BACKLOG.md` 随代码走、可 diff、离线可读、不需 API，更简单。仓库建时已设 `has_issues: false` |
| 用休息分钟数相等判断长休息 | Codex 评审：长短时长可以相同，每组数量可中途改变；不能稳定表示本次休息类型 |
| 只把原发布 workflow 的分支过滤从 `*` 改成 `**` | 会让开发分支开始跑缺 secret、带删 prerelease 操作的上游发布流程；应整体设计无 secret 验证流程 |
| 只删 `.lproj` 磁盘文件来清理本地化（P4） | Claude 原判断「无独立 build file 引用」是**错的**：`pbxproj:16/169/217-226/33/36/37` 有完整的 BuildFile + Resources phase + PBXVariantGroup 引用链。只删文件会破坏构建，必须同步处理 variant group / build file / 资源阶段 / knownRegions |
| 用 `grep -c "lproj"` 判断 Xcode 项目引用 | pbxproj 主要靠 **UUID 互引**，按字符串数出现次数会系统性漏掉间接引用。要查引用请用 `PBXBuildFile` / `PBXVariantGroup` / build phase 段落，或直接 `rg 'Localizable|PBXVariantGroup'` |
| 用静态 grep 出现次数推算 SwiftUI 计算属性的动态调用次数（P5） | 静态次数 ≠ 动态次数：分支未必都走、`LazyVStack` 行内访问随记录数增长、闭包内访问是延迟的。SwiftUI 没有自动 memoization 契约，但精确调用数只能靠 Instruments 或临时计数 |
| 用 `NSApp.launchedAsHidden` 判断登录自启 | **该 API 在当前 SDK 不存在**（实测编译错误）。应改用 `NSAppleEventManager.shared().currentAppleEvent` 读 `kAEOpenApplication` 的 `keyAEPropData` 是否为 `keyAELaunchedAsLogInItem`，并在启动事件处理期尽早保存 |
| 只包住 `showMainWindow()` 来实现「登录静默」（方案 B 原始形态） | 不完整。`App.swift:44` 的 `reminder.show()` 同样在登录时触发，`Notifications.swift:22` 也调 `activate(ignoringOtherApps: true)`。见 P8 |
| 删掉 `Icons/` 整个目录 | `convert.sh` 需要 **两张**源图（`TomatoBar.png` → AppIcon，`tomato-filled.png` → 四组菜单栏图标），`README.md` 记录图标来源。源素材与开发工具不因「Xcode 零引用」而失去价值 |

---

## 更新本文件的规则

会话结束时改写这几节：**当前状态**（版本号、HEAD、测试数、数据量）、**进行中**、**下一步**、
**刚做完**（追加，写明日期和执行者）、**已否决的方案**（只增不删）。

「刚做完」按会话追加，过旧的可折叠为一行摘要指向 commit hash。**不要删「已否决的方案」** —— 
那是防止后续 AI 重走弯路的核心资产。
