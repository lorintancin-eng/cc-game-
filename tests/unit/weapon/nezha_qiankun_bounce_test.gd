## 环天圈弹射投射物（乾坤圈进化）：链式弹射 / 单敌去重 / 选最近未命中 / 弹射递减。
##
## 直接驱动 _hit_and_redirect + _on_body_entered + MockEnemy。测试保持 bounces 高于驱动
## 次数、且场上始终有「下一个目标」，避免投射物中途 _finish 自 queue_free（同飞剑/乾坤圈
## 测试的处理）。Nezha 入树以便 _find_next_target 用 get_tree()。
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/weapon -gexit

extends "res://tests/helpers/test_base.gd"

const QiankunBounceProjectileScript = preload("res://scripts/weapon/nezha/qiankun_bounce_projectile.gd")


class MockEnemy extends Node2D:
	var total_damage: float = 0.0
	var hit_count: int = 0

	func take_damage(amount: float) -> void:
		total_damage += amount
		hit_count += 1


func _make_projectile(dmg: float, bounces: int) -> QiankunBounceProjectile:
	var proj: QiankunBounceProjectile = QiankunBounceProjectileScript.new()
	add_child_autofree(proj)
	proj.global_position = Vector2.ZERO
	proj.damage = dmg
	proj.bounces_remaining = bounces
	return proj


func _enemy_at(pos: Vector2) -> MockEnemy:
	var e := MockEnemy.new()
	e.add_to_group("enemies")
	add_child_autofree(e)
	e.global_position = pos
	return e


func test_bounce_chains_through_distinct_enemies() -> void:
	var proj := _make_projectile(10.0, 6)  # 高于驱动次数 → 不触发 _finish
	var e1 := _enemy_at(Vector2(10.0, 0.0))
	var e2 := _enemy_at(Vector2(20.0, 0.0))
	var e3 := _enemy_at(Vector2(30.0, 0.0))

	proj._hit_and_redirect(e1)
	assert_eq(e1.hit_count, 1, "命中敌 1")
	assert_eq(proj.bounces_remaining, 5, "弹射 -1")

	proj._hit_and_redirect(e2)
	assert_eq(e2.hit_count, 1, "弹射命中敌 2")
	assert_eq(proj.bounces_remaining, 4)

	proj._hit_and_redirect(e3)
	assert_eq(e3.hit_count, 1, "弹射命中敌 3")
	assert_float_eq(e3.total_damage, 10.0, 0.001, "每跳满伤")


func test_bounce_dedups_same_enemy() -> void:
	var proj := _make_projectile(10.0, 6)
	var e1 := _enemy_at(Vector2(10.0, 0.0))
	var _e2 := _enemy_at(Vector2(20.0, 0.0))  # 让首次命中后有下一个目标，不 _finish

	proj._on_body_entered(e1)
	proj._on_body_entered(e1)  # 已命中 → 去重

	assert_eq(e1.hit_count, 1, "同一敌人弹射中只命中一次")


func test_find_next_target_picks_nearest_unhit() -> void:
	var proj := _make_projectile(10.0, 6)
	var near := _enemy_at(Vector2(40.0, 0.0))
	var far := _enemy_at(Vector2(400.0, 0.0))

	assert_eq(proj._find_next_target(), near, "选最近的未命中敌人")

	proj._hit_and_redirect(near)  # near 进入 _hit_ids，剩 far
	assert_eq(proj._find_next_target(), far, "最近的已命中 → 选次近")


func test_find_next_target_null_when_all_hit() -> void:
	var proj := _make_projectile(10.0, 6)
	var only := _enemy_at(Vector2(40.0, 0.0))
	# 标记为已命中（不驱动 _hit_and_redirect 以免无目标 → _finish）
	proj._hit_ids[only.get_instance_id()] = true
	assert_null(proj._find_next_target(), "全部命中过 → 无下一个目标")
