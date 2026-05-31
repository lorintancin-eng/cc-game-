class_name FireSpearProjectile
extends Area2D

## 火尖枪投射物 — 方向性穿透火枪（哪吒 W201）。
##
## 朝发射方向直线飞行，穿透至多 pierce_count 个敌人，每个满伤，单敌只击一次
## （instance_id 去重）。伤害走单参 take_damage(amount)，与现有武器一致。
## 模型同飞剑投射物（scripts/weapon/flying_sword_projectile.gd）。
##
## 到期 / 穿透耗尽时在原地留下「灼烧地面」（BurningGround，短暂滞留 DoT）。

const MIN_DIRECTION_LENGTH: float = 0.001
const MIN_LIFETIME: float = 0.05

const BURNING_GROUND_SCENE: PackedScene = preload("res://scenes/weapon/nezha/BurningGround.tscn")
const BURNING_RADIUS: float = 40.0
const BURNING_DOT_FRACTION: float = 0.2  # 每跳灼烧 = 火尖枪伤害 ×0.2（随伤害升级而强化）
const BURNING_TICK: float = 0.4
const BURNING_LIFETIME: float = 1.5

var damage: float = 0.0
var speed: float = 0.0
var lifetime: float = 0.0
var pierce_count: int = 1

var _direction: Vector2 = Vector2.RIGHT
var _elapsed_time: float = 0.0
var _hit_count: int = 0
var _hit_instance_ids: Dictionary = {}
var _is_spent: bool = false
var _is_launched: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _is_launched:
		return

	global_position += _direction * speed * delta
	_elapsed_time += delta

	if _elapsed_time >= lifetime:
		_finish()


func launch(
	new_direction: Vector2,
	new_damage: float,
	new_speed: float,
	new_lifetime: float,
	new_pierce_count: int
) -> void:
	if new_direction.length_squared() <= MIN_DIRECTION_LENGTH * MIN_DIRECTION_LENGTH:
		_direction = Vector2.RIGHT
	else:
		_direction = new_direction.normalized()

	damage = maxf(new_damage, 0.0)
	speed = maxf(new_speed, 0.0)
	lifetime = maxf(new_lifetime, MIN_LIFETIME)
	pierce_count = maxi(new_pierce_count, 1)
	_elapsed_time = 0.0
	_hit_count = 0
	_hit_instance_ids.clear()
	_is_spent = false
	_is_launched = true
	rotation = _direction.angle()
	set_physics_process(true)


func _on_body_entered(body: Node2D) -> void:
	if _is_spent or is_queued_for_deletion() or _hit_count >= pierce_count:
		return
	if not body.is_in_group("enemies"):
		return
	if not body.has_method("take_damage"):
		return

	var instance_id := body.get_instance_id()
	if _hit_instance_ids.has(instance_id):
		return

	_hit_instance_ids[instance_id] = true
	_hit_count += 1
	body.call("take_damage", damage)

	if _hit_count >= pierce_count:
		_finish()


func _finish() -> void:
	if _is_spent:
		return

	_is_spent = true
	_is_launched = false
	set_physics_process(false)
	_spawn_burning_ground()
	queue_free()


## 在投射物当前位置生成灼烧地面（作为父节点的子节点，独立于本投射物存活）。
func _spawn_burning_ground() -> void:
	if BURNING_GROUND_SCENE == null:
		return
	var parent := get_parent()
	if parent == null:
		return
	var ground := BURNING_GROUND_SCENE.instantiate() as BurningGround
	if ground == null:
		return
	parent.add_child(ground)
	ground.setup(global_position, BURNING_RADIUS, damage * BURNING_DOT_FRACTION, BURNING_TICK, BURNING_LIFETIME)
