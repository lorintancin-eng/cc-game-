class_name SunWukongV2
extends ActiveSkillCharacter

## SunWukongV2 — 齐天大圣 v0.4 重做版
##
## 项目内**唯一**主动技能角色（详见 ADR-0003）
##   - 主武器：金箍棒（自动扇形攻击，挂在 PlayerSunWukong.tscn 的 JinguBangV2 节点）
##   - 4 主动技能（按 1/2/3/4 释放，开局未解锁，靠 Lv5/10/15/20 选择）：
##     · 槽 0 毫毛分身 (cd 12s)
##     · 槽 1 筋斗云   (cd 8s)
##     · 槽 2 七十二变 (cd 25s)
##     · 槽 3 定身术   (cd 15s)
##   - 被动：火眼金睛（对精英/Boss +20% 伤害，由 get_damage_modifier 实现）
##
## 场景树：作为 PlayerSunWukong.tscn 的 CharacterBase 节点挂载
## 4 技能节点是 Player 的兄弟节点，通过 ../节点名 引用


# ─────────────────────────────────────────────
# 技能节点引用（兄弟节点，用 get_node_or_null 防御单测加载场景）
# ─────────────────────────────────────────────

@onready var _hair_clone: Node2D = get_node_or_null("../HairCloneV2")
@onready var _cloud_step: Node2D = get_node_or_null("../CloudStep")
@onready var _transform: Node2D = get_node_or_null("../Transform72")
@onready var _immobilize: Node2D = get_node_or_null("../Immobilize")

# W213: 火眼金睛升级累积层数（上限 7，每层 +5%，从 +20% 累积到 +55%）
var _fire_eyes_bonus_stacks: int = 0
const FIRE_EYES_BASE_MULTIPLIER: float = 1.2  # 基础 +20%
const FIRE_EYES_STACK_BONUS: float = 0.05      # 每层 +5%
const FIRE_EYES_MAX_STACKS: int = 7            # 上限 7 层（共 +35%）


# ─────────────────────────────────────────────
# 生命周期
# ─────────────────────────────────────────────

func _ready() -> void:
	# 设置角色标识（Inspector 中若有覆盖值，则以 Inspector 为准）
	if character_id == "":
		character_id = "sun_wukong"
	if display_name == "":
		display_name = "齐天大圣"

	# 注册 4 个主动技能槽（initial_unlock=false，开局全部锁定，靠升级解锁）
	_register_skill(0, "毫毛分身", 12.0, false)
	_register_skill(1, "筋斗云", 8.0, false)
	_register_skill(2, "七十二变", 25.0, false)
	_register_skill(3, "定身术", 15.0, false)


# ─────────────────────────────────────────────
# 主动技能分发（override）
# ─────────────────────────────────────────────

## 玩家按下 1/2/3/4 后由 cast_skill() 调用。
## 返回 true 表示成功释放，基类随即启动 cooldown；false 不消耗 cooldown。
func _on_cast_skill(slot: int) -> bool:
	var player_node: Node = get_parent()
	if player_node == null:
		push_warning("SunWukongV2._on_cast_skill: no parent player node")
		return false

	match slot:
		0:
			if _hair_clone == null:
				push_warning("SunWukongV2._on_cast_skill: HairCloneV2 node not found")
				return false
			return _hair_clone.cast(player_node)
		1:
			if _cloud_step == null:
				push_warning("SunWukongV2._on_cast_skill: CloudStep node not found")
				return false
			return _cloud_step.cast(player_node)
		2:
			if _transform == null:
				push_warning("SunWukongV2._on_cast_skill: Transform72 node not found")
				return false
			return _transform.cast(player_node)
		3:
			if _immobilize == null:
				push_warning("SunWukongV2._on_cast_skill: Immobilize node not found")
				return false
			return _immobilize.cast(player_node)
		_:
			return false


# ─────────────────────────────────────────────
# 火眼金睛被动（override）
# ─────────────────────────────────────────────

## 对精英怪或 Boss 返回带 W213 累积加成的倍率，其余返回 1.0。
## 由武器脚本（如 JinguBangV2）在造成伤害前查询，防御性检查 target 合法性。
func get_damage_modifier(target: Node) -> float:
	if target == null:
		return 1.0
	var is_high_value := false
	if target.is_in_group("bosses"):
		is_high_value = true
	elif target.get("is_elite") == true:
		is_high_value = true
	if not is_high_value:
		return 1.0
	return FIRE_EYES_BASE_MULTIPLIER + _fire_eyes_bonus_stacks * FIRE_EYES_STACK_BONUS


## W213: 火眼金睛 +5% 升级（达到上限自动 clamp）
## 返回 true 表示成功增加，false 表示已达上限
func add_fire_eyes_bonus() -> bool:
	if _fire_eyes_bonus_stacks >= FIRE_EYES_MAX_STACKS:
		return false
	_fire_eyes_bonus_stacks += 1
	return true


## W213: 查询是否已达上限（供 player.gd 池子过滤）
func is_fire_eyes_maxed() -> bool:
	return _fire_eyes_bonus_stacks >= FIRE_EYES_MAX_STACKS


# ─────────────────────────────────────────────
# 技能升级同步（override）
# ─────────────────────────────────────────────

## 先调 super 更新 _skill_levels / _skill_unlocked，
## 再把新等级同步到对应技能节点的 .level 字段。
## 技能节点各自的 level setter（_apply_level）会重新应用配置参数。
func apply_skill_upgrade(id: String) -> void:
	super.apply_skill_upgrade(id)

	# 仅处理孙悟空主动技能升级 id
	if not (id.begins_with("wukong_skill_unlock_") or id.begins_with("wukong_skill_upgrade_")):
		return

	# 解析槽位 suffix（"wukong_skill_unlock_N" 或 "wukong_skill_upgrade_N"）
	var suffix: String = ""
	if id.begins_with("wukong_skill_unlock_"):
		suffix = id.substr("wukong_skill_unlock_".length())
	else:
		suffix = id.substr("wukong_skill_upgrade_".length())

	if not suffix.is_valid_int():
		return

	var slot: int = int(suffix)
	if slot < 0 or slot > 3:
		return

	var new_level: int = get_skill_level(slot)

	# 找到对应技能节点并同步 level
	var target_node: Node2D = null
	match slot:
		0:
			target_node = _hair_clone
		1:
			target_node = _cloud_step
		2:
			target_node = _transform
		3:
			target_node = _immobilize

	if target_node != null and "level" in target_node:
		target_node.level = new_level


# ─────────────────────────────────────────────
# 升级池过滤（override）
# ─────────────────────────────────────────────

## W213: 返回孙悟空全部专属升级 ID（pool 层会按解锁状态动态过滤）
## player.gd 自动包含 common_ids = [max_hp, move_speed, pickup_radius, xp_gain]
## 此处额外列出所有孙悟空专属 ID，player.gd 的池子过滤逻辑将决定哪些实际出现。
func _get_allowed_upgrade_ids() -> Array[String]:
	return [
		"wukong_jingu_bang_damage",
		"wukong_jingu_bang_range",
		"wukong_jingu_bang_arc",
		"wukong_fire_eyes_bonus",
		"wukong_hair_clone_count",
		"wukong_hair_clone_duration",
		"wukong_hair_clone_damage",
		"wukong_cloud_step_range",
		"wukong_cloud_step_cooldown",
		"wukong_cloud_step_damage",
		"wukong_transform_duration",
		"wukong_transform_cooldown",
		"wukong_transform_form_boost",
		"wukong_immobilize_range",
		"wukong_immobilize_duration",
		"wukong_immobilize_burst_damage",
	]
