# HANDOFF.md

**易变层** —— 每次会话结束时更新。稳定约定见 [`../AGENTS.md`](../AGENTS.md)，问题清单见 [`BACKLOG.md`](BACKLOG.md)。

最后更新：2026-09-29，by Claude Code · 开源准备：README 重写、封面截图替换、隐私自查；最小窗口 780×620

---

## ⚠️ 做 UI 自动化前必读：同名进程陷阱

本机可能同时存在**多个进程名都是 `TomatoBar Personal`** 的实例（正式版 + QA 变体）。
此时 **System Events 的进程定位完全不可靠**，本轮实测：

```
first process whose bundle identifier is "…QA13"    →  返回 pid 17294（正式版！）
first process whose unix id is 40847（QA13 的 pid）  →  读到的 bid 是 com.dilyar.TomatoBarPersonal（正式版的！）
```

即：**按 bundle id 过滤会串到按名字匹配的第一个进程；连按 pid 定位后读属性也会串。**
本轮曾因此在不知情的情况下读到正式版界面（`2 段 / 9分钟 / 旧提示文案`），
**若再往下点一次「删除记录」，删掉的就是用户真实数据。**

**规则**：

1. UI 自动化前**必须先确认只有一个同名进程**，或先退出正式版
2. 每次交互前**读回界面文本做身份核验** —— QA 数据与正式版数据必须能一眼区分
   （本轮：QA13 = 6 段/1小时55分/新提示文案；正式版 = 2 段/9分钟/旧提示文案）。
   看到意料之外的数值立刻停手
3. 操作真实用户数据前先做快照（本轮：`TomatoBarBuildBackups/sessions-prod-before-UIQA-*.json`）
4. 更彻底的做法是让 QA 变体**进程名也不同**。本轮试过 `PRODUCT_NAME="TomatoBar QA13"`，
   与 LaunchAtLogin 的登录辅助 bundle 冲突（`Multiple commands produce …TomatoBar QA13.bundle`），**未解决**

另：本机**没有屏幕录制权限**，`screencapture` 报 `could not create image from display`，
所以视觉验收做不了，只能靠辅助功能树 + 落盘数据比对。

---

## 当前状态

| 项 | 值 |
|---|---|
| ✅ **已安装版本** | **3.9.0（V1.3）**，`/Applications/TomatoBar Personal.app`，本次会话构建、签名校验、安装、启动，正在运行 |
| HEAD | `4b3bd52`（最小尺寸验证记录）← `03bcb52`（contentMinSize 顺序修复）← `d6fc9bb` ← `6ff1819`（定版 V1.3） |
| 工作区 | 本轮最小尺寸第二轮修复（delegate 兜底）另起提交；已安装版本与 HEAD 一致 |
| 测试 | **153 项领域 + 12 项真实桥接 + 8 项合成启动事件**通过；Release clean build 与严格签名校验通过（V1.3 定版时复跑确认） |
| **CI** | `tests` workflow 已由前轮启用；本轮交付以本地检查为证，未将旧 CI 结果当本轮结果 |
| 远程 | `origin` = `mikilolipop/TomatoBar-Personal`（私有，默认分支 `feature/personal-focus`）；`upstream` = `ivoronin/TomatoBar` |
| 用户真实数据 | 前轮记载 2 条；**本轮未读取、未写入正式容器，也未退出正式应用**，不把旧数据量当作当前复查结果 |
| QA 隔离环境 | 旧 QA13 app 未重建启动；本轮桥接检查只在 QA13 的新建 review-UUID 子目录做合成 IO，完成后清理该子目录；既有 QA13 sessions 未改 |
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

**V1.3 已定版并安装**（`6ff1819`，内部版本 3.9.0，见 [`V1.3更新说明.md`](V1.3更新说明.md)）。
用户明确要求：这一版先把已经做完的功能定稿装上用，剩余问题不在本轮范围内解决。

分类视觉方案在 [`分类视觉设计.md`](分类视觉设计.md)，**设计已定稿，代码尚未按新格式实现**
（当前仍是纯 SF Symbol 字符串，兼容规则见设计文档）。
P1/P2/P8 的候选补丁在仓库里但**尚未合入生效路径**，需要真人按 [`V1.3验收清单.md`](V1.3验收清单.md)
在真实登录场景验收后才能启用，V1.3 定版明确不含这部分行为变化。

