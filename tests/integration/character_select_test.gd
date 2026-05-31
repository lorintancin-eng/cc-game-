## Integration: selecting 哪吒 from the real CharacterSelectPanel spawns a working
## Nezha player (CharacterBase=Nezha + 火尖枪) and the HUD switches to its 三昧真火
## energy bar. Catches the live select→spawn→HUD-rebind wiring the .new() unit tests
## can't (scene exports, node names, HUD reflection).
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/integration -gconfig=res://tests/.gutconfig.json -gexit

extends "res://tests/helpers/test_base.gd"

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _build_main() -> Node:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	return main


func test_select_panel_has_nezha_scene_wired() -> void:
	var main := _build_main()
	var panel := main.get_node("CharacterSelectPanel")
	assert_not_null(panel.nezha_scene, "PlayerNezha.tscn is assigned to the panel's nezha_scene export")


func test_selecting_nezha_spawns_nezha_with_fire_spear() -> void:
	var main := _build_main()
	var panel := main.get_node("CharacterSelectPanel")

	panel._on_nezha_button_pressed()

	var player := main.get_node_or_null("Player")
	assert_not_null(player, "selecting 哪吒 adds a Player to Main")
	var character_base := player.get_node_or_null("CharacterBase")
	assert_not_null(character_base, "the spawned Player has a CharacterBase")
	assert_true(character_base is Nezha, "the CharacterBase is 哪吒 (Nezha)")
	# `is <Type>` (not just non-null) so a weapon SCRIPT that fails to parse — the node
	# would load as a plain Node2D without its script — fails the test loudly.
	assert_true(player.get_node_or_null("FireSpearWeapon") is FireSpearWeapon,
		"哪吒 ships with a working 火尖枪 (script parsed + attached)")
	assert_true(player.get_node_or_null("QiankunDiscWeapon") is QiankunDiscWeapon,
		"哪吒 ships with a working 乾坤圈 (script parsed + attached)")
	assert_true(player.get_node_or_null("CelestialSilkWeapon") is CelestialSilkWeapon,
		"哪吒 ships with a working 混天绫 (script parsed + attached)")


func test_nezha_player_takes_character_stats() -> void:
	var main := _build_main()
	var panel := main.get_node("CharacterSelectPanel")
	panel._on_nezha_button_pressed()
	var player := main.get_node_or_null("Player")
	assert_not_null(player)
	# player._ready copies max_health/move_speed off the CharacterBase.
	assert_eq(player.max_hp, 90.0, "哪吒 base HP 90 applied to the player")
	assert_eq(player.move_speed, 220.0, "哪吒 base move speed 220 applied")


func test_selecting_nezha_shows_samadhi_energy_bar() -> void:
	var main := _build_main()
	var panel := main.get_node("CharacterSelectPanel")
	panel._on_nezha_button_pressed()

	var hud := main.get_node_or_null("HUD")
	assert_not_null(hud, "HUD present")
	var energy_panel = hud.get("_energy_panel")
	assert_not_null(energy_panel, "HUD exposes its energy panel")
	assert_true(energy_panel.visible, "哪吒 has a 三昧真火 bar → energy panel visible")
