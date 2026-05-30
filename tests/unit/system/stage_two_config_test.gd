## Validates StageTwoConfig.build() — the data-driven Stage 2 (幽都鬼市)
## definition (ADR-0004). Confirms it assembles the Step-6a enemies + the
## Step-6b Judge boss + the trade config, has NO Demon Seal, and that the
## shared get_active_wave() selection works on its wave timeline.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/system -gexit

extends "res://tests/helpers/test_base.gd"

const LANTERN_GHOST := preload("res://resources/enemies/lantern_ghost.tres")
const RESENTFUL_INFANT := preload("res://resources/enemies/resentful_infant.tres")
const TOMB_GUARDIAN := preload("res://resources/enemies/tomb_guardian.tres")
const IMPERMANENCE_ELITE := preload("res://resources/enemies/impermanence_elite.tres")


# ─── top-level config ────────────────────────────────────────────────────

func test_stage_two_config_identity() -> void:
	var c := StageTwoConfig.build()
	assert_eq(c.stage_id, &"stage_2", "stage_id")
	assert_eq(c.display_name, "幽都鬼市", "display_name")
	assert_float_eq(c.stage_duration, 300.0, 0.001, "5-minute stage")
	assert_not_null(c.boss_scene, "has a boss scene (Ghost Market Judge)")


func test_stage_two_has_no_demon_seal() -> void:
	# Stage 2's risk/reward is the trade stalls, not a Demon Seal.
	var c := StageTwoConfig.build()
	assert_null(c.demon_seal_config, "Stage 2 has no Demon Seal")


func test_stage_two_has_trade_stall_config() -> void:
	var c := StageTwoConfig.build()
	assert_not_null(c.trade_stall_config, "Stage 2 HAS a trade stall config")
	var t := c.trade_stall_config
	assert_eq(t.stall_count_per_run, 4, "4 stalls per run")
	assert_eq(t.stall_spawn_times.size(), 4, "4 spawn times")
	assert_float_eq(t.stall_spawn_times[0], 90.0, 0.001, "first stall at 1:30 (not 0:30)")
	assert_eq(t.demon_tide_elite_archetype, IMPERMANENCE_ELITE,
		"demon tide uses the Stage-2 Impermanence elite, not Shanxiao")
	assert_eq(t.demon_tide_elite_counts, [0, 0, 1, 1],
		"elite schedule per Formula 4 r1 (trade 1/2 = 0, 3/4 = 1)")


# ─── waves use the Stage-2 roster ────────────────────────────────────────

func test_stage_two_has_five_waves() -> void:
	var c := StageTwoConfig.build()
	assert_eq(c.waves.size(), 5, "5 wave bands (mirrors Stage 1 structure)")


func test_stage_two_wave_0_is_filler_plus_swarm() -> void:
	var c := StageTwoConfig.build()
	var wave0 := c.get_active_wave(0.0)
	assert_not_null(wave0, "wave at t=0")
	assert_true(wave0.archetype_pool.has(LANTERN_GHOST), "wave 0 has Lantern Ghost")
	assert_true(wave0.archetype_pool.has(RESENTFUL_INFANT), "wave 0 has Resentful Infant")


func test_stage_two_tank_joins_at_wave_2() -> void:
	var c := StageTwoConfig.build()
	# Tomb Guardian (tank) should NOT be in the early waves but present from 2:00.
	var wave0 := c.get_active_wave(0.0)
	assert_false(wave0.archetype_pool.has(TOMB_GUARDIAN), "no tank in wave 0")
	var wave2 := c.get_active_wave(120.0)
	assert_true(wave2.archetype_pool.has(TOMB_GUARDIAN), "tank joins at 2:00")


func test_stage_two_wave_selection_at_boundaries() -> void:
	# get_active_wave returns the band whose start_time is the greatest <= t.
	var c := StageTwoConfig.build()
	assert_float_eq(c.get_active_wave(0.0).start_time, 0.0, 0.001, "t=0 → wave 0")
	assert_float_eq(c.get_active_wave(59.0).start_time, 0.0, 0.001, "t=59 → still wave 0")
	assert_float_eq(c.get_active_wave(60.0).start_time, 60.0, 0.001, "t=60 → wave 1")
	assert_float_eq(c.get_active_wave(270.0).start_time, 270.0, 0.001, "t=270 → wave 4")
	assert_float_eq(c.get_active_wave(300.0).start_time, 270.0, 0.001, "t=300 → wave 4 (last)")


# ─── elite event ─────────────────────────────────────────────────────────

func test_stage_two_schedules_one_impermanence_elite() -> void:
	var c := StageTwoConfig.build()
	assert_eq(c.elite_events.size(), 1,
		"one scheduled elite (trade stalls provide the rest)")
	var e := c.elite_events[0]
	assert_eq(e.archetype, IMPERMANENCE_ELITE, "the scheduled elite is Impermanence")
	assert_eq(e.affixes, ["swift"], "swift affix")
	assert_float_eq(e.spawn_time, 210.0, 0.001, "spawns at 3:30")
