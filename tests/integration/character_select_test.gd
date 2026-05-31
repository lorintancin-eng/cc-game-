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


func test_nezha_starts_with_only_fire_spear_unlocked() -> void:
	# 设计：火尖枪初始；混天绫 / 乾坤圈 升级解锁。开局应只有火尖枪在开火。
	var main := _build_main()
	var panel := main.get_node("CharacterSelectPanel")
	panel._on_nezha_button_pressed()
	var player := main.get_node_or_null("Player")
	assert_not_null(player)

	assert_true((player.get_node("FireSpearWeapon") as NezhaWeaponBase).is_unlocked(),
		"火尖枪开局解锁（初始武器）")
	assert_false((player.get_node("QiankunDiscWeapon") as NezhaWeaponBase).is_unlocked(),
		"乾坤圈开局锁定（待升级解锁）")
	assert_false((player.get_node("CelestialSilkWeapon") as NezhaWeaponBase).is_unlocked(),
		"混天绫开局锁定（待升级解锁）")


func _pool_ids(player: Node) -> Array:
	var ids: Array = []
	for item in player._get_upgrade_pool():
		ids.append(String(item.get("id", "")))
	return ids


func test_nezha_unlock_upgrade_unlocks_weapon_and_pool_switches_to_enhance() -> void:
	# 完整升级闭环：锁定→池给「悟得」→应用→武器解锁→池改给强化项。
	var main := _build_main()
	var panel := main.get_node("CharacterSelectPanel")
	panel._on_nezha_button_pressed()
	var player := main.get_node_or_null("Player")
	var qiankun := player.get_node("QiankunDiscWeapon") as NezhaWeaponBase

	var ids_before := _pool_ids(player)
	assert_true("nezha_unlock_qiankun" in ids_before, "锁定时池里有「悟得乾坤圈」")
	assert_false("nezha_qiankun_disc_damage" in ids_before, "锁定时不出现乾坤圈强化项")

	player._apply_upgrade(&"nezha_unlock_qiankun")
	assert_true(qiankun.is_unlocked(), "应用「悟得乾坤圈」→ 乾坤圈解锁")

	var ids_after := _pool_ids(player)
	assert_false("nezha_unlock_qiankun" in ids_after, "解锁后「悟得」项消失")
	assert_true("nezha_qiankun_disc_damage" in ids_after, "解锁后出现乾坤圈强化项")


func test_avatar_mode_speeds_up_and_fans_fire_spear() -> void:
	# 法相天地：填满三昧真火 → 全武器提速、火尖枪三枪齐射。
	var main := _build_main()
	var panel := main.get_node("CharacterSelectPanel")
	panel._on_nezha_button_pressed()
	var player := main.get_node_or_null("Player")
	var fire_spear := player.get_node("FireSpearWeapon") as NezhaWeaponBase
	var nezha := player.get_node("CharacterBase") as Nezha

	var base_cd := fire_spear._get_cooldown()
	assert_eq(fire_spear._avatar_fan_count(), 1, "平时火尖枪单发")

	for _i in range(20):
		nezha._on_kill(null)  # 击杀充能 → 满 100 → ready（不自动）
	assert_true(nezha.is_avatar_ready(), "满槽待主动释放")
	assert_false(nezha.is_avatar_active(), "不自动进入法相")
	nezha.try_activate_avatar()  # 主动释放
	assert_true(nezha.is_avatar_active(), "主动释放进入法相天地")

	assert_almost_eq(fire_spear._get_cooldown(), base_cd * 0.4, 0.01, "法相期间冷却 ×0.4(射速 ×2.5)")
	assert_eq(fire_spear._avatar_fan_count(), 3, "法相期间火尖枪三枪齐射")


func test_skill_key_one_triggers_nezha_avatar() -> void:
	# 输入路径：按 1（slot 0）→ player._try_cast_skill(0) → Nezha.try_activate_avatar()。
	var main := _build_main()
	var panel := main.get_node("CharacterSelectPanel")
	panel._on_nezha_button_pressed()
	var player := main.get_node_or_null("Player")
	var nezha := player.get_node("CharacterBase") as Nezha

	for _i in range(20):
		nezha._on_kill(null)  # ready
	player._try_cast_skill(0)  # 模拟按 1

	assert_true(nezha.is_avatar_active(), "按 1 → 主动释放法相天地")


func test_san_cai_synergy_gate_requires_all_three_weapons() -> void:
	# 三才合击门控：仅三件神兵全解锁时激活（乾坤圈出手才甩火尖枪）。
	var main := _build_main()
	var panel := main.get_node("CharacterSelectPanel")
	panel._on_nezha_button_pressed()
	var player := main.get_node_or_null("Player")
	var qiankun := player.get_node("QiankunDiscWeapon") as QiankunDiscWeapon

	assert_false(qiankun._all_nezha_weapons_unlocked(), "开局仅火尖枪 → 三才合击未激活")
	player._apply_upgrade(&"nezha_unlock_qiankun")
	player._apply_upgrade(&"nezha_unlock_silk")
	assert_true(qiankun._all_nezha_weapons_unlocked(), "三件神兵全解锁 → 三才合击激活")


func test_qiankun_orbit_evolves_to_bounce_and_scales_with_level() -> void:
	# 环天圈：乾坤圈进化为弹射形态，每多升一级 +1 发。
	var main := _build_main()
	var panel := main.get_node("CharacterSelectPanel")
	panel._on_nezha_button_pressed()
	var player := main.get_node_or_null("Player")
	var qiankun := player.get_node("QiankunDiscWeapon") as QiankunDiscWeapon

	assert_false(qiankun.is_bounce_mode(), "默认回旋形态")
	qiankun.add_qiankun_orbit()
	assert_true(qiankun.is_bounce_mode(), "环天圈 → 弹射形态")
	assert_eq(qiankun.bounce_disc_count(), 1, "首级 1 发弹射圈")
	qiankun.add_qiankun_orbit()
	qiankun.add_qiankun_orbit()
	assert_eq(qiankun.bounce_disc_count(), 3, "每多一级 +1 发")
