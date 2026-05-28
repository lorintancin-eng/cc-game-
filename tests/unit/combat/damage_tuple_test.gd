## Unit tests for DamageTypes (scripts/combat/damage_types.gd) — covers Combat
## Story 001 AC-04, AC-05, AC-19 plus code-review findings (MT-01..04 + sub-threshold).
##
## Test function naming follows `.claude/rules/test-standards.md` 3-segment
## pattern: test_[system]_[scenario]_[expected_result] (system = "damage_types").
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gtest=res://tests/unit/combat -gexit

extends "res://tests/helpers/test_base.gd"

const DamageTypesScript = preload("res://scripts/combat/damage_types.gd")

# Mock nodes shared across tests. Created in before_each, freed in after_each.
# Note: Godot 4 allows add_to_group() / is_in_group() on nodes that are NOT in
# the scene tree — group membership is tracked on the node itself.
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

func test_damage_types_make_payload_returns_all_5_fields() -> void:
	var amount: float = 12.0
	var payload: Dictionary = DamageTypesScript.make_payload(
		_source_node, _enemy_node, amount,
		DamageTypesScript.DamageType.DIRECT,
		DamageTypesScript.SourceKind.WEAPON
	)
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


func test_damage_types_validate_payload_accepts_well_formed_dict() -> void:
	var payload: Dictionary = DamageTypesScript.make_payload(
		_source_node, _enemy_node, 5.0,
		DamageTypesScript.DamageType.TICK,
		DamageTypesScript.SourceKind.WEAPON
	)
	assert_true(DamageTypesScript.validate_payload(payload),
		"Well-formed payload should validate true")


func test_damage_types_validate_payload_detects_missing_keys() -> void:
	var bad_payload: Dictionary = {
		"source": _source_node,
		"target": _enemy_node,
		"amount": 5.0,
		"damage_type": DamageTypesScript.DamageType.DIRECT,
	}
	assert_false(DamageTypesScript.validate_payload(bad_payload),
		"Payload missing 'source_kind' must fail validation")


func test_damage_types_validate_payload_detects_bad_enum_value() -> void:
	var bad_payload: Dictionary = {
		"source": _source_node,
		"target": _enemy_node,
		"amount": 5.0,
		"damage_type": 99,
		"source_kind": DamageTypesScript.SourceKind.WEAPON,
	}
	assert_false(DamageTypesScript.validate_payload(bad_payload),
		"Out-of-range damage_type must fail validation")


# ─── AC-04: Friendly-fire skip ────────────────────────────────────────────

func test_damage_types_is_friendly_fire_weapon_to_player_returns_true() -> void:
	assert_true(
		DamageTypesScript.is_friendly_fire(DamageTypesScript.SourceKind.WEAPON, _player_node),
		"WEAPON → player must be friendly fire"
	)


func test_damage_types_is_friendly_fire_weapon_to_ally_returns_true() -> void:
	assert_true(
		DamageTypesScript.is_friendly_fire(DamageTypesScript.SourceKind.WEAPON, _ally_node),
		"WEAPON → ally must be friendly fire"
	)


func test_damage_types_is_friendly_fire_weapon_to_enemy_returns_false() -> void:
	assert_false(
		DamageTypesScript.is_friendly_fire(DamageTypesScript.SourceKind.WEAPON, _enemy_node),
		"WEAPON → enemy must NOT be friendly fire"
	)


func test_damage_types_is_friendly_fire_enemy_to_player_returns_false() -> void:
	assert_false(
		DamageTypesScript.is_friendly_fire(DamageTypesScript.SourceKind.ENEMY, _player_node),
		"ENEMY → player must NOT be friendly fire"
	)


func test_damage_types_is_friendly_fire_environment_to_player_returns_false() -> void:
	assert_false(
		DamageTypesScript.is_friendly_fire(DamageTypesScript.SourceKind.ENVIRONMENT, _player_node),
		"ENVIRONMENT → player must NOT be friendly fire (env damages player)"
	)


# ─── AC-19: Zero-damage + negative damage clamp ───────────────────────────

func test_damage_types_zero_amount_creates_valid_payload() -> void:
	var payload: Dictionary = DamageTypesScript.make_payload(
		_source_node, _enemy_node, 0.0,
		DamageTypesScript.DamageType.DIRECT,
		DamageTypesScript.SourceKind.WEAPON
	)
	assert_float_eq(payload["amount"], 0.0)
	assert_true(DamageTypesScript.validate_payload(payload),
		"Zero-amount payload should still validate")


func test_damage_types_negative_amount_clamps_to_zero() -> void:
	var payload: Dictionary = DamageTypesScript.make_payload(
		_source_node, _enemy_node, -5.0,
		DamageTypesScript.DamageType.DIRECT,
		DamageTypesScript.SourceKind.WEAPON
	)
	assert_float_eq(payload["amount"], 0.0, 0.001,
		"Negative amount must clamp to 0.0 (no healing-through-damage exploit)")


