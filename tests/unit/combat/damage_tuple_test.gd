## Unit tests for DamageTypes (scripts/combat/damage_types.gd) — covers Combat
## Story 001 AC-04, AC-05, AC-19.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gtest=res://tests/unit/combat -gexit

extends "res://tests/helpers/test_base.gd"

const DamageTypesScript = preload("res://scripts/combat/damage_types.gd")

# Mock nodes shared across tests. Created in before_each, freed in after_each
# to avoid orphan-node warnings.
var _source_node: Node
var _player_node: Node
var _enemy_node: Node
var _ally_node: Node


func before_each() -> void:
	super.before_each()
	_source_node = Node.new()
	_source_node.name = "MockSource"
	_player_node = Node.new()
	_player_node.name = "MockPlayer"
	_player_node.add_to_group(&"player")
	_enemy_node = Node.new()
	_enemy_node.name = "MockEnemy"
	_enemy_node.add_to_group(&"enemies")
	_ally_node = Node.new()
	_ally_node.name = "MockAlly"
	_ally_node.add_to_group(&"allies")


func after_each() -> void:
	for node in [_source_node, _player_node, _enemy_node, _ally_node]:
		if is_instance_valid(node):
			node.free()
	_source_node = null
	_player_node = null
	_enemy_node = null
	_ally_node = null
	super.after_each()


# ─── AC-05: 5-field tuple validation ──────────────────────────────────────

func test_make_payload_returns_all_5_fields() -> void:
	# Arrange
	var amount: float = 12.0
	# Act
	var payload: Dictionary = DamageTypesScript.make_payload(
		_source_node, _enemy_node, amount,
		DamageTypesScript.DamageType.DIRECT,
		DamageTypesScript.SourceKind.WEAPON
	)
	# Assert — all 5 required keys present with correct values
	assert_eq(payload.size(), 5, "Payload should have exactly 5 keys")
	assert_true(payload.has("source"), "Payload missing 'source' key")
	assert_true(payload.has("target"), "Payload missing 'target' key")
	assert_true(payload.has("amount"), "Payload missing 'amount' key")
	assert_true(payload.has("damage_type"), "Payload missing 'damage_type' key")
	assert_true(payload.has("source_kind"), "Payload missing 'source_kind' key")
	assert_eq(payload["source"], _source_node, "source should be the mock source")
	assert_eq(payload["target"], _enemy_node, "target should be the mock enemy")
	assert_float_eq(payload["amount"], 12.0)
	assert_eq(payload["damage_type"], DamageTypesScript.DamageType.DIRECT)
	assert_eq(payload["source_kind"], DamageTypesScript.SourceKind.WEAPON)


func test_validate_payload_accepts_well_formed_dict() -> void:
	# Arrange
	var payload: Dictionary = DamageTypesScript.make_payload(
		_source_node, _enemy_node, 5.0,
		DamageTypesScript.DamageType.TICK,
		DamageTypesScript.SourceKind.WEAPON
	)
	# Act
	var result: bool = DamageTypesScript.validate_payload(payload)
	# Assert
	assert_true(result, "Well-formed payload should validate true")


func test_validate_payload_detects_missing_keys() -> void:
	# Arrange — manually-constructed dict missing 'source_kind'
	var bad_payload: Dictionary = {
		"source": _source_node,
		"target": _enemy_node,
		"amount": 5.0,
		"damage_type": DamageTypesScript.DamageType.DIRECT,
	}
	# Act
	var result: bool = DamageTypesScript.validate_payload(bad_payload)
	# Assert
	assert_false(result, "Payload missing 'source_kind' must fail validation")


func test_validate_payload_detects_bad_enum_value() -> void:
	# Arrange — payload with out-of-range damage_type
	var bad_payload: Dictionary = {
		"source": _source_node,
		"target": _enemy_node,
		"amount": 5.0,
		"damage_type": 99,                                  # invalid enum
		"source_kind": DamageTypesScript.SourceKind.WEAPON,
	}
	# Act
	var result: bool = DamageTypesScript.validate_payload(bad_payload)
	# Assert
	assert_false(result, "Out-of-range damage_type must fail validation")


# ─── AC-04: Friendly-fire skip ────────────────────────────────────────────

func test_is_friendly_fire_weapon_to_player_returns_true() -> void:
	# Weapon damage to player → friendly fire skip applies
	var result: bool = DamageTypesScript.is_friendly_fire(
		DamageTypesScript.SourceKind.WEAPON, _player_node
	)
	assert_true(result, "WEAPON → player must be friendly fire")


func test_is_friendly_fire_weapon_to_ally_returns_true() -> void:
	# Weapon damage to ally (e.g. hair clones) → friendly fire skip applies
	var result: bool = DamageTypesScript.is_friendly_fire(
		DamageTypesScript.SourceKind.WEAPON, _ally_node
	)
	assert_true(result, "WEAPON → ally must be friendly fire")


func test_is_friendly_fire_weapon_to_enemy_returns_false() -> void:
	# Weapon damage to enemy → NOT friendly fire, damage applies normally
	var result: bool = DamageTypesScript.is_friendly_fire(
		DamageTypesScript.SourceKind.WEAPON, _enemy_node
	)
	assert_false(result, "WEAPON → enemy must NOT be friendly fire")


func test_is_friendly_fire_enemy_to_player_returns_false() -> void:
	# Enemy contact damage to player — normal damage event, no friendly-fire skip
	var result: bool = DamageTypesScript.is_friendly_fire(
		DamageTypesScript.SourceKind.ENEMY, _player_node
	)
	assert_false(result, "ENEMY → player must NOT be friendly fire")


func test_is_friendly_fire_environment_to_player_returns_false() -> void:
	# Environment burn patch on player → DOES damage (per Combat GDD Edge Cases)
	var result: bool = DamageTypesScript.is_friendly_fire(
		DamageTypesScript.SourceKind.ENVIRONMENT, _player_node
	)
	assert_false(result, "ENVIRONMENT → player must NOT be friendly fire (env damages player)")


# ─── AC-19: Zero-damage + negative damage clamp ───────────────────────────

func test_zero_amount_creates_valid_payload() -> void:
	# amount = 0 is a legitimate status-only probe — payload must still be well-formed
	var payload: Dictionary = DamageTypesScript.make_payload(
		_source_node, _enemy_node, 0.0,
		DamageTypesScript.DamageType.DIRECT,
		DamageTypesScript.SourceKind.WEAPON
	)
	assert_float_eq(payload["amount"], 0.0)
	assert_true(DamageTypesScript.validate_payload(payload),
		"Zero-amount payload should still validate (consumer decides whether to emit damage_taken)")


func test_negative_amount_clamps_to_zero() -> void:
	# Negative damage values must NOT heal through this path — clamped to 0.0
	var payload: Dictionary = DamageTypesScript.make_payload(
		_source_node, _enemy_node, -5.0,
		DamageTypesScript.DamageType.DIRECT,
		DamageTypesScript.SourceKind.WEAPON
	)
	assert_float_eq(payload["amount"], 0.0,
		0.001,
		"Negative amount must clamp to 0.0 (no healing-through-damage exploit)")