| 条目 | 当前状态 |
|---|---|
| 解码兼容性 | 同意现有实现；独立合成旧结构 oracle + 可选日期/必需字段/嵌套 tags 等 42 项新增断言通过 |
| 删除 | 真实 TBTimer 成功、重复调用、写失败、history 发布已测；alert 键盘默认/外部关闭/连点的实际 UI 序列未测 |
| **P12** | ✅ **已修复**（`996cdf8`）：落盘按规范标签重写键 + 解析别名回退 |
| **P13** | ✅ **已修复**（`996cdf8`）：样式改为 delta 合并提交，不再整图覆盖 |
| **P14** | ✅ **已修复**（`996cdf8`）：判定谓词移入 `FocusState.categoryFilterStillMatches`，两种语义进领域测试 |
| **P15** | **新增未修**：概览分类筛选按钮在辅助功能树里没有任何名称，是 P14 实机复验受阻的直接原因；也是 V1.2 就存在的无障碍债 |
| P1 + P2 + P8 | **候选补丁在仓库但按用户决定暂不启用**：同步捕获登录标记、初始主窗口/恢复提醒同时静默、真正关闭主窗口才降级 accessory。需要真人登录验收后才会接入 V1.4 或热修 |
| P10 / P11 | popover 删除入口、VoiceOver 体验、Return/Esc 键盘实测、恢复自动图标 —— **仍未真人验证**，V1.3 不声称这些通过 |
| P3 / P4 / P5 / P6 | 沿用此前决定，未动；P3（长休息图标）作为已知问题写入 V1.3 更新说明 |

## 下一步（V1.3 定版之后）

V1.3 已按用户决定定稿上线，不再往这个版本里加东西。后续事项按优先级：

1. **真人跑一遍 V1.3 验收清单**（`docs/V1.3验收清单.md`）：开「登录时启动」→ 登出登入
   验证候选补丁；关窗看 Dock 图标；顺手验 popover 删除入口（P10）和恢复自动图标。
   **候选补丁目前不在生效路径上**，验收通过后才决定是否接入下一版（V1.3.x 或 V1.4）。
2. **P15**：给概览分类筛选按钮补 `.accessibilityLabel`，一并处理 P11（同属无障碍债，
   都是加一行 label 的事，可以合并一个提交修完）。
3. 分类视觉像素素材：由 Codex 按设计文档交付，届时才需要真正改代码接像素资源。
4. P3（长休息图标）、P4/P5/P6：维持"暂不修"，没有新证据不重新评估。
5. V1.3 若之后有小的稳定性修复，可以直接在 3.9.x 补丁版本里出，不必等下一个大版本。

### 视觉验证遗留项（V1.3 未覆盖）

- 往 `scripts/seed-qa.py` 加几段**亚分钟记录**，用于视觉验证 `FocusCharts.tileWidth` 的
  `max(44, …)` 最小宽度分支。该分支在 UI 层，`scripts/test.sh` 编译不进去，**只能靠眼睛看**。
  注意：QA12 沙盒容器还在，但 **QA12 的 .app 本体已不存在**，需先造一个 QA12 bundle ID 的构建变体；
  QA13 已经在本轮建过并可用（见「QA13 复现方式」），不必复用 QA12。

---

---

## 刚做完（2026-09-29，Claude Code 发布 V1.3 GitHub Release + 下载包）

- **universal 构建**：`ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO` 另跑一次 Release 构建
  （`/tmp/TomatoBar-universal-build`），lipo 确认双架构、`--deep --strict` 签名通过。
  项目默认 `scripts/build.sh` 只出 arm64，**尚未把 universal 参数并进 build.sh**（待定夺）
- **打包**：`/tmp/TomatoBarPersonal-3.9.0.dmg`（hdiutil UDZO，含 Applications 拖拽位，
  CRC 校验 + 挂载实测）与 `.zip`（ditto 保元数据），SHA-256 见 Release 正文
- **tag `v3.9.0`**：沿用上游内部版本号命名（上游历史 tag 占用了 v1.x–v3.6.1，
  `v1.3` 会撞名）；对外标题 `TomatoBar Personal V1.3 (3.9.0)`
- **GitHub Release 已创建**：挂 dmg + zip 双附件，正文含下载表、Gatekeeper 处理、
  校验和、本版新增/长期特性/质量/已知未修；README 头部加「下载 V1.3」徽章、
  安装一节改为 Releases 优先 + 源码构建保留
