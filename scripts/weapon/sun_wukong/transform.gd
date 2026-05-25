class_name Transform72
extends Node2D

## 七十二变（孙悟空 v2 主动技能 3，按键 3）
##
## 随机变 5 种形态之一，持续 5-8s，形态有不同 buff。
## Lv4 进化"法天象地"固定巨猿 + 强化。
##
## 详细：docs/SUN_WUKONG_V2_DESIGN.md §6
##
## v0.4 MVP 简化：
## - 5 形态完整美术 / 特效（雷电链 / 残影 / 羽刃投射）→ v0.4.x 后续
## - 当前只实现"持续时间 + 数值 buff（移速/伤害）+ 形态 ID 记录"
## - 完整形态效果待 Enemy buff 系统 + 特效美术后补完

const FORM_GIANT_APE := "giant_ape"
const FORM_GOLDEN_EAGLE := "golden_eagle"
const FORM_STONE_MONKEY := "stone_monkey"
const FORM_DRAGON_SHADOW := "dragon_shadow"
const FORM_SPIRIT_FOX := "spirit_fox"

const ALL_FORMS: Array[String] = [
	FORM_GIANT_APE,
	FORM_GOLDEN_EAGLE,
	FORM_STONE_MONKEY,
	FORM_DRAGON_SHADOW,
	FORM_SPIRIT_FOX,
]

@export var level: int = 1: set = _apply_level

var _duration: float = 5.0
var _force_giant_ape: bool = false  # Lv4
var _enhanced_buffs: bool = false  # Lv3+

var _current_form: String = ""
var _player_ref: WeakRef = null

# W213 升级 bonus
var duration_bonus: float = 0.0
var form_boost_bonus: float = 0.0  # 形态 buff 倍率额外加成（如 +10%）


func _ready() -> void:
	_apply_level(level)


func _apply_level(lv: int) -> void:
	level = clampi(lv, 1, 4)
	match level:
		1:
			_duration = 5.0
			_force_giant_ape = false
			_enhanced_buffs = false
		2:
			_duration = 7.0
			_force_giant_ape = false
			_enhanced_buffs = false
		3:
			_duration = 7.0
			_force_giant_ape = false
			_enhanced_buffs = true
		4:
			_duration = 8.0
			_force_giant_ape = true
			_enhanced_buffs = true


# 公共接口：W212 SunWukong v2 的 _on_cast_skill(2) 调用
func cast(player_node: Node) -> bool:
	if player_node == null:
		return false
	# 选形态
	if _force_giant_ape:
		_current_form = FORM_GIANT_APE
	else:
		_current_form = ALL_FORMS[randi() % ALL_FORMS.size()]
	_player_ref = weakref(player_node)
	# 应用 buff
	_apply_form_buff(player_node, _current_form)
	# 持续时间结束后恢复（base + W213 bonus）
	get_tree().create_timer(_duration + duration_bonus).timeout.connect(_on_duration_end)
	return true


func get_current_form() -> String:
	return _current_form


func _apply_form_buff(player_node: Node, form: String) -> void:
	# 数值 buff（移速 / 伤害倍率），通过 player.set_*_multiplier 接入
	var speed_mult: float = 1.0
	var dmg_mult: float = 1.0
	match form:
		FORM_GIANT_APE:
			# 攻击范围 +30%（待 W212 接入金箍棒 range_modifier），击退 +50% TODO
			dmg_mult = 1.1  # Lv4 法天象地还应 +30% 移速
			if _force_giant_ape:
				speed_mult = 1.3
		FORM_GOLDEN_EAGLE:
			speed_mult = 1.5  # 移速 +50%
			# TODO: 羽刃投射特效
		FORM_STONE_MONKEY:
			# 护盾 +100, 受伤 -30% TODO（需 Player shield 系统）
			dmg_mult = 0.9  # 简化为：略降伤害以体现"防御"
		FORM_DRAGON_SHADOW:
			dmg_mult = 1.2  # 简化雷电链为统一伤害提升
			# TODO: 真正雷电链投射
		FORM_SPIRIT_FOX:
			speed_mult = 1.2  # 闪避 +30% 简化为移速 +20%
			# TODO: 迷惑残影
	# Lv3+ 增强基础 buff
	if _enhanced_buffs:
		speed_mult *= 1.1
		dmg_mult *= 1.1
	# W213: form_boost_bonus 额外乘到倍率上（+10% 即 form_boost_bonus = 0.1）
	if form_boost_bonus > 0.0:
		speed_mult *= (1.0 + form_boost_bonus)
		dmg_mult *= (1.0 + form_boost_bonus)
	if player_node.has_method("set_speed_multiplier"):
		player_node.set_speed_multiplier(speed_mult)
	if player_node.has_method("set_damage_multiplier"):
		player_node.set_damage_multiplier(dmg_mult)


func _on_duration_end() -> void:
	if _player_ref == null:
		return
	var player = _player_ref.get_ref()
	if player == null:
		return
	# 恢复 buff
	if player.has_method("set_speed_multiplier"):
		player.set_speed_multiplier(1.0)
	if player.has_method("set_damage_multiplier"):
		player.set_damage_multiplier(1.0)
	_current_form = ""
