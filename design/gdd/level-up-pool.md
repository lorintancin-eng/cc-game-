# Level Up & Upgrade Pool System

> **Status**: Approved (revision-2 — addresses D-B2 from /review-all-gdds 2026-05-27: per-upgrade stack cap added, OQ-2 RESOLVED). **Code landed 2026-05-29** (commit 063da34): `_upgrade_pick_count` + `_get_upgrade_max_stacks` + `_get_upgrade_pool` cap filter in `scripts/player/player.gd`; regression tests in `tests/unit/player/upgrade_stack_cap_test.gd`. Cap values remain GDD starting points — playtest-tunable per Rule 6 / line 213.
> **Author**: claude (revision-2 by claude — adds max_stacks contract; Combat 5× ceiling now a hard cap enforced at pool generation)
> **Last Updated**: 2026-05-29 (D-B2 code implementation landed)
> **Implements Pillar**: Pillar 2 (auto-battle + meaningful construction choices — Level Up IS the construction-decision moment)
> **TR Coverage**: TR-core-004 (pause + 3-choice UI), TR-wpn-003 (pool filtered by character/weapons)
> **Layer**: Progression / UI (depends on Run State, Player, Experience, Character System)

## Overview

Level Up & Upgrade Pool is the **construction-choice moment** that punctuates every 30-60 seconds of gameplay. When Player crosses an XP threshold (per Player GDD Formula 3), Experience emits `level_reached(N)`; Player opens the LevelUpPanel (a CanvasLayer); the pool generates 3 random upgrade options filtered by current character/weapon state; player clicks one; `upgrade_applied(upgrade_id)` fires; Player's `_apply_upgrade` match statement mutates state.

This is the **only system that intentionally pauses the run** — game tree is paused while panel is visible, resuming on selection. It is the breath between waves of pressure.

**Important code-reality finding**: the upgrade pool is **hardcoded in Player.gd** (`_get_upgrade_pool()` returns a hardcoded array of dicts; `_apply_upgrade` has a match statement with hardcoded deltas). This violates Pillar 4 (data-driven) — per Player GDD OQ-6 + Resource Data Framework GDD's compliance audit (Pillar-4 audit row "Upgrade definitions: NON-COMPLIANT — hardcoded match"). Resolution: extract to `resources/upgrades/*.tres`. **OQ-1 here.**

Reference: Player GDD Formula 4 (XP accrual + level threshold), Experience GDD (XP source), Combat GDD (weapons being upgraded), 04_SKILL_DESIGN.md §9 (upgrade pool filter design intent), ADR-0003 (Sun Wukong active-skill upgrades).

## Player Fantasy

Level Up is the **decision-laden pause**. The player has been moving, dodging, watching — now they stop. Three options appear:

> "Three choices: 'Talisman damage +10', 'Movement speed +10%', or 'Unlock Flying Sword'. I have Talisman maxed already — taking another damage upgrade would be marginal. Speed sounds tempting; I've been getting hit a lot. But Flying Sword is the construction-defining decision — if I take it now, my entire build pivots. I pick Flying Sword. The panel closes; the run resumes; I can see the new sword orbiting me already."

When Level Up works invisibly, the player feels:
- **Meaningful agency** — the 3 choices are different enough that the choice matters
- **Construction emerges** — over 6-10 level-ups in a run, the player can see their build shape
- **Earned pause** — the run paused because YOU did something (killed enemies, gathered XP), not because the game interrupted you
- **Anticipation of resolution** — every choice changes the next 60 seconds of play

Anti-fantasy: random options that all feel equivalent ("3 different damage +N choices"), pool filtering that's invisible (player doesn't know why their unlock didn't appear), panel that pops up at bad moments and can't be cancelled.

## Detailed Rules

### Core Rules

1. **Run pauses while LevelUpPanel is visible**. `get_tree().paused = true` is set by Player when panel opens; restored to previous state (usually false) on selection. LevelUpPanel itself has `process_mode = PROCESS_MODE_WHEN_PAUSED` so its UI logic continues running during pause.

2. **Exactly 3 options per level-up** (or fewer if pool is exhausted). `_get_random_upgrade_options()` runs Fisher-Yates shuffle on the full pool, takes first 3.
   - **EXCEPTION (v0.5 — Merit System Node 3)**: if Merit Node 3 (灵光一闪) is purchased (meta-progression, `merit-system.md`), the **first level-up of the run** offers **4 options** instead of 3 (one-time per run; subsequent level-ups revert to 3). The panel must support a **variable choice count (3 or 4)** rather than a fixed 3-button layout. Source of truth: `merit-system.md` Node 3 (灵光一闪).

