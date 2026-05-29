class_name WaveConfig
extends Resource

## One band of a stage's spawn timeline (ADR-0004).
##
## A StageConfig holds an Array[WaveConfig] sorted by start_time. The Stage
## Director selects the active band by scanning for the latest WaveConfig whose
## start_time has elapsed, then feeds its values to EnemySpawner.apply_wave_config.
## Replaces the hardcoded _get_wave_* step functions in stage_director.gd.

## Absolute elapsed-time (seconds) at which this wave band becomes active.
## The active band is the one with the greatest start_time <= elapsed_time.
@export var start_time: float = 0.0

## Seconds between spawns while this band is active (lower = denser).
@export var spawn_interval: float = 1.35

## Maximum concurrent enemies the spawner allows during this band.
@export var max_enemies: int = 18

## Weighted archetype pool the spawner draws from during this band.
## Parallel array with archetype_weights (index-matched).
@export var archetype_pool: Array[EnemyArchetype] = []

## Spawn weights, index-matched to archetype_pool. Higher = more frequent.
@export var archetype_weights: Array[float] = []
