class_name Player
extends CharacterBody2D

signal died
signal health_changed(current_hp: float, max_hp: float)
signal experience_changed(current_xp: float, xp_to_next_level: float, level: int)
signal level_reached(level: int)
signal upgrade_applied(upgrade_id: StringName)

const HEALTH_BAR_WIDTH: float = 36.0
const HEALTH_BAR_HEIGHT: float = 5.0
## Combat GDD Core Rule 8 + Formula 7: at most this many enemies may apply
## contact damage to the player on any single frame. Hard engine constant —
## NOT a .tres tuning knob. Without it, 8+ enemies in contact = ~0.4s wipe,
## breaking Pillar 1 (清晰的生存压力). The 4 chosen are the most-recently-entered.
const MAX_CONTACT_ATTACKERS: int = 4
const DEFAULT_LEVEL_UP_PANEL_SCENE: PackedScene = preload("res://scenes/ui/LevelUpPanel.tscn")
const UPGRADE_TALISMAN_DAMAGE := &"talisman_damage"
const UPGRADE_TALISMAN_COOLDOWN := &"talisman_cooldown"
const UPGRADE_TALISMAN_COUNT := &"talisman_count"
const UPGRADE_TALISMAN_SPEED := &"talisman_speed"
const UPGRADE_UNLOCK_FLYING_SWORD := &"unlock_flying_sword"
const UPGRADE_FLYING_SWORD_DAMAGE := &"flying_sword_damage"
const UPGRADE_FLYING_SWORD_COOLDOWN := &"flying_sword_cooldown"
const UPGRADE_FLYING_SWORD_PIERCE := &"flying_sword_pierce"
const UPGRADE_FLYING_SWORD_COUNT := &"flying_sword_count"
const UPGRADE_UNLOCK_THUNDER_LAW := &"unlock_thunder_law"
const UPGRADE_THUNDER_LAW_DAMAGE := &"thunder_law_damage"
const UPGRADE_THUNDER_LAW_COOLDOWN := &"thunder_law_cooldown"
const UPGRADE_THUNDER_LAW_RADIUS := &"thunder_law_radius"
const UPGRADE_THUNDER_LAW_TARGET_COUNT := &"thunder_law_target_count"
const UPGRADE_UNLOCK_BAGUA_ARRAY := &"unlock_bagua_array"
const UPGRADE_BAGUA_ARRAY_DAMAGE := &"bagua_array_damage"
const UPGRADE_BAGUA_ARRAY_RADIUS := &"bagua_array_radius"
const UPGRADE_BAGUA_ARRAY_ROTATION_SPEED := &"bagua_array_rotation_speed"
const UPGRADE_BAGUA_ARRAY_TICK_RATE := &"bagua_array_tick_rate"
const UPGRADE_UNLOCK_EXPLOSIVE_TALISMAN := &"unlock_explosive_talisman"
const UPGRADE_EXPLOSIVE_TALISMAN_RADIUS := &"explosive_talisman_radius"
const UPGRADE_EXPLOSIVE_TALISMAN_DAMAGE := &"explosive_talisman_damage"
const UPGRADE_EXPLOSIVE_TALISMAN_COUNT := &"explosive_talisman_count"
const UPGRADE_EXPLOSIVE_TALISMAN_COOLDOWN := &"explosive_talisman_cooldown"
const UPGRADE_UNLOCK_MOUNTAIN_SEAL := &"unlock_mountain_seal"
const UPGRADE_MOUNTAIN_SEAL_DAMAGE := &"mountain_seal_damage"
const UPGRADE_MOUNTAIN_SEAL_RADIUS := &"mountain_seal_radius"
const UPGRADE_MOUNTAIN_SEAL_COOLDOWN := &"mountain_seal_cooldown"
const UPGRADE_MAX_HP := &"max_hp"
const UPGRADE_MOVE_SPEED := &"move_speed"
const UPGRADE_PICKUP_RADIUS := &"pickup_radius"
const UPGRADE_XP_GAIN := &"xp_gain"

@export var move_speed: float = 180.0
@export var max_hp: float = 100.0
@export var initial_xp_to_next_level: float = 18.0
@export var xp_growth_multiplier: float = 1.28
@export var xp_growth_flat: float = 6.0
@export var upgrade_random_seed: int = 2401
@export var level_up_panel_scene: PackedScene = DEFAULT_LEVEL_UP_PANEL_SCENE
@export var xp_gain_multiplier: float = 1.0
@export var pickup_radius_bonus: float = 0.0

var current_hp: float = 0.0
var current_xp: float = 0.0
var xp_to_next_level: float = 0.0
var level: int = 1

var _is_dead: bool = false
var _pending_upgrade_choices: int = 0
var _pending_skill_choices: int = 0  # W211: 主动技能选择面板待处理数（孙悟空 Lv5/10/15/20）
var _is_selecting_upgrade: bool = false
var _was_tree_paused_before_level_up: bool = false
## Ghost Market trade panel state (mirrors the level-up pause pattern).
var _is_in_trade: bool = false
var _was_tree_paused_before_trade: bool = false
var _blood_pact_stacks: int = 0
var _is_flying_sword_unlocked: bool = false
var _is_thunder_law_unlocked: bool = false
var _is_bagua_array_unlocked: bool = false
var _is_explosive_talisman_unlocked: bool = false
var _is_mountain_seal_unlocked: bool = false
var _upgrade_rng := RandomNumberGenerator.new()
## D-B2 (Level Up Pool GDD r2): per-upgrade pick counter for the stack cap.
## Keyed by upgrade_id; incremented on selection; read by _get_upgrade_pool to
## drop upgrades that have reached _get_upgrade_max_stacks(). Enforces the
## Combat GDD 5× source-modifier ceiling as a hard cap (damage upgrades cap at 3).
var _upgrade_pick_count: Dictionary = {}
var _level_up_panel: LevelUpPanel
var _is_invincible: bool = false
var _speed_multiplier: float = 1.0
var _damage_multiplier: float = 1.0
## Ghost Market 阴债 (Yin Debt) timed speed buff — additive bonus kept SEPARATE
## from _speed_multiplier (which 七十二变 / transforms drive) so the two never clash.
## Effective speed = move_speed × _speed_multiplier × (1 + _yin_debt_speed_bonus).
var _yin_debt_speed_bonus: float = 0.0
var _yin_debt_remaining: float = 0.0
## Live contact attackers for the aggregate DPS ceiling (Combat GDD Core Rule 8).
## Each entry: {"enemy": Node, "entry_time": float}. Maintained by enemies via
## register_contact_attacker / unregister_contact_attacker on their damage-area
## overlap. Only the MAX_CONTACT_ATTACKERS most-recently-entered may damage per frame.
var _contact_attackers: Array[Dictionary] = []

