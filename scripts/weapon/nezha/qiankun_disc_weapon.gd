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
	var target := _find_nearest_enemy(_get_attack_range())
	if target == null:
		return false
	# 法相期间伤害 ×1.5（射速加成由 NezhaWeaponBase._get_cooldown 自动处理）。
	return _fire_disc(
		global_position.direction_to(target.global_position),
		_get_damage() * _avatar_damage_mult(),
		out_distance
	)


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
