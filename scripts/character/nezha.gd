class_name Nezha
extends CharacterBase

## 哪吒（火劫童子）— v0.4 角色
##
## 设计来源：design/narrative/02_CHARACTER_DESIGN.md §4.3
##
## 专属能量「三昧真火」（Samadhi Fire）—— 风险收益机制：
##   - 上限 100；**受到伤害时 +10**（由 player.take_damage 转发 _on_damaged 充能）
##   - 满 100 后进入「蓄力」(armed)：**下一次**任意哪吒武器攻击触发增强
##   - 增强（单次）：全武器 **伤害 ×1.3（+30%）、范围 ×1.5（+50%）**，触发后真火清零
##   - 少挨打少爆发，多挨打多爆发
##
## 全自动开火角色（非主动技；遵守 ADR-0003：项目内仅孙悟空有主动技）。
## 哪吒武器（火尖枪 / 混天绫 / 乾坤圈）在攻击前查询 is_fire_armed()，若已蓄力则
## 套用 fire_damage_multiplier() / fire_range_multiplier()，并调用 consume_fire_boost()。
##
## 场景树：作为 PlayerNezha.tscn 的 "CharacterBase" 子节点挂载。
## 基础属性（HP 90 / 移速 220 / 拾取 55）由场景的 Inspector 导出值提供（同孙悟空模式），
## 本脚本只兜底身份标识与能量条配置，不在 _ready 写死数值，保持数据驱动可覆盖。

const SAMADHI_MAX: float = 100.0
const SAMADHI_PER_HIT: float = 10.0
const FIRE_DAMAGE_MULT: float = 1.3   # 蓄力下一击 +30% 伤害
const FIRE_RANGE_MULT: float = 1.5    # 蓄力下一击 +50% 范围

## 当前三昧真火。命名遵守 HUD 能量条契约（hud.gd 每帧读取 character_base 的 current_lingqi）。
var current_lingqi: float = 0.0

var _fire_armed: bool = false


func _ready() -> void:
	if character_id == "":
		character_id = "nezha"
	if display_name == "":
		display_name = "火劫童子"
	if element == "neutral":
		element = "fire"  # 哪吒五行属火（v0.5 元素系统启用后参与克制）
	if energy_bar_config.is_empty():
		energy_bar_config = {
			"max_value": SAMADHI_MAX,
			"label": "三昧真火",
			"auto_trigger": false,  # 不自动触发；留给下一次武器攻击消费
		}


## 玩家受伤回调（player.take_damage 转发）。
## 固定 +10 真火（与伤害数值无关）；满 100 即蓄力并通知 HUD。
## 已蓄力时冻结在 100、不再叠加、不重复 emit。
func _on_damaged(_amount: float) -> void:
	if _fire_armed:
		return
	current_lingqi = minf(current_lingqi + SAMADHI_PER_HIT, SAMADHI_MAX)
	if current_lingqi >= SAMADHI_MAX:
		_fire_armed = true
		energy_full_triggered.emit()


## 武器查询：是否已蓄力（下一击应增强）。
func is_fire_armed() -> bool:
	return _fire_armed


## 蓄力时的伤害倍率，否则 1.0。
func fire_damage_multiplier() -> float:
	return FIRE_DAMAGE_MULT if _fire_armed else 1.0


## 蓄力时的范围倍率，否则 1.0。
func fire_range_multiplier() -> float:
	return FIRE_RANGE_MULT if _fire_armed else 1.0


## 消费一次蓄力：清零真火、解除蓄力。武器在套用增强后调用。
## 未蓄力时为 no-op（不会误清当前积累的真火）。
func consume_fire_boost() -> void:
	if not _fire_armed:
		return
	_fire_armed = false
	current_lingqi = 0.0


## 哪吒专属升级 ID（pool 过滤用）。weapons/upgrades 随后续切片接入；
## 现在返回完整清单即可把哪吒限制为「通用升级 + 哪吒升级」，不会误带修行者武器升级。
func _get_allowed_upgrade_ids() -> Array[String]:
	return [
		"nezha_fire_spear_damage",
		"nezha_fire_spear_cooldown",
		"nezha_celestial_silk_damage",
		"nezha_celestial_silk_duration",
		"nezha_qiankun_disc_damage",
		"nezha_qiankun_disc_count",
		"nezha_samadhi_charge",
	]
