## Unit tests for the D-B2 per-upgrade stack cap (Level Up Pool GDD r2, Rule 6).
##
## The GDD resolved D-B2 (unbounded upgrade stacking could exceed the Combat 5×
## source-modifier ceiling) by capping picks per upgrade. The cap was design-only
## until now — this suite covers the just-added code implementation:
##   - _get_upgrade_max_stacks(id): category caps by id suffix
##   - _get_upgrade_pool(): excludes any upgrade at/over its cap, BEFORE shuffle
##
## _get_upgrade_pool runs on a tree-detached .new() Player: with no
## _character_base (the @onready stays null without _ready) the character filter
## is skipped, so the pool is the 8 always-present base upgrades. We seed
## _upgrade_pick_count directly to simulate prior picks.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/player -gexit

extends "res://tests/helpers/test_base.gd"

const PlayerScript = preload("res://scripts/player/player.gd")


func _make_player() -> Player:
	var player: Player = PlayerScript.new()
	autofree(player)
	return player


func _pool_has(pool: Array, id: String) -> bool:
	for entry in pool:
		if String(entry.get("id", "")) == id:
			return true
	return false


# ─── _get_upgrade_max_stacks: category caps ──────────────────────────────

func test_upgrade_max_stacks_by_category() -> void:
	var player := _make_player()
	# Damage caps at 3 (keeps 3×(+10) on base-8 weapon = 4.75× ≤ Combat 5×).
	assert_eq(player._get_upgrade_max_stacks("talisman_damage"), 3, "damage cap = 3")
	assert_eq(player._get_upgrade_max_stacks("flying_sword_damage"), 3, "any *_damage = 3")
	# Pierce caps at 2 (anti dominant-strategy cluster wipe).
	assert_eq(player._get_upgrade_max_stacks("flying_sword_pierce"), 2, "pierce cap = 2")
	# Count caps at 3 (covers _count and _target_count).
	assert_eq(player._get_upgrade_max_stacks("talisman_count"), 3, "count cap = 3")
	assert_eq(player._get_upgrade_max_stacks("thunder_law_target_count"), 3, "target_count cap = 3")
	# Cooldown caps at 5.
	assert_eq(player._get_upgrade_max_stacks("talisman_cooldown"), 5, "cooldown cap = 5")
	# Unlocks cap at 1 (one-shot).
	assert_eq(player._get_upgrade_max_stacks("unlock_flying_sword"), 1, "unlock cap = 1")
	# Everything else defaults to 5.
	assert_eq(player._get_upgrade_max_stacks("max_hp"), 5, "max_hp default cap = 5")
	assert_eq(player._get_upgrade_max_stacks("move_speed"), 5, "move_speed default cap = 5")


# ─── _get_upgrade_pool: cap enforcement ──────────────────────────────────

func test_upgrade_pool_excludes_damage_upgrade_at_cap() -> void:
	# Arrange — talisman_damage already picked 3 times (= cap).
	var player := _make_player()
	player._upgrade_pick_count["talisman_damage"] = 3

	# Act
	var pool := player._get_upgrade_pool()

	# Assert — the capped upgrade is gone; other base upgrades remain.
	assert_false(_pool_has(pool, "talisman_damage"), "capped damage upgrade excluded from pool")
	assert_true(_pool_has(pool, "talisman_cooldown"), "uncapped sibling still offered")
	assert_true(_pool_has(pool, "max_hp"), "unrelated upgrade still offered")


func test_upgrade_pool_keeps_damage_upgrade_below_cap() -> void:
	# Arrange — picked twice (below the cap of 3).
	var player := _make_player()
	player._upgrade_pick_count["talisman_damage"] = 2

	# Act
	var pool := player._get_upgrade_pool()

	# Assert — still offered until it reaches the cap.
	assert_true(_pool_has(pool, "talisman_damage"), "below-cap damage upgrade still offered")


func test_upgrade_pool_excludes_max_hp_at_cap_only() -> void:
	# Arrange — max_hp default cap is 5.
	var player_at_cap := _make_player()
	player_at_cap._upgrade_pick_count["max_hp"] = 5
	var player_below := _make_player()
	player_below._upgrade_pick_count["max_hp"] = 4

	# Act
	var pool_at_cap := player_at_cap._get_upgrade_pool()
	var pool_below := player_below._get_upgrade_pool()

	# Assert
	assert_false(_pool_has(pool_at_cap, "max_hp"), "max_hp excluded at cap (5)")
	assert_true(_pool_has(pool_below, "max_hp"), "max_hp still offered at 4 (< 5)")


func test_upgrade_pool_unaffected_upgrades_present_by_default() -> void:
	# Arrange — fresh player, no picks recorded.
	var player := _make_player()

	# Act
	var pool := player._get_upgrade_pool()

	# Assert — all 8 always-present base upgrades are offered.
	for id in ["talisman_damage", "talisman_cooldown", "talisman_count", "talisman_speed",
			"max_hp", "move_speed", "pickup_radius", "xp_gain"]:
		assert_true(_pool_has(pool, id), "base upgrade '%s' present with no picks" % id)