3. **Upgrade pool is dynamically filtered by character/weapon state**:
   - Always-present: 4 Talisman upgrades + 4 Player attribute upgrades (max_hp, move_speed, pickup_radius, xp_gain)
   - **Locked behind unlock-upgrades**: Flying Sword (4 upgrades), Thunder Law (4 + 1 unlock), Bagua Array (4 + 1 unlock), Explosive Talisman (4 + 1 unlock), Mountain Seal (likely + 1 unlock)
   - Each weapon's upgrades appear in pool **only if** that weapon is currently unlocked (`_is_<weapon>_unlocked` flag set true)
   - Per TR-wpn-003: upgrades stay locked behind character/weapon ownership

4. **Pool RNG is deterministic via `upgrade_random_seed = 2401`** (Player.tscn). Two runs with same seed see identical level-up sequences (per Player GDD Core Rule 8).

5. **Multi-level carry-over** (Player GDD Formula 4): if a single `gain_experience` call crosses multiple thresholds, `_pending_upgrade_choices` queue stacks. Each level-up shows its own 3-choice panel; queue drains one at a time.

6. **Per-upgrade stack cap** (D-B2 resolution — enforces Combat GDD 5× source_modifier ceiling as a hard cap, not advisory):
   - Each upgrade definition declares a `max_stacks: int` field (added to UpgradeDefinition contract in OQ-1 refactor; v0.4 implements via parallel `_upgrade_pick_count: Dictionary` keyed by upgrade_id).
   - **Caps by category** (closes D-B2 from /review-all-gdds 2026-05-27):
     - Weapon damage upgrades (UPGRADE_TALISMAN_DAMAGE, UPGRADE_FLYING_SWORD_DAMAGE, UPGRADE_BAGUA_DAMAGE, UPGRADE_THUNDER_DAMAGE, UPGRADE_EXPLOSIVE_DAMAGE, UPGRADE_MOUNTAIN_DAMAGE): **`max_stacks = 3`** (3 stacks of +10 on base-8 weapon = 38 damage = **4.75× multiplier — within Combat 5× ceiling**)
     - Weapon cooldown upgrades (UPGRADE_TALISMAN_COOLDOWN, UPGRADE_*_COOLDOWN): **`max_stacks = 5`** (5 stacks × 0.9 multiplicative = 0.59× cooldown ≈ 1.7× firing rate — safe; pairs with damage cap to stay under 5× total DPS)
     - Pierce upgrades (UPGRADE_FLYING_SWORD_PIERCE): **`max_stacks = 2`** (linear DPS scaling vs clusters per D-W1 dominant-strategy concern — 2 stacks = base + 2 pierce + 1 baseline = 4 hits per swing max; capped to prevent 8-pierce cluster wipe)
     - Projectile count upgrades (UPGRADE_*_COUNT): **`max_stacks = 3`**
     - Player HP upgrades (UPGRADE_MAX_HP): **`max_stacks = 5`** (5 stacks × +20 = 200 bonus HP, ceiling 300 total — bounded for Pressure Curve)
     - Player speed/pickup/xp_gain upgrades: **`max_stacks = 5`** (×1.5 max cumulative)
     - Weapon unlock upgrades (UPGRADE_UNLOCK_FLYING_SWORD, etc.): **`max_stacks = 1`** (one-shot — disappears after taken; further unlocks for that weapon are excluded by `_is_<weapon>_unlocked` flag check per Rule 3)
   - **Enforcement**: `_get_upgrade_pool()` filters out any upgrade where `_upgrade_pick_count[upgrade_id] >= max_stacks`. The cap is checked BEFORE the shuffle so capped upgrades never reach the panel.
   - **Pool exhaustion edge case**: if ALL upgrades are at max_stacks (theoretical late-run scenario), pool returns empty → panel shows 0 buttons → soft-lock. Mitigated in practice: 8 always-present × 5 max = 40 picks before exhaustion (more levels than a 5-min run produces). See AC-13 + Edge Case below.

6. **Sun Wukong active-skill choices** (parallel queue): Sun Wukong v2 (`ActiveSkillCharacter`) gains additional skill-choice queues at levels 5/10/15/20 (per W211 design). `_pending_skill_choices` separate from `_pending_upgrade_choices`. After regular upgrade queue drains, skill choice queue activates if character is ActiveSkillCharacter and skills aren't at cap (Lv4).