# Per code-review suggestion #3: AC-19 edge "float precision near zero → still
# creates valid payload" — sub-threshold positive float must NOT be clamped to 0.
func test_damage_types_sub_threshold_positive_amount_not_clamped() -> void:
	var tiny: float = 0.0001
	var payload: Dictionary = DamageTypesScript.make_payload(
		_source_node, _enemy_node, tiny,
		DamageTypesScript.DamageType.TICK,
		DamageTypesScript.SourceKind.WEAPON
	)
	assert_float_eq(payload["amount"], 0.0001, 0.00001,
		"Tiny positive amount must NOT be clamped to 0.0 (only negatives clamp)")


# ─── MT-01..04: Code-review BLOCKING gaps + ADVISORY ──────────────────────

# MT-01: null source must not crash; validate_payload allows null source (some
# damage events are environmental — patches with no Node origin)
func test_damage_types_make_payload_null_source_returns_valid_dict() -> void:
	var payload: Dictionary = DamageTypesScript.make_payload(
		null, _enemy_node, 10.0,
		DamageTypesScript.DamageType.BURN,
		DamageTypesScript.SourceKind.ENVIRONMENT
	)
	assert_eq(payload.size(), 5, "Payload still has 5 keys even with null source")
	assert_eq(payload["source"], null, "source field correctly holds null")
	assert_true(DamageTypesScript.validate_payload(payload),
		"validate_payload allows null source (environmental damage has no Node origin)")


# MT-01 extension: null target must fail validate_payload (damage with no target is meaningless)
func test_damage_types_validate_payload_null_target_returns_false() -> void:
	var bad_payload: Dictionary = {
		"source": _source_node,
		"target": null,
		"amount": 5.0,
		"damage_type": DamageTypesScript.DamageType.DIRECT,
		"source_kind": DamageTypesScript.SourceKind.WEAPON,
	}
	assert_false(DamageTypesScript.validate_payload(bad_payload),
		"null target must fail validation (damage with no target is meaningless)")


# MT-02: negative enum value in make_payload — must return valid Dict shape
# but validate_payload on that dict returns false.
func test_damage_types_make_payload_negative_damage_type_returns_invalid_payload() -> void:
	var payload: Dictionary = DamageTypesScript.make_payload(
		_source_node, _enemy_node, 5.0,
		-1,                                                # negative enum value
		DamageTypesScript.SourceKind.WEAPON
	)
	assert_eq(payload.size(), 5, "make_payload still returns a 5-key dict for bad enum")
	assert_false(DamageTypesScript.validate_payload(payload),
		"validate_payload must reject the dict built with negative damage_type")


# MT-03: a freed source reference must NOT crash validate_payload.
# Godot 4 behavior: when an Object (non-RefCounted Node) is freed, every Variant
# still referencing it — including Dictionary values — evaluates to null on read.
# So a payload whose source was freed has source == null after the free(). Per the
# make_payload contract, null source is VALID (environmental hazards have no Node
# origin), so validate_payload returns true. The guarantee under test is: reading
# the auto-nulled dangling reference does not crash, and the contract is honored.
func test_damage_types_validate_payload_freed_source_is_nulled_and_accepted() -> void:
	var temp_source: Node = Node.new()
	var payload: Dictionary = DamageTypesScript.make_payload(
		temp_source, _enemy_node, 5.0,
		DamageTypesScript.DamageType.DIRECT,
		DamageTypesScript.SourceKind.WEAPON
	)
	temp_source.free()                                       # source now freed
	assert_eq(payload["source"], null,
		"Godot 4 must auto-null a Dictionary value whose Object was freed")
	assert_true(DamageTypesScript.validate_payload(payload),
		"validate_payload accepts an auto-nulled (freed) source as environmental damage, no crash")


func test_damage_types_validate_payload_freed_target_returns_false() -> void:
	var temp_target: Node = Node.new()
	var payload: Dictionary = DamageTypesScript.make_payload(
		_source_node, temp_target, 5.0,
		DamageTypesScript.DamageType.DIRECT,
		DamageTypesScript.SourceKind.WEAPON
	)
	temp_target.free()                                       # target now freed
	assert_false(DamageTypesScript.validate_payload(payload),
		"validate_payload must reject payloads with freed target Node")


# MT-04 (advisory): out-of-range source_kind in make_payload — return dict,
# validate rejects.
func test_damage_types_make_payload_bad_source_kind_returns_invalid_payload() -> void:
	var payload: Dictionary = DamageTypesScript.make_payload(
		_source_node, _enemy_node, 5.0,
		DamageTypesScript.DamageType.DIRECT,
		99                                                  # out-of-range SourceKind
	)
	assert_eq(payload.size(), 5, "make_payload still returns a 5-key dict for bad source_kind")
	assert_false(DamageTypesScript.validate_payload(payload),
		"validate_payload must reject the dict built with bad source_kind")