# 玩家朝向（W205 引入，用于孙悟空金箍棒扇形方向）
# 修行者也有此字段但不主动使用
var facing: Vector2 = Vector2.RIGHT

@onready var _health_fill: Polygon2D = $HealthBar/Fill
@onready var _talisman_weapon: TalismanWeapon = get_node_or_null("TalismanWeapon")
@onready var _flying_sword_weapon: FlyingSwordWeapon = get_node_or_null("FlyingSwordWeapon")
@onready var _thunder_law_weapon: ThunderLawWeapon = get_node_or_null("ThunderLawWeapon")
@onready var _bagua_array_weapon = get_node_or_null("BaguaArrayWeapon")
@onready var _explosive_talisman_weapon = get_node_or_null("ExplosiveTalismanWeapon")
@onready var _mountain_seal_weapon = get_node_or_null("MountainSealWeapon")
@onready var _character_base: CharacterBase = get_node_or_null("CharacterBase")


func _ready() -> void:
	if _character_base != null:
		max_hp = _character_base.max_health
		move_speed = _character_base.move_speed
	_ensure_input_actions()
	_set_weapon_unlocked(_flying_sword_weapon, _is_flying_sword_unlocked)
	_set_weapon_unlocked(_thunder_law_weapon, _is_thunder_law_unlocked)
	_set_weapon_unlocked(_bagua_array_weapon, _is_bagua_array_unlocked)
	_set_weapon_unlocked(_explosive_talisman_weapon, _is_explosive_talisman_unlocked)
	_set_weapon_unlocked(_mountain_seal_weapon, _is_mountain_seal_unlocked)
	max_hp = maxf(max_hp, 1.0)
	current_hp = max_hp
	level = maxi(level, 1)
	current_xp = maxf(current_xp, 0.0)
	xp_to_next_level = maxf(initial_xp_to_next_level, 1.0)
	_upgrade_rng.seed = upgrade_random_seed
	_update_health_bar()
	health_changed.emit(current_hp, max_hp)
	experience_changed.emit(current_xp, xp_to_next_level, level)
	# 连接 EnemySpawner 的 enemy_killed signal 到角色基类 _on_kill 转发
	var spawner := get_parent().get_node_or_null("EnemySpawner")
	if spawner != null and spawner.has_signal("enemy_killed"):
		spawner.enemy_killed.connect(_on_enemy_killed)


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		return

	_tick_yin_debt(delta)
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * move_speed * _speed_multiplier * (1.0 + _yin_debt_speed_bonus)
	move_and_slide()
	# W205: 更新玩家朝向（非零输入时）
	if input_direction != Vector2.ZERO:
		facing = input_direction.normalized()


func take_damage(amount: float) -> void:
	if _is_dead or _is_invincible or amount <= 0.0:
		return

	current_hp = maxf(current_hp - amount, 0.0)
	_update_health_bar()
	health_changed.emit(current_hp, max_hp)
	# 转发受伤回调给角色基类（基类默认 pass；哪吒据此为三昧真火充能）。
	if _character_base != null:
		_character_base._on_damaged(amount)
	if current_hp <= 0.0:
		_die()