7. **Upgrade application is hardcoded** (Player GDD OQ-6 + Resource Data GDD compliance gap): `_apply_upgrade` is a long match statement with per-upgrade-ID code (e.g. `_talisman_weapon.damage += 10.0` for UPGRADE_TALISMAN_DAMAGE). Delta values are NOT data-driven — they live in code. Tech debt.

8. **`upgrade_applied(upgrade_id)` signal fires after application**, allowing HUD/analytics/other systems to observe what was picked.

### Upgrade Pool Composition (v0.4 hardcoded)

**Always-present (8 entries)**:
| Upgrade ID | Title (zh) | Delta | Description |
|---|---|---|---|
| `talisman_damage` | 追魂符威力 +10 | weapon.damage += 10 | Per-upgrade |
| `talisman_cooldown` | 追魂符施放 -10% | cooldown × 0.9 | Per-upgrade |
| `talisman_count` | 追魂符数量 +1 | projectile_count += 1 | |
| `talisman_speed` | 追魂符飞行 +15% | projectile_speed × 1.15 | |
| `max_hp` | 气血上限 +20 | max_hp += 20 + heal | Player |
| `move_speed` | 身法 +10% | move_speed × 1.10 | Player |
| `pickup_radius` | 摄取范围 +18 | pickup_radius_bonus += 18 | Player |
| `xp_gain` | 修为获取 +10% | xp_gain_multiplier × 1.10 | Player |

**Behind weapon unlocks** (each adds 4 upgrades to pool when unlocked):
- Flying Sword: damage +8, cooldown -10%, pierce +1, count +1
- Thunder Law: damage +8, cooldown -10%, radius +20, target_count +1
- Bagua Array: damage +5 (per tick), radius +15, rotation +20%, tick_rate -10%
- Explosive Talisman: radius +12, damage +8, count +1, cooldown -10%

**Sun Wukong active-skill upgrades** (per ADR-0003): at Sun Wukong levels 5/10/15/20, an additional skill-choice panel offers 3 active-skill upgrades. Each skill (毫毛分身, 筋斗云, 七十二变, 定身术) has Lv1→Lv4 upgrades. Per `ActiveSkillCharacter.get_skill_choices()`.

### Five Phases Element Tag (v0.5 — UpgradeDefinition `element` field)

The Five Phases Synergy System (`elements-five-phases.md`) requires each upgrade to carry a Five Phases (五行) element so that level-up selections can drive generating-cycle (相生) combos. Each `UpgradeDefinition` gains an **`element: String`** field (added alongside the OQ-1 `.tres` refactor; until then, assigned in parallel by `upgrade_id` like `max_stacks`).

**Assignment rule** (source of truth: `elements-five-phases.md` §Integration with Upgrade Pool):

| Upgrade category | Element (五行) |
|---|---|
| Weapon upgrades — Talisman / Explosive Talisman | fire (火) |
| Weapon upgrades — Flying Sword | metal (金) |
| Weapon upgrades — Thunder Law | water (水) |
| Weapon upgrades — Bagua Array / Mountain Seal | earth (土) |
| Player attribute upgrades — max_hp, move_speed, pickup_radius, xp_gain | wood (木) |
| Weapon unlock upgrades (UPGRADE_UNLOCK_<weapon>) | the unlocked weapon's element (per the rows above) |

- Weapon upgrades **inherit their weapon's element**; weapon-unlock upgrades carry that same weapon's element.
- The **LevelUpPanel displays the element icon per option** and shows a **"相生!" combo-proximity hint** when an option would activate a new generating-cycle combo (per Five Phases generating-cycle: 木→火→土→金→水→木).

### Pool Filter Logic

```python
def _get_upgrade_pool():
    pool = [<8 always-present upgrades>]
    
    if _is_flying_sword_unlocked:
        pool.extend(<4 FlyingSword upgrades>)
    elif not _is_flying_sword_unlocked:
        pool.append({"id": UPGRADE_UNLOCK_FLYING_SWORD, "title": "解锁 飞剑"})
    
    # Same pattern for Thunder Law, Bagua, Explosive Talisman, Mountain Seal
    
    return pool
```

