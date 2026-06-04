## CombatEvents — stateless combat event bus (autoload).
## Pure signal relay — NO gameplay logic, NO state.
## Accessed globally via the autoload name "CombatEvents" (project.godot).
## Enemies emit enemy_killed before queue_free(); consumers (ComboManager 燎原) connect ONCE.
## NOTE: No class_name declared — Godot 4.6 forbids class_name that matches an autoload name.
extends Node

signal enemy_killed(kill_data: EnemyKillData)
