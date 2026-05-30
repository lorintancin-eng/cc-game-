## Golden test for StageConfig.get_active_wave (ADR-0004 step 3 foundation).
##
## The data-driven wave selector MUST reproduce the old hardcoded
## StageDirector._get_wave_config_index() step function byte-identically for
## Stage 1, or the playtested 5-minute pacing drifts. This test pins the Stage-1
## wave outputs (spawn_interval / max_enemies / weights) at every boundary time
## to the exact constants currently hardcoded in stage_director.gd:
##
##   wave | start_time | interval | max | weights
##   -----+------------+----------+-----+-----------------------------
##    0   |   0.0      |  1.35    | 18  | [4.0, 3.0]
##    1   |  60.0      |  1.08    | 24  | [3.6, 3.0, 0.8, 0.6]
##    2   | 120.0      |  0.90    | 32  | [2.8, 2.8, 1.2, 1.0, 0.35]
##    3   | 180.0      |  0.72    | 42  | [2.5, 2.4, 1.8, 1.4, 0.7]
##    4   | 270.0      |  0.55    | 56  | [2.0, 2.0, 2.3, 1.9, 1.0]
##
## (archetype_pool is intentionally left empty here — the typed Array[EnemyArchetype]
## wiring is validated when the spawner integration lands; this test covers the
## selection logic + the scalar/weight values, which are the pacing-critical bits.)
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/system -gexit

extends "res://tests/helpers/test_base.gd"

const StageConfigScript = preload("res://scripts/resources/stage_config.gd")
const WaveConfigScript = preload("res://scripts/resources/wave_config.gd")


# weights is passed untyped; Array.assign() coerces it into the typed
# Array[float] field robustly (avoids untyped-literal → typed-array assignment
# friction in GDScript 4).
func _make_wave(start: float, interval: float, max_e: int, weights: Array) -> WaveConfig:
	var w: WaveConfig = WaveConfigScript.new()
	w.start_time = start
	w.spawn_interval = interval
	w.max_enemies = max_e
	w.archetype_weights.assign(weights)
	return w


# The canonical Stage-1 wave set, mirroring stage_director.gd exactly.
func _build_stage_1() -> StageConfig:
	var config: StageConfig = StageConfigScript.new()
	var waves: Array[WaveConfig] = []
	waves.append(_make_wave(0.0, 1.35, 18, [4.0, 3.0]))
	waves.append(_make_wave(60.0, 1.08, 24, [3.6, 3.0, 0.8, 0.6]))
	waves.append(_make_wave(120.0, 0.90, 32, [2.8, 2.8, 1.2, 1.0, 0.35]))
	waves.append(_make_wave(180.0, 0.72, 42, [2.5, 2.4, 1.8, 1.4, 0.7]))
	waves.append(_make_wave(270.0, 0.55, 56, [2.0, 2.0, 2.3, 1.9, 1.0]))
	config.waves = waves
	return config


# ─── boundary-time selection: interval + max match the old step function ──

func test_stage_config_wave_selection_at_boundary_times() -> void:
	var config := _build_stage_1()
	# (elapsed_time, expected_interval, expected_max) — boundaries mirror the
	# old _get_wave_config_index thresholds (>= 60/120/180/270).
	var cases := [
		[0.0, 1.35, 18], [59.999, 1.35, 18],
		[60.0, 1.08, 24], [119.999, 1.08, 24],
		[120.0, 0.90, 32], [179.999, 0.90, 32],
		[180.0, 0.72, 42], [269.999, 0.72, 42],
		[270.0, 0.55, 56], [300.0, 0.55, 56],
	]
	for case in cases:
		var t: float = case[0]
		var wave := config.get_active_wave(t)
		assert_not_null(wave, "a wave must be active at t=%s" % t)
		assert_float_eq(wave.spawn_interval, case[1], 0.0001, "interval at t=%s" % t)
		assert_eq(wave.max_enemies, int(case[2]), "max_enemies at t=%s" % t)


# ─── weights match per tier ───────────────────────────────────────────────

func test_stage_config_wave_selection_weights_match() -> void:
	var config := _build_stage_1()
	assert_eq(config.get_active_wave(0.0).archetype_weights, [4.0, 3.0], "wave 0 weights")
	assert_eq(config.get_active_wave(60.0).archetype_weights, [3.6, 3.0, 0.8, 0.6], "wave 1 weights")
	assert_eq(config.get_active_wave(120.0).archetype_weights, [2.8, 2.8, 1.2, 1.0, 0.35], "wave 2 weights")
	assert_eq(config.get_active_wave(180.0).archetype_weights, [2.5, 2.4, 1.8, 1.4, 0.7], "wave 3 weights")
	assert_eq(config.get_active_wave(270.0).archetype_weights, [2.0, 2.0, 2.3, 1.9, 1.0], "wave 4 weights")


# ─── degenerate / robustness ──────────────────────────────────────────────

func test_stage_config_empty_waves_returns_null() -> void:
	var config: StageConfig = StageConfigScript.new()
	assert_null(config.get_active_wave(100.0), "no waves → null")


func test_stage_config_time_before_first_wave_returns_null() -> void:
	# Stage 1's first wave starts at 0.0; a negative time has no active wave.
	var config := _build_stage_1()
	assert_null(config.get_active_wave(-1.0), "time before the earliest start_time → null")


func test_stage_config_selection_robust_to_unsorted_waves() -> void:
	# The scan must pick the greatest qualifying start_time regardless of order.
	var config: StageConfig = StageConfigScript.new()
	var waves: Array[WaveConfig] = []
	waves.append(_make_wave(270.0, 0.55, 56, [2.0]))
	waves.append(_make_wave(0.0, 1.35, 18, [4.0, 3.0]))
	waves.append(_make_wave(120.0, 0.90, 32, [2.8]))
	config.waves = waves
	# At t=150, the greatest start_time <= 150 is 120 → interval 0.90.
	assert_float_eq(config.get_active_wave(150.0).spawn_interval, 0.90, 0.0001,
		"unsorted: picks the latest qualifying wave (start 120 at t=150)")
	# At t=300, the greatest is 270 → interval 0.55.
	assert_float_eq(config.get_active_wave(300.0).spawn_interval, 0.55, 0.0001,
		"unsorted: picks start 270 at t=300")
