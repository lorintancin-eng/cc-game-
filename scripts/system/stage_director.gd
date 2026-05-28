class_name StageDirector
extends Node2D

signal stage_time_changed(elapsed_time: float, stage_duration: float)
signal boss_warning_started(warning_lead_time: float)
signal boss_spawned(boss: Enemy)
signal elite_spawned(elite: Enemy, affixes: Array[String])
signal demon_seal_spawned(demon_seal: Area2D)
signal demon_seal_progress_changed(progress_seconds: float, required_seconds: float, is_sealing: bool)
signal demon_seal_completed(demon_seal: Area2D)
signal stage_cleared(elapsed_time: float)
signal stage_failed(elapsed_time: float)

const DEFAULT_BOSS_SCENE: PackedScene = preload("res://scenes/enemy/FamineBeastBoss.tscn")
const DEFAULT_DEMON_SEAL_SCENE: PackedScene = preload("res://scenes/system/DemonSeal.tscn")
const DEFAULT_EXPERIENCE_ORB_SCENE: PackedScene = preload("res://scenes/system/ExperienceOrb.tscn")
const WANDERING_SOUL_ARCHETYPE: Resource = preload("res://resources/enemies/wandering_soul.tres")
const PAPER_DOLL_ARCHETYPE: Resource = preload("res://resources/enemies/paper_doll.tres")
const FOX_SPIRIT_ARCHETYPE: Resource = preload("res://resources/enemies/fox_spirit.tres")
const STONE_GOLEM_ARCHETYPE: Resource = preload("res://resources/enemies/stone_golem.tres")
const GHOST_FLAME_ARCHETYPE: Resource = preload("res://resources/enemies/ghost_flame.tres")
const SHANXIAO_ELITE_ARCHETYPE: Resource = preload("res://resources/enemies/shanxiao_elite.tres")
const MIN_STAGE_DURATION: float = 1.0
const MIN_SPAWN_DISTANCE: float = 80.0
const ELITE_AFFIX_IRON_BONES: String = "iron_bones"
const ELITE_AFFIX_SWIFT: String = "swift"
const WAVE_TWO_START_TIME: float = 60.0
const WAVE_THREE_START_TIME: float = 120.0
const WAVE_FOUR_START_TIME: float = 180.0
const WAVE_BOSS_WARNING_START_TIME: float = 270.0

@export var player_path: NodePath = ^"../Player"
@export var enemy_spawner_path: NodePath = ^"../EnemySpawner"
@export var boss_scene: PackedScene = DEFAULT_BOSS_SCENE
@export var demon_seal_scene: PackedScene = DEFAULT_DEMON_SEAL_SCENE
@export var experience_orb_scene: PackedScene = DEFAULT_EXPERIENCE_ORB_SCENE
@export var stage_duration: float = 300.0
@export var boss_warning_lead_time: float = 30.0
@export var boss_spawn_distance: float = 420.0
@export var boss_move_speed: float = 70.0
@export var boss_max_hp: float = 260.0
@export var boss_damage: float = 16.0
@export var boss_scale: float = 1.8
@export var boss_phase_spawn_interval: float = 2.5
@export var boss_phase_max_enemies: int = 8
@export var demon_seal_spawn_time: float = 120.0
@export var demon_seal_min_spawn_distance: float = 200.0
@export var demon_seal_max_spawn_distance: float = 280.0
@export var demon_seal_required_seconds: float = 8.0
@export var demon_seal_pressure_interval_multiplier: float = 0.65
@export var demon_seal_pressure_max_enemy_bonus: int = 6
@export var demon_seal_reward_orb_count: int = 8
@export var demon_seal_reward_xp_value: float = 6.0
@export var demon_seal_reward_radius: float = 54.0
@export var first_elite_spawn_time: float = 180.0
@export var second_elite_spawn_time: float = 240.0
@export var elite_spawn_distance: float = 420.0

# ─────────────────────────────────────────────
# DEBUG/QA：测试加速参数（默认 1.0 不影响正式游戏）
# 调小 spawn_interval_multiplier（如 0.3）→ 出怪间隔变 3x 短，敌人更密
# 调大 max_enemies_multiplier（如 2.0）→ 场上敌人上限翻倍
# 用于 W214 QA 快速观察战斗体验，测试完务必改回 1.0
# ─────────────────────────────────────────────
@export_group("Debug / QA Test")
@export var spawn_interval_multiplier: float = 1.0
@export var max_enemies_multiplier: float = 1.0
@export_group("")

var elapsed_time: float = 0.0

