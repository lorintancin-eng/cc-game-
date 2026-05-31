## 道具掉落纯逻辑（PickupDrops）：掉率 / 触发 / 随机种类(低血加权) / 回血量。
## 设计：design/quick-specs/pickup-items.md
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/system -gexit

extends "res://tests/helpers/test_base.gd"


func test_drop_chance_elite_and_boss_always_drop() -> void:
	assert_eq(PickupDrops.drop_chance(true, false, 0.04), 1.0, "精英必掉")
	assert_eq(PickupDrops.drop_chance(false, true, 0.04), 1.0, "Boss 必掉")


func test_drop_chance_normal_uses_normal_chance() -> void:
	assert_float_eq(PickupDrops.drop_chance(false, false, 0.04), 0.04, 0.0001, "普通敌用 normal_chance")
	assert_eq(PickupDrops.drop_chance(false, false, 2.0), 1.0, "概率夹到 1.0")


func test_should_drop_threshold() -> void:
	assert_true(PickupDrops.should_drop(0.04, 0.01), "roll<chance → 掉")
	assert_false(PickupDrops.should_drop(0.04, 0.5), "roll>=chance → 不掉")


func test_pick_type_full_hp_is_uniform_by_roll() -> void:
	# 满血权重 [1,1,1,1]，total=4：roll 区间 [0,.25)=heal [.25,.5)=magnet [.5,.75)=purge [.75,1)=freeze
	assert_eq(PickupDrops.pick_type(1.0, 0.0), PickupDrops.TYPE_HEAL)
	assert_eq(PickupDrops.pick_type(1.0, 0.3), PickupDrops.TYPE_MAGNET)
	assert_eq(PickupDrops.pick_type(1.0, 0.6), PickupDrops.TYPE_PURGE)
	assert_eq(PickupDrops.pick_type(1.0, 0.9), PickupDrops.TYPE_FREEZE)


func test_pick_type_low_hp_weights_heal() -> void:
	# 低血权重 [2,1,1,1]，total=5：roll<0.4(target<2) 都给 heal
	assert_eq(PickupDrops.pick_type(0.2, 0.0), PickupDrops.TYPE_HEAL)
	assert_eq(PickupDrops.pick_type(0.2, 0.39), PickupDrops.TYPE_HEAL, "低血时灵丹覆盖更宽的 roll 区间")
	assert_eq(PickupDrops.pick_type(0.2, 0.5), PickupDrops.TYPE_MAGNET, "超出灵丹区间后才到下一个")


func test_heal_amount_is_fraction_of_max_hp() -> void:
	assert_float_eq(PickupDrops.heal_amount(100.0, 0.30), 30.0, 0.001)
	assert_float_eq(PickupDrops.heal_amount(90.0, 0.30), 27.0, 0.001)
