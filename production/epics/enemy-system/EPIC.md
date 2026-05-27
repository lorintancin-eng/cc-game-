# Epic: Enemy System

> **Layer**: Core
> **GDD**: design/gdd/enemy-system.md (revision-1, Approved)
> **Architecture Module**: Core / Actors + Resources (per `docs/architecture/ARCHITECTURE.md` §角色模块 + §资源模块)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories enemy-system`

## Overview

The Enemy System is the threat half of the auto-battle contract. Every non-Boss entity that contacts the player and applies damage is an `Enemy` (`CharacterBody2D` subclass, 242 lines). Each archetype's stats / behavior comes from an `EnemyArchetype` Resource (26 lines, 19 fields) bound to the `archetype` export — the canonical example of MythSurvivor's Pillar-4 data-driven content pattern. 7 archetypes exist as `.tres` files (paper_doll, wandering_soul, fox_spirit, ghost_flame, stone_golem, shanxiao_elite, famine_beast). Two movement modes (CHASE direct; WAVE_CHASE sinusoidal). Elite affix system (`iron_bones` HP×1.45, `swift` speed×1.3) stacks multiplicatively over general elite multipliers. The `FamineBeastBoss` (327 lines) extends Enemy with a 4-state machine (CHASE / CHARGE_WINDUP / CHARGE / CHARGE_RECOVERY), 3 telegraphed skills (Charge / Burst / Summon), and Enrage phase at 30% HP.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|---|---|---|
| ADR-0001: Godot 4.x + GDScript | CharacterBody2D + Area2D contact detection; Resource-driven archetype; signal-based death lifecycle | HIGH (50-100 enemies + 200+ projectiles is the performance stress case per ADR-0001 Performance Implications) |

> **Note**: No Enemy-specific ADR exists. Archetype pattern, elite affix stacking rules, and Boss state machine are spec-locked in the GDD only.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|---|---|---|
| TR-enemy-001 | Archetype pattern: base Enemy class + per-enemy .tres | ❌ No ADR — suggested: ADR for Enemy archetype pattern |
| TR-enemy-002 | Hit feedback (0.1s white flash, elite screen-shake) | ❌ No ADR — same suggested ADR as Combat for combat feedback signal |
| TR-enemy-003 | Boss spawn at 5:00, defeat triggers victory | ❌ No ADR — suggested: ADR for Boss spawn + victory (shared with Run State epic) |

> ⚠️ **All 3 TRs are untraced**. Same situation as Combat and Run State — brownfield project hasn't promoted decisions to ADR yet. Recommend ADR for Enemy archetype pattern before `/create-stories enemy-system` since it constrains the data-driven scaffolding all 7 + future archetypes must follow.

## Definition of Done

This epic is complete when:
- All stories implemented, reviewed, and closed via `/story-done`
- All 25 acceptance criteria from `design/gdd/enemy-system.md` verified
- All 6 Formulas have passing tests in `tests/unit/enemy/` (movement chase, wave chase, take_damage delegation, contact damage throttle, elite multiplier stack, boss enrage skill multiplier)
- All 7 archetype `.tres` values match `design/registry/entities.yaml` (cross-doc consistency)
- Boss state machine integration test: full Boss fight from CHASE → CHARGE → CHARGE_RECOVERY → CHASE, plus Enrage trigger at 30% HP
- Elite affix combo test: Shanxiao + iron_bones + swift → HP 199, DMG 18, SPD 98.3 (revision-1 corrected values)
- All 7 Open Questions resolved or explicitly deferred (especially OQ-1 `damage_taken` signal emission + OQ-2 take_damage 5-tuple migration — both block Combat Feedback / Status Effects GDDs)

## Next Step

Run `/create-stories enemy-system` to break this epic into implementable stories.
