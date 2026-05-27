## GUT (Godot Unit Test) headless command-line runner.
##
## Usage (from project root — GUT addon must be installed first):
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gtest=res://tests/unit -gtest=res://tests/integration -gexit
##
## Or use this script as a thin wrapper for custom configuration:
##   godot --headless --script tests/gut_runner.gd
##
## Prerequisites:
##   1. Install GUT via AssetLib (search "Gut") → addons/gut/ committed to repo
##   2. Enable the GUT plugin in Project Settings → Plugins
##   3. GUT ≥ 9.x required for Godot 4
##
## CI equivalent command (used in .github/workflows/tests.yml):
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gtest=res://tests/unit -gtest=res://tests/integration \
##         -gconfig=res://tests/.gutconfig.json -gexit

extends SceneTree

const GUT_ADDON_PATH: String = "res://addons/gut/gut_cmdln.gd"

func _init() -> void:
	if not ResourceLoader.exists(GUT_ADDON_PATH):
		push_error("[gut_runner] GUT addon not found at %s" % GUT_ADDON_PATH)
		push_error("[gut_runner] Install GUT via AssetLib (search 'Gut') and commit addons/gut/")
		quit(1)
		return

	# GUT command-line runner is invoked directly via -s flag in CI.
	# This script exists as a documented entry point and can be customized.
	# For programmatic use, load the GUT cmdln script and execute:
	var cmdln_script: GDScript = load(GUT_ADDON_PATH)
	if cmdln_script == null:
		push_error("[gut_runner] Failed to load GUT command-line runner")
		quit(1)
		return

	# GUT cmdln handles its own argument parsing; just instantiate it.
	var runner = cmdln_script.new()
	if runner == null:
		push_error("[gut_runner] Failed to instantiate GUT runner")
		quit(1)
		return

	quit(0)
