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

---

## 严重性定义

| 级别 | 含义 |
|---|---|
| 🔴 P1/P2 | 影响日常使用，或用户一开启某开关就会踩到 |
| 🟡 P3–P5 | 行为不符预期或规模化隐患，当前无感 |
| ⚪ P6/P7 | 卫生问题，不影响功能 |

---

## 🔴 P1 — 「登录时启动」会导致每次登录弹大窗口并抢焦点

**状态**：待评审 · **潜伏中**（该开关目前是关的，所以现在还不会发生）

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

---

## 🔴 P2 — `LSUIElement = YES` 与 `setActivationPolicy(.regular)` 矛盾，Dock 图标永久残留

**状态**：待评审 · **当前即可复现**

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

---

## ⚪ P7 — CI workflow 是上游的，缺 secret 会失败

**状态**：待评审 · 已建议方案，待用户确认

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

---

## 已修完（本次会话）

| 项 | 内容 | 提交 |
|---|---|---|
| — | `focusDuration()` 此前**零测试**，却被 6 处引用（含 `MainWindow.swift:110` 的 46pt 累计总时长、周/月图悬停提示、分类行、记录行）。补 6 项格式化断言 + 8 项真实数据回归，41 → **55 项** | `8fb1e74` |
| — | 变异检验：注入 3 个错误（`% 60 == 0`→`== 1`、截断→四舍五入、`< 60`→`< 59`），全部被对应断言抓到，源码已还原并 diff 确认一致 | 同上 |
| — | `docs/**/*.png` 加入 `.gitignore`，26 张 16MB QA 截图不进 git；已验证 `tests.txt`、上游 `screenshot.png`、构建必需的 imageset PNG 未被误伤 | 同上 |

`focusDuration()` 位于 `Analytics.swift:80`，已在 `scripts/test.sh` 的编译列表内，补测零基建成本。

---

## 记录规则

- 新问题追加到对应严重性分区，**必须附 file:line 证据和可独立执行的核验命令**
- 修完的移到「已修完」，注明 commit hash
- 被否决的移到 [`HANDOFF.md`](HANDOFF.md) 的「已否决的方案」并写明理由 —— 不要直接删掉，
  否则后续 AI 会重新提出同一个方案