- 版本对外 V1.3 / 内部 3.9.0 双轨并写在 Release 与 README，避免后续混淆

---

## 刚做完（2026-09-29，Claude Code 开源准备：README 重写 + 封面截图替换）

用户计划公开此仓库，要求美化 GitHub 侧内容。

- **README.md 全部重写**为个人 fork 定位（中文、开源仓库口吻）：徽章（CI/macOS 12.3+/Swift/MIT）、
  功能一览、版本表（V1.0=3.7.0、V1.1=**3.7.1**、V1.2=3.8.0、V1.3=3.9.0，已逐一对照更新说明核实）、
  源码构建与 Gatekeeper 说明、开发入口、`tomatobar-personal://startStop`、上游 MIT 致谢
- **删除了"TomatoBar.log 事件日志"段落**——grep 确认个人版源码里不存在该写入，这是上游描述，不可照搬
- **根目录 `screenshot.png` 由上游旧界面（带 Sounds 页）替换为个人版 V1.3 概览空态截图**
  （用户提供，2502×1878，零记录零时长，无个人信息）
- 开源前隐私自查：无 secrets（`DEVELOPMENT_TEAM` 为空、CI 不用密钥）；
  QA 截图与备份图在 `.gitignore` 内不会发布；历史提交仅含 noreply 公开邮箱；
  `export_options.plist` 无账号信息；`main` 分支为冻结上游基线
- **GitHub 元信息已用 gh CLI 直接设置完成**（会话后半段从 Releases 装了 gh 2.101.0 到 `~/bin/gh`，
  复用钥匙串里已有的登录态，token scopes 含 repo）：
  Description（中英双语）、10 个 topics 均已生效；
  仓库**不是 GitHub fork**（无父仓库横幅），默认分支已是 `feature/personal-focus`
- **社交预览图无法用 API 设置**（`/social_preview` 端点 404，属网页专属）：
  已生成 1200×630 成品在 `/tmp/og.png`（完整窗口+白边），待用户在
  Settings → General → Social preview 手工上传
- **未转 public**——发布开关留给用户

## 给用户的设置建议（GitHub 网页 Settings → General）

- ~~Description、Topics~~ 已通过 gh CLI 设置完成
- Social preview：上传 `/tmp/og.png`（已生成，1200×630）；若 /tmp 被清，
  可用 `sips -z 610 813 screenshot.png --out /tmp/og2.png && sips --padToHeightWidth 630 1200 --padColor FFFFFF /tmp/og2.png --out /tmp/og.png` 重新生成
- 转 public 前建议：打 `v1.3` tag 并在 GitHub Releases 附上 .app（用户决定中）
- gh 装在 `~/bin/gh`，不在默认 PATH；要用可直接 `~/bin/gh …`，或在 `~/.zshrc` 加 `export PATH="$HOME/bin:$PATH"`

---

## 刚做完（2026-09-29，Claude Code 修主窗口最小尺寸失效）

用户报告：主窗口缩小到某个尺寸以下后内容不再自适应，而是被裁切（番茄图标被切一半）。

**根因**：`App.swift` `showMainWindow()` 里 `contentMinSize = 920×740` 设在
`window.contentViewController = hosting` **之前**，而赋值 `contentViewController` 会用
视图控制器自己的最小尺寸覆盖窗口 `contentMinSize`；又因 `hosting.sizingOptions = []`
禁掉了尺寸传播，覆盖后最小尺寸≈0，920×740 从未生效。窗口因此能缩到 SwiftUI 布局地板
（约 900pt 宽）以下，此时定宽内容无法压缩，只能居中溢出被裁。

**修复**：把 `window.contentMinSize` 移到 `contentViewController` 赋值之后重新设置，
并加注释说明该 AppKit 陷阱（代码里已有防回归注释）。`scripts/test.sh` 153 项全绿。

**验证**：新构建已安装并运行（替换 3.9.0 旧产物）。实测把 autosave frame 写成 500×400，
重启后恢复被钳制为 920×772（内容 920×740 + 标题栏），且正常写回 autosave。
注意：System Events 的 AX 强制 resize 会绕过 minSize（曾污染 autosave 为 600×714，已恢复），
不能用它测试最小尺寸；拖拽路径与 frame 恢复共用同一 clamp 逻辑，以此为准。

### 第二轮：上一段的结论不完整，仍有路径能绕过

