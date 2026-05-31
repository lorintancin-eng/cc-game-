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
## ADR-0004: emitted INSTEAD of stage_cleared when the stage boss dies AND a
## RunDirector reports a next stage — the run advances rather than ending. The
## RunDirector listens and drives reset_for_stage(). stage_cleared still fires on
## the FINAL (or standalone) stage → the victory screen.
signal stage_advance_requested()

const DEFAULT_BOSS_SCENE: PackedScene = preload("res://scenes/enemy/FamineBeastBoss.tscn")
const DEFAULT_DEMON_SEAL_SCENE: PackedScene = preload("res://scenes/system/DemonSeal.tscn")
const DEFAULT_EXPERIENCE_ORB_SCENE: PackedScene = preload("res://scenes/system/ExperienceOrb.tscn")
const TRADE_STALL_SCENE: PackedScene = preload("res://scenes/system/TradeStall.tscn")
const MIN_STAGE_DURATION: float = 1.0
const MIN_SPAWN_DISTANCE: float = 80.0
# ADR-0004: the wave timeline (start times / intervals / max / pools / weights),
# elite spawn events, and elite affixes are now DATA-DRIVEN via StageConfig —
# see the `stage_config` export below. The old hardcoded WAVE_*_START_TIME
# constants + archetype preloads + _get_wave_* functions were removed.

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
## ADR-0004: data-driven stage definition. null ⇒ defaults to StageOneConfig
## (Stage 1 荒山古道). The wave timeline, elite events, demon-seal params, boss
## scene + stage duration all come from here. The boss_*/demon_seal_* exports
## above are populated FROM this config in _ready (config wins) and kept so the
## rest of the file reads them unchanged. A RunDirector assigns stage_config per
## stage (Stage 2 = 幽都鬼市).
@export var stage_config: StageConfig

## ADR-0004: optional run lifecycle owner. When set (wired in Main.tscn) AND
## stage_config is null, the StageDirector pulls the active stage's config from
## the RunDirector instead of hardcoding Stage 1. Null ⇒ standalone Stage-1
## fallback (unchanged single-stage behavior). The RunDirector drives the
## Stage 1→2 transition in a later step.
@export var run_director: RunDirector

## Ghost Market trade panel (wired in Main.tscn). When a TradeStall's hold
## completes, the StageDirector shows this panel with the 3 offers + applies the
## chosen buff. Null ⇒ trades are inert (stalls still spawn but can't open).
@export var trade_panel: TradePanel

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
var _is_stage_cleared: bool = false
var _is_stage_failed: bool = false
var _is_demon_seal_pressure_active: bool = false
var _current_wave: WaveConfig = null
## Parallel to stage_config.elite_events — _fired_elite_events[i] = true once
## that event has spawned (each fires once). Sized in _ready.
var _fired_elite_events: Array[bool] = []
var _rng := RandomNumberGenerator.new()
var _player: Player
var _enemy_spawner: EnemySpawner
var _demon_seal: Area2D

# Ghost Market trade run-state.
var _trade_count: int = 0          # cumulative completed trades (0-indexed n)
var _market_unease: int = 0        # expired-stall FOMO counter (capped at 3)
var _fired_stall_count: int = 0    # how many of trade_stall_config.stall_spawn_times have fired
var _active_stalls: Array[TradeStall] = []
var _active_trade_stall: TradeStall = null  # the stall whose panel is currently open
var _active_offers: Array = []
var _stalls_resolved: int = 0      # stalls spent or expired this stage (for early-exit)
var _pending_tides: Array = []     # scheduled tide bursts: {remaining, normals, elites}


