class_name CelestialSilkWeapon
extends NezhaWeaponBase

## 混天绫（哪吒 W202）— 朝最近敌人抛出红绫，在其位置展开束缚领域。
##
## 领域（CelestialSilkZone）：普通敌束缚、Boss 减速、范围内持续伤害（见 zone 脚本）。
## 三昧真火「蓄力」联动：蓄力时本次领域 **半径 ×1.5、每 tick 伤害 ×1.3**，命中后消费。
## WeaponBase.damage 即「每 tick DoT 伤害」（升级强化它即可提升持续伤害）。
##
## 解锁：设计上为升级解锁（非初始）。当前为开发期常驻；正式解锁门控在升级池切片接入。

const DEFAULT_ZONE_SCENE: PackedScene = preload("res://scenes/weapon/nezha/CelestialSilkZone.tscn")

@export var zone_scene: PackedScene = DEFAULT_ZONE_SCENE
@export var zone_radius: float = 90.0
@export var zone_lifetime: float = 3.0
@export var tick_interval: float = 0.5


func _try_attack() -> bool:
	var target := _find_nearest_enemy(_get_attack_range())
	if target == null:
		return false
	# 法相期间每跳 DoT ×1.5（射速加成由 NezhaWeaponBase._get_cooldown 自动处理）。
	return _spawn_silk(
		target.global_position,
		zone_radius,
		_get_damage() * _avatar_damage_mult()
	)


func _spawn_silk(pos: Vector2, r: float, dot: float) -> bool:
	if zone_scene == null:
		push_warning("CelestialSilkWeapon has no zone scene.")
		return false

	var instance := zone_scene.instantiate()
	if not instance is CelestialSilkZone:
		push_error("CelestialSilkWeapon zone_scene must instantiate a CelestialSilkZone.")
		instance.queue_free()
		return false

	var zone := instance as CelestialSilkZone
	_get_projectile_parent().add_child(zone)
	zone.setup(pos, r, dot, tick_interval, zone_lifetime)
	return true
