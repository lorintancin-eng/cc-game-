## Unit tests for the Player XP / level-up progression curve.
##
## Per .claude/docs/coding-standards.md, "XP/level math" is BLOCKING test
## coverage — it is the balance backbone of the run. This suite locks in the
## curve formula and the gain_experience level-up loop.
##
## Formula (scripts/player/player.gd):
##   _get_next_xp_threshold(prev) = ceil( prev * max(mult,1.0) + max(flat,0.0) )
##       with a monotonic floor of prev + 1 (threshold always strictly grows).
##   Defaults: initial 18, mult 1.28, flat 6.0, xp_gain_multiplier 1.0.
##   → thresholds: 18, 30, 45, 64, ...
##
## We instantiate the Player SCRIPT directly (no scene / _ready) and seed the
## post-_ready fields (level/current_xp/xp_to_next_level) by hand, because
## gain_experience only does arithmetic + signal emits — no physics or child
## nodes. autofree frees the CharacterBody2D at teardown.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/player -gexit

extends "res://tests/helpers/test_base.gd"

# Test double: the real Player._queue_upgrade_choices() (called when a level is
# gained) reads get_tree().paused to pause for the upgrade panel — which is a
# null instance on a tree-detached node and crashes. We subclass and stub it,
# preserving only the _pending_upgrade_choices bookkeeping so the pure XP math
# (and the choice count) can be asserted without scene-tree side effects.
class TestPlayer extends Player:
	func _queue_upgrade_choices(levels_gained: int) -> void:
		_pending_upgrade_choices += maxi(levels_gained, 0)


# Player with the leveling fields seeded to a known post-_ready state. _ready is
# NOT run (it needs scene children); we set only what the XP path reads.
func _make_player(start_level: int, start_xp: float, threshold: float) -> Player:
	var player: Player = TestPlayer.new()
	autofree(player)
	player.level = start_level
	player.current_xp = start_xp
	player.xp_to_next_level = threshold
	return player


# ─── _get_next_xp_threshold: the curve ───────────────────────────────────

func test_player_xp_threshold_follows_curve_with_defaults() -> void:
	# Arrange — default mult 1.28, flat 6.0.
	var player := _make_player(1, 0.0, 18.0)

	# Act / Assert — ceil(prev*1.28 + 6) at each step.
	assert_float_eq(player._get_next_xp_threshold(18.0), 30.0, 0.001, "18 → 30")
	assert_float_eq(player._get_next_xp_threshold(30.0), 45.0, 0.001, "30 → 45")
	assert_float_eq(player._get_next_xp_threshold(45.0), 64.0, 0.001, "45 → 64")


func test_player_xp_threshold_is_strictly_monotonic_even_at_min_growth() -> void:
	# Arrange — degenerate growth (mult 1.0, flat 0.0): formula would return
	# `prev`, but the +1 floor must force a strict increase so leveling can't stall.
	var player := _make_player(1, 0.0, 18.0)
	player.xp_growth_multiplier = 1.0
	player.xp_growth_flat = 0.0

	# Act
	var next := player._get_next_xp_threshold(18.0)

	# Assert
	assert_float_eq(next, 19.0, 0.001, "min-growth floor: prev + 1")


# ─── gain_experience: single / overflow / multi-level ────────────────────

func test_player_gain_experience_single_level_up_exact() -> void:
	# Arrange — exactly enough to hit the next level, no remainder.
	var player := _make_player(1, 0.0, 18.0)
	var levels: Array[int] = []
	player.level_reached.connect(func(lv: int): levels.append(lv))

	# Act
	player.gain_experience(18.0)

	# Assert
	assert_eq(player.level, 2, "reached level 2")
	assert_float_eq(player.current_xp, 0.0, 0.001, "no leftover XP")
	assert_float_eq(player.xp_to_next_level, 30.0, 0.001, "threshold advanced to 30")
	assert_eq(levels.size(), 1, "level_reached emitted once")
	assert_eq(levels[0], 2, "level_reached carried the new level")


func test_player_gain_experience_overflow_carries_remainder() -> void:
	# Arrange — gain more than one level's worth; remainder carries.
	var player := _make_player(1, 0.0, 18.0)

	# Act — 25 XP: 18 to hit L2, 7 carries.
	player.gain_experience(25.0)

	# Assert
	assert_eq(player.level, 2, "single level up")
	assert_float_eq(player.current_xp, 7.0, 0.001, "remainder 25-18 = 7 carried")
	assert_float_eq(player.xp_to_next_level, 30.0, 0.001, "threshold advanced")


func test_player_gain_experience_multi_level_in_one_grant() -> void:
	# Arrange — a big orb that should grant two levels at once.
	var player := _make_player(1, 0.0, 18.0)
	var levels: Array[int] = []
	player.level_reached.connect(func(lv: int): levels.append(lv))

	# Act — 53 XP: 18 (→L2, rem 35), 30 (→L3, rem 5), 5 < 45 stop.
	player.gain_experience(53.0)

	# Assert
	assert_eq(player.level, 3, "two levels gained")
	assert_float_eq(player.current_xp, 5.0, 0.001, "final remainder 5")
	assert_float_eq(player.xp_to_next_level, 45.0, 0.001, "threshold at 45 after two level-ups")
	assert_eq(levels.size(), 2, "level_reached emitted once per level")
	assert_eq(levels[1], 3, "last level_reached = 3")


# ─── xp_gain_multiplier scaling ──────────────────────────────────────────

func test_player_gain_experience_applies_gain_multiplier() -> void:
	# Arrange — x_gain_multiplier 2.0 means a 9-XP orb counts as 18.
	var player := _make_player(1, 0.0, 18.0)
	player.xp_gain_multiplier = 2.0

	# Act
	player.gain_experience(9.0)

	# Assert — effective 18 → level up exactly.
	assert_eq(player.level, 2, "gain multiplier scales XP (9 × 2 = 18 → level up)")
	assert_float_eq(player.current_xp, 0.0, 0.001, "no remainder")


# ─── guards: dead / non-positive amounts are no-ops ──────────────────────

func test_player_gain_experience_ignored_when_dead() -> void:
	# Arrange
	var player := _make_player(1, 0.0, 18.0)
	player._is_dead = true

	# Act
	player.gain_experience(100.0)

	# Assert — terminal state: no XP, no level change.
	assert_eq(player.level, 1, "dead player does not level")
	assert_float_eq(player.current_xp, 0.0, 0.001, "dead player gains no XP")


func test_player_gain_experience_ignores_non_positive_amount() -> void:
	# Arrange
	var player := _make_player(3, 10.0, 45.0)

	# Act
	player.gain_experience(0.0)
	player.gain_experience(-25.0)

	# Assert — unchanged.
	assert_eq(player.level, 3, "level unchanged on amount <= 0")
	assert_float_eq(player.current_xp, 10.0, 0.001, "XP unchanged on amount <= 0")