var _is_boss_warning_started: bool = false
var _is_boss_spawned: bool = false
var _is_demon_seal_spawned: bool = false
var _is_demon_seal_completed: bool = false
var _is_first_elite_spawned: bool = false
var _is_second_elite_spawned: bool = false
var _is_stage_cleared: bool = false
var _is_stage_failed: bool = false
var _is_demon_seal_pressure_active: bool = false
var _current_wave_config_index: int = -1
var _rng := RandomNumberGenerator.new()
var _player: Player
var _enemy_spawner: EnemySpawner
var _demon_seal: Area2D


func _ready() -> void:
	stage_duration = maxf(stage_duration, MIN_STAGE_DURATION)
	boss_warning_lead_time = clampf(boss_warning_lead_time, 0.0, stage_duration)
	boss_spawn_distance = maxf(boss_spawn_distance, MIN_SPAWN_DISTANCE)
	boss_max_hp = maxf(boss_max_hp, 1.0)
	boss_damage = maxf(boss_damage, 0.0)
	boss_scale = maxf(boss_scale, 0.1)
	demon_seal_spawn_time = clampf(demon_seal_spawn_time, 0.0, stage_duration)
	demon_seal_min_spawn_distance = maxf(demon_seal_min_spawn_distance, MIN_SPAWN_DISTANCE)
	demon_seal_max_spawn_distance = maxf(demon_seal_max_spawn_distance, demon_seal_min_spawn_distance)
	demon_seal_required_seconds = maxf(demon_seal_required_seconds, 0.1)
	demon_seal_pressure_interval_multiplier = clampf(demon_seal_pressure_interval_multiplier, 0.1, 1.0)
	demon_seal_pressure_max_enemy_bonus = maxi(demon_seal_pressure_max_enemy_bonus, 0)
	demon_seal_reward_orb_count = maxi(demon_seal_reward_orb_count, 0)
	demon_seal_reward_xp_value = maxf(demon_seal_reward_xp_value, 0.0)
	demon_seal_reward_radius = maxf(demon_seal_reward_radius, 0.0)
	first_elite_spawn_time = clampf(first_elite_spawn_time, 0.0, stage_duration)
	second_elite_spawn_time = clampf(second_elite_spawn_time, 0.0, stage_duration)
	elite_spawn_distance = maxf(elite_spawn_distance, MIN_SPAWN_DISTANCE)
	_rng.randomize()

	_player = get_node_or_null(player_path) as Player
	_enemy_spawner = get_node_or_null(enemy_spawner_path) as EnemySpawner
	if _player != null and not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)
	_apply_current_wave_config(true)

	stage_time_changed.emit(elapsed_time, stage_duration)


func _process(delta: float) -> void:
	if _is_stage_cleared or _is_stage_failed:
		return

	elapsed_time = minf(elapsed_time + delta, stage_duration)
	stage_time_changed.emit(elapsed_time, stage_duration)
	_apply_current_wave_config()

	if not _is_boss_warning_started and elapsed_time >= stage_duration - boss_warning_lead_time:
		_is_boss_warning_started = true
		boss_warning_started.emit(boss_warning_lead_time)

	if not _is_demon_seal_spawned and elapsed_time >= demon_seal_spawn_time:
		_spawn_demon_seal()

	if not _is_first_elite_spawned and elapsed_time >= first_elite_spawn_time:
		_spawn_first_elite()

	if not _is_second_elite_spawned and elapsed_time >= second_elite_spawn_time:
		_spawn_second_elite()

	if not _is_boss_spawned and elapsed_time >= stage_duration:
		_spawn_boss()


func _spawn_demon_seal() -> void:
	_is_demon_seal_spawned = true
	if demon_seal_scene == null:
		push_warning("StageDirector has no demon_seal_scene.")
		return

	var seal_instance := demon_seal_scene.instantiate()
	if not seal_instance is Area2D:
		push_error("StageDirector demon_seal_scene must instantiate an Area2D.")
		seal_instance.queue_free()
		return

	_demon_seal = seal_instance as Area2D
	if not _demon_seal.has_signal(&"seal_progress_changed") or not _demon_seal.has_signal(&"seal_completed"):
		push_error("StageDirector demon_seal_scene must provide seal progress and completed signals.")
		_demon_seal.queue_free()
		_demon_seal = null
		return

	_demon_seal.set("required_seconds", demon_seal_required_seconds)
	_demon_seal.connect(&"seal_progress_changed", _on_demon_seal_progress_changed)
	_demon_seal.connect(&"seal_completed", _on_demon_seal_completed)

	_get_spawn_parent().add_child(_demon_seal)
	_demon_seal.global_position = _get_demon_seal_spawn_position()
	demon_seal_spawned.emit(_demon_seal)