用户复现后反馈"依旧会有"，实测窗口被拖到 **368×415**，内容照样被裁。

**上一轮的判断哪里错了**：`contentMinSize` 只约束**用户拖拽边缘**和**frame 恢复**两条路径。
把窗口缩小到 368×415 走的是另一条路（第三方贴边工具、macOS 的窗口磁贴、
或任何直接 `setFrame` 的调用方），这类路径**根本不受 `contentMinSize` 约束**，
所以我上一轮"拖拽与恢复共用同一 clamp"的结论虽然成立，却漏掉了这个更大的入口。

**第二处修复**（`App.swift`）：把尺寸地板从"依赖 AppKit 约束"改为"delegate 主动兜住"。
`windowWillResize` 钳制将要应用的新尺寸，`windowDidResize` 在窗口已经被改小之后
再纠回地板；地板值统一走 `mainWindowMinContent` 常量。全屏/Split View 直接放行
（那种尺寸归系统管，硬抢会来回抖动）。

**验证**：对运行中的实例做 AX 强制 `set size {500,400}`，窗口被自动纠回
**920×772**，autosave 同步写为 `320 75 920 772`。`scripts/test.sh` 153 项全绿，
Release 构建 + 严格签名通过，已安装运行。

**仍未做**：没能在本机确定到底是哪个缩窗入口（用户是手动拖的还是用了贴边工具），
所以无法断言 delegate 之外没有别的漏口；现在的兜底是事后的，窗口会有一帧被裁再纠回。
若用户后续报告仍会裁切，需要先问清缩窗方式再排查。

### 第三轮：用户嫌最小窗口太大，下调为 780×620

用户确认兜底生效（强制缩窗会被弹回），但要求最小尺寸再小一点。

- `mainWindowMinContent` 920×740 → **780×620**（`App.swift:25` 单点常量）
- 图表行 `.frame(height: 280)` → `.frame(minHeight: 170, idealHeight: 280, maxHeight: 280)`，
  FocusChart 本身三个视图全是 GeometryReader 自适应（日=可滚动、周=柱高随高度、月=格高钳制），
  摘要面板固定 340 + 间距 36 后图表仍拿 ~300pt；纵向固定件合计 + 170 图表 ≈ 620，成立
- 实测：强制 `set size 500×400` → 弹回 **780×652**（=620 内容 + 32 标题栏），写回 autosave

**新的工具认知（重要，影响以后所有 UI 自动化）**：
主窗口的 SwiftUI 内容在 System Events 里只暴露成**一个不透明 AXGroup**（=内容区本身），
`entire contents` 递归计数为 0，枚举不到内部按钮/文本。所以"AX 扫描无溢出"只能证明
容器级不越界，**内容级视觉验收仍然只能人眼**（与本文顶部"没有屏幕录制权限"一致）。
本轮内部是否裁切未获机检证据，待用户目测；若用户报"周/月视图在最小尺寸下挤坏了"，
优先怀疑对象是图表行 minHeight 170 的压缩下限与月份网格 `cellHeight` 钳制。

---

## 刚做完（2026-09-29，Claude Code 定版 V1.3）

用户决定：先把做完的功能定稿成能用的版本，剩余问题（P1/P2/P8 候选补丁、P3、P10/P11/P15）
不在本轮范围内解决，也不阻断定版。

- `MARKETING_VERSION` 3.8.0 → **3.9.0**（`project.pbxproj` 两处）；`MainWindow.swift`
  设置面板底部版本标签同步改为 `Personal · V1.3`
- 新增 `docs/V1.3更新说明.md`：本版新增功能（删除记录、分类入口、分类图标可选、
  存储读盘恢复、记录行精简）、统计口径、数据兼容性、**以及明确列出本版未修的已知问题**
  （不粉饰成"全部完成"）
- `README.md` 顶部加 V1.3 引导条
- 复跑 `scripts/test.sh`（153 项）、`scripts/build.sh`（Release clean build + 严格签名）通过
- **构建产物安装到 `/Applications`，已启动**（版本 3.9.0，安装前后均校验签名）
- 提交 `6ff1819`，推送 `origin/feature/personal-focus`
- 本次定版**没有动真实用户数据**，没有新增或修改代码逻辑（只改版本号和文档），
  P12/P13/P14 的实际修复在上一个提交 `996cdf8` 里，此处不重复计入

---

## 刚做完（2026-09-29，Codex 第二轮）

