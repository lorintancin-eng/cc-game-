## Unit tests for TradeFormulas — the Ghost Market Trade economic + penalty math
## (ghost-market-trade.md revision-1). Every assertion traces to a Formula or an
## Acceptance Criterion in the GDD. Pure static math → no scene tree needed.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/system -gexit

extends "res://tests/helpers/test_base.gd"


# ─── Formula 2 — Blood Pact max-HP cost escalation ───────────────────────

func test_blood_pact_cost_escalates_15_20_25() -> void:
	assert_eq(TradeFormulas.blood_pact_max_hp_cost(0), 15, "trade 0 → 15")
	assert_eq(TradeFormulas.blood_pact_max_hp_cost(1), 20, "trade 1 → 20")
	assert_eq(TradeFormulas.blood_pact_max_hp_cost(2), 25, "trade 2 → 25")


func test_blood_pact_cost_clamps_past_third_trade() -> void:
	# n beyond the array clamps to the last cost (25), never errors.
	assert_eq(TradeFormulas.blood_pact_max_hp_cost(3), 25, "trade 3 clamps to 25")
	assert_eq(TradeFormulas.blood_pact_max_hp_cost(99), 25, "large n clamps to 25")


# ─── Formula 1 — Blood Pact damage buff with structural ceiling ──────────

func test_blood_pact_damage_typical_base8() -> void:
	# GDD worked example: base 8, stacked 18 (one +10 upgrade), 2 pacts → 20.4.
	var dmg := TradeFormulas.weapon_damage_after_pact(18.0, 8.0, 2)
	assert_float_eq(dmg, 20.4, 0.001, "minf(18 + 8×0.15×2, 40) = 20.4")


func test_blood_pact_damage_ceiling_holds_low_base6() -> void:
	# AC-03b-ceiling: base 6, stacked 36, 3 pacts → clamped to 6×5 = 30.0.
	var dmg := TradeFormulas.weapon_damage_after_pact(36.0, 6.0, 3)
	assert_float_eq(dmg, 30.0, 0.001, "minf(38.7, 30.0) = 30.0 — ceiling holds for low base")


func test_blood_pact_damage_at_ceiling_base8() -> void:
	# AC-08: base 8, stacked 38, 3 pacts → minf(41.6, 40.0) = 40.0 (exactly at ceiling).
	var dmg := TradeFormulas.weapon_damage_after_pact(38.0, 8.0, 3)
	assert_float_eq(dmg, 40.0, 0.001, "minf(41.6, 40.0) = 40.0")


func test_blood_pact_damage_zero_stacks_is_passthrough() -> void:
	var dmg := TradeFormulas.weapon_damage_after_pact(18.0, 8.0, 0)
	assert_float_eq(dmg, 18.0, 0.001, "0 pacts → unchanged stacked damage")


# ─── Blood Pact floor + stack-cap lock ───────────────────────────────────

func test_blood_pact_locked_below_hp_floor() -> void:
	# AC-04-floor: max_hp 54, cost 15 → 39 < 40 → LOCKED.
	assert_true(TradeFormulas.is_blood_pact_locked(54.0, 0, 0), "54-15=39 < 40 → locked")


func test_blood_pact_unlocked_at_hp_floor_boundary() -> void:
	# AC-04-floor: max_hp 56, cost 15 → 41 ≥ 40 → ENABLED.
	assert_false(TradeFormulas.is_blood_pact_locked(56.0, 0, 0), "56-15=41 ≥ 40 → unlocked")


func test_blood_pact_locked_at_stack_cap() -> void:
	# AC-07: 3 pacts already taken → locked regardless of HP.
	assert_true(TradeFormulas.is_blood_pact_locked(500.0, 0, 3),
		"3 stacks → locked even with huge HP")


func test_blood_pact_triple_pact_leaves_exactly_floor() -> void:
	# Formula 2 note: 100 HP − (15+20+25=60) = 40 = floor. The third pact at n=2
	# (cost 25) on max_hp 65 → 40 ≥ 40 → still allowed.
	assert_false(TradeFormulas.is_blood_pact_locked(65.0, 2, 2), "65-25=40 → at floor, allowed")
	assert_true(TradeFormulas.is_blood_pact_locked(64.0, 2, 2), "64-25=39 < 40 → locked")


func test_apply_blood_pact_max_hp_and_clamp() -> void:
	# AC-03: max 100, n0 → 85; current_hp clamped to the new max.
	var new_max := TradeFormulas.apply_blood_pact_max_hp(100.0, 0)
	assert_float_eq(new_max, 85.0, 0.001, "100 - 15 = 85")
	assert_float_eq(TradeFormulas.clamp_current_hp(90.0, new_max), 85.0, 0.001, "current 90 → clamped to 85")
	assert_float_eq(TradeFormulas.clamp_current_hp(70.0, new_max), 70.0, 0.001, "current 70 → unchanged")


