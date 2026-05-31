# Consistency Check Report
Date: 2026-05-31
Registry entries checked: 14 entities, 0 items, 10 formulas, 9 constants
GDDs scanned: 28 (03_CORE_GAMEPLAY, 04_SKILL_DESIGN, 05_ENEMY_DESIGN, active-skills, audio-system, boss-system, camera-system, character-system, combat-feedback, combat-system, demon-seal, elements-five-phases, enemy-spawning, enemy-system, experience-progression, ghost-market-trade, input-system, level-up-pool, pickup-system, player-system, resource-data-framework, run-state, stage-2-enemies, stage-director, status-effects, targeting-system, vfx-system, weapon-system)
Scan trigger: post-/art-bible session 2026-05-31

---

## Conflicts Found (must resolve before architecture)

### 🔴 CONFLICT GROUP A — D-B1 Enemy Damage ×2.0 Buff: enemy-system.md archetype table not updated

**Background**: `combat-system.md` revision-5 (2026-05-27) selected D-B1 path(a) — `×2.0` damage multiplier across all 7 Stage-1 enemy archetypes. All `.tres` files and `entities.yaml` were explicitly updated at that time (per revision-5 status line). However, **`enemy-system.md`** was NOT updated.

**Registry (authoritative — source: entities.yaml, revised 2026-05-27)**:

| Enemy | damage (post-D-B1) |
|-------|---|
| paper_doll | 10.0 |
| wandering_soul | 16.0 |
| fox_spirit | 14.0 |
| ghost_flame | 12.0 |
| stone_golem | 24.0 |
| shanxiao_elite | 30.0 |
| famine_beast | 36.0 |

**Conflict in `enemy-system.md:112-118`** — archetype reference table still shows pre-D-B1 values:

| Archetype | damage (stale) |
|---|---|
| paper_doll.tres | 5.0 |
| wandering_soul.tres | 8.0 |
| fox_spirit.tres | 7.0 |
| ghost_flame.tres | 6.0 |
| stone_golem.tres | 12.0 |
| shanxiao_elite.tres | 15.0 |
| famine_beast.tres | 18.0 |

**Additional stale locations in `enemy-system.md`**:
- **Line 120** (cross-doc note): "these values match `design/registry/entities.yaml` 1:1" — **FALSE** after D-B1. Note references "Combat GDD revision-4" which predates the buff.
- **AC-01 (line 433)**: `damage = 5.0` for paper_doll — should be `10.0`
- **AC-16 (line 471)**: `damage = 15 × 1.2 = 18.0` for Shanxiao Elite base — base archetype should be 30.0; post-elite multiply = `30.0 × 1.2 = 36.0`
- **AC-17, AC-18 (lines 473-475)**: `damage = 18.0` for Shanxiao Elite post-affix — should be 36.0

→ **Resolution**: Update `enemy-system.md`:
  1. Archetype table (lines 112-118): replace all 7 damage values with post-D-B1 values
  2. Cross-doc note (line 120): update to reference "Combat GDD **revision-5**" and remove false ✅
  3. AC-01 (line 433): damage = 5.0 → 10.0
  4. AC-16 (line 471): base damage 15 → 30; post-multiply = 36.0
  5. AC-17, AC-18: update all 18.0 damage references to 36.0

---

### 🔴 CONFLICT GROUP B — boss-system.md Famine Beast damage reference not updated

**Registry**: `famine_beast.damage = 36.0` (revised 2026-05-27, D-B1 path(a) ×2.0)

**Conflict in `boss-system.md:36`**: `- damage = 18 (NOT 16)` — the "(NOT 16)" correctly distinguishes from Stage Director dead-code default, but 18.0 itself is now the stale pre-D-B1 value.

**Conflict in `boss-system.md:164`** (Tuning Knobs table): `| damage (archetype) | 200 – 800 | 18 | Lethality per hit` — default should be 36.

→ **Resolution**: Update `boss-system.md`:
  1. Line 36: `damage = 18` → `damage = 36` (note: revised in D-B1 path(a) ×2.0, 2026-05-27)
  2. Tuning Knobs table line 164: default `18` → `36`

**Note**: The `burst_damage = 18.0` (Boss ability tuning knob, `enemy-system.md:378`) is a **separate value** from the archetype contact-damage — it is the Boss's Burst special-ability damage, unaffected by the D-B1 contact-damage buff. This is NOT a conflict.

---

### 🔴 CONFLICT GROUP C — combat-system.md example and ACs not updated to post-D-B1 Stone Golem damage

`combat-system.md` revision-5 updated the Pressure Curve section (Famine Beast `dmg=36 r5`, Wandering Soul `dmg=16 r5`) but did NOT update the concrete ACs and inline examples that reference Stone Golem damage.

