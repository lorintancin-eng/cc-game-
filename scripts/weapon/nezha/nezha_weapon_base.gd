class_name NezhaWeaponBase
extends WeaponBase

## 哪吒武器共享基类。
##
## 提供三件哪吒武器（火尖枪 / 混天绫 / 乾坤圈）共用的能力，避免重复：
##   - 三昧真火「蓄力」查询/消费（_attack_boost / _consume_boost_if）
##   - 最近敌人搜索（_find_nearest_enemy）
##   - 投射物父节点选择（_get_projectile_parent）
##
## 角色引用走兄弟节点 get_parent()/"CharacterBase"（同孙悟空武器模式）。
## 子类只需实现 _try_attack：取 _attack_boost() → 用增强后的范围/伤害开火 →
## 命中后 _consume_boost_if(boost["armed"])。


func _get_nezha() -> Nezha:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("CharacterBase") as Nezha


## 本次攻击的三昧真火增强：{armed: bool, damage_mult: float, range_mult: float}。
## 未蓄力（或非哪吒）时两个倍率均为 1.0。
func _attack_boost() -> Dictionary:
	var nezha := _get_nezha()
	var armed: bool = nezha != null and nezha.is_fire_armed()
	return {
		"armed": armed,
		"damage_mult": (nezha.fire_damage_multiplier() if armed else 1.0),
		"range_mult": (nezha.fire_range_multiplier() if armed else 1.0),
	}


## 命中后调用：若本次为蓄力攻击则消费蓄力（清零三昧真火）。
func _consume_boost_if(armed: bool) -> void:
	if not armed:
		return
	var nezha := _get_nezha()
	if nezha != null:
		nezha.consume_fire_boost()


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


func _get_projectile_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene
	var parent := get_parent()
	if parent != null and parent.get_parent() != null:
		return parent.get_parent()
	return self