# ─── Formula 3 — Soul Codex XP cost ──────────────────────────────────────

func test_soul_codex_cost_escalates_60_80_110_150() -> void:
	assert_eq(TradeFormulas.soul_codex_xp_cost(0), 60, "trade 0 → 60")
	assert_eq(TradeFormulas.soul_codex_xp_cost(1), 80, "trade 1 → 80")
	assert_eq(TradeFormulas.soul_codex_xp_cost(2), 110, "trade 2 → 110")
	assert_eq(TradeFormulas.soul_codex_xp_cost(3), 150, "trade 3 → 150")
	assert_eq(TradeFormulas.soul_codex_xp_cost(50), 150, "large n clamps to 150")


func test_soul_codex_affordability_gate() -> void:
	# AC-05: 40 XP, cost 60 → unaffordable; 60 XP → affordable.
	assert_false(TradeFormulas.is_soul_codex_affordable(40.0, 0), "40 < 60 → disabled")
	assert_true(TradeFormulas.is_soul_codex_affordable(60.0, 0), "60 ≥ 60 → enabled")


func test_soul_codex_spend_never_below_zero() -> void:
	# Spend clamps at 0 (never de-levels). Real flow disables unaffordable offers,
	# but the maxf guard is defense-in-depth.
	assert_float_eq(TradeFormulas.spend_soul_codex_xp(200.0, 0), 140.0, 0.001, "200 - 60 = 140")
	assert_float_eq(TradeFormulas.spend_soul_codex_xp(40.0, 0), 0.0, 0.001, "40 - 60 floored to 0")


# ─── Formula 4 — demon tide intensity per trade ──────────────────────────

func test_demon_tide_trade_1_and_2_are_five_normals_no_elite() -> void:
	# AC-06-tide1 / AC-06-tide2.
	for n in [1, 2]:
		var spec := TradeFormulas.demon_tide(n, 0)
		assert_eq(spec.normal_count, 5, "trade %d → 5 normals" % n)
		assert_eq(spec.elite_count, 0, "trade %d → 0 elites" % n)
		assert_float_eq(spec.interval_mult, 0.75, 0.001, "trade %d → ×0.75" % n)
		assert_float_eq(spec.window_seconds, 12.0, 0.001, "trade %d → 12s window" % n)


func test_demon_tide_trade_3_adds_one_elite() -> void:
	# AC-06-tide3: 5 normals + 1 Impermanence elite.
	var spec := TradeFormulas.demon_tide(3, 0)
	assert_eq(spec.normal_count, 5, "5 normals")
	assert_eq(spec.elite_count, 1, "1 elite from trade 3")
	assert_float_eq(spec.interval_mult, 0.75, 0.001, "×0.75")
	assert_float_eq(spec.window_seconds, 12.0, 0.001, "12s")


func test_demon_tide_trade_4_escalates() -> void:
	# AC-06-tide4: 6 normals + 1 elite, ×0.65 for 20s.
	var spec := TradeFormulas.demon_tide(4, 0)
	assert_eq(spec.normal_count, 6, "6 normals at trade 4")
	assert_eq(spec.elite_count, 1, "1 elite")
	assert_float_eq(spec.interval_mult, 0.65, 0.001, "×0.65")
	assert_float_eq(spec.window_seconds, 20.0, 0.001, "20s window")


func test_demon_tide_clamps_past_trade_4() -> void:
	var spec := TradeFormulas.demon_tide(9, 0)
	assert_eq(spec.normal_count, 6, "trade 9 clamps to the 4+ row (6 normals)")
	assert_eq(spec.elite_count, 1, "still 1 elite")
	assert_float_eq(spec.window_seconds, 20.0, 0.001, "still 20s")


# ─── market_unease tide bonus (Rule 8) ───────────────────────────────────

func test_market_unease_adds_at_most_one_normal() -> void:
	# unease 0 → no bonus; unease 1/2/3 → exactly +1 normal (capped).
	assert_eq(TradeFormulas.demon_tide(1, 0).normal_count, 5, "unease 0 → 5")
	assert_eq(TradeFormulas.demon_tide(1, 1).normal_count, 6, "unease 1 → +1 → 6")
	assert_eq(TradeFormulas.demon_tide(1, 3).normal_count, 6, "unease 3 → still only +1 → 6")


func test_market_unease_counter_clamps_at_three() -> void:
	assert_eq(TradeFormulas.clamp_market_unease(5), 3, "raw 5 clamps to 3")
	assert_eq(TradeFormulas.clamp_market_unease(0), 0, "0 stays 0")
	assert_eq(TradeFormulas.clamp_market_unease(-2), 0, "negative clamps to 0")