Each weapon's unlock-upgrade is in the pool until it's taken; thereafter, its 4 upgrade variants appear.

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Player** (C-01, Approved) | Bidirectional | Player owns `_get_upgrade_pool()`, `_apply_upgrade()`, `_is_<weapon>_unlocked` flags; emits `upgrade_applied` |
| **Experience & Progression** (FT-04, Approved) | Experience → Level Up | `level_reached(N)` opens panel |
| **Run State** (F-03, Approved) | Level Up → Run State | `get_tree().paused = true` while panel visible |
| **Weapon System** (FT-03, Designed) | Level Up → Weapon | Upgrades mutate weapon node state (damage, cooldown, count, etc.) |
| **Character System** (FT-06, future) | Character → Level Up | Active-skill upgrades only for ActiveSkillCharacter subclass (Sun Wukong v2) |
| **Active Skills** (FT-07, future) | Active Skills → Level Up | Skill-choice panel queue + Lv1-Lv4 upgrade variants |
| **HUD** (P-01, future) | Level Up → HUD | `upgrade_applied(id)` for toast / icon feedback |

## Formulas

### Formula 1: Pool selection (Fisher-Yates + take 3)

```python
options = _get_upgrade_pool()                     # filtered pool
for i in range(options.size - 1, 0, -1):          # Fisher-Yates shuffle
    swap = _upgrade_rng.randi_range(0, i)
    options[i], options[swap] = options[swap], options[i]

return options[:3]                                # take first 3
```

**Variables:**

| Variable | Type | Range | Description |
|---|---|---|---|
| `options` | Array[Dictionary] | size 5 – 30 | Filtered pool entries |
| `_upgrade_rng` | RandomNumberGenerator | seeded by `upgrade_random_seed = 2401` | Deterministic |

