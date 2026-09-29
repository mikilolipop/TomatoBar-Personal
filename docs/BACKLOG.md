# BACKLOG.md

已知问题清单。每条附**证据（file:line）**、**独立核验方法**、**严重性**与**状态**。

> **给交叉评审者（Codex 或其他 AI）的说明**
>
> 本清单由 Claude Code（Opus 5）于 2026-09-28 通过静态阅读源码得出，**尚未做任何运行期复现**。
> 每条都给了可独立执行的核验命令，请**自行验证后再采信**，不要假设我的结论正确。
> 特别欢迎推翻我的严重性判断，以及指出我漏掉的问题。
>
> 用户已决定：**修任何一条之前，先要你的第二意见。**
>
> 约定与架构见 [`../AGENTS.md`](../AGENTS.md)；当前进度见 [`HANDOFF.md`](HANDOFF.md)。

> **2026-09-28 Codex 交叉评审**：基于 `1f43359`，只修改评审与交接文档。
> 以下原始分析保留以便对照；各条新增「评审意见（Codex）」是本次结论，冲突时以评审为准。
> P 编号是问题 ID，不应同时充当严重性等级。评审分别写明影响级别。
> 已独立执行原清单的源码/资源/项目引用检查、偏好与传统登录项查询、55 项测试；
> 另做领域层 Release 优化基准、恢复状态探针和 GitHub REST 只读核验。
> 本机报告 macOS 27.2（26B5091g）。未更改登录项、未重登、未操作在用应用窗口、未写用户数据。
> 因此不能把源码可达性或 API 契约称为 macOS 27 登录/焦点行为的端到端复现。

---

> **2026-09-29 Codex 第二轮评审**：基于 `ef50b45` 及交接提交 `58638f3`。
> 新增独立兼容性断言（96 → 138）、真实 TBTimer 桥接探针（12 项）、合成登录事件检查（8 项）。
> 未访问正式容器；桥接 IO 只在 QA13 的新建 review-UUID 子目录，退出时清理自己的目录。
> 样式/删除/编辑生产代码本轮保持原样；P12–P14 已复现并记录，尚未修复。
> P1/P2/P8 已有候选补丁，但真人登录、焦点、Dock 和 UI 布局验收仍未完成。
> 较早源码行号属于原提交；本轮新证据行号以此评审提交为准。

## 严重性定义

| 级别 | 含义 |
|---|---|
| 🔴 P1/P2 | 影响日常使用，或用户一开启某开关就会踩到 |
| 🟡 P3–P5 | 行为不符预期或规模化隐患，当前无感 |
| ⚪ P6/P7 | 卫生问题，不影响功能 |

---

## 🔴 P1 — 「登录时启动」会导致每次登录弹大窗口并抢焦点

**状态**：2026-09-29 候选补丁完成，真人登录待验。下方保留原分析；本轮未检查正式版登录开关。

### 证据

`TomatoBar/App.swift:25-45`，`applicationDidFinishLaunching` 中**无条件**调用：

```swift
showMainWindow()          // App.swift:43
```

而 `showMainWindow()`（`App.swift:67-90`）内部：

```swift
NSApp.setActivationPolicy(.regular)          // App.swift:86
mainWindow?.makeKeyAndOrderFront(nil)        // App.swift:87
NSApp.activate(ignoringOtherApps: true)      // App.swift:88 ← 抢焦点
```

窗口尺寸 `1120 × 800`（`App.swift:70`）。

设置面板中存在「登录时启动」开关：`MainWindow.swift:262` 与 `View.swift:165` 的 `LaunchAtLogin.Toggle`。

### 核验

```sh
grep -n "showMainWindow()" TomatoBar/App.swift
sed -n '67,90p' TomatoBar/App.swift
# 确认该开关当前未启用（应只有 __hasMigrated，没有实际登录项）：
plutil -p ~/Library/Containers/com.dilyar.TomatoBarPersonal/Data/Library/Preferences/com.dilyar.TomatoBarPersonal.plist | grep -i launch
osascript -e 'tell application "System Events" to get the name of every login item'
```

我实测结果：偏好里只有 `LaunchAtLogin__hasMigrated => true`；系统登录项只有 Notion、Google Drive。**即当前未启用。**

### 影响

手动打开应用时弹主窗口是 V1.2 的**设计意图**（`docs/V1.2更新说明.md`：「打开应用，或从菜单栏点击『打开主窗口』」），这部分不是 bug。

问题在于**同一个 `showMainWindow()` 被两种语义完全不同的场景复用**：用户主动打开 vs 登录时后台自启。后者应当静默驻留菜单栏，却会糊一个 1120×800 窗口并抢走焦点。

### 我的假设（请挑战）

用户一旦开启「登录时启动」就会踩到，且大概率会归因为「这 App 有毛病」而不是「我不该开这个开关」。
建议区分启动来源：登录自启时跳过 `showMainWindow()`。

> ❓**评审问题**：macOS 上区分「登录自启」与「用户主动打开」的可靠做法是什么？
> `NSApp.launchedAsHidden`？`applicationDidFinishLaunching` 的 notification userInfo？
> 还是 LaunchAtLogin 5.x 有专门的 API？我未做运行期验证，不确定哪种在 macOS 27 上可靠。

## 评审意见（Codex）

**结论：部分同意；保留高优先级行为问题，但「当前未启用」的证据不充分。**

无条件打开主窗口与激活调用已核对；手动打开弹窗是产品设计，不是 bug。方案 B 合理。
原核验命令确实输出只有迁移键、传统登录项 Notion / Google Drive，但这**不能排除现代登录项**：
项目锁定 LaunchAtLogin **5.0.2**，macOS 13+ 使用 `SMAppService.mainApp`；真实开关状态应从目标应用进程的
`LaunchAtLogin.isEnabled` / `SMAppService.mainApp.status` 或系统设置核验。独立命令行进程查询 mainApp 会查到自己，不能代替目标应用。

- 当前 SDK 实测 `xcrun swift -e 'import AppKit; print(NSApplication.shared.launchedAsHidden)'` 编译失败：没有该成员，不能使用这个猜测 API。
- 锁定依赖没有 `wasLaunchedAtLogin` 等来源 API；`isEnabled` 只表示注册状态，开启自启后仍可手动打开，不能用它跳过所有窗口。
- 推荐在启动事件处理期检查 `NSAppleEventManager.shared().currentAppleEvent`：确认 `kAEOpenApplication`，读取 `keyAEPropData` 的枚举值是否为 `keyAELaunchedAsLogInItem`。这是 Apple 定义的登录来源标记；尽早保存结果，不要在异步任务中事后查询当前事件。
- `NSApplicationLaunchIsDefaultLaunchKey` 还涵盖文件、服务、状态恢复等多种非默认启动，不能单独当作登录标志。隐藏启动也不等同于登录启动。
- 保留手动冷启动和 `applicationShouldHandleReopen` 的显示逻辑；登录时还须抑制启动恢复提醒的激活（新增 P8）。不要丢掉 needsAttention 状态，菜单栏仍可提示用户确认。

