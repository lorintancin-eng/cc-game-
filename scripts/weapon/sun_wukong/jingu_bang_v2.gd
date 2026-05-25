class_name JinguBangV2
extends WeaponBase

## 如意金箍棒 v2（孙悟空主武器）
##
## 真"无 cd"主武器：每帧检测前方扇形范围，对敌人造成伤害。
## 防多重命中：同一敌人 0.25s 内不重复受伤（W212-D 攻击频率翻倍）。
## 等级 1-4 线性成长（详见 docs/SUN_WUKONG_V2_DESIGN.md §3）：
##   Lv1: 扇形 120° / 半径 90 / damage 10
##   Lv2: 扇形 180° / 半径 110 / damage 15
##   Lv3: 同 Lv2 + 每 3s 重棍砸地（半径 150 / dmg 40 / 击退 80）
##   Lv4: 进化定海重棍（重棍半径 180 / dmg 50 + 2s 地裂 dps 8/0.3s）
##
## 不挂任何场景。W212 SunWukong v2 场景建好后接入。

@export var level: int = 1: set = _apply_level
@export var rehit_cooldown: float = 0.25
@export var smash_interval: float = 3.0
@export var character_owner: String = "sun_wukong"
@export var element: String = "metal"

# 等级派生参数（_apply_level 设置）
var _arc_deg: float = 120.0
var _radius: float = 90.0
var _smash_enabled: bool = false
var _smash_radius: float = 150.0
var _smash_damage: float = 40.0
var _smash_knockback: float = 80.0
var _fissure_enabled: bool = false

# W213 升级 bonus（与 _apply_level base 值叠加）
var damage_bonus: float = 0.0
var radius_bonus: float = 0.0
var arc_bonus: float = 0.0

# 命中冷却字典 {Enemy: 剩余 cooldown s}
var _hit_cooldowns: Dictionary = {}

# 重棍计时
var _smash_timer: float = 0.0


func _ready() -> void:
	# 设默认 damage 为 10（Lv1）
	if damage <= 0.0:
		damage = 10.0
	_apply_level(level)


# 完全 override（不调用 super._process，因为 WeaponBase 有冷却门控会阻断每帧检测）
func _process(delta: float) -> void:
	# 推进命中 cooldown
	_tick_hit_cooldowns(delta)
	# 每帧扇形检测
	_check_fan_hits()
	# Lv3+ 重棍计时
	if _smash_enabled:
		_smash_timer += delta
		if _smash_timer >= smash_interval:
			_smash_timer = 0.0
			_trigger_smash()
	# 每帧重绘扇形视觉
	queue_redraw()


func _draw() -> void:
	var facing := _get_facing()
	if facing == Vector2.ZERO:
		facing = Vector2.RIGHT
	var base_angle := facing.angle()
	var half_arc := deg_to_rad((_arc_deg + arc_bonus) * 0.5)
	var color := Color(1.0, 0.78, 0.2, 0.18)
	var segments := 16
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)  # 圆心
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var ang := base_angle - half_arc + (half_arc * 2.0) * t
		points.append(Vector2.RIGHT.rotated(ang) * (_radius + radius_bonus))
	draw_colored_polygon(points, color)


func _apply_level(lv: int) -> void:
	level = clampi(lv, 1, 4)
	match level:
		1:
			_arc_deg = 120.0
			_radius = 90.0
			damage = 10.0
			_smash_enabled = false
			_fissure_enabled = false
		2:
			_arc_deg = 180.0
			_radius = 110.0
			damage = 15.0
			_smash_enabled = false
			_fissure_enabled = false
		3:
			_arc_deg = 180.0
			_radius = 110.0
			damage = 15.0
			_smash_enabled = true
			_smash_radius = 150.0
			_smash_damage = 40.0
			_fissure_enabled = false
		4:
			_arc_deg = 180.0
			_radius = 110.0
			damage = 15.0
			_smash_enabled = true
			_smash_radius = 180.0
			_smash_damage = 50.0
			_fissure_enabled = true


