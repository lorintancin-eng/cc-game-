class_name QiankunDiscWeapon
extends NezhaWeaponBase

## 乾坤圈（哪吒 W203）— 自动锁定最近敌人，掷出回旋两段的金圈。
##
## 三昧真火「蓄力」联动：蓄力时本次伤害 ×1.3、飞出距离（范围）×1.5，命中后消费。
## 圈飞出 out_distance 后回旋飞回玩家，去/回各命中同一敌人一次（共 2 段）。
##
## 解锁：设计上为升级解锁（非初始）。当前为开发期常驻；正式解锁门控在升级池切片接入。

const DEFAULT_PROJECTILE_SCENE: PackedScene = preload("res://scenes/weapon/nezha/QiankunDiscProjectile.tscn")

@export var projectile_scene: PackedScene = DEFAULT_PROJECTILE_SCENE
@export var out_distance: float = 220.0


func _try_attack() -> bool:
	# 字典取值是 Variant，先落到类型化局部变量，避免 `:=` 推断失败。
	var boost := _attack_boost()
	var armed: bool = boost["armed"]
	var damage_mult: float = boost["damage_mult"]
	var range_mult: float = boost["range_mult"]

	var search_range := _get_attack_range() * range_mult
	var target := _find_nearest_enemy(search_range)
	if target == null:
		return false

	var fired := _fire_disc(
		global_position.direction_to(target.global_position),
		_get_damage() * damage_mult,
		out_distance * range_mult
	)
	if fired:
		_consume_boost_if(armed)
	return fired


func _fire_disc(direction: Vector2, dmg: float, out_dist: float) -> bool:
	if projectile_scene == null:
		push_warning("QiankunDiscWeapon has no projectile scene.")
		return false

	var instance := projectile_scene.instantiate()
	if not instance is QiankunDiscProjectile:
		push_error("QiankunDiscWeapon projectile_scene must instantiate a QiankunDiscProjectile.")
		instance.queue_free()
		return false

	var disc := instance as QiankunDiscProjectile
	_get_projectile_parent().add_child(disc)
	disc.global_position = global_position
	disc.launch(direction, dmg, _get_projectile_speed(), out_dist, get_parent() as Node2D)
	return true
