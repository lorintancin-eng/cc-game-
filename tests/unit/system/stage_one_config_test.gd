## Validates the StageOneConfig builder (ADR-0004). Pins the full config
## construction — the typed Array[EnemyArchetype] pools, elite events, and the
## DemonSealConfig sub-resource — for the 3-minute (180s) timeline with the
## final-minute 怪浪 swarm wave. (Values are playtest-tunable; this test guards
## the STRUCTURE: 4 waves, swarm densest, elites + seal rescaled.)
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
	assert_float_eq(config.stage_duration, 180.0, 0.001, "3-minute stage")
	assert_not_null(config.boss_scene, "boss_scene assigned (FamineBeastBoss)")
	assert_null(config.trade_stall_config, "Stage 1 has no trade stalls")


# ─── waves: 4-wave 3-minute timeline + the swarm ─────────────────────────

func test_stage_one_has_four_waves_with_correct_scalars() -> void:
	var config := StageOneConfigScript.build()
	assert_eq(config.waves.size(), 4, "4 waves (3-minute timeline)")
	var expected := [
		[0.0, 1.35, 18], [40.0, 1.0, 26], [80.0, 0.7, 40], [120.0, 0.3, 80],
	]
	for i in range(4):
		assert_float_eq(config.waves[i].start_time, expected[i][0], 0.001, "wave %d start" % i)
		assert_float_eq(config.waves[i].spawn_interval, expected[i][1], 0.001, "wave %d interval" % i)
		assert_eq(config.waves[i].max_enemies, int(expected[i][2]), "wave %d max" % i)


func test_stage_one_final_wave_is_the_swarm() -> void:
	# 怪浪: the last wave (2:00) must be the densest + fastest of the run.
	var config := StageOneConfigScript.build()
	var swarm := config.waves[3]
	for i in range(3):
		assert_true(swarm.max_enemies > config.waves[i].max_enemies,
			"swarm max (%d) > wave %d max" % [swarm.max_enemies, i])
		assert_true(swarm.spawn_interval <= config.waves[i].spawn_interval,
			"swarm spawns at least as fast as wave %d" % i)
	assert_float_eq(swarm.start_time, 120.0, 0.001, "swarm starts in the final minute (2:00)")


func test_stage_one_wave_pools() -> void:
	var config := StageOneConfigScript.build()
	assert_eq(_names(config.waves[0].archetype_pool), ["Paper Doll", "Wandering Soul"], "wave 0 pool")
	assert_eq(_names(config.waves[1].archetype_pool),
		["Paper Doll", "Wandering Soul", "Fox Spirit", "Ghost Flame"], "wave 1 pool")
	for i in [2, 3]:
		assert_eq(_names(config.waves[i].archetype_pool),
			["Paper Doll", "Wandering Soul", "Fox Spirit", "Ghost Flame", "Stone Golem"],
			"wave %d pool (full roster)" % i)


func test_stage_one_wave_weights_index_match_pools() -> void:
	var config := StageOneConfigScript.build()
	for i in range(4):
		assert_eq(config.waves[i].archetype_weights.size(), config.waves[i].archetype_pool.size(),
			"wave %d weights length == pool length" % i)
	assert_eq(config.waves[2].archetype_weights, [2.8, 2.8, 1.2, 1.0, 0.35], "wave 2 weights")


# ─── elite events (rescaled) ─────────────────────────────────────────────

func test_stage_one_elite_events() -> void:
	var config := StageOneConfigScript.build()
	assert_eq(config.elite_events.size(), 2, "2 elite events")
	assert_float_eq(config.elite_events[0].spawn_time, 95.0, 0.001, "elite 1 rescaled")
	assert_eq(config.elite_events[0].archetype.display_name, "Shanxiao Elite", "elite 1 archetype")
	assert_eq(config.elite_events[0].affixes, ["iron_bones"], "elite 1 iron_bones")
	assert_float_eq(config.elite_events[1].spawn_time, 140.0, 0.001, "elite 2 rescaled")
	assert_eq(config.elite_events[1].affixes, ["swift"], "elite 2 swift")
	assert_float_eq(config.elite_events[1].spawn_distance, 420.0, 0.001, "elite spawn distance")


# ─── demon seal sub-resource (spawn time rescaled, rest unchanged) ────────

func test_stage_one_demon_seal_config() -> void:
	var d := StageOneConfigScript.build().demon_seal_config
	assert_not_null(d, "demon seal config present")
	assert_float_eq(d.spawn_time, 60.0, 0.001, "seal spawn rescaled to 1:00")
	assert_float_eq(d.required_seconds, 8.0, 0.001, "seal 8s")
	assert_float_eq(d.pressure_interval_multiplier, 0.65, 0.001, "pressure ×0.65")
	assert_eq(d.pressure_max_enemy_bonus, 6, "pressure +6")
	assert_eq(d.reward_orb_count, 8, "reward 8 orbs")
	assert_float_eq(d.reward_xp_value, 6.0, 0.001, "reward 6 xp each")
	assert_float_eq(d.reward_radius, 54.0, 0.001, "reward radius 54")
