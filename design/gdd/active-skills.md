# Active Skills System

> **Status**: Designed (revision-0)
> **Author**: claude (reverse-doc from ActiveSkillCharacter + SunWukongV2 + 6 sun_wukong/ scripts + ADR-0003 + SUN_WUKONG_V2_DESIGN.md)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 2 (player input depth for one character)
> **TR Coverage**: TR-char-002 (Sun Wukong active skills exception per ADR-0003)
> **Layer**: Feature/Alpha (depends on Character System, Combat, Input)

## Overview

Active Skills is the **player-triggered weapon system** — currently a single-character exception (Sun Wukong v2) per ADR-0003. Where auto-firing weapons follow `cooldown → fire` per-frame, active skills follow `key press → cooldown check → activate`.

Sun Wukong has 4 active-skill slots bound to keys 1-4:
- **毫毛分身** (Hair Clones) — summons temporary AI minions
- **筋斗云** (Cloud Step) — dash mobility skill
- **七十二变** (72 Transformations) — temporary transformation
- **定身术** (Immobilize) — freezes enemy in place

Skills unlock progressively (Lv5/10/15/20 per Level Up GDD skill-choice queue). Each slot has Lv1-Lv4 upgrades (Level Up GDD pool).

Reference: ADR-0003 (foundational design), SUN_WUKONG_V2_DESIGN.md (concrete arrangement), ActiveSkillCharacter base class, Character System GDD §ActiveSkillCharacter subclass, Input GDD `skill_1..4` action contract.

## Player Fantasy

Sun Wukong is the **operations-heavy** character — unlike 修行者 who just survives, the Wukong player thinks about combo timing:

> "Charge in with 筋斗云 (1), drop a 毫毛分身 (3) to draw aggro, then 定身术 (4) on the elite to freeze it, then dash out with 七十二变 (2) before its burst comes off cooldown. I'm not just kiting — I'm composing."

Anti-fantasy: skills that feel passive (no input feedback), cooldowns that are too long (feel ammo-starved), or skills that don't visually differ.

## Detailed Rules

1. **ActiveSkillCharacter extends CharacterBase** (per Character System GDD §4) — adds 4 cooldown slots + `cast_skill(slot)` API.
2. **Sun Wukong v2 is the ONLY ActiveSkillCharacter subclass** (per ADR-0003 — explicit exception).
3. **Input contract**: Player's `_input(event)` routes `skill_1..4` key presses to `ActiveSkillCharacter.cast_skill(0..3)` (per Input GDD AC-11).
4. **Skill cast eligibility**: requires `_skill_unlocked[slot]` AND `_skill_cooldowns[slot] == 0` (per Character System GDD Formula 3).
5. **Cast process**: `_on_cast_skill(slot)` is subclass override (SunWukongV2 implements). Returns true on successful activation → cooldown resets to `_skill_max_cds[slot]`.
6. **Cooldown countdown** per `_process(delta)` in ActiveSkillCharacter base class.
7. **Skill unlocks via Level Up GDD `_pending_skill_choices`**: at Lv5/10/15/20, Sun Wukong gets a skill-choice panel (3 options from Lv1-Lv4 upgrades; unlocks first then upgrades).

### Sun Wukong v2 Skill Inventory

| Slot | Skill | Effect | Implementation |
|---|---|---|---|
| 0 | 毫毛分身 (Hair Clones) | Summon 2 AI minions | `sun_wukong/hair_clone_v2.gd` + `hair_clone_unit.gd` |
| 1 | 筋斗云 (Cloud Step) | Dash forward + invulnerability | `sun_wukong/cloud_step.gd` |
| 2 | 七十二变 (72 Transformations) | Temporary transformation (damage boost?) | `sun_wukong/transform.gd` |
| 3 | 定身术 (Immobilize) | Freeze nearest enemy | `sun_wukong/immobilize.gd` |

Plus **金箍棒 v2** (`jingu_bang_v2.gd`) — automatic weapon (not active-skill). Sun Wukong's auto-weapon, fires on `WeaponBase` cooldown logic.

## Formulas

