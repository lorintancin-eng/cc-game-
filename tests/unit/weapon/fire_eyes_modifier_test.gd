## Unit tests for Sun Wukong 火眼金睛 wiring (W206).
##
## Verifies the defensive null-check contract of the `_get_fire_eyes_modifier`
## helper present in three weapon scripts:
##   - scripts/weapon/sun_wukong/jingu_bang_v2.gd (canonical impl, unchanged)
##   - scripts/weapon/sun_wukong/hair_clone_unit.gd (NEW wiring)
##   - scripts/weapon/sun_wukong/immobilize.gd     (NEW wiring)
##
## Contract: the helper MUST return 1.0 whenever any of the five lookup
## conditions fails (no owner, owner has no _character_base, _character_base
## null, _character_base missing method). It MUST proxy to
## `_character_base.get_damage_modifier(target)` when all five succeed.
##
## Regression test for the bug fixed in this commit: hair clone attacks and
## immobilize bursts previously did NOT apply Sun Wukong's signature passive
## (1.2-1.55× vs Boss/Elite). After the wiring, all three weapons apply it.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gtest=res://tests/unit/weapon -gexit

extends "res://tests/helpers/test_base.gd"

const HairCloneUnitScript = preload("res://scripts/weapon/sun_wukong/hair_clone_unit.gd")
const ImmobilizeScript = preload("res://scripts/weapon/sun_wukong/immobilize.gd")


# ─── Test doubles ────────────────────────────────────────────────────────

## Plain Node with no `_character_base` field — covers branch 2.
func _make_owner_without_character_base() -> Node:
	return Node.new()


## Node with `_character_base = null` — covers branch 3.
class OwnerWithNullCharacterBase extends Node:
	var _character_base = null


## Node with `_character_base` set, but the base lacks `get_damage_modifier`.
## Covers branch 4.
class StubCharacterBaseNoMethod extends RefCounted:
	pass


class OwnerWithCharacterBaseNoMethod extends Node:
	var _character_base = StubCharacterBaseNoMethod.new()


## Node with `_character_base` exposing `get_damage_modifier(target)`. Returns
## a configurable value so we can verify the proxy result. Covers branch 5.
class StubCharacterBaseWithModifier extends RefCounted:
	var return_value: float = 1.42

	func get_damage_modifier(_target: Node) -> float:
		return return_value


class OwnerWithCharacterBaseAndMethod extends Node:
	var _character_base = StubCharacterBaseWithModifier.new()


# ─── HairCloneUnit ───────────────────────────────────────────────────────

func test_weapon_fire_eyes_hair_clone_no_owner_returns_one() -> void:
	# Arrange
	var clone = HairCloneUnitScript.new()
	clone.player_owner = null
	# Act
	var result: float = clone._get_fire_eyes_modifier(null)
	# Assert
	assert_float_eq(result, 1.0, 0.0001, "no owner must default to 1.0×")
	clone.free()


func test_weapon_fire_eyes_hair_clone_owner_without_character_base_returns_one() -> void:
	# Arrange
	var clone = HairCloneUnitScript.new()
	var owner_node = _make_owner_without_character_base()
	clone.player_owner = owner_node
	# Act
	var result: float = clone._get_fire_eyes_modifier(null)
	# Assert
	assert_float_eq(result, 1.0, 0.0001, "owner without _character_base must default to 1.0×")
	owner_node.free()
	clone.free()


func test_weapon_fire_eyes_hair_clone_null_character_base_returns_one() -> void:
	# Arrange
	var clone = HairCloneUnitScript.new()
	var owner_node = OwnerWithNullCharacterBase.new()
	clone.player_owner = owner_node
	# Act
	var result: float = clone._get_fire_eyes_modifier(null)
	# Assert
	assert_float_eq(result, 1.0, 0.0001, "null _character_base must default to 1.0×")
	owner_node.free()
	clone.free()