- 逐文件复核 State / Log / Analytics / Timer / View / MainWindow / FocusCharts / App / Notifications。
- 解码实现与普通 ASCII 样式规范化通过；3 个遗漏以 P12–P14 写回 BACKLOG，附可独立运行的合成探针。
- 保留已验证的删除/分类生产逻辑；未因静态疑虑重写 RecordEditor 或持久化格式。
- tests 96 → **138**；新增 `test-bridge.sh` **12 项**，链接真实 SwiftPM 依赖与 UI/桥接源码，仅把 @main 入口移除以运行检查。
  无 Mock TBTimer；验证写失败不丢内存、重复删除不误删、图标单独修改仍发 history 通知。没有 UI 点击。
- 先写 `docs/V1.3验收清单.md`，再实施 App.swift + LaunchContext.swift 的 P1/P2/P8 候选补丁。
  新增 `test-launch-context.sh` **8 项**；同步观察 willFinish/didFinish，已确认的登录标记不被后续 nil 覆盖。
- `scripts/build.sh` clean Release 成功，严格签名检查通过；未安装、未重启正式应用、未登记 QA 登录项。
- `docs/分类视觉设计.md`：保留 categoryStyles 字符串，另增可选 categoryVisuals、资源/旧值/自动回退、增量提交与无脚本兼容。
- 未完成：真人登录、Dock/UI 焦点、Return/Esc、popover、VoiceOver、最大文字/小窗滚动、图标恢复自动。
  编译真实视图做离屏缓存时有文字缺失，舍弃该结果，不写成视觉验收通过。
- 没有翻案或重提已否决方案。仅纠正 AGENTS 对“SwiftUI 不能用 swiftc 测”的过强表述：可以链接依赖测桥接，仍不能据此声称 UI 已验收。

---

## 刚做完（2026-09-29，Claude Code 修 Codex 评审发现的 P12–P14）

Codex 评审（`a9939b5`）抓出我上一轮代码里三个已复现的 bug，全部成立，已修：

- **P12 Unicode 图标失配**：`caseInsensitiveCompare`（标签规范化）与 `lowercased()`
  （样式键）是两套不等价的等价关系，`Straße`/`STRASSE` 比较相等但折叠不同，
  导致从草稿拼写写入的覆盖在标签被规范化后查不到。修：落盘时按规范名重写键 +
  解析时别名回退（`FocusState.styleSymbol`）。
- **P13 双编辑器整图覆盖**：编辑器打开时抓全量样式快照、保存时整张提交，
  两个入口（主窗口 sheet / 菜单栏 popover）同时存在时后保存者抹掉先保存者。
  修：只提交 delta（`[String: String?]`，nil=移除），服务端合并。
- **P14 概览筛选残留**：清理失效筛选用 `hasTag`，但概览按**首标签**筛选；
  最后一条主分类记录被改分类后，旧标签作为次标签仍在 → 筛选不清除 → 概览空列表。
  修：谓词移入 `FocusState.categoryFilterStillMatches(_:primaryOnly:)` 并入领域测试。

测试 96 → **153**。四个变异（删别名回退／删规范名重写／整表清空代替合并／概览误用
hasTag）全部被抓。

**P14 的实机复验失败两次后放弃，原因值得记录**：概览分类筛选按钮在辅助功能树中
**没有任何名称**（P15，V1.2 既有缺陷），自动化无法按名定位，只能靠位置猜，
两次「验证通过」都是前置条件没成立的空转（筛选根本没生效就断言行数）。
发现方法是**先断言前置条件**（筛选后行数应为 1），不满足就中止 —— 否则会报告一个
假的 ✅。谓词改入领域层后，这个 bug 的正确性不再依赖 UI 自动化。

键盘行为实测矩阵见 BACKLOG：`.cancelAction` 下 Esc=取消、Return 无反应；
`.defaultAction` 下 Return=取消、Esc 无反应。保留 `.cancelAction`。
之前「destructive 保证不是默认按钮」的说法已纠正为实测结论。

**用户已在生产环境亲手验证删除功能**：那条 1 秒误触记录在 09:54→10:36 之间
通过新版 UI 被删除（快照比对确认），非数据丢失。

Codex 本轮另交付：任务二设计说明 `docs/分类视觉设计.md`（保留 SF Symbol 字符串、
另加可选像素描述、旧值兼容与回退）；任务三 P1+P2+P8 候选补丁
（`TomatoBar/LaunchContext.swift`、`App.swift` 改动）与 `docs/V1.3验收清单.md`。
**候选补丁尚未实机验收**：真实登录、Dock/焦点交互需用户按清单执行。

