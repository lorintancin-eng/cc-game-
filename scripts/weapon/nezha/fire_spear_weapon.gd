class_name FireSpearWeapon
extends WeaponBase

## 火尖枪（哪吒 W201）— 朝最近敌人掷出穿透火枪。
##
## 三昧真火「蓄力」联动：哪吒蓄力时，本次攻击 **伤害 ×1.3、范围 ×1.5**，
## 命中后消费蓄力（清零）。无目标时不消费，留给下一次有目标的攻击。
## 角色引用走兄弟节点 get_parent()/"CharacterBase"（同孙悟空武器模式）。
##
## TODO(Slice 4)：命中/到期生成「灼烧地面」滞留伤害区。

const DEFAULT_PROJECTILE_SCENE: PackedScene = preload("res://scenes/weapon/nezha/FireSpearProjectile.tscn")

@export var projectile_scene: PackedScene = DEFAULT_PROJECTILE_SCENE
@export var pierce_count: int = 2


func _try_attack() -> bool:
	# 蓄力查询（用增强后的范围搜敌，真正开火后才消费）。
	var nezha := _get_nezha()
	var armed: bool = nezha != null and nezha.is_fire_armed()
	var range_mult: float = nezha.fire_range_multiplier() if armed else 1.0
	var damage_mult: float = nezha.fire_damage_multiplier() if armed else 1.0

	var search_range := _get_attack_range() * range_mult
	var target := _find_nearest_enemy(search_range)
	if target == null:
		return false  # 无目标 → 不消费蓄力

	var fired := _fire_spear(
		global_position.direction_to(target.global_position),
		_get_damage() * damage_mult,
		_get_projectile_lifetime() * range_mult
	)
	if fired and armed:
		nezha.consume_fire_boost()
	return fired


func _get_nezha() -> Nezha:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("CharacterBase") as Nezha


func _find_nearest_enemy(search_range: float) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance_squared := search_range * search_range

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
		nearest = enemy_node
		nearest_distance_squared = distance_squared

	return nearest


func _fire_spear(direction: Vector2, dmg: float, life: float) -> bool:
	if projectile_scene == null:
		push_warning("FireSpearWeapon has no projectile scene.")
		return false

	var instance := projectile_scene.instantiate()
	if not instance is FireSpearProjectile:
		push_error("FireSpearWeapon projectile_scene must instantiate a FireSpearProjectile.")
		instance.queue_free()
		return false

	var projectile := instance as FireSpearProjectile
	_get_projectile_parent().add_child(projectile)
	projectile.global_position = global_position
	projectile.launch(direction, dmg, _get_projectile_speed(), life, maxi(pierce_count, 1))
	return true


func _get_projectile_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene
	var parent := get_parent()
	if parent != null and parent.get_parent() != null:
		return parent.get_parent()
	return self
