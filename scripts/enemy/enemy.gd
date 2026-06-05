class_name Enemy
extends CharacterBody2D

signal died(enemy: Enemy)
## Emitted after HP mutation when the enemy is hit by a non-zero damage event.
## Payload: (current_hp, max_hp, last_damage_amount).
## Per Combat GDD r5 Core Rule 3 + Enemy GDD r1 — required by HUD enemy HP bars
## and Status Effects (FT-10) integration. Does NOT fire for zero-damage events
## (those go through source-side damage_dealt instead, per Combat AC-19).
signal damage_taken(current_hp: float, max_hp: float, last_damage_amount: float)

const MIN_DAMAGE_INTERVAL: float = 0.1
const HEALTH_BAR_WIDTH: float = 28.0
const HEALTH_BAR_HEIGHT: float = 4.0
const DEFAULT_EXPERIENCE_ORB_SCENE: PackedScene = preload("res://scenes/system/ExperienceOrb.tscn")
const MOVEMENT_CHASE: int = 0
const MOVEMENT_WAVE_CHASE: int = 1
const ELITE_AFFIX_IRON_BONES: String = "iron_bones"
const ELITE_AFFIX_SWIFT: String = "swift"

@export var archetype: Resource
@export var move_speed: float = 90.0
@export var max_hp: float = 24.0
@export var damage: float = 8.0
@export var damage_interval: float = 0.8
@export var xp_drop_value: float = 5.0
@export var experience_orb_scene: PackedScene = DEFAULT_EXPERIENCE_ORB_SCENE
@export_enum("Chase", "Wave Chase") var movement_mode: int = MOVEMENT_CHASE
@export var wave_amplitude: float = 0.0
@export var wave_frequency: float = 0.0
@export var wave_phase: float = 0.0
@export var is_elite: bool = false
@export var elite_affixes: Array[String] = []
@export var elite_health_multiplier: float = 1.25
@export var elite_damage_multiplier: float = 1.15
@export var elite_speed_multiplier: float = 1.05
@export var iron_bones_health_multiplier: float = 1.45
@export var swift_speed_multiplier: float = 1.3
## Five Phases 相克 element (Story 005). Set from the archetype at apply; weapons
## read it via WeaponBase.element_of(self) to compute the matchup multiplier.
@export var element: String = "neutral"

var current_hp: float = 0.0

var _damage_cooldown: float = 0.0
var _damage_targets: Array[Node] = []
var _is_dead: bool = false
var _movement_time: float = 0.0
var _player: Node2D
## Tracks the last damage amount for the EnemyKillData payload (Story 003).
var _last_kill_source_element: String = "neutral"
var _last_damage_amount: float = 0.0

@onready var _damage_area: Area2D = $DamageArea
@onready var _body: Polygon2D = $Body
@onready var _body_collision: CollisionShape2D = $CollisionShape2D
@onready var _damage_collision: CollisionShape2D = $DamageArea/CollisionShape2D
@onready var _health_bar: Node2D = $HealthBar
@onready var _health_fill: Polygon2D = $HealthBar/Fill


func _ready() -> void:
	add_to_group("enemies")
	if archetype != null:
		_apply_archetype_values(archetype)
	if is_elite:
		_apply_elite_modifiers()
	max_hp = maxf(max_hp, 1.0)
	current_hp = max_hp
	_damage_area.body_entered.connect(_on_damage_body_entered)
	_damage_area.body_exited.connect(_on_damage_body_exited)
	_apply_archetype_visuals(archetype)
	_update_health_bar()
	_find_player()


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		return

	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)

	if not is_instance_valid(_player):
		_find_player()

	if _player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_movement_time += delta
	velocity = _get_move_direction(_player.global_position) * move_speed
	move_and_slide()

	_try_damage_player()


func apply_archetype(enemy_archetype: Resource) -> void:
	archetype = enemy_archetype
	if archetype == null:
		return

	_apply_archetype_values(archetype)
	if is_elite:
		_apply_elite_modifiers()
	max_hp = maxf(max_hp, 1.0)
	current_hp = max_hp
	if is_node_ready():
		_apply_archetype_visuals(archetype)
		_update_health_bar()


func configure_elite(affixes: Array[String]) -> void:
	var configured_affixes := affixes.duplicate()
	if archetype != null:
		_apply_archetype_values(archetype)

	is_elite = true
	elite_affixes = configured_affixes
	_apply_elite_modifiers()
	max_hp = maxf(max_hp, 1.0)
	current_hp = max_hp
	if is_node_ready():
		_apply_archetype_visuals(archetype)
		_update_health_bar()