**Output:** exactly 3 unique options (or fewer if pool < 3, which shouldn't happen in v0.4 with 8 always-present).

**Determinism**: same seed + same pool state (= same weapon-unlock pattern) → same 3 options every time. Pairs with EnemySpawner.random_seed = 1301 for full replay.

### Formula 2: Upgrade delta application (hardcoded match)

```gdscript
match upgrade_id:
    UPGRADE_TALISMAN_DAMAGE:
        if _talisman_weapon != null: _talisman_weapon.damage += 10.0
    UPGRADE_TALISMAN_COOLDOWN:
        if _talisman_weapon != null: _talisman_weapon.cooldown *= 0.9
    UPGRADE_MAX_HP:
        max_hp += 20
        current_hp = min(current_hp + 20, max_hp)
    ...
```

Each upgrade has hardcoded delta. **Pillar 4 violation** per Player GDD OQ-6 / Resource Data GDD audit. Tech debt — extract to `.tres`.

### Formula 3: Queue draining (multi-level + skill chain)

```
on _on_panel_upgrade_selected(upgrade_id):
    _apply_upgrade(upgrade_id)
    upgrade_applied.emit(upgrade_id)
    
    if _pending_upgrade_choices > 0:
        _pending_upgrade_choices -= 1
        # show next regular upgrade panel
    elif _pending_skill_choices > 0 AND character is ActiveSkillCharacter:
        # show skill-choice panel
    else:
        # all queues drained, resume run
        get_tree().paused = _was_tree_paused_before_level_up
```

Queue drains sequentially. Sun Wukong v2 can stack regular + skill choices per gain_experience burst.

### Formula 4: Cumulative DPS impact per upgrade stack (with revision-2 caps applied)

**Pre-revision-2 (BROKEN — exceeded Combat 5× ceiling)**:
```
base damage = 8.0
4 × UPGRADE_TALISMAN_DAMAGE (+10) = 48 damage  → 6× multiplier — VIOLATES Combat 5× warning
```

**Post-revision-2 (CAPPED per Rule 6)**:
```
base damage = 8.0
max 3 × UPGRADE_TALISMAN_DAMAGE (+10) = 38 damage  → 4.75× multiplier (within Combat 5× ceiling)
cooldown 0.9 × 0.9^5 = 0.531  → 1.69× firing rate (capped at 5 stacks)
combined DPS = 38 / 0.531 ≈ 71.5 DPS (vs base 8.9 DPS) → 8.0× DPS over base

BUT — damage multiplier alone = 4.75× (within Combat ceiling)
       cooldown contribution = 1.69× separate axis (not source_modifier)
       Combat 5× warning is specifically about source_modifier × crit_multiplier — passes.
```

**Worked example for Flying Sword + pierce cap (D-W1 dominant-strategy mitigation)**:
```
base = 8 damage, pierce_count = 0 (base), cooldown = 0.9
+ 2 × UPGRADE_FLYING_SWORD_PIERCE (cap) → pierce_count = 2 → max 3 hits per swing (initial + 2 pierce)
+ 3 × UPGRADE_FLYING_SWORD_DAMAGE = 38 damage per hit
+ 5 × UPGRADE_FLYING_SWORD_COOLDOWN = 0.531s cooldown
DPS (per-target single contact) = 38 / 0.531 = 71.5 DPS
DPS (cluster, 3 enemies in pierce line) = 71.5 × 3 = 214.5 DPS  → still strong but capped
                                                                  vs uncapped 8 pierce × ... = unbounded
```

**Verification via /balance-check post-playtest**: caps should be tuned (not eliminated) if playtest shows builds feel under-powered. The caps in Rule 6 are starting values per D-B2 resolution — adjustable in revision-3 after playtest data.

## Edge Cases

- **If Player levels up while Level Up panel is already open** (queue mode): `_pending_upgrade_choices` increments; next panel opens after current selection.
- **If Player dies during panel** (panel visible when `_is_dead = true`): per Player GDD AC-12, `gain_experience` early-returns, so `level_reached` doesn't re-fire. But if the panel was already open from before death, the player can still click — `_apply_upgrade` mutates state, `upgrade_applied` emits. Defensive but slightly odd (dead player picks an upgrade). Run is over anyway.
- **If pool is empty** (`_get_upgrade_pool()` returns empty): `_get_random_upgrade_options` returns empty array. Panel `show_choices(empty)` displays 0 visible buttons. Player can't proceed — soft-locks. Should never happen with v0.4's 8 always-present upgrades.
- **If pool has fewer than 3 entries**: `min(3, options.size())` clamps. Panel shows fewer buttons. Acceptable degraded state.
- **If `upgrade_selected` is clicked but `upgrade_id` is empty StringName**: panel ignores via `if String(_option_ids[index]).is_empty(): return` guard. Defensive.
- **If `level_up_panel_scene` is null** (Player.tscn misconfigured): `_ensure_level_up_panel` push_errors. Level-up still increments level but no panel opens — soft-lock at next level.
- **If two `level_reached` signals fire simultaneously** (multi-level XP burst): `_pending_upgrade_choices` tracks count; queue handles serially.
- **If Sun Wukong levels up but is at Lv4 on all 4 skills**: `get_skill_choices()` returns empty; skill-choice queue skips. Regular upgrade panel proceeds normally.
- **If character switches mid-run** (impossible in v0.4 — character is locked at run start): the unlocked-weapon flags would persist incorrectly. Edge case prevented by run-lifecycle.
- **If Player has no weapon equipped**: pool only contains 4 Player attribute upgrades (no weapon-specific options). 3-choice panel still works.
- **If the same upgrade is taken multiple times** (stacking): each `_apply_upgrade` call applies the delta cumulatively. Per Rule 6 (revision-2), an upgrade is removed from the pool once `_upgrade_pick_count[upgrade_id] >= max_stacks`. Example: UPGRADE_TALISMAN_DAMAGE can be taken 3× max (+30 damage), then removed from pool.
- **If all upgrades reach max_stacks** (theoretical late-run): `_get_upgrade_pool()` returns empty filtered set → panel shows 0 buttons. In practice the 8 always-present × 5 stacks = 40 picks before exhaustion; a 5-minute run produces ~6-12 levels — exhaustion not reached. Defensive fallback: if pool empty, panel auto-closes and `get_tree().paused = false` (no soft-lock). See AC-13.

## Dependencies

| Dependency | Type | Direction | Interface |
|---|---|---|---|
| **Player** (C-01, Approved) | Hard | Bidirectional | Player owns pool generation + application; Level Up panel emits `upgrade_selected` |
| **Experience & Progression** (FT-04, Approved) | Hard | Experience → Level Up | `level_reached(N)` signal triggers panel open |
| **Run State** (F-03, Approved) | Hard | Bidirectional | Pause/resume game tree during panel |
| **Weapon System** (FT-03, Designed) | Hard | Level Up → Weapon | Upgrade application mutates weapon node fields |
| **Character System** (FT-06, future) | Hard | Character → Level Up | Active-skill upgrades for ActiveSkillCharacter |
| **Active Skills** (FT-07, future) | Soft | Active Skills → Level Up | Skill-choice panel queue (Sun Wukong v2 Lv5/10/15/20) |
| **HUD** (P-01, future) | Soft | Level Up → HUD | `upgrade_applied` for toast/icon |
| **Resource Data Framework** (F-02, Approved) | Soft (future) | Currently NOT compliant | Future: extract upgrade definitions to `.tres` |
| **Five Phases Synergy** (v0.5) | Soft | Depended-on-by (Five Phases → Level Up) | Each UpgradeDefinition exposes an `element` tag; LevelUpPanel renders element icons + "相生!" combo-proximity hints (see Five Phases Element Tag section) |
| **Merit System** (v0.5) | Soft | Depended-on-by (Merit → Level Up) | Node 3 (灵光一闪) drives a variable choice count (3 or 4) on the first level-up of a run (Rule 2 exception); "Unseal" nodes add weapons to the base pool and remove the corresponding in-run unlock upgrades |

**Bidirectional check:**
- Player GDD lists Level Up as "Level Up & Upgrade Pool (FT-05) | Soft | Player ↔ Pool" ✅
- Experience GDD lists Level Up as downstream (when level_reached fires) ✅
- Weapon System GDD lists Level Up as upgrade-application consumer ✅
- Five Phases Synergy GDD (`elements-five-phases.md`) depends on Level Up for per-upgrade `element` tags + combo hints ✅ (depended-on-by)
- Merit System GDD (`merit-system.md`) depends on Level Up for Node 3 variable choice count + "Unseal" pool changes ✅ (depended-on-by)

## Tuning Knobs

| Knob | Owner | Design-safe range | Default | Effect at extremes |
|---|---|---|---|---|
| Number of choices per panel | LevelUpPanel.tscn (3 buttons) | 3 (locked) | 3 | <3 = no choice; >3 = decision fatigue |
| `upgrade_random_seed` | Player.tscn | any int | 2401 (dev) | Production randomizes per run |
| Per-upgrade delta (e.g. TALISMAN_DAMAGE = +10) | Hardcoded in `_apply_upgrade` | varies per upgrade | various | (Pillar 4 violation; OQ-1) |
| Always-present pool size | Hardcoded in `_get_upgrade_pool()` | 5 – 15 | 8 | <5 = repetitive; >15 = no clear identity |
| Pool entries per weapon (after unlock) | Hardcoded | 3 – 6 | 4 | More variety vs noise tradeoff |
| Sun Wukong skill-choice levels | hardcoded | varies | 5, 10, 15, 20 (every 5) | (locked design) |
| **`max_stacks` for damage upgrades** | UpgradeDefinition.tres | 2 – 5 | **3** | <2 = too restrictive; >5 violates Combat 5× ceiling |
| **`max_stacks` for cooldown upgrades** | UpgradeDefinition.tres | 3 – 7 | **5** | Multiplicative 0.9^N; 5 = 1.69× firing rate cap |
| **`max_stacks` for pierce upgrades** | UpgradeDefinition.tres | 1 – 3 | **2** | Linear cluster-DPS scaling (D-W1 concern); cap prevents 8-pierce wipe |
| **`max_stacks` for projectile count upgrades** | UpgradeDefinition.tres | 2 – 4 | **3** | Pairs with cooldown for total throughput |
| **`max_stacks` for HP upgrades** | UpgradeDefinition.tres | 3 – 7 | **5** | 5×+20 = 200 bonus HP (ceiling 300 total) |
| **`max_stacks` for speed/pickup/xp_gain upgrades** | UpgradeDefinition.tres | 3 – 7 | **5** | ×1.5 max cumulative |
| **`max_stacks` for weapon-unlock upgrades** | UpgradeDefinition.tres | 1 (locked) | **1** | One-shot; further excluded by `_is_<weapon>_unlocked` flag |

Most tuning is currently hardcoded — see OQ-1 for migration path.

## Acceptance Criteria

**AC-01** **GIVEN** Player at Level 1 with current_xp = 0 AND `level_reached(2)` fires, **WHEN** the panel opens, **THEN** `get_tree().paused = true` AND 3 distinct upgrade options are displayed AND first button has keyboard focus.

**AC-02** **GIVEN** the panel displays 3 options, **WHEN** player clicks option index 1, **THEN** `_on_panel_upgrade_selected(<id_of_option_1>)` fires AND `_apply_upgrade(<id>)` mutates state AND `upgrade_applied(<id>)` signal fires AND panel hides AND `get_tree().paused = false`.

**AC-03** **GIVEN** UPGRADE_TALISMAN_DAMAGE is selected, **WHEN** applied, **THEN** Talisman weapon's `damage` field is incremented by 10.0 (per Player GDD AC-13 + this GDD's Formula 2).

