## 混天绫·束缚领域（哪吒 W202）：范围 DoT / 普通敌束缚 / Boss 减速 / 范围外不受影响。
##
## 直接驱动 _apply_dot + _apply_movement_control + MockEnemy（带 velocity / take_damage），
## headless 确定性；不调 _physics_process（不触发 lifetime queue_free）。
## 仅验证「调用 enemy 公共 API」的效果，不改 enemy.gd。
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/weapon -gexit

extends "res://tests/helpers/test_base.gd"

const CelestialSilkZoneScript = preload("res://scripts/weapon/nezha/celestial_silk_zone.gd")


class MockEnemy extends Node2D:
	var velocity: Vector2 = Vector2.ZERO
	var total_damage: float = 0.0
	var hit_count: int = 0

	func take_damage(amount: float) -> void:
		total_damage += amount
		hit_count += 1


func _make_zone(r: float, dot: float) -> CelestialSilkZone:
	var zone: CelestialSilkZone = CelestialSilkZoneScript.new()
	add_child_autofree(zone)
	zone.global_position = Vector2.ZERO
	zone.radius = r
	zone.dot_per_tick = dot
	return zone


func _make_enemy(pos: Vector2, is_boss: bool = false) -> MockEnemy:
	var e := MockEnemy.new()
	e.add_to_group("enemies")
	if is_boss:
		e.add_to_group("bosses")
	add_child_autofree(e)
	e.global_position = pos
	return e


func test_silk_dot_damages_only_enemies_in_radius() -> void:
	var zone := _make_zone(100.0, 5.0)
	var inside := _make_enemy(Vector2(50.0, 0.0))
	var outside := _make_enemy(Vector2(400.0, 0.0))

	zone._apply_dot()

	assert_eq(inside.hit_count, 1, "范围内敌人受 DoT")
	assert_float_eq(inside.total_damage, 5.0, 0.001, "每 tick 伤害 = dot_per_tick")
	assert_eq(outside.hit_count, 0, "范围外敌人不受影响")


func test_silk_binds_normal_enemy_velocity_to_zero() -> void:
	var zone := _make_zone(100.0, 5.0)
	var enemy := _make_enemy(Vector2(20.0, 0.0))
	enemy.velocity = Vector2(30.0, 40.0)

	zone._apply_movement_control()

	assert_eq(enemy.velocity, Vector2.ZERO, "普通敌被束缚（velocity 归零）")


func test_silk_slows_boss_instead_of_binding() -> void:
	var zone := _make_zone(100.0, 5.0)
	var boss := _make_enemy(Vector2(20.0, 0.0), true)
	boss.velocity = Vector2(10.0, 0.0)

	zone._apply_movement_control()

	assert_eq(boss.velocity, Vector2(5.0, 0.0), "Boss 仅减速 ×0.5，不冻结")


func test_silk_leaves_outside_enemy_movement_untouched() -> void:
	var zone := _make_zone(100.0, 5.0)
	var enemy := _make_enemy(Vector2(400.0, 0.0))
	enemy.velocity = Vector2(10.0, 10.0)

	zone._apply_movement_control()

	assert_eq(enemy.velocity, Vector2(10.0, 10.0), "范围外不被束缚/减速")
