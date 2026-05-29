## Unit tests for Enemy elite stat modifiers (Enemy System — balance math).
##
## Elite enemies multiply their base stats and then apply per-affix multipliers
## on top (compounding). This determines elite difficulty, so per
## coding-standards.md ("enemy spawning / balance formulas") it warrants coverage.
##
## Formula (scripts/enemy/enemy.gd::_apply_elite_modifiers):
##   max_hp     *= max(elite_health_multiplier, 0.1)
##   damage     *= max(elite_damage_multiplier, 0.0)
##   move_speed *= max(elite_speed_multiplier, 0.1)
##   for affix:
##     iron_bones → max_hp     *= max(iron_bones_health_multiplier, 0.1)
##     swift      → move_speed *= max(swift_speed_multiplier, 0.1)
##
## Instantiated via .new() with explicit stat + multiplier values (no archetype,
## no scene tree — the method is pure field arithmetic and never touches the
## @onready visual nodes). autofree frees the CharacterBody2D at teardown.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/enemy -gexit

extends "res://tests/helpers/test_base.gd"

const EnemyScript = preload("res://scripts/enemy/enemy.gd")


# Build an enemy with explicit base stats + multipliers (so the test is
# deterministic regardless of future default changes).
func _make_elite_enemy(
	base_hp: float, base_damage: float, base_speed: float,
	hp_mult: float, dmg_mult: float, spd_mult: float,
	affixes: Array[String] = []
) -> Enemy:
	var enemy: Enemy = EnemyScript.new()
	autofree(enemy)
	enemy.max_hp = base_hp
	enemy.damage = base_damage
	enemy.move_speed = base_speed
	enemy.elite_health_multiplier = hp_mult
	enemy.elite_damage_multiplier = dmg_mult
	enemy.elite_speed_multiplier = spd_mult
	enemy.elite_affixes = affixes
	return enemy


# ─── base elite multipliers (no affixes) ─────────────────────────────────

func test_enemy_elite_applies_all_three_base_multipliers() -> void:
	# Arrange — base 10/8/100, multipliers 2.0 / 1.5 / 1.2.
	var enemy := _make_elite_enemy(10.0, 8.0, 100.0, 2.0, 1.5, 1.2)

	# Act
	enemy._apply_elite_modifiers()

	# Assert
	assert_float_eq(enemy.max_hp, 20.0, 0.001, "hp × 2.0")
	assert_float_eq(enemy.damage, 12.0, 0.001, "damage × 1.5")
	assert_float_eq(enemy.move_speed, 120.0, 0.001, "speed × 1.2")


# ─── affixes compound on top of the base elite multipliers ───────────────

func test_enemy_iron_bones_compounds_health() -> void:
	# Arrange — base hp 10, elite ×2.0, iron_bones ×1.5 → 10×2×1.5 = 30.
	var enemy := _make_elite_enemy(10.0, 8.0, 100.0, 2.0, 1.5, 1.2, ["iron_bones"])
	enemy.iron_bones_health_multiplier = 1.5

	# Act
	enemy._apply_elite_modifiers()

	# Assert — iron_bones multiplies AFTER the base elite hp multiplier.
	assert_float_eq(enemy.max_hp, 30.0, 0.001, "hp × 2.0 (elite) × 1.5 (iron_bones)")
	# Speed / damage unaffected by iron_bones.
	assert_float_eq(enemy.move_speed, 120.0, 0.001, "iron_bones does not touch speed")


func test_enemy_swift_compounds_speed() -> void:
	# Arrange — base speed 100, elite ×1.2, swift ×1.5 → 100×1.2×1.5 = 180.
	var enemy := _make_elite_enemy(10.0, 8.0, 100.0, 2.0, 1.5, 1.2, ["swift"])
	enemy.swift_speed_multiplier = 1.5

	# Act
	enemy._apply_elite_modifiers()

	# Assert
	assert_float_eq(enemy.move_speed, 180.0, 0.001, "speed × 1.2 (elite) × 1.5 (swift)")
	assert_float_eq(enemy.max_hp, 20.0, 0.001, "swift does not touch hp")


func test_enemy_both_affixes_apply_to_their_own_stats() -> void:
	# Arrange — both affixes; each compounds on its respective stat.
	var enemy := _make_elite_enemy(10.0, 8.0, 100.0, 2.0, 1.5, 1.2, ["iron_bones", "swift"])
	enemy.iron_bones_health_multiplier = 1.5
	enemy.swift_speed_multiplier = 1.5

	# Act
	enemy._apply_elite_modifiers()

	# Assert
	assert_float_eq(enemy.max_hp, 30.0, 0.001, "hp gets elite × iron_bones")
	assert_float_eq(enemy.move_speed, 180.0, 0.001, "speed gets elite × swift")
	assert_float_eq(enemy.damage, 12.0, 0.001, "damage gets only the base elite multiplier")


# ─── defensive multiplier floors ─────────────────────────────────────────

func test_enemy_elite_health_multiplier_floored_at_min() -> void:
	# Arrange — a degenerate 0.0 health multiplier must be clamped to 0.1, not
	# zero out the enemy's HP.
	var enemy := _make_elite_enemy(10.0, 8.0, 100.0, 0.0, 1.5, 1.2)

	# Act
	enemy._apply_elite_modifiers()

	# Assert — 10 × max(0.0, 0.1) = 1.0
	assert_float_eq(enemy.max_hp, 1.0, 0.001, "health multiplier floored at 0.1")


# ─── configure_elite public flow ─────────────────────────────────────────

func test_enemy_configure_elite_sets_flag_and_inits_current_hp() -> void:
	# Arrange — no archetype, so configure_elite uses the current field values.
	# Set the iron_bones multiplier BEFORE configure_elite so it participates.
	var enemy := _make_elite_enemy(10.0, 8.0, 100.0, 2.0, 1.5, 1.2)
	enemy.iron_bones_health_multiplier = 1.5

	# Act
	enemy.configure_elite(["iron_bones"])

	# Assert — is_elite flagged, affixes stored, current_hp initialized to full
	# (post-modifier) max_hp = 10 × 2.0 × 1.5 = 30, clamped to >= 1.
	assert_true(enemy.is_elite, "configure_elite marks the enemy elite")
	assert_eq(enemy.elite_affixes, ["iron_bones"], "affixes stored")
	assert_float_eq(enemy.max_hp, 30.0, 0.001, "configure_elite applies elite + affix multipliers")
	assert_float_eq(enemy.current_hp, enemy.max_hp, 0.001, "current_hp initialized to full max_hp")
	assert_true(enemy.max_hp >= 1.0, "max_hp clamped to >= 1")