**AC-04** **GIVEN** UPGRADE_MAX_HP is selected, **WHEN** applied, **THEN** Player's `max_hp` increases by 20 AND `current_hp` is set to `min(current_hp + 20, max_hp)` AND `health_changed(current_hp, max_hp)` emits.

**AC-05** **GIVEN** `_is_flying_sword_unlocked = false`, **WHEN** `_get_upgrade_pool()` runs, **THEN** UPGRADE_UNLOCK_FLYING_SWORD IS in pool AND UPGRADE_FLYING_SWORD_DAMAGE is NOT.

**AC-06** **GIVEN** `_is_flying_sword_unlocked = true` (after taking unlock), **WHEN** `_get_upgrade_pool()` runs, **THEN** all 4 Flying Sword upgrades ARE in pool AND UPGRADE_UNLOCK_FLYING_SWORD is NOT.

**AC-07** **GIVEN** Player reaches Level 5 as Sun Wukong v2 (ActiveSkillCharacter), **WHEN** regular upgrade queue drains, **THEN** `_pending_skill_choices` activates AND skill-choice panel opens with up to 3 skill options (from `ActiveSkillCharacter.get_skill_choices()`).

**AC-08** **GIVEN** same `upgrade_random_seed = 2401` across two runs AND same XP cadence AND same weapon unlock pattern, **WHEN** both runs reach Level 2, **THEN** the 3 options shown are identical (determinism for /balance-check replay).

