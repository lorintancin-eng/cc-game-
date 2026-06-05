## Unit tests for Story 011 (logic core): upgrade/unlock → element_inventory gains.
## This is what makes 相生 combos actually reachable in-game (the UI element icons +
## 相生 proximity hint are the visual half of Story 011, deferred — they need
## playtest/screenshot sign-off that headless cannot produce).
##
## Covers:
##   - _get_upgrade_element maps each weapon-family upgrade to its weapon element,
##     player-attribute upgrades to Wood, and unlock_*/character/unknown ids to neutral
##   - WEAPON_UNLOCK_ELEMENTS matches the GDD weapon identities
##   - _apply_upgrade increments the correct element on selection (no double-count on unlock)
##   - END-TO-END: a real ComboManager activates a combo when an upgrade completes a pair
##
## Instantiation: Player.new() (no _ready) + ComboManager.new(). autofree() teardown.

extends "res://tests/helpers/test_base.gd"


func _make_player() -> Player:
	var player := Player.new()
	autofree(player)
	return player


# ─── _get_upgrade_element mapping ────────────────────────────────────────────

func test_get_upgrade_element_weapon_families_map_to_weapon_element() -> void:
	var player := _make_player()
	assert_eq(player._get_upgrade_element(&"talisman_damage"), "fire", "符箓 upgrade → fire")
	assert_eq(player._get_upgrade_element(&"flying_sword_pierce"), "metal", "飞剑 upgrade → metal")
	assert_eq(player._get_upgrade_element(&"thunder_law_radius"), "water", "雷法 upgrade → water")
	assert_eq(player._get_upgrade_element(&"bagua_array_tick_rate"), "earth", "八卦阵 upgrade → earth")
	assert_eq(player._get_upgrade_element(&"explosive_talisman_damage"), "fire", "爆裂符 upgrade → fire")
	assert_eq(player._get_upgrade_element(&"mountain_seal_radius"), "earth", "山印 upgrade → earth")


func test_get_upgrade_element_player_attributes_map_to_wood() -> void:
	var player := _make_player()
	for id in ["max_hp", "move_speed", "pickup_radius", "xp_gain"]:
		assert_eq(player._get_upgrade_element(StringName(id)), "wood", "%s → wood" % id)


func test_get_upgrade_element_unlock_and_unknown_return_neutral() -> void:
	var player := _make_player()
	assert_eq(player._get_upgrade_element(&"unlock_thunder_law"), "neutral",
			"unlock_* gains via WEAPON_UNLOCK_ELEMENTS, not here")
	assert_eq(player._get_upgrade_element(&"wukong_jingu_bang_damage"), "neutral",
			"character-specific upgrade → neutral")
	assert_eq(player._get_upgrade_element(&"some_unknown_id"), "neutral", "unknown → neutral")


# ─── WEAPON_UNLOCK_ELEMENTS matches GDD weapon identities ─────────────────────

func test_weapon_unlock_elements_match_gdd_identities() -> void:
	assert_eq(Player.WEAPON_UNLOCK_ELEMENTS["unlock_flying_sword"], "metal", "飞剑 = metal")
	assert_eq(Player.WEAPON_UNLOCK_ELEMENTS["unlock_thunder_law"], "water", "雷法 = water")
	assert_eq(Player.WEAPON_UNLOCK_ELEMENTS["unlock_bagua_array"], "earth", "八卦阵 = earth")
	assert_eq(Player.WEAPON_UNLOCK_ELEMENTS["unlock_explosive_talisman"], "fire", "爆裂符 = fire")
	assert_eq(Player.WEAPON_UNLOCK_ELEMENTS["unlock_mountain_seal"], "earth", "山印 = earth")


# ─── _apply_upgrade increments the correct element ───────────────────────────

func test_apply_upgrade_wood_attribute_grants_wood() -> void:
	var player := _make_player()
	watch_signals(player)
	player._apply_upgrade(&"max_hp")
	assert_eq(player.element_inventory["wood"], 1, "气血上限 upgrade → wood +1")
	assert_signal_emitted(player, "element_inventory_changed")


func test_apply_upgrade_weapon_upgrade_grants_weapon_element() -> void:
	var player := _make_player()
	player._apply_upgrade(&"talisman_damage")
	assert_eq(player.element_inventory["fire"], 1, "追魂符威力 upgrade → fire +1")


func test_apply_upgrade_unlock_grants_element_once_no_double_count() -> void:
	var player := _make_player()
	player._apply_upgrade(&"unlock_thunder_law")
	assert_eq(player.element_inventory["water"], 1,
			"unlock 雷法 → water +1 exactly (no double via _get_upgrade_element)")


# ─── END-TO-END: upgrade completes a pair → ComboManager activates live ──────

func test_upgrade_completing_pair_activates_combo_live() -> void:
	# Arrange — player seeded with fire=1 (starting Talisman), real ComboManager wired
	var player := _make_player()
	player._add_element("fire")
	var cm := ComboManager.new()
	autofree(cm)
	cm.connect_to_player(player)  # initial recompute: fire=1 only → no combo
	assert_false(cm.is_combo_active("木生火"), "precondition: 木生火 inactive at fire=1")
	watch_signals(cm)

	# Act — take a Wood attribute upgrade (气血上限) → wood +1
	player._apply_upgrade(&"max_hp")

	# Assert — fire=1 + wood=1 completes 木生火; the combo activates live
	assert_true(cm.is_combo_active("木生火"),
			"taking a Wood upgrade with fire=1 activates 木生火 in-game")
	assert_signal_emit_count(cm, "combo_activated", 1)