---

## 刚做完（2026-09-29，Claude Code 修三处 UI 重复 + 分类图标可手动选）

用户对上一轮的界面提出两处实质批评，均成立，均为我照规格逐字实现、没有发现规格条目在
同一界面上互相冲突所致：

1. **记录行铅笔与 ⋯ 菜单功能重复**，且表头还写了一句图例「铅笔编辑，⋯ 可删除」。
   → 删掉铅笔，⋯ 菜单保留「编辑记录／删除记录」；表头只留「按时间顺序」。
   用户已确认此形态（选项「只留 ⋯ 菜单」）。
2. **编辑器里两个下拉内容完全相同**：分类菜单的「已使用的分类和标签」组
   与「选择已有标签」菜单都列 `availableTags`。
   → 删掉「选择已有标签」。想复用已有标签作为次标签，直接在输入框键入即可，
   `normalizedTags` 会按大小写不敏感归一到既有写法。
3. **顺带发现的第三个问题**：截图里三块日视图色块图标完全相同 ——
   `Garden.symbol` 只认 7 个硬编码名字，其余一律落到同一个网格图标，
   预览和色块因此毫无信息量。→ 未命名的分类改为按名字哈希取 10 个不同的
   fallback 图标（与颜色共用同一个 FNV-1a），七个命名分类和「未分类」不变。

**新需求：分类图标可手动选**（用户在「自动派生 / 手动选图标 / 图标+颜色都可选」中
选了中间项）。实现：

- `FocusState.categoryStyles: [String: String]`，键为小写分类名，值为 SF Symbol 名。
  是**展示元数据**，不是平行分类字段 —— 首标签规则不变
- **向后兼容是承重墙**：旧 sessions.json 没有这个键，合成 Codable 解码会把缺键当失败，
  而本应用把解码失败表现为「文件损坏并锁死全部计时」。因此 `FocusState` 手写
  `init(from:)`，新键用 `decodeIfPresent`。测试会剥掉该键后断言仍能解码；
  把 `decodeIfPresent` 换成 `decode` 的变异会以**正是那个会锁死应用的 keyNotFound** 失败
- 声明该 init 会抑制隐式成员初始化器，首次构建即让所有 `FocusState()` 调用点报错。
  已补显式 `init()` 并加注释 —— 这类东西下次改动很容易再悄悄弄坏
- `editRecord` 的 `categoryStyles` 参数默认为 nil：改名改标签不碰 override；
  编辑器在**同一次原子写入**里提交图标选择，取消则一并丢弃
- 测试 90 → **96**

UI 验收（QA13 实机）：调色板列出 16 个带中文名的图标 + 「恢复自动图标」；
给「材料力学」选「星星」→ 落盘 `categoryStyles = {"材料力学": "star"}`；重启后仍在；
**正式版那份完全没有 categoryStyles 键的 sessions.json 在新构建下正常加载运行**。

未验证：「恢复自动图标」的点击本身 —— 调色板菜单在辅助功能控制下打不开
（与 P10 同一类 SwiftUI 引用失效），那一行 `removeValue` 记为未验证，见 BACKLOG P10。

---

## 刚做完（2026-09-28，Claude Code 实施「删除记录」+「分类入口清晰化」）

### 代码改动

**领域层（可测）**
- `FocusState.deleteRecord(id:)`：按 UUID 删除，**只动 `records`** —— 计时、暂停、轮次、
  休息安排不受影响是结构性保证，不靠事后恢复
- `FocusRecord.tags(withPrimaryCategory:in:)`：切换分类 = 把选中标签移到首位，其余保留并按
  大小写不敏感去重。**空分类是 no-op 而不是清空标签** —— 「未分类」只是空标签列表的显示形态，
  不作为可选项提供，因为清空全部标签会摧毁这个方法要保护的其他标签

**桥接层**
- `TBTimer.deleteRecord(id:)`：镜像 `editRecord` 的**先落盘成功再更新内存**。
  保存失败时**故意不设 `storageError`** —— 因为 `state` 只在写成功后才赋值，内存与磁盘仍然一致、
  没有未保存内容；设了会让 `hasUnsavedChanges` 变真并因一次没发生的删除阻止退出

