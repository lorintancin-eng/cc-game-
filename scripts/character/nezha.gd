class_name Nezha
extends CharacterBase

## 哪吒（火劫童子）— v0.4 角色 ·「莲花化身 · 三头六臂」重设计版
##
## 设计：design/quick-specs/nezha-skill-redesign.md
##
## 爽感引擎 = 蓄力 → 爆发循环：
##   三昧真火（充能槽）：**击杀 +5 / 受击 +8** → 满 100 自动进入【法相天地】6 秒：
##     · 全武器射速 ×2.5（冷却 ×0.4）、伤害 ×1.5
##     · 火尖枪三枪齐射（见 FireSpearWeapon）
##     · 自身减伤 30%（鼓励猛攻、爆发即生存窗口）
##   法相结束 → 【莲花真火爆】范围 nova（击杀越多炸越狠）→ 清零重新蓄力。
##
## 全自动开火（非主动技；ADR-0003：仅孙悟空有主动技）。法相是自动循环，不需玩家按键。
## 仅调用 enemy 公共 API（take_damage / 组），不碰冻结的 enemy.gd。

const SAMADHI_MAX: float = 100.0
const CHARGE_PER_KILL: float = 5.0
const CHARGE_PER_HIT: float = 8.0

const AVATAR_DURATION: float = 6.0
const AVATAR_COOLDOWN_MULT: float = 0.4   # 冷却 ×0.4 → 射速 ×2.5
const AVATAR_DAMAGE_MULT: float = 1.5
const AVATAR_DAMAGE_REDUCTION: float = 0.7  # 受到伤害 ×0.7（减伤 30%）

const NOVA_BASE_DAMAGE: float = 80.0
const NOVA_DAMAGE_PER_KILL: float = 8.0
const NOVA_RADIUS: float = 160.0

## HUD 能量条读此字段：蓄力期 = 当前真火；法相期 = 剩余时长占比 ×100（条会回落）。
var current_lingqi: float = 0.0

## 升级钩子（R5 接入；默认无加成）。
var charge_rate_mult: float = 1.0        # 「真火不灭」充能加速
var avatar_duration_bonus: float = 0.0   # 「法相延绵」
var nova_damage_mult: float = 1.0        # 「怒火焚天」

var _avatar_active: bool = false
var _avatar_ready: bool = false   # 三昧真火满、待玩家主动释放
var _avatar_remaining: float = 0.0
var _avatar_kills: int = 0


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
			"auto_trigger": false,  # 满槽后待玩家主动释放（按 1）
		}


func _physics_process(delta: float) -> void:
	if not _avatar_active:
		return
	_avatar_remaining -= delta
	current_lingqi = SAMADHI_MAX * clampf(_avatar_remaining / _avatar_total_duration(), 0.0, 1.0)
	if _avatar_remaining <= 0.0:
		_end_avatar()


# ─────────────────────────────────────────────
# 充能（击杀 / 受击 回调，已由 player + spawner 转发）
# ─────────────────────────────────────────────

func _on_kill(_enemy: Node) -> void:
	if _avatar_active:
		_avatar_kills += 1
		return
	_add_charge(CHARGE_PER_KILL)


func _on_damaged(_amount: float) -> void:
	if _avatar_active:
		return
	_add_charge(CHARGE_PER_HIT)


func _add_charge(amount: float) -> void:
	current_lingqi = minf(current_lingqi + amount * charge_rate_mult, SAMADHI_MAX)
	if current_lingqi >= SAMADHI_MAX and not _avatar_ready:
		_avatar_ready = true
		energy_full_triggered.emit()  # HUD 提示：三昧真火满，可主动释放法相（按 1）


# ─────────────────────────────────────────────
# 法相天地
# ─────────────────────────────────────────────

func _start_avatar() -> void:
	_avatar_active = true
	_avatar_ready = false
	_avatar_remaining = _avatar_total_duration()
	_avatar_kills = 0
	current_lingqi = SAMADHI_MAX


func _end_avatar() -> void:
	_fire_lotus_nova()
	_avatar_active = false
	_avatar_remaining = 0.0
	current_lingqi = 0.0


func _avatar_total_duration() -> float:
	return AVATAR_DURATION + avatar_duration_bonus


## 莲花真火爆：以玩家位置为心、半径 NOVA_RADIUS 的范围爆发。
## 伤害 = (80 + 8×法相击杀数) × nova_damage_mult。仅调 enemy.take_damage。
func _fire_lotus_nova() -> void:
	var origin := _origin_position()
	var damage := (NOVA_BASE_DAMAGE + NOVA_DAMAGE_PER_KILL * float(_avatar_kills)) * nova_damage_mult
	var radius_squared := NOVA_RADIUS * NOVA_RADIUS
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		if enemy_node.is_queued_for_deletion():
			continue
		if origin.distance_squared_to(enemy_node.global_position) > radius_squared:
			continue
		if enemy_node.has_method("take_damage"):
			enemy_node.call("take_damage", damage)


## 哪吒挂在 Player（Node2D）下，nova 以 Player 位置为心。
func _origin_position() -> Vector2:
	var parent := get_parent()
	if parent is Node2D:
		return (parent as Node2D).global_position
	return Vector2.ZERO


# ─────────────────────────────────────────────
# 武器 / player 查询接口
# ─────────────────────────────────────────────

func is_avatar_active() -> bool:
	return _avatar_active


## 三昧真火是否已满、待主动释放（HUD 提示 + player 输入用）。
func is_avatar_ready() -> bool:
	return _avatar_ready


## 玩家主动释放法相天地（按 1 触发）。满槽且未在法相中才成功，返回是否成功释放。
func try_activate_avatar() -> bool:
	if not _avatar_ready or _avatar_active:
		return false
	_start_avatar()
	return true


func avatar_damage_mult() -> float:
	return AVATAR_DAMAGE_MULT


func avatar_cooldown_mult() -> float:
	return AVATAR_COOLDOWN_MULT


## player.take_damage 查询：法相期减伤 30%，否则不减。
func get_incoming_damage_mult() -> float:
	return AVATAR_DAMAGE_REDUCTION if _avatar_active else 1.0


## 测试 / 外部只读：本次法相已击杀数。
func avatar_kills() -> int:
	return _avatar_kills


func _get_allowed_upgrade_ids() -> Array[String]:
	return [
		"nezha_fire_spear_damage",
		"nezha_fire_spear_cooldown",
		"nezha_unlock_qiankun",
		"nezha_qiankun_disc_damage",
		"nezha_unlock_silk",
		"nezha_celestial_silk_damage",
	]
