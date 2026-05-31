## 乾坤圈投射物 回旋两段 / 每段去重 / 满伤（哪吒 W203）。
##
## 直接驱动 _on_body_entered + _switch_to_return + MockEnemy，headless 确定性。
## _on_body_entered 不触发 _finish（仅 _physics_process 在到期/接回时销毁），
## 故可自由驱动而不会中途自 queue_free。
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/weapon -gexit

extends "res://tests/helpers/test_base.gd"

const QiankunDiscProjectileScript = preload("res://scripts/weapon/nezha/qiankun_disc_projectile.gd")


class MockEnemy extends Node2D:
	var total_damage: float = 0.0
	var hit_count: int = 0

	func take_damage(amount: float) -> void:
		total_damage += amount
		hit_count += 1


func _make_projectile(dmg: float) -> QiankunDiscProjectile:
	var proj: QiankunDiscProjectile = QiankunDiscProjectileScript.new()
	add_child_autofree(proj)
	proj.damage = dmg  # 不 launch()，避免开启 _physics_process（移动/回旋）
	return proj


func _make_enemy() -> MockEnemy:
	var e := MockEnemy.new()
	e.add_to_group("enemies")
	add_child_autofree(e)
	return e


func test_qiankun_hits_each_enemy_once_per_phase() -> void:
	# Arrange
	var proj := _make_projectile(15.0)
	var enemy := _make_enemy()

	# Act — 去程命中（含重叠去重）
	proj._on_body_entered(enemy)
	proj._on_body_entered(enemy)
	# Assert
	assert_eq(enemy.hit_count, 1, "去程同一敌人只命中一次")

	# Act — 回旋后回程命中
	proj._switch_to_return()
	proj._on_body_entered(enemy)
	proj._on_body_entered(enemy)
	# Assert
	assert_eq(enemy.hit_count, 2, "回程再命中一次 → 共两段")
	assert_float_eq(enemy.total_damage, 30.0, 0.001, "两段各满伤")


func test_qiankun_hits_multiple_distinct_enemies_in_a_phase() -> void:
	var proj := _make_projectile(15.0)
	var e1 := _make_enemy()
	var e2 := _make_enemy()

	proj._on_body_entered(e1)
	proj._on_body_entered(e2)

	assert_eq(e1.hit_count, 1, "敌 1 命中一次")
	assert_eq(e2.hit_count, 1, "敌 2 命中一次")


func test_qiankun_ignores_non_enemy_body() -> void:
	var proj := _make_projectile(15.0)
	var non_enemy := MockEnemy.new()  # 未加入 "enemies" 组
	add_child_autofree(non_enemy)

	proj._on_body_entered(non_enemy)

	assert_eq(non_enemy.hit_count, 0, "非敌人 body 不受伤")
