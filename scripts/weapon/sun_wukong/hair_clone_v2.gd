class_name HairCloneV2
extends Node2D

## 毫毛分身技能控制器（孙悟空 v2 主动技能 1）
##
## 按键 1 触发 → 召唤 N 只毫毛分身（按等级，2/3/3/3）
## cooldown 12s（由 ActiveSkillCharacter 管理）
##
## 4 级成长见 docs/SUN_WUKONG_V2_DESIGN.md §4

const HAIR_CLONE_UNIT := preload("res://scripts/weapon/sun_wukong/hair_clone_unit.gd")

@export var level: int = 1: set = _apply_level

# 等级派生参数
var _clone_count: int = 2
var _clone_lifetime: float = 6.0
var _clone_damage: float = 8.0
var _clone_interval: float = 1.5
var _sweep_enabled: bool = false
var _burst_enabled: bool = false

# W213 升级 bonus
var count_bonus: int = 0
var lifetime_bonus: float = 0.0
var damage_bonus: float = 0.0


func _ready() -> void:
	_apply_level(level)


func _apply_level(lv: int) -> void:
	level = clampi(lv, 1, 4)
	match level:
		1:
			_clone_count = 2
			_clone_lifetime = 6.0
			_clone_damage = 8.0
			_clone_interval = 1.5
			_sweep_enabled = false
			_burst_enabled = false
		2:
			_clone_count = 3
			_clone_lifetime = 8.0
			_clone_damage = 8.0
			_clone_interval = 1.5
			_sweep_enabled = false
			_burst_enabled = false
		3:
			_clone_count = 3
			_clone_lifetime = 8.0
			_clone_damage = 8.0
			_clone_interval = 1.5
			_sweep_enabled = true
			_burst_enabled = false
		4:
			_clone_count = 3
			_clone_lifetime = 8.0
			_clone_damage = 8.0
			_clone_interval = 1.5
			_sweep_enabled = true
			_burst_enabled = true


# 公共接口：W212 时 SunWukong v2 的 _on_cast_skill(0) 调用此方法
# 返回 true 表示成功召唤
func cast(player_node: Node) -> bool:
	if player_node == null:
		return false
	if not player_node is Node2D:
		return false
	var player_pos: Vector2 = (player_node as Node2D).global_position
	var scene := get_tree().current_scene
	if scene == null:
		push_warning("HairCloneV2.cast: current_scene is null")
		return false
	# 召唤 N 只分身（base + bonus）
	var count := _clone_count + count_bonus
	for i in range(count):
		var clone := HairCloneUnit.new()
		# 配置等级参数（含 W213 bonus）
		clone.damage = _clone_damage + damage_bonus
		clone.attack_interval = _clone_interval
		clone.lifetime = _clone_lifetime + lifetime_bonus
		clone.sweep_enabled = _sweep_enabled
		clone.burst_enabled = _burst_enabled
		# 设置 player_owner 以便 clone 查询 Sun Wukong 的火眼金睛修正
		clone.player_owner = player_node
		# 随机散布位置（玩家周围 ±32px）
		var angle: float = TAU * float(i) / float(count) + randf_range(-0.3, 0.3)
		var offset := Vector2.RIGHT.rotated(angle) * 32.0
		clone.global_position = player_pos + offset
		scene.add_child(clone)
	return true
