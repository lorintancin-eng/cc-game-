class_name ThunderLawWeapon
extends WeaponBase

const DEFAULT_STRIKE_SCENE: PackedScene = preload("res://scenes/weapon/ThunderStrike.tscn")
const MIN_RADIUS: float = 1.0

@export var radius: float = 72.0
@export var target_count: int = 1
@export var strike_scene: PackedScene = DEFAULT_STRIKE_SCENE


func _process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if _cooldown_remaining > 0.0:
		return

	if _try_attack():
		_cooldown_remaining = _get_cooldown()


func _try_attack() -> bool:
	var targets := _find_nearest_targets()
	if targets.is_empty():
		return false

	var damaged_instance_ids: Dictionary = {}
	for target in targets:
		if not is_instance_valid(target):
			continue

		var strike_position := target.global_position
		_apply_radius_damage(strike_position, damaged_instance_ids)
		_spawn_strike(strike_position)

	return true


func _find_nearest_targets() -> Array[Node2D]:
	var attack_range_val := _get_attack_range()
	var max_distance_squared := attack_range_val * attack_range_val
	var max_targets := _get_target_count()
	var targets: Array[Node2D] = []
	var distances_squared: Array[float] = []

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		if not enemy.has_method("take_damage"):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node.is_queued_for_deletion():
			continue

		var distance_squared := global_position.distance_squared_to(enemy_node.global_position)
		if distance_squared > max_distance_squared:
			continue

		var insert_index := distances_squared.size()
		for index in range(distances_squared.size()):
			if distance_squared < distances_squared[index]:
				insert_index = index
				break

		targets.insert(insert_index, enemy_node)
		distances_squared.insert(insert_index, distance_squared)

		if targets.size() > max_targets:
			targets.pop_back()
			distances_squared.pop_back()

	return targets


func _apply_radius_damage(strike_position: Vector2, damaged_instance_ids: Dictionary) -> void:
	var strike_radius := _get_radius()
	var strike_radius_squared := strike_radius * strike_radius
	var strike_damage := _get_damage()

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		if not enemy.has_method("take_damage"):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node.is_queued_for_deletion():
			continue

		var instance_id := enemy_node.get_instance_id()
		if damaged_instance_ids.has(instance_id):
			continue
		if strike_position.distance_squared_to(enemy_node.global_position) > strike_radius_squared:
			continue

		damaged_instance_ids[instance_id] = true
		# Story 005: weapon-side 相克 matchup multiplier.
		var final_damage := strike_damage * ElementMatchup.modifier(element, WeaponBase.element_of(enemy_node))
		enemy_node.call("take_damage", final_damage)


func _spawn_strike(strike_position: Vector2) -> void:
	if strike_scene == null:
		push_warning("ThunderLawWeapon has no strike scene.")
		return

	var strike_instance := strike_scene.instantiate()
	if not strike_instance is Node2D:
		push_error("ThunderLawWeapon strike_scene must instantiate a Node2D.")
		strike_instance.queue_free()
		return

	var strike := strike_instance as Node2D
	_get_strike_parent().add_child(strike)
	strike.global_position = strike_position

	if strike.has_method("configure"):
		strike.call("configure", _get_radius())


func _get_radius() -> float:
	return maxf(radius, MIN_RADIUS)


func _get_target_count() -> int:
	return maxi(target_count, 1)


func _get_strike_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene

	var parent := get_parent()
	if parent != null and parent.get_parent() != null:
		return parent.get_parent()

	return self
