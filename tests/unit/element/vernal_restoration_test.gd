## Unit tests for 春生回元 Vernal Restoration (水生木) — Story 010 / ADR-0006 / Formula 7.
##
## Player reads ComboManager.get_regen_params() → {hp_per_4s, xp_bonus} when 水生木
## is active and applies:
##   - accumulator-based unconditional HP regen (heals hp_per_4s every 4s, clamped)
##   - an XP-pickup multiplier (×(1 + xp_bonus)), multiplicative with xp_gain upgrades
##
## Covers:
##   - AC-11: +2 HP / 4s (or scaled), clamped to max_hp, works after taking damage
##   - AC-12: xp_bonus=0.30, orb 5.5 → effective 7.15
##   - Formula 7: steps=3 → hp_per_4s=5, xp_bonus=0.30
##   - Multiplicative with an existing xp_gain upgrade
##   - Accumulator: no heal before the interval; accumulates across sub-interval ticks
##   - Inactive combo / null ComboManager → no regen, no crash
##
## Instantiation: Player.new() + ComboManager.new() (no _ready) — the real
## ComboManager is driven via _on_inventory_changed to activate 水生木, then attached
## to the player's _combo_manager. autofree() handles teardown.
##
## Run via:
##   "/tmp/Godot_v4.6-stable_win64_console.exe" --headless \
##       -s res://addons/gut/gut_cmdln.gd \
##       -gtest=res://tests/unit/element/vernal_restoration_test.gd -gexit

extends "res://tests/helpers/test_base.gd"


func _inv(water: int, wood: int) -> Dictionary:
	return {"metal": 0, "wood": wood, "water": water, "fire": 0, "earth": 0}


## Factory: a bare Player (HP 50/100) with a real ComboManager whose 水生木 combo
## is activated to (water, wood). xp fields seeded so gain_experience never levels up.
func _make_player(water: int, wood: int) -> Player:
	var player := Player.new()
	autofree(player)
	player.max_hp = 100.0
	player.current_hp = 50.0
	player.level = 1
	player.current_xp = 0.0
	player.xp_to_next_level = 1000.0  # high: no level-up during XP assertions
	player.xp_gain_multiplier = 1.0
	var cm := ComboManager.new()
	autofree(cm)
	cm._on_inventory_changed(_inv(water, wood))
	player._combo_manager = cm
	return player


# ─── AC-11: HP regen on the interval tick ────────────────────────────────────

func test_vernal_regen_heals_hp_per_4s_on_interval() -> void:
	# Arrange — water=1, wood=1 → steps=0 → hp_per_4s = 2
	var player := _make_player(1, 1)

	# Act — one full interval elapses
	player._tick_vernal_regen(Player.VERNAL_REGEN_INTERVAL)

	# Assert — +2 HP
	assert_float_eq(player.current_hp, 52.0, 0.001, "水生木 active → +2 HP after 4s")


func test_vernal_regen_does_not_heal_before_interval() -> void:
	# Arrange
	var player := _make_player(1, 1)

	# Act — only half an interval
	player._tick_vernal_regen(Player.VERNAL_REGEN_INTERVAL * 0.5)

	# Assert — no heal yet
	assert_float_eq(player.current_hp, 50.0, 0.001, "no regen before the interval completes")


func test_vernal_regen_accumulates_across_sub_interval_ticks() -> void:
	# Arrange — hp_per_4s = 2
	var player := _make_player(1, 1)

	# Act — four 1.0s ticks sum to one 4s interval
	for i in range(4):
		player._tick_vernal_regen(1.0)

	# Assert — exactly one heal fired
	assert_float_eq(player.current_hp, 52.0, 0.001, "accumulated 4×1s → one +2 heal")


func test_vernal_regen_clamps_to_max_hp() -> void:
	# Arrange — current_hp near max
	var player := _make_player(1, 1)
	player.current_hp = 99.5

	# Act
	player._tick_vernal_regen(Player.VERNAL_REGEN_INTERVAL)

	# Assert — clamped, never exceeds max_hp
	assert_float_eq(player.current_hp, 100.0, 0.001, "regen clamps to max_hp")


func test_vernal_regen_works_after_taking_damage() -> void:
	# Arrange — AC-11 edge: regen is unconditional (no grace period)
	var player := _make_player(1, 1)
	player.take_damage(10.0)  # 50 → 40

	# Act
	player._tick_vernal_regen(Player.VERNAL_REGEN_INTERVAL)

	# Assert — regen still fires after damage
	assert_float_eq(player.current_hp, 42.0, 0.001, "regen unconditional — heals after taking damage")


# ─── Formula 7 scaling ───────────────────────────────────────────────────────

