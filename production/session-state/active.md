# Active Session State

> **Last Updated**: 2026-05-25
> **Last Hand-Off**: /adopt → user picks Step 1.2 (ADR-0001 retrofit) next

---

## Current Task

**Adoption Audit Complete + B-1 Fixed**

`/adopt` Phase 1-6 done. Adoption plan written to
`docs/adoption-plan-2026-05-25.md` with 3 BLOCKING / 7 HIGH / 12 MEDIUM / 3 LOW.

B-1 closed in-place: systems-index.md Status column normalized to legal values.

---

## Status

| Item | Value |
|---|---|
| Project Stage | Production |
| Review Mode | lean |
| Active Milestone | roadmap (v0.4 pre-QA) |
| Systems Index | ✅ Written (B-1 fixed) |
| Adoption Plan | ✅ docs/adoption-plan-2026-05-25.md |
| BLOCKING fixed | 1 / 3 (B-1 done; B-2, B-3 pending) |
| HIGH fixed | 0 / 7 |
| Single-System GDDs | 0 / 25 (retrofit pending) |
| Active Sprint | None (backlog only) |
| Test Framework | Not installed (GUT pending /test-setup) |

---

## Files Touched This Session

- `design/gdd/systems-index.md` — Status 列 22 行从非法值改为 `Not Started`,加 Status 说明 Note
- `docs/adoption-plan-2026-05-25.md` — new (完整迁移清单)
- `production/session-state/active.md` — this file

---

## Open Decisions

- ADR-0002 跳号待澄清(可能 v0.3 阶段被废止)
- `design/gdd/game-pillars.md` 是否要从 game-concept.md 抽取独立成文
- `design/registry/entities.yaml` 是否由 `/consistency-check` 自动填充

---

## Recommended Next Action

按 `docs/adoption-plan-2026-05-25.md` Execution Order:

1. **B-2 + B-3 + H-1 ~ H-4**(手工编辑两个 ADR,加 4 个章节,~ 35 min)
   - `docs/architecture/0001-godot4-gdscript.md` 加 `## Status`、`## ADR Dependencies`、`## Engine Compatibility`
   - `docs/architecture/0003-sun-wukong-active-skills.md` 同上
2. **H-7**:把 `design/gdd/game-concept.md` 的"MVP 成功标准"重命名为"Acceptance Criteria"(~ 10 min)
3. **Step 3 Bootstrap**:`/architecture-review` → `/create-control-manifest`(~ 1-2 sessions)
4. **`/test-setup`**(GUT)
5. **M-12 / L-1 / L-2**(填 perf budgets + ADR 性能章节)
6. **不修**:M-5 ~ M-11 接受现状(宏观 GDD 不强求 8 章节)、L-3 不改 ADR 命名

---

## Recovery Instructions

如果会话崩溃,新会话开始时:
1. 读取本文件
2. 读取 `docs/adoption-plan-2026-05-25.md`(迁移清单 + 详细修复指南)
3. 读取 `design/gdd/systems-index.md`(完整系统列表)
4. 继续上面"Recommended Next Action"中尚未完成的项
