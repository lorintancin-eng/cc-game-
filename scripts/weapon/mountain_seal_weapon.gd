class_name MountainSealWeapon
extends WeaponBase

const DEFAULT_IMPACT_SCENE: PackedScene = preload("res://scenes/weapon/MountainSealImpact.tscn")
const MIN_RADIUS: float = 1.0

@export var radius: float = 118.0
@export var impact_scene: PackedScene = DEFAULT_IMPACT_SCENE


func _process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if _cooldown_remaining > 0.0:
		return

	if _try_attack():
		_cooldown_remaining = _get_cooldown()


func _try_attack() -> bool:
	var target := _find_nearest_enemy()
	if target == null:
		return false

	var impact_position := target.global_position
	_apply_radius_damage(impact_position)
	_spawn_impact(impact_position)
	return true


func _find_nearest_enemy() -> Node2D:
	var attack_range_val := _get_attack_range()
	var nearest_enemy: Node2D = null
	var nearest_distance_squared := attack_range_val * attack_range_val

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		if not enemy.has_method("take_damage"):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node.is_queued_for_deletion():
			continue

		var distance_squared := global_position.distance_squared_to(enemy_node.global_position)
		if distance_squared > nearest_distance_squared:
			continue

		nearest_enemy = enemy_node
		nearest_distance_squared = distance_squared

	return nearest_enemy


func _apply_radius_damage(impact_position: Vector2) -> void:
	var seal_radius := _get_radius()
	var seal_radius_squared := seal_radius * seal_radius
	var seal_damage := _get_damage()

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		if not enemy.has_method("take_damage"):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node.is_queued_for_deletion():
			continue
		if impact_position.distance_squared_to(enemy_node.global_position) > seal_radius_squared:
			continue

		# Story 005: weapon-side 相克 matchup multiplier.
		var final_damage := seal_damage * ElementMatchup.modifier(element, WeaponBase.element_of(enemy_node))
		final_damage = WeaponBase.apply_combo_effects(owner_combo_manager(), enemy_node, final_damage)
		enemy_node.call("take_damage", final_damage)


func _spawn_impact(impact_position: Vector2) -> void:
	if impact_scene == null:
		push_warning("MountainSealWeapon has no impact scene.")
		return

	var impact_instance := impact_scene.instantiate()
	if not impact_instance is Node2D:
		push_error("MountainSealWeapon impact_scene must instantiate a Node2D.")
		impact_instance.queue_free()
		return

	var impact := impact_instance as Node2D
	_get_effect_parent().add_child(impact)
	impact.global_position = impact_position

	if impact.has_method("configure"):
		impact.call("configure", _get_radius())


func _get_radius() -> float:
	return maxf(radius, MIN_RADIUS)


func _get_effect_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene

	var parent := get_parent()
	if parent != null and parent.get_parent() != null:
		return parent.get_parent()

	return self
