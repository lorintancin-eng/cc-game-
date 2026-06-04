# Five Phases Synergy System (五行相生协同)

> **Status**: In Design (revision-4 — added 相克 matchup AC coverage + anti-dormancy floor + asymmetry/tuning notes from a /design-review that had run against the STALE revision-1 placeholder at git HEAD; its other blockers were already moot in revision-2/3. revision-3: CONCERNS resolved — heading, scaling caps, crit Formula 8 max(), propagation to 5 GDDs.)
> **Author**: user + claude
> **Last Updated**: 2026-06-02
> **Implements Pillar**: Pillar 2 (自动战斗与有意义的构筑选择 — Five Phases turns the flat upgrade pool into a synergy-driven build system with 3-5 distinct construction paths per run)
> **Layer**: Feature/Full Vision → v0.5 core delivery
> **Supersedes**: elements-five-phases.md revision-1 (placeholder 5×5 matchup-only GDD, 2026-05-27)

## Overview

The Five Phases Synergy System transforms MythSurvivor's flat, additive upgrade pool into a **synergy-driven build construction layer**. Every weapon and element-tagged upgrade carries one of the Five Phases (五行: Metal 金, Wood 木, Water 水, Fire 火, Earth 土). When the player accumulates items across specific element pairs, passive **Generating Cycle (相生) combo effects** activate automatically — producing nonlinear power spikes ("1+1>2") that reward deliberate build planning over random stat-stacking.

At the infrastructure level, the system owns: (1) element tag assignment on weapons, upgrades, and enemies; (2) a combo registry that maps element-pair thresholds to effect definitions; (3) the `element_modifier` slot in Combat Formula 1 for damage matchup interactions (carried forward from revision-1); and (4) integration hooks into the Upgrade Pool (element-aware filtering and combo-proximity hints) and Ghost Market (element-tagged trades).

The Five Phases cycle — 木生火, 火生土, 土生金, 金生水, 水生木 — provides **5 primary build paths** (one per generating pair) plus **5 overcoming (相克) interactions** that create build tension (taking elements that counter each other introduces tradeoffs). This gives the player 3-5 viable construction routes per run, up from the current single "stack highest numbers" strategy.

Without this system, every run's upgrade decisions are interchangeable — any weapon upgrade is roughly equivalent to any other. With it, the player pursues a coherent elemental identity that shapes which upgrades are valuable, which Ghost Market trades are worth the cost, and which enemy matchups to seek or avoid.

Reference: ADR-0001 (Godot 4.x + GDScript) constrains implementation to signal-based architecture and `.tres` Resource data. Combat GDD OQ-4 reserves the `element_modifier` pipeline slot.

## Player Fantasy

The Five Phases system is **directly felt** — the moment a combo activates is the emotional peak of the build.

> "I've been stacking Fire upgrades all run — Explosive Talisman damage, Talisman speed. Then the level-up panel shows a new Earth upgrade: '厚土护甲 +15 max HP'. I take it. The screen pulses — **火生土** flashes across my character — and suddenly a molten shield orbits me, burning nearby enemies on contact. My build just evolved. I went from 'guy with explosions' to 'walking furnace'. THAT'S what I was building toward."

When the system works, the player feels:
- **Build identity**: "I'm running a Fire-Earth build this time" — not just "I picked whatever had the biggest number"
- **Explosive payoff**: the combo activation is a visible, audible, unmistakable moment — damage numbers spike, new VFX appear, the battlefield changes
- **Strategic anticipation**: during every level-up choice, the player is thinking "which element gets me closer to my next combo?" instead of "which stat is highest?"
- **Replayability hunger**: "Next run I want to try Water-Metal — I wonder what that combo does"

