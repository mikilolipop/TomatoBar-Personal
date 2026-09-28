# HANDOFF.md

**易变层** —— 每次会话结束时更新。稳定约定见 [`../AGENTS.md`](../AGENTS.md)，问题清单见 [`BACKLOG.md`](BACKLOG.md)。

最后更新：2026-09-28，by Claude Code（Opus 5）· 实施 P9 + P7

---

## 当前状态

| 项 | 值 |
|---|---|
| ⚠️ **已安装版本** | **3.8.0（V1.2），不含 P9 修复**。P9/P7 只进了 git 和 CI，**尚未重装到 `/Applications`**。产物在 `/tmp/TomatoBar-personal-build/Build/Products/Release/`（注意 `/tmp` 会被系统清理）。建议与下一轮修复合并重装一次，避免反复重装 |
| HEAD | `abf55df`（P7 换 CI）← `e69be32`（P9 重试按钮）← `bd7c214`（复核 Codex 评审）← `d01bc20`（Codex 评审）← `1f43359`（协作结构）← `8fb1e74`（首次提交 V1.0–V1.2）← `90a77d6`（上游基线） |
| 工作区 | 干净，与 `origin/feature/personal-focus` 一致 |
| 测试 | `scripts/test.sh` → **61 项全绿**（P9 新增 6 项） |
| **CI** | ✅ **已生效**：GitHub Actions `tests` workflow，首次运行 [36431326540](https://github.com/mikilolipop/TomatoBar-Personal/actions/runs/36431326540) **success**，46 秒，61 项全过 + 通用二进制构建 + 产物 bundle id 断言 |
| 远程 | `origin` = `mikilolipop/TomatoBar-Personal`（私有，默认分支 `feature/personal-focus`）；`upstream` = `ivoronin/TomatoBar` |
| 用户真实数据 | **1 条**记录、phase=idle；本次会话未触碰 |
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

**无进行中的代码改动。** 本轮用户只授权了 **P9 与 P7**，两项均已实施、验证、提交、推送，CI 首次运行 success。

其余条目状态：

| 条目 | 状态 |
|---|---|
| P1 + P2 + P8 | **未授权**。三者必须一起做（Codex 指出方案 B 原形态漏了 P8 会仍抢焦点）。需要用户亲自登出登入验收，两个 AI 都验不了 |
| P3 | **未授权**。完整修法需持久化 RestKind + 旧 JSON 兼容解码 + 补测，比原估的 3 行大 |
| P4 / P6 | 建议**跳过**。Codex 双双降级；P4 有真实构建风险（variant group + Resources 引用链），收益接近零 |
| P5 | **暂不修**。原 13 次 / 416 趟估算已撤回，按 UI 实测排期 |
| P7 遗留 | main 首次推送为何零运行**仍未证实**，不得写成已查明。现已无关紧要 |

---

## 下一步

1. **决定是否重装**。当前 `/Applications` 里是**不含 P9 修复**的 3.8.0。P9 只在
   sessions.json 损坏这种罕见路径上才可见，**无紧急性**；建议与下一轮修复合并重装一次。
   若要单独重装，注意产物在 `/tmp/TomatoBar-personal-build/`，`/tmp` 会被系统清理，
   重装前先确认产物还在，否则重跑 `scripts/build.sh`
2. **P1 + P2 + P8 是一个不可拆的整体**，实施前应先写 `docs/V1.3验收清单.md`，
   因为验收必须由用户真人执行：开「登录时启动」→ 登出登入 → 确认不弹窗不抢焦点但菜单栏有「请确认」
   → 手动启动确认弹窗正常 → 关窗确认 Dock 图标消失 → 从 Dock 重开
   → **开设置 sheet 时确认图标不消失**（Codex 特别警告：不要在 `windowDidResignKey` 里降级）
   → 最小化确认图标不消失
   登录来源判定用 `NSAppleEventManager.shared().currentAppleEvent` 读 `kAEOpenApplication` 的
   `keyAEPropData` 是否为 `keyAELaunchedAsLogInItem`，在启动事件处理期尽早保存。
   **`NSApp.launchedAsHidden` 不存在**，已实测编译报错
3. P3 若要做，先确认是否值得为一个菜单栏图标做领域改动；折中方案是只在 `TBTimer` 上存
   非持久化标志，代价是**重启后图标可能不准**，需用户接受该缺陷
4. V1.3 若发版，另写一份验收文档，**不要回头改 `design-qa.md` 里的「41 项检查」**

### V1.3 候选（尚未规划）

- 往 `scripts/seed-qa.py` 加几段**亚分钟记录**，用于视觉验证 `FocusCharts.tileWidth` 的
  `max(44, …)` 最小宽度分支。该分支在 UI 层，`scripts/test.sh` 编译不进去，**只能靠眼睛看**。
  注意：QA12 沙盒容器还在，但 **QA12 的 .app 本体已不存在**，需先造一个 QA12 bundle ID 的构建变体。

---

## 刚做完（2026-09-28，Claude Code 实施 P9 + P7）

**P9 — 重试按钮（`e69be32`）**

- `retrySave()` → `retryStorage()`：读失败时走新增的私有 `reload()` 重新读盘，写失败时重试保存；
  `storageRetryTitle` 相应显示「重新读取」/「重试保存」
- 选择**让按钮真正可用**而不是隐藏它。`loadFailed` 阻止 `persist()` 覆盖损坏文件的保护完全保留，`reload()` 只读不写
- 实施前先逐个核验写入口，确认 `loadFailed` 期间 `phase` 恒为 `.idle`、内存中无可丢失数据 ——
  这是 `reload()` 安全的全部前提，已写进代码注释
- 两个错误横幅加「打开记录文件夹」；顺带修 `openRecordsFolder()` 覆写既有 `storageError` 的问题
- 测试 55 → **61 项**；变异检验两个真实世界易犯错误均被抓到（详见 BACKLOG P9 小节）
- UI 层 `test.sh` 编译不到，另跑 `scripts/build.sh` 干净构建，并在产物二进制中确认
  `重新读取`/`重试保存`/新错误文案/私有 `reload()` 符号均存在

**P7 — 换 CI（`abf55df`）**

- 整体替换 `.github/workflows/main.yml`，不是改过滤器
- 单 job 两步：领域测试（先跑，逻辑失败就不花构建分钟数）+ 构建 smoke check
  （采纳 Codex 意见：`test.sh` 只编译 9 个 Swift 文件中的 3 个，UI 层无其他覆盖）
- `branches-ignore: [main]`、`concurrency` 取消被取代的运行、`runs-on: macos-latest`
  避免钉死会被退役的 `macos-15`；零 secret 引用
- 提交前本地预演了三条产物断言命令，并做 YAML 解析校验
- **首次真实运行 success**：46 秒，四行 PASS 末尾 `PASS: 61 total checks`，
  42 行 SwiftCompile/Ld + `BUILD SUCCEEDED`，arm64 + x86_64 通用二进制，
  `grep -x 'com.dilyar.TomatoBarPersonal'` 实际匹配输出
- 46 秒含通用二进制构建快得可疑，**因此拉完整日志逐项核实，没有只看绿色勾**
- 顺带证实 Codex 对 P7 的诊断：同分支同仓库，只把 `branches: '*'` 换成
  `branches-ignore: [main]`，workflow 立刻登记并运行（workflows 0→1、runs 0→1）

**方法论教训（已写入 BACKLOG 记录规则）**

第一次做 `load()` 变异时只改了 decode 一行，结果**无效** —— `load()` 有四个抛错点，
其余仍在抛错，行为未变。**做变异检验必须先确认变异真的改变了可观察行为**，
否则「没抓到」是变异无效而不是测试有洞，会误导出「测试覆盖足够」的错误结论。

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
| 用 `strings` 验证 Swift 字面量是否进了产物二进制 | **方法无效**：连 `准备开始`、`正在专注` 这些从未改动的旧字符串也搜不到 —— Swift 把短字符串内联成 small string 存进代码段，不在 cstring 区。改用 `grep -a` 搜 UTF-8 字节 + `nm` 找符号。**用已知存在的旧值校准检测方法**，否则会把「方法失效」误判成「改动没进产物」 |
| 只改一处抛错点来变异检验 `load()` | **无效变异**。`FocusStore.load()` 有四个抛错点（`Data(contentsOf:)`、`JSONDecoder`、`JSONSerialization`、`copyItem`），只把 decode 改成 `try?` 时其余仍在抛错，可观察行为未变。变异检验的前提是变异**真的改变了行为** |
| 只看 CI 的绿色勾就认定步骤做了实事 | 本次 46 秒跑完含通用二进制的 Release 构建，快得可疑。必须拉完整日志核实（PASS 行数、SwiftCompile 行数、断言的实际输出）。步骤「成功」不等于步骤「有效」 |

---

## 更新本文件的规则

会话结束时改写这几节：**当前状态**（版本号、HEAD、测试数、数据量）、**进行中**、**下一步**、
**刚做完**（追加，写明日期和执行者）、**已否决的方案**（只增不删）。

「刚做完」按会话追加，过旧的可折叠为一行摘要指向 commit hash。**不要删「已否决的方案」** —— 
那是防止后续 AI 重走弯路的核心资产。
