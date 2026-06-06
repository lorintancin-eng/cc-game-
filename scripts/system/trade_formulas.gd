class_name TradeFormulas
extends RefCounted

## Pure, deterministic math for the Ghost Market Trade (ghost-market-trade.md
## revision-1). Static functions only — no scene tree, no node state — so the
## entire economic + penalty model is unit-testable headlessly and locked under
## CI BEFORE any live wiring (TradeStall node, TradePanel UI, StageDirector tide
## spawning) touches it.
##
## This is the single source of truth for the trade schedule. TradeStallConfig
## holds the tunable knobs for the editor; where they overlap, the live wiring
## decides precedence — but the canonical defaults (and the trade-4 escalation
## the flat TradeStallConfig schema can't express) live here.
##
## Covers Formulas 1-4, the Blood Pact max-HP floor lock, the Soul Codex
## affordability gate, and the market_unease tide bonus.

# ─── Blood Pact (血契) — Formula 1 + 2 ────────────────────────────────────
const BLOOD_PACT_HP_COSTS: Array[int] = [15, 20, 25]
const BLOOD_PACT_HP_FLOOR: int = 40
const BLOOD_PACT_DAMAGE_PER_STACK: float = 0.15
const BLOOD_PACT_MAX_STACKS: int = 3
## Source-modifier ceiling from combat-system.md — Formula 1's structural clamp.
const SOURCE_MODIFIER_CEILING_MULT: float = 5.0

# ─── Soul Codex (魂典) — Formula 3 ────────────────────────────────────────
const SOUL_CODEX_XP_COSTS: Array[int] = [60, 80, 110, 150]

# ─── Phase Bead (五行灵珠) — flat XP cost, pure 相生 combo-enabler (Story 012) ──
const PHASE_BEAD_XP_COST: int = 40

# ─── Demon tide (Formula 4) — indexed by 1-based cumulative trade n (clamped) ─
const DEMON_TIDE_NORMALS: Array[int] = [5, 5, 5, 6]
const DEMON_TIDE_ELITES: Array[int] = [0, 0, 1, 1]
const DEMON_TIDE_INTERVAL_MULTS: Array[float] = [0.75, 0.75, 0.75, 0.65]
const DEMON_TIDE_WINDOWS: Array[float] = [12.0, 12.0, 12.0, 20.0]

# ─── market_unease (non-engagement FOMO, Rule 8) ──────────────────────────
const MARKET_UNEASE_MAX: int = 3
## At most +1 normal enemy added to the next tide regardless of unease magnitude.
const MARKET_UNEASE_TIDE_BONUS: int = 1


# ─── Blood Pact ───────────────────────────────────────────────────────────

## Formula 2 — permanent max-HP cost by global trade counter `n` (0-indexed,
## clamped to the last cost). 15 / 20 / 25.
static func blood_pact_max_hp_cost(n: int) -> int:
	return BLOOD_PACT_HP_COSTS[clampi(n, 0, BLOOD_PACT_HP_COSTS.size() - 1)]


## Formula 1 — weapon damage after Blood Pact stacks, structurally clamped to
## the source-modifier ceiling (base × 5.0) for ANY base value. 火眼金睛 crit is
## a SEPARATE downstream multiplicative stage and is intentionally NOT included.
static func weapon_damage_after_pact(stacked_weapon_damage: float, base_weapon_damage: float, blood_pact_stacks: int) -> float:
	var boosted := stacked_weapon_damage + base_weapon_damage * BLOOD_PACT_DAMAGE_PER_STACK * float(blood_pact_stacks)
	return minf(boosted, base_weapon_damage * SOURCE_MODIFIER_CEILING_MULT)


## A Blood Pact offer is locked (disabled) when the stack cap is hit OR when
## paying the cost would drop max_hp below the hard floor of 40.
static func is_blood_pact_locked(max_hp: float, n: int, blood_pact_stacks: int) -> bool:
	if blood_pact_stacks >= BLOOD_PACT_MAX_STACKS:
		return true
	return max_hp - float(blood_pact_max_hp_cost(n)) < float(BLOOD_PACT_HP_FLOOR)


## The new max_hp after paying a Blood Pact (no floor guard here — the lock in
## is_blood_pact_locked prevents an illegal spend upstream).
static func apply_blood_pact_max_hp(max_hp: float, n: int) -> float:
	return max_hp - float(blood_pact_max_hp_cost(n))


## current_hp is clamped to never exceed the reduced max_hp.
static func clamp_current_hp(current_hp: float, new_max_hp: float) -> float:
	return minf(current_hp, new_max_hp)


# ─── Soul Codex ───────────────────────────────────────────────────────────

## Formula 3 — XP cost by global trade counter `n` (0-indexed, clamped).
## 60 / 80 / 110 / 150.
static func soul_codex_xp_cost(n: int) -> int:
	return SOUL_CODEX_XP_COSTS[clampi(n, 0, SOUL_CODEX_XP_COSTS.size() - 1)]


## A Soul Codex offer is affordable when current XP covers the cost.
static func is_soul_codex_affordable(current_xp: float, n: int) -> bool:
	return current_xp >= float(soul_codex_xp_cost(n))


## XP after a Soul Codex spend — never below 0, never triggers a level-up.
static func spend_soul_codex_xp(current_xp: float, n: int) -> float:
	return maxf(current_xp - float(soul_codex_xp_cost(n)), 0.0)


## A Phase Bead (五行灵珠) is affordable when current XP covers the flat 40-XP cost.
static func is_phase_bead_affordable(current_xp: float) -> bool:
	return current_xp >= float(PHASE_BEAD_XP_COST)


## XP after a Phase Bead spend — never below 0.
static func spend_phase_bead_xp(current_xp: float) -> float:
	return maxf(current_xp - float(PHASE_BEAD_XP_COST), 0.0)


# ─── Demon tide + market unease ───────────────────────────────────────────

## market_unease is a monotonic run counter capped at MARKET_UNEASE_MAX (3) so
## ignoring every stall can't cascade into an oppressive bonus.
static func clamp_market_unease(raw_unease: int) -> int:
	return clampi(raw_unease, 0, MARKET_UNEASE_MAX)


## Formula 4 — the demon tide a trade summons. `n` is the 1-based cumulative
## trade number (clamped at 4+). `market_unease` adds at most +1 normal enemy.
static func demon_tide(n: int, market_unease: int) -> DemonTideSpec:
	var idx := clampi(n - 1, 0, DEMON_TIDE_NORMALS.size() - 1)
	var spec := DemonTideSpec.new()
	spec.normal_count = DEMON_TIDE_NORMALS[idx]
	spec.elite_count = DEMON_TIDE_ELITES[idx]
	spec.interval_mult = DEMON_TIDE_INTERVAL_MULTS[idx]
	spec.window_seconds = DEMON_TIDE_WINDOWS[idx]
	spec.normal_count += mini(clamp_market_unease(market_unease), MARKET_UNEASE_TIDE_BONUS)
	return spec
