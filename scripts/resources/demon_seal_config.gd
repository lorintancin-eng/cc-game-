class_name DemonSealConfig
extends Resource

## Per-stage Demon Seal parameters (ADR-0004).
##
## Extracts the demon_seal_* @export block from stage_director.gd into a
## sub-resource so each StageConfig can tune (or omit) the seal. Field names +
## defaults mirror the current stage_director.gd values exactly, so Stage 1 is
## byte-identical when authored from these defaults.
##
## A null DemonSealConfig on a StageConfig means the stage has no Demon Seal.

## Elapsed-time (seconds) the seal spawns at (~2:00 in Stage 1).
@export var spawn_time: float = 120.0

## Min/max distance (px) from the player the seal spawns within.
@export var min_spawn_distance: float = 200.0
@export var max_spawn_distance: float = 280.0

## Seconds the player must remain in the seal to complete it.
@export var required_seconds: float = 8.0

## While sealing, the spawner's interval is multiplied by this (<1 = denser).
@export var pressure_interval_multiplier: float = 0.65

## While sealing, the spawner's max_enemies gains this bonus.
@export var pressure_max_enemy_bonus: int = 6

## Reward on completion: this many XP orbs, each worth reward_xp_value,
## scattered within reward_radius of the seal.
@export var reward_orb_count: int = 8
@export var reward_xp_value: float = 6.0
@export var reward_radius: float = 54.0
