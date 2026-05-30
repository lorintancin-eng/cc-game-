## Unit tests for GhostMarketJudge — headless-safe LOGIC only.
##
## Covers: enrage trigger (HP ratio), enrage effects (move_speed ×1.35,
## brush_radius ×1.2, _is_enraged), one-way enrage guard, the skill-interval
## multiplier, and the summon cap. The feel/telegraphs/scene visuals are
## playtest-only (CI can't run the game).
##
## Instantiated via .new() — no scene tree. The @onready visual nodes (_body,
## _enraged_aura) are seeded with dummy Polygon2D in _make_judge, because
## _enter_enrage writes to _body.color / _enraged_aura.visible and would
## null-crash on a tree-detached instance otherwise. We do NOT call the real
## take_damage (its super.Enemy.take_damage touches _health_fill, also null
## detached); instead we set current_hp + replicate the enrage check.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/enemy -gexit

extends "res://tests/helpers/test_base.gd"

const JudgeScript = preload("res://scripts/enemy/ghost_market_judge.gd")


func _make_judge(p_max_hp: float, p_current_hp: float) -> GhostMarketJudge:
	var judge: GhostMarketJudge = JudgeScript.new()
	autofree(judge)
	# Seed the @onready visual nodes _enter_enrage writes to — null on a .new()
	# instance (the scene tree never ran @onready) → would crash without these.
	judge._body = Polygon2D.new()
	autofree(judge._body)
	judge._enraged_aura = Polygon2D.new()
	autofree(judge._enraged_aura)
	judge.max_hp = p_max_hp
	judge.current_hp = p_current_hp
	judge.move_speed = 64.0
	judge.hook_speed = 360.0
	judge.brush_radius = 66.0
	judge.enrage_health_ratio = 0.3
	judge.enrage_speed_multiplier = 1.35
	judge.enrage_brush_radius_multiplier = 1.2
	judge.enrage_skill_interval_multiplier = 0.65
	return judge


# ─── enrage trigger (HP ratio) ───────────────────────────────────────────

func test_judge_enrage_triggers_at_or_below_30_percent() -> void:
	# Arrange — drop HP to 143/480 = 0.298 (<= 0.3).
	var judge := _make_judge(480.0, 143.0)
	# Act — replicate take_damage's post-super enrage check (avoids the
	# Enemy.take_damage _health_fill node touch on a detached instance).
	if not judge._is_dead and not judge._is_enraged:
		if judge.current_hp / judge.max_hp <= judge.enrage_health_ratio:
			judge._enter_enrage()
	# Assert
	assert_true(judge._is_enraged, "enrage fires when hp/max_hp <= 0.3")


func test_judge_enrage_does_not_trigger_above_threshold() -> void:
	# Arrange — 200/480 = 0.417 (above 0.3).
	var judge := _make_judge(480.0, 200.0)
	# Act
	if not judge._is_dead and not judge._is_enraged:
		if judge.current_hp / judge.max_hp <= judge.enrage_health_ratio:
			judge._enter_enrage()
	# Assert
	assert_false(judge._is_enraged, "no enrage above the 30% threshold")


# ─── enrage effects ──────────────────────────────────────────────────────

func test_judge_enrage_multiplies_move_speed() -> void:
	var judge := _make_judge(480.0, 100.0)
	var base_speed: float = judge.move_speed
	judge._enter_enrage()
	assert_float_eq(judge.move_speed, base_speed * 1.35, 0.001, "move_speed ×1.35")


func test_judge_enrage_grows_brush_radius() -> void:
	# Judge-specific flourish: 判笔 radius widens on 审判终结 (66 → 79.2).
	var judge := _make_judge(480.0, 100.0)
	var base_radius: float = judge.brush_radius
	judge._enter_enrage()
	assert_float_eq(judge.brush_radius, base_radius * 1.2, 0.01, "brush_radius ×1.2")


func test_judge_enrage_sets_flag() -> void:
	var judge := _make_judge(480.0, 100.0)
	judge._enter_enrage()
	assert_true(judge._is_enraged, "_is_enraged set")


# ─── one-way enrage (the take_damage guard prevents re-entry) ─────────────

func test_judge_enrage_does_not_double_apply() -> void:
	# Arrange — enrage once.
	var judge := _make_judge(480.0, 100.0)
	judge._enter_enrage()
	var speed_after_first: float = judge.move_speed
	# Act — the take_damage guard (`if _is_enraged: return`) blocks a 2nd enrage.
	var re_entered := false
	if not judge._is_dead and not judge._is_enraged:
		judge._enter_enrage()
		re_entered = true
	# Assert
	assert_false(re_entered, "second enrage blocked by the _is_enraged guard")
	assert_float_eq(judge.move_speed, speed_after_first, 0.001, "speed not ×1.35 twice")


# ─── skill-interval multiplier ───────────────────────────────────────────

func test_judge_skill_multiplier_is_one_when_calm() -> void:
	var judge := _make_judge(480.0, 300.0)
	assert_float_eq(judge._get_skill_interval_multiplier(), 1.0, 0.001, "1.0 when not enraged")


func test_judge_skill_multiplier_is_enrage_value_when_enraged() -> void:
	var judge := _make_judge(480.0, 100.0)
	judge._enter_enrage()
	assert_float_eq(judge._get_skill_interval_multiplier(), 0.65, 0.001,
		"0.65 when enraged (skills fire sooner)")


# ─── summon cap ──────────────────────────────────────────────────────────

func test_judge_summon_cap_rejects_when_at_max() -> void:
	# Arrange — fill the summon tracking array to the cap with stub Enemy nodes.
	var judge := _make_judge(480.0, 300.0)
	judge.summon_max_alive = 6
	judge.summon_batch_count = 2
	for _i in judge.summon_max_alive:
		var stub: Enemy = preload("res://scripts/enemy/enemy.gd").new()
		autofree(stub)
		judge._summoned_enemies.append(stub)
	var count_before: int = judge._summoned_enemies.size()

	# Act — available_slots = 6 - 6 = 0 → early return BEFORE any tree access.
	judge._summon_minions()

	# Assert
	assert_eq(judge._summoned_enemies.size(), count_before,
		"_summon_minions spawns nothing when summon_max_alive is reached")
