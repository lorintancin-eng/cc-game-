class_name FireSpearWeapon
extends NezhaWeaponBase

## 火尖枪（哪吒 W201）— 朝最近敌人掷出穿透火枪。
##
## 三昧真火「蓄力」联动（继承自 NezhaWeaponBase）：蓄力时本次 **伤害 ×1.3、范围 ×1.5**，
## 命中后消费；无目标时不消费，留给下一次有目标的攻击。
##
## TODO(Slice 4)：命中/到期生成「灼烧地面」滞留伤害区。

const DEFAULT_PROJECTILE_SCENE: PackedScene = preload("res://scenes/weapon/nezha/FireSpearProjectile.tscn")

@export var projectile_scene: PackedScene = DEFAULT_PROJECTILE_SCENE
@export var pierce_count: int = 2


func _try_attack() -> bool:
	# 字典取值是 Variant，先落到类型化局部变量，避免 `:=` 推断失败。
	var boost := _attack_boost()
	var armed: bool = boost["armed"]
	var damage_mult: float = boost["damage_mult"]
	var range_mult: float = boost["range_mult"]

	var search_range := _get_attack_range() * range_mult
	var target := _find_nearest_enemy(search_range)
	if target == null:
		return false  # 无目标 → 不消费蓄力

	var fired := _fire_spear(
		global_position.direction_to(target.global_position),
		_get_damage() * damage_mult,
		_get_projectile_lifetime() * range_mult
	)
	if fired:
		_consume_boost_if(armed)
	return fired


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
