class_name RunDirector
extends Node

## Owns the multi-stage run lifecycle (ADR-0004): the ordered stage sequence
## (Stage 1 荒山古道 → Stage 2 幽都鬼市) and which stage is active. Progression is
## SEQUENTIAL — the player carries their build / level / HP from stage to stage
## (one life to the bottom). StageDirector pulls its StageConfig from here.
##
## A scene node injected via @export (NOT an autoload singleton — per the project's
## no-gameplay-singletons rule). Lives in Main.tscn above the single-stage systems.
##
## Flow: StageDirector provides the active config from here (get_current_stage_config).
## When a stage boss dies AND a next stage exists, StageDirector emits
## stage_advance_requested → _on_stage_advance_requested advances the sequence,
## resets the StageDirector onto the new stage (clears enemies, restarts wave 0),
## and heals the carried-over player. The victory screen only fires on the final
## stage's stage_cleared.

## Emitted when the run moves to the next stage. Payload: the new 0-based index
## and the StageConfig to load.
signal stage_advanced(stage_index: int, stage_config: StageConfig)

## Emitted when advance_to_next_stage() is called on the final stage — the whole
## run is won. The live wiring will show the run-victory screen on this.
signal run_completed()

## ADR-0004: the StageDirector this RunDirector drives (wired in Main.tscn). When
## a stage boss dies with a next stage available, StageDirector emits
## stage_advance_requested → this director advances, resets the StageDirector for
## the new stage, and heals the player.
@export var stage_director: StageDirector

## Fraction of max_hp restored to the player on clearing a stage — the carry-over
## reward for sequential (one-life) progression.
const STAGE_CLEAR_HEAL_FRACTION: float = 0.4

var _stage_index: int = 0
var _stage_configs: Array[StageConfig] = []


func _ready() -> void:
	_ensure_sequence()
	if stage_director != null and not stage_director.stage_advance_requested.is_connected(_on_stage_advance_requested):
		stage_director.stage_advance_requested.connect(_on_stage_advance_requested)


## Replaces the default sequence — primarily for tests / future custom run modes.
## Resets the active stage to the first.
func set_stage_sequence(configs: Array[StageConfig]) -> void:
	_stage_configs = configs.duplicate()
	_stage_index = 0


func get_current_stage_config() -> StageConfig:
	_ensure_sequence()
	if _stage_configs.is_empty():
		return null
	return _stage_configs[clampi(_stage_index, 0, _stage_configs.size() - 1)]


func get_stage_index() -> int:
	return _stage_index


func stage_count() -> int:
	_ensure_sequence()
	return _stage_configs.size()


func has_next_stage() -> bool:
	_ensure_sequence()
	return _stage_index < _stage_configs.size() - 1


## Advances to the next stage and returns its config. On the final stage this
## advances nothing, emits run_completed, and returns null.
func advance_to_next_stage() -> StageConfig:
	_ensure_sequence()
	if not has_next_stage():
		run_completed.emit()
		return null
	_stage_index += 1
	var config := get_current_stage_config()
	stage_advanced.emit(_stage_index, config)
	return config


# ─── transition orchestration (driven by StageDirector.stage_advance_requested) ─

## The stage boss died and a next stage exists: advance the sequence, reset the
## StageDirector onto the new stage, and heal the carried-over player. Seamless —
## no pause, no victory screen (those are only for the final/standalone stage's
## stage_cleared).
func _on_stage_advance_requested() -> void:
	var next_config := advance_to_next_stage()
	if next_config == null:
		return  # defensive — StageDirector only emits this when has_next_stage()
	if stage_director != null:
		stage_director.reset_for_stage(next_config)
	_heal_player()


## Heals the player by STAGE_CLEAR_HEAL_FRACTION of max_hp. The player is found via
## the "player" group (it is spawned dynamically by CharacterSelectPanel, so the
## RunDirector cannot hold a static reference).
func _heal_player() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		player.heal(player.max_hp * STAGE_CLEAR_HEAL_FRACTION)


# ─── private ─────────────────────────────────────────────────────────────

## Lazily builds the canonical 2-stage sequence the first time it's needed, so
## the director works whether or not _ready() has run (e.g. headless tests).
func _ensure_sequence() -> void:
	if not _stage_configs.is_empty():
		return
	_stage_configs = [StageOneConfig.build(), StageTwoConfig.build()]
