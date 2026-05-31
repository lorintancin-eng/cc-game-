## 哪吒「三昧真火」充能 → 蓄力 → 增强 → 消费 逻辑。
## 设计：design/narrative/02_CHARACTER_DESIGN.md §4.3
##   受击 +10；满 100 蓄力；下一击 伤害 ×1.3 / 范围 ×1.5；触发清零。
##
## 纯逻辑（Nezha 无 @onready / 无场景依赖），detached .new() 直接测。
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/character -gexit

extends "res://tests/helpers/test_base.gd"


func _nezha() -> Nezha:
	return autofree(Nezha.new())


func test_samadhi_charges_fixed_ten_per_hit_regardless_of_damage() -> void:
	var n := _nezha()
	n._on_damaged(5.0)
	assert_eq(n.current_lingqi, 10.0, "受击固定 +10 真火（与伤害数值无关）")
	n._on_damaged(999.0)
	assert_eq(n.current_lingqi, 20.0, "再受击再 +10")


func test_samadhi_arms_and_emits_at_full() -> void:
	var n := _nezha()
	watch_signals(n)
	for _i in range(9):
		n._on_damaged(1.0)
	assert_false(n.is_fire_armed(), "90 真火未满 → 未蓄力")
	assert_signal_not_emitted(n, "energy_full_triggered")
	n._on_damaged(1.0)  # → 100
	assert_true(n.is_fire_armed(), "满 100 → 蓄力")
	assert_eq(n.current_lingqi, 100.0, "封顶 100")
	assert_signal_emitted(n, "energy_full_triggered")


func test_samadhi_does_not_overcharge_or_reemit_while_armed() -> void:
	var n := _nezha()
	for _i in range(10):
		n._on_damaged(1.0)  # 蓄力
	watch_signals(n)
	n._on_damaged(50.0)  # 蓄力中再受击
	assert_eq(n.current_lingqi, 100.0, "蓄力后冻结在 100，不溢出")
	assert_true(n.is_fire_armed())
	assert_signal_not_emitted(n, "energy_full_triggered", "蓄力中不重复 emit")


func test_multipliers_are_one_until_armed() -> void:
	var n := _nezha()
	assert_eq(n.fire_damage_multiplier(), 1.0, "未蓄力 伤害 ×1.0")
	assert_eq(n.fire_range_multiplier(), 1.0, "未蓄力 范围 ×1.0")
	for _i in range(10):
		n._on_damaged(1.0)
	assert_eq(n.fire_damage_multiplier(), 1.3, "蓄力 伤害 ×1.3 (+30%)")
	assert_eq(n.fire_range_multiplier(), 1.5, "蓄力 范围 ×1.5 (+50%)")


func test_consume_resets_fire_and_disarms() -> void:
	var n := _nezha()
	for _i in range(10):
		n._on_damaged(1.0)
	assert_true(n.is_fire_armed())
	n.consume_fire_boost()
	assert_false(n.is_fire_armed(), "消费后解除蓄力")
	assert_eq(n.current_lingqi, 0.0, "消费后真火清零")
	assert_eq(n.fire_damage_multiplier(), 1.0, "消费后倍率回 1.0")


func test_consume_when_not_armed_keeps_partial_charge() -> void:
	var n := _nezha()
	n._on_damaged(1.0)  # 10 真火，未蓄力
	n.consume_fire_boost()
	assert_eq(n.current_lingqi, 10.0, "未蓄力时消费不清零（no-op）")
