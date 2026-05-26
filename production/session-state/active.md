# Active Session State

> **Last Updated**: 2026-05-25
> **Last Hand-Off**: /map-systems → user decides next step

---

## Current Task

**Systems Decomposition Complete**

`design/gdd/systems-index.md` written. 25 systems identified across 5 layers
(Foundation 3 / Core 5 / Feature 12 / Presentation 3 / Polish 2).

22 of 25 systems have code implementations (project is in Production stage,
v0.1 MVP released, v0.2 complete, v0.3 in progress, v0.4 pre-QA).

---

## Status

| Item | Value |
|---|---|
| Project Stage | Production |
| Review Mode | lean |
| Active Milestone | roadmap (v0.4 pre-QA) |
| Systems Index | ✅ Written |
| Single-System GDDs | 0 / 25 (retrofit pending) |
| Active Sprint | None (backlog only) |
| Test Framework | Not installed (GUT pending /test-setup) |

---

## Files Touched This Session

- `design/gdd/systems-index.md` — new (25-system catalog)
- `production/session-state/active.md` — this file
- `design/gdd/game-concept.md` — renamed from GDD.md
- `production/stage.txt` — set to Production
- `production/review-mode.txt` — set to lean
- `production/project-stage-report.md` — new
- 5 cross-reference fixes(README + 4 markdown files)

---

## Open Decisions

- ADR-0002 跳号待澄清(可能 v0.3 阶段被废止)
- `design/gdd/game-pillars.md` 是否要从 game-concept.md 抽取独立成文
- `design/registry/entities.yaml` 是否由 `/consistency-check` 自动填充

---

## Recommended Next Skill

按 systems-index.md Recommended Design Order:

1. **`/adopt`** — 审计 4 个宏观 GDD(game-concept / 03_CORE / 04_SKILL / 05_ENEMY)是否符合 CCGS 8 章节标准,产出迁移计划(推荐先做这个,避免直接 retrofit 时发现宏观 GDD 缺章节)
2. **`/test-setup`** — 安装 GUT 框架(测试是 BLOCKING 级别要求)
3. **`/design-system combat-system`** — 从 #1 Combat(highest bottleneck risk)开始 GDD retrofit
4. **手动开 Godot 编辑器** 验证 `res://` 引用没断(迁移后必做的健康检查)

---

## Recovery Instructions

如果会话崩溃,新会话开始时:
1. 读取本文件
2. 读取 `design/gdd/systems-index.md`(完整系统列表)
3. 读取 `production/project-stage-report.md`(项目阶段分析)
4. 继续上面"Recommended Next Skill"列表中尚未完成的项
