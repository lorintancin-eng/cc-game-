## 火尖枪·灼烧地面（哪吒 W201 附带）：范围 DoT + 火尖枪投射物到期生成。
##
## DoT 直接驱动 _apply_dot + MockEnemy；生成测试用 _spawn_burning_ground（不触发
## queue_free，避免 teardown 双重释放），验证灼烧地面作为投射物父节点的子节点出现。
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/weapon -gexit

extends "res://tests/helpers/test_base.gd"

const BurningGroundScript = preload("res://scripts/weapon/nezha/burning_ground.gd")
const FireSpearProjectileScript = preload("res://scripts/weapon/nezha/fire_spear_projectile.gd")


class MockEnemy extends Node2D:
	var total_damage: float = 0.0
	var hit_count: int = 0

	func take_damage(amount: float) -> void:
		total_damage += amount
		hit_count += 1


func _make_ground(r: float, dot: float) -> BurningGround:
	var g: BurningGround = BurningGroundScript.new()
	add_child_autofree(g)
	g.global_position = Vector2.ZERO
	g.radius = r
	g.dot_per_tick = dot
	return g


func _make_enemy(pos: Vector2) -> MockEnemy:
	var e := MockEnemy.new()
	e.add_to_group("enemies")
	add_child_autofree(e)
	e.global_position = pos
	return e


func test_burning_ground_dots_only_enemies_in_radius() -> void:
	var ground := _make_ground(40.0, 3.0)
	var inside := _make_enemy(Vector2(20.0, 0.0))
	var outside := _make_enemy(Vector2(200.0, 0.0))

	ground._apply_dot()

	assert_eq(inside.hit_count, 1, "范围内敌人被灼烧")
	assert_float_eq(inside.total_damage, 3.0, 0.001, "每跳 = dot_per_tick")
	assert_eq(outside.hit_count, 0, "范围外敌人不被灼烧")


func test_fire_spear_projectile_spawns_burning_ground() -> void:
	# 灼烧地面作为投射物父节点的子节点生成（投射物到期/耗尽时留在原地）。
	var container := Node2D.new()
	add_child_autofree(container)
	var proj = FireSpearProjectileScript.new()
	container.add_child(proj)  # get_parent() = container（由 container 的 autofree 统一回收）

	proj._spawn_burning_ground()

	var found := false
	for child in container.get_children():
		if child is BurningGround:
			found = true
			break
	assert_true(found, "火尖枪生成灼烧地面（投射物的兄弟节点）")
