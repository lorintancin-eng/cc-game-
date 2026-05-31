class_name StageOneConfig
extends RefCounted

## Canonical Stage 1 (荒山古道) configuration, extracted VERBATIM from the
## hardcoded values in stage_director.gd (pre-ADR-0004). This single builder is
## the data-driven source of truth for Stage 1 — replacing the five scattered
## _get_wave_*() functions + the WAVE_*_START_TIME constants.
##
## It is the golden reference for the migration: the golden test asserts this
## config reproduces the old hardcoded outputs exactly. Later it can be serialized
## to `resources/stages/stage_1.tres` (in the Godot editor) and assigned to the
## StageDirector; until then the director can call StageOneConfig.build() as its
## default config.
##
## NOTE: this is intentionally a code builder, not a `.tres`, so it can be unit
## tested headlessly (CI compiles + runs it). The `.tres` serialization is an
## editor-side follow-up that does not block the director migration.

const PAPER_DOLL := preload("res://resources/enemies/paper_doll.tres")
const WANDERING_SOUL := preload("res://resources/enemies/wandering_soul.tres")
const FOX_SPIRIT := preload("res://resources/enemies/fox_spirit.tres")
const GHOST_FLAME := preload("res://resources/enemies/ghost_flame.tres")
const STONE_GOLEM := preload("res://resources/enemies/stone_golem.tres")
const SHANXIAO_ELITE := preload("res://resources/enemies/shanxiao_elite.tres")
const FAMINE_BOSS_SCENE := preload("res://scenes/enemy/FamineBeastBoss.tscn")

const ELITE_AFFIX_IRON_BONES := "iron_bones"
const ELITE_AFFIX_SWIFT := "swift"


## Builds the Stage 1 StageConfig with values identical to the current
## stage_director.gd hardcoding.
static func build() -> StageConfig:
	var config := StageConfig.new()
	config.stage_id = &"stage_1"
	config.display_name = "荒山古道"
	config.stage_duration = 180.0  # 3-minute stage (was 300); boss at 3:00
	config.boss_scene = FAMINE_BOSS_SCENE
	# Art Bible §4.4: 荒山 = 黛黑 base shifted toward a cool blue-grey (蓝灰冷偏,
	# "子夜过后、月光稀薄"). Subtle so 黛黑 stays dominant (§4.6 rule 2).
	config.ambient_tint = Color(0.16, 0.19, 0.28)
	config.ambient_tint_strength = 0.14

	# 3-minute compressed timeline: 4 waves (was 5), the last being the 怪浪 swarm.
	var waves: Array[WaveConfig] = []
	# Wave 0 (0:00) — Paper Doll + Wandering Soul
	waves.append(_wave(0.0, 1.35, 18, [PAPER_DOLL, WANDERING_SOUL], [4.0, 3.0]))
	# Wave 1 (0:40) — + Fox Spirit + Ghost Flame
	waves.append(_wave(40.0, 1.0, 26,
		[PAPER_DOLL, WANDERING_SOUL, FOX_SPIRIT, GHOST_FLAME],
		[3.6, 3.0, 0.8, 0.6]))
	# Wave 2 (1:20) — + Stone Golem, building toward the swarm
	waves.append(_wave(80.0, 0.7, 40,
		[PAPER_DOLL, WANDERING_SOUL, FOX_SPIRIT, GHOST_FLAME, STONE_GOLEM],
		[2.8, 2.8, 1.2, 1.0, 0.35]))
	# Wave 3 — 怪浪 (2:00, the final minute before the boss). The monster tide:
	# enemies pour in from all sides at several times the prior density. max_enemies
	# + spawn_interval are the intensity knobs (playtest-tunable; watch perf above
	# ~90 on-screen).
	waves.append(_wave(120.0, 0.3, 80,
		[PAPER_DOLL, WANDERING_SOUL, FOX_SPIRIT, GHOST_FLAME, STONE_GOLEM],
		[2.0, 2.0, 2.3, 1.9, 1.0]))
	config.waves = waves

	# Elites rescaled to the 3-minute timeline (was 3:00 / 4:00).
	var elites: Array[EliteSpawnEvent] = []
	elites.append(_elite(95.0, SHANXIAO_ELITE, [ELITE_AFFIX_IRON_BONES], 420.0))
	elites.append(_elite(140.0, SHANXIAO_ELITE, [ELITE_AFFIX_SWIFT], 420.0))
	config.elite_events = elites

	config.demon_seal_config = _demon_seal()

	# Stage 1 has no Ghost Market trade stalls.
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


static func _demon_seal() -> DemonSealConfig:
	var d := DemonSealConfig.new()
	d.spawn_time = 60.0  # rescaled to the 3-minute timeline (was 120)
	d.min_spawn_distance = 200.0
	d.max_spawn_distance = 280.0
	d.required_seconds = 8.0
	d.pressure_interval_multiplier = 0.65
	d.pressure_max_enemy_bonus = 6
	d.reward_orb_count = 8
	d.reward_xp_value = 6.0
	d.reward_radius = 54.0
	return d
