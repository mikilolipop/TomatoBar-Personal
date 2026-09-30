# CLAUDE.md

本项目的约定、架构、命令与红线统一写在 **[`AGENTS.md`](AGENTS.md)**（跨 AI 工具共用，Codex 也读它）。
请先完整阅读该文件，本文件刻意不复制其内容，避免两份文档漂移。

另外两份必读：

- **[`docs/HANDOFF.md`](docs/HANDOFF.md)** — 易变层：当前状态、进行中、下一步、刚做完、**已否决的方案**
- **[`docs/BACKLOG.md`](docs/BACKLOG.md)** — 已知问题清单，带优先级、证据（file:line）与状态

## 会话协议

开始时：`git status` → `git log --oneline -5` → `./scripts/test.sh`（必须全绿；项数以末行
PASS 为准，当前 192 项）→ 读上述三份文档。

结束时：`./scripts/test.sh` 全绿 → 更新 `docs/HANDOFF.md` → commit + push。**不得留下未提交的工作。**

## 最高优先红线

- `scripts/test.sh` 不绿不得提交
- 绝不执行 `git checkout .` / `git clean -fd` / `git reset --hard`，除非用户明确要求
- 不向 `upstream`（ivoronin/TomatoBar）推送；`origin` 是 `mikilolipop/TomatoBar-Personal`
  （**public**，2026-09-29 实测确认 —— 不要把真实个人使用数据提交进仓库）
- 不修改历史验收记录（`design-qa.md`、`docs/V1.x更新说明.md`）—— 它们是带日期的时点证据
