## 火尖枪投射物穿透 / 满伤 / 去重 / 拒绝（哪吒 W201）。
##
## 模型同飞剑，但独立类（后续加「灼烧地面」会分化）。直接驱动 _on_body_entered
## + MockEnemy，headless 确定性；测试停在 pierce cap 之下，避免投射物中途
## 自 queue_free 触发 GUT autofree 双重释放（同飞剑测试的处理）。
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/weapon -gexit

extends "res://tests/helpers/test_base.gd"

const FireSpearProjectileScript = preload("res://scripts/weapon/nezha/fire_spear_projectile.gd")


class MockEnemy extends Node2D:
	var total_damage: float = 0.0
	var hit_count: int = 0

	func take_damage(amount: float) -> void:
		total_damage += amount
		hit_count += 1


func _make_projectile(dmg: float, pierce: int) -> FireSpearProjectile:
	var proj: FireSpearProjectile = FireSpearProjectileScript.new()
	add_child_autofree(proj)
	# 直接设字段而非 launch()，避免开启 _physics_process（移动/寿命）。
	proj.damage = dmg
	proj.pierce_count = pierce
	return proj


func _make_enemy() -> MockEnemy:
	var e := MockEnemy.new()
	e.add_to_group("enemies")
	add_child_autofree(e)
	return e


func test_fire_spear_pierces_each_distinct_enemy_full_damage() -> void:
	# Arrange — pierce_count = 5（高于 3 次命中，不触发 cap/_finish）。
	var proj := _make_projectile(12.0, 5)
	var e1 := _make_enemy()
	var e2 := _make_enemy()
	var e3 := _make_enemy()

	# Act
	proj._on_body_entered(e1)
	proj._on_body_entered(e2)
	proj._on_body_entered(e3)

	# Assert — 每个一次满伤，无穿透衰减。
	assert_eq(e1.hit_count, 1, "敌 1 命中一次")
	assert_eq(e2.hit_count, 1, "敌 2 命中一次")
	assert_eq(e3.hit_count, 1, "敌 3 命中一次")
	assert_float_eq(e1.total_damage, 12.0, 0.001, "满伤无衰减")
	assert_float_eq(e3.total_damage, 12.0, 0.001, "第三个仍满伤")


func test_fire_spear_dedups_same_enemy() -> void:
	# pierce_count = 3，去重才是限制项（单个敌人不重复计数）。
	var proj := _make_projectile(12.0, 3)
	var enemy := _make_enemy()

	proj._on_body_entered(enemy)
	proj._on_body_entered(enemy)
	proj._on_body_entered(enemy)

	assert_eq(enemy.hit_count, 1, "同一敌人至多受击一次")
	assert_float_eq(enemy.total_damage, 12.0, 0.001, "重叠不重复扣血")


func test_fire_spear_rejects_body_when_pierce_exhausted() -> void:
	# 模拟已达穿透上限（2/2），验证入口守卫 `_hit_count >= pierce_count`。
	var proj := _make_projectile(7.0, 2)
	proj._hit_count = 2
	var late_enemy := _make_enemy()

	proj._on_body_entered(late_enemy)

	assert_eq(late_enemy.hit_count, 0, "达穿透上限后拒绝后续敌人")


func test_fire_spear_ignores_non_enemy_body() -> void:
	var proj := _make_projectile(12.0, 3)
	var non_enemy := MockEnemy.new()  # 未加入 "enemies" 组
	add_child_autofree(non_enemy)

	proj._on_body_entered(non_enemy)

	assert_eq(non_enemy.hit_count, 0, "非敌人 body 不受穿透伤害")
