# HANDOFF.md

**易变层** —— 每次会话结束时更新。稳定约定见 [`../AGENTS.md`](../AGENTS.md)，问题清单见 [`BACKLOG.md`](BACKLOG.md)。

最后更新：2026-09-28，by Claude Code（Opus 5）

---

## 当前状态

| 项 | 值 |
|---|---|
| 已安装版本 | **3.8.0（V1.2）**，`/Applications/TomatoBar Personal.app`，本次会话中构建并安装，已启动运行 |
| HEAD | `8fb1e74`（分支 `feature/personal-focus`） |
| 工作区 | 干净 |
| 测试 | `scripts/test.sh` → **55 项全绿** |
| 远程 | `origin` = `mikilolipop/TomatoBar-Personal`（私有，默认分支 `feature/personal-focus`）；`upstream` = `ivoronin/TomatoBar` |
| 用户真实数据 | 个人版容器内 `sessions.json` 共 **1 条**记录，phase=idle，升级前后完好 |
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

**无代码改动进行中。** 等待 Codex 对 BACKLOG P1–P7 的交叉评审。

用户已决定：**先让 Codex 审这份分析，再决定改不改**。评审材料已写进 [`BACKLOG.md`](BACKLOG.md)，
每条都带 file:line 证据和「如何独立核验」，Codex 无需本会话上下文即可验证。

---

## 下一步

1. **等 Codex 交叉评审 BACKLOG P1–P7**（用户负责把 BACKLOG.md 交给 Codex）
2. 评审回来后，按用户已选定的方案修 **P1 + P2 + P3**：
   - 用户已选 **方案 B**：保留「打开应用即弹主窗口」的 V1.2 设计意图，但要
     (a) 关窗后收回 Dock 图标，(b) 「登录时启动」场景下不弹窗口、不抢焦点
   - P3 是 3 行改动（长休息用 `.longRest` 图标）
   - 预计总量约 10–15 行
3. P4（本地化死文件）、P6（`export_options.plist`、`.swiftlint.yml` 死文件）是清理，可合并成一个提交
4. P7：建议把 `.github/workflows/main.yml` 换成只跑 `scripts/test.sh` 的极简 workflow（无需任何 secret）。**待用户确认**
5. P5（FocusSummary 重复构造）**暂不修** —— 现在只有 1 条记录，属过早优化。但已在 BACKLOG 记录精确复杂度，数据量上来后再处理

### V1.3 候选（尚未规划）

- 往 `scripts/seed-qa.py` 加几段**亚分钟记录**，用于视觉验证 `FocusCharts.tileWidth` 的
  `max(44, …)` 最小宽度分支。该分支在 UI 层，`scripts/test.sh` 编译不进去，**只能靠眼睛看**。
  注意：QA12 沙盒容器还在，但 **QA12 的 .app 本体已不存在**，需先造一个 QA12 bundle ID 的构建变体。

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

## 已否决的方案（**请勿重走**）

| 方案 | 否决理由 |
|---|---|
| 写 `scripts/import-original-log.py` 导入脚本 | 原版 App 已退役，那份 log 冻结在 965 字节 / 10 行，永不增长。为一次性动作留一个需长期维护的脚本是过度工程 —— 直接内联进测试即可 |
| 用 JSON fixture 喂测试 | 违背仓库既有约定（`Tests/main.swift` 全部内联构造 Swift 记录）。会引入文件 IO、解析失败、路径依赖三种新失败模式，换不到好处 |
| 把 V1.0/V1.1/V1.2 拆成三个提交 | 文件是累积修改的，只能靠猜分配 hunk，**那是编造历史**，比一个诚实的快照提交更糟。已在提交信息中说明是 squashed snapshot |
| 只用原版真实数据做测试输入 | 4 段最长 30 分钟，`focusDuration()` 的「小时」两个分支**真实数据永远够不着**。必须补合成值才能全覆盖 |
| 把 16MB QA 截图提交进 git | 永不 diff 的二进制，每次 clone 都要背。已 gitignore，磁盘和 tarball 里有副本 |
| 修改 `design-qa.md` 里的「41 项检查」 | 那是带日期的 V1.2 验收记录，改它等于篡改历史证据。数字过时也保留，V1.3 另写一份 |
| 现在就优化 P5（FocusSummary 重复构造） | 当前只有 1 条记录，属过早优化。已记录精确复杂度，等数据量上来或实测到卡顿再处理 |
| 开启 GitHub Issues 做 backlog | 单人 + 两个 AI，`docs/BACKLOG.md` 随代码走、可 diff、离线可读、不需 API，更简单。仓库建时已设 `has_issues: false` |

---

## 更新本文件的规则

会话结束时改写这几节：**当前状态**（版本号、HEAD、测试数、数据量）、**进行中**、**下一步**、
**刚做完**（追加，写明日期和执行者）、**已否决的方案**（只增不删）。

「刚做完」按会话追加，过旧的可折叠为一行摘要指向 commit hash。**不要删「已否决的方案」** —— 
那是防止后续 AI 重走弯路的核心资产。
