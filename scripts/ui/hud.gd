class_name HUD
extends CanvasLayer

@export var player_path: NodePath = ^"../Player"
@export var enemy_spawner_path: NodePath = ^"../EnemySpawner"
@export var game_over_panel_path: NodePath = ^"../GameOverPanel"
@export var stage_director_path: NodePath = ^"../StageDirector"

const _STATUS_PRIORITY_NONE := 0
const _STATUS_PRIORITY_DEMON_SEAL := 10
const _STATUS_PRIORITY_BOSS_WARNING := 20
const _STATUS_PRIORITY_BOSS_SPAWNED := 30
const _STATUS_PRIORITY_RUN_FINISHED := 40

var _survival_time: float = 0.0
var _stage_duration: float = 0.0
var _displayed_time_seconds: int = -1
var _kill_count: int = 0
var _final_level: int = 1
var _is_run_finished: bool = false
var _stage_status_priority: int = _STATUS_PRIORITY_NONE

var _player: Player
var _enemy_spawner: EnemySpawner
var _game_over_panel: GameOverPanel
var _stage_director: Node
# Bug C fix: cache character_base to avoid per-frame reflection in _update_energy_bar
var _cached_character_base: Node = null
# Boss HP bar wiring (uses Enemy.damage_taken signal from Combat Story 002)
var _active_boss: Enemy = null

@onready var _health_label: Label = $Panel/Margin/Content/HealthLabel
@onready var _level_label: Label = $Panel/Margin/Content/LevelLabel
@onready var _experience_label: Label = $Panel/Margin/Content/ExperienceLabel
@onready var _time_label: Label = $Panel/Margin/Content/TimeLabel
@onready var _kill_label: Label = $Panel/Margin/Content/KillLabel
@onready var _stage_status_label: Label = $Panel/Margin/Content/StageStatusLabel
@onready var _energy_panel: Control = $EnergyPanel
@onready var _energy_label: Label = $EnergyPanel/EnergyVBox/EnergyMargin/EnergyContent/EnergyLabel
@onready var _energy_bar: ProgressBar = $EnergyPanel/EnergyVBox/EnergyMargin/EnergyContent/EnergyBar
@onready var _energy_value_label: Label = $EnergyPanel/EnergyVBox/EnergyMargin/EnergyContent/EnergyValueLabel
@onready var _skill_panel: PanelContainer = $SkillPanel
@onready var _skill_icon_1: ColorRect = $SkillPanel/SkillHBox/SkillMargin/SkillRow/SkillSlot1/SkillIcon1
@onready var _skill_label_1: Label = $SkillPanel/SkillHBox/SkillMargin/SkillRow/SkillSlot1/SkillLabel1
@onready var _skill_icon_2: ColorRect = $SkillPanel/SkillHBox/SkillMargin/SkillRow/SkillSlot2/SkillIcon2
@onready var _skill_label_2: Label = $SkillPanel/SkillHBox/SkillMargin/SkillRow/SkillSlot2/SkillLabel2
@onready var _skill_icon_3: ColorRect = $SkillPanel/SkillHBox/SkillMargin/SkillRow/SkillSlot3/SkillIcon3
@onready var _skill_label_3: Label = $SkillPanel/SkillHBox/SkillMargin/SkillRow/SkillSlot3/SkillLabel3
@onready var _skill_icon_4: ColorRect = $SkillPanel/SkillHBox/SkillMargin/SkillRow/SkillSlot4/SkillIcon4
@onready var _skill_label_4: Label = $SkillPanel/SkillHBox/SkillMargin/SkillRow/SkillSlot4/SkillLabel4
@onready var _boss_panel: PanelContainer = $BossPanel
@onready var _boss_name_label: Label = $BossPanel/BossMargin/BossContent/BossNameLabel
@onready var _boss_hp_bar: ProgressBar = $BossPanel/BossMargin/BossContent/BossHPBar
@onready var _boss_hp_value_label: Label = $BossPanel/BossMargin/BossContent/BossHPValueLabel


func _ready() -> void:
	_player = get_node_or_null(player_path) as Player
	_enemy_spawner = get_node_or_null(enemy_spawner_path) as EnemySpawner
	_game_over_panel = get_node_or_null(game_over_panel_path) as GameOverPanel
	_stage_director = get_node_or_null(stage_director_path)

	_connect_player()
	_connect_enemy_spawner()
	_connect_stage_director()
	_refresh_initial_state()
	_update_time_label(true)
	_update_kill_label()
	_set_stage_status("")
	_setup_energy_bar()
	_setup_skill_panel()


func _process(delta: float) -> void:
	if not (_is_run_finished or _stage_director != null):
		_survival_time += delta
		_update_time_label()
	_update_energy_bar()


