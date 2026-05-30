## Validates the StageOneConfig builder reproduces the Stage-1 values hardcoded
## in stage_director.gd (ADR-0004). This is the second half of the golden
## reference: stage_config_wave_selection_test pins the selection logic;
## this pins the full config construction — including the typed
## Array[EnemyArchetype] pools, the elite events, and the DemonSealConfig
## sub-resource (the parts most at risk from GDScript typed-array handling).
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/system -gexit

extends "res://tests/helpers/test_base.gd"

const StageOneConfigScript = preload("res://scripts/resources/stage_one_config.gd")


func _names(pool: Array) -> Array:
	var out: Array = []
	for a in pool:
		out.append(a.display_name)
	return out


# ─── stage metadata ───────────────────────────────────────────────────────

func test_stage_one_metadata() -> void:
	var config := StageOneConfigScript.build()
	assert_eq(config.stage_id, &"stage_1", "stage_id")
	assert_eq(config.display_name, "荒山古道", "display_name")
	assert_float_eq(config.stage_duration, 300.0, 0.001, "stage_duration")
	assert_not_null(config.boss_scene, "boss_scene assigned (FamineBeastBoss)")
	assert_null(config.trade_stall_config, "Stage 1 has no trade stalls")


# ─── waves: scalar values + typed archetype pools ────────────────────────

func test_stage_one_has_five_waves_with_correct_scalars() -> void:
	var config := StageOneConfigScript.build()
	assert_eq(config.waves.size(), 5, "5 waves")
	var expected := [
		[0.0, 1.35, 18], [60.0, 1.08, 24], [120.0, 0.90, 32],
		[180.0, 0.72, 42], [270.0, 0.55, 56],
	]
	for i in range(5):
		assert_float_eq(config.waves[i].start_time, expected[i][0], 0.001, "wave %d start" % i)
		assert_float_eq(config.waves[i].spawn_interval, expected[i][1], 0.001, "wave %d interval" % i)
		assert_eq(config.waves[i].max_enemies, int(expected[i][2]), "wave %d max" % i)


func test_stage_one_wave_pools_match_hardcoded_archetypes() -> void:
	var config := StageOneConfigScript.build()
	# Wave 0: Paper Doll + Wandering Soul
	assert_eq(_names(config.waves[0].archetype_pool), ["Paper Doll", "Wandering Soul"], "wave 0 pool")
	# Wave 1: + Fox Spirit + Ghost Flame
	assert_eq(_names(config.waves[1].archetype_pool),
		["Paper Doll", "Wandering Soul", "Fox Spirit", "Ghost Flame"], "wave 1 pool")
	# Waves 2-4: + Stone Golem (5-enemy pool)
	for i in [2, 3, 4]:
		assert_eq(_names(config.waves[i].archetype_pool),
			["Paper Doll", "Wandering Soul", "Fox Spirit", "Ghost Flame", "Stone Golem"],
			"wave %d pool" % i)


func test_stage_one_wave_weights_index_match_pools() -> void:
	var config := StageOneConfigScript.build()
	# Each weight array must be the same length as its pool (index-matched).
	for i in range(5):
		assert_eq(config.waves[i].archetype_weights.size(), config.waves[i].archetype_pool.size(),
			"wave %d weights length == pool length" % i)
	assert_eq(config.waves[2].archetype_weights, [2.8, 2.8, 1.2, 1.0, 0.35], "wave 2 weights")


# ─── elite events ─────────────────────────────────────────────────────────

func test_stage_one_elite_events() -> void:
	var config := StageOneConfigScript.build()
	assert_eq(config.elite_events.size(), 2, "2 elite events")
	assert_float_eq(config.elite_events[0].spawn_time, 180.0, 0.001, "elite 1 @ 3:00")
	assert_eq(config.elite_events[0].archetype.display_name, "Shanxiao Elite", "elite 1 archetype")
	assert_eq(config.elite_events[0].affixes, ["iron_bones"], "elite 1 iron_bones")
	assert_float_eq(config.elite_events[1].spawn_time, 240.0, 0.001, "elite 2 @ 4:00")
	assert_eq(config.elite_events[1].affixes, ["swift"], "elite 2 swift")
	assert_float_eq(config.elite_events[1].spawn_distance, 420.0, 0.001, "elite spawn distance")


# ─── demon seal sub-resource ──────────────────────────────────────────────

func test_stage_one_demon_seal_config() -> void:
	var d := StageOneConfigScript.build().demon_seal_config
	assert_not_null(d, "demon seal config present")
	assert_float_eq(d.spawn_time, 120.0, 0.001, "seal spawn 2:00")
	assert_float_eq(d.required_seconds, 8.0, 0.001, "seal 8s")
	assert_float_eq(d.pressure_interval_multiplier, 0.65, 0.001, "pressure ×0.65")
	assert_eq(d.pressure_max_enemy_bonus, 6, "pressure +6")
	assert_eq(d.reward_orb_count, 8, "reward 8 orbs")
	assert_float_eq(d.reward_xp_value, 6.0, 0.001, "reward 6 xp each")
	assert_float_eq(d.reward_radius, 54.0, 0.001, "reward radius 54")