func _ready() -> void:
	if stage_config == null:
		if run_director != null:
			stage_config = run_director.get_current_stage_config()
		if stage_config == null:
			stage_config = StageOneConfig.build()
	_apply_stage_config_values()
	_fired_elite_events.resize(stage_config.elite_events.size())
	_fired_elite_events.fill(false)
	# A stage whose config has no Demon Seal never spawns one (Stage 2 uses
	# trade stalls instead) — mark it already-spawned to skip the spawn check.
	if stage_config.demon_seal_config == null:
		_is_demon_seal_spawned = true

	_clamp_stage_values()
	_rng.randomize()

	_player = get_node_or_null(player_path) as Player
	_enemy_spawner = get_node_or_null(enemy_spawner_path) as EnemySpawner
	if _enemy_spawner != null:
		_enemy_spawner.difficulty_multiplier = stage_config.difficulty_multiplier
	if _player != null and not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)
	_apply_current_wave_config(true)

	stage_time_changed.emit(elapsed_time, stage_duration)

	# Same instanced-sub-scene NodePath quirk as run_director: resolve the panel by
	# sibling lookup if the @export didn't bind (this was why stalls never opened).
	if trade_panel == null:
		trade_panel = _find_trade_panel()
	if trade_panel != null:
		if not trade_panel.offer_chosen.is_connected(_on_trade_offer_chosen):
			trade_panel.offer_chosen.connect(_on_trade_offer_chosen)
		if not trade_panel.declined.is_connected(_on_trade_declined):
			trade_panel.declined.connect(_on_trade_declined)


func _process(delta: float) -> void:
	if _is_stage_cleared or _is_stage_failed:
		return

	elapsed_time = minf(elapsed_time + delta, stage_duration)
	stage_time_changed.emit(elapsed_time, stage_duration)
	_apply_current_wave_config()

	var is_interlude := stage_config != null and stage_config.is_interlude
	if not is_interlude and not _is_boss_warning_started and elapsed_time >= stage_duration - boss_warning_lead_time:
		_is_boss_warning_started = true
		boss_warning_started.emit(boss_warning_lead_time)

	if not _is_demon_seal_spawned and elapsed_time >= demon_seal_spawn_time:
		_spawn_demon_seal()

	_check_elite_spawns()
	_check_trade_stall_spawns()
	_tick_pending_tides(delta)

	if stage_config != null and stage_config.is_interlude:
		_check_interlude_early_exit()

	if elapsed_time >= stage_duration:
		if stage_config != null and stage_config.is_interlude:
			_end_interlude()
		elif not _is_boss_spawned:
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
	_expire_all_stalls_for_boss()
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

	_get_spawn_parent().add_child(boss)  # runs Enemy._ready → applies archetype stats
	boss.global_position = _get_boss_spawn_position()
	# Per-stage difficulty scaling for the boss (gentler than waves; sets public
	# fields only — does NOT touch the frozen enemy.gd / boss scripts).
	if stage_config != null and stage_config.difficulty_multiplier > 1.0:
		var boss_scale_mult := 1.0 + (stage_config.difficulty_multiplier - 1.0) * 0.6
		boss.max_hp *= boss_scale_mult
		boss.current_hp = boss.max_hp
		boss.damage *= boss_scale_mult
	boss_spawned.emit(boss)


func _check_elite_spawns() -> void:
	# Fire each config elite event once when elapsed_time crosses its spawn_time
	# (replaces the old two hardcoded _spawn_first/second_elite at 180/240).
	for i in range(stage_config.elite_events.size()):
		if _fired_elite_events[i]:
			continue
		var event := stage_config.elite_events[i]
		if event == null:
			_fired_elite_events[i] = true
			continue
		if elapsed_time >= event.spawn_time:
			_spawn_elite_event(event)
			_fired_elite_events[i] = true


