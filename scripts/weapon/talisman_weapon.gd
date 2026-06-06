class_name TalismanWeapon
extends WeaponBase

const DEFAULT_PROJECTILE_SCENE: PackedScene = preload("res://scenes/weapon/TalismanProjectile.tscn")

@export var projectile_scene: PackedScene = DEFAULT_PROJECTILE_SCENE
@export var projectile_count: int = 1
@export var projectile_spread_degrees: float = 12.0


func _try_attack() -> bool:
	var target := _find_nearest_enemy()
	if target == null:
		return false

	return _fire_projectiles(target)


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


func _fire_projectiles(target: Node2D) -> bool:
	var projectile_total := _get_projectile_count()
	var base_direction := global_position.direction_to(target.global_position)
	var spread_step := deg_to_rad(maxf(projectile_spread_degrees, 0.0))
	var start_offset := -spread_step * float(projectile_total - 1) * 0.5
	var did_fire := false

	for index in range(projectile_total):
		var direction := base_direction.rotated(start_offset + spread_step * float(index))
		if _fire_projectile(direction):
			did_fire = true

	return did_fire


func _fire_projectile(direction: Vector2) -> bool:
	if projectile_scene == null:
		push_warning("TalismanWeapon has no projectile scene.")
		return false

	var projectile_instance := projectile_scene.instantiate()
	if not projectile_instance is TalismanProjectile:
		push_error("TalismanWeapon projectile_scene must instantiate a TalismanProjectile.")
		projectile_instance.queue_free()
		return false

	var projectile := projectile_instance as TalismanProjectile
	projectile.element = element  # Story 005: pass weapon element to the projectile
	projectile.combo_manager = owner_combo_manager()  # Stories 008/009: combo state for crit/frost
	var projectile_parent := _get_projectile_parent()
	projectile_parent.add_child(projectile)
	projectile.global_position = global_position

	projectile.launch(
		direction,
		_get_damage(),
		_get_projectile_speed(),
		_get_attack_range(),
		_get_projectile_lifetime()
	)
	return true


func _get_projectile_count() -> int:
	return maxi(projectile_count, 1)


func _get_projectile_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene

	var parent := get_parent()
	if parent != null and parent.get_parent() != null:
		return parent.get_parent()

	return self