func _spawn_boss() -> void:
	_is_boss_spawned = true
	_apply_boss_phase_spawn_pressure()

	if boss_scene == null:
		push_warning("StageDirector has no boss_scene.")
		return

	var boss_instance := boss_scene.instantiate()
	if not boss_instance is Enemy:
		push_error("StageDirector boss_scene must instantiate an Enemy.")
		boss_instance.queue_free()
		return

	var boss := boss_instance as Enemy
	boss.name = "FamineBeastBoss"
	if boss.archetype == null:
		boss.move_speed = boss_move_speed
		boss.max_hp = boss_max_hp
		boss.damage = boss_damage
		boss.scale = Vector2.ONE * boss_scale
	boss.xp_drop_value = 0.0
	boss.died.connect(_on_boss_died)

	_get_spawn_parent().add_child(boss)
	boss.global_position = _get_boss_spawn_position()
	boss_spawned.emit(boss)


func _spawn_first_elite() -> void:
	_is_first_elite_spawned = true
	_spawn_shanxiao_elite([ELITE_AFFIX_IRON_BONES])


func _spawn_second_elite() -> void:
	_is_second_elite_spawned = true
	_spawn_shanxiao_elite([ELITE_AFFIX_SWIFT])


func _spawn_shanxiao_elite(affixes: Array[String]) -> void:
	if _enemy_spawner == null:
		push_warning("StageDirector could not find EnemySpawner for elite spawn.")
		return

	var elite := _enemy_spawner.spawn_elite_at(
		SHANXIAO_ELITE_ARCHETYPE,
		_get_elite_spawn_position(),
		affixes
	)
	if elite != null:
		elite_spawned.emit(elite, affixes)


func _apply_boss_phase_spawn_pressure() -> void:
	if _enemy_spawner == null:
		return

	_enemy_spawner.spawn_interval = maxf(_enemy_spawner.spawn_interval, boss_phase_spawn_interval)
	if boss_phase_max_enemies >= 0:
		_enemy_spawner.max_enemies = mini(_enemy_spawner.max_enemies, boss_phase_max_enemies)


func _apply_current_wave_config(force_apply: bool = false) -> void:
	if _enemy_spawner == null or _is_boss_spawned:
		return

	var wave_config_index := _get_wave_config_index()
	if not force_apply and wave_config_index == _current_wave_config_index:
		return

	_current_wave_config_index = wave_config_index
	var wave_spawn_interval := _get_wave_spawn_interval(wave_config_index)
	var wave_max_enemies := _get_wave_max_enemies(wave_config_index)
	if _is_demon_seal_pressure_active:
		wave_spawn_interval = maxf(wave_spawn_interval * demon_seal_pressure_interval_multiplier, 0.1)
		wave_max_enemies += demon_seal_pressure_max_enemy_bonus

	# DEBUG/QA：应用测试加速倍率（默认 1.0 / 1.0 不改变行为）
	wave_spawn_interval = maxf(wave_spawn_interval * maxf(spawn_interval_multiplier, 0.01), 0.1)
	wave_max_enemies = maxi(int(round(float(wave_max_enemies) * maxf(max_enemies_multiplier, 0.1))), 1)

	_enemy_spawner.apply_wave_config(
		wave_spawn_interval,
		wave_max_enemies,
		_get_wave_archetype_pool(wave_config_index),
		_get_wave_archetype_weights(wave_config_index)
	)


func _get_wave_config_index() -> int:
	if elapsed_time >= WAVE_BOSS_WARNING_START_TIME:
		return 4
	if elapsed_time >= WAVE_FOUR_START_TIME:
		return 3
	if elapsed_time >= WAVE_THREE_START_TIME:
		return 2
	if elapsed_time >= WAVE_TWO_START_TIME:
		return 1

	return 0


func _get_wave_spawn_interval(wave_config_index: int) -> float:
	match wave_config_index:
		0:
			return 1.35
		1:
			return 1.08
		2:
			return 0.90
		3:
			return 0.72
		_:
			return 0.55


func _get_wave_max_enemies(wave_config_index: int) -> int:
	match wave_config_index:
		0:
			return 18
		1:
			return 24
		2:
			return 32
		3:
			return 42
		_:
			return 56


func _get_wave_archetype_pool(wave_config_index: int) -> Array[Resource]:
	match wave_config_index:
		0:
			return [
				PAPER_DOLL_ARCHETYPE,
				WANDERING_SOUL_ARCHETYPE,
			]
		1:
			return [
				PAPER_DOLL_ARCHETYPE,
				WANDERING_SOUL_ARCHETYPE,
				FOX_SPIRIT_ARCHETYPE,
				GHOST_FLAME_ARCHETYPE,
			]
		_:
			return [
				PAPER_DOLL_ARCHETYPE,
				WANDERING_SOUL_ARCHETYPE,
				FOX_SPIRIT_ARCHETYPE,
				GHOST_FLAME_ARCHETYPE,
				STONE_GOLEM_ARCHETYPE,
			]