**AC-09** **GIVEN** Player gains XP large enough to cross 2 levels at once, **WHEN** queue processes, **THEN** 2 panels open sequentially (one for level 2, one for level 3) AND each gets its own 3-choice generation.

**AC-10** **GIVEN** `_get_upgrade_pool()` returns 8 always-present + 0 weapon-specific (no weapons unlocked beyond Talisman), **WHEN** options are generated, **THEN** 3 unique options from those 8 are shown.

**AC-11** **GIVEN** UPGRADE_TALISMAN_DAMAGE has been selected 3 times (at cap per Rule 6) across the run, **WHEN** the next level-up's `_get_upgrade_pool()` runs, **THEN** UPGRADE_TALISMAN_DAMAGE is NOT in the pool (filtered out because `_upgrade_pick_count["UPGRADE_TALISMAN_DAMAGE"] == 3 >= max_stacks`) AND Talisman weapon's `damage` is base + 30 = 38 (within Combat 5× source_modifier ceiling per D-B2 resolution).

**AC-12** **GIVEN** Player dies (`_is_dead = true`) before opening Level Up panel, **WHEN** `level_reached` would have fired, **THEN** panel does NOT open AND player goes to game-over screen instead.

**AC-13** **GIVEN** every upgrade in `_get_upgrade_pool()` has reached `max_stacks` (theoretical late-run pool exhaustion), **WHEN** `level_reached` fires, **THEN** panel auto-closes within 1 frame AND `get_tree().paused = false` AND `upgrade_applied("UPGRADE_NONE_AVAILABLE")` sentinel signal emits for analytics (no soft-lock).

**AC-14** **GIVEN** UPGRADE_FLYING_SWORD_PIERCE has been selected 2 times (at cap per Rule 6), **WHEN** the next level-up's `_get_upgrade_pool()` runs AND Flying Sword is unlocked, **THEN** UPGRADE_FLYING_SWORD_PIERCE is NOT in the pool AND the remaining Flying Sword upgrades (damage / cooldown / count) ARE still in the pool with their own per-upgrade cap states.

**AC-15** **GIVEN** UPGRADE_UNLOCK_FLYING_SWORD has been selected once (at cap = 1 per Rule 6 weapon-unlock category), **WHEN** the next level-up's `_get_upgrade_pool()` runs, **THEN** UPGRADE_UNLOCK_FLYING_SWORD is NOT in the pool (both per the `max_stacks = 1` cap AND the `_is_flying_sword_unlocked = true` flag check per AC-06).

## Open Questions

