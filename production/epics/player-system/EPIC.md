# Epic: Player System

> **Layer**: Core
> **GDD**: design/gdd/player-system.md (revision-2, Approved)
> **Architecture Module**: Core / Actors (per `docs/architecture/ARCHITECTURE.md` §角色模块 — 玩家角色)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories player-system`

## Overview

Player owns the human-controlled avatar: movement (WASD), HP (`max_hp = 100`), experience curve (recursive ceilf-clamped per Formula 3), level-up flow, weapon ownership (6 pre-instantiated weapon child nodes), and the upgrade application pipeline. Implementation lives in `scripts/player/player.gd` (843 lines, ~30+ upgrade IDs). `CharacterBase` (Resource-as-Node attached at character-select) overrides Player's base stats per character (修行者, 孙悟空 via `ActiveSkillCharacter` subclass). Player emits 5 signals (`died`, `health_changed`, `experience_changed`, `level_reached`, `upgrade_applied`) consumed by HUD, Run State, and Combat Feedback.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|---|---|---|
| ADR-0001: Godot 4.x + GDScript | Foundational stack — CharacterBody2D + signal architecture + Resource-driven CharacterBase | MEDIUM (post-cutoff API risk on Input system; CharacterBody2D `move_and_slide` stable across 4.x) |
| ADR-0003: Sun Wukong active skills (exception) | `ActiveSkillCharacter` subclass enables 1/2/3/4 key skill routing; otherwise auto-battle preserved | LOW (Input + signal architecture stable) |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|---|---|---|
| TR-core-001 | Manual movement (WASD/arrows), auto attacks | ADR-0001 ✅ |
| TR-stack-001 | Godot 4.x + GDScript implementation stack | ADR-0001 ✅ |

> **No untraced requirements**. All Player-system TRs are covered by ADRs. (Player GDD has additional implicit requirements — e.g. XP curve shape, upgrade application — but these are encoded as Player-only design decisions that don't require cross-system ADRs.)

## Definition of Done

This epic is complete when:
- All stories implemented, reviewed, and closed via `/story-done`
- All 20 acceptance criteria from `design/gdd/player-system.md` verified
- Movement / HP / XP / Level Up / Upgrade Application stories have passing test files in `tests/unit/player/`
- CharacterBase integration test verifies override behavior at character-select time
- Active Skills (Sun Wukong subclass) has dedicated test against ADR-0003 contract
- All 7 Open Questions resolved or explicitly deferred (OQ-1 HP/Pressure-curve coupling closed by Combat GDD revision-4; OQ-2 `set_damage_multiplier` naming + wiring; OQ-3 revive scope; OQ-4 camera coupling; OQ-5 weapon pre-instantiation perf; OQ-6 upgrade-delta tech debt; OQ-7 XP curve ceilf behavior)

## Next Step

Run `/create-stories player-system` to break this epic into implementable stories.