func _spawn_elite_event(event: EliteSpawnEvent) -> void:
	if _enemy_spawner == null:
		push_warning("StageDirector could not find EnemySpawner for elite spawn.")
		return
	if event.archetype == null:
		push_warning("StageDirector elite event has no archetype.")
		return

	var affixes: Array[String] = []
	affixes.assign(event.affixes)
	var elite := _enemy_spawner.spawn_elite_at(
		event.archetype,
		_get_elite_spawn_position(event.spawn_distance),
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

	if stage_config == null:
		return
	var active_wave := stage_config.get_active_wave(elapsed_time)
	if active_wave == null:
		return
	if not force_apply and active_wave == _current_wave:
		return

	_current_wave = active_wave
	var wave_spawn_interval := active_wave.spawn_interval
	var wave_max_enemies := active_wave.max_enemies
	if _is_demon_seal_pressure_active:
		wave_spawn_interval = maxf(wave_spawn_interval * demon_seal_pressure_interval_multiplier, 0.1)
		wave_max_enemies += demon_seal_pressure_max_enemy_bonus

	# DEBUG/QA：应用测试加速倍率（默认 1.0 / 1.0 不改变行为）
	wave_spawn_interval = maxf(wave_spawn_interval * maxf(spawn_interval_multiplier, 0.01), 0.1)
	wave_max_enemies = maxi(int(round(float(wave_max_enemies) * maxf(max_enemies_multiplier, 0.1))), 1)

	# Stage difficulty (endless escalation): more enemies + faster spawn. 1.0 = no-op.
	var difficulty := 1.0
	if stage_config != null:
		difficulty = maxf(stage_config.difficulty_multiplier, 0.1)
	if not is_equal_approx(difficulty, 1.0):
		wave_spawn_interval = maxf(wave_spawn_interval / difficulty, 0.1)
		wave_max_enemies = maxi(int(round(float(wave_max_enemies) * difficulty)), 1)

	# archetype_pool is Array[EnemyArchetype]; the spawner takes Array[Resource].
	# .assign() coerces the type; .duplicate() the weights so the spawner cannot
	# mutate the config's array (matches the old per-call fresh-array behavior).
	var pool: Array[Resource] = []
	pool.assign(active_wave.archetype_pool)
	var weights: Array[float] = active_wave.archetype_weights.duplicate()
	_enemy_spawner.apply_wave_config(
		wave_spawn_interval,
		wave_max_enemies,
		pool,
		weights
	)


## ADR-0004: re-initializes the director for a NEW stage mid-run (the multi-stage
## transition). Called by RunDirector when advancing 荒山→鬼市. Resets the per-stage
## progression flags + clock, swaps in the new config, clears the previous stage's
## enemies, and restarts at wave 0. Does NOT touch the player (RunDirector heals
## it) and does NOT re-resolve _player/_enemy_spawner (cached from _ready, the same
## nodes persist across the transition).
func reset_for_stage(new_config: StageConfig) -> void:
	if new_config == null:
		push_error("StageDirector.reset_for_stage called with a null config.")
		return
	stage_config = new_config

	elapsed_time = 0.0
	_is_boss_warning_started = false
	_is_boss_spawned = false
	_is_demon_seal_spawned = false
	_is_demon_seal_completed = false
	_is_stage_cleared = false
	_is_stage_failed = false
	_is_demon_seal_pressure_active = false
	_current_wave = null

	# Per-stage trade/stall state — reset so each interlude spawns its own stalls.
	# (_trade_count + _market_unease are RUN-scoped and intentionally persist.)
	_fired_stall_count = 0
	_stalls_resolved = 0
	_active_stalls.clear()
	_pending_tides.clear()
	_active_trade_stall = null
	_active_offers = []

	# Re-apply config + clamps in the same order as _ready.
	_apply_stage_config_values()
	_fired_elite_events.clear()
	_fired_elite_events.resize(stage_config.elite_events.size())
	_fired_elite_events.fill(false)
	if stage_config.demon_seal_config == null:
		_is_demon_seal_spawned = true
	_clamp_stage_values()

	# Wipe the previous stage's enemies; restart spawning — but DISABLE passive
	# spawning for an interlude (it stays calm until a trade tide, which spawn_burst
	# delivers regardless of this flag). _apply_current_wave_config still sets the
	# pool so the tide draws from the 鬼市 roster.
	if _enemy_spawner != null:
		_enemy_spawner.clear_all_enemies()
		_enemy_spawner.set_spawning_enabled(not stage_config.is_interlude)
		_enemy_spawner.difficulty_multiplier = stage_config.difficulty_multiplier
	_apply_current_wave_config(true)

	stage_time_changed.emit(elapsed_time, stage_duration)


## The MIN-clamp pass over the boss + demon-seal exports. Extracted from _ready so
## reset_for_stage re-applies the exact same clamps when swapping stage configs.
func _clamp_stage_values() -> void:
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


func _apply_stage_config_values() -> void:
	# Populate the boss_*/demon_seal_* exports + stage_duration + boss_scene from
	# the StageConfig so the rest of the file reads the fields unchanged. Config
	# wins over any scene-set export. For Stage 1 these mirror the old defaults
	# exactly (golden-tested), so behavior is byte-identical.
	stage_duration = stage_config.stage_duration
	if stage_config.boss_scene != null:
		boss_scene = stage_config.boss_scene
	boss_warning_lead_time = stage_config.boss_warning_lead_time
	boss_spawn_distance = stage_config.boss_spawn_distance
	boss_move_speed = stage_config.boss_move_speed
	boss_max_hp = stage_config.boss_max_hp
	boss_damage = stage_config.boss_damage
	boss_scale = stage_config.boss_scale
	boss_phase_spawn_interval = stage_config.boss_phase_spawn_interval
	boss_phase_max_enemies = stage_config.boss_phase_max_enemies

	var d := stage_config.demon_seal_config
	if d != null:
		demon_seal_spawn_time = d.spawn_time
		demon_seal_min_spawn_distance = d.min_spawn_distance
		demon_seal_max_spawn_distance = d.max_spawn_distance
		demon_seal_required_seconds = d.required_seconds
		demon_seal_pressure_interval_multiplier = d.pressure_interval_multiplier
		demon_seal_pressure_max_enemy_bonus = d.pressure_max_enemy_bonus
		demon_seal_reward_orb_count = d.reward_orb_count
		demon_seal_reward_xp_value = d.reward_xp_value
		demon_seal_reward_radius = d.reward_radius


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


func _get_elite_spawn_position(distance: float) -> Vector2:
	var player_position := global_position
	if is_instance_valid(_player):
		player_position = _player.global_position

	var angle := _rng.randf_range(0.0, TAU)
	return player_position + Vector2.RIGHT.rotated(angle) * distance


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


# ─── Ghost Market trade orchestration (鬼市交易) ─────────────────────────────

func _check_trade_stall_spawns() -> void:
	if stage_config == null or stage_config.trade_stall_config == null or _is_boss_spawned:
		return
	var times: Array = stage_config.trade_stall_config.stall_spawn_times
	while _fired_stall_count < times.size():
		if elapsed_time < float(times[_fired_stall_count]):
			break
		_spawn_trade_stall(stage_config.trade_stall_config)
		_fired_stall_count += 1


func _spawn_trade_stall(cfg: TradeStallConfig) -> void:
	var stall_instance := TRADE_STALL_SCENE.instantiate()
	var stall := stall_instance as TradeStall
	if stall == null:
		push_error("StageDirector TRADE_STALL_SCENE must instantiate a TradeStall.")
		stall_instance.queue_free()
		return
	stall.setup(cfg.stall_linger_seconds, 1.0, 0.5)
	stall.trade_requested.connect(_on_trade_requested)
	stall.stall_expired.connect(_on_stall_expired)
	_get_spawn_parent().add_child(stall)
	stall.global_position = _get_elite_spawn_position(220.0)
	_active_stalls.append(stall)


func _expire_all_stalls_for_boss() -> void:
	for stall in _active_stalls:
		if is_instance_valid(stall):
			stall.notify_boss_spawned()
	_active_stalls.clear()


func _on_trade_requested(stall: TradeStall) -> void:
	if _is_stage_cleared or _is_stage_failed or _player == null:
		return
	if trade_panel == null:
		trade_panel = _find_trade_panel()
	if trade_panel == null:
		stall.return_to_available()  # no panel wired → don't hang the stall
		return
	_active_trade_stall = stall
	_active_offers = _build_trade_offers()
	_player.begin_trade()
	trade_panel.show_offers(_active_offers)


## Builds the 3 offers from TradeFormulas + the player's live state. Costs use the
## 0-indexed global trade counter n; the tide preview is the (n+1)th tide.
func _build_trade_offers() -> Array:
	var n := _trade_count
	var tide := TradeFormulas.demon_tide(n + 1, _market_unease)
	var tide_label := "潮汐 %d怪" % tide.normal_count
	if tide.elite_count > 0:
		tide_label += " +%d精英" % tide.elite_count

	var bp_cost := TradeFormulas.blood_pact_max_hp_cost(n)
	var bp_locked := _player == null or TradeFormulas.is_blood_pact_locked(
		_player.max_hp, n, _player.blood_pact_stacks())
	# Soul Codex pre-resolves a specific weapon-aware upgrade at panel-open time
	# (shown on the card, applied on pick). Empty pool ⇒ no offer (bad-luck filter).
	var sc_upgrade: Dictionary = _player.pick_trade_upgrade() if _player != null else {}
	var sc_has := not sc_upgrade.is_empty()
	var sc_cost := TradeFormulas.soul_codex_xp_cost(n)
	var sc_ok := sc_has and _player != null and TradeFormulas.is_soul_codex_affordable(_player.current_xp, n)
	var sc_desc := String(sc_upgrade.get("title", "")) if sc_has else "（暂无可习）"
	var sc_id := StringName(sc_upgrade.get("id", &"")) if sc_has else &""

	return [
		{
			"kind": "blood_pact", "title": "血契", "description": "武器伤害 ×1.15",
			"cost_label": "永久气血上限 -%d" % bp_cost, "tide_label": tide_label,
			"disabled": bp_locked,
		},
		{
			"kind": "soul_codex", "title": "魂典", "description": sc_desc,
			"cost_label": "修为 -%d" % sc_cost, "tide_label": tide_label,
			"disabled": not sc_ok, "upgrade_id": sc_id,
		},
		{
			"kind": "yin_debt", "title": "阴债", "description": "移速 +20%（45秒）",
			"cost_label": "免费 · 债后偿", "tide_label": tide_label, "disabled": false,
		},
	]


func _on_trade_offer_chosen(index: int) -> void:
	if _active_trade_stall == null or _player == null or index < 0 or index >= _active_offers.size():
		_close_trade()
		return
	if _is_stage_cleared or _is_stage_failed or _player._is_dead:
		_active_trade_stall.abort_trade()  # Step-A abort: no spend, no buff
		_close_trade()
		return

	var offer: Dictionary = _active_offers[index]
	var n := _trade_count
	var applied := false
	match String(offer.get("kind", "")):
		"blood_pact":
			applied = _player.execute_blood_pact(n)
		"soul_codex":
			applied = _player.execute_soul_codex(n, offer.get("upgrade_id", &""))
		"yin_debt":
			_player.execute_yin_debt()
			applied = true

	if applied:
		_active_trade_stall.mark_spent()
		_stalls_resolved += 1
		_active_stalls.erase(_active_trade_stall)
		_trade_count += 1
		# Anger the market: Yin Debt's tide is delayed (the "debt"); others immediate.
		if String(offer.get("kind", "")) == "yin_debt":
			var yspec := TradeFormulas.demon_tide(_trade_count, _market_unease)
			_pending_tides.append({"remaining": 13.5, "normals": yspec.normal_count, "elites": yspec.elite_count})
		else:
			spawn_demon_tide(_trade_count, _market_unease)
	else:
		_active_trade_stall.return_to_available()
	_close_trade()


func _on_trade_declined() -> void:
	if _active_trade_stall != null:
		_active_trade_stall.return_to_available()
	_close_trade()


func _close_trade() -> void:
	if trade_panel != null:
		trade_panel.hide_panel()
	if _player != null:
		_player.end_trade()
	_active_trade_stall = null
	_active_offers = []


func _on_stall_expired(stall: TradeStall) -> void:
	_active_stalls.erase(stall)
	_stalls_resolved += 1
	_market_unease = TradeFormulas.clamp_market_unease(_market_unease + 1)


## Spawns the demon tide a completed trade angers (ghost-market-trade.md Formula 4):
## an initial burst of Ghost Market enemies + Impermanence elites, PLUS two smaller
## follow-up bursts over the tide window — sustained pressure (the interlude has no
## passive spawning, so the tide IS the threat). Guarded against a dead player /
## ended stage (GDD Rule 7).
func spawn_demon_tide(trade_n: int, market_unease: int) -> void:
	var spec := TradeFormulas.demon_tide(trade_n, market_unease)
	_emit_tide_burst(spec.normal_count, spec.elite_count)
	var follow := maxi(spec.normal_count / 2, 2)
	_pending_tides.append({"remaining": spec.window_seconds * 0.45, "normals": follow, "elites": 0})
	_pending_tides.append({"remaining": spec.window_seconds * 0.85, "normals": follow, "elites": 0})


## Spawns one tide burst — normals from the current pool + Impermanence elites.
func _emit_tide_burst(normal_count: int, elite_count: int) -> void:
	if _is_stage_cleared or _is_stage_failed or _enemy_spawner == null:
		return
	if _player != null and _player._is_dead:
		return
	_enemy_spawner.spawn_burst(normal_count)
	if elite_count > 0 and stage_config != null and stage_config.trade_stall_config != null:
		var elite_archetype: EnemyArchetype = stage_config.trade_stall_config.demon_tide_elite_archetype
		if elite_archetype != null:
			var affixes: Array[String] = ["swift"]
			for _i in elite_count:
				_enemy_spawner.spawn_elite_at(elite_archetype, _get_elite_spawn_position(240.0), affixes)


## Fires scheduled tide bursts (sustained follow-ups + the delayed Yin Debt tide).
func _tick_pending_tides(delta: float) -> void:
	if _pending_tides.is_empty():
		return
	var still_pending: Array = []
	for tide in _pending_tides:
		tide["remaining"] = float(tide["remaining"]) - delta
		if tide["remaining"] <= 0.0:
			_emit_tide_burst(int(tide["normals"]), int(tide["elites"]))
		else:
			still_pending.append(tide)
	_pending_tides = still_pending


func _on_boss_died(_boss: Enemy) -> void:
	if _is_stage_cleared or _is_stage_failed:
		return

	_is_stage_cleared = true
	_set_demon_seal_pressure_active(false)
	if _enemy_spawner != null:
		_enemy_spawner.set_spawning_enabled(false)
	_end_stage()


## Interludes end at stage_duration, OR EARLY once every stall is resolved (traded
## or expired) and all scheduled tide bursts have fired — so a decisive player isn't
## stuck waiting out the timer, while a trader still faces their tides first.
func _check_interlude_early_exit() -> void:
	if _is_stage_cleared or elapsed_time < 4.0:
		return
	var cfg := stage_config.trade_stall_config
	if cfg == null:
		return
	if _fired_stall_count >= cfg.stall_spawn_times.size() \
			and _stalls_resolved >= _fired_stall_count \
			and _pending_tides.is_empty():
		_end_interlude()


## A trade interlude (no boss) ends at stage_duration: stop spawning + advance,
## exactly like a boss death (but with no boss to kill).
func _end_interlude() -> void:
	if _is_stage_cleared or _is_stage_failed:
		return
	_is_stage_cleared = true
	if _enemy_spawner != null:
		_enemy_spawner.set_spawning_enabled(false)
	_expire_all_stalls_for_boss()
	_end_stage()


## ADR-0004: advance to the next stage if the RunDirector has one, else fire
## stage_cleared (the run-victory screen). Shared by boss death + interlude end.
## Robust fallback: a typed-NodePath @export on an INSTANCED sub-scene can fail to
## resolve at load; if so, find the sibling RunDirector directly.
func _end_stage() -> void:
	if run_director == null:
		run_director = _find_run_director()
	var has_next := run_director != null and run_director.has_next_stage()
	print("[StageDirector] stage end — run_director=%s has_next_stage=%s → %s" % [
		run_director, has_next, "ADVANCE" if has_next else "VICTORY"])
	if has_next:
		stage_advance_requested.emit()
	else:
		stage_cleared.emit(elapsed_time)


## Sibling lookup fallback for the RunDirector when the @export NodePath didn't
## resolve (an instanced sub-scene quirk). One sibling get_node_or_null — not a
## brittle deep path.
func _find_run_director() -> RunDirector:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null(^"RunDirector") as RunDirector


## Sibling lookup fallback for the TradePanel (same instanced-sub-scene @export quirk).
func _find_trade_panel() -> TradePanel:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null(^"TradePanel") as TradePanel


func _on_player_died() -> void:
	if _is_stage_cleared or _is_stage_failed:
		return

	_is_stage_failed = true
	_set_demon_seal_pressure_active(false)
	stage_failed.emit(elapsed_time)
