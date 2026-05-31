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
	config.stage_duration = 180.0  # 3-minute stage (was 300); Judge at 3:00
	config.boss_scene = JUDGE_BOSS_SCENE
	# Art Bible §4.4: 幽都鬼市 = 黛黑 base shifted toward a warm ash-yellow (灰黄阴暖,
	# 阴界运作的市集). Subtle so 黛黑 stays dominant (§4.6 rule 2).
	config.ambient_tint = Color(0.30, 0.25, 0.16)
	config.ambient_tint_strength = 0.13

	# 3-minute compressed timeline: 4 waves (was 5), the last being the 怪浪 swarm.
	var waves: Array[WaveConfig] = []
	# Wave 0 (0:00) — Lantern Ghost (filler) + Resentful Infant (swarm)
	waves.append(_wave(0.0, 1.2, 22, [LANTERN_GHOST, RESENTFUL_INFANT], [3.5, 3.0]))
	# Wave 1 (0:40) — + Ghost Bailiff (fast hunter)
	waves.append(_wave(40.0, 1.0, 28,
		[LANTERN_GHOST, RESENTFUL_INFANT, GHOST_BAILIFF],
		[3.0, 2.8, 1.2]))
	# Wave 2 (1:20) — + Tomb Guardian (tank), building toward the swarm
	waves.append(_wave(80.0, 0.7, 40,
		[LANTERN_GHOST, RESENTFUL_INFANT, GHOST_BAILIFF, TOMB_GUARDIAN],
		[2.6, 2.6, 1.6, 0.5]))
	# Wave 3 — 怪浪 (2:00, the final minute before the Judge). The ghost-market tide:
	# enemies flood in from all sides at several times the prior density. Tuned a
	# touch denser than Stage 1 for the mid-game build (playtest-tunable; perf-watch).
	waves.append(_wave(120.0, 0.3, 84,
		[LANTERN_GHOST, RESENTFUL_INFANT, GHOST_BAILIFF, TOMB_GUARDIAN],
		[2.0, 2.2, 2.3, 1.2]))
	config.waves = waves

	# One scheduled elite (黑白无常, swift), rescaled to the 3-minute timeline.
	var elites: Array[EliteSpawnEvent] = []
	elites.append(_elite(100.0, IMPERMANENCE_ELITE, [ELITE_AFFIX_SWIFT], 420.0))
	config.elite_events = elites

	config.demon_seal_config = null
	# Trade stalls moved to the Ghost Market INTERLUDE between combat stages
	# (GhostMarketInterludeConfig). 幽都 is now a pure combat stage: 判官 boss +
	# the Ghost Market enemy roster.
	config.trade_stall_config = null
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
