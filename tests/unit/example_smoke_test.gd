## Example smoke test — verifies that the GUT framework is installed and
## the test harness can run a trivial assertion.
##
## DELETE THIS FILE once a real test file exists in tests/unit/.

extends "res://addons/gut/test.gd"

func test_smoke_arithmetic() -> void:
	# Trivial assertion to confirm the runner works.
	assert_eq(2 + 2, 4, "Basic arithmetic should work")

func test_smoke_string_concat() -> void:
	assert_eq("Myth" + "Survivor", "MythSurvivor", "String concat should work")

func test_smoke_fixture_path_exists() -> void:
	# Confirms the fixtures directory is on the resource path.
	assert_true(DirAccess.dir_exists_absolute("res://tests/fixtures"),
		"tests/fixtures/ directory should be reachable as a resource path")
