class_name NezhaWeaponBase
extends WeaponBase

## 哪吒武器共享基类。
##
## 提供三件哪吒武器（火尖枪 / 混天绫 / 乾坤圈）共用的能力：
##   - 解锁门控（starts_locked / unlock / is_unlocked）
##   - 法相天地增益：法相期间冷却 ×0.4（射速 ×2.5）+ 伤害 ×1.5
##   - 最近敌人搜索（_find_nearest_enemy）
##   - 投射物父节点选择（_get_projectile_parent）
##
## 角色引用走兄弟节点 get_parent()/"CharacterBase"（同孙悟空武器模式）。
## 子类 _try_attack：搜敌 → 用 `_get_damage() * _avatar_damage_mult()` 开火即可；
## 射速加成由本基类覆盖 _get_cooldown() 自动处理，无需子类介入。

@export var starts_locked: bool = false

var _is_unlocked: bool = true


func _ready() -> void:
	if starts_locked:
		_is_unlocked = false


## 锁定时停火（覆盖 WeaponBase 的自动开火 _process 循环）。
func _process(delta: float) -> void:
	if not _is_unlocked:
		return
	super._process(delta)


## 由升级池「悟得…」解锁项调用（player._apply_upgrade）。
func unlock() -> void:
	_is_unlocked = true


func is_unlocked() -> bool:
	return _is_unlocked


# ─────────────────────────────────────────────
# 法相天地增益
# ─────────────────────────────────────────────

func _get_nezha() -> Nezha:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("CharacterBase") as Nezha


## 法相期间的伤害倍率（×1.5），否则 1.0。子类在开火伤害上乘它。
func _avatar_damage_mult() -> float:
	var nezha := _get_nezha()
	if nezha != null and nezha.is_avatar_active():
		return nezha.avatar_damage_mult()
	return 1.0


## 法相期间冷却 ×0.4（射速 ×2.5）。覆盖 WeaponBase 的冷却取值，自动生效。
func _get_cooldown() -> float:
	var base := super._get_cooldown()
	var nezha := _get_nezha()
	if nezha != null and nezha.is_avatar_active():
		return maxf(base * nezha.avatar_cooldown_mult(), MIN_COOLDOWN)
	return base


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