**UI 层**
- `RecordEditor` 重写：`onDelete` 闭包、红色「删除记录」+ 确认弹窗（`role: .destructive`
  使其不为默认按钮，Esc 绑定取消）、**始终显示**的「统计分类」区（含图标+颜色实时预览、
  已使用/建议两组去重菜单、自定义分类输入）、「其他标签」区、说明文案
- **主标签刻意不出现在「其他标签」的可移除列表里** —— 否则移除操作会静默改变统计归属
- 主窗口记录行加 ⋯ 菜单（编辑记录／删除记录），**保留铅笔入口**
- 两处删除路径共用 `RecordEditor.confirmationMessage(for:)`，文案不会分叉
- `Garden.suggestedCategories` 集中管理建议分类，`color()` 改用它（**顺序 load-bearing**）
- 日视图提示改为「点击色块，编辑名称、分类和标签。」；记录区提示改为「铅笔编辑，⋯ 可删除」
- 编辑器改为 ScrollView + 固定底栏；popover 标签区 270→320pt、sheet 350→430pt
  （新增内容所需，**这是本轮唯一的既有布局尺寸调整**）

**未做**（按规格）：批量删除、回收站、整库清空、像素插画、素材生成依赖、完整的图案/颜色自定义管理器。
未动 P1–P7。

### 测试

61 → **90 项**。新增覆盖：按 UUID 删除且顺序不变、未知 ID 抛 `missingRecord` 且列表不变、
删除后统计正确、分类随最后一条记录消失、删除跨 save/load 持久、
**删除不改变 phase/paused/rounds/remaining/deadline/name/segmentStart/startedAt**、
复制体变更不影响原体（这是「先落盘再更新内存」安全的根据）、不可写目标确实抛错、
分类切换的首标签规则 8 种情形、`category` 取首标签与空标签显示「未分类」。

变异检验 6 个，**全部被对应断言抓到**：按下标 0 删除、顺手清零 rounds、
不去重、追加到末尾而非首位、大小写敏感去重、空分类清空全部标签。
其中两个 perl 变异**注入失败**（转义问题），已改用 python 字面替换重做 —— 未把注入失败当成「没抓到」。

### 隔离环境 UI 验收（QA13，实机操作，非静态分析）

环境：`PRODUCT_BUNDLE_IDENTIFIER=com.dilyar.TomatoBarPersonal.QA13` 单独构建，
容器与正式版完全隔离；灌入 6 条合成数据（含 45 秒无标签记录、1 条提前结束记录、6 个分类）。
**验收前已快照正式版 sessions.json，验收后逐条比对：ID／名称／标签／时长／完成状态全部一致。**

已验证 ✅

| 项 | 实测结果 |
|---|---|
| ⋯ 菜单 | 菜单项为 `[编辑记录] [删除记录]`，6 行各有一个 menu button |
| 确认弹窗文案 | `删除这段专注记录？`／`「建模作业」`／`2026年9月28日 11:00 · 专注 20分钟`／`删除后，这段专注时长将从统计中移除。` —— 名称、日期、时长、说明齐全 |
| 取消路径 | 弹窗关闭、数据仍 6 条、`建模作业` 仍在、界面仍 `6 段 / 1小时55分` |
| 真删除 | 数据 6→5、`建模作业` 移除、剩余 5745 秒 |
| 统计即时刷新 | **无需重启**，界面立即变 `5 段 / 1小时35分`（两处「段」计数同步） |
| 分类联动 | 删除后 `建模` 从「已使用」消失并回落到「建议分类」组，证明 `allTags` 已更新 |
| 分类选择器分组 | `已使用的分类和标签`：材料力学/数学/学习/英语/阅读；`建议分类`：建模/编程/写作 —— **已使用者被去重排除** |
| 统计分类始终可见 | 无标签记录 `误触测试` 的选择器 `name = [未分类]`（规格二.1） |
| 说明文案 | `统计分类决定图表归属和图标；其他标签用于搜索和筛选。` 逐字一致（规格二.4） |
| 分区呈现 | `统计分类` 与 `其他标签` 为两个独立小节，各有标题（规格二.4） |
| 首标签规则（UI 端到端） | `英语听力` 原 `['英语','学习']`：切换前其他标签区只显示 `[学习]`（**主标签不在可移除列表**）→ 选 `学习` → 分类变 `学习`、其他标签区变 `[英语]`（**旧首标签降级保留未丢失**）→ 保存 → 落盘 `['学习','英语']` ✅ |
| 自定义/建议分类落盘 | `误触测试` 选 `编程` → 落盘 `tags=['编程']` |
| 重启持久化 | 重启 QA13 后仍 `5 段 / 1小时35分`，`建模作业` 不存在，行2 显示 `学习 · 英语`，行4 显示 `编程` |
| 秒级与未分类渲染 | 行5 `误触测试 ¦ 未分类 ¦ 45秒`（`focusDuration` 的 `<60` 分支）；行6 显示 `提前结束` |
| 小时分支渲染 | 汇总 `1小时55分` → 删除后 `1小时35分`，**`focusDuration` 的小时分支首次在真实 UI 中确认** |
| 新提示文案 | `每一块是一段专注，按时间排列。点击色块，编辑名称、分类和标签。` 与 `按时间顺序 · 铅笔编辑，⋯ 可删除` 均正确渲染 |

