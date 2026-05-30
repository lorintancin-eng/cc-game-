class_name StageTwoConfig
extends RefCounted

## Canonical Stage 2 (幽都鬼市 / Netherworld Ghost Market) configuration —
## ADR-0004 data-driven stage, mirroring StageOneConfig's code-builder pattern.
##
## Assembles the Stage-2 content: the 5 Ghost Market enemy archetypes (Step 6a),
## the Ghost Market Judge boss (Step 6b), and the Ghost Market Trade config
## (ghost-market-trade.md revision-1). Stage 2 has NO Demon Seal (demon_seal_config
## null) — its risk/reward beat is the trade stalls instead.
##
## TUNING: the wave intensity is tuned a bit harder than Stage 1 because Stage 2
## is reached SEQUENTIALLY (the player arrives mid-game, ~L8-12, multi-weapon,
## ~120-160 HP). All values are playtest-tunable starting points.
##
## Code builder (not a .tres) so CI can compile + unit-test it headlessly; the
## .tres serialization is an editor follow-up. A RunDirector (Step 4-5) will
## assign this to the StageDirector when advancing from Stage 1.

const LANTERN_GHOST := preload("res://resources/enemies/lantern_ghost.tres")
const RESENTFUL_INFANT := preload("res://resources/enemies/resentful_infant.tres")
const GHOST_BAILIFF := preload("res://resources/enemies/ghost_bailiff.tres")
const TOMB_GUARDIAN := preload("res://resources/enemies/tomb_guardian.tres")
const IMPERMANENCE_ELITE := preload("res://resources/enemies/impermanence_elite.tres")
const JUDGE_BOSS_SCENE := preload("res://scenes/enemy/GhostMarketJudge.tscn")

const ELITE_AFFIX_SWIFT := "swift"


## Builds the Stage 2 StageConfig.
static func build() -> StageConfig:
	var config := StageConfig.new()
	config.stage_id = &"stage_2"
	config.display_name = "幽都鬼市"
	config.stage_duration = 300.0
	config.boss_scene = JUDGE_BOSS_SCENE

	var waves: Array[WaveConfig] = []
	# Wave 0 (0:00) — Lantern Ghost (filler) + Resentful Infant (swarm)
	waves.append(_wave(0.0, 1.2, 22, [LANTERN_GHOST, RESENTFUL_INFANT], [3.5, 3.0]))
	# Wave 1 (1:00) — + Ghost Bailiff (fast hunter)
	waves.append(_wave(60.0, 1.0, 28,
		[LANTERN_GHOST, RESENTFUL_INFANT, GHOST_BAILIFF],
		[3.0, 2.8, 1.2]))
	# Wave 2 (2:00) — + Tomb Guardian (tank)
	waves.append(_wave(120.0, 0.85, 36,
		[LANTERN_GHOST, RESENTFUL_INFANT, GHOST_BAILIFF, TOMB_GUARDIAN],
		[2.6, 2.6, 1.6, 0.5]))
	# Wave 3 (3:00) — same pool, heavier weights
	waves.append(_wave(180.0, 0.7, 46,
		[LANTERN_GHOST, RESENTFUL_INFANT, GHOST_BAILIFF, TOMB_GUARDIAN],
		[2.3, 2.4, 2.0, 0.9]))
	# Wave 4 (4:30) — boss-warning density
	waves.append(_wave(270.0, 0.55, 58,
		[LANTERN_GHOST, RESENTFUL_INFANT, GHOST_BAILIFF, TOMB_GUARDIAN],
		[2.0, 2.2, 2.3, 1.2]))
	config.waves = waves

	# One scheduled elite (黑白无常, swift). The trade stalls' demon-tide provides
	# additional elite pressure, so Stage 2 schedules fewer than Stage 1's two.
	var elites: Array[EliteSpawnEvent] = []
	elites.append(_elite(210.0, IMPERMANENCE_ELITE, [ELITE_AFFIX_SWIFT], 420.0))
	config.elite_events = elites

	# Stage 2 has NO Demon Seal — the trade stalls are its risk/reward system.
	config.demon_seal_config = null
	config.trade_stall_config = _trade_stalls()
	return config


static func _wave(start: float, interval: float, max_e: int, pool: Array, weights: Array) -> WaveConfig:
	var w := WaveConfig.new()
	w.start_time = start
	w.spawn_interval = interval
	w.max_enemies = max_e
	w.archetype_pool.assign(pool)
	w.archetype_weights.assign(weights)
	return w


static func _elite(spawn_time: float, archetype: EnemyArchetype, affixes: Array, distance: float) -> EliteSpawnEvent:
	var e := EliteSpawnEvent.new()
	e.spawn_time = spawn_time
	e.archetype = archetype
	e.affixes.assign(affixes)
	e.spawn_distance = distance
	return e


static func _trade_stalls() -> TradeStallConfig:
	# Values per ghost-market-trade.md revision-1 (Tuning Knobs + Formula 4).
	var t := TradeStallConfig.new()
	t.stall_count_per_run = 4
	t.stall_spawn_times = [90.0, 150.0, 210.0, 255.0]
	t.stall_linger_seconds = 25.0
	t.demon_tide_base_count = 5
	t.demon_tide_interval_mult = 0.75
	t.demon_tide_window_seconds = 12.0
	# Elite added to the tide by cumulative trade count (0/0/1/1 per Formula 4 r1).
	t.demon_tide_elite_counts = [0, 0, 1, 1]
	t.demon_tide_elite_archetype = IMPERMANENCE_ELITE
	return t