func _connect_player() -> void:
	if _player == null:
		push_warning("HUD could not find Player at %s." % player_path)
		return

	if not _player.health_changed.is_connected(_on_player_health_changed):
		_player.health_changed.connect(_on_player_health_changed)
	if not _player.experience_changed.is_connected(_on_player_experience_changed):
		_player.experience_changed.connect(_on_player_experience_changed)
	if not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)


func _connect_enemy_spawner() -> void:
	if _enemy_spawner == null:
		push_warning("HUD could not find EnemySpawner at %s." % enemy_spawner_path)
		return

	_kill_count = _enemy_spawner.defeated_enemy_count
	if not _enemy_spawner.enemy_defeated.is_connected(_on_enemy_defeated):
		_enemy_spawner.enemy_defeated.connect(_on_enemy_defeated)


func _connect_stage_director() -> void:
	if _stage_director == null:
		return

	if not _stage_director.is_connected(&"stage_time_changed", _on_stage_time_changed):
		_stage_director.connect(&"stage_time_changed", _on_stage_time_changed)
	if not _stage_director.is_connected(&"boss_warning_started", _on_boss_warning_started):
		_stage_director.connect(&"boss_warning_started", _on_boss_warning_started)
	if not _stage_director.is_connected(&"boss_spawned", _on_boss_spawned):
		_stage_director.connect(&"boss_spawned", _on_boss_spawned)
	if not _stage_director.is_connected(&"demon_seal_spawned", _on_demon_seal_spawned):
		_stage_director.connect(&"demon_seal_spawned", _on_demon_seal_spawned)
	if not _stage_director.is_connected(&"demon_seal_progress_changed", _on_demon_seal_progress_changed):
		_stage_director.connect(&"demon_seal_progress_changed", _on_demon_seal_progress_changed)
	if not _stage_director.is_connected(&"demon_seal_completed", _on_demon_seal_completed):
		_stage_director.connect(&"demon_seal_completed", _on_demon_seal_completed)
	if not _stage_director.is_connected(&"stage_cleared", _on_stage_cleared):
		_stage_director.connect(&"stage_cleared", _on_stage_cleared)


func _refresh_initial_state() -> void:
	if _player == null:
		_update_health_label(0.0, 0.0)
		_update_experience_label(0.0, 0.0, _final_level)
		return

	var progression_state := _player.get_progression_state()
	var current_hp := float(progression_state.get("current_hp", 0.0))
	var max_hp := float(progression_state.get("max_hp", 0.0))
	var current_xp := float(progression_state.get("current_xp", 0.0))
	var xp_to_next_level := float(progression_state.get("xp_to_next_level", 0.0))
	var level := int(progression_state.get("level", 1))
	_update_health_label(current_hp, max_hp)
	_update_experience_label(current_xp, xp_to_next_level, level)


func _update_health_label(current_hp: float, max_hp: float) -> void:
	_health_label.text = "气血 %s / %s" % [_format_number(current_hp), _format_number(max_hp)]


func _update_experience_label(current_xp: float, xp_to_next_level: float, level: int) -> void:
	_final_level = maxi(level, 1)
	_level_label.text = "境界 %d" % _final_level
	_experience_label.text = "修为 %s / %s" % [_format_number(current_xp), _format_number(xp_to_next_level)]


func _update_time_label(force: bool = false) -> void:
	var time_seconds := floori(_survival_time)
	if not force and time_seconds == _displayed_time_seconds:
		return

	_displayed_time_seconds = time_seconds
	if _stage_duration > 0.0:
		_time_label.text = "历劫时间 %s / %s" % [_format_time(_survival_time), _format_time(_stage_duration)]
	else:
		_time_label.text = "历劫时间 %s" % _format_time(_survival_time)


func _update_kill_label() -> void:
	_kill_label.text = "镇妖数 %d" % _kill_count


func _set_stage_status(status_text: String, priority: int = _STATUS_PRIORITY_DEMON_SEAL) -> void:
	if status_text.is_empty():
		_stage_status_priority = _STATUS_PRIORITY_NONE
		_stage_status_label.text = ""
		_stage_status_label.visible = false
		return

	if priority < _stage_status_priority:
		return

	_stage_status_priority = priority
	_stage_status_label.text = status_text
	_stage_status_label.visible = true


func _format_time(total_seconds: float) -> String:
	var whole_seconds := floori(maxf(total_seconds, 0.0))
	var minutes := int(whole_seconds / 60)
	var seconds := whole_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func _format_number(value: float) -> String:
	var rounded := roundf(value)
	if is_equal_approx(value, rounded):
		return str(int(rounded))

	return "%.1f" % value


