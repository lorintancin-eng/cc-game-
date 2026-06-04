## Integration tests for the CombatEvents bus — Story 003 (ADR-0006 §Decision 4 / R-1).
##
## Validates that:
##   1. Enemy._die() emits CombatEvents.enemy_killed exactly once per death.
##   2. The EnemyKillData payload is value-only (no Node ref) with correct types.
##   3. The emit happens before queue_free (payload is valid at signal time).
##   4. Three enemy deaths produce exactly three signal emissions (no leaks).
##   5. CombatEvents exposes only the signal (relay-purity / no state).
##
## Enemy nodes are instantiated via .new() (no scene tree required).
## xp_drop_value is set to 0.0 to skip _drop_experience() (XP drop guard).
## queue_free() on a detached node is a no-op — no crash.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gtest=res://tests/integration/combat/combat_events_bus_test.gd -gexit

extends "res://tests/helpers/test_base.gd"

const EnemyScript := preload("res://scripts/enemy/enemy.gd")

var _captured_kill_data: Array[EnemyKillData] = []
var _capture_connection: Callable


func before_each() -> void:
	super.before_each()
	_captured_kill_data = []
	_capture_connection = func(kd: EnemyKillData) -> void:
		_captured_kill_data.append(kd)
	CombatEvents.enemy_killed.connect(_capture_connection)
	watch_signals(CombatEvents)


func after_each() -> void:
	if CombatEvents.enemy_killed.is_connected(_capture_connection):
		CombatEvents.enemy_killed.disconnect(_capture_connection)
	super.after_each()


## Helper: create a minimal enemy ready for _die() without scene-tree side effects.
func _make_dying_enemy(
	source_element: String = "neutral",
	damage_amount: float = 10.0,
	death_position: Vector2 = Vector2(50.0, 75.0)
) -> Enemy:
	var enemy: Enemy = EnemyScript.new()
	autofree(enemy)
	enemy.xp_drop_value = 0.0            # skip _drop_experience()
	enemy._last_kill_source_element = source_element
	enemy._last_damage_amount = damage_amount
	enemy.global_position = death_position
	return enemy


# ─── 1. Single kill → exactly one signal emission ────────────────────────

func test_combat_events_enemy_killed_emits_once_per_death() -> void:
	# Arrange
	var enemy := _make_dying_enemy()

	# Act
	enemy._die()

	# Assert
	assert_signal_emit_count(CombatEvents, "enemy_killed", 1,
		"enemy_killed must fire exactly once per enemy death")


# ─── 2. Payload fields are value types (String, float, Vector2 — no Node) ─

func test_combat_events_kill_data_payload_has_value_types_only() -> void:
	# Arrange
	var enemy := _make_dying_enemy("neutral", 15.0, Vector2(10.0, 20.0))

	# Act
	enemy._die()

	# Assert — payload captured; verify types are value types (no Node ref)
	assert_eq(_captured_kill_data.size(), 1, "one kill_data captured")
	var kd: EnemyKillData = _captured_kill_data[0]
	assert_true(kd.source_element is String,
		"source_element must be a String (value type)")
	assert_true(kd.damage is float,
		"damage must be a float value type")
	assert_true(kd.position is Vector2,
		"position must be a Vector2 (value type)")
	# Confirm it's a RefCounted value object (NOT a Node — value-only payload, R-1)
	assert_true(kd is RefCounted,
		"EnemyKillData is a RefCounted value object, not a Node")


# ─── 3. Emit happens before queue_free — payload is valid at signal time ──

func test_combat_events_payload_valid_at_signal_time() -> void:
	# Arrange — known values to check in the captured payload
	var expected_elem: String = "neutral"
	var expected_damage: float = 42.0
	var expected_pos := Vector2(100.0, 200.0)
	var enemy := _make_dying_enemy(expected_elem, expected_damage, expected_pos)

	# Act
	enemy._die()

	# Assert — if emit were AFTER queue_free, the data would be lost / crashed
	assert_eq(_captured_kill_data.size(), 1,
		"payload must have been captured before queue_free")
	var kd: EnemyKillData = _captured_kill_data[0]
	assert_eq(kd.source_element, expected_elem,
		"source_element matches at emit time")
	assert_float_eq(kd.damage, expected_damage, 0.001,
		"damage matches at emit time")
	assert_float_eq(kd.position.x, expected_pos.x, 0.001,
		"position.x matches at emit time")
	assert_float_eq(kd.position.y, expected_pos.y, 0.001,
		"position.y matches at emit time")


# ─── 4. Three deaths → exactly three emissions (connect-once bus) ─────────

func test_combat_events_three_deaths_emit_exactly_three_times() -> void:
	# Arrange
	var e1 := _make_dying_enemy("neutral", 5.0, Vector2(0.0, 0.0))
	var e2 := _make_dying_enemy("neutral", 10.0, Vector2(10.0, 10.0))
	var e3 := _make_dying_enemy("neutral", 20.0, Vector2(20.0, 20.0))

	# Act
	e1._die()
	e2._die()
	e3._die()

	# Assert
	assert_signal_emit_count(CombatEvents, "enemy_killed", 3,
		"three deaths must produce exactly three enemy_killed emissions")
	assert_eq(_captured_kill_data.size(), 3,
		"exactly three EnemyKillData payloads captured")


# ─── 5. Relay purity: CombatEvents exposes only the signal (no state) ─────

func test_combat_events_relay_purity_no_state_properties() -> void:
	# Inspect CombatEvents for state variables. The bus must only expose
	# 'enemy_killed'. We verify it has no exported or non-signal properties
	# beyond what Node provides by checking the script's property list.
	#
	# Approach: CombatEvents is an autoload Node. Its script defines only
	# the signal — no var declarations. We assert that the custom property
	# list (from the script, not from Node internals) is empty.
	# Only SCRIPT-declared member variables carry PROPERTY_USAGE_SCRIPT_VARIABLE.
	# Inherited Node properties (owner, multiplayer, ...) and category headers do not,
	# so this isolates CombatEvents' own state without a fragile name blocklist.
	var script_props: Array[String] = []
	for prop: Dictionary in CombatEvents.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			script_props.append(str(prop["name"]))

	assert_eq(script_props.size(), 0,
		"CombatEvents must define NO state variables (pure relay) — found: %s" % str(script_props))


# ─── 6. source_element is 'neutral' until Story 005, damage and position correct ─

func test_combat_events_stub_values_source_element_neutral_damage_and_position() -> void:
	# Arrange — Story 005 will wire source.element; until then, stub is "neutral".
	var expected_damage: float = 30.0
	var expected_pos := Vector2(77.0, 88.0)
	var enemy := _make_dying_enemy("neutral", expected_damage, expected_pos)

	# Act
	enemy._die()

	# Assert
	assert_eq(_captured_kill_data.size(), 1, "one payload captured")
	var kd: EnemyKillData = _captured_kill_data[0]
	assert_eq(kd.source_element, "neutral",
		"source_element must be 'neutral' until Story 005 wires weapon element")
	assert_float_eq(kd.damage, expected_damage, 0.001,
		"damage must equal the last take_damage amount")
	assert_float_eq(kd.position.x, expected_pos.x, 0.001,
		"position.x must be the enemy's global_position.x at death")
	assert_float_eq(kd.position.y, expected_pos.y, 0.001,
		"position.y must be the enemy's global_position.y at death")
