# Status Effects System

> **Status**: Approved (revision-1 — addresses 3 BLOCKERS + 3 RECOMMENDED + 3 NICE-TO-HAVE from /design-review revision-0 MAJOR REVISION)
> **Author**: claude (reverse-doc from Combat GDD §damage types + scattered status implementations in enemy.gd / weapon code / sun_wukong/immobilize.gd)
> **Last Updated**: 2026-05-27
> **Implements Pillar**: Pillar 2 (build depth — status layered on damage)
> **TR Coverage**: (supports Combat GDD's tick / burn damage types)
> **Layer**: Feature/Vertical Slice (depends on Combat)

## Overview

Status Effects is the **damage-over-time + behavioral-modifier layer** that extends Combat GDD's 4 damage types beyond instant strikes. **v0.4 implementation honesty: 1/6 effects fully implemented; flash, burn DOT, and the centralized status pipeline are reserved-but-unimplemented contracts.**

This GDD locks the future contract: a centralized `StatusEffect` Resource subclass with apply / tick / expire semantics, plus a subscriber pipeline against Combat's `damage_dealt` signal (the source-side payload Combat GDD revision-2 added specifically to unblock Status Effects integration — see Combat GDD line 207-214 + revision-2 entry line 589).

Reference: Combat GDD damage types + AC-15-17 (burn fixed-step) + revision-2 `damage_dealt` source-side payload, Sun Wukong v2 design, Enemy GDD Formula 5 (affix application with elite-multiplier ordering).

## Player Fantasy

Status effects are **build-defining modifiers** in the full vision. Today (v0.4), the only player-facing feedback is the immobilize freeze on Sun Wukong's 定身术 AOE — no flash, no DOT visuals, no slow trails, no stack counters. The aspirational fantasy:

**Vertical Slice target** (once VFX GDD lands): visible burn rings on Thunder Strike ground patches, slow trails on slowed enemies, stack counters on iron-bones'd elites, white flash on hit (Combat Feedback GDD). The "layered DPS canvas" — burn ticking while Bagua aura ticks while slow gradually dilutes the enemy's pace — is the Pillar 2 deliverable.

**v0.4 reality**: when the player has Bagua + Thunder Law, Bagua applies single-float `take_damage` (no status), Thunder Strike is a 0.32s visual-only Node2D with no after-effect. The player infers DPS from HP-bar drain, not from status-layered feedback.

## Detailed Rules

1. **Damage types Combat GDD already covers** (contract — not all wired through code):
   - `direct` (instant strike) — implemented across all weapons
   - `tick` (Bagua aura) — Bagua delivers a single-float `take_damage` per tick currently; no Status Effect stack created
   - `explosion` (Explosive Talisman impact) — single-float `take_damage` on impact; no Status Effect stack
   - `burn` (planned Thunder Strike after-effect) — **NOT IMPLEMENTED**; Thunder Strike is visual-only (0.32s lifetime, no DOT)
2. **Hit flash (Enemy)** — **NOT IMPLEMENTED in v0.4**. Combat Feedback GDD reserves the 0.1s white sprite tint + 0.05s per-target throttle contract; Enemy.gd does NOT currently override sprite on `take_damage`. Combat Feedback GDD revision-1 confirms this.
3. **Immobilize** (Sun Wukong 定身术) — implemented in `scripts/weapon/sun_wukong/immobilize.gd`. **API**: NOT a method on Enemy — the weapon maintains `_active_immobilizations: Array` and per-frame writes `enemy.set("velocity", Vector2.ZERO)` for caught enemies (lines 71-89). There is no `enemy.set_immobilized()` API. Duration varies per level: Lv1=1.0s / Lv2=1.3s / Lv3=1.3s / Lv4=1.8s. Elite/Boss get duration × 0.5 (line 115) unless Lv4 `_can_break_elite=true`.
4. **Elite affixes** (Enemy spawn) — applied at `configure_elite(affixes)` per Enemy GDD Formula 5 (line 248-266). Multipliers stack with general-elite × 1.25 ordering:
   - `iron_bones`: max_hp_archetype × 1.25 × 1.45 (Shanxiao base 110 → 199.4)
   - `swift`: move_speed_archetype × 1.25 × 1.3
   - NOT visually labeled (no icon overlay yet)
5. **Future StatusEffect base class** (OQ-1) — note: `Callable` exports are NOT serializable in Godot 4.x `.tres`, so the contract below is **aspirational pseudo-code**, not directly implementable as Resource. v0.5+ revision should use a registry of named handler functions instead of Callable exports.
   ```
   # ASPIRATIONAL — not directly implementable as .tres (Callable export limitation)
   class_name StatusEffect extends Resource
   @export var effect_id: String        # closed-set: "burn", "slow", "immobilize", "iron_bones", "swift"
   @export var duration: float
   @export var tick_interval: float = 0.0  # 0 = no tick
   # on_apply / on_tick / on_expire: resolved at runtime via registry lookup keyed by effect_id
   ```
6. **Status Application Pipeline** (subscriber contract):
   - Status Effects service subscribes to `Combat.damage_dealt(source, target, amount, damage_type, source_kind)` (Combat GDD revision-2 source-side payload — line 207-214)
   - On `damage_type = BURN` events: check for existing burn stack on `target`; create new stack OR refresh duration per Stacking Matrix (below)
   - On `damage_type = TICK`: NO stack created by default (Bagua aura tick already direct-damages; status stack would double-count)
   - On `damage_type = DIRECT` / `EXPLOSION`: NO stack created (these are instant damage)
7. **DYING guard** (per Combat Core Rule 6): if `target.is_dying`, all status applications are silently dropped — no stack creation, no signal, no error.

### Status Effect Inventory (v0.4) — HONEST IMPLEMENTATION STATUS

| Effect | Source | Behavior | Status |
|---|---|---|---|
| Hit Flash | Combat damage event | 0.1s white sprite tint, 0.05s per-target throttle | ❌ **NOT IMPLEMENTED** (Combat Feedback GDD revision-1 reserves contract) |
| Burn (DOT) | Thunder Strike after-effect | Fixed-step damage 0.1s tick × burn_duration | ❌ **NOT IMPLEMENTED** (Combat Formula 5 contract reserved; Thunder Strike code is visual-only) |
| Bagua tick | Continuous aura | Per-tick damage on enemies in radius | 🟡 **PARTIAL** — damage applied via single-float `take_damage`; NO status stack created |
| Immobilize | Sun Wukong 定身术 | Per-frame `velocity = Vector2.ZERO` for AOE in `_radius` | 🟡 **PARTIAL** — implemented IN-weapon (`immobilize.gd:71-89`), no Enemy API; no visual indicator |
| Iron Bones | Shanxiao Elite affix | max_hp × 1.45 (after × 1.25 general elite — Enemy Formula 5) | ✅ **IMPLEMENTED** in `enemy.gd:configure_elite` |
| Swift | Elite affix | move_speed × 1.3 (after × 1.25 general elite) | ✅ **IMPLEMENTED** in `enemy.gd:configure_elite` |

**Summary**: 2/6 fully implemented (elite affixes), 2/6 partial (Bagua tick / Immobilize — work but lack pipeline integration), 2/6 aspirational (Hit Flash / Burn DOT — reserved contracts).

### Stacking Matrix (Edge Cases B-2 resolution)

| Effect Class | Same source | Different source | Different effect type |
|---|---|---|---|
| Immobilize | refresh duration (extend `end_time` to `now + duration`, take max if existing later) | refresh duration (take max of all sources) | independent (burn ticks during immobilize) |
| Burn DOT (future) | refresh duration; keep dps unchanged (no dps stacking) | independent stacks (each source has its own end_time + dps) | independent |
| Multiplicative debuff (slow, vuln) — future | multiplicative (clamped to 0.1 floor) | multiplicative (clamped) | independent |
| Elite affix (iron_bones / swift) | applied once at spawn — not runtime mutable | N/A — affixes are spawn-time only | independent (both stack on same enemy: e.g. iron_bones + swift gives Shanxiao 199.4 HP AND ×1.3 speed) |

## Formulas

### Formula 1: Burn fixed-step accumulator (reserved future — owned by Combat GDD Formula 5)
Per Combat GDD Formula 5: `tick = burn_dps × 0.1s` (BURN_TICK_INTERVAL = 0.1 engine constant). Frame-rate independent. **Status Effects does NOT own this formula** — it's Combat's. Status Effects owns the *application pipeline* that subscribes to `damage_dealt` and creates/refreshes burn stacks.

### Formula 2: Elite affix multipliers (delegated — owned by Enemy GDD Formula 5)
**See Enemy GDD lines 248-266** for the full ordered specification including general-elite × 1.25 base. Restated here only as a cross-reference cue, NOT as a duplicate authority:
```
# Conceptual order (Enemy GDD Formula 5 is authoritative):
# 1. archetype.max_hp * 1.25 (general elite)
# 2. then × 1.45 (iron_bones, if affix present)  → final
# 3. archetype.move_speed * 1.25 (general elite)
# 4. then × 1.3 (swift, if affix present)        → final
```
**Worked example** (Shanxiao with iron_bones): max_hp = 110 × 1.25 × 1.45 = 199.4 (matches Enemy GDD AC-17).

### Formula 3: Immobilize per-frame velocity override (code-truth)
```
# In Immobilize._physics_process (immobilize.gd:71-89):
on _physics_process(_delta):
    for entry in _active_immobilizations:           # [{enemy, end_time}, ...]
        if not is_instance_valid(entry.enemy): drop entry
        elif now >= entry.end_time: drop entry
        elif "velocity" in entry.enemy:
            entry.enemy.set("velocity", Vector2.ZERO)  # OVERWRITES per frame
```
The mechanism is **per-frame velocity overwrite**, NOT a `move_speed_multiplier = 0` debuff. `enemy.set_immobilized()` does NOT exist in Enemy API.

### Formula 4: Effect lifetime accumulator (generic — applies to future DOT / slow / etc.)
```
# Future centralized service per-effect tick (when StatusEffect Resource service lands):
on _process(delta):
    for effect in _active_effects:
        effect.remaining -= delta
        if effect.tick_interval > 0 and now >= effect.next_tick:
            effect.on_tick.call(effect.target)        # via registry lookup
            effect.next_tick = now + effect.tick_interval
        if effect.remaining <= 0:
            effect.on_expire.call(effect.target)
            remove(effect)
```

## Edge Cases
- **Stacked immobilize** (same target re-immobilized): per Stacking Matrix above — refresh duration to `now + duration`, take max of all sources' end_times. Code does this via the per-target `_active_immobilizations` array (`immobilize.gd:113-122`).
- **Immobilize on Boss / Elite**: per `immobilize.gd:109-118` — Lv1-3 immobilize gets `0.5×` duration on Elites (per Stacking Matrix "different effect type" column); Boss is currently treated identically to Elite in v0.4 (TODO comment line 11: "Boss 简化为也完全定身（v0.4.x 加 stun_until 字段后再做'定妖印'差异化）"). Lv4 `_can_break_elite=true` removes the elite penalty.
- **Burn patch in same area as Bagua tick** (future): per Stacking Matrix — different effect types are independent. Both DOT and Bagua tick apply.
- **Elite affix on Boss**: not designed — affixes apply to Shanxiao Elite spawn only. Boss has its own attribute scaling per Boss System GDD.
- **Status effect applied to DYING target**: silently dropped per Rule 7 (Combat Core Rule 6 echo) — no stack, no signal, no error.
- **Pause state** (`get_tree().paused == true`): centralized StatusEffect service (when implemented) should pause its accumulator alongside game; immobilize.gd already pauses naturally via `_physics_process` honoring pause.

## Dependencies
| Dep | Type | Interface |
|---|---|---|
| **Combat** (C-03) | Hard | Status effects extend damage types |
| **Enemy** (C-04) | Hard | Status applied to enemy state (HP, speed, behavior) |
| **Weapon System** (FT-03) | Hard | Weapons trigger status (Bagua tick, Thunder burn) |
| **Active Skills** (FT-07, future) | Soft | Sun Wukong's 定身术 immobilize |

## Tuning Knobs
| Knob | Range | Default | Notes |
|---|---|---|---|
| Hit flash duration | 0.05 – 0.2s | 0.1s | Owned by Combat Feedback GDD (Combat Feedback Tuning Knobs line 69) |
| Burn tick interval | locked | 0.1s | **NOT a tuning knob** — engine constant per Combat GDD line 327 `BURN_TICK_INTERVAL = 0.1`; ADR amendment required to change |
| Immobilize Lv1 duration | 0.5 – 3s | 1.0s (code: `immobilize.gd:18`) | |
| Immobilize Lv2 duration | 0.5 – 3s | 1.3s (code: `immobilize.gd:48`) | |
| Immobilize Lv3 duration | 0.5 – 3s | 1.3s (code: `immobilize.gd:53`) | |
| Immobilize Lv4 duration | 0.5 – 3s | 1.8s (code: `immobilize.gd:62`) | |
| Immobilize Elite penalty | 0.3 – 1.0 | 0.5× (code: `immobilize.gd:115`) | Lv4 `_can_break_elite=true` bypasses this |
| Iron Bones HP multiplier | 1.0 – 2.0 | 1.45 (per Enemy GDD `iron_bones_health_multiplier`) | |
| Swift speed multiplier | 1.0 – 2.0 | 1.3 (per Enemy GDD `swift_speed_multiplier`) | |

## Acceptance Criteria

**AC-01** **RESERVED — activates when Combat Feedback GDD ships hit flash**. Currently AC-01 is unverifiable (Enemy.gd has no flash code). Will be: GIVEN enemy at full HP, WHEN `damage_taken(target, amount > 0)` fires, THEN sprite tints white for 0.1s. (Combat Feedback GDD revision-1 AC-01 is the authoritative version.)

**AC-02** **RESERVED — activates when burn DOT is implemented**. Will be: GIVEN Thunder Strike spawned on ground patch with `burn_dps=10` and `burn_duration=2.0`, WHEN burn accumulator runs, THEN at each 0.1s fixed-step interval (per Combat Formula 5 BURN_TICK_INTERVAL) target receives 1.0 damage; total over 2s = 20 damage. v0.4 Thunder Strike is visual-only — no DOT.

**AC-03** **GIVEN** Sun Wukong at position (0,0) at Lv1 with `_radius=150.0` and Player presses key 4, **WHEN** `Immobilize.cast(player)` runs, **THEN** all non-elite enemies within 150 px have their per-frame `velocity` forced to `Vector2.ZERO` for 1.0s AND `enemy.global_position.distance_to(previous_position) < ε` for each frame during that 1.0s window.

**AC-04** **GIVEN** Shanxiao archetype (`max_hp = 110`), **WHEN** spawned with `is_elite = true` AND `elite_affixes = ["iron_bones"]`, **THEN** final `max_hp = 110 × 1.25 × 1.45 = 199.375` (per Enemy GDD Formula 5; Enemy AC-17 is authoritative).

**AC-05** **GIVEN** Shanxiao Elite with `elite_affixes = ["iron_bones", "swift"]`, **WHEN** spawned, **THEN** both modifiers apply independently: `max_hp = 199.375` AND `move_speed = archetype_speed × 1.25 × 1.3`. Different effect types stack independently per Stacking Matrix.

**AC-06** **GIVEN** an enemy with `is_dying = true`, **WHEN** any status application attempted (immobilize, burn — future, etc.), **THEN** no stack created AND no signal emitted AND no error logged (silent drop per Rule 7 / Combat Core Rule 6).

**AC-07** **GIVEN** Lv1 Immobilize cast on a Shanxiao Elite, **WHEN** `immobilize.gd:109-118` evaluates `is_elite=true` AND `_can_break_elite=false`, **THEN** the immobilize end_time uses 0.5× duration (0.5 × 1.0 = 0.5s).

**AC-08** **GIVEN** Status Effects service is subscribed to `Combat.damage_dealt`, **WHEN** an event with `damage_type = TICK` fires (e.g. Bagua tick), **THEN** no burn stack is created (TICK delivers direct damage; no stack double-count).

**AC-09** **GIVEN** Status Effects service is subscribed to `Combat.damage_dealt`, **WHEN** an event with `damage_type = BURN` fires (future Thunder Strike), **THEN** a burn stack is created OR refreshed on `target` per the Stacking Matrix (different-source = independent stacks; same-source = refresh duration).

## Open Questions

- **OQ-1** (Extract StatusEffect Resource service): currently statuses are scattered (immobilize.gd in-weapon, configure_elite spawn-time, no DOT, no flash). A centralized service with the registry-of-named-handlers pattern (NOT Callable exports — those don't serialize in `.tres`) would unify. **Owner**: systems-designer + lead-programmer. **Target**: v0.5+.
- **OQ-2** (Status visual indicators): players don't currently see "this enemy is burning" / "this enemy is slowed" / "this elite is iron-bones'd" — only the underlying effect. Add per-status icons / sprite overlays. **Owner**: ux-designer + technical-artist. **Cross-reference**: VFX GDD §enemy-overlays must include status icon sprite spec when authored to revision-1. **Target**: VFX GDD authoring + v0.5 implementation.
- **OQ-3** ✅ RESOLVED in revision-1 — Stacking Matrix added to Detailed Rules.

## Registry Updates

Status effect constants worth registering in `design/registry/entities.yaml`:
- `burn_tick_interval = 0.1` (source: combat-system.md Formula 5; referenced_by: status-effects.md)
- `effect_id_namespace = ["burn", "slow", "immobilize", "iron_bones", "swift"]` (source: status-effects.md Rule 5)
- Per-archetype iron_bones / swift multipliers (currently inline in archetype .tres files — flag as TR-data candidate; Shanxiao = 1.45/1.3 baseline, no per-archetype overrides yet)
- Immobilize per-level durations: `{lv1=1.0, lv2=1.3, lv3=1.3, lv4=1.8}` (source: immobilize.gd:18/48/53/62)
- Immobilize elite penalty: `0.5×` (source: immobilize.gd:115)

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass; v0.4 has 6 status types but no centralized service (scattered inline). 6 ACs. 3 OQs: extract StatusEffect Resource, visual indicators, stacking semantics. |
| 1 | 2026-05-27 | /design-review revision-0 MAJOR REVISION (3 BLOCKERS + 3 RECOMMENDED + 3 NICE-TO-HAVE) | **B-1 closed**: Inventory table rewritten with honest ❌/🟡/✅ markers — flash and burn DOT are aspirational (NOT ✅), Bagua/Immobilize are 🟡 partial (work but lack pipeline integration), only elite affixes are ✅. Overview headers now lead with "1/6 fully implemented". Immobilize API corrected: no `set_immobilized()` exists; mechanism is per-frame velocity overwrite. **B-2 closed**: Stacking Matrix added to Detailed Rules (Immobilize / Burn / Multiplicative debuff / Elite affix × Same source / Different source / Different effect type — 12-cell matrix). OQ-3 marked RESOLVED. **B-3 closed**: all 9 ACs rewritten — AC-01/02 marked RESERVED with explicit unblock condition; AC-03 testable via observable velocity-zero rule; AC-04 anchored to Enemy AC-17; AC-05-09 in proper GIVEN/WHEN/THEN form. **R-1 closed**: Formula 2 demoted to cross-reference (Enemy GDD owns); Formula 3 rewritten to match code (velocity, not move_speed_multiplier); new Formula 4 (lifetime accumulator) added. **R-2 closed**: Tuning Knobs replaced fabricated immobilize 2.5s TBD with per-level 1.0/1.3/1.3/1.8 from code; Burn tick interval marked "NOT a tuning knob" engine const; added elite penalty knob. **R-3 closed**: Rule 6 Status Application Pipeline added — consumes `Combat.damage_dealt` signal contract (Combat GDD revision-2 line 207-214); AC-08/AC-09 defend the contract. **N-3 closed**: Registry Updates section expanded with 5 candidate entries. |
