class_name FamineBeastBoss
extends Enemy

enum BossState {
	CHASE,
	CHARGE_WINDUP,
	CHARGE,
	CHARGE_RECOVERY,
}

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy/Enemy.tscn")
const PAPER_DOLL_ARCHETYPE: Resource = preload("res://resources/enemies/paper_doll.tres")
const WANDERING_SOUL_ARCHETYPE: Resource = preload("res://resources/enemies/wandering_soul.tres")

@export var charge_cooldown: float = 4.8
@export var charge_windup_time: float = 0.7
@export var charge_duration: float = 0.55
@export var charge_recovery_time: float = 0.35
@export var charge_speed: float = 390.0
@export var charge_warning_length: float = 240.0
@export var burst_cooldown: float = 5.8
@export var burst_warning_time: float = 1.05
@export var burst_radius: float = 58.0
@export var burst_damage: float = 18.0
@export var burst_linger_time: float = 0.18
@export var summon_cooldown: float = 7.0
@export var summon_batch_count: int = 2
@export var summon_max_alive: int = 6
@export var summon_spawn_radius: float = 86.0
@export var enrage_health_ratio: float = 0.3
@export var enrage_speed_multiplier: float = 1.35
@export var enrage_skill_interval_multiplier: float = 0.65

var _state: int = BossState.CHASE
var _state_timer: float = 0.0
var _charge_timer: float = 0.0
var _burst_timer: float = 0.0
var _summon_timer: float = 0.0
var _charge_direction: Vector2 = Vector2.RIGHT
var _is_enraged: bool = false
var _burst_markers: Array[Dictionary] = []
var _summoned_enemies: Array[Enemy] = []

@onready var _charge_telegraph: Line2D = $ChargeTelegraph
@onready var _enraged_aura: Polygon2D = $EnragedAura


func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	xp_drop_value = 0.0
	charge_cooldown = maxf(charge_cooldown, 0.1)
	charge_windup_time = maxf(charge_windup_time, 0.05)
	charge_duration = maxf(charge_duration, 0.05)
	charge_recovery_time = maxf(charge_recovery_time, 0.0)
	charge_speed = maxf(charge_speed, 0.0)
	charge_warning_length = maxf(charge_warning_length, 8.0)
	burst_cooldown = maxf(burst_cooldown, 0.1)
	burst_warning_time = maxf(burst_warning_time, 0.05)
	burst_radius = maxf(burst_radius, 4.0)
	burst_damage = maxf(burst_damage, 0.0)
	burst_linger_time = maxf(burst_linger_time, 0.05)
	summon_cooldown = maxf(summon_cooldown, 0.1)
	summon_batch_count = maxi(summon_batch_count, 0)
	summon_max_alive = maxi(summon_max_alive, 0)
	summon_spawn_radius = maxf(summon_spawn_radius, 8.0)
	enrage_health_ratio = clampf(enrage_health_ratio, 0.01, 0.99)
	enrage_speed_multiplier = maxf(enrage_speed_multiplier, 0.1)
	enrage_skill_interval_multiplier = clampf(enrage_skill_interval_multiplier, 0.1, 1.0)

	_charge_timer = 1.4
	_burst_timer = 3.0
	_summon_timer = 4.2
	_charge_telegraph.visible = false
	_enraged_aura.visible = false
	_enraged_aura.polygon = _make_circle_polygon(34.0, 24)


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		return

	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)
	_process_burst_markers(delta)
	_process_summon_timer(delta)

	if not is_instance_valid(_player):
		_find_player()

	if _player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	match _state:
		BossState.CHASE:
			_process_chase(delta)
		BossState.CHARGE_WINDUP:
			_process_charge_windup(delta)
		BossState.CHARGE:
			_process_charge(delta)
		BossState.CHARGE_RECOVERY:
			_process_charge_recovery(delta)

	_try_damage_player()


func take_damage(amount: float) -> void:
	super.take_damage(amount)
	if _is_dead or _is_enraged:
		return
	if current_hp / max_hp <= enrage_health_ratio:
		_enter_enrage()


func _die() -> void:
	_clear_boss_effects()
	super._die()


func _process_chase(delta: float) -> void:
	_movement_time += delta
	_charge_timer -= delta
	_burst_timer -= delta

	if _charge_timer <= 0.0:
		_start_charge_windup()
		return

	if _burst_timer <= 0.0:
		_start_burst_marker()
		_burst_timer = burst_cooldown * _get_skill_interval_multiplier()

	velocity = _get_move_direction(_player.global_position) * move_speed
	move_and_slide()


func _process_charge_windup(delta: float) -> void:
	_update_charge_direction()
	_state_timer -= delta
	velocity = Vector2.ZERO
	move_and_slide()
	if _state_timer <= 0.0:
		_start_charge()


func _process_charge(delta: float) -> void:
	_state_timer -= delta
	velocity = _charge_direction * charge_speed
	move_and_slide()
	if _state_timer <= 0.0:
		_start_charge_recovery()


func _process_charge_recovery(delta: float) -> void:
	_state_timer -= delta
	velocity = Vector2.ZERO
	move_and_slide()
	if _state_timer <= 0.0:
		_state = BossState.CHASE


func _start_charge_windup() -> void:
	_state = BossState.CHARGE_WINDUP
	_state_timer = charge_windup_time
	_charge_timer = charge_cooldown * _get_skill_interval_multiplier()
	_update_charge_direction()
	_charge_telegraph.visible = true


func _start_charge() -> void:
	_state = BossState.CHARGE
	_state_timer = charge_duration
	_charge_telegraph.visible = false


func _start_charge_recovery() -> void:
	_state = BossState.CHARGE_RECOVERY
	_state_timer = charge_recovery_time
	velocity = Vector2.ZERO