# 获取玩家 facing（owner 是 Player 节点）
func _get_facing() -> Vector2:
	if owner == null:
		return Vector2.RIGHT
	if "facing" in owner:
		return owner.facing
	return Vector2.RIGHT


# 查询火眼金睛伤害修正（W206）
# owner 是 Player 节点，通过 _character_base 找到 ActiveSkillCharacter 实例
func _get_fire_eyes_modifier(target: Node) -> float:
	if owner == null:
		return 1.0
	if not "_character_base" in owner:
		return 1.0
	var cb = owner._character_base
	if cb == null:
		return 1.0
	if not cb.has_method("get_damage_modifier"):
		return 1.0
	return cb.get_damage_modifier(target)


func _check_fan_hits() -> void:
	var facing := _get_facing()
	var half_arc_cos := cos(deg_to_rad((_arc_deg + arc_bonus) * 0.5))
	var radius_sq := (_radius + radius_bonus) * (_radius + radius_bonus)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if not enemy is Node2D:
			continue
		if _hit_cooldowns.has(enemy):
			continue
		var enemy_node := enemy as Node2D
		var to_enemy: Vector2 = enemy_node.global_position - global_position
		if to_enemy.length_squared() > radius_sq:
			continue
		var dir_to_enemy := to_enemy.normalized()
		if dir_to_enemy.dot(facing) < half_arc_cos:
			continue
		# 命中
		if enemy_node.has_method("take_damage"):
			enemy_node.take_damage((_get_damage() + damage_bonus) * _get_fire_eyes_modifier(enemy_node))
		_hit_cooldowns[enemy_node] = rehit_cooldown


func _tick_hit_cooldowns(delta: float) -> void:
	var to_remove: Array = []
	for enemy in _hit_cooldowns.keys():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			to_remove.append(enemy)
			continue
		_hit_cooldowns[enemy] -= delta
		if _hit_cooldowns[enemy] <= 0.0:
			to_remove.append(enemy)
	for key in to_remove:
		_hit_cooldowns.erase(key)


func _trigger_smash() -> void:
	var smash_radius_sq := _smash_radius * _smash_radius
	# 对范围内敌人造成 _smash_damage + 击退
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		var to_enemy: Vector2 = enemy_node.global_position - global_position
		if to_enemy.length_squared() > smash_radius_sq:
			continue
		# 伤害
		if enemy_node.has_method("take_damage"):
			enemy_node.take_damage(_smash_damage * _get_fire_eyes_modifier(enemy_node))
		# 击退（直接位移）
		if to_enemy.length() > 0.001:
			enemy_node.global_position += to_enemy.normalized() * _smash_knockback
	# Lv4 地裂
	if _fissure_enabled:
		_spawn_fissure()


func _spawn_fissure() -> void:
	# 在玩家位置 spawn 一个 2s 地裂区域，每 0.3s 对范围内敌人造成 8 伤害
	var fissure := Node2D.new()
	fissure.name = "JinguFissure"
	fissure.global_position = global_position
	var scene := get_tree().current_scene
	if scene == null:
		fissure.queue_free()
		return
	scene.add_child(fissure)
	# 用 tween 管理淡出视觉
	var tween := fissure.create_tween()
	tween.tween_property(fissure, "modulate:a", 0.3, 2.0)
	# 每 0.3s 触发一次伤害
	var duration := 2.0
	var tick_interval := 0.3
	var fissure_damage := 8.0
	var fissure_radius := _smash_radius
	var tick_count := int(duration / tick_interval)
	for i in range(tick_count):
		var delay := tick_interval * i
		var tick_tween := fissure.create_tween()
		tick_tween.tween_interval(delay)
		tick_tween.tween_callback(func():
			if not is_instance_valid(fissure):
				return
			var fr_sq := fissure_radius * fissure_radius
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
					continue
				if not enemy is Node2D:
					continue
				var e := enemy as Node2D
				if e.global_position.distance_squared_to(fissure.global_position) > fr_sq:
					continue
				if e.has_method("take_damage"):
					e.take_damage(fissure_damage * _get_fire_eyes_modifier(e))
		)
	# 2s 后销毁
	get_tree().create_timer(duration).timeout.connect(fissure.queue_free)
