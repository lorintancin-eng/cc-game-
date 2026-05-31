## 镇妖四宝效果（Pickup.apply_effect + TimeStop._apply_freeze）：回血/吸经验/清屏/冻结。
## 设计：design/quick-specs/pickup-items.md
##
## 直接驱动 apply_effect + mock player/orb/enemy（带对应方法 + 组）。Pickup/TimeStop 入树
## 以便用 get_tree() 取组。
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/system -gexit

extends "res://tests/helpers/test_base.gd"

const PickupScript = preload("res://scripts/system/pickup.gd")
const TimeStopScript = preload("res://scripts/system/time_stop.gd")


class MockPlayer extends Node2D:
	var max_hp: float = 100.0
	var healed: float = 0.0
	var gained_xp: float = 0.0

	func heal(amount: float) -> void:
		healed += amount

	func gain_experience(amount: float) -> void:
		gained_xp += amount


class MockOrb extends Node2D:
	var xp_value: float = 0.0


class MockEnemy extends Node2D:
	var velocity: Vector2 = Vector2.ZERO
	var total_damage: float = 0.0

	func take_damage(amount: float) -> void:
		total_damage += amount


func _pickup(type: String) -> Pickup:
	var p: Pickup = PickupScript.new()
	p.pickup_type = type
	add_child_autofree(p)
	return p


func _orb(xp: float) -> MockOrb:
	var o := MockOrb.new()
	o.xp_value = xp
	o.add_to_group(&"experience_orbs")
	add_child_autofree(o)
	return o


func _enemy(is_boss: bool = false) -> MockEnemy:
	var e := MockEnemy.new()
	e.add_to_group(&"enemies")
	if is_boss:
		e.add_to_group(&"bosses")
	add_child_autofree(e)
	return e


func test_heal_pickup_heals_fraction_of_max_hp() -> void:
	var player: MockPlayer = autofree(MockPlayer.new())
	player.max_hp = 100.0
	var pickup := _pickup(PickupDrops.TYPE_HEAL)

	pickup.apply_effect(player)

	assert_float_eq(player.healed, 30.0, 0.001, "灵丹回 30% 最大气血")


func test_magnet_pickup_grants_all_orb_xp() -> void:
	var player: MockPlayer = autofree(MockPlayer.new())
	var _o1 := _orb(5.0)
	var _o2 := _orb(7.0)
	var pickup := _pickup(PickupDrops.TYPE_MAGNET)

	pickup.apply_effect(player)

	assert_float_eq(player.gained_xp, 12.0, 0.001, "聚灵符吸取全屏经验(5+7)")


func test_purge_pickup_damages_all_enemies() -> void:
	var e1 := _enemy()
	var e2 := _enemy()
	var pickup := _pickup(PickupDrops.TYPE_PURGE)

	pickup.apply_effect(null)  # purge 不需要 player

	assert_float_eq(e1.total_damage, 100.0, 0.001, "镇妖雷符全屏伤害")
	assert_float_eq(e2.total_damage, 100.0, 0.001)


func test_timestop_freezes_normal_and_slows_boss() -> void:
	var time_stop: TimeStop = TimeStopScript.new()
	add_child_autofree(time_stop)
	var normal := _enemy()
	normal.velocity = Vector2(30.0, 40.0)
	var boss := _enemy(true)
	boss.velocity = Vector2(10.0, 0.0)

	time_stop._apply_freeze()

	assert_eq(normal.velocity, Vector2.ZERO, "普通敌定身(velocity 归零)")
	assert_eq(boss.velocity, Vector2(5.0, 0.0), "Boss 仅减速 ×0.5")
