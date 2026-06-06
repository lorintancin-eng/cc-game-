class_name ExplosiveTalismanProjectile
extends Area2D

const DEFAULT_IMPACT_SCENE: PackedScene = preload("res://scenes/weapon/ExplosiveImpact.tscn")
const MIN_DIRECTION_LENGTH: float = 0.001
const MIN_LIFETIME: float = 0.05
const MIN_EXPLOSION_RADIUS: float = 1.0

@export var impact_scene: PackedScene = DEFAULT_IMPACT_SCENE

var damage: float = 0.0
var speed: float = 0.0
var lifetime: float = 0.0
var explosion_radius: float = 58.0
var explosion_damage: float = 14.0

## Five Phases element of the firing weapon (Story 005). Set by the weapon on spawn.
var element: String = "neutral"
## Owning player's ComboManager (Stories 008/009). Set by the weapon on spawn so the
## direct hit + each blast target apply 矿脉精粹 crit + 寒露凝锋 frost.
var combo_manager: ComboManager

var _direction: Vector2 = Vector2.RIGHT
var _elapsed_time: float = 0.0
var _has_exploded: bool = false
var _is_launched: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _is_launched:
		return

	global_position += _direction * speed * delta
	_elapsed_time += delta

	if _elapsed_time >= lifetime:
		_explode(global_position, null)


func launch(
	new_direction: Vector2,
	new_damage: float,
	new_speed: float,
	new_lifetime: float,
	new_explosion_radius: float,
	new_explosion_damage: float
) -> void:
	if new_direction.length_squared() <= MIN_DIRECTION_LENGTH * MIN_DIRECTION_LENGTH:
		_direction = Vector2.RIGHT
	else:
		_direction = new_direction.normalized()

	damage = maxf(new_damage, 0.0)
	speed = maxf(new_speed, 0.0)
	lifetime = maxf(new_lifetime, MIN_LIFETIME)
	explosion_radius = maxf(new_explosion_radius, MIN_EXPLOSION_RADIUS)
	explosion_damage = maxf(new_explosion_damage, 0.0)
	_elapsed_time = 0.0
	_has_exploded = false
	_is_launched = true
	rotation = _direction.angle()
	set_physics_process(true)


func _on_body_entered(body: Node2D) -> void:
	if _has_exploded:
		return
	if not body.is_in_group("enemies"):
		return
	if not body.has_method("take_damage"):
		return

	_explode(global_position, body)


func _explode(epicenter: Vector2, direct_body: Node2D) -> void:
	if _has_exploded:
		return

	_has_exploded = true
	_is_launched = false
	set_physics_process(false)

	if is_instance_valid(direct_body) and direct_body.has_method("take_damage"):
		# Story 005: weapon-side 相克 matchup on the direct impact.
		var direct_final := damage * ElementMatchup.modifier(element, WeaponBase.element_of(direct_body))
		direct_final = WeaponBase.apply_combo_effects(combo_manager, direct_body, direct_final)
		direct_body.call("take_damage", direct_final)

	var explosion_radius_squared := explosion_radius * explosion_radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		if not enemy.has_method("take_damage"):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node.is_queued_for_deletion():
			continue
		if epicenter.distance_squared_to(enemy_node.global_position) > explosion_radius_squared:
			continue

		# Story 005: weapon-side 相克 matchup on each enemy caught in the blast.
		var blast_final := explosion_damage * ElementMatchup.modifier(element, WeaponBase.element_of(enemy_node))
		blast_final = WeaponBase.apply_combo_effects(combo_manager, enemy_node, blast_final)
		enemy_node.call("take_damage", blast_final)

	_spawn_impact(epicenter)
	queue_free()


func _spawn_impact(epicenter: Vector2) -> void:
	if impact_scene == null:
		return

	var impact_instance := impact_scene.instantiate()
	if not impact_instance is Node2D:
		impact_instance.queue_free()
		return

	var impact := impact_instance as Node2D
	_get_effect_parent().add_child(impact)
	impact.global_position = epicenter
	if impact.has_method("configure"):
		impact.call("configure", explosion_radius)


func _get_effect_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene

	var parent := get_parent()
	if parent != null:
		return parent

	return self
