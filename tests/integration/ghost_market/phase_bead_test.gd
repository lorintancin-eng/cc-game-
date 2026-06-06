## Integration test for 五行灵珠 Phase Bead (Story 012) — the testable logic core.
##
## Phase Bead is a Ghost Market trade that spends 40 XP to add +1 to the player's
## weakest element with NO stat buff (a pure 相生 combo-enabler), spawns no demon
## tide, and is gated behind Merit Node 7 (off until the Merit epic ships).
##
## Covers (logic core; the element-icon UI + the live no-tide trade flow are deferred):
##   - AC-17: 40 XP → element +1, XP −40, no stat buff
##   - affordability gate (insufficient XP → no-op)
##   - weakest-element weighting (deterministic) + all-≥1 edge
##   - Merit Node 7 gate defaults OFF (SaveService absent → Phase Bead never offered)
##   - TradeFormulas Phase Bead cost helpers
##
## (no-tide on purchase is wired in stage_director._on_trade_offer_chosen — the
## `elif chosen_kind == "phase_bead": pass` branch — and is covered by the live
## trade flow / playtest, not this unit-level test.)

extends "res://tests/helpers/test_base.gd"


func _make_player() -> Player:
	var player := Player.new()
	autofree(player)
	player.current_xp = 50.0
	player.xp_to_next_level = 1000.0  # high: emits don't level up
	player.level = 1
	return player


# ─── TradeFormulas Phase Bead cost ───────────────────────────────────────────

func test_phase_bead_cost_is_40_and_affordability_gate() -> void:
	assert_eq(TradeFormulas.PHASE_BEAD_XP_COST, 40, "Phase Bead is a flat 40 XP")
	assert_true(TradeFormulas.is_phase_bead_affordable(40.0), "40 XP affords it")
	assert_false(TradeFormulas.is_phase_bead_affordable(39.9), "below cost → not affordable")
	assert_float_eq(TradeFormulas.spend_phase_bead_xp(50.0), 10.0, 0.001, "50 − 40 = 10")
	assert_float_eq(TradeFormulas.spend_phase_bead_xp(20.0), 0.0, 0.001, "never below 0")


# ─── AC-17: element +1, XP −40, no stat buff ─────────────────────────────────

func test_phase_bead_grants_element_and_deducts_xp_no_buff() -> void:
	# Arrange — 50 XP, no blood-pact buffs yet
	var player := _make_player()

	# Act — buy a Wood Phase Bead
	var ok := player.execute_phase_bead("wood")

	# Assert — wood +1, XP −40, returns true
	assert_true(ok, "affordable purchase succeeds")
	assert_eq(player.element_inventory["wood"], 1, "wood +1")
	assert_float_eq(player.current_xp, 10.0, 0.001, "XP 50 − 40 = 10")
	# No stat buff: blood-pact stacks untouched, no weapon damage change path taken
	assert_eq(player.blood_pact_stacks(), 0, "Phase Bead applies NO stat buff")


func test_phase_bead_unaffordable_is_noop() -> void:
	# Arrange — only 30 XP
	var player := _make_player()
	player.current_xp = 30.0

	# Act
	var ok := player.execute_phase_bead("water")

	# Assert — rejected, no element gain, XP unchanged
	assert_false(ok, "insufficient XP → rejected")
	assert_eq(player.element_inventory["water"], 0, "no element gained")
	assert_float_eq(player.current_xp, 30.0, 0.001, "XP unchanged")


# ─── Weakest-element weighting (deterministic) ───────────────────────────────

func test_pick_weakest_element_returns_lowest_count() -> void:
	# Arrange — water is the unique lowest
	var player := _make_player()
	player.element_inventory = {"metal": 1, "wood": 2, "water": 0, "fire": 3, "earth": 1}

	# Act + Assert
	assert_eq(player.pick_weakest_element(), "water", "lowest-count element is picked")


func test_pick_weakest_element_all_equal_is_deterministic() -> void:
	# Arrange — all equal (incl. all ≥1): tiebreak by fixed cycle order → metal first
	var player := _make_player()
	player.element_inventory = {"metal": 1, "wood": 1, "water": 1, "fire": 1, "earth": 1}

	# Act + Assert — never a wasted purchase (every combo scales); deterministic
	assert_eq(player.pick_weakest_element(), "metal", "all-equal → first in cycle order (deterministic)")


# ─── Merit Node 7 gate defaults OFF ──────────────────────────────────────────

func test_phase_bead_gated_off_when_save_service_absent() -> void:
	# Arrange — headless: no SaveService autoload
	var sd := StageDirector.new()
	autofree(sd)
	assert_false(Engine.has_singleton("SaveService"), "precondition: SaveService absent in headless test")

	# Act + Assert — Node 7 gate is OFF → Phase Bead never offered
	assert_false(sd._is_phase_bead_unlocked(), "Phase Bead gated OFF without Merit Node 7")
