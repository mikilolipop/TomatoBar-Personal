# TomatoBar Personal · Windows

完全无声的本地番茄钟。Windows 客户端使用 React 19、TypeScript、Tauri 2；macOS 原生客户端位于仓库的 `TomatoBar/`，两端通过 `sessions.json` 手动交换记录。

## 开发与检查

```sh
npm ci
npm run dev                 # 独立浏览器预览，使用浏览器存储
npm run check               # 零警告 lint、回归检查、TypeScript 与生产前端构建
npm run format:check
npm run tauri dev           # 原生客户端；需要 Rust 与平台开发工具
npm run tauri build         # Windows 生成 NSIS .exe 与 WiX .msi
```

原生检查在 `src-tauri/` 运行：

```sh
cargo fmt --check
cargo test --locked
cargo clippy --locked --all-targets -- -D warnings
```

在 Mac 上另运行 `npm run test:interop`：它使用合成数据、真实 Swift 领域源文件与临时目录，检查 TypeScript → Swift → TypeScript 的实际兼容性。需要 Node、Xcode 命令行工具；不访问真实用户记录，不属于 Windows 必跑项。

## 代码边界

| 目录 | 职责 |
| --- | --- |
| `src/core/` | 显式时钟的计时状态机、记录/待办/大任务、日历统计、设置、数据格式与存储接口 |
| `src/application/` | 单一写入队列；先保存再发布；5 秒 checkpoint；错误阻断、重试、导入与退出事务 |
| `src/platform/` | 唯一依赖 Tauri 的适配器；浏览器预览与原生数据隔离 |
| `src/hooks/` | React 外部状态订阅、浏览器计时与原生脉冲订阅及清理 |
| `src/components/` | 展示和输入；通用原生 dialog、任务树、图表、记录编辑与计时器 |
| `src-tauri/src/` | 固定文件路径的原子读写、单实例、系统托盘、窗口生命周期与无声提醒 |

`App.tsx` 负责组装导航和弹窗，不直接写存储，也不在 React 状态更新器中执行提醒。

## 计时和数据行为

- 工作、休息只能按合法阶段切换。暂停关闭专注片段；恢复建立新片段；延迟完成以 deadline 封顶。
- 重启和大于 10 秒的计时脉冲间隔恢复为「暂停在已保存 checkpoint」；离线或睡眠间隔不计入专注。正常异常退出最多少记约 5 秒，保存失败时以界面的错误状态为准。
- 「结束并记录」保留短时段及长时段；「取消专注」不生成记录。跳过休息保留本组轮数，等待显式开始下一轮。
- 第一个标签用于统计。子任务可继承大任务标签，完成记录保存任务和项目关联；删除容器保留已有历史记录。
- 设置单独持久化；长休息按完成轮数安排。更改设置不改变当前时段已确定的时长。
- `sessions.json` 支持旧 Windows ISO 日期和 Swift 默认的 2001 年起算秒数。导出使用 Swift 日期格式；设置不混进专注数据。
- 文件无效或读取失败时阻止新计时及覆盖写入，不静默退回空状态或自动取旧备份。保存失败保留待重试状态，记录编辑落盘成功后才更新界面。
- 导入严格校验、明确替换、先保存再显示成功；运行或暂停中的时段须先结束/取消。导入前旧数据单独备份，不会被后续 checkpoint 覆盖。

原生数据在 Tauri 的应用数据目录，Windows 通常为 `%APPDATA%\com.dilyar.TomatoBarPersonal\`：`sessions.json`、`settings.json`、上一版 `*.previous.json`、损坏原稿 `*.corrupt.json` 和导入前 `*.import-backup-*.json`。首次原生启动可迁移旧 WebView 存储，旧数据保留。浏览器预览用独立浏览器存储，测试使用独立空配置。

## Windows 桌面行为及验收边界

- 使用系统原生标题栏。主窗口关闭按钮隐藏窗口，单一计时所有者继续运行。
- 托盘左键打开窗口，右键提供打开、开始/暂停/继续、保存并退出。
- 退出先暂停并保存；失败时留在应用中处理。到时显示主窗口及无声置顶提醒，关闭提醒恢复普通窗口层级。
- 当前宠物是**应用窗口内可拖动的挂件**，不是独立跨应用桌宠窗口。保持现有 Tomy/Sprout 素材，本次不迁移 macOS 最新坐姿素材。
- 浏览器流程、Mac 上 Rust 编译/存储检查不证明 Windows 原生实机表现。Windows 安装、托盘、关窗后台、真实睡眠、DPI/多屏与置顶提醒需按 [重构记录与验收清单](../docs/Windows重构-2026-10-11.md) 验收。

原生 API 参考：[Tauri 系统托盘](https://v2.tauri.app/learn/system-tray/)、[单实例](https://v2.tauri.app/plugin/single-instance/)、[跨平台原子文件写入](https://docs.rs/atomic-write-file/latest/atomic_write_file/)。