func _on_player_health_changed(current_hp: float, max_hp: float) -> void:
	_update_health_label(current_hp, max_hp)


func _on_player_experience_changed(current_xp: float, xp_to_next_level: float, level: int) -> void:
	_update_experience_label(current_xp, xp_to_next_level, level)


func _on_enemy_defeated(defeated_count: int) -> void:
	_kill_count = maxi(defeated_count, 0)
	_update_kill_label()


func _on_stage_time_changed(elapsed_time: float, stage_duration: float) -> void:
	_survival_time = elapsed_time
	_stage_duration = stage_duration
	_update_time_label()


func _on_boss_warning_started(_warning_lead_time: float) -> void:
	_set_stage_status("妖气暴涨，妖王即将降临", _STATUS_PRIORITY_BOSS_WARNING)


func _on_boss_spawned(boss: Enemy) -> void:
	_set_stage_status("妖王降临", _STATUS_PRIORITY_BOSS_SPAWNED)
	_bind_active_boss(boss)


func _bind_active_boss(boss: Enemy) -> void:
	if boss == null or not is_instance_valid(boss):
		_active_boss = null
		_boss_panel.visible = false
		return
	# Drop any previous binding before grabbing the new boss.
	_unbind_active_boss()
	_active_boss = boss
	if not boss.damage_taken.is_connected(_on_boss_damage_taken):
		boss.damage_taken.connect(_on_boss_damage_taken)
	if not boss.died.is_connected(_on_boss_died):
		boss.died.connect(_on_boss_died)
	# Resolve display name from the EnemyArchetype Resource if available.
	var boss_name: String = "妖王"
	if boss.archetype != null and "display_name" in boss.archetype:
		var display = boss.archetype.display_name
		if display is String and display != "":
			boss_name = display
	_boss_name_label.text = boss_name
	_boss_hp_bar.max_value = boss.max_hp
	_boss_hp_bar.value = boss.current_hp
	_boss_hp_value_label.text = "%s / %s" % [_format_number(boss.current_hp), _format_number(boss.max_hp)]
	_boss_panel.visible = true


func _unbind_active_boss() -> void:
	if _active_boss == null:
		return
	if is_instance_valid(_active_boss):
		if _active_boss.damage_taken.is_connected(_on_boss_damage_taken):
			_active_boss.damage_taken.disconnect(_on_boss_damage_taken)
		if _active_boss.died.is_connected(_on_boss_died):
			_active_boss.died.disconnect(_on_boss_died)
	_active_boss = null


func _on_boss_damage_taken(current_hp: float, max_hp: float, _last_damage: float) -> void:
	if _boss_hp_bar == null:
		return
	_boss_hp_bar.max_value = max_hp
	_boss_hp_bar.value = current_hp
	_boss_hp_value_label.text = "%s / %s" % [_format_number(current_hp), _format_number(max_hp)]


func _on_boss_died(_boss: Enemy) -> void:
	_unbind_active_boss()
	if _boss_panel != null:
		_boss_panel.visible = false


func _on_demon_seal_spawned(_demon_seal: Area2D) -> void:
	_set_stage_status("镇妖碑已现身", _STATUS_PRIORITY_DEMON_SEAL)


func _on_demon_seal_progress_changed(progress_seconds: float, required_seconds: float, is_sealing: bool) -> void:
	var progress_percent := 0
	if required_seconds > 0.0:
		progress_percent = roundi(clampf(progress_seconds / required_seconds, 0.0, 1.0) * 100.0)

	var suffix := ""
	if not is_sealing:
		suffix = "（暂停）"
	_set_stage_status("镇妖碑封印 %d%%%s" % [progress_percent, suffix], _STATUS_PRIORITY_DEMON_SEAL)


func _on_demon_seal_completed(_demon_seal: Area2D) -> void:
	_set_stage_status("镇妖碑封印完成", _STATUS_PRIORITY_DEMON_SEAL)


func _on_stage_cleared(stage_time: float) -> void:
	if _is_run_finished:
		return

	_is_run_finished = true
	_survival_time = stage_time
	_update_time_label(true)
	_set_stage_status("封印完成", _STATUS_PRIORITY_RUN_FINISHED)
	if _game_over_panel != null:
		_game_over_panel.show_stage_clear(_survival_time, _kill_count, _final_level)

	get_tree().paused = true


func _on_player_died() -> void:
	if _is_run_finished:
		return

	_is_run_finished = true
	_update_time_label(true)
	_set_stage_status("道消身陨", _STATUS_PRIORITY_RUN_FINISHED)
	if _game_over_panel != null:
		_game_over_panel.show_summary(_survival_time, _kill_count, _final_level)

	get_tree().paused = true