func take_damage(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return

	current_hp = maxf(current_hp - amount, 0.0)
	_last_damage_amount = amount
	# NOTE (Story 005): the 相克 matchup is applied WEAPON-SIDE (weapons multiply
	# damage before this single-param take_damage), so the source weapon's element
	# is NOT threaded here — _last_kill_source_element stays "neutral" until
	# TODO(Story-006): 燎原 wires the kill-source element via its own mechanism.
	_update_health_bar()
	damage_taken.emit(current_hp, max_hp, amount)
	if current_hp <= 0.0:
		_die()


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D


func _get_move_direction(target_position: Vector2) -> Vector2:
	var move_direction := global_position.direction_to(target_position)
	if movement_mode != MOVEMENT_WAVE_CHASE or move_direction == Vector2.ZERO:
		return move_direction

	var wave_offset := move_direction.orthogonal() * sin(_movement_time * wave_frequency * TAU + wave_phase) * wave_amplitude
	return (move_direction + wave_offset).normalized()


func _apply_archetype_values(enemy_archetype: Resource) -> void:
	move_speed = enemy_archetype.move_speed
	max_hp = enemy_archetype.max_hp
	damage = enemy_archetype.damage
	element = enemy_archetype.element
	damage_interval = enemy_archetype.damage_interval
	xp_drop_value = enemy_archetype.xp_drop_value
	movement_mode = enemy_archetype.movement_mode
	wave_amplitude = enemy_archetype.wave_amplitude
	wave_frequency = enemy_archetype.wave_frequency
	wave_phase = enemy_archetype.wave_phase
	is_elite = enemy_archetype.is_elite
	elite_affixes = enemy_archetype.elite_affixes.duplicate()
	elite_health_multiplier = enemy_archetype.elite_health_multiplier
	elite_damage_multiplier = enemy_archetype.elite_damage_multiplier
	elite_speed_multiplier = enemy_archetype.elite_speed_multiplier
	iron_bones_health_multiplier = enemy_archetype.iron_bones_health_multiplier
	swift_speed_multiplier = enemy_archetype.swift_speed_multiplier


func _apply_elite_modifiers() -> void:
	max_hp *= maxf(elite_health_multiplier, 0.1)
	damage *= maxf(elite_damage_multiplier, 0.0)
	move_speed *= maxf(elite_speed_multiplier, 0.1)

	for affix in elite_affixes:
		match affix:
			ELITE_AFFIX_IRON_BONES:
				max_hp *= maxf(iron_bones_health_multiplier, 0.1)
			ELITE_AFFIX_SWIFT:
				move_speed *= maxf(swift_speed_multiplier, 0.1)


func _apply_archetype_visuals(enemy_archetype: Resource) -> void:
	if enemy_archetype == null:
		return

	_body.color = enemy_archetype.body_color
	_body.scale = Vector2.ONE * maxf(enemy_archetype.body_scale, 0.1)
	_health_bar.position.y = enemy_archetype.health_bar_y
	_set_circle_shape_radius(_body_collision, enemy_archetype.collision_radius)
	_set_circle_shape_radius(_damage_collision, enemy_archetype.damage_radius)


func _set_circle_shape_radius(collision_shape: CollisionShape2D, radius: float) -> void:
	if collision_shape.shape is CircleShape2D:
		var circle_shape := collision_shape.shape.duplicate() as CircleShape2D
		circle_shape.radius = maxf(radius, 1.0)
		collision_shape.shape = circle_shape


func _try_damage_player() -> void:
	if _damage_cooldown > 0.0 or damage <= 0.0:
		return

	for target in _damage_targets:
		if _is_player_damage_target(target):
			# Combat GDD Core Rule 8: the player only accepts contact damage from
			# the MAX_CONTACT_ATTACKERS most-recently-entered attackers per frame.
			# If gated out, deal no damage AND do NOT start the cooldown — this
			# enemy stays ready the instant a slot frees (Formula 7 / Story 008).
			# has_method guard keeps behavior unchanged if the target predates the API.
			if target.has_method("is_contact_attacker_allowed") and not target.is_contact_attacker_allowed(self):
				return
			target.call("take_damage", damage)
			_damage_cooldown = maxf(damage_interval, MIN_DAMAGE_INTERVAL)
			return


func _is_player_damage_target(target: Object) -> bool:
	if not target is Node:
		return false

	var target_node := target as Node
	return target_node.is_in_group("player") and target.has_method("take_damage")


func _update_health_bar() -> void:
	if _health_fill == null:
		return

	var health_ratio := clampf(current_hp / max_hp, 0.0, 1.0)
	var left := -HEALTH_BAR_WIDTH * 0.5
	var right := left + HEALTH_BAR_WIDTH * health_ratio
	var top := -HEALTH_BAR_HEIGHT * 0.5
	var bottom := HEALTH_BAR_HEIGHT * 0.5
	_health_fill.polygon = PackedVector2Array([
		Vector2(left, top),
		Vector2(right, top),
		Vector2(right, bottom),
		Vector2(left, bottom),
	])


func _on_damage_body_entered(body: Node2D) -> void:
	if _is_player_damage_target(body) and not _damage_targets.has(body):
		_damage_targets.append(body)
		# Register with the player's aggregate contact-ceiling tracker (Core Rule 8).
		if body.has_method("register_contact_attacker"):
			body.register_contact_attacker(self)


func _on_damage_body_exited(body: Node2D) -> void:
	_damage_targets.erase(body)
	# Free up our slot in the player's contact ceiling so a queued attacker promotes.
	if is_instance_valid(body) and body.has_method("unregister_contact_attacker"):
		body.unregister_contact_attacker(self)


func _die() -> void:
	if _is_dead:
		return

	_is_dead = true
	velocity = Vector2.ZERO
	_drop_experience()
	died.emit(self)
	var kill_data := EnemyKillData.new(_last_kill_source_element, _last_damage_amount, global_position)
	CombatEvents.enemy_killed.emit(kill_data)
	queue_free()


func _drop_experience() -> void:
	if xp_drop_value <= 0.0 or experience_orb_scene == null:
		return

	var orb_instance := experience_orb_scene.instantiate()
	if not orb_instance is ExperienceOrb:
		push_error("Enemy experience_orb_scene must instantiate an ExperienceOrb.")
		orb_instance.queue_free()
		return

	var orb := orb_instance as ExperienceOrb
	var drop_parent := _get_drop_parent()
	if drop_parent is Node2D:
		orb.position = (drop_parent as Node2D).to_local(global_position)
	else:
		orb.global_position = global_position
	orb.xp_value = xp_drop_value
	drop_parent.call_deferred("add_child", orb)


func _get_drop_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene

	var parent := get_parent()
	if parent != null:
		return parent

	return self
