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

## Total stage length (seconds). Boss spawns at this mark.
@export var stage_duration: float = 300.0

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
