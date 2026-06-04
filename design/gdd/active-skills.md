# Active Skills System

> **Status**: Approved (revision-1 — addresses 5 BLOCKERS + 4 RECOMMENDED + 4 NICE-TO-HAVE from /design-review revision-0 MAJOR REVISION)
> **Author**: claude (reverse-doc from ActiveSkillCharacter + SunWukongV2 + 6 sun_wukong/ scripts + ADR-0003 + SUN_WUKONG_V2_DESIGN.md)
> **Last Updated**: 2026-05-27
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
2. **Sun Wukong v2 is the ONLY ActiveSkillCharacter subclass** (per ADR-0003 — explicit exception). **Scope-creep guard**: if a future PR introduces a second `extends ActiveSkillCharacter` subclass, the PR MUST be rejected and an ADR amendment to ADR-0003 MUST be filed first. CI guard recommended: grep for `extends ActiveSkillCharacter` and fail if more than one class declares it.
3. **Input contract**: Player's **`_unhandled_input(event)`** routes `skill_1..4` key presses to `ActiveSkillCharacter.cast_skill(0..3)` (per Input GDD AC-11). **`_unhandled_input` (NOT `_input`) is required** so that a focused UI modal consumes the key first — and skill input is additionally gated on `not get_tree().paused` so it cannot fire through the level-up panel (which pauses the tree) or a blocking trade modal (review finding C / ADR-0003 line 42 permits both handlers; `_unhandled_input` + pause-gate is the modal-safe choice). Slot offset: keys are 1-indexed (player-facing), slots are 0-indexed (code-internal). Key 1 → slot 0; key 4 → slot 3.
4. **Skill cast eligibility**: requires `_skill_unlocked[slot]` AND `_skill_cooldowns[slot] == 0` (per Character System GDD Formula 3).
5. **Cast process**: `_on_cast_skill(slot)` is subclass override (SunWukongV2 implements). Returns true on successful activation → cooldown resets to `_skill_max_cds[slot]`.
6. **Cooldown countdown** per `_process(delta)` in ActiveSkillCharacter base class. **Throttled emit policy** (aligned to ADR-0003's 2026-05-28 amendment — this is the as-built behavior, enforced by `tests/unit/character/skill_cooldown_emit_throttle_test.gd`): `skill_cooldown_changed` fires only when one of (a) `ceili(remaining)` changes from the previous frame (the HUD label shows integer seconds, so sub-second changes are invisible), (b) cooldown reaches 0, or (c) a discrete state change (`_register_skill`, `cast_skill` start, level-up, CD-bonus apply). This caps emit rate at **~1/sec/slot (~4/sec total)**, a 60× reduction vs naive per-frame — and matches `.claude/rules/gdscript.md` §UI "HUD updates should be event-driven." (Supersedes the earlier per-frame proposal — the code throttles; per-frame was the stale defect, ADR-0003 line 47-52.)
7. **Skill unlocks via Level Up GDD `_pending_skill_choices`**: at Lv5/10/15/20, Sun Wukong gets a skill-choice panel (3 options from Lv1-Lv4 upgrades; unlocks first then upgrades). Order is **deterministic** — iterates slots 0..3 (per `active_skill_character.gd:117-143`), so first unlock is slot 0 (毫毛分身), then 1 (筋斗云), 2 (七十二变), 3 (定身术).
8. **`reduce_skill_max_cd(slot, amount)` cooldown reduction** (W213-driven upgrade hook): `_skill_max_cds[slot] = maxf(_skill_max_cds[slot] - amount, 1.0)`. **Engine floor: 1.0s** — cooldowns cannot be reduced below this regardless of stacked upgrades. Documented per code line 200-207.
9. **Cast feedback signal contract** (resolves ADR-0003 line 25-27 named signals omission): in addition to `skill_cooldown_changed`, the system emits `skill_triggered(slot)` exactly once on successful cast — for HUD pulse / VFX trigger / Audio cue subscribers. Future implementation; reserved.
10. **火眼金睛 passive — see Passive subsection below**.

### Passive: 火眼金睛 (Fire Eyes — Wukong-only damage boost vs Elite/Boss)

**Contract source**: Combat GDD line 235 reserves the `crit_multiplier` slot (`m_c`) for "**火眼金睛: 1.2** | OQ-2 placeholder; reserved for Active Skills GDD". Combat AC-21 (line 552) is waiting for this GDD to define it. **Code**: `sun_wukong_v2.gd:96-120` `get_damage_modifier(target) -> float`.

**Target predicate (high-value target)**:
- `target.is_in_group("bosses")` — Famine Beast Boss + future Bosses
- OR `target.get("is_elite") == true` — Shanxiao Elite spawned via affixes

For non-elite, non-boss targets, multiplier = 1.0 (no boost).

**Multiplier formula**:
```
const FIRE_EYES_BASE_MULTIPLIER: float = 1.2
const FIRE_EYES_STACK_BONUS: float = 0.05
const FIRE_EYES_MAX_STACKS: int = 7

func get_damage_modifier(target: Node) -> float:
    if not _is_high_value_target(target):
        return 1.0
    return FIRE_EYES_BASE_MULTIPLIER + clampi(_fire_eyes_stacks, 0, FIRE_EYES_MAX_STACKS) * FIRE_EYES_STACK_BONUS
    # → 1.20 at 0 stacks, 1.25 at 1 stack, ..., 1.55 at 7 stacks
```

**Pipeline integration**: applied via Combat GDD Formula 1's `crit_multiplier` slot (per Combat OQ-4 resolution pre-clamp). Wukong's weapons query `get_damage_modifier(target)` before damage emission and multiply into the damage tuple.

**crit_multiplier slot sharing (v0.5)**: Five Phases' 矿脉精粹 combo also writes to the `crit_multiplier` slot (probabilistic ×1.5 on any hit). The two resolve by `max()`: `crit_multiplier = max(fire_eyes_modifier, ore_crit_roll)`. 火眼金睛 provides a deterministic FLOOR (≥1.2 vs elites/bosses); 矿脉精粹 provides a probabilistic SPIKE (1.5) that can exceed it. They do NOT multiply — a player with both never gets 1.2×1.5=1.8. Authoritative spec: elements-five-phases.md Formula 8.

**Stacks** (W213-driven upgrade per Level Up GDD): each W213 upgrade adds +1 stack to `_fire_eyes_stacks` (capped at 7). Stacks persist for the rest of the run.

**HUD display** (OQ — see Open Questions): stacks could show as small icons under Sun Wukong's character portrait. Currently NOT in HUD GDD revision-1; flag for revision-2 if W213 stacks become visible-state-dependent.

### Sun Wukong v2 Skill Inventory (per code-truth audit)

| Slot | Key | Skill | Effect | Lv1 Defaults (code) | Lv1→Lv4 scaling | Implementation |
|---|---|---|---|---|---|---|
| 0 | 1 | 毫毛分身 (Hair Clones) | Summon 2 AI clone-units that target nearby enemies independently | count=2, cooldown=12s | 2/3/3/3 clones per level (Lv2-4 add clone behaviors) | `sun_wukong/hair_clone_v2.gd` + `hair_clone_unit.gd` |
| 1 | 2 | 筋斗云 (Cloud Step) | Dash forward 200 px at high speed; invulnerable during dash | distance=200 px, cooldown=8s, invincibility=true | distance scales per level | `sun_wukong/cloud_step.gd` |
| 2 | 3 | 七十二变 (72 Transformations) | Temporary transformation — Lv1-3 random form (5 forms: giant_ape / golden_eagle / stone_monkey / dragon_shadow / spirit_fox); Lv4 forced giant_ape; per-form buffs TBD | duration=5s, cooldown=25s | duration scales; Lv4 forces giant_ape | `sun_wukong/transform.gd` |
| 3 | 4 | 定身术 (Immobilize) | AOE freeze — all non-elite enemies within `_radius` get per-frame `velocity = Vector2.ZERO` for `_duration`; Elite/Boss get 0.5× duration (Lv1-3); Lv4 breaks elite | radius=150, duration=1.0s, cooldown=15s | 1.0/1.3/1.3/1.8s; Lv3+ adds vulnerability bonus + burst; Lv4 elite-breaking | `sun_wukong/immobilize.gd` |

Plus **金箍棒 v2** (`jingu_bang_v2.gd`) — automatic weapon (not active-skill). Sun Wukong's auto-weapon, fires on `WeaponBase` cooldown logic.

### Per-Skill Detailed Specifications

**Slot 0 — 毫毛分身 (Hair Clones)** (`hair_clone_v2.gd` + `hair_clone_unit.gd`):
- Spawns `_clone_count` units (2 at Lv1, 3 at Lv2+) at Sun Wukong's position
- Each clone is an independent unit with its own targeting (per Targeting GDD's 5× duplicated `_find_nearest_enemy()` — OQ-2 future refactor)
- Clones have `lifetime` seconds (TBD per level)
- Cooldown: 12s base (Lv1), tunable per Tuning Knobs

**Slot 1 — 筋斗云 (Cloud Step)** (`cloud_step.gd`):
- Dash direction: along player movement direction (or facing direction if stationary)
- Dash distance: 200 px at Lv1; scales per level
- Invulnerability frames: enabled for dash duration (`_invincible_enabled = true`)
- Returns false from `_on_cast_skill` if no valid path (rare edge case)
- Cooldown: 8s base

**Slot 2 — 七十二变 (72 Transformations)** (`transform.gd`):
- Lv1-3: random form roll from 5: `FORM_GIANT_APE / FORM_GOLDEN_EAGLE / FORM_STONE_MONKEY / FORM_DRAGON_SHADOW / FORM_SPIRIT_FOX`
- Lv4: forced `FORM_GIANT_APE`
- Duration: 5s base
- Per-form buffs are TBD (currently no concrete effect per-form — OQ-3)
- Cooldown: 25s base

**Slot 3 — 定身术 (Immobilize)** (`immobilize.gd`) — see also Status Effects GDD §Immobilize:
- AOE radius from Sun Wukong: 150 px Lv1 → 200/200/280 Lv2/3/4
- Mechanism: per-frame `enemy.set("velocity", Vector2.ZERO)` for all caught enemies until `end_time`
- Elite penalty: 0.5× duration (Lv1-3); Lv4 `_can_break_elite=true` removes penalty
- Lv3+ adds vulnerability bonus (`_vuln_bonus = 0.3`) — pending Enemy buff system; AND end-of-duration burst (`_burst_enabled = true`, damage=35, radius=100)
- Cooldown: 15s base

**Combo overlap rules**: All 4 skills are independent — casting slot N while slot M's effect is mid-active is allowed. No shared cooldown. Hair clones from a previous cast remain active when a new clone cast spawns more (clones accumulate). Cloud Step invulnerability + Transform buff stack. Immobilize freezes enemies regardless of which other skills are mid-effect.

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

### Formula 2: Cooldown countdown with throttled emit (per Rule 6 / ADR-0003)
```
on _process(delta):
    for slot in 0..3:
        if _skill_cooldowns[slot] > 0:
            prev_ceil = ceili(_skill_cooldowns[slot])
            _skill_cooldowns[slot] = max(0, _skill_cooldowns[slot] - delta)
            # THROTTLED: emit only on integer-second change or reaching 0 — NOT every frame
            if ceili(_skill_cooldowns[slot]) != prev_ceil or _skill_cooldowns[slot] == 0:
                skill_cooldown_changed.emit(slot, _skill_cooldowns[slot], max_cd, unlocked)
```
**Throttled emit** (~1/sec/slot, ~4/sec total) — the integer-second HUD label makes sub-second emits invisible, so they are suppressed. Discrete events (cast / register / level-up / CD-bonus) emit separately. Matches ADR-0003 line 47-52 + `skill_cooldown_emit_throttle_test.gd`.

### Formula 3: 火眼金睛 damage modifier (per Passive subsection)
```
on damage_dealt(target):
    if Sun Wukong is the source:
        damage_modifier = get_damage_modifier(target)
        # 1.0 if target is not high-value
        # 1.2 + stacks * 0.05 if target.is_in_group("bosses") or target.is_elite
    else:
        damage_modifier = 1.0
final_damage = raw_damage × source_modifier × damage_modifier × element_modifier × pierce_falloff
                                              ^^^^^^^^^^^^^^^^^^
                                              feeds Combat Formula 1's crit_multiplier slot
```

### Formula 4: `reduce_skill_max_cd` clamp
```
on reduce_skill_max_cd(slot, amount):
    _skill_max_cds[slot] = maxf(_skill_max_cds[slot] - amount, 1.0)
    # 1.0s engine floor — cannot reduce below this regardless of stacks
```

### Formula 5: Skill unlock via Level Up queue (cross-reference)
Per Level Up GDD §3 (multi-level handling). At specific player levels (5/10/15/20), `_pending_skill_choices` adds 1; queue drains after regular upgrade queue. Order is slot-index deterministic (slot 0 first → slot 3 last).

## Edge Cases
- **Player presses key for locked skill**: `cast_skill` returns false; no error, no feedback (current code — see Anti-fantasy in Player Fantasy — future polish should add a "click" sound).
- **Multiple key presses during cooldown**: subsequent presses ignored.
- **Player switches character mid-run**: impossible in v0.4 (character locked at spawn).
- **All 4 skills at Lv4 max**: skill-choice queue returns empty; Level Up panel skips skill choices.
- **Adding a second `extends ActiveSkillCharacter` subclass** (e.g. future 哪吒 character): **PR MUST be rejected** until ADR-0003 amendment files. Rule 2 scope-creep guard.
- **`reduce_skill_max_cd` pushes below 1.0s**: clamped to 1.0s engine floor (Formula 4).
- **火眼金睛 vs non-high-value target**: `get_damage_modifier` returns 1.0; no boost applied.
- **Casting slot N while slot M mid-effect**: both effects active simultaneously (no shared cooldown — combo rule per Per-Skill Specifications).
- **七十二变 random form roll determinism**: random per cast at Lv1-3 (no seed); Lv4 deterministic (always giant_ape).
- **`_on_cast_skill(slot)` returns false** (e.g. Cloud Step finds no valid path): cooldown does NOT trigger; skill remains castable.

## Dependencies
| Dep | Type | Interface |
|---|---|---|
| **Character System** (FT-06) | Hard | ActiveSkillCharacter base class |
| **Input** (F-01) | Hard | skill_1..4 actions + Player._input routing |
| **Combat** (C-03) | Hard | Skill damage applied via Combat tuple |
| **Targeting** (C-05) | Hard | 定身术 finds nearest enemy |
| **Level Up & Upgrade Pool** (FT-05) | Hard | Skill-choice queue at Lv5/10/15/20 |
| **HUD** (P-01) | Soft | 4-slot cooldown indicators (already in HUD GDD) |
| **Five Phases Synergy** (elements-five-phases.md) | Lateral/Shared | Shared `crit_multiplier` slot — 火眼金睛 (floor) + 矿脉精粹 (spike) resolved by `max()` per Five Phases Formula 8 |

## Tuning Knobs
| Knob | Range | Default | Notes |
|---|---|---|---|
| 毫毛分身 cooldown (Lv1) | 6 – 20s | **12s** | `sun_wukong_v2.gd:47` |
| 毫毛分身 clone count | 1 – 4 | **2 → 3 → 3 → 3** per Lv1-4 | `hair_clone_v2.gd` |
| 筋斗云 cooldown (Lv1) | 4 – 15s | **8s** | `sun_wukong_v2.gd:48` |
| 筋斗云 dash distance (Lv1) | 100 – 400 px | **200 px** | `cloud_step.gd:18` |
| 七十二变 cooldown (Lv1) | 15 – 40s | **25s** | `sun_wukong_v2.gd:49` |
| 七十二变 duration (Lv1) | 3 – 10s | **5s** | `transform.gd` |
| 定身术 cooldown (Lv1) | 8 – 25s | **15s** | `sun_wukong_v2.gd:50` |
| 定身术 duration (Lv1-4) | 0.5 – 3s | **1.0 / 1.3 / 1.3 / 1.8s** | `immobilize.gd:18/48/53/62` |
| 定身术 radius (Lv1-4) | 100 – 400 px | **150 / 200 / 200 / 280 px** | `immobilize.gd:17/47/52/61` |
| 定身术 Elite penalty | 0.3 – 1.0 | **0.5×** (bypassed at Lv4) | `immobilize.gd:115` |
| `reduce_skill_max_cd` floor | locked | **1.0s** | engine const per `active_skill_character.gd:203` |
| `FIRE_EYES_BASE_MULTIPLIER` | 1.0 – 2.0 | **1.2** | per Combat GDD reservation + `sun_wukong_v2.gd:96-120` |
| `FIRE_EYES_STACK_BONUS` | 0.0 – 0.2 | **0.05** per stack | per W213 upgrade hook |
| `FIRE_EYES_MAX_STACKS` | 1 – 15 | **7** | hard cap (caps at 1.55× total) |
| Skill unlock levels | locked design | 5, 10, 15, 20 | per Level Up GDD §3 |
| Active-skill character count | **locked = 1 (ADR-0003)** | 1 | adding requires ADR amendment |

## Acceptance Criteria

**AC-01** **GIVEN** Player as Sun Wukong v2 with slot 0 unlocked and off-cooldown, **WHEN** key 1 pressed, **THEN** `ActiveSkillCharacter.cast_skill(0)` invokes `_on_cast_skill(0)` → 毫毛分身 spawns 2 hair clones (Lv1 count) as Children of the appropriate parent node.

**AC-02** **GIVEN** Player as Sun Wukong v2 with slot 3 unlocked and off-cooldown, **WHEN** key 4 pressed, **THEN** `Immobilize.cast(player)` runs: all non-elite enemies within `_radius = 150 px` have per-frame `velocity` forced to `Vector2.ZERO` for `_duration = 1.0s` AND `enemy.global_position.distance_to(previous_position) < ε` for each frame during that window. (Elite enemies get 0.5× duration per immobilize.gd:115.)

**AC-03** **GIVEN** Sun Wukong's 筋斗云 (slot 1) is on cooldown, **WHEN** key 2 pressed, **THEN** (a) `cast_skill(1)` returns false; (b) no dash node spawned; (c) cooldown timer is NOT reset.

**AC-04** **GIVEN** Sun Wukong reaches Player Level 5, **WHEN** Level Up GDD skill-choice queue activates, **THEN** 3 skill options are offered (per `active_skill_character.gd:140` `slice to 3`) in slot-index deterministic order (slot 0 first).

**AC-05** **GIVEN** a skill on active cooldown, **WHEN** a `_process(delta)` frame does NOT change `ceili(remaining)`, **THEN** `skill_cooldown_changed` does **NOT** emit for that slot; **WHEN** a frame crosses an integer-second boundary OR reaches 0, **THEN** it emits exactly once (throttled policy, Rule 6 / ADR-0003).

**AC-06** **GIVEN** 修行者 (NOT an ActiveSkillCharacter) is the active CharacterBase, **WHEN** key 1 pressed, **THEN** Player's `_try_cast_skill(0)` is invoked AND early-returns silently (no skill cast, no error) per Input GDD AC-12.

**AC-07** **GIVEN** all skill slots are at Lv4 max, **WHEN** `get_skill_choices` runs, **THEN** the slice excludes every slot (per `active_skill_character.gd:139` "lv == 4 已满，跳过") AND returns empty list; Level Up panel skips skill choices.

**AC-08** **GIVEN** Sun Wukong is active, **WHEN** Sun Wukong's weapon fires at a Boss (in `bosses` group), **THEN** `get_damage_modifier(boss)` returns `FIRE_EYES_BASE_MULTIPLIER (1.2) + _fire_eyes_stacks × 0.05` (1.20 with 0 stacks, capped at 1.55 with 7 stacks) AND Combat's `crit_multiplier` slot receives this value (per Combat AC-21 contract).

**AC-09** **GIVEN** Sun Wukong is active, **WHEN** Sun Wukong's weapon fires at a Paper Doll (non-elite non-boss), **THEN** `get_damage_modifier(target)` returns 1.0 (no boost).

**AC-10** **GIVEN** `_skill_max_cds[1] = 2.5s`, **WHEN** `reduce_skill_max_cd(1, 5.0)` is called, **THEN** `_skill_max_cds[1] = max(2.5 - 5.0, 1.0) = 1.0` (engine floor enforced).

**AC-11** **GIVEN** Sun Wukong successfully casts slot 0, **WHEN** the cast succeeds, **THEN** `skill_triggered(0)` emits exactly once (for HUD pulse / VFX / Audio cue subscribers per Rule 9).

## Open Questions

- **OQ-1** (Skill cooldown balance validation): code-shipped values (12/8/25/15s) are now in Tuning Knobs. Whether these are **the right values** is a separate question — needs playtest. Owner: game-designer + systems-designer. **Target**: post-playtest.
- **OQ-2** (Hair Clone AI behavior): hair_clone_unit.gd implements its own targeting (per Targeting GDD's 5-implementation count). Should follow same Targeting refactor pattern. **Owner**: ai-programmer + targeting refactor.
- **OQ-3** (Transform per-form buffs): code defines 5 forms (giant_ape / golden_eagle / stone_monkey / dragon_shadow / spirit_fox); per-form buffs are TODO. Should be: giant_ape=damage boost, golden_eagle=speed boost, stone_monkey=defense, dragon_shadow=invulnerability, spirit_fox=cooldown reduction (preliminary design). **Owner**: game-designer. **Target**: v0.4.x polish.
- **OQ-4** (Multi-skill chaining): combos are pure cooldown gating (no stamina) per Per-Skill Specifications combo rule. If playtest reveals over-powered chaining, consider shared meta-cooldown.
- **OQ-5** (Gamepad mapping for active skills): per Input GDD OQ-3.
- **OQ-6** (火眼金睛 stack visibility in HUD): currently no HUD indicator for the 0-7 stack count. Should W213 upgrades show stack progress? **Owner**: ux-designer + ux-programmer. **Target**: HUD revision-2 when W213 upgrade integration lands.
- **OQ-7 (RESOLVED 2026-06-04)**: the Rule 6 per-frame-vs-throttle contradiction is closed in favor of **throttle** — that is the as-built behavior (`active_skill_character.gd::_process` + regression test `skill_cooldown_emit_throttle_test.gd`) and ADR-0003's 2026-05-28 amendment. Rule 6 / Formula 2 / AC-05 / AC-06 were aligned to throttle; the earlier "amend ADR-0003 to permit per-frame" proposal is **withdrawn** (it would have broken the passing test). No further cross-doc action. (Review finding A.)

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass; documents 4-slot active-skill contract via ActiveSkillCharacter + SunWukongV2. Sun Wukong only character with active skills (per ADR-0003). Specific skill values + tuning TBD (OQ-1). 7 ACs. 5 OQs. |
| 1 | 2026-05-27 | /design-review revision-0 MAJOR REVISION (5 BLOCKERS + 4 RECOMMENDED + 4 NICE-TO-HAVE) | **B-1 closed**: 火眼金睛 passive contract documented as a new subsection — target predicate, `FIRE_EYES_BASE_MULTIPLIER=1.2 / STACK_BONUS=0.05 / MAX_STACKS=7` constants, `get_damage_modifier(target)` formula, Combat Formula 1 crit_multiplier slot integration. AC-08/09 defend. Combat GDD line 235 + AC-21 now have their reserved contract. **B-2 closed**: per-frame emit contradiction with ADR-0003 acknowledged in Rule 6 — declared designed-in exception specifically for cooldown progress bars; ADR-0003 cross-doc amendment tracked as OQ-7. **B-3 closed**: TBD Tuning Knobs replaced with shipped defaults from code (12/8/25/15s cooldowns, 200px Cloud Step, 5s Transform, 1.0-1.8s Immobilize per level, 150-280px Immobilize radius, 0.5× Elite penalty, 1.0s reduce_skill_max_cd floor). 16 knobs total. **B-4 closed**: scope-creep guard added as Rule 2 ("PR rejected; ADR amendment required") + Tuning Knob "Active-skill character count = locked 1". **B-5 closed**: Per-Skill Detailed Specifications subsection added — 4 skills with concrete effect specs; combo overlap rule; 七十二变 5-form roster; immobilize AOE vs nearest-enemy clarification (AOE, not nearest); cloud_step invulnerability frames. **R-1 closed**: AC-10 added defending 1.0s engine floor. **R-2 closed**: Rule 9 + AC-11 added for `skill_triggered(slot)` event-shaped signal (ADR-0003 named signals). **R-3 closed**: AC-02 rewritten to match code's AOE velocity-zero pattern (not "nearest enemy.move_speed"). **R-4 closed**: combo overlap rule added in Per-Skill Specifications. **N-1 closed**: slot-to-key mapping offset documented (Rule 3). **N-3 closed**: AC-04 determinism note (slot-index order). |
| 2 | 2026-06-02 | Five Phases Synergy propagation (elements-five-phases.md 矿脉精粹) | Documented `crit_multiplier` slot sharing with Five Phases 矿脉精粹: resolved by max() (火眼金睛 floor, 矿脉精粹 spike). Additive only — 火眼金睛 behavior unchanged. |
