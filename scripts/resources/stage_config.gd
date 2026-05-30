class_name StageConfig
extends Resource

## Full data description of one stage (ADR-0004).
##
## The Stage Director becomes a generic engine that reads a StageConfig instead
## of hardcoding the timeline. Each stage is a standalone `.tres`
## (resources/stages/stage_1.tres, stage_2.tres, ...). The RunDirector holds an
## Array[StageConfig] and sequences them.
##
## Authoring Stage 1 from these fields with the existing values produces a
## byte-identical Stage 1 (verified by the golden test in the migration plan).

## Stable id for save/telemetry/HUD ("stage_1", "stage_2", ...).
@export var stage_id: StringName = &"stage_1"

## HUD/banner display name (e.g. "荒山古道", "幽都鬼市").
@export var display_name: String = "荒山"

## Ghost Market TRADE INTERLUDE (not a combat stage): no boss, no passive wave
## spawning (waves may carry a pool for trade tides at max_enemies 0). Spawns the
## trade stalls + auto-advances to the next combat stage at stage_duration. The
## StageDirector treats stage_duration as the interlude length, not a boss timer.
@export var is_interlude: bool = false

## Total stage length (seconds). Boss spawns at this mark.
@export var stage_duration: float = 300.0

## Endless-escalation knob (ADR-0004). Scales each wave's enemy COUNT up and its
## spawn INTERVAL down (more enemies, faster) without re-authoring waves — so the
## RunDirector can loop the two designed stages at rising difficulty. 1.0 = the
## authored values (Stage 1/2); the remix stages use >1.0.
@export var difficulty_multiplier: float = 1.0

## Spawn timeline, authored as standalone WaveConfig `.tres` sorted by start_time.
@export var waves: Array[WaveConfig] = []

## Scheduled elite spawns (fired once each when elapsed_time crosses spawn_time).
@export var elite_events: Array[EliteSpawnEvent] = []

## The boss scene spawned at stage_duration. Swappable per stage
## (FamineBeastBoss for Stage 1, GhostMarketJudge for Stage 2).
@export var boss_scene: PackedScene

@export_group("Boss Fallback")
## Used ONLY when the boss scene has no archetype (dead-code parity with the
## current stage_director.gd export block — boss .tscn always has an archetype).
@export var boss_warning_lead_time: float = 30.0
@export var boss_spawn_distance: float = 420.0
@export var boss_move_speed: float = 70.0
@export var boss_max_hp: float = 260.0
@export var boss_damage: float = 16.0
@export var boss_scale: float = 1.8
@export var boss_phase_spawn_interval: float = 2.5
@export var boss_phase_max_enemies: int = 8

@export_group("Demon Seal")
## Per-stage Demon Seal params. null ⇒ this stage has no Demon Seal.
@export var demon_seal_config: DemonSealConfig

@export_group("Stage 2+ (Ghost Market)")
## Per-stage Ghost Market Trade config. null ⇒ this stage has no trade stalls
## (Stage 1 leaves this null).
@export var trade_stall_config: TradeStallConfig = null


## Returns the active WaveConfig for [param elapsed_time] — the wave with the
## greatest start_time that does not exceed elapsed_time. Returns null if waves
## is empty or every start_time is still in the future.
##
## This is the data-driven replacement for the old
## StageDirector._get_wave_config_index() step function (ADR-0004): instead of
## hardcoded WAVE_*_START_TIME constants + a match, the director scans this
## stage's wave list. The scan is robust to unsorted waves (picks the greatest
## qualifying start_time), so authoring order does not matter.
func get_active_wave(elapsed_time: float) -> WaveConfig:
	var active: WaveConfig = null
	for wave in waves:
		if wave == null:
			continue
		if elapsed_time >= wave.start_time:
			if active == null or wave.start_time > active.start_time:
				active = wave
	return active