func _update_charge_direction() -> void:
	if is_instance_valid(_player):
		var direction := global_position.direction_to(_player.global_position)
		if direction != Vector2.ZERO:
			_charge_direction = direction

	_charge_telegraph.points = PackedVector2Array([
		Vector2.ZERO,
		_charge_direction * charge_warning_length,
	])


func _start_burst_marker() -> void:
	var target_position := global_position
	if is_instance_valid(_player):
		target_position = _player.global_position

	var marker := _create_burst_marker(target_position)
	_burst_markers.append({
		"node": marker,
		"timer": burst_warning_time,
		"state": 0,
	})


func _create_burst_marker(target_position: Vector2) -> Node2D:
	var marker := Node2D.new()
	marker.name = "FamineBurstMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = target_position

	var warning := Polygon2D.new()
	warning.name = "Warning"
	warning.color = Color(0.85, 0.08, 0.04, 0.32)
	warning.polygon = _make_circle_polygon(burst_radius, 32)
	marker.add_child(warning)

	var explosion := Polygon2D.new()
	explosion.name = "Explosion"
	explosion.visible = false
	explosion.color = Color(1.0, 0.36, 0.06, 0.58)
	explosion.polygon = _make_circle_polygon(burst_radius * 1.08, 32)
	marker.add_child(explosion)

	return marker


func _process_burst_markers(delta: float) -> void:
	var index := _burst_markers.size() - 1
	while index >= 0:
		var burst := _burst_markers[index]
		var marker := burst["node"] as Node2D
		if not is_instance_valid(marker):
			_burst_markers.remove_at(index)
			index -= 1
			continue

		burst["timer"] = float(burst["timer"]) - delta
		if int(burst["state"]) == 0 and float(burst["timer"]) <= 0.0:
			_detonate_burst(marker)
			burst["state"] = 1
			burst["timer"] = burst_linger_time
		elif int(burst["state"]) == 1 and float(burst["timer"]) <= 0.0:
			marker.queue_free()
			_burst_markers.remove_at(index)

		index -= 1


func _detonate_burst(marker: Node2D) -> void:
	var warning := marker.get_node_or_null("Warning") as Polygon2D
	if warning != null:
		warning.visible = false

	var explosion := marker.get_node_or_null("Explosion") as Polygon2D
	if explosion != null:
		explosion.visible = true

	if is_instance_valid(_player) and _player.has_method("take_damage"):
		if _player.global_position.distance_to(marker.global_position) <= burst_radius:
			_player.call("take_damage", burst_damage)


func _process_summon_timer(delta: float) -> void:
	_clean_summoned_enemies()
	if summon_batch_count <= 0 or summon_max_alive <= 0:
		return

	_summon_timer -= delta
	if _summon_timer > 0.0:
		return

	_summon_timer = summon_cooldown * _get_skill_interval_multiplier()
	_summon_minions()


func _summon_minions() -> void:
	var available_slots := summon_max_alive - _summoned_enemies.size()
	if available_slots <= 0:
		return

	var spawn_count := mini(summon_batch_count, available_slots)
	var base_count := _summoned_enemies.size()
	for index in spawn_count:
		var minion_archetype := PAPER_DOLL_ARCHETYPE
		if (base_count + index) % 2 == 1:
			minion_archetype = WANDERING_SOUL_ARCHETYPE
		_spawn_minion(minion_archetype, index, spawn_count)


func _spawn_minion(enemy_archetype: Resource, index: int, spawn_count: int) -> void:
	var enemy_instance := ENEMY_SCENE.instantiate()
	if not enemy_instance is Enemy:
		enemy_instance.queue_free()
		return

	var enemy := enemy_instance as Enemy
	enemy.archetype = enemy_archetype
	_get_effect_parent().add_child(enemy)

	var angle := TAU * float(index) / float(maxi(spawn_count, 1))
	enemy.global_position = global_position + Vector2.RIGHT.rotated(angle) * summon_spawn_radius
	enemy.died.connect(_on_summoned_enemy_died)
	_summoned_enemies.append(enemy)


func _clean_summoned_enemies() -> void:
	var index := _summoned_enemies.size() - 1
	while index >= 0:
		if not is_instance_valid(_summoned_enemies[index]):
			_summoned_enemies.remove_at(index)
		index -= 1


func _on_summoned_enemy_died(enemy: Enemy) -> void:
	_summoned_enemies.erase(enemy)


func _enter_enrage() -> void:
	_is_enraged = true
	move_speed *= enrage_speed_multiplier
	charge_speed *= enrage_speed_multiplier
	_charge_timer = minf(_charge_timer, charge_cooldown * enrage_skill_interval_multiplier * 0.5)
	_burst_timer = minf(_burst_timer, burst_cooldown * enrage_skill_interval_multiplier * 0.5)
	_summon_timer = minf(_summon_timer, summon_cooldown * enrage_skill_interval_multiplier * 0.5)
	_body.color = Color(0.78, 0.14, 0.08, 1.0)
	_enraged_aura.visible = true


func _clear_boss_effects() -> void:
	_charge_telegraph.visible = false
	for burst in _burst_markers:
		var marker := burst["node"] as Node2D
		if is_instance_valid(marker):
			marker.queue_free()
	_burst_markers.clear()

	for enemy in _summoned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_summoned_enemies.clear()


func _get_skill_interval_multiplier() -> float:
	if _is_enraged:
		return enrage_skill_interval_multiplier
	return 1.0


func _make_circle_polygon(radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in maxi(point_count, 3):
		var angle := TAU * float(index) / float(maxi(point_count, 3))
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points


func _get_effect_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene

	var parent := get_parent()
	if parent != null:
		return parent

	return self
