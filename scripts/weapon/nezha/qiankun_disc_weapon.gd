class_name QiankunDiscWeapon
extends NezhaWeaponBase

## 乾坤圈（哪吒 W203）— 自动锁定最近敌人。两种形态：
##   - 默认：掷出**回旋两段**的金圈（飞出再回旋飞回，去/回各命中一次）。
##   - 环天圈（升级 add_qiankun_orbit 进化后）：改为掷出**弹射金圈**——直线飞向目标，命中后
##     改向次近的未命中敌人继续弹射；每多升一级 +1 发（满屏金圈乱弹）。
##
## 三昧真火法相期伤害 ×1.5（射速由基类 _get_cooldown 自动处理）。
## 三才合击：三件神兵全解锁 → 出手额外甩一道火尖枪（见 NezhaWeaponBase / FireSpearWeapon）。

const DEFAULT_PROJECTILE_SCENE: PackedScene = preload("res://scenes/weapon/nezha/QiankunDiscProjectile.tscn")
const DEFAULT_BOUNCE_SCENE: PackedScene = preload("res://scenes/weapon/nezha/QiankunBounceProjectile.tscn")
const SYNERGY_SPEAR_FRACTION: float = 0.5  # 三才合击额外火尖枪的伤害比例
const BOUNCE_COUNT: int = 4                 # 环天圈每发弹射的敌人数

@export var projectile_scene: PackedScene = DEFAULT_PROJECTILE_SCENE
@export var bounce_scene: PackedScene = DEFAULT_BOUNCE_SCENE
@export var out_distance: float = 220.0

var _bounce_mode: bool = false
var _bounce_disc_count: int = 1


func _try_attack() -> bool:
	var target := _find_nearest_enemy(_get_attack_range())
	if target == null:
		return false

	# 法相期间伤害 ×1.5（射速加成由 NezhaWeaponBase._get_cooldown 自动处理）。
	var dmg := _get_damage() * _avatar_damage_mult()
	var fired: bool
	if _bounce_mode:
		fired = _fire_bounce_discs(target, dmg)
	else:
		fired = _fire_disc(global_position.direction_to(target.global_position), dmg, out_distance)

	# 三才合击：三件神兵全解锁 → 乾坤圈出手额外甩一道火尖枪（50% 伤害）。
	if fired and _all_nezha_weapons_unlocked():
		_fire_synergy_spear(target)
	return fired


# ─────────────────────────────────────────────
# 环天圈进化（弹射形态）
# ─────────────────────────────────────────────

func is_bounce_mode() -> bool:
	return _bounce_mode


func bounce_disc_count() -> int:
	return _bounce_disc_count


## 环天圈升级：首次化为弹射形态；后续每级 +1 发。
func add_qiankun_orbit() -> void:
	if not _bounce_mode:
		_bounce_mode = true
	else:
		_bounce_disc_count += 1


func _fire_bounce_discs(first_target: Node2D, dmg: float) -> bool:
	var any := false
	for _i in range(maxi(_bounce_disc_count, 1)):
		if _fire_bounce_disc(first_target, dmg):
			any = true
	return any


func _fire_bounce_disc(first_target: Node2D, dmg: float) -> bool:
	if bounce_scene == null:
		push_warning("QiankunDiscWeapon has no bounce scene.")
		return false
	var instance := bounce_scene.instantiate()
	if not instance is QiankunBounceProjectile:
		push_error("QiankunDiscWeapon bounce_scene must instantiate a QiankunBounceProjectile.")
		instance.queue_free()
		return false
	var disc := instance as QiankunBounceProjectile
	_get_projectile_parent().add_child(disc)
	disc.global_position = global_position
	disc.launch(first_target, dmg, _get_projectile_speed(), BOUNCE_COUNT)
	return true


# ─────────────────────────────────────────────
# 默认回旋形态
# ─────────────────────────────────────────────

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


# ─────────────────────────────────────────────
# 三才合击
# ─────────────────────────────────────────────

func _fire_synergy_spear(target: Node2D) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var fire_spear := parent.get_node_or_null("FireSpearWeapon") as FireSpearWeapon
	if fire_spear != null:
		fire_spear.fire_synergy_spear(target, SYNERGY_SPEAR_FRACTION)
