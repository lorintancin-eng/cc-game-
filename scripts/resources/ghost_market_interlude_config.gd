class_name GhostMarketInterludeConfig
extends RefCounted

## A calm Ghost Market TRADE INTERLUDE (幽都鬼市) between combat stages — NOT a
## combat stage. No boss, no Demon Seal, no passive wave spawning (the StageDirector
## disables it for interludes). It spawns trade stalls; trading still angers the
## market (the demon tide spawns 鬼市 enemies into the room — the cost). The single
## wave exists only to give the tide a pool. Auto-advances to the next combat stage
## at stage_duration.

const LANTERN_GHOST := preload("res://resources/enemies/lantern_ghost.tres")
const RESENTFUL_INFANT := preload("res://resources/enemies/resentful_infant.tres")
const GHOST_BAILIFF := preload("res://resources/enemies/ghost_bailiff.tres")
const TOMB_GUARDIAN := preload("res://resources/enemies/tomb_guardian.tres")
const IMPERMANENCE_ELITE := preload("res://resources/enemies/impermanence_elite.tres")


static func build() -> StageConfig:
	var config := StageConfig.new()
	config.stage_id = &"interlude"
	config.display_name = "幽都鬼市 · 交易"
	config.is_interlude = true
	config.stage_duration = 25.0  # interlude length (auto-advance)
	config.boss_scene = null
	config.demon_seal_config = null

	# A single wave that ONLY supplies the demon-tide pool (passive spawning is
	# disabled for interludes, so nothing spawns until a trade tide fires).
	var waves: Array[WaveConfig] = []
	var w := WaveConfig.new()
	w.start_time = 0.0
	w.spawn_interval = 1.0
	w.max_enemies = 12
	w.archetype_pool.assign([LANTERN_GHOST, RESENTFUL_INFANT, GHOST_BAILIFF, TOMB_GUARDIAN])
	w.archetype_weights.assign([2.6, 2.6, 1.6, 0.8])
	waves.append(w)
	config.waves = waves

	config.trade_stall_config = _stalls()
	return config


static func _stalls() -> TradeStallConfig:
	# 3 stalls spawned EARLY (reachable in the calm room), long linger.
	var t := TradeStallConfig.new()
	t.stall_count_per_run = 3
	t.stall_spawn_times = [2.0, 6.0, 10.0]
	t.stall_linger_seconds = 20.0
	t.demon_tide_base_count = 5
	t.demon_tide_interval_mult = 0.75
	t.demon_tide_window_seconds = 12.0
	t.demon_tide_elite_counts = [0, 0, 1, 1]
	t.demon_tide_elite_archetype = IMPERMANENCE_ELITE
	return t
