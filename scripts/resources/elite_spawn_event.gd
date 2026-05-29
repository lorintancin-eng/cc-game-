class_name EliteSpawnEvent
extends Resource

## A scheduled elite spawn within a stage (ADR-0004).
##
## A StageConfig holds an Array[EliteSpawnEvent]. The Stage Director fires each
## once when elapsed_time crosses its spawn_time, calling
## EnemySpawner.spawn_elite_at(archetype, position, affixes). Replaces the two
## hardcoded _spawn_first_elite / _spawn_second_elite calls.

## Absolute elapsed-time (seconds) at which this elite spawns (fires once).
@export var spawn_time: float = 180.0

## The elite archetype to spawn (is_elite=true archetype, e.g. Shanxiao / 黑白无常).
@export var archetype: EnemyArchetype

## Affix names applied at spawn (e.g. ["iron_bones"], ["swift"]).
@export var affixes: Array[String] = []

## Distance (px) from the player to spawn the elite.
@export var spawn_distance: float = 420.0