### Formula 1: Skill cast pipeline (delegated to Character System Formula 3)
```
on cast_skill(slot):
    if not _skill_unlocked[slot]: return false
    if _skill_cooldowns[slot] > 0: return false
    success = _on_cast_skill(slot)
    if success:
        _skill_cooldowns[slot] = _skill_max_cds[slot]
        skill_cooldown_changed.emit(slot, max_cd, max_cd, true)
    return success
```

### Formula 2: Cooldown per-frame
```
on _process(delta):
    for slot in 0..3:
        if _skill_cooldowns[slot] > 0:
            _skill_cooldowns[slot] = max(0, _skill_cooldowns[slot] - delta)
            skill_cooldown_changed.emit(slot, remaining, max_cd, unlocked)
```

### Formula 3: Skill unlock via Level Up queue
Per Level Up GDD §3 (multi-level handling). At specific player levels (5/10/15/20), `_pending_skill_choices` adds 1; queue drains after regular upgrade queue.

## Edge Cases
- **Player presses key for locked skill**: `cast_skill` returns false; no error, no feedback.
- **Multiple key presses during cooldown**: subsequent presses ignored.
- **Player switches character mid-run**: impossible in v0.4 (character locked at spawn).
- **All 4 skills at Lv4 max**: skill-choice queue returns empty; Level Up panel skips skill choices.

## Dependencies
| Dep | Type | Interface |
|---|---|---|
| **Character System** (FT-06) | Hard | ActiveSkillCharacter base class |
| **Input** (F-01) | Hard | skill_1..4 actions + Player._input routing |
| **Combat** (C-03) | Hard | Skill damage applied via Combat tuple |
| **Targeting** (C-05) | Hard | 定身术 finds nearest enemy |
| **Level Up & Upgrade Pool** (FT-05) | Hard | Skill-choice queue at Lv5/10/15/20 |
| **HUD** (P-01) | Soft | 4-slot cooldown indicators (already in HUD GDD) |

## Tuning Knobs
| Knob | Range | Default |
|---|---|---|
| Skill max_cd (per slot) | 3 – 30s | TBD per skill |
| Hair Clone count | 1 – 4 | 2 |
| Cloud Step dash distance | 100 – 400 px | TBD |
| Transform duration | 2 – 10s | TBD |
| Immobilize duration | 1 – 5s | TBD |
| Skill unlock levels | locked design | 5, 10, 15, 20 |

## Acceptance Criteria

**AC-01** Player as Sun Wukong v2 presses key 1 (skill_1) → ActiveSkillCharacter.cast_skill(0) → 毫毛分身 spawns 2 hair clones.
**AC-02** Player presses key 4 (skill_4) → 定身术 → nearest enemy.move_speed effectively 0 for duration.
**AC-03** Player presses key 2 during 筋斗云 cooldown → cast_skill returns false, no dash.
**AC-04** Sun Wukong reaches Player Level 5 → Level Up GDD skill-choice queue activates → 3 skill options offered.
**AC-05** Skill cooldown ticks per frame → skill_cooldown_changed emits each frame for HUD smoothness.
**AC-06** Non-ActiveSkillCharacter (修行者) presses key 1 → Player ignores (per Input GDD AC-12) — no skill cast.
**AC-07** Skill slot at Lv4 (max) → skill-choice queue's get_skill_choices excludes that slot's options.

## Open Questions

- **OQ-1** (Skill cooldowns + tuning values): specific cooldown values not yet finalized. SUN_WUKONG_V2_DESIGN.md has design intent; verify code defaults match. Owner: game-designer + systems-designer.
- **OQ-2** (Hair Clone AI behavior): hair_clone_unit.gd implements its own targeting (per Targeting GDD's 5-implementation count). Should follow same Targeting refactor pattern.
- **OQ-3** (Transform mechanic specifics): SUN_WUKONG_V2_DESIGN.md mentions 七十二变 but precise effect (damage boost? invulnerability? form change?) needs design-pass. Owner: game-designer.
- **OQ-4** (Multi-skill chaining): combos like "freeze + dash + clone-attack" — is there a stamina-style limit, or pure cooldown gating?
- **OQ-5** (Gamepad mapping for active skills): per Input GDD OQ-3.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass; documents 4-slot active-skill contract via ActiveSkillCharacter + SunWukongV2. Sun Wukong only character with active skills (per ADR-0003). Specific skill values + tuning TBD (OQ-1). 7 ACs. 5 OQs. |