- **OQ-1** (Extract upgrade definitions to `.tres` — Pillar-4 compliance): per Resource Data Framework GDD audit, upgrade definitions are NON-COMPLIANT (hardcoded in `_apply_upgrade` match). **Resolution candidate**: create `resources/upgrades/<upgrade_id>.tres` files (UpgradeDefinition Resource subclass with id, title, description, target_weapon, delta_field, delta_value). `_apply_upgrade` becomes a generic dispatch reading from `.tres`. **Owner**: systems-designer + lead-programmer. **Estimated cost**: 4-6 hours refactor. **Target**: pre-v0.5 polish. **Same finding** as Player GDD OQ-6 + Resource Data GDD audit row.
- **OQ-2** ✅ **RESOLVED in revision-2 (D-B2 from /review-all-gdds 2026-05-27)** — `max_stacks` field added per category in Rule 6 + Tuning Knobs table. Damage caps at 3 stacks (4.75× ceiling — within Combat 5× warning); cooldown 5; pierce 2; count 3; HP/attributes 5; weapon unlocks 1. Enforcement at `_get_upgrade_pool()` filter (pre-shuffle). Worked examples in Formula 4. AC-11/14/15 defend. Future tuning per playtest expected — see Formula 4 final note.
- **OQ-3** (Upgrade rarity / tiers): currently all upgrades have equal probability via shuffle. Real Survivor games have rarity tiers (common/uncommon/rare/epic) with weighted probability. Some upgrades (e.g. UPGRADE_UNLOCK_<weapon>) feel inherently rarer than +10% movement. **Resolution candidate**: add `tier` enum (common/uncommon/rare); shuffle within tier; offer 2 commons + 1 uncommon OR 1 of each tier. **Owner**: economy-designer + game-designer. **Target**: post-MVP.
- **OQ-4** (Upgrade pool UI scrolling): currently 3 buttons are fixed in `LevelUpPanel.tscn`. If pool has < 3 entries, extra buttons are hidden. UI design assumes always-3. **Resolution candidate**: keep current design — 3 is a player-cognition-friendly number. Document this lock.
- **OQ-5** (Pool refresh between selections in same panel): if player rejects all 3 (e.g. "I want a different option"), no reroll mechanic exists. Real Survivor games have "reroll" or "skip" buttons. **Resolution candidate**: add Skip button (gives +1 XP, panel closes) and a Reroll button (regenerates 3 options, costs gold/banishes — but no gold economy in v0.4). **Owner**: ux-designer + economy-designer. **Target**: post-MVP economy work.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass; documents Level Up + Upgrade Pool from Player.gd hardcoded match. 12 ACs, 5 OQs (extract to .tres, stack cap, rarity tiers, UI scrolling, reroll). |
| 1 | (n/a — first-try PASS) | /design-review revision-0 | No revision-1 needed (PASS with 0 findings on first review). |
| 2 | 2026-05-27 | D-B2 from /review-all-gdds (BLOCKING design theory) | **D-B2 closed**: per-upgrade stack cap added (Rule 6) with category-based caps (damage=3, cooldown=5, pierce=2, count=3, HP=5, attributes=5, unlocks=1) enforced at `_get_upgrade_pool()` pre-shuffle filter. Combat 5× source_modifier ceiling now a HARD CAP (was advisory in revision-0). Formula 4 worked examples updated (was 6× violator; now 4.75× compliant). Tuning Knobs table extended with 7 new max_stacks rows. OQ-2 marked RESOLVED. AC-11 rewritten + AC-13/14/15 added for cap enforcement + pool exhaustion + weapon-unlock cap interaction. |
| 3 | 2026-06-02 | Design-change propagation (v0.5 systems) | Propagated **Five Phases** (UpgradeDefinition `element` field + per-option element icon + "相生!" combo hint — new "Five Phases Element Tag" section) and **Merit System** (Node 3 灵光一闪 4-choice first-level-up exception — Rule 2 amendment + variable choice count) dependencies. Two new Dependencies rows (Five Phases Synergy, Merit System) marked depended-on-by. **Additive only — existing rules, values, and caps unchanged.** |

## Registry Updates Recorded

**Significant**: every upgrade ID + title + delta + max_stacks should eventually be registered in `entities.yaml` as items, per Resource Data GDD compliance roadmap. v0.4 cannot register them because they're not yet `.tres` — but the migration path (OQ-1) ends with full registry coverage. Revision-2 adds `max_stacks` to the required field list for UpgradeDefinition Resource (see OQ-1).

**Cross-doc consistency**:
- Player GDD OQ-6 ↔ this GDD OQ-1 (same finding from different perspectives) ✅
- Resource Data Framework audit ↔ Pillar-4 violation acknowledgement ✅
- Combat GDD damage formula pipeline (`source_modifier` slot) is where upgrade deltas should plug in (Combat GDD Formula 1) ⏳

## Revision Log

| Revision | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass from `level_up_panel.gd` (62 lines) + Player.gd `_get_upgrade_pool()` (hardcoded array of 8 always-present + 5 weapon-conditional × 4-5 upgrades each ≈ 30 total IDs) + `_apply_upgrade` match. 8 required CCGS sections + Open Questions + Registry Updates. Documents 3-choice panel UX, deterministic pool RNG, queue-based multi-level handling, Sun Wukong skill-choice parallel queue. 12 ACs cover panel open/close, upgrade application, weapon unlock filtering, stacking, determinism, Player-death edge case. 5 OQs include Pillar-4 compliance migration (OQ-1, same as Player OQ-6), stack cap (OQ-2), rarity tiers (OQ-3), UI lock (OQ-4), reroll/skip (OQ-5). |
