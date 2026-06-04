class_name EnemyKillData
extends RefCounted

## Value-only payload for CombatEvents.enemy_killed (ADR-0006 §Decision 4 / R-1).
## Carries NO Node reference — the enemy is freed end-of-frame after queue_free().

var source_element: String
var damage: float
var position: Vector2


func _init(elem: String, dmg: float, pos: Vector2) -> void:
	source_element = elem
	damage = dmg
	position = pos
