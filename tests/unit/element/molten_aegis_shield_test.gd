## Unit tests for 熔岩甲 Molten Aegis (火生土) — Story 007 / ADR-0006 / Formula 5.
##
## When 火生土 is active, Player reads ComboManager.get_shield_params() →
## {max_hp, regen, grace} and runs a damage-absorbing shield: incoming damage hits
## the shield before player HP (excess passes through); the shield regenerates
## `regen` per 5s after a `grace`-second window since the last hit.
##
## Covers:
##   - AC-05: shield absorbs up to its HP, excess to player HP, shield → 0
##   - AC-06: regen fires after the grace period (per MOLTEN_SHIELD_REGEN_INTERVAL)
##   - grace blocks regen while it is counting down
##   - Formula 5 scaling: steps=3 → max_hp 30, regen 6
##   - clamp to _shield_max; inactive-combo / null-ComboManager guards
##
## Instantiation: Player.new() + a real ComboManager.new() driven via
## _on_inventory_changed to activate 火生土. autofree() teardown. (Visual molten
## ring VFX is deferred — headless-unverifiable.)

extends "res://tests/helpers/test_base.gd"


## Factory: Player (HP 50/100) with a real ComboManager whose 火生土 is set to
## (fire, earth). Activate via fire>=1 AND earth>=1.
func _make_player_with_molten(fire: int, earth: int) -> Player:
	var player := Player.new()
	autofree(player)
	player.max_hp = 100.0
	player.current_hp = 50.0
	var cm := ComboManager.new()
	autofree(cm)
	cm._on_inventory_changed({"metal": 0, "wood": 0, "water": 0, "fire": fire, "earth": earth})
	player._combo_manager = cm
	return player


# ─── AC-05: absorb + excess ──────────────────────────────────────────────────

func test_molten_shield_absorbs_then_excess_to_hp() -> void:
	# Arrange — 火生土 active (steps=0), shield at 10
	var player := _make_player_with_molten(1, 1)
	player._shield_hp = 10.0

	# Act — 15 damage: shield absorbs 10, 5 excess to HP
	player.take_damage(15.0)

	# Assert
	assert_float_eq(player.shield_hp(), 0.0, 0.001, "shield absorbs 10 → 0")
	assert_float_eq(player.current_hp, 45.0, 0.001, "excess 5 → HP 50-5=45")


func test_molten_shield_excess_passes_through() -> void:
	# Arrange
	var player := _make_player_with_molten(1, 1)
	player._shield_hp = 10.0

	# Act — 25 damage: shield 10 absorbed, 15 excess
	player.take_damage(25.0)

	# Assert
	assert_float_eq(player.shield_hp(), 0.0, 0.001, "shield depleted")
	assert_float_eq(player.current_hp, 35.0, 0.001, "excess 15 → 50-15=35")


# ─── Activation grants a full shield (Formula 5) ─────────────────────────────

func test_molten_on_activate_grants_full_shield_steps_zero() -> void:
	# Arrange — fire=1, earth=1 → steps=0 → max_hp 15
	var player := _make_player_with_molten(1, 1)

	# Act
	player._on_combo_activated(ComboManager.COMBO_MOLTEN)

	# Assert — full shield at activation
	assert_float_eq(player.shield_hp(), 15.0, 0.001, "steps=0 → shield_max 15, full on activate")


func test_molten_on_activate_scales_at_steps_three() -> void:
	# Arrange — fire=2, earth=3 → total=5 → steps=3 → max_hp 30
	var player := _make_player_with_molten(2, 3)

	# Act
	player._on_combo_activated(ComboManager.COMBO_MOLTEN)

	# Assert
	assert_float_eq(player.shield_hp(), 30.0, 0.001, "steps=3 → shield_max 30, full")


