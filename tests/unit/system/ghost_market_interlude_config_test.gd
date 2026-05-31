## Validates GhostMarketInterludeConfig.build() — the calm trade interlude between
## combat stages (is_interlude, stalls, no boss/seal, a tide pool, short duration).
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/system -gexit

extends "res://tests/helpers/test_base.gd"


func test_interlude_is_marked_interlude() -> void:
	var c := GhostMarketInterludeConfig.build()
	assert_true(c.is_interlude, "is_interlude flag set")
	assert_eq(c.stage_id, &"interlude", "interlude id")


func test_interlude_has_no_boss_or_seal() -> void:
	var c := GhostMarketInterludeConfig.build()
	assert_null(c.boss_scene, "no boss in a trade interlude")
	assert_null(c.demon_seal_config, "no demon seal")


func test_interlude_has_trade_stalls() -> void:
	var c := GhostMarketInterludeConfig.build()
	assert_not_null(c.trade_stall_config, "the interlude HAS the trade stalls")
	assert_eq(c.trade_stall_config.stall_count_per_run, 3, "3 stalls")
	assert_true(c.trade_stall_config.stall_spawn_times[0] <= 5.0,
		"first stall spawns early so it's reachable in the calm room")


func test_interlude_has_a_tide_pool_wave() -> void:
	# A single wave supplies the demon-tide pool (Ghost Market enemies); passive
	# spawning is disabled by the StageDirector for interludes.
	var c := GhostMarketInterludeConfig.build()
	assert_eq(c.waves.size(), 1, "one pool wave")
	assert_false(c.waves[0].archetype_pool.is_empty(), "pool carries the 鬼市 enemies")


func test_interlude_has_no_time_pressure() -> void:
	# No time limit — the player leaves via the LeavePortal whenever ready; the
	# duration is just a soft-lock failsafe, and the stalls linger the whole time.
	var c := GhostMarketInterludeConfig.build()
	assert_true(c.stage_duration >= 120.0, "no hard time limit (large failsafe duration)")
	assert_true(c.trade_stall_config.stall_linger_seconds >= 120.0, "stalls stay (no rush)")