未验证 ❌（**不要把上面的通过当成全部通过**）

- **P10 菜单栏 popover 的删除入口**：状态栏项只支持 `AXPress`，执行后 popover 不出现；
  按实测坐标 `click at {876,16}` 同样无效。popover 用的是同一个 `RecordEditor`，
  特有代码只有 4 行 `onDelete` 闭包且已编译通过，但**没有实机点过**
- **P11 分类选择器的 VoiceOver 读屏结果**：`description = [向下移动]`（chevron 图标）
  覆盖了我的 `accessibilityLabel`，且 AX `name` 在不同时刻分别读到 `未分类` 和 `统计分类：英语`，
  **不稳定**。无读屏环境，无法判断实际体验
- **视觉层面全部未验证**：本机无屏幕录制权限，`screencapture` 失败。
  图标+颜色预览是否真的渲染、布局是否拥挤、popover 320pt 与 sheet 430pt 是否合适，
  **全部只验证了辅助功能树结构和落盘数据，没有看过一眼**
- 删除失败路径（磁盘写失败时的错误提示）未做 UI 复现，只有领域层测试

### QA13 复现方式

```sh
xcodebuild -project TomatoBar.xcodeproj -scheme TomatoBar -configuration Release \
  -derivedDataPath /tmp/TomatoBar-QA13-build \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  PRODUCT_BUNDLE_IDENTIFIER=com.dilyar.TomatoBarPersonal.QA13 ONLY_ACTIVE_ARCH=NO build
# 数据路径：~/Library/Containers/com.dilyar.TomatoBarPersonal.QA13/Data/Library/Application Support/TomatoBarPersonal/sessions.json
```

**不要覆盖 `PRODUCT_NAME`** —— 会与 LaunchAtLogin 的登录辅助 bundle 冲突。

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
| 用 System Events 的 `bundle identifier` 或 `unix id` 定位同名进程 | **会静默串到错误进程**，实测 `whose bundle identifier is "…QA13"` 返回正式版 pid，连按 QA13 的 pid 定位后读 `bundle identifier` 也返回正式版的值。做 UI 自动化前必须只剩一个同名进程，且每次交互前读回界面文本核验身份。详见本文件顶部「同名进程陷阱」 |
| 覆盖 `PRODUCT_NAME` 来造 QA 变体 | 与 LaunchAtLogin 的登录辅助 bundle 冲突：`Multiple commands produce …TomatoBar QA13.bundle`。只覆盖 `PRODUCT_BUNDLE_IDENTIFIER` 即可隔离容器，但进程名会相同（见上一条） |
| 把「其他标签」列表显示为全部标签（含主标签） | 移除主标签会让 `tags[1]` 顶上来成为新分类，**静默改变统计归属**，正是规格明确禁止的。主标签只能通过「统计分类」选择器更换 |
| 把「未分类」做成分类选择器里的一个可选项 | 要让记录变成未分类就得清空全部标签，那会摧毁其他标签。它只是空标签列表的显示形态，不是可选值 |

---

## 更新本文件的规则

会话结束时改写这几节：**当前状态**（版本号、HEAD、测试数、数据量）、**进行中**、**下一步**、
**刚做完**（追加，写明日期和执行者）、**已否决的方案**（只增不删）。

「刚做完」按会话追加，过旧的可折叠为一行摘要指向 commit hash。**不要删「已否决的方案」** —— 
那是防止后续 AI 重走弯路的核心资产。