## Restores [param amount] HP, clamped to max_hp. No-op when dead or for a
## non-positive amount. Mirrors take_damage's health-bar + signal update. Used by
## the multi-stage run transition — RunDirector heals the player when advancing to
## the next stage (+40% max_hp per stage cleared).
func heal(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return

	current_hp = minf(current_hp + amount, max_hp)
	_update_health_bar()
	health_changed.emit(current_hp, max_hp)


## Ghost Market 阴债 (Yin Debt): grant a timed move-speed bonus (e.g. +20% for 45s).
## A fresh application overwrites any active one (re-buffing refreshes, not stacks).
func apply_yin_debt_speed(bonus: float, duration: float) -> void:
	_yin_debt_speed_bonus = maxf(bonus, 0.0)
	_yin_debt_remaining = maxf(duration, 0.0)


## Counts the Yin Debt buff down; clears the bonus when it expires. Driven each
## frame by _physics_process; extracted so it is unit-testable without the tree.
func _tick_yin_debt(delta: float) -> void:
	if _yin_debt_remaining <= 0.0:
		return
	_yin_debt_remaining -= delta
	if _yin_debt_remaining <= 0.0:
		_yin_debt_remaining = 0.0
		_yin_debt_speed_bonus = 0.0


# ─── Ghost Market trade (鬼市交易) ──────────────────────────────────────────

## Opens a trade: saves + sets the pause state (mirrors the level-up panel; the
## TradePanel processes while paused). is_in_trade() gates a second stall.
func begin_trade() -> void:
	if _is_in_trade:
		return
	_was_tree_paused_before_trade = get_tree().paused
	_is_in_trade = true
	get_tree().paused = true


## Closes a trade: restores the pre-trade pause state.
func end_trade() -> void:
	_is_in_trade = false
	get_tree().paused = _was_tree_paused_before_trade


func is_in_trade() -> bool:
	return _is_in_trade


func blood_pact_stacks() -> int:
	return _blood_pact_stacks


## 血契 Blood Pact: pay permanent max-HP for a weapon-damage buff. [param n] is the
## global trade counter. Returns false if the floor/stack lock rejects it (defensive
## re-check; the panel should already disable a locked offer). Simplified MVP buff:
## ×(1+0.15) to each owned weapon's damage per stack (GDD Formula 1's additive-on-base
## model is a later refinement).
func execute_blood_pact(n: int) -> bool:
	if TradeFormulas.is_blood_pact_locked(max_hp, n, _blood_pact_stacks):
		return false
	max_hp = TradeFormulas.apply_blood_pact_max_hp(max_hp, n)
	current_hp = TradeFormulas.clamp_current_hp(current_hp, max_hp)
	_update_health_bar()
	health_changed.emit(current_hp, max_hp)
	_blood_pact_stacks += 1
	var mult := 1.0 + TradeFormulas.BLOOD_PACT_DAMAGE_PER_STACK
	for weapon in _owned_weapons():
		var dmg = weapon.get("damage")
		if dmg != null:
			weapon.set("damage", float(dmg) * mult)
	upgrade_applied.emit(&"blood_pact")
	return true


## 魂典 Soul Codex: spend XP for an upgrade (reuses _apply_upgrade + the D-B2 cap
## counter, WITHOUT the level-up panel flow). Returns false if XP is insufficient.
func execute_soul_codex(n: int, upgrade_id: StringName) -> bool:
	if not TradeFormulas.is_soul_codex_affordable(current_xp, n):
		return false
	current_xp = TradeFormulas.spend_soul_codex_xp(current_xp, n)
	experience_changed.emit(current_xp, xp_to_next_level, level)
	if upgrade_id != &"":
		var key := String(upgrade_id)
		_upgrade_pick_count[key] = int(_upgrade_pick_count.get(key, 0)) + 1
		_apply_upgrade(upgrade_id)
	return true


## 阴债 Yin Debt: free now, +20% move speed for 45s (the demon-tide debt is paid
## later, scheduled by StageDirector).
func execute_yin_debt() -> void:
	apply_yin_debt_speed(0.2, 45.0)
	upgrade_applied.emit(&"yin_debt")


func _owned_weapons() -> Array:
	var out: Array = []
	for w in [_talisman_weapon, _flying_sword_weapon, _thunder_law_weapon,
			_bagua_array_weapon, _explosive_talisman_weapon, _mountain_seal_weapon]:
		if w != null and w.visible:
			out.append(w)
	return out


# ─── Aggregate contact-damage ceiling (Combat GDD Core Rule 8 + Formula 7) ───

## Registers [param enemy] as a live contact attacker (called by Enemy when its
## damage area begins overlapping this player). Idempotent — re-registering an
## already-tracked enemy is a no-op so the original entry_time is preserved.
func register_contact_attacker(enemy: Node) -> void:
	if enemy == null:
		return
	for entry in _contact_attackers:
		if entry["enemy"] == enemy:
			return
	_contact_attackers.append({
		"enemy": enemy,
		"entry_time": Time.get_ticks_msec() / 1000.0,
	})


## Removes [param enemy] from the contact list (called by Enemy on damage-area
## exit, or implicitly pruned when the enemy is freed).
func unregister_contact_attacker(enemy: Node) -> void:
	for i in range(_contact_attackers.size() - 1, -1, -1):
		if _contact_attackers[i]["enemy"] == enemy:
			_contact_attackers.remove_at(i)


## Returns true iff [param enemy] is allowed to deal contact damage this frame —
## i.e. it is among the MAX_CONTACT_ATTACKERS most-recently-entered live contacts.
## Enemies outside the cap are gated out (no damage, no cooldown start), so they
## become eligible the instant a slot frees. Prunes freed entries as a side effect.
func is_contact_attacker_allowed(enemy: Node) -> bool:
	_prune_contact_attackers()
	return enemy in select_allowed_attackers(_contact_attackers, MAX_CONTACT_ATTACKERS)


## Pure selection helper (static so it is unit-testable without physics/timing):
## given contact entries [{enemy, entry_time}, ...] and a cap, return the array
## of enemy Nodes permitted to attack — the [param max_attackers] entries with
## the highest entry_time (most recently entered). If the list fits under the
## cap, every enemy is returned.
static func select_allowed_attackers(attackers: Array, max_attackers: int) -> Array:
	if attackers.size() <= max_attackers:
		var all_enemies: Array = []
		for entry in attackers:
			all_enemies.append(entry["enemy"])
		return all_enemies
	var sorted: Array = attackers.duplicate()
	sorted.sort_custom(func(a, b): return a["entry_time"] > b["entry_time"])
	var allowed: Array = []
	for i in range(max_attackers):
		allowed.append(sorted[i]["enemy"])
	return allowed


func _prune_contact_attackers() -> void:
	for i in range(_contact_attackers.size() - 1, -1, -1):
		if not is_instance_valid(_contact_attackers[i]["enemy"]):
			_contact_attackers.remove_at(i)


func gain_experience(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return

	current_xp += amount * maxf(xp_gain_multiplier, 0.0)
	var levels_gained := 0
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		level += 1
		xp_to_next_level = _get_next_xp_threshold(xp_to_next_level)
		levels_gained += 1
		level_reached.emit(level)

	experience_changed.emit(current_xp, xp_to_next_level, level)

	if levels_gained > 0:
		# W211: 孙悟空（ActiveSkillCharacter）每升 5/10/15/20 级额外解锁一次主动技能选择
		if _character_base is ActiveSkillCharacter:
			# 防御性 clamp：理论上 level >= levels_gained，但避免负数导致 range 异常
			var start_level := maxi(level - levels_gained, 0)
			for new_lv in range(start_level + 1, level + 1):
				if new_lv % 5 == 0 and new_lv <= 20:
					_pending_skill_choices += 1
		_queue_upgrade_choices(levels_gained)


func get_progression_state() -> Dictionary:
	return {
		"level": level,
		"current_xp": current_xp,
		"xp_to_next_level": xp_to_next_level,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"pickup_radius_bonus": pickup_radius_bonus,
		"xp_gain_multiplier": xp_gain_multiplier,
	}


func get_pickup_radius_bonus() -> float:
	return maxf(pickup_radius_bonus, 0.0)


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


func _die() -> void:
	if _is_dead:
		return

	_is_dead = true
	velocity = Vector2.ZERO
	died.emit()


func _ensure_input_actions() -> void:
	var action_events := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"skill_1": [KEY_1],
		"skill_2": [KEY_2],
		"skill_3": [KEY_3],
		"skill_4": [KEY_4],
	}

	for action_name in action_events.keys():
		var action_key := StringName(action_name)
		if not InputMap.has_action(action_key):
			InputMap.add_action(action_key)

		for keycode in action_events[action_name]:
			var event_keycode: int = keycode
			if _action_has_key(action_key, event_keycode):
				continue

			var event := InputEventKey.new()
			event.keycode = event_keycode
			InputMap.action_add_event(action_key, event)


func _action_has_key(action_name: StringName, keycode: int) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.keycode == keycode:
				return true

	return false


func _input(event: InputEvent) -> void:
	if _is_dead:
		return
	if get_tree().paused:
		return
	if event.is_action_pressed("skill_1"):
		_try_cast_skill(0)
	elif event.is_action_pressed("skill_2"):
		_try_cast_skill(1)
	elif event.is_action_pressed("skill_3"):
		_try_cast_skill(2)
	elif event.is_action_pressed("skill_4"):
		_try_cast_skill(3)


# W212-B：检测 _character_base 是否为 ActiveSkillCharacter，
# 是则转发到 cast_skill(slot)；否则静默忽略（修行者按 1/2/3/4 无反应）
func _try_cast_skill(slot: int) -> void:
	if _character_base == null:
		return
	if not (_character_base is ActiveSkillCharacter):
		# 非主动技能角色（如修行者）按键无反应，不输出 warning（避免 R002 噪音）
		return
	var skill_char := _character_base as ActiveSkillCharacter
	skill_char.cast_skill(slot)


func _get_next_xp_threshold(previous_threshold: float) -> float:
	var next_threshold := previous_threshold * maxf(xp_growth_multiplier, 1.0) + maxf(xp_growth_flat, 0.0)
	return ceilf(maxf(next_threshold, previous_threshold + 1.0))


func _queue_upgrade_choices(levels_gained: int) -> void:
	_pending_upgrade_choices += maxi(levels_gained, 0)
	if _is_selecting_upgrade:
		return

	_was_tree_paused_before_level_up = get_tree().paused
	_show_next_upgrade_choice()


func _show_next_upgrade_choice() -> void:
	# 常规升级优先（保持 v0.2 行为）
	if _pending_upgrade_choices > 0:
		_pending_upgrade_choices -= 1
		_is_selecting_upgrade = true
		_ensure_level_up_panel()
		if not is_instance_valid(_level_up_panel):
			_is_selecting_upgrade = false
			get_tree().paused = _was_tree_paused_before_level_up
			return
		_level_up_panel.show_choices(_get_random_upgrade_options())
		get_tree().paused = true
		return

	# W211: 常规升级处理完后，处理主动技能选择队列（孙悟空 Lv5/10/15/20）
	while _pending_skill_choices > 0:
		if not (_character_base is ActiveSkillCharacter):
			_pending_skill_choices = 0
			break
		# 与 _pending_upgrade_choices 处理顺序保持一致：先 -= 1 再处理
		_pending_skill_choices -= 1
		var skill_char := _character_base as ActiveSkillCharacter
		var skill_choices := skill_char.get_skill_choices()
		if skill_choices.is_empty():
			# 4 槽均已 Lv4 满级或未注册，跳过本次（cap 场景）
			continue
		_is_selecting_upgrade = true
		_ensure_level_up_panel()
		if not is_instance_valid(_level_up_panel):
			_is_selecting_upgrade = false
			get_tree().paused = _was_tree_paused_before_level_up
			return
		_level_up_panel.show_choices(skill_choices)
		get_tree().paused = true
		return

	# 全部队列处理完
	get_tree().paused = _was_tree_paused_before_level_up


func _ensure_level_up_panel() -> void:
	if is_instance_valid(_level_up_panel):
		return
	if level_up_panel_scene == null:
		push_error("Player has no level_up_panel_scene.")
		return

	var panel_instance := level_up_panel_scene.instantiate()
	if not panel_instance is LevelUpPanel:
		push_error("level_up_panel_scene must instantiate a LevelUpPanel.")
		panel_instance.queue_free()
		return

	_level_up_panel = panel_instance as LevelUpPanel
	_get_level_up_panel_parent().add_child(_level_up_panel)
	_level_up_panel.upgrade_selected.connect(_on_upgrade_selected)


func _get_level_up_panel_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene

	var parent := get_parent()
	if parent != null:
		return parent

	return self


func _get_random_upgrade_options() -> Array[Dictionary]:
	var options := _get_upgrade_pool()
	for i in range(options.size() - 1, 0, -1):
		var swap_index := _upgrade_rng.randi_range(0, i)
		var option := options[i]
		options[i] = options[swap_index]
		options[swap_index] = option

	var selected_options: Array[Dictionary] = []
	for i in range(mini(3, options.size())):
		selected_options.append(options[i])

	return selected_options


## Picks ONE upgrade for a Ghost Market 魂典 (Soul Codex) trade — a weapon-aware,
## D-B2-cap-respecting option from the level-up pool (unlock a locked weapon, or
## boost an owned one). Returns {} when the pool is exhausted (all capped/maxed),
## so the caller drops the Soul Codex offer (bad-luck protection, GDD Rule 3).
func pick_trade_upgrade() -> Dictionary:
	var options := _get_random_upgrade_options()
	if options.is_empty():
		return {}
	return options[0]


func _get_upgrade_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = [
		{
			"id": UPGRADE_TALISMAN_DAMAGE,
			"title": "追魂符威力 +10",
			"description": "追魂符击中妖物时伤害提高 10。"
		},
		{
			"id": UPGRADE_TALISMAN_COOLDOWN,
			"title": "追魂符施放 -10%",
			"description": "追魂符出手间隔缩短 10%。"
		},
		{
			"id": UPGRADE_TALISMAN_COUNT,
			"title": "追魂符数量 +1",
			"description": "每次施法额外祭出 1 枚追魂符。"
		},
		{
			"id": UPGRADE_TALISMAN_SPEED,
			"title": "追魂符飞行 +15%",
			"description": "追魂符飞行速度提高 15%。"
		},
		{
			"id": UPGRADE_MAX_HP,
			"title": "气血上限 +20",
			"description": "气血上限提高 20，并回复等量气血。"
		},
		{
			"id": UPGRADE_MOVE_SPEED,
			"title": "身法 +10%",
			"description": "行走身法提升，移动速度提高 10%。"
		},
		{
			"id": UPGRADE_PICKUP_RADIUS,
			"title": "摄取范围 +18",
			"description": "可从更远处吸纳修为灵光。"
		},
		{
			"id": UPGRADE_XP_GAIN,
			"title": "修为获取 +10%",
			"description": "吸收修为灵光时获得的修为提高 10%。"
		}
	]

	if _is_flying_sword_unlocked:
		pool.append({
			"id": UPGRADE_FLYING_SWORD_DAMAGE,
			"title": "飞剑威力 +8",
			"description": "飞剑斩妖伤害提高 8。"
		})
		pool.append({
			"id": UPGRADE_FLYING_SWORD_COOLDOWN,
			"title": "飞剑出鞘 -10%",
			"description": "飞剑出鞘间隔缩短 10%。"
		})
		pool.append({
			"id": UPGRADE_FLYING_SWORD_PIERCE,
			"title": "飞剑贯穿 +1",
			"description": "飞剑可额外贯穿 1 个妖物。"
		})
		pool.append({
			"id": UPGRADE_FLYING_SWORD_COUNT,
			"title": "飞剑数量 +1",
			"description": "每次御剑额外放出 1 柄飞剑。"
		})
	else:
		pool.append({
			"id": UPGRADE_UNLOCK_FLYING_SWORD,
			"title": "悟得飞剑",
			"description": "唤出飞剑护身，自动追击附近妖物。"
		})

	if _is_thunder_law_unlocked:
		pool.append({
			"id": UPGRADE_THUNDER_LAW_DAMAGE,
			"title": "雷电符咒威力 +10",
			"description": "雷电符咒落雷伤害提高 10。"
		})
		pool.append({
			"id": UPGRADE_THUNDER_LAW_COOLDOWN,
			"title": "雷电符咒施放 -10%",
			"description": "雷电符咒引雷间隔缩短 10%。"
		})
		pool.append({
			"id": UPGRADE_THUNDER_LAW_RADIUS,
			"title": "雷电符咒范围 +16",
			"description": "雷电符咒落雷范围扩大 16。"
		})
		pool.append({
			"id": UPGRADE_THUNDER_LAW_TARGET_COUNT,
			"title": "雷电符咒目标 +1",
			"description": "每次施咒额外轰击 1 个目标。"
		})
	else:
		pool.append({
			"id": UPGRADE_UNLOCK_THUNDER_LAW,
			"title": "悟得雷电符咒",
			"description": "绘成雷电符咒，轰击聚集的妖物。"
		})

	if _is_bagua_array_unlocked:
		pool.append({
			"id": UPGRADE_BAGUA_ARRAY_DAMAGE,
			"title": "八卦阵威力 +6",
			"description": "八卦阵灵光脉冲伤害提高 6。"
		})
		pool.append({
			"id": UPGRADE_BAGUA_ARRAY_RADIUS,
			"title": "八卦阵范围 +14",
			"description": "八卦阵伤害范围扩大 14。"
		})
		pool.append({
			"id": UPGRADE_BAGUA_ARRAY_ROTATION_SPEED,
			"title": "八卦阵运转 +20%",
			"description": "八卦阵旋转速度提高 20%。"
		})
		pool.append({
			"id": UPGRADE_BAGUA_ARRAY_TICK_RATE,
			"title": "八卦阵脉冲 -10%",
			"description": "八卦阵伤害脉冲间隔缩短 10%。"
		})
	else:
		pool.append({
			"id": UPGRADE_UNLOCK_BAGUA_ARRAY,
			"title": "悟得八卦阵",
			"description": "布下旋转阵势，持续伤及近身妖物。"
		})

	if _is_explosive_talisman_unlocked:
		pool.append({
			"id": UPGRADE_EXPLOSIVE_TALISMAN_RADIUS,
			"title": "爆裂符范围 +12",
			"description": "爆裂符爆发范围扩大 12。"
		})
		pool.append({
			"id": UPGRADE_EXPLOSIVE_TALISMAN_DAMAGE,
			"title": "爆裂符威力 +8",
			"description": "爆裂符爆发伤害提高 8。"
		})
		pool.append({
			"id": UPGRADE_EXPLOSIVE_TALISMAN_COUNT,
			"title": "爆裂符数量 +1",
			"description": "每次施法额外祭出 1 枚爆裂符。"
		})
		pool.append({
			"id": UPGRADE_EXPLOSIVE_TALISMAN_COOLDOWN,
			"title": "爆裂符施放 -10%",
			"description": "爆裂符施放间隔缩短 10%。"
		})
	else:
		pool.append({
			"id": UPGRADE_UNLOCK_EXPLOSIVE_TALISMAN,
			"title": "悟得爆裂符",
			"description": "祭出触敌即爆的符箓，震散妖群。"
		})

	if _is_mountain_seal_unlocked:
		pool.append({
			"id": UPGRADE_MOUNTAIN_SEAL_DAMAGE,
			"title": "山河印威力 +16",
			"description": "山河印砸落伤害提高 16。"
		})
		pool.append({
			"id": UPGRADE_MOUNTAIN_SEAL_RADIUS,
			"title": "山河印范围 +18",
			"description": "山河印砸落范围扩大 18。"
		})
		pool.append({
			"id": UPGRADE_MOUNTAIN_SEAL_COOLDOWN,
			"title": "山河印显化 -10%",
			"description": "山河印显化间隔缩短 10%。"
		})
	else:
		pool.append({
			"id": UPGRADE_UNLOCK_MOUNTAIN_SEAL,
			"title": "悟得山河印",
			"description": "凝出重印镇落，压制大片妖物。"
		})

	# W213: 孙悟空专属升级池（仅在 character_base 是 SunWukongV2 时添加）
	if _character_base is SunWukongV2:
		var swk := _character_base as SunWukongV2

		# 金箍棒强化（始终可选）
		var jingu_node := get_node_or_null("JinguBangV2")
		if jingu_node != null:
			pool.append({"id": "wukong_jingu_bang_damage", "title": "金箍棒·破煞 +5", "description": "金箍棒每次命中伤害提高 5。"})
			pool.append({"id": "wukong_jingu_bang_range", "title": "金箍棒·延伸 +15", "description": "金箍棒攻击半径扩大 15。"})
			pool.append({"id": "wukong_jingu_bang_arc", "title": "金箍棒·横扫 +20°", "description": "金箍棒扇形角度扩大 20 度。"})

		# 火眼金睛强化（未到上限才出现）
		if not swk.is_fire_eyes_maxed():
			pool.append({"id": "wukong_fire_eyes_bonus", "title": "火眼金睛·洞彻 +5%", "description": "对精英 / Boss 伤害额外提升 5%（上限 +35%）。"})

		# 毫毛分身强化（slot 0 解锁后）
		if swk.is_skill_unlocked(0):
			var hc_node := get_node_or_null("HairCloneV2")
			if hc_node != null:
				pool.append({"id": "wukong_hair_clone_count", "title": "毫毛分身 +1", "description": "每次召唤额外增加 1 只分身。"})
				pool.append({"id": "wukong_hair_clone_duration", "title": "毫毛分身 +2s", "description": "分身持续时间延长 2 秒。"})
				pool.append({"id": "wukong_hair_clone_damage", "title": "毫毛分身 +5", "description": "分身攻击伤害提高 5。"})

		# 筋斗云强化（slot 1 解锁后）
		if swk.is_skill_unlocked(1):
			var cs_node := get_node_or_null("CloudStep")
			if cs_node != null:
				pool.append({"id": "wukong_cloud_step_range", "title": "筋斗云·远翔 +50", "description": "筋斗云冲刺距离增加 50。"})
				pool.append({"id": "wukong_cloud_step_cooldown", "title": "筋斗云·疾风 -2s", "description": "筋斗云冷却缩短 2 秒。"})
				pool.append({"id": "wukong_cloud_step_damage", "title": "筋斗云·路径 +10", "description": "筋斗云路径伤害提高 10。"})

		# 七十二变强化（slot 2 解锁后）
		if swk.is_skill_unlocked(2):
			var tf_node := get_node_or_null("Transform72")
			if tf_node != null:
				pool.append({"id": "wukong_transform_duration", "title": "七十二变 +2s", "description": "变化持续时间延长 2 秒。"})
				pool.append({"id": "wukong_transform_cooldown", "title": "七十二变 -5s", "description": "变化冷却缩短 5 秒。"})
				pool.append({"id": "wukong_transform_form_boost", "title": "七十二变·精进 +10%", "description": "变化期间形态加成额外提升 10%。"})

		# 定身术强化（slot 3 解锁后）
		if swk.is_skill_unlocked(3):
			var im_node := get_node_or_null("Immobilize")
			if im_node != null:
				pool.append({"id": "wukong_immobilize_range", "title": "定身术 +50", "description": "定身术范围扩大 50。"})
				pool.append({"id": "wukong_immobilize_duration", "title": "定身术 +0.3s", "description": "定身术持续时间延长 0.3 秒。"})
				pool.append({"id": "wukong_immobilize_burst_damage", "title": "定身术·爆裂 +10", "description": "Lv3+ 符印爆裂伤害提高 10。"})

	if _character_base != null:
		var allowed: Array[String] = _character_base._get_allowed_upgrade_ids()
		if not allowed.is_empty():
			# 修复 BUG-T207-02：用字面 String 而非 StringName 常量，避免 Array[String] 类型不匹配
			var common_ids: Array[String] = [
				"max_hp", "move_speed", "pickup_radius", "xp_gain"
			]
			var filtered: Array[Dictionary] = []
			for item in pool:
				var item_id: String = item.get("id", "")
				if item_id in common_ids or item_id in allowed:
					filtered.append(item)
			pool = filtered

	# D-B2 (Level Up Pool GDD r2, Rule 6): drop any upgrade that has reached its
	# per-upgrade stack cap, BEFORE the panel shuffle, so capped upgrades never
	# appear as a choice. Enforces the Combat 5× source-modifier ceiling as a
	# hard cap (damage upgrades cap at 3 → 4.75× max).
	var capped: Array[Dictionary] = []
	for entry in pool:
		var entry_id := String(entry.get("id", ""))
		if int(_upgrade_pick_count.get(entry_id, 0)) < _get_upgrade_max_stacks(entry_id):
			capped.append(entry)
	return capped


## D-B2 per-upgrade stack caps (Level Up Pool GDD r2, Rule 6), categorized by
## upgrade_id suffix. Values are the GDD's starting points — playtest-tunable
## (GDD line 213). Caps:
##   *_damage → 3 (3×(+10) on base-8 weapon = 38 = 4.75× ≤ Combat 5× ceiling)
##   *_pierce → 2 (anti dominant-strategy cluster wipe, D-W1)
##   *_count / *_target_count → 3
##   *_cooldown → 5
##   unlock_* → 1 (also gated by the _is_<weapon>_unlocked flag, belt-and-suspenders)
##   everything else (max_hp / move_speed / pickup_radius / xp_gain / radius / etc.) → 5
func _get_upgrade_max_stacks(upgrade_id: String) -> int:
	if upgrade_id.begins_with("unlock_"):
		return 1
	if upgrade_id.ends_with("_damage"):
		return 3
	if upgrade_id.ends_with("_pierce"):
		return 2
	if upgrade_id.ends_with("_count"):  # covers _count and _target_count
		return 3
	if upgrade_id.ends_with("_cooldown"):
		return 5
	return 5


func _on_upgrade_selected(upgrade_id: StringName) -> void:
	# D-B2: record the pick so _get_upgrade_pool can enforce the per-upgrade cap.
	# Key by String — pool ids are a mix of StringName (UPGRADE_* constants) and
	# String (wukong_* literals), and Godot 4 treats those as distinct dict keys.
	var pick_key := String(upgrade_id)
	_upgrade_pick_count[pick_key] = int(_upgrade_pick_count.get(pick_key, 0)) + 1
	_apply_upgrade(upgrade_id)
	if is_instance_valid(_level_up_panel):
		_level_up_panel.hide_panel()

	_is_selecting_upgrade = false
	# W211: 同时考虑常规升级 + 主动技能选择两个队列
	if _pending_upgrade_choices > 0 or _pending_skill_choices > 0:
		_show_next_upgrade_choice()
	else:
		get_tree().paused = _was_tree_paused_before_level_up


func _apply_upgrade(upgrade_id: StringName) -> void:
	# W211: 主动技能升级（wukong_skill_*）转发到 ActiveSkillCharacter
	var id_str := String(upgrade_id)
	if id_str.begins_with("wukong_skill_"):
		if _character_base is ActiveSkillCharacter:
			(_character_base as ActiveSkillCharacter).apply_skill_upgrade(id_str)
			upgrade_applied.emit(upgrade_id)
		else:
			push_warning("Skill upgrade %s but no ActiveSkillCharacter attached" % id_str)
		return

	# W213: 孙悟空专属升级（wukong_jingu_bang_* / wukong_fire_eyes_* / wukong_hair_clone_* 等）
	if id_str.begins_with("wukong_") and not id_str.begins_with("wukong_skill_"):
		if not (_character_base is SunWukongV2):
			push_warning("W213 upgrade %s but no SunWukongV2 attached" % id_str)
			return
		var swk := _character_base as SunWukongV2
		match id_str:
			"wukong_jingu_bang_damage":
				var n := get_node_or_null("JinguBangV2")
				if n != null:
					n.damage_bonus += 5.0
			"wukong_jingu_bang_range":
				var n := get_node_or_null("JinguBangV2")
				if n != null:
					n.radius_bonus += 15.0
			"wukong_jingu_bang_arc":
				var n := get_node_or_null("JinguBangV2")
				if n != null:
					n.arc_bonus += 20.0
			"wukong_fire_eyes_bonus":
				swk.add_fire_eyes_bonus()
			"wukong_hair_clone_count":
				var n := get_node_or_null("HairCloneV2")
				if n != null:
					n.count_bonus += 1
			"wukong_hair_clone_duration":
				var n := get_node_or_null("HairCloneV2")
				if n != null:
					n.lifetime_bonus += 2.0
			"wukong_hair_clone_damage":
				var n := get_node_or_null("HairCloneV2")
				if n != null:
					n.damage_bonus += 5.0
			"wukong_cloud_step_range":
				var n := get_node_or_null("CloudStep")
				if n != null:
					n.dash_distance_bonus += 50.0
			"wukong_cloud_step_cooldown":
				swk.reduce_skill_max_cd(1, 2.0)
			"wukong_cloud_step_damage":
				var n := get_node_or_null("CloudStep")
				if n != null:
					n.path_damage_bonus += 10.0
			"wukong_transform_duration":
				var n := get_node_or_null("Transform72")
				if n != null:
					n.duration_bonus += 2.0
			"wukong_transform_cooldown":
				swk.reduce_skill_max_cd(2, 5.0)
			"wukong_transform_form_boost":
				var n := get_node_or_null("Transform72")
				if n != null:
					n.form_boost_bonus += 0.1
			"wukong_immobilize_range":
				var n := get_node_or_null("Immobilize")
				if n != null:
					n.radius_bonus += 50.0
			"wukong_immobilize_duration":
				var n := get_node_or_null("Immobilize")
				if n != null:
					n.duration_bonus += 0.3
			"wukong_immobilize_burst_damage":
				var n := get_node_or_null("Immobilize")
				if n != null:
					n.burst_damage_bonus += 10.0
			_:
				push_warning("Unknown Sun Wukong upgrade: %s" % id_str)
				return
		upgrade_applied.emit(upgrade_id)
		return

	match upgrade_id:
		UPGRADE_TALISMAN_DAMAGE:
			if _talisman_weapon != null:
				_talisman_weapon.damage += 10.0
		UPGRADE_TALISMAN_COOLDOWN:
			if _talisman_weapon != null:
				_talisman_weapon.cooldown = maxf(_talisman_weapon.cooldown * 0.9, WeaponBase.MIN_COOLDOWN)
		UPGRADE_TALISMAN_COUNT:
			if _talisman_weapon != null:
				_talisman_weapon.projectile_count += 1
		UPGRADE_TALISMAN_SPEED:
			if _talisman_weapon != null:
				_talisman_weapon.projectile_speed *= 1.15
		UPGRADE_UNLOCK_FLYING_SWORD:
			_is_flying_sword_unlocked = true
			_set_weapon_unlocked(_flying_sword_weapon, true)
		UPGRADE_FLYING_SWORD_DAMAGE:
			if _flying_sword_weapon != null:
				_flying_sword_weapon.damage += 8.0
		UPGRADE_FLYING_SWORD_COOLDOWN:
			if _flying_sword_weapon != null:
				_flying_sword_weapon.cooldown = maxf(_flying_sword_weapon.cooldown * 0.9, WeaponBase.MIN_COOLDOWN)
		UPGRADE_FLYING_SWORD_PIERCE:
			if _flying_sword_weapon != null:
				_flying_sword_weapon.pierce_count += 1
		UPGRADE_FLYING_SWORD_COUNT:
			if _flying_sword_weapon != null:
				_flying_sword_weapon.projectile_count += 1
		UPGRADE_UNLOCK_THUNDER_LAW:
			_is_thunder_law_unlocked = true
			_set_weapon_unlocked(_thunder_law_weapon, true)
		UPGRADE_THUNDER_LAW_DAMAGE:
			if _thunder_law_weapon != null:
				_thunder_law_weapon.damage += 10.0
		UPGRADE_THUNDER_LAW_COOLDOWN:
			if _thunder_law_weapon != null:
				_thunder_law_weapon.cooldown = maxf(_thunder_law_weapon.cooldown * 0.9, WeaponBase.MIN_COOLDOWN)
		UPGRADE_THUNDER_LAW_RADIUS:
			if _thunder_law_weapon != null:
				_thunder_law_weapon.radius += 16.0
		UPGRADE_THUNDER_LAW_TARGET_COUNT:
			if _thunder_law_weapon != null:
				_thunder_law_weapon.target_count += 1
		UPGRADE_UNLOCK_BAGUA_ARRAY:
			_is_bagua_array_unlocked = true
			_set_weapon_unlocked(_bagua_array_weapon, true)
		UPGRADE_BAGUA_ARRAY_DAMAGE:
			if _bagua_array_weapon != null:
				_bagua_array_weapon.damage += 6.0
		UPGRADE_BAGUA_ARRAY_RADIUS:
			if _bagua_array_weapon != null:
				_bagua_array_weapon.radius += 14.0
		UPGRADE_BAGUA_ARRAY_ROTATION_SPEED:
			if _bagua_array_weapon != null:
				_bagua_array_weapon.rotation_speed *= 1.2
		UPGRADE_BAGUA_ARRAY_TICK_RATE:
			if _bagua_array_weapon != null:
				_bagua_array_weapon.tick_rate = maxf(_bagua_array_weapon.tick_rate * 0.9, WeaponBase.MIN_COOLDOWN)
		UPGRADE_UNLOCK_EXPLOSIVE_TALISMAN:
			_is_explosive_talisman_unlocked = true
			_set_weapon_unlocked(_explosive_talisman_weapon, true)
		UPGRADE_EXPLOSIVE_TALISMAN_RADIUS:
			if _explosive_talisman_weapon != null:
				_explosive_talisman_weapon.explosion_radius += 12.0
		UPGRADE_EXPLOSIVE_TALISMAN_DAMAGE:
			if _explosive_talisman_weapon != null:
				_explosive_talisman_weapon.explosion_damage += 8.0
		UPGRADE_EXPLOSIVE_TALISMAN_COUNT:
			if _explosive_talisman_weapon != null:
				_explosive_talisman_weapon.projectile_count += 1
		UPGRADE_EXPLOSIVE_TALISMAN_COOLDOWN:
			if _explosive_talisman_weapon != null:
				_explosive_talisman_weapon.cooldown = maxf(_explosive_talisman_weapon.cooldown * 0.9, WeaponBase.MIN_COOLDOWN)
		UPGRADE_UNLOCK_MOUNTAIN_SEAL:
			_is_mountain_seal_unlocked = true
			_set_weapon_unlocked(_mountain_seal_weapon, true)
		UPGRADE_MOUNTAIN_SEAL_DAMAGE:
			if _mountain_seal_weapon != null:
				_mountain_seal_weapon.damage += 16.0
		UPGRADE_MOUNTAIN_SEAL_RADIUS:
			if _mountain_seal_weapon != null:
				_mountain_seal_weapon.radius += 18.0
		UPGRADE_MOUNTAIN_SEAL_COOLDOWN:
			if _mountain_seal_weapon != null:
				_mountain_seal_weapon.cooldown = maxf(_mountain_seal_weapon.cooldown * 0.9, WeaponBase.MIN_COOLDOWN)
		UPGRADE_MAX_HP:
			max_hp += 20.0
			current_hp = minf(current_hp + 20.0, max_hp)
			_update_health_bar()
			health_changed.emit(current_hp, max_hp)
		UPGRADE_MOVE_SPEED:
			move_speed *= 1.1
		UPGRADE_PICKUP_RADIUS:
			pickup_radius_bonus += 18.0
		UPGRADE_XP_GAIN:
			xp_gain_multiplier *= 1.1
		_:
			push_warning("Unknown upgrade selected: %s" % String(upgrade_id))
			return

	upgrade_applied.emit(upgrade_id)


func _set_weapon_unlocked(weapon: WeaponBase, is_unlocked: bool) -> void:
	if weapon == null:
		return

	if is_unlocked:
		weapon.process_mode = Node.PROCESS_MODE_INHERIT
		weapon.visible = true
	else:
		weapon.process_mode = Node.PROCESS_MODE_DISABLED
		weapon.visible = false


# 由 CharacterBase 子类调用，控制玩家无敌状态（七十二变等）
func set_invincible(value: bool) -> void:
	_is_invincible = value


# 由 CharacterBase 子类调用，临时调整移速倍率
func set_speed_multiplier(value: float) -> void:
	_speed_multiplier = value


# 由 CharacterBase 子类调用，临时调整伤害倍率（T204+ 武器接入）
func set_damage_multiplier(value: float) -> void:
	_damage_multiplier = value


# EnemySpawner 击杀信号转发到角色基类
func _on_enemy_killed(enemy: Node) -> void:
	if _character_base != null:
		_character_base._on_kill(enemy)
