class_name EnemySpawner
extends Node2D

signal enemy_defeated(defeated_count: int)
signal elite_spawned(elite: Enemy, affixes: Array[String])
signal enemy_killed(enemy: Enemy)

const DEFAULT_ENEMY_SCENE: PackedScene = preload("res://scenes/enemy/Enemy.tscn")
const WANDERING_SOUL_ARCHETYPE: Resource = preload("res://resources/enemies/wandering_soul.tres")
const PAPER_DOLL_ARCHETYPE: Resource = preload("res://resources/enemies/paper_doll.tres")
const FOX_SPIRIT_ARCHETYPE: Resource = preload("res://resources/enemies/fox_spirit.tres")
const STONE_GOLEM_ARCHETYPE: Resource = preload("res://resources/enemies/stone_golem.tres")
const GHOST_FLAME_ARCHETYPE: Resource = preload("res://resources/enemies/ghost_flame.tres")

@export var enemy_scene: PackedScene = DEFAULT_ENEMY_SCENE
@export var enemy_archetype_pool: Array[Resource] = []
@export var enemy_archetype_weights: Array[float] = []
@export var spawn_interval: float = 1.25
@export var max_enemies: int = 18
@export var spawn_margin: float = 80.0
@export var random_seed: int = 1301
@export var is_spawning_enabled: bool = true

var current_enemy_count: int = 0
var defeated_enemy_count: int = 0

var _rng := RandomNumberGenerator.new()
var _spawn_timer: float = 0.0


func _ready() -> void:
	_rng.seed = random_seed
	_spawn_timer = maxf(spawn_interval, 0.1)
	_ensure_default_archetype_pool()


func _process(delta: float) -> void:
	if not is_spawning_enabled or enemy_scene == null or max_enemies <= 0:
		return

	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return

	_spawn_timer += maxf(spawn_interval, 0.1)
	_try_spawn_enemy()


func _try_spawn_enemy() -> void:
	if current_enemy_count >= max_enemies:
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		# 选角前 player 不存在，静默跳过本次 spawn
		return

	var enemy := _create_enemy(_select_archetype())
	if enemy == null:
		return

	enemy.global_position = _get_spawn_position(player.global_position)


func spawn_elite_at(enemy_archetype: Resource, spawn_position: Vector2, affixes: Array[String]) -> Enemy:
	var enemy := _create_enemy(enemy_archetype, affixes)
	if enemy == null:
		return null

	enemy.global_position = spawn_position
	elite_spawned.emit(enemy, affixes)
	return enemy


func set_spawning_enabled(is_enabled: bool) -> void:
	is_spawning_enabled = is_enabled


## Despawns every live enemy this spawner owns and resets the live count. Used by
## the multi-stage transition (RunDirector) to clear the previous stage's enemies
## before the next stage's waves begin. queue_free() does NOT emit `died` (no XP
## orbs, no kill credit), so the count is reset directly rather than via signals.
func clear_all_enemies() -> void:
	for child in get_children():
		if child is Enemy:
			child.queue_free()
	current_enemy_count = 0


func apply_wave_config(
	new_spawn_interval: float,
	new_max_enemies: int,
	new_archetype_pool: Array[Resource],
	new_archetype_weights: Array[float]
) -> void:
	spawn_interval = maxf(new_spawn_interval, 0.1)
	max_enemies = maxi(new_max_enemies, 0)
	_spawn_timer = minf(_spawn_timer, spawn_interval)

	enemy_archetype_pool.clear()
	for enemy_archetype in new_archetype_pool:
		if enemy_archetype != null:
			enemy_archetype_pool.append(enemy_archetype)

	if enemy_archetype_pool.is_empty():
		_ensure_default_archetype_pool()
		return

	enemy_archetype_weights.clear()
	for index in enemy_archetype_pool.size():
		var weight := 1.0
		if index < new_archetype_weights.size():
			weight = new_archetype_weights[index]
		enemy_archetype_weights.append(maxf(weight, 0.0))


func get_effective_archetype_count() -> int:
	if enemy_archetype_pool.is_empty():
		return 0

	var archetype_count := 0
	for enemy_archetype in enemy_archetype_pool:
		if enemy_archetype != null:
			archetype_count += 1

	return archetype_count


func _create_enemy(enemy_archetype: Resource, affixes: Array[String] = []) -> Enemy:
	if enemy_scene == null:
		push_warning("EnemySpawner has no enemy_scene.")
		return null

	var enemy_instance := enemy_scene.instantiate()
	if not enemy_instance is Enemy:
		push_error("EnemySpawner enemy_scene must instantiate an Enemy.")
		enemy_instance.queue_free()
		return null

	var enemy := enemy_instance as Enemy
	enemy.archetype = enemy_archetype
	add_child(enemy)
	if not affixes.is_empty():
		enemy.configure_elite(affixes)
	enemy.died.connect(_on_enemy_died)
	current_enemy_count += 1
	return enemy


func _ensure_default_archetype_pool() -> void:
	if not enemy_archetype_pool.is_empty():
		return

	enemy_archetype_pool = [
		WANDERING_SOUL_ARCHETYPE,
		PAPER_DOLL_ARCHETYPE,
		FOX_SPIRIT_ARCHETYPE,
		STONE_GOLEM_ARCHETYPE,
		GHOST_FLAME_ARCHETYPE,
	]
	enemy_archetype_weights = [
		3.0,
		4.0,
		1.6,
		0.8,
		1.2,
	]


func _select_archetype() -> Resource:
	if enemy_archetype_pool.is_empty():
		return null

	var total_weight := 0.0
	for index in enemy_archetype_pool.size():
		if enemy_archetype_pool[index] == null:
			continue
		total_weight += _get_archetype_weight(index)

	if total_weight <= 0.0:
		return null

	var roll := _rng.randf_range(0.0, total_weight)
	var running_weight := 0.0
	for index in enemy_archetype_pool.size():
		var enemy_archetype: Resource = enemy_archetype_pool[index]
		if enemy_archetype == null:
			continue

		running_weight += _get_archetype_weight(index)
		if roll <= running_weight:
			return enemy_archetype

	return null


func _get_archetype_weight(index: int) -> float:
	if index < enemy_archetype_weights.size():
		return maxf(enemy_archetype_weights[index], 0.0)

	return 1.0


func _get_spawn_position(player_position: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	var camera := get_viewport().get_camera_2d()
	var camera_zoom := Vector2.ONE
	if camera != null:
		camera_zoom = camera.zoom

	var half_visible_size := viewport_size * 0.5 / camera_zoom
	var side := _rng.randi_range(0, 3)
	var offset := Vector2.ZERO

	match side:
		0:
			offset.x = -half_visible_size.x - spawn_margin
			offset.y = _rng.randf_range(-half_visible_size.y, half_visible_size.y)
		1:
			offset.x = half_visible_size.x + spawn_margin
			offset.y = _rng.randf_range(-half_visible_size.y, half_visible_size.y)
		2:
			offset.x = _rng.randf_range(-half_visible_size.x, half_visible_size.x)
			offset.y = -half_visible_size.y - spawn_margin
		_:
			offset.x = _rng.randf_range(-half_visible_size.x, half_visible_size.x)
			offset.y = half_visible_size.y + spawn_margin

	return player_position + offset


func _on_enemy_died(_enemy: Enemy) -> void:
	current_enemy_count = maxi(current_enemy_count - 1, 0)
	enemy_killed.emit(_enemy)
	defeated_enemy_count += 1
	enemy_defeated.emit(defeated_enemy_count)