func _setup_energy_bar() -> void:
	# Bug B fix: disconnect from previous character_base before switching
	if _cached_character_base != null and is_instance_valid(_cached_character_base):
		if _cached_character_base.has_signal("energy_full_triggered"):
			if _cached_character_base.energy_full_triggered.is_connected(_on_energy_full):
				_cached_character_base.energy_full_triggered.disconnect(_on_energy_full)
	_cached_character_base = null

	if _player == null:
		_energy_panel.visible = false
		return
	var character_base = _player.get("_character_base")
	if character_base == null:
		_energy_panel.visible = false
		return
	var config = character_base.get("energy_bar_config")
	if config == null or config.is_empty():
		_energy_panel.visible = false
		return
	# Bug C fix: store reference so _update_energy_bar skips per-frame reflection
	_cached_character_base = character_base
	_energy_bar.max_value = config.get("max_value", 30.0)
	_energy_bar.value = 0.0
	_energy_label.text = config.get("label", "能量")
	# Bug A fix: explicitly restore visibility when config is valid (handles character switch)
	_energy_panel.visible = true
	if character_base.has_signal("energy_full_triggered"):
		if not character_base.energy_full_triggered.is_connected(_on_energy_full):
			character_base.energy_full_triggered.connect(_on_energy_full)


func _update_energy_bar() -> void:
	if not _energy_panel.visible:
		return
	# Bug C fix: use cached reference instead of per-frame get() reflection
	if _cached_character_base == null:
		return
	var current = _cached_character_base.get("current_lingqi")
	if current == null:
		return
	_energy_bar.value = current
	_energy_value_label.text = "%d/%d" % [int(current), int(_energy_bar.max_value)]
	if current >= _energy_bar.max_value:
		_energy_bar.modulate = Color(1.0, 0.9, 0.3)
	else:
		_energy_bar.modulate = Color.WHITE


func _on_energy_full() -> void:
	# Bug D fix: brief scale pulse to signal energy full state visually
	if _energy_bar == null:
		return
	var tween := create_tween()
	tween.tween_property(_energy_bar, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(_energy_bar, "scale", Vector2(1.0, 1.0), 0.2)


func _setup_skill_panel() -> void:
	if _player == null:
		_skill_panel.visible = false
		return
	var character_base = _player.get("_character_base")
	if character_base == null:
		_skill_panel.visible = false
		return
	# 仅孙悟空显示主动技能 cooldown 面板
	if character_base.character_id != "sun_wukong":
		_skill_panel.visible = false
		return
	_skill_panel.visible = true
	# 4 个 slot 初始化为未解锁灰显状态
	for slot in range(4):
		update_skill_cooldown(slot, 0.0, 0.0, false)
	# 如果 character_base 是 ActiveSkillCharacter，订阅 cooldown signal
	if character_base.has_signal("skill_cooldown_changed"):
		if not character_base.skill_cooldown_changed.is_connected(_on_skill_cooldown_changed):
			character_base.skill_cooldown_changed.connect(_on_skill_cooldown_changed)


# 公开接口：W204 起 ActiveSkillCharacter 子类调用此方法更新 4 个技能槽显示
# slot: 0-3 对应键位 1/2/3/4
# remaining: 剩余 cooldown 秒数（<=0 表示就绪）
# max_cd: 技能总 cooldown（暂未用，预留显示进度环时用）
# unlocked: 是否已解锁
func update_skill_cooldown(slot: int, remaining: float, _max_cd: float, unlocked: bool) -> void:
	if slot < 0 or slot > 3:
		return
	var icon: ColorRect = _get_skill_icon(slot)
	var label: Label = _get_skill_label(slot)
	if icon == null or label == null:
		return
	if not unlocked:
		# 灰显
		icon.color = Color(0.3, 0.3, 0.3, 1.0)
		label.text = "--"
	elif remaining > 0.0:
		# cooldown 中
		icon.color = Color(0.6, 0.5, 0.2, 1.0)  # 暗金
		label.text = "%ds" % ceili(remaining)
	else:
		# 就绪
		icon.color = Color(1.0, 0.8, 0.3, 1.0)  # 亮金
		label.text = str(slot + 1)


func _get_skill_icon(slot: int) -> ColorRect:
	match slot:
		0: return _skill_icon_1
		1: return _skill_icon_2
		2: return _skill_icon_3
		3: return _skill_icon_4
	return null


func _get_skill_label(slot: int) -> Label:
	match slot:
		0: return _skill_label_1
		1: return _skill_label_2
		2: return _skill_label_3
		3: return _skill_label_4
	return null


func _on_skill_cooldown_changed(slot: int, remaining: float, max_cd: float, unlocked: bool) -> void:
	update_skill_cooldown(slot, remaining, max_cd, unlocked)
