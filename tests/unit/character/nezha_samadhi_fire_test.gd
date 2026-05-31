## 哪吒「莲花化身 · 三头六臂」三昧真火 → (满→ready) → 主动释放法相天地 → 莲花真火爆。
##
## 设计：design/quick-specs/nezha-skill-redesign.md
##   击杀 +5 / 受击 +8 充能；满 100 → ready（不自动）；玩家按 1 → try_activate_avatar() 进入
##   法相 6s（减伤 30%、不再充能）；到期放莲花真火爆（80 + 8×法相击杀数，半径 160）后清零。
##
## Nezha 入树（add_child_autofree）以便 nova 用 get_tree() 取 enemies；同步测试无帧推进，
## _physics_process 由测试手动驱动。
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/character -gexit

extends "res://tests/helpers/test_base.gd"


class MockEnemy extends Node2D:
	var total_damage: float = 0.0
	var hit_count: int = 0

	func take_damage(amount: float) -> void:
		total_damage += amount
		hit_count += 1


func _nezha() -> Nezha:
	return add_child_autofree(Nezha.new())


func _enemy_at(pos: Vector2) -> MockEnemy:
	var e := MockEnemy.new()
	e.add_to_group("enemies")
	add_child_autofree(e)
	e.global_position = pos
	return e


func _fill(n: Nezha) -> void:
	for _i in range(20):
		n._on_kill(null)  # 20 × 5 = 100


func test_samadhi_charges_by_kill_and_by_hit() -> void:
	var n := _nezha()
	n._on_kill(null)
	assert_eq(n.current_lingqi, 5.0, "击杀 +5")
	n._on_damaged(1.0)
	assert_eq(n.current_lingqi, 13.0, "受击 +8（与伤害数值无关）")


func test_full_meter_becomes_ready_not_auto_active() -> void:
	var n := _nezha()
	watch_signals(n)
	_fill(n)
	assert_true(n.is_avatar_ready(), "满槽 → ready（待主动释放）")
	assert_false(n.is_avatar_active(), "不自动进入法相")
	assert_signal_emitted(n, "energy_full_triggered")  # HUD 提示


func test_manual_trigger_activates_avatar() -> void:
	var n := _nezha()
	assert_false(n.try_activate_avatar(), "未满时释放失败")
	_fill(n)
	assert_true(n.try_activate_avatar(), "满槽主动释放成功")
	assert_true(n.is_avatar_active(), "进入法相天地")
	assert_false(n.is_avatar_ready(), "释放后 ready 清除")
	assert_false(n.try_activate_avatar(), "法相中重复释放失败")


func test_avatar_reduces_incoming_damage() -> void:
	var n := _nezha()
	assert_eq(n.get_incoming_damage_mult(), 1.0, "非法相不减伤")
	_fill(n)
	n.try_activate_avatar()
	assert_eq(n.get_incoming_damage_mult(), 0.7, "法相减伤 30%")


func test_avatar_does_not_recharge_meter() -> void:
	var n := _nezha()
	_fill(n)
	n.try_activate_avatar()
	n._on_damaged(1.0)
	assert_eq(n.current_lingqi, 100.0, "法相期间受击不再充能")


func test_avatar_expires_fires_lotus_nova_and_resets() -> void:
	var n := _nezha()
	_fill(n)
	n.try_activate_avatar()  # → 法相（avatar_kills 归零）
	n._on_kill(null)
	n._on_kill(null)  # 法相期间击杀 ×2
	assert_eq(n.avatar_kills(), 2, "法相期间累计击杀")

	var near := _enemy_at(Vector2(50.0, 0.0))    # nova 半径 160 内
	var far := _enemy_at(Vector2(500.0, 0.0))    # 半径外

	n._physics_process(7.0)  # 推过 6s → 法相结束 → 莲花真火爆

	assert_false(n.is_avatar_active(), "法相结束")
	assert_eq(n.current_lingqi, 0.0, "结束清零、重新蓄力")
	assert_eq(near.hit_count, 1, "莲花真火爆命中范围内敌人")
	assert_float_eq(near.total_damage, 96.0, 0.001, "nova = 80 + 8×2击杀")
	assert_eq(far.hit_count, 0, "范围外敌人不中")