Anti-fantasy: combos that activate silently (player doesn't notice), element tags that feel like arbitrary labels (no mechanical consequence), or a system so complex the player can't plan toward combos within a 5-minute run.

*`creative-director` not consulted — Lean mode. Review manually before production.*

## Detailed Rules

### Core Rules

1. **Five Phases vocabulary (closed set)**: `{metal, wood, water, fire, earth}`. The `neutral` value from revision-1 is deprecated for weapons and upgrades — all must declare an element. Enemies may still be `neutral` (no elemental affinity). Invalid values → `push_error()` + treated as neutral.

2. **Every weapon declares exactly one element** (immutable, defined by weapon identity). Every upgrade in the pool declares exactly one element (tagged in its `.tres` definition).

3. **Element inventory**: the system tracks the player's **element counts** — a dictionary `{metal: N, wood: N, water: N, fire: N, earth: N}` updated whenever a weapon is unlocked or an upgrade is applied. A weapon unlock adds +1 to its element. Each upgrade stack adds +1 to its element.

4. **Generating Cycle (相生) combo activation**: when the player's element inventory contains ≥1 of element A AND ≥1 of element B, where A→B is a generating pair, the corresponding combo effect activates. Combos are **passive and automatic** — no player input required.

5. **Generating pairs** (directional, A generates B):
   - 木生火 (Wood → Fire)
   - 火生土 (Fire → Earth)
   - 土生金 (Earth → Metal)
   - 金生水 (Metal → Water)
   - 水生木 (Water → Wood)

6. **Combo effects are persistent once activated** — they remain active for the rest of the run. They cannot be lost or deactivated.

7. **Multiple combos can coexist** — a player with Fire ≥1, Earth ≥1, and Metal ≥1 has both 火生土 and 土生金 active simultaneously. A theoretical maximum of 5 simultaneous combos exists (all 5 generating pairs active).

8. **Overcoming Cycle (相克) interactions**: retained from revision-1 as **combat damage modifiers only** (not build-internal penalties). When a weapon with element X hits an enemy with element Y: favorable matchup → damage ×1.3, unfavorable → ×0.8, neutral/same → ×1.0. See Formulas §1.

9. **No build-internal penalty for element mixing**: a player can freely take upgrades from any element. Having Metal and Fire (which are 相克) does NOT weaken either. The overcoming cycle only applies to weapon-vs-enemy matchups.

10. **Combo effects scale with element depth**: while activation requires only 1+1, some combo effects scale with the total count of the generating pair's elements (see individual combo descriptions). This rewards doubling down on a pair without gating activation behind high thresholds.

11. **Run-start element inventory initialization**: at run start, `element_inventory` is seeded BEFORE the first level-up. The starting weapon contributes +1 to its element (e.g., 修行者 starts with Talisman → fire=1). The Merit System's Node 11 (元素感应), if purchased, adds +1 to a random element at this same initialization step (per Merit GDD AC-09). Combo activation (Formula 2) is checked once after initialization, so a player can begin a run with a combo already active if Node 11 seeds a complementary element. This is the only path to a run-start combo; all other element gains come from level-ups and Ghost Market trades.

### Element Assignments

#### Weapons (6 weapons → 5 elements)

| Weapon | Element | Rationale |
|---|---|---|
| 符箓 (Talisman) | 火 (Fire) | Fire talisman — baseline projectile as burning paper charm |
| 飞剑 (Flying Sword) | 金 (Metal) | Forged blade — piercing metal |
| 雷法 (Thunder Law) | 水 (Water) | 雷泽属水 — in Chinese cosmology, thunder/lightning arises from water (泽卦 = lake/marsh) |
| 八卦阵 (Bagua Array) | 土 (Earth) | Bagua as earthly formation — grounding, protective rotation |
| 爆裂符 (Explosive Talisman) | 火 (Fire) | Explosion = fire element; pairs with Talisman for Fire-heavy builds |
| 山印 (Mountain Seal) | 土 (Earth) | Mountain = earth element; pairs with Bagua for Earth-heavy builds |

**Element distribution**: Fire ×2, Earth ×2, Metal ×1, Water ×1, Wood ×0 weapons.

**Wood (木) has no weapon** — intentional. Wood is the "growth/life" element, represented through **player attribute upgrades** (HP, pickup radius, XP gain, move speed) and Ghost Market trades. This creates asymmetry: Wood is easy to accumulate through utility upgrades but offers no direct DPS weapon, making Wood-adjacent combos (水生木, 木生火) require deliberate non-damage investment.

#### Upgrades (element-tagged)

Each upgrade inherits its weapon's element, plus player attribute upgrades are assigned to Wood:

| Upgrade Category | Element | Examples |
|---|---|---|
| Talisman upgrades (damage/cooldown/count/speed) | 火 (Fire) | 追魂符威力, 追魂符施放 |
| Flying Sword upgrades (damage/cooldown/pierce) | 金 (Metal) | 飞剑威力, 飞剑穿透 |
| Thunder Law upgrades (damage/cooldown/count) | 水 (Water) | 雷法威力, 雷法目标数 |
| Bagua Array upgrades (damage/cooldown/radius) | 土 (Earth) | 八卦阵威力, 八卦阵范围 |
| Explosive Talisman upgrades (damage/cooldown/radius) | 火 (Fire) | 爆裂符威力, 爆裂符范围 |
| Mountain Seal upgrades (damage/cooldown/radius) | 土 (Earth) | 山印威力, 山印范围 |
| Player attribute upgrades (max_hp/move_speed/pickup_radius/xp_gain) | 木 (Wood) | 气血上限, 身法, 拾取, 修为 |
| Weapon unlock upgrades | Same as weapon | 解锁飞剑 = 金, 解锁雷法 = 水 |

### Generating Cycle (相生) Synergies

Each generating pair produces a unique passive combo effect when activated (≥1 of each element in the pair). Effects are persistent for the rest of the run.

#### 1. 木生火 — 燎原 (Wildfire Spread)
**Pair**: Wood + Fire | **Theme**: Wood fuels fire — flames spread between enemies

**Effect**: When a Fire-element weapon kills an enemy, the kill spawns a **fire burst** at the death location (radius = 40 px) that deals **50% of the killing blow's damage** to all enemies in range. If the burst kills another enemy, it chains (max 3 chains per trigger). Chain damage does NOT decay between links.

**Damage pipeline contract**: burst damage is `damage_type = EXPLOSION`, `source_kind = WEAPON` (so it does NOT trigger friendly fire and is attributed to the player for kill-credit). It bypasses the `source_modifier` / `crit_multiplier` / `element_modifier` pipeline (it is a derived value already computed from the killing blow's final damage), and applies directly via `enemy.take_damage(burst_damage)`. The 3-chain cap and the WILDFIRE_MAX_CHAINS tuning knob are the only bounds — see W-01 / OQ-7 for the DPS-ceiling validation requirement.

**Scaling**: Each additional Wood or Fire point beyond the activation threshold (1+1) increases burst radius by +8 px (cap: 80 px at 7 total element points, per Formula 3 with MAX_SCALE_STEPS=5: 40 + min(5,5)×8 = 80).

**Battlefield feel**: Clustered enemies start chain-dying — the player sees popcorn explosions rippling through a pack. Rewards positioning near dense groups.

---

#### 2. 火生土 — 熔岩甲 (Molten Aegis)
**Pair**: Fire + Earth | **Theme**: Fire hardens earth into protective armor

**Effect**: Player gains a **damage-absorbing shield** that regenerates over time. Shield HP = **15** (flat). Regenerates **3 HP per 5 seconds** while not taking damage (2-second grace period after last hit before regen starts). Shield absorbs damage before player HP. Shield is visible as a molten ring around the player character.

**Damage pipeline contract**: shield absorption happens AFTER Combat Formula 1 produces `final_damage` (post-clamp). The shield absorbs `min(shield_hp, final_damage)`; any excess (`final_damage − absorbed`) passes to `Player.take_damage(excess)`. The shield intercepts the fully-modified damage value, so element matchups and crits are already baked in before absorption. See Formula 5 and Edge Cases for the partial-absorption resolution.

**Scaling**: Each additional Fire or Earth point beyond the activation threshold adds +5 shield HP and +1 regen per 5s (cap: 40 shield HP, 8 regen at 7 total element points).

**Battlefield feel**: The player gains a visible safety buffer — they can afford to be slightly more aggressive in positioning. The shield breaking is an audible/visible warning ("my buffer is gone, retreat").

---

#### 3. 土生金 — 矿脉精粹 (Ore Refinement)
**Pair**: Earth + Metal | **Theme**: Earth yields precious metal ore — weapons grow sharper

**Effect**: All weapons gain **+1 pierce** (projectile weapons pass through 1 additional enemy; radius weapons hit 1 additional target beyond their normal cap). For Bagua Array (tick aura), this translates to +15% tick damage instead (aura already hits all in radius — pierce is meaningless for it).

**Scaling**: Each additional Earth or Metal point beyond the activation threshold adds a **2% chance per hit to deal a critical strike** (×1.5 damage). Cap: 10% crit chance at 7 total element points (per Formula 3 with MAX_SCALE_STEPS=5: min(5,5)×2% = 10%). (This uses the `crit_multiplier` slot in Combat Formula 1 — see Formula 8 for the collision-resolution rule with Active Skills' 火眼金睛.)

**Battlefield feel**: Projectiles punching through enemy lines — the player sees their Flying Sword hitting 4 instead of 3 enemies. The occasional crit flash adds punch.

---

#### 4. 金生水 — 寒露凝锋 (Frost Condensation)
**Pair**: Metal + Water | **Theme**: Cold metal condenses moisture — chilling strikes

**Effect**: All weapon hits apply a **slow debuff** to the target: move speed ×0.7 for 1.5 seconds. Slow does NOT stack in intensity (reapplication refreshes duration only). Slowed enemies have a visible frost VFX overlay.

**Scaling**: Each additional Metal or Water point beyond the activation threshold extends slow duration by +0.3s (cap: 3.0s at 7 total element points, per Formula 3 with MAX_SCALE_STEPS=5: 1.5 + min(5,5)×0.3 = 3.0).

**Battlefield feel**: The enemy wave visibly decelerates around the player — suddenly the pressure curve feels manageable. Pairs powerfully with Thunder Law's multi-target to slow entire groups simultaneously.

---

#### 5. 水生木 — 春生回元 (Vernal Restoration)
**Pair**: Water + Wood | **Theme**: Water nourishes wood — life force regeneration

**Effect**: Player regenerates **2 HP every 4 seconds** (passive, unconditional — works even while taking damage). Additionally, XP orb pickup value is increased by **+15%** (multiplicative with existing XP gain upgrades).

**Scaling**: Each additional Water or Wood point beyond the activation threshold adds +1 HP per 4s regen and +5% XP bonus (cap: 7 HP/4s and +40% XP at 7 total element points).

**Battlefield feel**: A slow but steady lifeline — the player notices their HP bar creeping up between encounters. The XP bonus means faster level-ups, which means more upgrades, which means more element points. A virtuous cycle for utility-focused builds.

### Overcoming Cycle (相克) Interactions

The overcoming cycle operates exclusively as **weapon-vs-enemy damage modifiers** in the Combat damage pipeline. It does NOT penalize build-internal element mixing.

**Overcoming pairs** (A overcomes B):
- 金克木 (Metal overcomes Wood)
- 木克土 (Wood overcomes Earth)
- 土克水 (Earth overcomes Water)
- 水克火 (Water overcomes Fire)
- 火克金 (Fire overcomes Metal)

**Damage modifiers** (applied via `element_modifier` slot in Combat Formula 1):
- Weapon element overcomes enemy element → ×1.3 (+30%)
- Enemy element overcomes weapon element → ×0.8 (−20%)
- Same element or neutral on either side → ×1.0

**Design intent**: elemental matchups add a **battlefield awareness layer** — the player notices "that pack of Earth enemies is weak to my Wood upgrades" and adjusts positioning to let the right weapon handle them. This is subtle strategic depth that rewards knowledge of the 相克 cycle without requiring manual targeting (auto-battle handles it).

**Asymmetry rationale**: the +30% advantage is intentionally larger than the −20% penalty — a positive-skew that keeps favorable matchups feeling rewarding rather than making unfavorable ones feel punishing. Do NOT "correct" this toward symmetry (±25%) without re-tuning overall DPS; the skew is a deliberate feel choice.

**Minimum-coverage constraint (anti-dormancy)**: to prevent the overcoming cycle from being off-by-default, **both Bosses must carry a non-neutral element** (Famine Beast = earth, Ghost Market Judge = metal — assigned in §Integration with Enemy System) and **at least 4 of the 6 Stage-1 enemies** must be non-neutral. v0.5 already assigns every enemy a concrete element, so this floor is satisfied; the constraint exists so a future enemy added as "neutral" for convenience cannot silently switch off the climax matchup. **相生 (generative cycle) is intentionally NOT modeled here** — wood→fire returns 1.0 in the *combat matchup* table; the generative interactions live in the §Generating Cycle combo system, a separate mechanic.

### Integration with Upgrade Pool

1. **Element tag display**: each upgrade option in the LevelUpPanel shows its element icon (small colored symbol: 金=white/silver, 木=green, 水=blue, 火=red, 土=yellow-brown) next to the upgrade name.

2. **Combo proximity hint**: when an upgrade would activate a new combo (i.e., the player currently has ≥1 of element A and this upgrade's element is B where A→B is a generating pair, or vice versa), the upgrade option shows a **"相生!" glow border** and a tooltip: "激活 [combo name]". This is the primary discovery mechanism — the player learns combos by seeing which upgrades trigger them.

3. **No forced element filtering**: the pool does NOT hide upgrades of "wrong" elements. All eligible upgrades appear as before (per Level Up Pool GDD Rules 2-3). The element system adds information to choices, not restrictions.

4. **Element count updated on selection**: `upgrade_applied` signal triggers element inventory update. If the new count satisfies a generating pair, `combo_activated(combo_id)` signal fires immediately (before the LevelUpPanel closes, so the activation VFX plays during the pause — visible and dramatic).

### Integration with Ghost Market

1. **Blood Pact (血契)** stalls are element-tagged: each Blood Pact trade offered is tagged with a random element (weighted toward elements the player already has ≥1 of, to enable combo completion). The element tag determines which weapon receives the damage buff. Display: element icon on the stall.

2. **Soul Codex (魂典)** stalls offer a weapon upgrade from the pool — the offered upgrade's element is visible. The player can use Ghost Market to selectively pick element-specific upgrades they need for combo completion.

3. **New stall type: 五行灵珠 (Phase Bead)** — a v0.5 Ghost Market addition. Cost: 40 XP (flat). Effect: adds +1 to a specific element count WITHOUT granting any stat buff. The element offered is random (weighted toward the player's weakest element). This is a pure combo-enabler: costs XP but gives no direct power, only element progress.

4. **Market strategy emergence**: the Ghost Market becomes a place where players can "shop for their combo" — if they're 1 Wood point away from 木生火, they look for Wood-tagged trades or Phase Beads. This transforms the market from "always take Blood Pact" to "what does my build need?"

### Integration with Enemy System

**Enemy element assignments** (v0.5 activation):

| Enemy | Element | Rationale |
|---|---|---|
| 纸人 (Paper Doll) | 木 (Wood) | Paper = wood product |
| 游魂 (Wandering Soul) | 水 (Water) | Ghostly, flowing, ephemeral |
| 狐灵 (Fox Spirit) | 火 (Fire) | Fox fire (狐火) mythology |
| 鬼火 (Ghost Flame) | 火 (Fire) | Literal ghost fire |
| 石魔 (Stone Golem) | 土 (Earth) | Stone = earth |
| 山魈精英 (Shanxiao Elite) | 金 (Metal) | Mountain spirit with metallic hide |
| 灯笼鬼 (Lantern Ghost) | 火 (Fire) | Lantern = fire |
| 怨婴 (Resentful Infant) | 水 (Water) | Sorrowful tears, water-associated |
| 鬼差 (Ghost Bailiff) | 金 (Metal) | Armored underworld official |
| 镇墓兽 (Tomb Guardian) | 土 (Earth) | Guards earth/tomb |
| 无常精英 (Impermanence Elite) | 木 (Wood) | Wooden chains/instruments of judgment |

**Boss elements**:
| Boss | Element | Rationale |
|---|---|---|
| 荒年兽 (Famine Beast) | 土 (Earth) | Famine = barren earth, drought |
| 鬼市判官 (Ghost Market Judge) | 金 (Metal) | Judge's metal seal and blade |

**Neutral enemies**: none in v0.5 — all enemies receive an element. Future enemy types may use `neutral` if their mythology doesn't suggest an element.

**Stage element composition**: Stage 1 (荒山) has a mix of Wood/Fire/Earth enemies. Stage 2 (幽都) skews Fire/Water/Metal. This means different builds have different "easy" and "hard" stages, adding replayability.

## Formulas

### Formula 1: Element Matchup Modifier (retained from revision-1)

The element matchup modifier is looked up from the overcoming cycle:

`element_modifier = lookup(source_element, target_element)`

```
favorable_set = {(metal,wood), (wood,earth), (earth,water), (water,fire), (fire,metal)}

if "neutral" in (source_element, target_element): return 1.0
if (source_element, target_element) in favorable_set: return FAVORABLE_MOD  # default 1.3
if (target_element, source_element) in favorable_set: return UNFAVORABLE_MOD  # default 0.8
return 1.0  # same element or non-adjacent pair
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| source_element | src_e | String | {metal,wood,water,fire,earth,neutral} | Element of the attacking weapon |
| target_element | tgt_e | String | {metal,wood,water,fire,earth,neutral} | Element of the target enemy |
| FAVORABLE_MOD | fav | float | 1.1 – 1.5 | Damage multiplier when source overcomes target |
| UNFAVORABLE_MOD | unfav | float | 0.5 – 0.9 | Damage multiplier when target overcomes source |

**Output Range:** 0.8 to 1.3 at default tuning; 1.0 for neutral/same/non-adjacent.
**Example:** Flying Sword (金/metal) hits Paper Doll (木/wood). (metal,wood) ∈ favorable_set → element_modifier = 1.3. Final damage = 8 × 1.0 × 1.0 × 1.3 × 1.0 = 10.4.

### Formula 2: Combo Activation Check

`combo_active(pair) = (element_inventory[pair.A] >= 1) AND (element_inventory[pair.B] >= 1)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| element_inventory | inv | Dict[String→int] | 0 – ~15 per element | Player's current element point totals |
| pair.A | A | String | Five Phases set | First element of the generating pair |
| pair.B | B | String | Five Phases set | Second element of the generating pair |

**Output:** boolean — true if combo is active, false otherwise.
**Example:** Player has {fire: 3, earth: 2, metal: 0, water: 0, wood: 1}. Check 火生土: fire≥1 AND earth≥1 → true. Check 木生火: wood≥1 AND fire≥1 → true. Check 土生金: earth≥1 AND metal≥1 → false (metal=0).

### Formula 3: Combo Scaling Factor

`scale_bonus = min(pair_element_total - 2, MAX_SCALE_STEPS) × STEP_VALUE`

Where `pair_element_total = element_inventory[pair.A] + element_inventory[pair.B]`.

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| pair_element_total | total | int | 2 – ~15 | Sum of both elements in the generating pair |
| MAX_SCALE_STEPS | max_s | int | 4 – 6 | Maximum number of bonus steps beyond activation |
| STEP_VALUE | step | varies | per-combo | The bonus per step (radius +8, shield +5, etc.) |

**Output Range:** 0 (at activation threshold of 2 total) to MAX_SCALE_STEPS × STEP_VALUE.
**Example (燎原):** Player has fire=3, wood=2. pair_element_total = 5. scale_bonus = min(5−2, 5) × 8 = 24 px additional burst radius. Total burst radius = 40 + 24 = 64 px.

### Formula 4: Wildfire Chain Damage (燎原)

`burst_damage = killing_blow_damage × 0.5`
`burst_radius = BASE_BURST_RADIUS + scale_bonus`

Max chains = 3 per trigger. Chain damage does NOT decay.

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| killing_blow_damage | kb_dmg | float | 1 – ~50 | The raw damage of the hit that killed the enemy |
| BASE_BURST_RADIUS | base_r | float | 40 px | Base radius of the death burst |
| scale_bonus | bonus | float | 0 – 40 px | From Formula 3 |

**Output Range:** burst_damage = 0.5 – 25. burst_radius = 40 – 80 px.
**Example:** Explosive Talisman (damage 18 after upgrades) kills a Paper Doll. burst_damage = 18 × 0.5 = 9. If 3 enemies within 40 px, all take 9 damage. If one dies, chains to next group (max 3 chains).

### Formula 5: Molten Aegis Shield (熔岩甲)

`shield_max_hp = BASE_SHIELD_HP + scale_bonus_hp`
`shield_regen_rate = BASE_REGEN + scale_bonus_regen` (HP per 5 seconds)

Regen starts after REGEN_GRACE_PERIOD seconds without taking damage.

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| BASE_SHIELD_HP | base_s | float | 15 | Base shield HP at activation |
| scale_bonus_hp | s_hp | float | 0 – 25 | +5 per step from Formula 3 |
| BASE_REGEN | base_rg | float | 3 per 5s | Base regen rate |
| scale_bonus_regen | s_rg | float | 0 – 5 per 5s | +1 per step from Formula 3 |
| REGEN_GRACE_PERIOD | grace | float | 2.0 s | Seconds after last damage before regen starts |

**Output Range:** shield_max_hp = 15 – 40. shield_regen_rate = 3 – 8 per 5s.
**Example:** Player has fire=2, earth=3. total=5, steps=3. shield_max_hp = 15 + 15 = 30. shield_regen_rate = 3 + 3 = 6 per 5s. After 2s without damage, shield regenerates 6 HP per 5s tick.

### Formula 6: Frost Slow Duration (寒露凝锋)

`slow_duration = BASE_SLOW_DURATION + scale_bonus_duration`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| BASE_SLOW_DURATION | base_d | float | 1.5 s | Base slow duration |
| scale_bonus_duration | s_dur | float | 0 – 1.5 s | +0.3s per step from Formula 3 |
| SLOW_FACTOR | slow | float | 0.7 | Target move speed multiplier (fixed, does not scale) |

**Output Range:** slow_duration = 1.5 – 3.0 s. SLOW_FACTOR = 0.7 (constant).
**Example:** Player has metal=1, water=2. total=3, steps=1. slow_duration = 1.5 + 0.3 = 1.8s.

### Formula 7: Vernal Restoration (春生回元)

`hp_regen = BASE_HP_REGEN + scale_bonus_regen` (HP per 4 seconds)
`xp_bonus = BASE_XP_BONUS + scale_bonus_xp` (multiplicative with existing XP gain)

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| BASE_HP_REGEN | base_hr | float | 2 per 4s | Base HP regen rate |
| scale_bonus_regen | s_hr | float | 0 – 5 per 4s | +1 per step from Formula 3 |
| BASE_XP_BONUS | base_xp | float | 0.15 (15%) | Base XP pickup value multiplier bonus |
| scale_bonus_xp | s_xp | float | 0 – 0.25 | +0.05 per step from Formula 3 |

**Output Range:** hp_regen = 2 – 7 per 4s. xp_bonus = 0.15 – 0.40 (15% – 40%).
**Example:** Player has water=2, wood=3. total=5, steps=3. hp_regen = 2 + 3 = 5 per 4s. xp_bonus = 0.15 + 0.15 = 0.30 (30%). If base XP orb = 5.5, effective = 5.5 × 1.30 = 7.15.

### Formula 8: crit_multiplier Slot Resolution (collision with Active Skills)

Both 矿脉精粹 (Ore Refinement, this GDD) and 火眼金睛 (Fire Eyes, Active Skills GDD) write to Combat Formula 1's single `crit_multiplier` slot. They are resolved by **max()** — the higher of the two applies on any given hit:

`crit_multiplier = max(fire_eyes_modifier, ore_crit_roll)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| fire_eyes_modifier | f_e | float | 1.0 or 1.2 | Active Skills 火眼金睛: deterministic ×1.2 vs elite/boss targets, else 1.0 (only present for Sun Wukong) |
| ore_crit_roll | o_c | float | 1.0 or 1.5 | 矿脉精粹: per-hit probabilistic roll — 1.5 on a successful crit (chance = ORE_CRIT_CHANCE per scaling), else 1.0 |

**Output Range:** 1.0 to 1.5.
**Resolution semantics:** 火眼金睛 provides a deterministic **floor** vs elites/bosses (always ≥1.2 on those targets); 矿脉精粹 provides a probabilistic **spike** (1.5) that exceeds the floor on lucky rolls. They do NOT multiply — a Sun Wukong player with both gets `max(1.2, crit_roll)`, never 1.2×1.5=1.8. This keeps the crit pipeline within the single reserved slot and avoids breaching Combat's DPS expectations.
**Example:** Sun Wukong (火眼金睛 active) with 矿脉精粹 hits an elite. fire_eyes_modifier = 1.2. ore_crit_roll succeeds → 1.5. crit_multiplier = max(1.2, 1.5) = 1.5. On a non-crit hit: max(1.2, 1.0) = 1.2. Against a normal (non-elite) enemy with a failed crit roll: max(1.0, 1.0) = 1.0.

## Edge Cases

- **If element_inventory updates mid-combat (via Ghost Market trade during interlude)**: combo activation check runs on inventory change signal. Any newly activated combos take effect immediately when combat resumes (next stage).
- **If a combo's scaling exceeds MAX_SCALE_STEPS**: clamped. Additional element points beyond the cap have no further scaling effect on that combo (but may enable other combos).
- **If 燎原 (Wildfire) chain kills occur during Boss phase**: chain damage CAN hit the Boss (Boss is not immune to chain bursts). Boss summons are valid chain targets. Chain cap of 3 still applies.
- **If 熔岩甲 (Molten Aegis) shield HP = 0 and player takes damage**: damage passes through to player HP normally. Shield regen timer starts from the last damage tick (whether shield or HP damage).
- **If 熔岩甲 shield absorbs partial damage**: shield absorbs up to its remaining HP; excess passes to player HP. Example: shield has 5 HP, incoming damage = 12 → shield breaks (absorbs 5), player takes 7.
- **If 寒露凝锋 (Frost) slow is applied to a Boss**: Boss IS affected by slow — the slow multiplier ×0.7 applies to the Boss's `move_speed` field. This is intentional — it rewards the Metal+Water build path against Bosses. **Note**: the Boss's Charge ability uses a SEPARATE `charge_speed` field (390 px/s, per Boss GDD Formula), NOT `move_speed`. Per OQ-2, the v0.5 decision is whether Frost slow also scales `charge_speed` (trivializes the Charge threat) or only `move_speed` (Boss still charges at full speed but repositions slowly). Default for v0.5: slow affects `move_speed` ONLY; `charge_speed` is unaffected, preserving the Charge as a readable threat.
- **If player has all 5 elements ≥1**: all 5 generating cycle combos are active simultaneously. This is the theoretical maximum — a "五行齐全" state. No special bonus for having all 5 (each combo operates independently).
- **If player picks a neutral upgrade (future-proofing)**: neutral upgrades do not increment any element counter. They provide their stat bonus but no combo progress.
- **If all 3 level-up options are the same element**: no forced diversity — this is a valid RNG outcome. The element hint system still shows combo proximity for the shared element.
- **If 五行灵珠 (Phase Bead) is offered but player has all elements ≥1**: the bead still offers +1 to weakest element (for scaling purposes). It is never a "wasted" purchase since all combos have scaling.
- **If 燎原 chain damage would kill an enemy that drops a pickup**: normal death processing occurs (XP orb spawn, pickup drop). The chain kill counts toward kill stats.
- **If two generating pairs share an element (e.g., Fire is in both 木生火 and 火生土)**: both combos check independently. Adding +1 Fire can activate BOTH combos simultaneously if Wood≥1 and Earth≥1. This is intended and creates satisfying "double activation" moments.

## Dependencies

| System | Direction | Type | Interface |
|---|---|---|---|
| **Combat** | Upstream (hard) | Data → Combat | `element_modifier` slot in Formula 1 damage pipeline (pre-clamp position). Combo effects that modify damage (燎原 burst, 矿脉精粹 crit) also flow through Combat. |
| **Enemy** | Upstream (hard) | Data ← Enemy | `element: String` field per EnemyArchetype `.tres`. Must be added to Enemy GDD's 19-field schema (currently reserved). |
| **Weapon System** | Upstream (hard) | Data ← Weapon | `element: String` field per weapon definition. Determines source element for matchup lookups and element inventory on unlock. |
| **Level Up & Upgrade Pool** | Upstream (hard) | Data ← Pool, Signal → Pool | Each UpgradeDefinition gets `element: String` field. Pool displays element icons and combo hints. `upgrade_applied` signal triggers element inventory update. |
| **Player** | Upstream (hard) | State owner | Player owns element_inventory dictionary. Combo activation signals emit from Player. Shield (熔岩甲) and regen (春生) effects are Player-side state. |
| **Ghost Market** | Lateral (soft) | Data ← Market | Blood Pact/Soul Codex stalls show element tags. New Phase Bead stall type adds pure element points. Market functions without this system but loses strategic depth. |
| **Character System** | Upstream (soft) | Data ← Character | Character may declare a starting element affinity (v0.6+ — out of scope for v0.5). |
| **Status Effects** | Downstream (soft) | Data → Status | Frost slow (寒露凝锋) creates a new status effect type. Must integrate with Status Effects GDD's effect registry. |
| **Combat Feedback** | Downstream (soft) | Signal → Feedback | Combo activation, elemental damage (+30%/−20%), shield break, chain kills all need visual/audio feedback events. |
| **HUD** | Downstream (soft) | Signal → HUD | Element inventory display, active combo indicators, shield HP bar — all need HUD integration. |

## Tuning Knobs

| Knob | Default | Safe Range | Affects | Breaks If |
|---|---|---|---|---|
| FAVORABLE_MOD | 1.3 | 1.1 – 1.5 | Elemental advantage damage bonus | >1.5: builds that match enemy elements dominate; <1.1: matchups feel irrelevant |
| UNFAVORABLE_MOD | 0.8 | 0.5 – 0.9 | Elemental disadvantage damage penalty | <0.5: mismatched weapons feel useless; >0.9: no reason to care about matchups |

> **Tuning coupling (FAVORABLE_MOD × UNFAVORABLE_MOD)**: these two knobs are independent in range but must be tuned together. Keep `UNFAVORABLE_MOD ≥ 1 / FAVORABLE_MOD` to bound the advantage:disadvantage ratio (e.g. FAVORABLE=1.3 → UNFAVORABLE ≥ 0.77; FAVORABLE=1.5 → ≥ 0.67). Independent extremes (1.5 / 0.5) create a 3× damage swing that can make whole builds non-viable against a single-element wave.
| WILDFIRE_BURST_RADIUS | 40 px | 30 – 60 px | 燎原 chain spread area | >60: trivializes clustered waves; <30: chains rarely proc |
| WILDFIRE_DAMAGE_RATIO | 0.5 (50%) | 0.3 – 0.7 | 燎原 burst damage relative to killing blow | >0.7: chain kills cascade too reliably, may breach DPS ceiling; <0.3: chains feel weak |
| WILDFIRE_MAX_CHAINS | 3 | 2 – 5 | Maximum chain links per trigger | >5: single kill → screen wipe; <2: combo feels underwhelming |
| SHIELD_BASE_HP | 15 | 10 – 25 | 熔岩甲 base shield capacity | >25: negates first-hit threat; <10: shield breaks before player notices it |
| SHIELD_REGEN_RATE | 3 per 5s | 1 – 6 per 5s | 熔岩甲 recovery speed | >6: shield is effectively permanent; <1: regen is negligible |
| SHIELD_GRACE_PERIOD | 2.0 s | 1.0 – 4.0 s | Time after damage before regen starts | >4: regen rarely activates in combat; <1: shield feels invincible |
| ORE_PIERCE_BONUS | +1 | +1 – +2 | 矿脉精粹 extra pierce per projectile | >+2: Flying Sword hits 6+ enemies (DPS ceiling risk); =0: combo feels invisible |
| ORE_CRIT_CHANCE_PER_STEP | 2% | 1% – 4% | 矿脉精粹 crit scaling per element step | >4%: at 6 steps = 24% crit (too swingy); <1%: crits too rare to notice |
| ORE_CRIT_MULTIPLIER | 1.5× | 1.3× – 2.0× | Critical hit damage multiplier | >2.0: crit kills feel random/unfair; <1.3: crits don't feel special |
| FROST_SLOW_FACTOR | 0.7 | 0.5 – 0.85 | Enemy speed multiplier when slowed | <0.5: enemies feel frozen (trivializes pressure); >0.85: slow is barely noticeable |
| FROST_BASE_DURATION | 1.5 s | 1.0 – 2.5 s | Base slow duration | >2.5: permanent slow on fast-firing weapons; <1.0: wears off before player benefits |
| VERNAL_HP_REGEN | 2 per 4s | 1 – 4 per 4s | 春生 HP regeneration rate | >4: negates low-tier enemy damage; <1: regen is imperceptible |
| VERNAL_XP_BONUS | 0.15 (15%) | 0.10 – 0.25 | 春生 XP pickup bonus | >0.25: too many free levels; <0.10: bonus not noticeable |
| PHASE_BEAD_COST | 40 XP | 20 – 80 XP | 五行灵珠 Ghost Market cost | >80: too expensive for a non-stat item; <20: always buy = removes decision |
| MAX_SCALE_STEPS | 5 | 3 – 8 | Cap on scaling bonus steps per combo | >8: extreme investment = extreme power (balance risk); <3: scaling too short to matter |

## Visual/Audio Requirements

### Combo Activation
- **Screen flash**: brief full-screen tint in the combo's element color (0.3s fade) when a generating cycle combo first activates
- **Text announcement**: combo name appears center-screen in calligraphic style (e.g., "火生土 — 熔岩甲") with element color, fades after 1.5s
- **Audio sting**: unique activation sound per combo — pentatonic chord using traditional Chinese instruments (guzheng pluck for Metal, wooden fish for Wood, water drum for Water, bronze bell for Fire, stone chime for Earth)

### Per-Combo Visual Effects
- **燎原 (Wildfire)**: orange-red fire burst at death location; flames spread visually to chain targets; particle trail between chain links
- **熔岩甲 (Molten Aegis)**: glowing amber ring around player character; ring cracks visually as shield HP drops; breaks with a flash when depleted; subtle pulse when regenerating
- **矿脉精粹 (Ore Refinement)**: metallic gleam on projectiles (silver overlay); crit hits show a brief golden flash + larger damage number
- **寒露凝锋 (Frost)**: frost crystal overlay on slowed enemies; brief ice particle burst on hit; frozen ground trail beneath slowed enemies
- **春生 (Vernal)**: green leaf particles rising from player every regen tick; XP orbs have a green glow tint when bonus is active

### Element Icons (5 icons)
- Each element needs a small icon (16×16 px at 1× scale) for upgrade panel, HUD inventory, and Ghost Market stall tags
- Style: ink-brush calligraphy character in circle (金/木/水/火/土) with element-colored background
- Must be readable at 12×12 px minimum for dense UI contexts

### Overcoming Matchup Feedback
- **Favorable hit**: damage number tinted in attacker's element color + "▲" indicator
- **Unfavorable hit**: damage number dimmed/grey + "▼" indicator
- No special audio for matchup — visual indicator only (avoid audio clutter in combat)

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:elements-five-phases` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

### HUD: Element Inventory Display
- **Location**: bottom-left corner, below the existing HP bar
- **Format**: 5 small element icons in a horizontal row (金木水火土). Each icon shows a count badge (number). Inactive elements (count=0) are greyed out.
- **Active combo indicators**: when a generating pair is active, a small arc/bridge connects the two element icons in the pair, colored in a blend of the two element colors

### HUD: Shield Bar (熔岩甲)
- **Location**: directly above the HP bar (layered)
- **Format**: narrow amber bar showing shield HP / shield max HP. Only visible when 熔岩甲 combo is active.
- **Regen indicator**: subtle pulse animation when shield is regenerating

### Level-Up Panel: Element Integration
- **Element icon**: small colored dot next to each upgrade option's title (uses the 16×16 element icons)
- **Combo hint glow**: if selecting this upgrade would activate a new combo, the option has a pulsing border in the combo's color blend + text "相生! 激活 [combo name]" beneath the description
- **No layout changes**: element info is additive — the existing 3-option panel layout, button sizing, and interaction model remain unchanged

### Ghost Market: Element Tags
- **Stall element icon**: each stall shows its element icon in the top-right corner
- **Phase Bead stall**: new visual template — a glowing orb matching the offered element color, with "五行灵珠" label and XP cost

📌 **UX Flag — Five Phases Synergy**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for each screen or HUD element this system contributes to **before** writing epics. Stories that reference UI should cite `design/ux/[screen].md`, not the GDD directly.

## Acceptance Criteria

**AC-01** — **GIVEN** player has element_inventory = {fire:1, earth:0}, **WHEN** player selects an Earth upgrade, **THEN** element_inventory updates to {fire:1, earth:1} AND `combo_activated("火生土")` signal fires AND 熔岩甲 shield appears around player.

**AC-02** — **GIVEN** 燎原 combo is active, **WHEN** a Fire-element weapon kills an enemy with 3 other enemies within 40 px, **THEN** a fire burst spawns at the death location dealing 50% of killing blow damage to all 3 nearby enemies.

**AC-03** — **GIVEN** 燎原 combo is active and burst kills a second enemy, **WHEN** the chain counter < 3, **THEN** a new burst spawns at the second death location. Chain counter increments.

**AC-04** — **GIVEN** 燎原 combo is active and chain counter = 3, **WHEN** a chain burst kills another enemy, **THEN** no further chain burst spawns (cap enforced).

**AC-05** — **GIVEN** 熔岩甲 combo is active with shield_hp = 10, **WHEN** player takes 15 damage, **THEN** shield absorbs 10, player HP reduced by 5. Shield HP = 0.

**AC-06** — **GIVEN** 熔岩甲 shield_hp = 0 and player has not taken damage for 2.0 seconds, **WHEN** regen tick fires, **THEN** shield_hp increases by regen_rate (3 at base).

**AC-07** — **GIVEN** 矿脉精粹 combo is active, **WHEN** Flying Sword fires a projectile, **THEN** projectile pierce_count = base (3) + 1 = 4.

**AC-08** — **GIVEN** 矿脉精粹 combo is active with 4 total Earth+Metal points (2 scale steps), **WHEN** any weapon hits an enemy, **THEN** there is a 4% chance the hit deals ×1.5 damage (crit).

**AC-09** — **GIVEN** 寒露凝锋 combo is active, **WHEN** any weapon hits an enemy, **THEN** enemy move_speed is set to base × 0.7 for 1.5s (or scaled duration). Subsequent hits refresh duration, do NOT stack intensity.

**AC-10** — **GIVEN** 寒露凝锋 combo is active, **WHEN** weapon hits a Boss, **THEN** Boss move_speed is reduced to ×0.7 (Boss is NOT immune to slow).

**AC-11** — **GIVEN** 春生回元 combo is active, **WHEN** 4 seconds pass, **THEN** player HP increases by 2 (or scaled value), clamped to max_hp.

**AC-12** — **GIVEN** 春生回元 combo is active with 30% XP bonus, **WHEN** player picks up XP orb worth 5.5, **THEN** effective XP gained = 5.5 × 1.30 = 7.15.

**AC-13** — **GIVEN** Flying Sword (金/metal) hits Paper Doll (木/wood), **WHEN** damage is calculated, **THEN** element_modifier = 1.3 (favorable). Final damage = base × source_mod × crit × 1.3 × pierce_falloff.

**AC-14** — **GIVEN** Flying Sword (金/metal) hits Ghost Flame (火/fire), **WHEN** damage is calculated, **THEN** element_modifier = 0.8 (unfavorable for the Metal attacker — 火克金: Fire overcomes Metal).

**AC-14b** (matchup coverage — remaining favorable pairs) — **GIVEN** each favorable matchup in {(wood,earth), (earth,water), (water,fire), (fire,metal)}, **WHEN** a weapon of the source element hits an enemy of the target element, **THEN** element_modifier = 1.3. One assertion per pair — guards against a dropped tuple in `favorable_set` (a typo would silently pass AC-13 alone).

**AC-14c** (matchup coverage — unfavorable mirrors) — **GIVEN** each reversed pair in {(earth,wood), (water,earth), (fire,water), (metal,fire)}, **WHEN** the source hits the target, **THEN** element_modifier = 0.8.

**AC-14d** (matchup coverage — unrelated pairs return 1.0) — **GIVEN** source=metal, target=water (neither overcomes the other), **WHEN** lookup resolves, **THEN** element_modifier = 1.0. Covers all 10 unrelated ordered pairs (e.g. wood→water, fire→earth, metal→earth) via the algorithmic fallthrough — the branch most likely to regress to a wrong 0.8/1.3.

**AC-14e** (matchup coverage — neutral target direction) — **GIVEN** source=metal, target=neutral, **WHEN** lookup resolves, **THEN** element_modifier = 1.0. The neutral short-circuit must check BOTH source and target (a refactor dropping the target check would break this while passing AC-03's source=neutral case).

**AC-15** — **GIVEN** player's element_inventory = {metal:0, wood:0, water:0, fire:0, earth:0}, **WHEN** player unlocks Flying Sword (金), **THEN** element_inventory.metal = 1. No combo activates (no second element present).

**AC-16** — **GIVEN** LevelUpPanel shows 3 options and one is a Water upgrade, **AND** player has metal≥1, **WHEN** panel renders, **THEN** the Water upgrade shows "相生! 激活 寒露凝锋" hint and glow border.

**AC-17** — **GIVEN** Ghost Market offers a 五行灵珠 (Phase Bead) of element Wood costing 40 XP, **WHEN** player completes the trade, **THEN** element_inventory.wood += 1 AND no stat buff is applied AND 40 XP is deducted.

**AC-18** — **GIVEN** player has all 5 elements ≥1, **WHEN** element inventory is checked, **THEN** all 5 generating cycle combos are simultaneously active. No special "五行齐全" bonus triggers.

**AC-19** — **GIVEN** 熔岩甲 is active, **WHEN** player enters Ghost Market interlude, **THEN** shield regen continues during interlude (no combat damage to interrupt grace period).

**AC-20** — **GIVEN** invalid element string "lightning" on an enemy .tres, **WHEN** element_modifier lookup occurs, **THEN** `push_error()` is called AND element is treated as neutral (modifier = 1.0).

**AC-21** — **GIVEN** Sun Wukong with both 火眼金睛 (active) and 矿脉精粹 (combo), **WHEN** a hit lands on an elite and the ore crit roll succeeds, **THEN** crit_multiplier = max(1.2, 1.5) = 1.5 (NOT 1.8 — the two crit sources resolve by max(), not multiplication, per Formula 8).

**AC-22** — **GIVEN** Merit Node 11 (元素感应) seeds fire=1 at run start AND the player's 修行者 starts with Talisman (fire), **WHEN** the run begins, **THEN** element_inventory.fire = 2 before the first level-up (per Core Rule 11 run-start initialization).

*`qa-lead` not consulted — Lean mode. Review manually before production.*

## Open Questions

- **OQ-1** (Bagua Array + 矿脉精粹): Bagua gets +15% tick damage instead of pierce. Is 15% the right number? May need playtest calibration — it should feel comparable in value to +1 pierce on projectile weapons.
- **OQ-2** (Boss slow scope): v0.5 default (per Edge Cases): Frost slow affects Boss `move_speed` ONLY, not `charge_speed` — the Charge stays a full-speed readable threat. Open: should slow duration also be reduced vs Bosses (e.g., ×0.5) to further protect the Boss threat profile? Playtest dependency.
- **OQ-7** (燎原 DPS-ceiling validation): Wildfire chain damage (50% non-decaying, 3 chains) is uncapped except by WILDFIRE_MAX_CHAINS. In dense packs (10+ enemies, 2:00-3:00 spike) one kill could cascade into many. v0.5 must add a playtest AC: "chain-kill count per trigger event ≤ X" derived from Combat's aggregate-DPS expectations, OR a per-frame chain cap. Owner: systems-designer. Flagged by cross-review W-01 + Five Phases design-review R-1.
- **OQ-3** (Phase Bead weighting): Phase Bead offers random element weighted toward player's weakest. Should it instead offer a choice of 2 elements? Adds decision depth but complicates UI.
- **OQ-4** (五行齐全 bonus): Should having all 5 elements ≥1 trigger a special bonus? Current design says no — each combo operates independently. But "complete the cycle" could be a powerful endgame goal. Defer to v0.6.
- **OQ-5** (Element-specific enemy waves): Should Stage Director spawn element-themed waves (e.g., "a wave of all-Fire enemies") to create matchup pressure? Or is the current mixed roster sufficient?
- **OQ-6** (Character starting element): Should characters start with +1 in an element matching their identity? (修行者 = neutral/none, 孙悟空 = 金/Metal for 金箍棒?) Defer to Character System v0.6 update.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Placeholder GDD for v0.5+ | Documents 5×5 matchup table, element_modifier slot in Combat. |
| 1 | 2026-05-27 | /design-review CONCERNS fix | Closed 2 BLOCKERS + 4 RECOMMENDED. Still placeholder scope. |
| 2 | 2026-06-02 | Gameplay depth initiative | **Complete rewrite**: expanded from matchup-only placeholder to full Five Phases Synergy System (build paths, generating-cycle combos, overcoming-cycle tradeoffs, upgrade pool integration). |
| 3 | 2026-06-02 | /design-review CONCERNS + cross-review | Fixed 4 blockers: (B-1) heading `Detailed Design`→`Detailed Rules`; (B-2) combo scaling caps (燎原/矿脉/寒露) aligned to Formula 3 @7 total; (B-3) crit_multiplier collision with 火眼金睛 resolved via new Formula 8 max(); (B-4) propagation to Enemy/Weapon/Level Up Pool/Ghost Market/Status Effects done. Added Core Rule 11 (run-start init), 燎原 damage-type contract, 熔岩甲 pipeline contract, OQ-7 (Wildfire DPS validation), AC-21/22. Corrected Boss charge_speed field + 镇墓兽 naming. |
| 4 | 2026-06-03 | /design-review of revision-1 (STALE — reviewer saw the pre-rewrite placeholder at git HEAD; revision-2/3 already addressed B-1/2/3 fantasy/dict/variable-table and B-4 Boss-element). Applied the items that still hold for revision-3 | Added 相克 matchup AC coverage (AC-14b remaining favorable pairs, 14c unfavorable mirrors, 14d unrelated-pairs→1.0, 14e neutral-target direction); added anti-dormancy minimum-coverage constraint (both Bosses + ≥4 Stage-1 enemies non-neutral); documented +30%/−20% asymmetry rationale; added FAVORABLE×UNFAVORABLE tuning-coupling note (ratio ≥ 1/fav); clarified 相生 is the combo system, not the 相克 matchup table. |