func test_vernal_regen_scales_at_steps_three() -> void:
	# Arrange — water=2, wood=3 → total=5 → steps=3 → hp_per_4s = 2 + 3×1 = 5
	var player := _make_player(2, 3)

	# Act
	player._tick_vernal_regen(Player.VERNAL_REGEN_INTERVAL)

	# Assert — +5 HP
	assert_float_eq(player.current_hp, 55.0, 0.001, "steps=3 → +5 HP per 4s")


func test_vernal_regen_caps_at_steps_five() -> void:
	# Arrange — water=5, wood=5 → total=10 → steps clamped to MAX_SCALE_STEPS=5
	#           → hp_per_4s = 2 + 5×1 = 7 (Formula 7 cap)
	var player := _make_player(5, 5)

	# Act
	player._tick_vernal_regen(Player.VERNAL_REGEN_INTERVAL)

	# Assert — +7 HP (capped, not 2 + 8×1)
	assert_float_eq(player.current_hp, 57.0, 0.001, "Formula 7 cap: steps clamp at 5 → +7 HP per 4s")


func test_vernal_regen_multi_interval_delta_fires_multiple_heals() -> void:
	# Arrange — hp_per_4s = 2; a single large delta spans two full intervals
	var player := _make_player(1, 1)

	# Act — 8.5s in one tick = two intervals (+0.5s remainder)
	player._tick_vernal_regen(Player.VERNAL_REGEN_INTERVAL * 2.0 + 0.5)

	# Assert — two heals fired in one call (catch-up), not one
	assert_float_eq(player.current_hp, 54.0, 0.001, "8.5s delta → two +2 heals (catch-up)")


# ─── Inactive / null guards ──────────────────────────────────────────────────

func test_vernal_regen_inactive_combo_no_heal() -> void:
	# Arrange — water=1, wood=0 → 水生木 NOT active
	var player := _make_player(1, 0)

	# Act
	player._tick_vernal_regen(Player.VERNAL_REGEN_INTERVAL)

	# Assert — no regen when the combo is inactive
	assert_float_eq(player.current_hp, 50.0, 0.001, "inactive 水生木 → no regen")


func test_vernal_regen_null_combo_manager_does_not_crash() -> void:
	# Arrange — no ComboManager attached
	var player := Player.new()
	autofree(player)
	player.max_hp = 100.0
	player.current_hp = 50.0

	# Act — must be a guarded no-op
	player._tick_vernal_regen(Player.VERNAL_REGEN_INTERVAL)

	# Assert — unchanged, no crash
	assert_float_eq(player.current_hp, 50.0, 0.001, "null ComboManager → regen is a no-op")


# ─── AC-12: XP pickup bonus (multiplicative) ─────────────────────────────────

func test_vernal_xp_bonus_multiplies_pickup_value() -> void:
	# Arrange — water=2, wood=3 → steps=3 → xp_bonus = 0.30 (GDD AC-12 example)
	var player := _make_player(2, 3)

	# Act — collect an orb worth 5.5
	player.gain_experience(5.5)

	# Assert — 5.5 × 1.0 × 1.30 = 7.15
	assert_float_eq(player.current_xp, 7.15, 0.001, "xp_bonus 0.30 → orb 5.5 becomes 7.15")


func test_vernal_xp_bonus_multiplicative_with_xp_gain_upgrade() -> void:
	# Arrange — steps=3 (xp_bonus 0.30) AND an existing +10% xp_gain upgrade
	var player := _make_player(2, 3)
	player.xp_gain_multiplier = 1.1

	# Act
	player.gain_experience(5.0)

	# Assert — 5.0 × 1.1 × 1.30 = 7.15 (multiplicative, not additive)
	assert_float_eq(player.current_xp, 7.15, 0.001, "xp_bonus stacks multiplicatively with xp_gain")


func test_vernal_xp_bonus_inactive_combo_no_bonus() -> void:
	# Arrange — water=1, wood=0 → 水生木 inactive → xp_bonus 0.0
	var player := _make_player(1, 0)

	# Act
	player.gain_experience(5.0)

	# Assert — base value only (×1.0)
	assert_float_eq(player.current_xp, 5.0, 0.001, "inactive combo → no XP bonus")


func test_vernal_xp_bonus_caps_at_steps_five() -> void:
	# Arrange — water=5, wood=5 → steps clamped at 5 → xp_bonus = 0.15 + 5×0.05 = 0.40 (cap)
	var player := _make_player(5, 5)

	# Act
	player.gain_experience(5.0)

	# Assert — 5.0 × 1.0 × 1.40 = 7.0 (capped bonus, not 0.15 + 8×0.05)
	assert_float_eq(player.current_xp, 7.0, 0.001, "Formula 7 cap: xp_bonus clamps at 0.40")
