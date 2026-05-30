## Validates the 5 Stage-2 (幽都鬼市) enemy archetype .tres files load + carry the
## stats from design/gdd/stage-2-enemies.md. Preloading each .tres makes CI's
## project import compile this file — a malformed .tres fails the build here.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/enemy -gexit

extends "res://tests/helpers/test_base.gd"

const LANTERN_GHOST := preload("res://resources/enemies/lantern_ghost.tres")
const RESENTFUL_INFANT := preload("res://resources/enemies/resentful_infant.tres")
const GHOST_BAILIFF := preload("res://resources/enemies/ghost_bailiff.tres")
const TOMB_GUARDIAN := preload("res://resources/enemies/tomb_guardian.tres")
const IMPERMANENCE := preload("res://resources/enemies/impermanence_elite.tres")


# ─── per-archetype stats (mirror stage-2-enemies.md) ─────────────────────

func test_lantern_ghost_stats() -> void:
	assert_eq(LANTERN_GHOST.display_name, "Lantern Ghost", "name")
	assert_float_eq(LANTERN_GHOST.max_hp, 28.0, 0.001, "hp")
	assert_float_eq(LANTERN_GHOST.move_speed, 96.0, 0.001, "speed")
	assert_float_eq(LANTERN_GHOST.damage, 16.0, 0.001, "damage")
	assert_eq(LANTERN_GHOST.movement_mode, 1, "WAVE_CHASE (floats)")
	assert_true(LANTERN_GHOST.wave_amplitude > 0.0 and LANTERN_GHOST.wave_amplitude < 2.0,
		"wave_amplitude is a unit-relative weave (~0.6), NOT a pixel value")
	assert_false(LANTERN_GHOST.is_elite, "filler, not elite")


func test_resentful_infant_stats() -> void:
	assert_eq(RESENTFUL_INFANT.display_name, "Resentful Infant", "name")
	assert_float_eq(RESENTFUL_INFANT.max_hp, 14.0, 0.001, "hp (swarm-fragile)")
	assert_float_eq(RESENTFUL_INFANT.move_speed, 150.0, 0.001, "speed (fastest)")
	assert_float_eq(RESENTFUL_INFANT.damage, 12.0, 0.001, "damage")
	assert_float_eq(RESENTFUL_INFANT.body_scale, 0.6, 0.001, "small")


func test_ghost_bailiff_stats() -> void:
	assert_eq(GHOST_BAILIFF.display_name, "Ghost Bailiff", "name")
	assert_float_eq(GHOST_BAILIFF.max_hp, 36.0, 0.001, "hp")
	assert_float_eq(GHOST_BAILIFF.move_speed, 124.0, 0.001, "fast hunter")
	assert_float_eq(GHOST_BAILIFF.damage, 20.0, 0.001, "damage")


func test_tomb_guardian_stats() -> void:
	assert_eq(TOMB_GUARDIAN.display_name, "Tomb Guardian", "name")
	assert_float_eq(TOMB_GUARDIAN.max_hp, 100.0, 0.001, "hp (tank)")
	assert_float_eq(TOMB_GUARDIAN.move_speed, 58.0, 0.001, "slow")
	assert_float_eq(TOMB_GUARDIAN.damage, 28.0, 0.001, "heavy")


func test_impermanence_elite_stats() -> void:
	assert_eq(IMPERMANENCE.display_name, "Impermanence", "name")
	assert_float_eq(IMPERMANENCE.max_hp, 135.0, 0.001, "hp")
	assert_float_eq(IMPERMANENCE.damage, 34.0, 0.001, "damage")
	assert_true(IMPERMANENCE.is_elite, "is_elite")
	assert_eq(IMPERMANENCE.elite_affixes, ["swift"], "swift affix (default)")


# ─── balance sanity: all within combat-system.md Stage-2 tier ranges ─────

func test_stage2_roster_within_balance_tiers() -> void:
	var roster := [LANTERN_GHOST, RESENTFUL_INFANT, GHOST_BAILIFF, TOMB_GUARDIAN, IMPERMANENCE]
	for a in roster:
		assert_true(a.max_hp >= 14.0 and a.max_hp <= 135.0,
			"%s hp in Stage-2 range" % a.display_name)
		assert_true(a.damage >= 12.0 and a.damage <= 34.0,
			"%s damage in Stage-2 range" % a.display_name)
		assert_true(a.damage_interval > 0.0, "%s has a positive damage interval" % a.display_name)
		# contact DPS = damage / interval — sanity, no degenerate values
		var dps: float = a.damage / a.damage_interval
		assert_true(dps > 0.0 and dps < 60.0, "%s contact DPS sane (got %.1f)" % [a.display_name, dps])