**Registry**: `stone_golem.damage = 24.0`

**Conflict in `combat-system.md:246`** (Formula 1 example):
> "A 修行者 with `current_hp = 28.0` is hit by a Stone Golem for `raw_damage = 12.0`..."
→ raw_damage should be `24.0`

**Conflict in `combat-system.md:526`** (AC-10):
> "Stone Golem (`damage = 12, damage_interval = 1.0`)"
→ damage should be `24`

**Conflict in `combat-system.md:527-528`** (AC-11):
> "Stone Golem (`damage = 12, damage_interval = 1.0`)"
→ damage should be `24`

→ **Resolution**: Update `combat-system.md`:
  1. Line 246: `raw_damage = 12.0` → `24.0`; result `16.0` → `4.0` (28 - 24 = 4)
  2. AC-10 (line 526): `damage = 12` → `damage = 24`
  3. AC-11 (line 527): `damage = 12` → `damage = 24`

---

## Stale Registry Entries

None — registry is the authoritative source and was updated as part of combat-system.md revision-5 (2026-05-27). The GDDs are stale relative to the registry.

---

## Unverifiable References (no conflict, informational)

ℹ️ `enemy-system.md` mentions `stage_duration_seconds = 300` (line 512) — Stage 1 duration. `boss-system.md` notes Stage 2 uses 180s (3:00) per StageTwoConfig. The registry constant `stage_duration_seconds = 300` correctly represents Stage 1's duration; Stage 2 uses a config-level override. No conflict.

ℹ️ `experience-progression.md` xp_drop_value references (Paper Doll 3.5, Wandering Soul 5.5, Fox Spirit 6.0, Ghost Flame 6.0, Stone Golem 12.0, Shanxiao Elite 22.0, Famine Beast 0) — all match registry ✅. XP values were NOT affected by the D-B1 damage buff.

ℹ️ `combat-system.md` Phase-TTK pressure curve references (line 53: Famine Beast `dmg=36`, line 49: Wandering Soul `dmg=16`) match registry ✅ — Pressure Curve section was updated in revision-5.

ℹ️ `run-state.md:422` cross-doc check references `stage_duration = 300.0` ✅ and `famine_beast.tres max_hp=360` ✅ — but also says `damage=18` (stale — see Conflict Group B above for boss-system.md; run-state.md itself does not state the damage value, so this is informational only).

---

## Clean Entries (no issues found)

✅ blood_pact_damage_per_stack = 0.15 — ghost-market-trade.md matches registry
✅ blood_pact_max_stacks = 3 — ghost-market-trade.md and level-up-pool.md match registry
✅ trade_stall_count_per_run = 4 — ghost-market-trade.md matches registry
✅ famine_beast.max_hp = 360 — boss-system.md, combat-system.md, enemy-system.md all agree
✅ ghost_market_judge (max_hp=480, damage=40, move_speed=64) — boss-system.md, stage-2-enemies.md match
✅ All Stage 2 enemies (lantern_ghost, resentful_infant, ghost_bailiff, tomb_guardian, impermanence_elite) — stage-2-enemies.md matches registry
✅ xp_drop_values (all 7 Stage 1 enemies) — experience-progression.md, enemy-system.md match registry
✅ demon_seal_spawn_time = 120 — stage-director.md matches registry
✅ demon_seal_duration = 8 — demon-seal.md matches registry
✅ max_contact_attackers = 4 — combat-system.md matches registry
✅ target_framerate = 60 — matches across all referencing GDDs
✅ player_xp_curve formula — player-system.md matches registry
✅ All Combat System formulas (damage_application, weapon_dps, multi_target, burn, pierce, aggregate_ceiling) — no cross-doc conflicts detected

---

## Verdict: CONFLICTS FOUND

**3 conflict groups detected**, all in the same root cause: `combat-system.md` revision-5 (D-B1 path(a), 2026-05-27) updated the registry and its own Pressure Curve section but did NOT propagate the damage ×2.0 change to `enemy-system.md` (archetype table + ACs) or `boss-system.md` (Famine Beast damage reference).

**Affected files to fix**:
1. `design/gdd/enemy-system.md` — 7 damage values in table, 4 AC references, cross-doc note
2. `design/gdd/boss-system.md` — 2 locations (narrative line 36, Tuning Knobs default)
3. `design/gdd/combat-system.md` — 3 locations (line 246 example, AC-10, AC-11)

**Impact**: These stale damage values would mislead architects authoring ADRs for combat balance or developers writing unit tests against GDD examples. They should be corrected before `/create-architecture`.

**No registry updates required** — registry was correctly updated by revision-5.