func test_molten_on_activate_ignores_other_combos() -> void:
	# Arrange
	var player := _make_player_with_molten(1, 1)

	# Act — a different combo id must not grant a 熔岩甲 shield
	player._on_combo_activated(ComboManager.COMBO_WILDFIRE)

	# Assert
	assert_float_eq(player.shield_hp(), 0.0, 0.001, "non-火生土 activation grants no shield")


# ─── AC-06: regen after grace ────────────────────────────────────────────────

func test_molten_shield_regens_after_grace() -> void:
	# Arrange — active, depleted, grace already elapsed
	var player := _make_player_with_molten(1, 1)
	player._shield_hp = 0.0
	player._shield_grace_remaining = 0.0

	# Act — one full regen interval
	player._tick_molten_shield(Player.MOLTEN_SHIELD_REGEN_INTERVAL)

	# Assert — +regen (3 at steps=0)
	assert_float_eq(player.shield_hp(), 3.0, 0.001, "steps=0 → regen 3 per interval")


func test_molten_shield_grace_blocks_regen() -> void:
	# Arrange — a hit sets the grace window
	var player := _make_player_with_molten(1, 1)
	player._shield_hp = 5.0
	player.take_damage(2.0)  # absorbs 2 → shield 3; grace set to 2.0
	assert_float_eq(player.shield_hp(), 3.0, 0.001, "precondition: shield 3 after a 2-dmg hit")

	# Act — tick within the grace window
	player._tick_molten_shield(1.0)

	# Assert — no regen while grace counts down
	assert_float_eq(player.shield_hp(), 3.0, 0.001, "no regen during grace period")


func test_molten_shield_regen_scales_at_steps_three() -> void:
	# Arrange — steps=3 → regen 6
	var player := _make_player_with_molten(2, 3)
	player._shield_max = 30.0
	player._shield_hp = 0.0
	player._shield_grace_remaining = 0.0

	# Act
	player._tick_molten_shield(Player.MOLTEN_SHIELD_REGEN_INTERVAL)

	# Assert
	assert_float_eq(player.shield_hp(), 6.0, 0.001, "steps=3 → regen 6 per interval")


func test_molten_shield_regen_clamps_to_max() -> void:
	# Arrange — near max (15 at steps=0)
	var player := _make_player_with_molten(1, 1)
	player._shield_hp = 14.0
	player._shield_grace_remaining = 0.0

	# Act
	player._tick_molten_shield(Player.MOLTEN_SHIELD_REGEN_INTERVAL)

	# Assert — 14+3 clamped to 15
	assert_float_eq(player.shield_hp(), 15.0, 0.001, "regen clamps to shield_max")


# ─── Inactive / null guards ──────────────────────────────────────────────────

func test_molten_shield_inactive_combo_no_absorb_no_regen() -> void:
	# Arrange — fire=1, earth=0 → 火生土 NOT active
	var player := _make_player_with_molten(1, 0)
	player._shield_hp = 10.0  # stale value, must be ignored

	# Act — damage with the combo inactive
	player.take_damage(15.0)

	# Assert — shield path skipped, full damage to HP
	assert_float_eq(player.current_hp, 35.0, 0.001, "inactive: full 15 to HP")
	player._shield_grace_remaining = 0.0
	player._tick_molten_shield(Player.MOLTEN_SHIELD_REGEN_INTERVAL)
	assert_float_eq(player.shield_hp(), 10.0, 0.001, "inactive: no regen")


func test_molten_shield_null_combo_manager_no_crash() -> void:
	# Arrange — no ComboManager at all
	var player := Player.new()
	autofree(player)
	player.max_hp = 100.0
	player.current_hp = 50.0

	# Act — both paths must be guarded no-ops
	player.take_damage(10.0)
	player._tick_molten_shield(Player.MOLTEN_SHIELD_REGEN_INTERVAL)

	# Assert
	assert_float_eq(player.current_hp, 40.0, 0.001, "null combo: normal damage")
	assert_float_eq(player.shield_hp(), 0.0, 0.001, "null combo: no shield")
