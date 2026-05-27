# Systems Index: MythSurvivor

> **Status**: Draft
> **Created**: 2026-05-25
> **Last Updated**: 2026-05-25
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

MythSurvivor 是一款 Godot 4.6 + GDScript 的 2D 俯视角自动战斗 Roguelite 生存游戏(中国神话题材)。
**25 个系统**分布在 5 个层级:Foundation(3)、Core(5)、Feature(12)、Presentation(3)、Polish(2)。

核心循环依赖关系:Input → Player → Combat → Enemy 系统群 → Experience → Level Up;
Stage Director 编排 5 分钟节奏,Boss/Demon Seal 提供风险收益结构。
高风险瓶颈系统是 **Combat / Player / Enemy**(每个被 6-7 个下游系统依赖)。

项目当前阶段:**Production**(v0.1 MVP 已发布,v0.2 完成,v0.3 角色系统进行中,v0.4 pre-QA)。
22/25 系统已有代码实现 — 本索引的优先级主要决定 **GDD 反向补写顺序**。

---

## Systems Enumeration

> **Status 列说明**:`Status` 反映**单系统 GDD 文件的状态**,不是代码实现状态。所有 25 行当前都是 `Not Started` —— 因为 25 个单系统 GDD 文件还没写,即使其中 22 个系统的代码已经实现。
> **代码实现状态**见下方 [Progress Tracker](#progress-tracker)。
> **合法 Status 值**:`Not Started` / `In Progress` / `In Review` / `Designed` / `Approved` / `Needs Revision`(`/adopt` 不允许其他值或括号)。

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|---|---|---|---|---|---|
| 1 | Input | Core | MVP | Approved | design/gdd/input-system.md | — |
| 2 | Resource Data Framework | Core | MVP | Approved | design/gdd/resource-data-framework.md | — |
| 3 | Run State | Core | MVP | Approved | design/gdd/run-state.md | — |
| 4 | Player | Core | MVP | Approved | design/gdd/player-system.md | Input |
| 5 | Camera | Core | MVP | Approved | design/gdd/camera-system.md | Player |
| 6 | Combat | Core | MVP | Approved | design/gdd/combat-system.md | Resource Data |
| 7 | Enemy | Core | MVP | Approved | design/gdd/enemy-system.md | Resource Data, Combat |
| 8 | Targeting | Core | MVP | Approved | design/gdd/targeting-system.md | Player, Enemy |
| 9 | Enemy Spawning | Gameplay | MVP | Approved | design/gdd/enemy-spawning.md | Run State, Enemy |
| 10 | Stage Director | Gameplay | Vertical Slice | Approved | design/gdd/stage-director.md | Run State, Enemy Spawning |
| 11 | Weapon System | Gameplay | MVP | Approved | design/gdd/weapon-system.md | Combat, Targeting |
| 12 | Experience & Progression | Progression | MVP | Approved | design/gdd/experience-progression.md | Enemy |
| 13 | Level Up & Upgrade Pool | Progression | MVP | Needs Revision | design/gdd/level-up-pool.md | Run State, Experience |
| 14 | Character System | Gameplay | Alpha | Approved | design/gdd/character-system.md | Player, Weapon System |
| 15 | Active Skills (孙悟空特例) | Gameplay | Alpha | Approved | design/gdd/active-skills.md | Input, Character System |
| 16 | Demon Seal | Gameplay | Vertical Slice | Approved | design/gdd/demon-seal.md | Player, Stage Director |
| 17 | Boss System | Gameplay | Vertical Slice | Approved | design/gdd/boss-system.md | Enemy, Stage Director |
| 18 | Status Effects | Gameplay | Vertical Slice | Approved | design/gdd/status-effects.md | Combat |
| 19 | Elements / 五行相克 (inferred) | Gameplay | Full Vision | Approved | design/gdd/elements-five-phases.md | Combat, Enemy |
| 20 | Pickup System (inferred) | Gameplay | MVP | Approved | design/gdd/pickup-system.md | Player, Experience |
| 21 | HUD | UI | MVP | Approved | design/ux/hud.md | Run State, Player, Experience, Active Skills, Combat Feedback |
| 22 | Menu System | UI | MVP | Approved | design/ux/menu-system.md | Run State, Level Up, Character System, HUD, Input |
| 23 | Combat Feedback | UI | Vertical Slice | Approved | design/gdd/combat-feedback.md | Combat, HUD, Audio, VFX |
| 24 | Audio | Audio | Full Vision | Approved | design/gdd/audio-system.md | Combat, Stage Director, Level Up, Demon Seal, Combat Feedback |
| 25 | VFX | UI | Full Vision | Approved | design/gdd/vfx-system.md | Combat, Weapon System, Enemy, Boss, Demon Seal |

> **Note**: P-01 HUD 和 P-22 Menu 按 `design/CLAUDE.md` 应放 `design/ux/`(用 `/ux-design` 生成);其他系统按 `design/gdd/[slug].md` 命名。

---

## Categories

| Category | 说明 | 本游戏的系统 |
|---|---|---|
| **Core** | 一切的基础 | Input, Resource Data, Run State, Player, Camera, Combat, Enemy, Targeting |
| **Gameplay** | 让游戏好玩的系统 | Enemy Spawning, Stage Director, Weapon System, Character System, Active Skills, Demon Seal, Boss, Status Effects, Elements, Pickup |
| **Progression** | 玩家成长 | Experience & Progression, Level Up & Upgrade Pool |
| **UI** | 玩家信息呈现 | HUD, Menu System, Combat Feedback, VFX |
| **Audio** | 声音 | Audio |

> Persistence(存档)、Economy(经济)、Narrative(剧情系统)、Meta(分析/教程)— **当前 MVP 不需要**,未来扩展时再加。

---

## Priority Tiers

| Tier | 系统数 | 目标里程碑 | 项目实际状态 |
|---|---|---|---|
| **MVP** | 15 | v0.1 First Playable | ✅ 已发布 |
| **Vertical Slice** | 5 | v0.2 一关完整体验 | ✅ 已实现 |
| **Alpha** | 2 | v0.3+ 完整玩法 | 🟡 进行中(孙悟空 v2) |
| **Full Vision** | 3 | v0.5+ Beta/Release | ❌ 未开始 |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **Input** — 输入是一切玩家交互的物理入口
2. **Resource Data Framework** — 数据驱动迭代支柱(.tres 配置)
3. **Run State** — 单局生命周期 / 暂停 / 计时 的所有者

### Core Layer (depends on foundation)

1. **Player** — depends on: Input
2. **Camera** — depends on: Player
3. **Combat** — depends on: Resource Data
4. **Enemy** — depends on: Resource Data, Combat
5. **Targeting** — depends on: Player, Enemy

### Feature Layer (depends on core)

1. **Enemy Spawning** — depends on: Run State, Enemy
2. **Stage Director** — depends on: Run State, Enemy Spawning
3. **Weapon System** — depends on: Combat, Targeting
4. **Experience & Progression** — depends on: Enemy
5. **Level Up & Upgrade Pool** — depends on: Run State, Experience
6. **Character System** — depends on: Player, Weapon System
7. **Active Skills** — depends on: Input, Character System
8. **Demon Seal** — depends on: Player, Stage Director
9. **Boss System** — depends on: Enemy, Stage Director
10. **Status Effects** — depends on: Combat
11. **Elements / 五行** — depends on: Combat, Enemy
12. **Pickup System** — depends on: Player, Experience

### Presentation Layer (depends on features)

1. **HUD** — depends on: Run State, Player, Experience, Active Skills
2. **Menu System** — depends on: Run State, Level Up, Character System
3. **Combat Feedback** — depends on: Combat, Enemy

### Polish Layer (depends on everything)

1. **Audio** — depends on: Combat, Experience, Level Up
2. **VFX** — depends on: Combat, Weapon System, Enemy

---

## Recommended Design Order (GDD Retrofit)

> 项目代码大多已存在,这是 **GDD 反向补写顺序**。Bottleneck 系统优先,因为下游 GDD 会引用它们。

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|---|---|---|---|---|---|
| 1 | Combat | MVP | Core | systems-designer | M (2-3 sessions) |
| 2 | Player | MVP | Core | game-designer | S (1 session) |
| 3 | Enemy | MVP | Core | systems-designer | M |
| 4 | Run State | MVP | Foundation | game-designer | S |
| 5 | Resource Data Framework | MVP | Foundation | game-designer + lead-programmer | S |
| 6 | Input | MVP | Foundation | game-designer | S |
| 7 | Camera | MVP | Core | game-designer | S |
| 8 | Targeting | MVP | Core | systems-designer | S |
| 9 | Experience & Progression | MVP | Progression | economy-designer | S |
| 10 | Pickup System | MVP | Gameplay | game-designer | S |
| 11 | Enemy Spawning | MVP | Gameplay | systems-designer | M |
| 12 | Weapon System | MVP | Gameplay | systems-designer | L (4+ sessions) |
| 13 | Level Up & Upgrade Pool | MVP | Progression | economy-designer | M |
| 14 | HUD | MVP | UI | ux-designer | S |
| 15 | Menu System | MVP | UI | ux-designer | M |
| 16 | Stage Director | Vertical Slice | Gameplay | level-designer | M |
| 17 | Demon Seal | Vertical Slice | Gameplay | systems-designer | S |
| 18 | Boss System | Vertical Slice | Gameplay | systems-designer + ai-programmer | M |
| 19 | Status Effects | Vertical Slice | Gameplay | systems-designer | S |
| 20 | Combat Feedback | Vertical Slice | UI | ux-designer + technical-artist | S |
| 21 | Character System | Alpha | Gameplay | game-designer | M |
| 22 | Active Skills | Alpha | Gameplay | systems-designer | M |
| 23 | Elements / 五行 | Full Vision | Gameplay | systems-designer | M |
| 24 | Audio | Full Vision | Audio | audio-director | M |
| 25 | VFX | Full Vision | UI | technical-artist | M |

> Effort: S = 1 session, M = 2-3 sessions, L = 4+ sessions

---

## Circular Dependencies

**None found** ✅ — Phase 3 检查所有潜在循环依赖(Player↔Enemy via Combat 中介,Character↔Weapon 单向,HUD↔Active Skills 通过信号),全部无循环。

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|---|---|---|---|
| **Combat** | Technical + Design | 🔴 Bottleneck — 7 个下游系统依赖。伤害类型扩展(burn / explosion / tick)如果设计错,所有武器都要改 | GDD 优先;`/architecture-decision` 锁定伤害类型契约;有 ADR-0001 部分覆盖 |
| **Player** | Design | 🔴 Bottleneck — 6 个下游依赖。移动手感是游戏体验核心,但 game-concept 描述模糊("玩家手动移动") | GDD 必须明确移动公式、速度上限、被击退处理 |
| **Enemy** | Technical | 🔴 Bottleneck — 6 个下游依赖。50-100 敌人同屏的性能压力 | 已有 archetype 模式;性能预算见 03_CORE §13;后续 `/perf-profile` 验证 |
| **Stage Director** | Design | 🟡 5 分钟节奏曲线 + Boss 触发时机调校,易过难或过易 | 03_CORE §12 已有期望表现表,playtest 后调 |
| **Active Skills (孙悟空)** | Design + Scope | 🟡 ADR-0003 决策风险 — 主动技能与自动战斗定位的张力,不被玩家接受会成"鸡肋角色" | v2 设计已写完;v0.3 playtest 验证 |
| **Audio** | Scope | 🟡 暗黑志怪音效未试,可能拉低体验也可能成亮点 | 推迟到 Full Vision;先用占位音验证基础节奏 |

---

## Progress Tracker

| Metric | Count |
|---|---|
| Total systems identified | 25 |
| Code implemented | 22 (✅) |
| Design docs authored (single-system GDD) | **25 / 25** ✅ |
| Design docs reviewed via /design-review | **25 / 25** ✅ (Combat 3 rounds; Player 4 rounds; 10 batch GDDs 1-2 rounds each via design-reviewer subagent — see commit history) |
| Design docs reviewed via /review-all-gdds | **1 round** (2026-05-27 — FAIL verdict; 5 BLOCKING consistency + 2 BLOCKING design theory; see `design/gdd/gdd-cross-review-2026-05-27.md`). 4/5 consistency blockers fixed same-day; D-B1 (HP playtest) + D-B2 (stack cap) remain. |
| Design docs approved | **24 / 25** — 1 flagged Needs Revision (level-up-pool — pending D-B2 stack cap decision) |
| MVP systems designed (single GDD) | 15 / 15 ✅ |
| Vertical Slice systems designed | 5 / 5 ✅ |
| Alpha systems designed | 2 / 2 ✅ (Character System + Active Skills) |
| Full Vision systems designed | 3 / 3 ✅ (Elements / Audio / VFX — placeholders for v0.5+) |

> **现状**:有 4 个宏观 GDD(game-concept/03_CORE/04_SKILL/05_ENEMY)+ 1 个 narrative(02_CHARACTER)+ 1 个 level(06_LEVEL)覆盖了多个系统,但 **没有单系统 GDD**。`/adopt` 之后会判断这些宏观 GDD 是否要拆分成单系统 GDD。

---

## Next Steps

- [x] Approve this systems enumeration
- [x] Run `/adopt` to audit existing macro-GDDs against the 8-section standard
- [x] Author all 25 single-system GDDs (Combat → Player → Enemy → Run State → ... → VFX)
- [x] Run `/design-review` on all 25 GDDs (5 MAJOR REVISION + 4 CONCERNS + 1 NEEDS REVISION; all revised to Approved revision-1)
- [x] Cross-doc fixes propagated (stage-director.md DemonSeal edge case; HUD↔CombatFeedback heartbeat ownership; ADR-0003 amendment for per-frame emit tracked as OQ-7 in active-skills.md)
- [ ] **NEXT**: Run `/review-all-gdds` for full cross-document consistency check
- [ ] **NEXT**: `/create-stories` per approved epic (4 epics ready: Combat, Player, Run State, Enemy)
- [ ] **NEXT**: Install GUT framework in Godot editor; `/test-setup`
- [ ] **NEXT**: `/gate-check pre-production` when stories are sprint-ready
- [ ] **Track defects from design-review**:
  - Demon Seal OQ-4: `_on_demon_seal_completed` missing `_is_stage_failed` guard (8 XP orbs spawn post-death) — v0.4.x patch
  - Active Skills OQ-7: ADR-0003 amendment for per-frame `skill_cooldown_changed` emit
  - Elements B-1 forward: Enemy GDD needs `element: String = "neutral"` field when v0.5 Elements activates
  - Status Effects: 4/6 effects unimplemented (Hit Flash, Burn DOT — Combat Feedback / Combat Formula 5 reservations)
  - Combat Feedback: `low_hp_state_changed` signal needs Combat Feedback service implementation
