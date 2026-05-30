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
## INCREMENT 1 (this step): config PROVIDER only — get_current_stage_config()
## returns Stage 1 at index 0, so the live game is byte-identical to today. The
## advance() bookkeeping + signals are built and unit-tested now, but nothing in
## the live scene calls advance() yet. The actual Stage 1→2 transition (reset the
## StageDirector + EnemySpawner, heal the player, suppress the victory screen) is
## the next, playtest-gated increment.

## Emitted when the run moves to the next stage. Payload: the new 0-based index
## and the StageConfig to load.
signal stage_advanced(stage_index: int, stage_config: StageConfig)

## Emitted when advance_to_next_stage() is called on the final stage — the whole
## run is won. The live wiring will show the run-victory screen on this.
signal run_completed()

var _stage_index: int = 0
var _stage_configs: Array[StageConfig] = []


func _ready() -> void:
	_ensure_sequence()


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


# ─── private ─────────────────────────────────────────────────────────────

## Lazily builds the canonical 2-stage sequence the first time it's needed, so
## the director works whether or not _ready() has run (e.g. headless tests).
func _ensure_sequence() -> void:
	if not _stage_configs.is_empty():
		return
	_stage_configs = [StageOneConfig.build(), StageTwoConfig.build()]
