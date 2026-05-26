## Base class for MythSurvivor unit and integration tests.
##
## Extend this class instead of GutTest directly to inherit shared setup
## (deterministic random seed, common assertions, fixture loaders).
##
## Example:
##   class_name WeaponCooldownTest
##   extends TestBase
##
##   func test_cooldown_resets_after_fire() -> void:
##       var weapon := load_fixture("weapon_basic")
##       weapon.fire()
##       assert_eq(weapon.remaining_cooldown(), weapon.base_cooldown)

class_name TestBase
extends "res://addons/gut/test.gd"
# NOTE: The above extends path is GUT's base test class. If you switch test
# frameworks (e.g. to gdUnit4), update this line and the extends in subclasses.

const FIXTURE_PATH: String = "res://tests/fixtures/"

## Set up deterministic state before each test. Override in subclasses
## but always call super.before_each() first.
func before_each() -> void:
	seed(0)
	randomize()
	# Re-seed after randomize() — randomize() reseeds from system time.
	seed(0)

## Tear down per-test state. Override in subclasses but always call
## super.after_each() last.
func after_each() -> void:
	pass

## Load a Resource fixture by short name from tests/fixtures/.
## Returns null if the fixture is missing — callers should check.
func load_fixture(fixture_name: String) -> Resource:
	var path: String = FIXTURE_PATH + fixture_name + ".tres"
	if not ResourceLoader.exists(path):
		push_warning("TestBase.load_fixture: missing fixture at %s" % path)
		return null
	return ResourceLoader.load(path)

## Assert that two floats are equal within a tolerance.
## GUT's assert_almost_eq exists; this wrapper enforces a project-default
## tolerance of 0.001 unless overridden.
func assert_float_eq(actual: float, expected: float, tolerance: float = 0.001, label: String = "") -> void:
	var diff: float = abs(actual - expected)
	var msg: String = "expected %f, got %f (tolerance %f)" % [expected, actual, tolerance]
	if label != "":
		msg = label + ": " + msg
	assert_true(diff <= tolerance, msg)

## Assert that a Resource was duplicated (deep copy) and is not the same
## instance as the original. Catches accidental shared-Resource mutation.
func assert_is_deep_copy(copy: Resource, original: Resource, label: String = "") -> void:
	var msg: String = "copy and original share the same instance"
	if label != "":
		msg = label + ": " + msg
	assert_ne(copy.get_instance_id(), original.get_instance_id(), msg)
