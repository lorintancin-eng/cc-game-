class_name PickupDrops
extends RefCounted

## 道具掉落的纯逻辑（无副作用、可测）：掉率、随机种类（低血灵丹加权）、回血量。
## 设计：design/quick-specs/pickup-items.md。掷骰用注入的 roll∈[0,1)，保证测试确定性。

const TYPE_HEAL: String = "heal"
const TYPE_MAGNET: String = "xp_magnet"
const TYPE_PURGE: String = "purge"
const TYPE_FREEZE: String = "freeze"

const TYPES: Array[String] = [TYPE_HEAL, TYPE_MAGNET, TYPE_PURGE, TYPE_FREEZE]

const LOW_HP_FRACTION: float = 0.5   # 低于此血量比例时灵丹加权
const LOW_HP_HEAL_WEIGHT: float = 2.0


## 掉落概率：精英 / Boss 必掉（1.0），普通敌为 normal_chance。
static func drop_chance(is_elite: bool, is_boss: bool, normal_chance: float) -> float:
	if is_boss or is_elite:
		return 1.0
	return clampf(normal_chance, 0.0, 1.0)


## roll∈[0,1) 是否触发掉落。
static func should_drop(chance: float, roll: float) -> bool:
	return roll < chance


## 随机选道具种类。hp_fraction<0.5 时灵丹权重×2（低血更易掉回血，同 VS）。
## roll∈[0,1) 决定结果（加权随机）。
static func pick_type(hp_fraction: float, roll: float) -> String:
	var weights: Array[float] = [1.0, 1.0, 1.0, 1.0]  # heal / magnet / purge / freeze
	if hp_fraction < LOW_HP_FRACTION:
		weights[0] = LOW_HP_HEAL_WEIGHT

	var total: float = 0.0
	for w in weights:
		total += w

	var target: float = clampf(roll, 0.0, 0.999999) * total
	var accumulated: float = 0.0
	for i in range(TYPES.size()):
		accumulated += weights[i]
		if target < accumulated:
			return TYPES[i]
	return TYPES[TYPES.size() - 1]


## 灵丹回血量 = max_hp × fraction。
static func heal_amount(max_hp: float, fraction: float) -> float:
	return maxf(max_hp, 0.0) * clampf(fraction, 0.0, 1.0)