func test_weapon_fire_eyes_hair_clone_character_base_missing_method_returns_one() -> void:
	# Arrange
	var clone = HairCloneUnitScript.new()
	var owner_node = OwnerWithCharacterBaseNoMethod.new()
	clone.player_owner = owner_node
	# Act
	var result: float = clone._get_fire_eyes_modifier(null)
	# Assert
	assert_float_eq(result, 1.0, 0.0001, "missing get_damage_modifier must default to 1.0×")
	owner_node.free()
	clone.free()


func test_weapon_fire_eyes_hair_clone_proxies_to_character_base() -> void:
	# Arrange — happy path: SunWukong v2 returns 1.42 vs elite
	var clone = HairCloneUnitScript.new()
	var owner_node = OwnerWithCharacterBaseAndMethod.new()
	(owner_node._character_base as StubCharacterBaseWithModifier).return_value = 1.42
	clone.player_owner = owner_node
	var dummy_target := Node.new()
	# Act
	var result: float = clone._get_fire_eyes_modifier(dummy_target)
	# Assert — proxy must return the base's value, not a hardcoded default
	assert_float_eq(result, 1.42, 0.0001, "must proxy through to _character_base.get_damage_modifier")
	dummy_target.free()
	owner_node.free()
	clone.free()


# ─── Immobilize ──────────────────────────────────────────────────────────
# Same 5-path contract; Immobilize uses `_player_owner` (underscored).

func test_weapon_fire_eyes_immobilize_no_owner_returns_one() -> void:
	# Arrange
	var im = ImmobilizeScript.new()
	im._player_owner = null
	# Act
	var result: float = im._get_fire_eyes_modifier(null)
	# Assert
	assert_float_eq(result, 1.0, 0.0001, "no owner must default to 1.0×")
	im.free()


func test_weapon_fire_eyes_immobilize_owner_without_character_base_returns_one() -> void:
	# Arrange
	var im = ImmobilizeScript.new()
	var owner_node = _make_owner_without_character_base()
	im._player_owner = owner_node
	# Act
	var result: float = im._get_fire_eyes_modifier(null)
	# Assert
	assert_float_eq(result, 1.0, 0.0001, "owner without _character_base must default to 1.0×")
	owner_node.free()
	im.free()


func test_weapon_fire_eyes_immobilize_null_character_base_returns_one() -> void:
	# Arrange
	var im = ImmobilizeScript.new()
	var owner_node = OwnerWithNullCharacterBase.new()
	im._player_owner = owner_node
	# Act
	var result: float = im._get_fire_eyes_modifier(null)
	# Assert
	assert_float_eq(result, 1.0, 0.0001, "null _character_base must default to 1.0×")
	owner_node.free()
	im.free()


func test_weapon_fire_eyes_immobilize_character_base_missing_method_returns_one() -> void:
	# Arrange
	var im = ImmobilizeScript.new()
	var owner_node = OwnerWithCharacterBaseNoMethod.new()
	im._player_owner = owner_node
	# Act
	var result: float = im._get_fire_eyes_modifier(null)
	# Assert
	assert_float_eq(result, 1.0, 0.0001, "missing get_damage_modifier must default to 1.0×")
	owner_node.free()
	im.free()


func test_weapon_fire_eyes_immobilize_proxies_to_character_base() -> void:
	# Arrange — covers the Sun Wukong v2 path returning 1.2 (base) up to 1.55 (max)
	var im = ImmobilizeScript.new()
	var owner_node = OwnerWithCharacterBaseAndMethod.new()
	(owner_node._character_base as StubCharacterBaseWithModifier).return_value = 1.55
	im._player_owner = owner_node
	var dummy_target := Node.new()
	# Act
	var result: float = im._get_fire_eyes_modifier(dummy_target)
	# Assert
	assert_float_eq(result, 1.55, 0.0001, "must proxy through to _character_base.get_damage_modifier")
	dummy_target.free()
	owner_node.free()
	im.free()
