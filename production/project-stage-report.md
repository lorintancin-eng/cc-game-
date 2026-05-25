# Project Stage Analysis

**Date**: 2026-05-25
**Stage**: Production
**Stage Confidence**: CONCERNS — 代码层是 Production(34 `.gd` / 19 `.tscn` / 7 `.tres` / 6 子系统),但 `design/gdd/systems-index.md` 缺失 + 无 `tests/` 框架,会阻碍 `/create-stories`、`/sprint-plan` 等下游 skill 正确读取项目元数据。

---

## 1. Completeness Overview

| 域 | 完成度 | 详情 |
|---|---|---|
| **Design** | 70% | 10 文档(4 GDD + 3 narrative + 1 level + 2 style);`game-concept.md` ✅、`systems-index.md` ❌、pillars 未独立成文 |
| **Code** | Production | 34 `.gd` + 19 `.tscn` + 7 `.tres`;6 系统:`character / enemy / player / system / ui / weapon` |
| **Architecture** | 70% | 2 真实 ADR(0001 Godot+GDScript、0003 孙悟空特例) + `ARCHITECTURE.md` 总览;ADR 0002 缺号待澄清 |
| **Production** | 60% | `roadmap.md` + `backlog.md` + 1 QA 清单 + v0.2/v0.3 完整 archive;无 active sprint |
| **Tests** | 0% | 无 `tests/` 目录(之前 Python runner 已删,GUT 待安装) |

---

## 2. Detected Artifacts

### 2.1 Design

- `design/gdd/game-concept.md`(原 GDD.md)— 项目愿景 + 设计支柱
- `design/gdd/03_CORE_GAMEPLAY.md` — 核心玩法循环
- `design/gdd/04_SKILL_DESIGN.md` — 技能系统设计
- `design/gdd/05_ENEMY_DESIGN.md` — 敌人系统设计
- `design/narrative/01_STORY_BIBLE.md` — 故事圣经
- `design/narrative/02_CHARACTER_DESIGN.md` — 角色设计
- `design/narrative/SUN_WUKONG_V2_DESIGN.md` — 孙悟空 v2 完整设计稿
- `design/levels/06_LEVEL_DESIGN.md` — 关卡设计
- `design/style/07_VISUAL_STYLE_GUIDE.md` — 视觉风格指南
- `design/style/08_UI_UX_GUIDE.md` — UI/UX 指南

### 2.2 Code(Godot 项目本体)

| 子系统 | `.gd` 文件 | 关键文件 |
|---|---|---|
| `scripts/character/` | 3 | `character_base`、`active_skill_character`、`sun_wukong_v2` |
| `scripts/enemy/` | 3 | `enemy`、`enemy_archetype`、`famine_beast_boss` |
| `scripts/player/` | 1 | `player` |
| `scripts/system/` | 4 | `demon_seal`、`enemy_spawner`、`experience_orb`、`stage_director` |
| `scripts/ui/` | 4 | `hud`、`character_select_panel`、`game_over_panel`、`level_up_panel` |
| `scripts/weapon/` | 19 | `weapon_base` + 6 武器(各含 weapon + projectile + impact)+ `sun_wukong/` 6 个技能 |

- **场景文件**:19 个 `.tscn`(Main + enemy/player/system/ui/weapon 分类)
- **资源文件**:7 个敌人 `.tres`(famine_beast、fox_spirit、ghost_flame、paper_doll、shanxiao_elite、stone_golem、wandering_soul)

### 2.3 Architecture

- `docs/architecture/ARCHITECTURE.md` — 系统总览
- `docs/architecture/0001-godot4-gdscript.md` — ADR-0001:技术栈选择
- `docs/architecture/0003-sun-wukong-active-skills.md` — ADR-0003:孙悟空特例(主动技能 vs 自动战斗)
- ⚠️ ADR-0002 缺号 — 需澄清

### 2.4 Production

- `production/milestones/roadmap.md` — 版本路线图(v0.1 → v0.4+)
- `production/sprints/backlog.md` — 跨版本任务待办池
- `production/qa/W214_v0.4_QA_Checklist.md` — v0.4 pre-QA 检查清单
- `production/archive/v0.2/`(4 文件)、`production/archive/v0.3/`(2 文件)— 历史快照
- `production/stage.txt = Production`
- `production/review-mode.txt = lean`

### 2.5 Tests

- 无 `tests/` 目录
- 无 GUT/gdUnit4 框架

---

## 3. Gaps Identified

| # | 差距 | 状态 | 备注 |
|---|---|---|---|
| 1 | GDD 入口文件命名(CCGS 期望 `game-concept.md`) | ✅ 已解决 | 重命名 + 5 处引用修复 |
| 2 | `design/gdd/systems-index.md` 缺失 | 🔜 待执行 | 用户选"跑 `/map-systems`",在下一轮触发 |
| 3 | `design/gdd/game-pillars.md` 未独立成文 | ⏸ 暂缓 | pillars 章节嵌在 game-concept.md 内,CCGS skill 可读 |
| 4 | 无 `tests/` 框架 | 🔜 待执行 | 用户选 GUT,在下一轮触发 `/test-setup` |
| 5 | `production/review-mode.txt` 未设 | ✅ 已解决 | 设为 `lean` |
| 6 | ADR 0002 缺号 | ⏸ 待澄清 | 可能 v0.3 阶段被废止或跳号,需用户确认 |
| 7 | 无 active sprint | ⏸ 待执行 | v0.4 QA 任务可由 `/sprint-plan` 转化 |
| 8 | `design/registry/entities.yaml` 空 | ⏸ 可选 | `/consistency-check` 可从 7 个敌人 `.tres` 自动填充 |

---

## 4. Recommended Next Steps(按优先级)

1. **`/map-systems`** — 把 6 个子系统正式整理成 `design/gdd/systems-index.md`(解锁 #2,下游 skill 依赖)
2. **`/test-setup`** — 安装 GUT,建立 `tests/{unit,integration}/` 框架(解锁 #4,coding-standards 把 balance/combat 测试列为 BLOCKING)
3. **`/adopt`** — 审计 4 个 GDD 是否符合 CCGS 8 章节标准(Overview / Player Fantasy / Detailed Rules / Formulas / Edge Cases / Dependencies / Tuning Knobs / Acceptance Criteria),输出迁移清单
4. **手动开 Godot 编辑器** — 用根目录 `Godot_v4.6.2-stable_win64.exe` 打开 `project.godot`,让 Godot 重新生成 `.godot/` 缓存,验证 `res://` 引用没断(迁移后必做的健康检查)
5. **`/sprint-plan v0.4-qa`** — 把 `production/qa/W214_v0.4_QA_Checklist.md` 转成正式 sprint(解锁 #7)
6. **(可选)`/consistency-check`** — 自动填充 `design/registry/entities.yaml`(解锁 #8)
7. **(可选)`/architecture-decision`** — 创建 ADR-0002 或确认跳号(解决 #6)

---

## 5. Role-Specific Highlights

### 5.1 Programmer
- 优先解决 #4(测试框架)— BLOCKING 标记的 balance/combat 测试缺失
- 优先验证 #4 后的 `res://` 引用完整性

### 5.2 Designer
- 优先解决 #2(systems-index)— 解锁下游 skill 路由
- #3 pillars 独立化可后置

### 5.3 Producer
- 优先解决 #7(active sprint)— v0.4 QA 工作需要正式 sprint 跟踪
- backlog.md 已有任务,直接转 sprint 即可
