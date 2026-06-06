class_name FlyingSwordWeapon
extends WeaponBase

const DEFAULT_PROJECTILE_SCENE: PackedScene = preload("res://scenes/weapon/FlyingSwordProjectile.tscn")

@export var pierce_count: int = 3
@export var projectile_scene: PackedScene = DEFAULT_PROJECTILE_SCENE
@export var projectile_count: int = 1
@export var projectile_spread_degrees: float = 10.0


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
		push_warning("FlyingSwordWeapon has no projectile scene.")
		return false

	var projectile_instance := projectile_scene.instantiate()
	if not projectile_instance is Node2D:
		push_error("FlyingSwordWeapon projectile_scene must instantiate a Node2D projectile.")
		projectile_instance.queue_free()
		return false
	if not projectile_instance.has_method("launch"):
		push_error("FlyingSwordWeapon projectile_scene must instantiate a projectile with launch().")
		projectile_instance.queue_free()
		return false

	var projectile := projectile_instance as Node2D
	projectile.set("element", element)  # Story 005: pass weapon element to the projectile
	projectile.set("combo_manager", owner_combo_manager())  # Stories 008/009: crit/frost state
	var projectile_parent := _get_projectile_parent()
	projectile_parent.add_child(projectile)
	projectile.global_position = global_position

	projectile.call(
		"launch",
		direction,
		_get_damage(),
		_get_projectile_speed(),
		_get_projectile_lifetime(),
		_get_pierce_count()
	)
	return true


func _get_projectile_count() -> int:
	return maxi(projectile_count, 1)


func _get_pierce_count() -> int:
	# Story 008: 矿脉精粹 (土生金) grants +1 pierce (pass through 1 more enemy).
	var cm := owner_combo_manager()
	var bonus: int = cm.get_pierce_bonus() if cm != null else 0
	return maxi(pierce_count + bonus, 1)


func _get_projectile_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene

	var parent := get_parent()
	if parent != null and parent.get_parent() != null:
		return parent.get_parent()

	return self
