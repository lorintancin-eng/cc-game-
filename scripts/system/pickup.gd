class_name Pickup
extends Area2D

## 镇妖四宝 — 地面一次性消耗道具。玩家走过去（存在式重叠）即触发对应效果后销毁。
## 设计：design/quick-specs/pickup-items.md。pickup_type 由 StageDirector 生成时设置。
##
## 生成后有 SPAWN_GRACE 短暂保护期（先让玩家看见、不立即被秒捡）+ 脉冲动画（显眼）+
## LIFETIME 寿命（不捡则消失）。效果（apply_effect 按类型分发，仅调公共 API，不碰冻结文件）：
##   灵丹   → player.heal(max_hp × HEAL_FRACTION)
##   聚灵符 → 吸取组 experience_orbs 的全部经验到玩家
##   镇妖雷符 → 组 enemies 全体 take_damage(PURGE_DAMAGE)
##   定身钟 → 生成 TimeStop（FREEZE_DURATION 秒全屏冻结）

const HEAL_FRACTION: float = 0.30
const PURGE_DAMAGE: float = 100.0
const FREEZE_DURATION: float = 3.0

const SPAWN_GRACE: float = 0.45   # 生成后这段时间内不可被捡（先让玩家看见）
const LIFETIME: float = 15.0      # 不捡则消失
const PULSE_SPEED: float = 6.0
const PULSE_AMPLITUDE: float = 0.14

const TIME_STOP_SCENE: PackedScene = preload("res://scenes/system/TimeStop.tscn")

const TYPE_COLORS: Dictionary = {
	"heal": Color(0.85, 0.2, 0.2),       # 朱砂红
	"xp_magnet": Color(0.3, 0.6, 0.9),   # 青蓝
	"purge": Color(0.72, 0.42, 0.92),    # 金紫
	"freeze": Color(0.72, 0.6, 0.32),    # 古铜
}

## 由 StageDirector 在生成后、加入树前设置。
var pickup_type: String = PickupDrops.TYPE_HEAL

var _collected: bool = false
var _grace_remaining: float = SPAWN_GRACE
var _elapsed: float = 0.0

@onready var _body: Polygon2D = get_node_or_null(^"Body")


func _ready() -> void:
	# 道具常在敌人死亡回调（可能处于物理查询刷新）中生成 → 延迟开启监听，避免报错。
	set_deferred(&"monitoring", true)
	if _body != null and TYPE_COLORS.has(pickup_type):
		_body.color = TYPE_COLORS[pickup_type]


func _physics_process(delta: float) -> void:
	if _collected:
		return
	_elapsed += delta

	# 脉冲动画（仅缩放视觉，不动判定半径），便于看见。
	if _body != null:
		_body.scale = Vector2.ONE * (1.0 + PULSE_AMPLITUDE * sin(_elapsed * PULSE_SPEED))

	# 生成保护期：先弹出可见，不立即被秒捡。
	if _grace_remaining > 0.0:
		_grace_remaining -= delta
		return

	# 寿命到则消失。
	if _elapsed >= LIFETIME:
		queue_free()
		return

	var player := _player_in_zone()
	if player == null:
		return
	_collected = true
	apply_effect(player)
	queue_free()


func _player_in_zone() -> Node2D:
	for body in get_overlapping_bodies():
		if body.is_in_group(&"player"):
			return body as Node2D
	return null


## 按类型施放效果。可测：直接传入 player（或 mock）驱动。
func apply_effect(player: Node) -> void:
	match pickup_type:
		PickupDrops.TYPE_HEAL:
			_apply_heal(player)
		PickupDrops.TYPE_MAGNET:
			_apply_magnet(player)
		PickupDrops.TYPE_PURGE:
			_apply_purge()
		PickupDrops.TYPE_FREEZE:
			_apply_freeze()


func _apply_heal(player: Node) -> void:
	if not player.has_method("heal"):
		return
	var max_hp: float = float(player.get("max_hp")) if "max_hp" in player else 0.0
	player.call("heal", PickupDrops.heal_amount(max_hp, HEAL_FRACTION))


func _apply_magnet(player: Node) -> void:
	if not player.has_method("gain_experience"):
		return
	for orb in get_tree().get_nodes_in_group(&"experience_orbs"):
		if not is_instance_valid(orb):
			continue
		var xp: float = float(orb.get("xp_value")) if "xp_value" in orb else 0.0
		player.call("gain_experience", xp)
		orb.queue_free()


func _apply_purge() -> void:
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", PURGE_DAMAGE)


func _apply_freeze() -> void:
	if TIME_STOP_SCENE == null:
		return
	var instance := TIME_STOP_SCENE.instantiate()
	var time_stop := instance as TimeStop
	if time_stop == null:
		instance.queue_free()
		return
	var parent := get_parent()
	if parent == null:
		time_stop.queue_free()
		return
	parent.add_child(time_stop)
	time_stop.setup(FREEZE_DURATION)