func _get_wave_archetype_weights(wave_config_index: int) -> Array[float]:
	match wave_config_index:
		0:
			return [4.0, 3.0]
		1:
			return [3.6, 3.0, 0.8, 0.6]
		2:
			return [2.8, 2.8, 1.2, 1.0, 0.35]
		3:
			return [2.5, 2.4, 1.8, 1.4, 0.7]
		_:
			return [2.0, 2.0, 2.3, 1.9, 1.0]


func _set_demon_seal_pressure_active(is_active: bool) -> void:
	if _enemy_spawner == null:
		return
	if is_active == _is_demon_seal_pressure_active:
		return

	_is_demon_seal_pressure_active = is_active
	if _is_boss_spawned:
		_apply_boss_phase_spawn_pressure()
		return

	_apply_current_wave_config(true)


func _get_spawn_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene

	var parent := get_parent()
	if parent != null:
		return parent

	return self


func _get_boss_spawn_position() -> Vector2:
	var player_position := global_position
	if is_instance_valid(_player):
		player_position = _player.global_position

	var angle := _rng.randf_range(0.0, TAU)
	return player_position + Vector2.RIGHT.rotated(angle) * boss_spawn_distance


func _get_demon_seal_spawn_position() -> Vector2:
	var player_position := global_position
	if is_instance_valid(_player):
		player_position = _player.global_position

	var angle := _rng.randf_range(0.0, TAU)
	var distance := _rng.randf_range(demon_seal_min_spawn_distance, demon_seal_max_spawn_distance)
	var base_pos := player_position + Vector2.RIGHT.rotated(angle) * distance
	var jitter := Vector2(_rng.randf_range(-30.0, 30.0), _rng.randf_range(-30.0, 30.0))
	return base_pos + jitter


func _get_elite_spawn_position() -> Vector2:
	var player_position := global_position
	if is_instance_valid(_player):
		player_position = _player.global_position

	var angle := _rng.randf_range(0.0, TAU)
	return player_position + Vector2.RIGHT.rotated(angle) * elite_spawn_distance


func _spawn_demon_seal_reward(center_position: Vector2) -> void:
	if experience_orb_scene == null:
		push_warning("StageDirector has no experience_orb_scene.")
		return

	for index in demon_seal_reward_orb_count:
		var orb_instance := experience_orb_scene.instantiate()
		if not orb_instance is ExperienceOrb:
			push_error("StageDirector experience_orb_scene must instantiate an ExperienceOrb.")
			orb_instance.queue_free()
			return

		var orb := orb_instance as ExperienceOrb
		orb.xp_value = demon_seal_reward_xp_value
		_get_spawn_parent().add_child(orb)

		var angle := TAU * float(index) / float(maxi(demon_seal_reward_orb_count, 1))
		var distance := demon_seal_reward_radius
		if demon_seal_reward_orb_count == 1:
			distance = 0.0
		orb.global_position = center_position + Vector2.RIGHT.rotated(angle) * distance


func _on_demon_seal_progress_changed(progress_seconds: float, required_seconds: float, is_sealing: bool) -> void:
	if _is_stage_cleared or _is_stage_failed or _is_demon_seal_completed:
		return

	_set_demon_seal_pressure_active(is_sealing)
	demon_seal_progress_changed.emit(progress_seconds, required_seconds, is_sealing)


func _on_demon_seal_completed(demon_seal: Area2D) -> void:
	if _is_demon_seal_completed:
		return
	# OQ-4 fix: if the run has already ended (player dead OR boss already killed),
	# swallow the late seal_completed signal — do NOT spawn 8 XP orbs on a corpse
	# and do NOT emit demon_seal_completed (HUD would mis-display "封印完成").
	# Surfaced by /review-all-gdds 2026-05-27 (defect #1) + Demon Seal GDD OQ-4.
	if _is_stage_failed or _is_stage_cleared:
		return

	_is_demon_seal_completed = true
	_set_demon_seal_pressure_active(false)
	_spawn_demon_seal_reward(demon_seal.global_position)
	demon_seal_completed.emit(demon_seal)


func _on_boss_died(_boss: Enemy) -> void:
	if _is_stage_cleared or _is_stage_failed:
		return

	_is_stage_cleared = true
	_set_demon_seal_pressure_active(false)
	if _enemy_spawner != null:
		_enemy_spawner.set_spawning_enabled(false)
	stage_cleared.emit(elapsed_time)


func _on_player_died() -> void:
	if _is_stage_cleared or _is_stage_failed:
		return

	_is_stage_failed = true
	_set_demon_seal_pressure_active(false)
	stage_failed.emit(elapsed_time)