依据：[Apple 登录事件标记](https://developer.apple.com/documentation/coreservices/1556410-launch_apple_event_constants/keyaelaunchedasloginitem)、
[锁定版本源码](https://github.com/sindresorhus/LaunchAtLogin/blob/9a894d799269cb591037f9f9cb0961510d4dca81/Sources/LaunchAtLogin/LaunchAtLogin.swift)。
**限制**：以上是官方契约与源码核验，尚无本机真实登录事件样本。实施后须在 macOS 27 验证登录、手动冷启动、已有进程重开、会话恢复；不能声称平台可靠性已验收。

### 2026-09-29 补丁复核（Codex）

**同意实施，维持高优先级；状态改为候选补丁完成、真人验收待办。**
`LaunchContext.swift:9-18` 核对 core/open-app 事件和 lgit 标记；App.swift 的 willFinish / didFinish
同步采样，任一次确认登录即保留该结果。只抑制最初显示，不改用户主动 reopen。
合成 nil/普通启动/错误 class/reopen/service/login/后续 nil 共 8 项通过，但无法证明系统真实登录时一定在这两个回调提供标记。
见 `scripts/test-launch-context.sh`、`docs/V1.3验收清单.md`。LSUIElement 保留，未改任何登录项。

---

## 🔴 P2 — `LSUIElement = YES` 与 `setActivationPolicy(.regular)` 矛盾，Dock 图标永久残留

**状态**：2026-09-29 候选补丁完成，Dock 生命周期实机验收待办。下方保留原分析。

### 证据

```sh
grep -n "INFOPLIST_KEY_LSUIElement" TomatoBar.xcodeproj/project.pbxproj
# → 363: INFOPLIST_KEY_LSUIElement = YES;
# → 398: INFOPLIST_KEY_LSUIElement = YES;

grep -n "setActivationPolicy" TomatoBar/*.swift
# → TomatoBar/App.swift:86: NSApp.setActivationPolicy(.regular)

grep -rn "accessory" TomatoBar/*.swift
# → 无任何结果
```

### 影响

`LSUIElement = YES` 声明「我是 accessory 应用，不要 Dock 图标」。但因为 P1 里那次无条件的
`showMainWindow()`，进程**在启动瞬间就被切成 `.regular`**，而全项目**没有任何一处切回 `.accessory`**。

结果：Dock 图标从启动起出现，**关闭主窗口也不消失，一直保留到退出应用**。
`windowWillClose`（`App.swift:96`）只改了 `windowActivity.visible`，没碰激活策略。

对一个菜单栏番茄钟来说这是行为不一致：要么老实当常规 App（那就该去掉 `LSUIElement`），
要么关窗后收回图标。

### 我的假设（请挑战）

`LSUIElement = YES` 是上游遗留（上游是纯 popover 菜单栏应用），V1.2 加主窗口时引入了
`.regular` 但没处理配套的生命周期。

用户已选定 **方案 B**：保留「打开应用即弹主窗口」，但关窗后收回 Dock 图标，且登录自启时不弹窗。

> ❓**评审问题**：`.regular` ↔ `.accessory` 来回切换在 macOS 27 上是否有已知的窗口层级 /
> 键盘焦点 / 菜单栏状态项副作用？是否更稳妥的做法是**去掉 `LSUIElement`**、承认它是常规 App，
> 只在无窗口时用 `NSApp.setActivationPolicy(.accessory)`？两种方案哪个风险更低？

## 评审意见（Codex）

**结论：部分同意；Dock 生命周期缺口成立，严重性建议降为中等体验问题。**

`LSUIElement` 给出启动时默认策略，运行后切换 `.regular` 是合法设计，两者本身不矛盾。
真正缺口是 `App.swift:96` 关闭主窗口后未降回 `.accessory`。只读运行查询确认当前应用
`activationPolicy.rawValue == 0`（regular），但本次没有执行关窗，关窗后的结论来自源码。

保留 `LSUIElement = YES`，显示主窗口时升为 regular，**主窗口真正关闭**时降为 accessory，是符合方案 B 的最小改动。
删除 LSUIElement 会让登录启动先按常规应用出现，不能降低风险。不要在 `windowDidResignKey` 中降级，
那也会发生在打开设置 sheet、切到其他应用时；最小化也不是关闭。处理时核对 notification 对象确为主窗口，并检查策略切换返回值。
始终 accessory 也可以展示窗口，但会改变 Dock / Cmd-Tab 体验，不属于保持现有主窗口行为的最小修复。

Apple 支持运行期切换，但不能据此保证 macOS 27 的 sheet、提醒 panel、全屏 Space、关闭后重开没有回归；这些需要隔离构建实测。
[accessory 契约](https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy-swift.enum/accessory)、
[策略切换返回值](https://developer.apple.com/documentation/appkit/nsapplication/setactivationpolicy(_:))。

只读运行核验（本次已执行）：
```sh
xcrun swift -e 'import AppKit; for a in NSWorkspace.shared.runningApplications where a.bundleIdentifier == "com.dilyar.TomatoBarPersonal" { print(a.activationPolicy.rawValue) }'
```

### 2026-09-29 补丁复核（Codex）

**同意补齐生命周期，严重性仍为中等体验问题；候选补丁完成。**
App.swift 的 windowWillClose 先核对关闭对象就是 mainWindow，再切 accessory 并检查返回值。
失焦、最小化回调不降级；打开主窗口切 regular，手动 reopen 不受登录来源标记限制。
构建已通过，**未实测 Dock/Space/sheet 行为**；不能将此条移到已验收完成。用户固定在 Dock 的快捷方式不由应用删除。

---

## 🟡 P3 — 长休息图标永远不会显示

**状态**：待评审 · **当前即可复现** · 预计 3 行改动

### 证据

资源与声明都存在：

```sh
ls -d TomatoBar/Assets.xcassets/BarIcon*.imageset
# → BarIconIdle / BarIconLongRest / BarIconShortRest / BarIconWork

grep -n "static let longRest" TomatoBar/App.swift
# → App.swift:8: static let longRest = Self("BarIconLongRest")
```

但唯一的图标选择逻辑（`TomatoBar/Timer.swift:143`）：

```swift
let icon: NSImage.Name = state.phase == .work ? .work : (state.phase == .rest ? .shortRest : .idle)
```

`.rest` 阶段**一律用 `.shortRest`**，从不区分长/短休息。

```sh
grep -rn "\.longRest" TomatoBar/*.swift
# → 只有 App.swift:8 的声明，无任何使用点
```

### 影响

`BarIconLongRest.imageset` 是死资源。用户进入长休息（`restMinutes` 返回 `longRestIntervalLength`）时，
菜单栏显示的是短休息图标。

注意 `FocusPhase` 只有一个 `.rest`，长短休息的区别仅体现在 `TBTimer.restMinutes`
（`Timer.swift:66`，按 `state.rounds % workIntervalsInSet` 判断）。所以修这条需要在
`updateStatus()` 里比较 `restMinutes == longRestIntervalLength`，或在 `FocusState` 里区分阶段。

> ❓**评审问题**：`restMinutes` 依赖 `@AppStorage` 的 `longRestIntervalLength` / `shortRestIntervalLength`，
> 若用户把两者设成相同值，图标判断会怎样？是否应该在 `FocusState` 层面记录本次休息的类型，
> 而不是事后从设置反推？（后者在用户中途改设置时会显示错误的图标）

## 评审意见（Codex）

**结论：同意未使用长休息图标；维持低至中等的视觉问题，撤回「可靠修复仅 3 行」估计。**

已核对资源、声明、所有使用点。原文 `grep "\.longRest"` 不会匹配声明中的 `let longRest`，
实际应是零使用点；不影响死图标结论。不要比较 `restMinutes == longRestIntervalLength`：短长时长相同就误判。
仅更改两种时长且仍不相等时，等值判断未必变错；**改变每组番茄数**才会直接改变取模结果，即使当前休息 deadline 完全没变。

若要保证中途改设置、暂停恢复、重启后图标语义稳定，建议在开始休息时确定 `RestKind` 并随 FocusState 持久化，
由状态决定当前图标；下一次休息才使用新设置。旧 sessions.json 缺字段必须能解码（可选字段/自定义兼容解码），
不能仅新增一个有默认值的非可选 Codable 属性就假定自动兼容。旧记录无法总是精确反推类型，要明确 fallback。
这是比 3 行大的领域改动，实施前应确认范围并补覆盖，不需要把 FocusPhase 拆成两种 rest 状态。

独立逻辑核验：
```sh
xcrun swift -e 'let rounds = 4; for group in [4, 3] { print(rounds % max(1, group) == 0) }; let short = 5, long = 5; print(short == long)'
# true, false, true：改组大小会变类型；相同时长不能编码类型。
```

---

## 🟡 P4 — 本地化整体是死的

**状态**：待评审 · 清理类

### 证据

```sh
for f in TomatoBar/*/Localizable.strings; do echo "$f: $(grep -c '=' "$f") 行"; done
# → en.lproj / ko.lproj / zh-Hans.lproj 各 23 行，键名如 IntervalsView.min

grep -rn "NSLocalizedString\|LocalizedStringResource" TomatoBar/*.swift
# → 无任何结果
```

界面文案全部是硬编码中文字面量，例如 `Timer.swift:55-60` 的 `phaseLabel`、
`View.swift` 与 `MainWindow.swift` 中所有 `Text("…")` / `Button("…")`。

### 影响

- 英/韩翻译是**纯死重量**，App 实际是中文单语，却仍打包三个 `.lproj` 目录
- 那些键（`IntervalsView.*`）对应的是**上游的旧界面**，与 V1.2 的新文案完全对不上。已抽样确认：`IntervalsView.min` 在 `.strings` 里存在，但 `grep -rn` 在所有 `.swift` 中**找不到**
- SwiftUI 的 `Text("中文")` 会走 `LocalizedStringKey` 查找，但因无匹配键而回退到字面量 —— 功能上无害，但文件具有误导性

补充观察：`project.pbxproj:141` 是 `developmentRegion = en`，`:143` 是 `knownRegions = (…)`，
全文件 `lproj` 只出现 3 次 —— 说明这些 `.lproj` 并非以独立 build file 形式引用，
清理时的牵连面比预想的小。但 `developmentRegion = en` 与实际硬编码中文界面**不一致**，
是否要一并改成 `zh-Hans` 待定。

> ❓**评审问题**：删掉三个 `.lproj` 是否会影响 `CFBundleLocalizations` / App Store 元数据 /
> 系统语言协商？还是说对私有分发的个人 App 完全无影响？另外，`project.pbxproj` 里是否还有
> 对这些 `.lproj` 的 build phase 引用需要一并清理？

## 评审意见（Codex）

**结论：部分同意；旧翻译键失效成立，降为低优先级清理，项目引用分析错误。**

没有 NSLocalizedString 不意味着 SwiftUI 本地化机制失效；这里是旧键与新中文字面量不匹配，
没有完整英韩界面属于个人版当前定位，不应视为功能缺陷。

`project.pbxproj:16,169` **确实把 Localizable.strings 加入 Resources build phase**；
`:217-226` 是 PBXVariantGroup，`:33,36,37` 是三种语言子引用，`:87` 是组引用。
只数 `lproj` 出现次数漏掉了间接引用；不能只删磁盘文件。

删除会改变 Bundle 支持的语言集合与 fallback；developmentRegion 也会影响系统提供的文案、格式协商。
不是「私有分发就完全无影响」。若清理，要一起处理 variant group/build file/资源阶段/knownRegions，
检查生成 Info.plist 的 CFBundleDevelopmentRegion、Bundle.localizations / preferredLocalizations，
在中文和英文系统语言下看系统控件文案；不要宣称能改变 App Store 上另行配置的商店元数据。
中文单语可考虑同步 developmentRegion，但应作为明确产品选择，非顺手改值。

补充核验（已执行）：
```sh
rg -n 'Localizable|PBXVariantGroup|developmentRegion|knownRegions' TomatoBar.xcodeproj/project.pbxproj
rg -n 'IntervalsView|NSLocalizedString|LocalizedStringResource' TomatoBar --glob '*.swift'
```

---

## 🟡 P5 — `FocusSummary` 在每次 body 求值时被重复构造 13 次

**状态**：已记录，**暂不修**（过早优化）· 但请评审我的复杂度分析是否准确

### 证据

`TomatoBar/MainWindow.swift:17-18` 是**计算属性**，不是缓存值：

```swift
private var summary: FocusSummary { FocusSummary(records: history.records, period: period, date: date) }
private var filtered: FocusSummary { FocusSummary(records: history.records, period: period, date: date, category: selectedCategory) }
```

Swift 计算属性**每次访问都重新求值**。实测访问次数：

```sh
grep -o "summary\.[a-zA-Z]*" TomatoBar/MainWindow.swift | sort | uniq -c
#   5 summary.interval
#   5 summary.categories
#   1 summary.seconds      → 小计 11 次
grep -n "filtered" TomatoBar/MainWindow.swift
#   :20 filtered.records  ·  :35 FocusChart(summary: filtered, …)  → 2 次
```

**合计 13 次构造 / 每次 body 求值。**

而 `FocusSummary.init`（`Analytics.swift:46-64`）本身是 O(天数 × 记录数)：

```swift
categories = Self.totals(records: self.records, interval: interval)   // Analytics.swift:54，1 次全量扫描
var cursor = interval.start
while cursor < interval.end {                                          // Analytics.swift:57
    days.append(FocusDay(date: cursor, categories: Self.totals(        // Analytics.swift:59，每天再全量扫描一次
        records: self.records, interval: DateInterval(start: cursor, end: min(next, interval.end)))))
```

月视图 31 天 → 每次构造 32 趟全量扫描 → **13 × 32 ≈ 416 趟全量记录扫描 / 每次 body 求值**。

### 触发时机（我核对过，不是每次按键）

`MainWindowView` 只在 `!historyTab` 时访问 `summary`/`filtered`；`visibleRecords`（:19-25）
和 `recordList`（:184）里的三元表达式在 `historyTab == true` 时**短路**，不会构造 `FocusSummary`。
所以历史页搜索框（`:151`，绑定 `@State search`）的按键**不触发**本问题。

概览页下触发 body 求值的有：日/周/月切换、日期翻页、分类筛选、展开/收起分类、
标签页切换、任一 sheet 开关（`editing` / `settings` / `expandedTimer` 都是本视图 `@State`）、
以及 `history.records` 变化。

### 现有的正确设计（应予肯定，勿误改）

`MainWindowView` 观察的是 `history: FocusHistory`（`:7`）而**不是** `timer: TBTimer`（`:6` 是 `let`）。
所以 `TBTimer` 的 0.25 秒 ticker **不会**驱动整页统计重算。`TimerCard` 自己 `@ObservedObject var timer`，
只重绘卡片。这个分层是对的，`design-qa.md` 也记录了该意图。**修 P5 时不要破坏它。**

### 影响评估

当前用户只有 **1 条**记录 → 416 趟扫描 = 416 次操作，完全无感。
若累积到 500 条 → 月视图每次交互约 **20 万次记录访问**，切换日/周/月大概率可见卡顿。

### 修法（若将来要修）

把 `summary` / `filtered` 从计算属性改为在 `body` 内 `let` 一次；或引入按
`(period, date, selectedCategory, records.count)` 键的缓存。

> ❓**评审问题**：
> 1. 我的 13 次 / 416 趟估算准确吗？SwiftUI 是否会对 `body` 内的计算属性访问做某种融合，使实际次数低于我的静态计数？
> 2. 有没有更根本的修法 —— 例如让 `FocusSummary` 的 `days` 改为惰性计算，或预先按天分桶一次？
> 3. 到什么数据量才值得动手？给个阈值建议。

## 评审意见（Codex）

**结论：部分同意重复计算风险；不同意固定 13 次 / 416 趟及 500 条大概率卡顿。维持暂不修。**

静态出现次数不是动态调用次数：`MainWindow.swift:100` 两次 interval 只在周视图发生；`:113` 三元分支只走一个；
`:125` 只在类别 > 5 且未展开时读 count。反过来，`filtered.records` 经 `visibleRecords` 被 `:144,160,168` 反复访问，
`:184` 的 `summary.interval` 位于每个记录行里，随 LazyVStack 求值行数增长，绝非固定一次。
SwiftUI 没有给这些计算属性自动 memoization 的契约；编译器可能做合法优化、SwiftUI 可能延迟/重用子树，
精确调用数需 Instruments 或临时计数，不能从 grep 得出。

`Analytics.swift:50-53` 先扫描全部 N 条并遍历 segment，随后排序；`:54,59` 扫的是筛选后的 M 条，**不是全库 N 条**。
若平均每条 K 个 segment、D 天、C 个分类，粗略成本是
`O(NK + M log M + (D+1)MK + (D+1)C log C)`，而非只算 D×N。
当前月份九月还是 30 天，不是 31 天；416 只能是错误假设下的算术，不是实测操作数。

本次 `swiftc -O` 领域基准：31 天、全部记录在当月、每条 1 个 60 秒 segment、1 分类，每档 21 次取中位数。
单次月汇总 N=1 **0.020 ms**、N=500 **1.231 ms**、N=5000 **5.854 ms**。
这不包含 SwiftUI、布局、列表行重复构造与磁盘保存，不能当整页耗时，也不能用来保证 5000 条流畅。
先在 500 / 5000 条和多 segment 场景做 UI profile；以目标设备统计占主线程 >16 ms 或交互稳定 >100 ms 为排期信号，
不要设一个通用记录数阈值。当前一条记录无须优化。

原分层正确：保留 MainWindowView 观察 history、TimerCard 观察 timer。
未来优先一次生成并传递 summary 给子视图/记录行，避免每行构造；仅在 body 声明局部 let，
却让其他计算属性继续调用原 getter，不会解决问题。**缓存键不能只含 records.count**：改名/改首标签不会改变 count，
却会改变列表和分类；需记录内容或可靠 revision，并考虑时区/日历。按天分桶优化也须保留跨日 segment 裁剪。

可复跑的领域基准见文末「评审复现脚本」；暂缓优化这一已否决决定不翻案。

---

## ⚪ P6 — 仓库里的死文件

**状态**：待评审 · 清理类

```sh
grep -rn "export_options\|swiftlint" scripts/ .github/ TomatoBar.xcodeproj/project.pbxproj
# → 无任何引用
```

| 文件 | 情况 |
|---|---|
| `export_options.plist` | 上游遗留（用于 archive 导出）。本项目用 `scripts/build.sh` 直接 `xcodebuild build`，不 archive |
| `.swiftlint.yml` | 配了 `disabled_rules: [trailing_comma, opening_brace]`，但**从未有任何脚本或 CI 运行过 SwiftLint**，且本机未安装 |
| `Icons/` | **已确认零引用**：`grep -c "Icons/" project.pbxproj` → **0**，但 7 个文件仍被 git 跟踪（`TomatoBar.png`、`TomatoBarAlt.png`、`TomatoBarOld.png`、`tomato-filled.png`、`convert.sh`、`README.md`）。当前 App 图标来自 `Assets.xcassets/AppIcon.appiconset`。**唯一可能的保留理由**是 `convert.sh` 是从源图重新生成各尺寸图标的工具 —— 若如此应保留 `convert.sh` + 一张源图，其余可删 |

已确认的本地化死键抽样：`IntervalsView.min` 在 `zh-Hans.lproj/Localizable.strings` 中存在，
但 `grep -rn` 在**所有 `.swift` 文件里都找不到**（对应 P4）。

> ❓**评审问题**：`.swiftlint.yml` 是该删掉，还是**接进 CI 真正跑起来**？考虑到 P7 建议的新
> workflow，加一个 SwiftLint 步骤成本很低，但会引入一个需要维护的规则集。个人项目值不值得？

## 评审意见（Codex）

**结论：部分同意；维持低优先级，Icons 不同意整体判死。**

已执行原引用搜索，当前脚本/CI 没引用 export_options 或 swiftlint。
只能得出「当前自动流程未使用」，不能证明历史上从未手动运行 SwiftLint；`.swiftlint.yml` 也可被工具约定自动发现。
当前不建议为清死文件而额外引入 SwiftLint / 新规则维护；后续实现者可选择删除配置或明确为可选工具保留。

`Icons/convert.sh:3-9,18-28,53-59` 分别需要 **TomatoBar.png 和 tomato-filled.png 两张源图**，
后者用于四组菜单栏图标，前者用于 AppIcon。保留脚本只留一张图会破坏其中一个入口。
`Icons/README.md:1` 记录图标来源，应保留来源信息；源图、说明、开发工具不要求被 Xcode 引用才有价值。
可再核对 Alt / Old 图是否还有人工设计用途，但不要直接由零 build 引用推导它们必须删除。

补充核验（已执行，不运行会改资源的 convert 脚本）：
```sh
cat Icons/README.md
nl -ba Icons/convert.sh
```

---

## ⚪ P7 — CI workflow 是上游的，缺 secret 会失败

**状态**：✅ **已修复 @ `abf55df`**（2026-09-28，Claude Code），并已在真实 CI 运行中验证 · Codex 评审后提升为中等构建/发布风险

### 修复方式

整体替换 `.github/workflows/main.yml`，不是改过滤器（Codex 已否决只把 `*` 改成 `**`）。
新 workflow 单 job 两步：

1. **Domain tests** — `sh scripts/test.sh`。无 secret、无签名、数秒完成，放在第一步，
   逻辑失败就不必再花构建分钟数
2. **Build smoke check** — Release 构建 + 断言产物名、ad-hoc 签名、bundle id。
   理由采纳 Codex 意见：`test.sh` 只编译 9 个 Swift 文件中的 **3 个**，
   App / Timer / View / MainWindow / FocusCharts / Notifications **无任何其他覆盖**，
   编译检查是防止 UI 层拼写错误的唯一防线

单个 job 而非两个：macOS 分钟数对私有仓库额度按 **10 倍**计。
`concurrency` 取消同分支被取代的运行，同理。
`branches-ignore: [main]`：main 是冻结的上游基线，既无 `scripts/test.sh` 也无 `Tests/`。
`runs-on: macos-latest` 而非钉死 `macos-15`（会被退役）。

### 首次真实运行结果（[run 36431326540](https://github.com/mikilolipop/TomatoBar-Personal/actions/runs/36431326540)）

| 项 | 值 |
|---|---|
| 结论 | **success**，分支 `feature/personal-focus` |
| 耗时 | 46 秒（测试 13:49:10 → 构建成功 13:49:53） |
| Runner | `macos-latest`，Xcode 26.6，macOS SDK 26.5 |
| 测试 | 四行 PASS 齐全，末尾 **`PASS: 61 total checks including storage recovery`** |
| 构建 | 42 行 SwiftCompile/Ld + `** BUILD SUCCEEDED **`，**arm64 + x86_64 通用二进制** |
| 产物断言 | `grep -x 'com.dilyar.TomatoBarPersonal'` 实际匹配并输出（日志第 2150 行） |

> 46 秒含一次通用二进制 Release 构建，快得可疑，因此**拉取完整日志逐项核实**，
> 没有只看绿色勾。步骤确实做了实事。

### 顺带解决了本条的「未解之谜」

这次推送是天然实验：同一分支、同一仓库，**只把过滤器从 `branches: '*'` 换成
`branches-ignore: [main]`，workflow 就立刻登记并运行了**
（`actions/workflows` 从 0 → 1、state=active；`actions/runs` 从 0 → 1）。

这**证实了 Codex 的诊断**：GitHub filter 的 `*` 不跨越 `/`，所以 `feature/personal-focus`
从未匹配过。

但 **main 首次推送为何也没触发，仍未证实** —— main 当时带的是上游那份 `branches: '*'`，
理应匹配。保留为未解，不写成已查明。现已无关紧要：新 workflow 显式处理了分支匹配。

### 原上游 workflow 为何必须整体替换（保留 Codex 的发现）

- 需要 `CODESIGN_CERT_BASE64` / `_PASSWORD` / `_PEM_BASE64`，本仓库 `actions/secrets` 为 0
- **Build 步骤 `cp -r "$BUILT_PRODUCTS_DIR/TomatoBar.app"`，而 `PRODUCT_NAME = "TomatoBar Personal"`**
  （`project.pbxproj:372,407`）→ 即使 secret 齐全也会失败（Codex 发现，Claude 漏掉）
- 第一步删 prerelease tag、末尾发布 zip，是上游公开发布流程，对个人 fork 无意义
- **它从不运行 `scripts/test.sh`** —— 61 项领域检查此前完全没有 CI

### 证据

`.github/workflows/main.yml` 随仓库推送，触发条件为 `push: branches: '*'` 与 `tags: 'v*'`。
依赖以下 secrets（本仓库均**不存在**）：

- `secrets.CODESIGN_CERT_BASE64`（第 40 行，`apple-actions/import-codesign-certs`）
- `secrets.CODESIGN_CERT_PASSWORD`（第 41 行）
- `secrets.CODESIGN_CERT_PEM_BASE64`（第 45 行）

仓库 Actions 状态：`enabled: True`，`allowed_actions: all`。
当前 `actions/runs` 的 `total_count: 0` —— **推送后并未触发**，原因未查明（见下）。

### 未解之谜（请协助判断）

首次推送两个分支后 Actions 运行数为 **0**。workflow 文件确认已在远程
（`GET /contents/.github/workflows/main.yml?ref=feature/personal-focus` → HTTP 200），
Actions 也是启用状态。为什么没触发？

可能原因：新建空仓库首次推送的注册延迟？还是 `branches: '*'` 不匹配含斜杠的
`feature/personal-focus`？—— 后者我倾向于是真正原因，因为 GitHub 的 `branches` filter
默认用 glob，`*` **不跨越 `/`**，需要 `**` 才能匹配 `feature/personal-focus`。
但 `main` 分支的推送本该匹配 `*` 却没触发，这点我解释不了。

> ❓**评审问题**：请判断未触发的真实原因。这直接影响「它以后会不会突然开始红叉」。

### 影响

如果将来触发，会在「Import signing certificate」步骤失败（缺 secret）。此外它的
Release / Prerelease 步骤是为**上游的公开发布流程**设计的，对个人 fork 毫无意义，
第一步「Delete old prerelease」还会在本仓库删 tag。

### 建议方案

替换为极简 workflow：只跑 `scripts/test.sh`。

- 不需要任何 secret
- 不需要签名（`test.sh` 用 `xcrun swiftc` 直接编译领域层三个文件）
- 几秒到几十秒跑完
- runner 用 `macos-15` 或更新

`scripts/build.sh` 是否也进 CI 待定：它需要解析两个 SwiftPM 依赖并做 codesign，
在 CI 上耗时明显更长，且 ad-hoc 签名的产物无法分发，价值有限。

## 评审意见（Codex）

**结论：部分同意；提升为中等构建/发布风险。feature 分支原因确定，main 首次零运行根因仍未证实。**

本次用已有 Git 凭据进行 GitHub REST GET（未打印凭据、未改设置），独立确认：
- 仓库 `private=true, fork=false`，创建于 `2026-09-28T12:36:39Z`，默认分支 feature/personal-focus。
  它是代码意义的 fork，不是 GitHub fork 网络成员，不能套用「fork 默认禁用 workflow」解释。
- actions/permissions：enabled=true, allowed_actions=all；actions/secrets：0。
- **actions/workflows：0，actions/runs：0**；文件存在并不等于 workflow 已被登记执行。
- 两分支 workflow 的 blob SHA 同为 `30f604050597df873d611409b53e5e0f883a44a1`，2255 字节。
- events 只返回 12:38:37Z / 12:38:39Z 两次 CreateEvent；本地 reflog 确认两次初始 push，
  以及 feature 分支 21:15:41 +0800 的后续 push。事件列表未列出后者的 PushEvent，因此**事件列表不是完整投递审计**，
  不能用「只有 CreateEvent」断言初次 push 没有发生。

[GitHub filter 规则](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#filter-pattern-cheat-sheet)
明确 `*` 不跨 `/`，所以 feature/personal-focus（包括本次文档 push）不匹配；main 匹配。
现有 API 无法回溯首次事件的 Actions 内部判定；新仓库登记/事件处理时序只能列为假设，
**不能把它写成已查明的根因**。没有通过推 main/tag、改 workflow 或派发发布动作来试错。
若必须追究这一次，需要原始投递/平台支持证据；另建无副作用的最小仓库只能验证机制，不能证明历史原因。

未来 main 新 push 或匹配 v* 的 tag 仍可能触发，零历史运行不是安全保障。
即使触发，**也不保证第一个失败点就是签名**：先有删 prerelease（受 token 写权限影响）、
再 `git describe --tags`（本仓库若没有可达 tag 也会失败）。后面的签名 secrets 确实缺失，
Build 还硬编码 `TomatoBar.app`（`:53-54`；产品名见 `project.pbxproj:372,407`），与个人版产物名不一致。此 workflow 没有跑 55 项领域测试。

赞成后续用不依赖 secrets 的 macOS 测试 workflow 替换，并明确匹配 feature/personal-focus 或 `**`；
不要只把原发布流程的 `*` 改成 `**`。UI 桥接层目前不在领域测试内，故无签名构建 smoke check 仍有价值，
不能因 ad-hoc 产物不适合常规分发就判定构建检查价值有限。本轮未改 CI。

独立复查（有 gh 的终端；本机本轮无 gh，实际使用等价 REST GET）：
```sh
gh api repos/mikilolipop/TomatoBar-Personal/actions/permissions
gh api repos/mikilolipop/TomatoBar-Personal/actions/workflows
gh api repos/mikilolipop/TomatoBar-Personal/actions/runs --jq .total_count
gh api repos/mikilolipop/TomatoBar-Personal/events --jq '.[] | {type,created_at,payload}'
git reflog show --date=iso refs/remotes/origin/main
git reflog show --date=iso refs/remotes/origin/feature/personal-focus
```

---

## 🔴 P8 — 登录静默方案还遗漏恢复提醒的激活路径

**状态**：2026-09-29 与 P1 一起完成候选补丁；真人登录未验收。**严重性：高，与 P1 一并处理。**

证据：`App.swift:44` 在启动时对 needsAttention 无条件 `reminder.show`；
`Notifications.swift:22-24` 会 activate / makeKeyAndOrderFront / orderFrontRegardless。
`State.swift:184-186` 的 recover 只暂停运行中状态，保留 workFinished/restFinished。
因此仅包住 `App.swift:43` 的 showMainWindow 无法满足「登录不弹窗不抢焦点」。

本次已对合成状态做 encode/decode/recover：输出 `recovered=workFinished attention=true`。
保留待确认状态是正确设计；修的是**登录时展示策略**，不能为了静默把状态清成 idle 或自动进入下一段。

独立核验：
```sh
sed -n '40,45p' TomatoBar/App.swift
sed -n '6,24p' TomatoBar/Notifications.swift
sed -n '184,187p' TomatoBar/State.swift
# 下方复现脚本包含编码/解码/恢复探针，不碰任何用户 sessions.json。
```

## 评审意见（Codex）

2026-09-29：**同意，保留与 P1 联动的高优先级。** 当前候选补丁把初始主窗口和恢复提醒放在同一个
shouldShowInitialWindows 分支；不清 needsAttention、不自动确认下一阶段。后续由用户主动查看或正常到时的提醒路径不变。
已检查 recovered paused / workFinished 不会因首次普通 tick 被当作新完成再次提醒；真实登录恢复提醒仍待清单第 6–8 步。

---

## 🟡 P9 — 读盘失败界面提供一个必然无效的「重试保存」按钮

**状态**：✅ **已修复 @ `e69be32`**（2026-09-28，Claude Code）· Codex 新增，静态控制流确认 · 严重性：低，错误恢复体验

### 修复方式

没有隐藏按钮，而是**让它真的能用**：`retrySave()` → `retryStorage()`，读失败时重新读盘
（新增私有 `reload()`），写失败时重试保存；`storageRetryTitle` 相应显示「重新读取」/「重试保存」。
两个错误横幅都加了「打开记录文件夹」，让修复路径从提示文案处即可到达。

`loadFailed` 阻止 `persist()` 覆盖损坏文件的保护**完全保留** —— `reload()` 只读不写。

顺带修了 `openRecordsFolder()` 会覆写既有 `storageError` 的问题：它现在紧贴那条消息，
覆盖掉就等于藏起「记录有风险」的唯一信号。

### reload() 为何安全（这是整个修法的前提，已逐个写入口核验）

`loadFailed` 期间 `phase` 恒为 `.idle`：`startWork` 被 `storageError` 挡住（`Timer.swift:74`），
`editRecord` 与 `persist` 被 `loadFailed` 挡住（`:90`、`:135`），因此从未写盘；
其余变更方法在 idle 下全是 no-op（`State.swift:140/156/164` 的 guard）。**内存中无可丢失数据。**
该不变量已写进 `reload()` 的注释，因为它是这个方法安全的全部理由。

### 测试

55 → **61 项**。`TBTimer` 依赖 SwiftUI，不在 `scripts/test.sh` 编译范围内，
故新增检查覆盖恢复路径的 `FocusStore` + `FocusState` 一半：失败读取保留损坏字节原样、
修复后无需重启即可再次加载、且保留时长/待确认状态/`needsAttention`。

变异检验：让 `recover()` 清掉 `needsAttention` **被抓到**；让 `load()` 完全吞掉错误
（真实世界里「防御式编程」最可能犯的错，会静默丢弃全部记录）**被 `Tests/main.swift:52`
既有的 corrupt-file 检查抓到**。

> ⚠️ 第一次做该变异时只改了 decode 一行，结果**无效** —— `load()` 有**四个**抛错点
> （`Data(contentsOf:)`、`JSONDecoder`、`JSONSerialization`、`copyItem`），
> 其余仍在抛错，行为未变。做变异检验时必须确认变异**真的改变了可观察行为**，
> 否则「没抓到」是变异无效，不是测试有洞。

UI 层改动 `test.sh` 编译不到，已用 `scripts/build.sh` 干净构建验证，
并在产物二进制中确认 `重新读取`、`重试保存`、新错误文案与私有 `reload()` 符号
（`_$s18TomatoBar_Personal7TBTimerC6reload…`）均存在。

证据：`Timer.swift:36-38` 读盘异常后 loadFailed=true；`:108` 的 retrySave 在此条件下什么也不做，
也不会重新 load。`View.swift:47-50` 与 `MainWindow.swift:220-221` 却对所有 storageError 展示「重试保存」。
即使用户已在外部修复文件，点它也不会恢复，必须重启应用。阻止覆盖损坏原文件是正确且必须保留的安全设计，
问题是按钮承诺与行为不一致。建议区分读/写错误：读错误说明备份修复后重启，或设计安全的重载路径；不能简单去掉 loadFailed guard。

独立核验：
```sh
sed -n '31,40p;108,109p;134,139p' TomatoBar/Timer.swift
rg -n -C 2 '重试保存' TomatoBar/View.swift TomatoBar/MainWindow.swift
rg -n 'loadFailed|store.load' TomatoBar/Timer.swift
# loadFailed 只在初始化设定；retrySave 不包含 reload。
```

## 评审意见（Codex）

2026-09-29：**同意 P9 的修复方向，维持已修状态，不以本轮领域测试冒充 reload UI 验收。**
Timer.swift:144-165 区分 loadFailed 并重新读盘；坏文件保护仍在 persist guard。
本轮另外实测真实 TBTimer 编辑/删除的失败返回与内存保留，没有修改这段已经验证的恢复代码。

---

## 🟡 P10 — 菜单栏 popover 的删除路径未经 UI 验收

**状态**：新增（2026-09-28，Claude Code 实施删除功能时发现）· 严重性：低 · **需要一次人工点击确认**

三个删除入口中有两个已完成 UI 验收：主窗口记录行的 ⋯ 菜单、以及编辑器内的「删除记录」。
**菜单栏 popover 的入口没能自动化验证。**

原因是工具限制，不是代码问题：

```
状态栏项可用动作: 仅 AXPress（无 AXShowMenu），子元素 0
perform action "AXPress"  → 窗口数仍为 1，popover 未出现
click at {876,16}（按实测坐标）→ 同样未出现
```

`popover.behavior = .transient`（`App.swift:29`），在辅助功能控制下焦点状态变化可能让它立即关闭。
本机也没有屏幕录制权限，无法用截图旁证。

**风险有限**：popover 用的是**同一个 `RecordEditor` 组件**，已在主窗口 sheet 里逐项验证；
popover 特有的代码只有 4 行 `onDelete` 闭包，与主窗口的结构完全相同且已通过编译。
但这不等于验证过 —— 需人工点一次：菜单栏图标 → 记录页 → 铅笔 → 删除记录 → 取消 → 再删除 → 确认。

## 评审意见（Codex）

2026-09-29：**部分同意。维持中低验收风险，不把“未验”当成功能必坏。**

- `MainWindow.swift:75-97`：取消按钮清 nil，Binding 被系统置 false 时也清 nil；确认动作先清 pendingDelete，
  再用 presenting 闭包捕获的 record 删除。没有发现“先清 pendingDelete 就丢 UUID”的错误。
  模态期间第二次点击不应产生并发写；即使重复调用，UUID 第二次缺失只返回错误，不会删下一行。
  真实桥接探针已证实这一点；系统关闭/Return/Esc/连续点击的实际事件顺序未验。
- `View.swift:263-270`：confirmDelete 由 alert 的 isPresented 生命周期复位，取消不调用 onDelete；
  删除失败编辑器保留并显示错误，成功由父级关闭。shared editor 不等于 popover 的焦点和 alert 生命周期也验过。
- **不同意源码注释及原交接中“destructive role 保证不是默认按钮”的确定性断言。** role 标记危险操作，
  `.cancelAction` 指定 Escape，并不能单独证明 Return 默认指向取消；
  [Apple defaultAction](https://developer.apple.com/documentation/swiftui/keyboardshortcut/defaultaction)
  才是指定主要键盘操作的接口。当前没有 Return 实测证据，不能反向断言“现在 Return 必然删除”。
  后续应显式指定取消为 defaultAction 并验证 Esc 仍取消；本轮不凭推测修改已验过的 alert。
- 真实桥接 `scripts/test-bridge.sh` 12 项：UUID 删除、重复删除、落盘、轮次保留、编辑/删除写失败与 history 一致性。
  这比值类型复制测试更接近实际，但不覆盖 SwiftUI 弹窗或交互。

**布局结论：部分同意结构改善；没有证据证明不会裁切，也没有证据证明滚动死锁。**
`View.swift:237-260` 只有一个编辑内容 ScrollView，标签用 LazyVGrid，不存在嵌套纵向 ScrollView 的必然争抢。
底栏与错误提示在滚动区外，320pt 的 popover 编辑区和 440×430 sheet（MainWindow.swift:68）会压缩内容，
长错误/最大文字设置下底栏可达性需实机测；主窗口 920×740 不能保证所有内容天然合适。
大量 `.font(.system(size: ...))` 固定字号不会简单随 dynamicTypeSize 放大，不能用 iOS 大字号假设判断 macOS。
本轮曾编译真实视图做 NSHostingView 离屏栅格化，但得到缺失文字/控件的图像，**舍弃为无效验收证据**。
没有为绕过同名进程风险退出或操作正式版；P10 popover、图标恢复自动、实际滚动和大字号保持待验。

---

## 🟡 P11 — 分类选择器的 accessibilityLabel 被 chevron 图标覆盖

**状态**：新增（2026-09-28，UI 验收时实测发现）· 严重性：低 · 无障碍

`View.swift` 中分类 `Menu` 设了 `.accessibilityLabel("统计分类：\(category)")`，但实测 AX 属性：

```
name        = [未分类]            ← 来自 label 里的 Text(category)
description = [向下移动]           ← 来自 chevron.down 图标，覆盖了我的 label
help        = [每条记录只计入一个分类]
```

同一控件在另一时刻读到 `name = [统计分类：英语]`，**说明 AX 名称不稳定**，
取决于 SwiftUI 何时重算 label。VoiceOver 可能读成「向下移动，菜单按钮」而不是分类名。

修法方向：给 chevron 图标单独加 `.accessibilityHidden(true)`，或把 label 换成
`Text(category)` 单一内容 + 外层 `.accessibilityLabel`。属小改动，但**需要 VoiceOver 实测**，
本机无法验证读屏结果。

## 评审意见（Codex）

2026-09-29：**部分同意，维持低严重性且未验收。** `View.swift:297-304` 的 chevron 没有 accessibilityHidden，
隐藏装饰图标是合理方向。但从 AX description/name 两次采样不能推导“被覆盖必由重算时机导致”，
也不能等同 VoiceOver 实际播报。原因结论应降为待证实；真人 VoiceOver 验收后再判定修复。

---

## 本轮已实现功能的交叉评审（2026-09-29）

### 解码与初始化契约

## 评审意见（Codex）

**同意兼容实现；未发现阻断级解码回归。** `State.swift:107-134` 的 CodingKeys 包含所有旧字段；
三个 Optional<Date> 使用 decodeIfPresent 与旧合成解码器一致：缺键/null 为 nil，有效数值解码，错误类型仍抛错。
categoryStyles 缺键/null 为 [:]，已存在且类型错误则抛错；这不会影响合法旧文件，不应把非可选旧字段缺失也容错成空状态。
FocusRecord.tags 的缺键/null 兼容在嵌套 records 中仍有效，日期策略沿用 JSONEncoder/Decoder 默认值。

新增 LegacyFocusState（旧字段形状的独立合成 Codable）作为 oracle，逐字段比较重编码值；覆盖 5 个 phase、
三种可选日期、必需旧字段缺失/null、旧 records 无 tags 与新样式字段缺失的组合、错误样式类型。
`Tests/main.swift:311` 起新增 42 项，`scripts/test.sh` 共 **138** 项通过。
显式 init() 恢复零参构造；旧 memberwise initializer 确实不再合成，但全库 `rg 'FocusState\(' --glob '*.swift'`
只发现零参调用，完整 UI 构建也通过。它是内部 app 类型，没有发现其他被悄悄破坏的现有初始化路径。

### 逐文件与刻意设计反向检查

| 文件 | 结论与边界 |
|---|---|
| State.swift | 兼容解码同意；删除只动 records 同意；普通 ASCII 大小写已通过，Unicode 不完全自洽见 P12；全量样式替换见 P13 |
| Timer.swift | 原子写入后才发 state/history 同意；写失败返回局部错误而不制造全局退出阻断是刻意设计。已有 storageError 也不会在失败 catch 被清掉。实际桥接已测 |
| View.swift | 首标签不进入其他标签可移除列表、删除成功由父级关闭、取消丢弃样式草稿均同意；alert 默认键不能仅凭 role 保证；整份 localStyles 快照见 P13 |
| MainWindow.swift | pendingDelete 派生 Binding 与捕获 record 的顺序同意；history/timer 观察分层保留；概览/历史复用清理条件有语义漏洞见 P14 |
| FocusCharts.swift | styles 值传入日图且 style-only edit 会发布 history，实测有通知，不能误报“仅改图标不刷新”；周/月不用图标符合现有图表意图；有限哈希集不保证分类图标互不重复 |
| Log.swift / Analytics.swift | 本次功能没有修改它们，重读后未发现删除集成新回归；统计只认首标签与历史筛选认全部标签是不同且合理的语义，P14 清理必须区分 |
| App.swift / Notifications.swift | 原版本与删除/图标无关；本轮按任务三改启动/关闭展示策略，未修改提醒确认后的计时路径，候选补丁待真人验收 |

删除最后一条分类记录后仍保留 categoryStyles，是方便复用分类的刻意设计，不应报成无引用字典泄漏。
图标覆盖是分类共享设置，不是每条记录的独立图标；界面未来可明确提醒这一点。
本轮未把建议分类灌入用户记录，也未把“未分类”重新作为清空标签的选择项。

---

## 🟡 P12 — Unicode 大小写规范化后图标覆盖失配

**状态**：新增，领域探针已复现，未修。**严重性：中等，特定自定义分类的视觉设置丢失。**

证据：`State.swift:153-158` 用 caseInsensitiveCompare 采用既有标签写法；
`View.swift:223-225,305-314` 用编辑草稿 category.lowercased() 做样式键；
`Timer.swift:137-138`、`FocusCharts.swift:136` 又以保存后的首标签 lowercased 查询。
`Straße` / `STRASSE` 和希腊 `ΟΣ` / `ος` 可以比较相等，但小写字符串不相同。
先有 Straße，编辑器输入 STRASSE 并选 star，会写 strasse 键，标签保存成 Straße，查询 straße 得 nil。

## 评审意见（Codex）

**部分同意原“自洽”判断：Swift/swift 已独立通过，但对所有允许输入的 Unicode 不成立。**
应由最终规范分类名决定写入键，并统一预览/解析时的别名回退；不能粗暴批量改旧字典键。
见分类视觉设计。独立核验：

```sh
xcrun swift -e 'import Foundation; for (a,b) in [("Swift","swift"),("Straße","STRASSE"),("ΟΣ","ος")] { print(a,b,a.caseInsensitiveCompare(b) == .orderedSame,a.lowercased() == b.lowercased()) }'
# true/true, true/false, true/false；端到端领域复现见下方新增问题探针。
```

---

## 🟡 P13 — 两处编辑器的全量样式快照会覆盖另一处已保存设置

**状态**：新增，状态层保存序列已复现；双窗口 UI 序列未实机验证。**严重性：中等，展示元数据丢失。**

证据：`View.swift:198-213` 在初始化抓取全量 localStyles；`:253-255` 每次保存传整个字典；
`State.swift:158` 无条件替换全局 map。主窗口 sheet 与菜单栏 popover 是两个入口（MainWindow.swift:57-68、View.swift:78-93），
源码没有共享编辑锁或增量合并。A/B 同时从空字典开始，A 保存 a=star，B 保存 b=globe，最终只剩 b。
即使 B 只改记录名称，仍提交它的旧整图，会撤销 A 的样式更新。原子写入保护文件完整，不能防止这个逻辑覆盖。

## 评审意见（Codex）

**不同意把“同一次原子保存”推成“多入口下不会丢样式”；新增中等问题。**
后续提交用户实际修改/删除的键的 delta 并合并最新 state，或明确禁止两个编辑草稿同时存在；无需引入数据库。
独立核验：执行下方新增问题探针，P13 输出仅 `["b": "globe"]`。UI 还需验证同时编辑的可达路径，不夸大为本轮已实机双窗口复现。

---

## 🟡 P14 — 概览分类筛选的清理错误地把次标签算作仍有该分类

**状态**：新增，领域条件已复现，未修。**严重性：低，筛选残留导致意外空列表。**

证据：`MainWindow.swift:89-92` 用 hasTag 清理概览和历史筛选；
`Analytics.swift:50-52` 概览按 category（首标签）筛选，`State.swift:69-73` 换分类把旧主标签留在尾部。
选中“阅读”，把最后一条阅读改为数学后，阅读仍作为次标签存在，clearStaleFilter 不清除，概览却显示 0 条。
这是最新分类编辑保留旧标签后很容易触发的交互，不是数据被删除。

## 评审意见（Codex）

**部分同意原筛选清理：历史页/popover 的全标签判断正确，概览应检查首标签语义。**
不要为修概览而把历史页也改成只看首标签。独立核验：执行下方探针，P14 输出 hasTag=true、primary summary=0；
并可在 QA13 选中唯一主分类后编辑换分类手工复验。

---

## 评审复现脚本

从仓库根运行；只在临时目录写独立探针，直接编译仓库原始领域代码。
这不是 UI 基准，也没有改动/替换 55 项正式测试。

```sh
python3 - <<'PYPROBE'
from pathlib import Path
import tempfile, subprocess
with tempfile.TemporaryDirectory(prefix='tomatobar-review-') as temp:
    root = Path(temp)
    (root / 'main.swift').write_text(r'''import Foundation
var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone(secondsFromGMT: 0)!
let date = cal.date(from: DateComponents(year: 2026, month: 10, day: 1))!
var checksum = 0.0
for n in [1, 500, 5000] {
    let records = (0..<n).map { i -> FocusRecord in
        let start = date.addingTimeInterval(Double(i % 31) * 86400 + Double(i / 31) * 60)
        let end = start.addingTimeInterval(60)
        return FocusRecord(id: UUID(), name: "probe", startedAt: start, endedAt: end,
            plannedSeconds: 60, completed: true,
            segments: [FocusSegment(start: start, end: end)], tags: ["tag"])
    }
    var ms: [Double] = []
    for _ in 0..<21 {
        let start = Date()
        checksum += FocusSummary(records: records, period: .month, date: date, calendar: cal).seconds
        ms.append(Date().timeIntervalSince(start) * 1000)
    }
    print("n=\(n) median_ms=\(ms.sorted()[10])")
}
var state = FocusState()
state.startWork(name: "probe", seconds: 1, at: date)
state.tick(at: date.addingTimeInterval(1))
var restored = try JSONDecoder().decode(FocusState.self, from: JSONEncoder().encode(state))
restored.recover()
print("recovered=\(restored.phase) attention=\(restored.needsAttention) checksum=\(checksum)")
''')
    subprocess.run(['xcrun', 'swiftc', '-O', 'TomatoBar/State.swift', 'TomatoBar/Analytics.swift',
                    str(root / 'main.swift'), '-o', str(root / 'probe')], check=True)
    subprocess.run([str(root / 'probe')], check=True)
PYPROBE
```

---

## 新增问题探针（P12–P14）

此探针只使用合成内存数据，不读写任何 sessions.json。输出复现当前缺陷，修复后应重新评估预期。
从仓库根目录运行：

```sh
python3 - <<'PYPROBE'
from pathlib import Path
import subprocess, tempfile
with tempfile.TemporaryDirectory(prefix='tomatobar-review-') as tmp:
    source = Path(tmp) / 'main.swift'
    source.write_text(r"""
import Foundation
let now = Date(timeIntervalSince1970: 1_800_000_000)
func record(_ tag: String) -> FocusRecord {
    FocusRecord(id: UUID(), name: "probe", startedAt: now, endedAt: now.addingTimeInterval(60), plannedSeconds: 60,
      completed: true, segments: [FocusSegment(start: now, end: now.addingTimeInterval(60))], tags: [tag])
}
var unicode = FocusState()
let u = record("Straße")
unicode.records = [u]
try unicode.editRecord(id: u.id, name: u.name, tags: ["STRASSE"], categoryStyles: ["strasse": "star"])
print("P12:", unicode.records[0].category, "override:", unicode.categoryStyles[unicode.records[0].category.lowercased()] as Any)
var concurrent = FocusState()
let a = record("A"), b = record("B")
concurrent.records = [a,b]
var editorA = concurrent.categoryStyles, editorB = concurrent.categoryStyles
editorA["a"] = "star"
try concurrent.editRecord(id: a.id, name: a.name, tags: a.tags, categoryStyles: editorA)
editorB["b"] = "globe"
try concurrent.editRecord(id: b.id, name: b.name, tags: b.tags, categoryStyles: editorB)
print("P13:", concurrent.categoryStyles)
var filtering = FocusState()
let f = record("阅读")
filtering.records = [f]
try filtering.editRecord(id: f.id, name: f.name, tags: FocusRecord.tags(withPrimaryCategory: "数学", in: f.tags))
print("P14: hasTag=", filtering.records.contains { $0.hasTag("阅读") }, "primary summary=", FocusSummary(records: filtering.records, period: .day, date: now, category: "阅读").records.count)
""")
    binary = Path(tmp) / 'probe'
    subprocess.run(['xcrun', 'swiftc', 'TomatoBar/State.swift', 'TomatoBar/Analytics.swift', str(source), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
PYPROBE
```

---

## 已修完

| 项 | 内容 | 提交 |
|---|---|---|
| **功能** | **单条历史记录删除**：`FocusState.deleteRecord(id:)` 按 UUID 删除、只动 `records`；`TBTimer.deleteRecord` 先落盘成功再更新内存与界面；`RecordEditor` 加红色「删除记录」+ 确认弹窗（名称/日期/时长/「删除后，这段专注时长将从统计中移除」，`role: .destructive` 使其不为默认按钮）；主窗口记录行加 ⋯ 菜单（编辑记录／删除记录），保留铅笔入口；删除后清除失效筛选标签。测试 61 → **90 项** | 见 git log |
| **功能** | **分类图标可手动选**：`FocusState.categoryStyles`（小写分类名 → SF Symbol），手写 `init(from:)` 保证旧文件无此键仍可解码；编辑器调色板 16 图标 + 恢复自动；日视图色块与预览优先取 override。测试 90 → **96 项** | 见 git log |
| **修正** | **三处 UI 重复**（用户指出）：记录行铅笔与 ⋯ 重复 → 只留 ⋯；表头图例删除；编辑器「选择已有标签」与分类菜单内容相同 → 删除前者；另修复所有非命名分类共用同一网格图标的问题（哈希取 10 种 fallback） | 见 git log |
| **功能** | **分类入口清晰化**：`RecordEditor` 始终显示「统计分类」（无分类显示「未分类」），选择器分「已使用的分类和标签」与「建议分类」两组并对已使用者去重，另有自定义分类输入；分类与「其他标签」分区呈现并附说明「统计分类决定图表归属和图标；其他标签用于搜索和筛选。」；选择器带图标+颜色实时预览；日视图提示改为「点击色块，编辑名称、分类和标签。」；`Garden.suggestedCategories` 集中管理（**顺序是 load-bearing，`color()` 按其下标取色**） | 见 git log |
| **P9** | 读盘失败时「重试保存」按钮必然无效 → 改为 `retryStorage()`，读失败重新读盘、写失败重试保存，按钮标题随场景变化；保留 `loadFailed` 防覆盖保护；错误横幅加「打开记录文件夹」；`openRecordsFolder()` 不再覆写既有错误。测试 55 → **61 项** | `e69be32` |
| **P7** | 整体替换上游发布 workflow 为无 secret 的「领域测试 + 构建 smoke check」单 job 流程。**首次真实运行 success，46 秒，61 项全过，通用二进制构建通过，产物 bundle id 断言匹配**。同时证实 `branches: '*'` 不匹配开发分支 | `abf55df` |
| — | `focusDuration()` 此前**零测试**，却被 6 处引用（含 `MainWindow.swift:110` 的 46pt 累计总时长、周/月图悬停提示、分类行、记录行）。补 6 项格式化断言 + 8 项真实数据回归，41 → **55 项** | `8fb1e74` |
| — | 变异检验：注入 3 个错误（`% 60 == 0`→`== 1`、截断→四舍五入、`< 60`→`< 59`），全部被对应断言抓到，源码已还原并 diff 确认一致 | 同上 |
| — | `docs/**/*.png` 加入 `.gitignore`，26 张 16MB QA 截图不进 git；已验证 `tests.txt`、上游 `screenshot.png`、构建必需的 imageset PNG 未被误伤 | 同上 |

`focusDuration()` 位于 `Analytics.swift:80`，已在 `scripts/test.sh` 的编译列表内，补测零基建成本。

> **注意 `scripts/test.sh` 的覆盖边界**：它只编译 `State.swift` + `Log.swift` + `Analytics.swift`，
> 即 9 个 Swift 文件中的 3 个。**改到 App / Timer / View / MainWindow / FocusCharts / Notifications
> 必须另外跑 `scripts/build.sh`**，否则拼写错误不会被发现。现在 CI 两步都跑，但本地要自己记得。

---

## 记录规则

- 新问题追加到对应严重性分区，**必须附 file:line 证据和可独立执行的核验命令**
- **P 编号是问题 ID，不当严重性等级用**（Codex 评审提出）。严重性写在每条的「状态」行里，可随评审调整
- 修完的：把该条**状态行改成 `✅ 已修复 @ <hash>` 并原地补「修复方式」小节**，同时在「已修完」表加一行。
  **不要删除原条目和评审意见** —— 分析过程和被推翻的判断本身就是资产
- 被否决的移到 [`HANDOFF.md`](HANDOFF.md) 的「已否决的方案」并写明理由 —— 不要直接删掉，
  否则后续 AI 会重新提出同一个方案
- **变异检验时必须确认变异真的改变了可观察行为**。「没抓到」可能是变异无效而非测试有洞
  （见 P9 小节里那个只改一处抛错点的失败尝试）
