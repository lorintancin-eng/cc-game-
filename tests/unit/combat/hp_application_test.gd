## Unit tests for HP Application + Overkill Clamp (Combat Story 002)
## covering AC-01 (Player) + AC-20 (Enemy) plus edge cases.
##
## Implementation files under test:
##   scripts/player/player.gd (Player.take_damage)
##   scripts/enemy/enemy.gd   (Enemy.take_damage)
##
## Story 002 added Enemy.damage_taken signal (Combat GDD r5 Core Rule 3).
## Player.health_changed signal pre-existed (verified compliant by this story).
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gtest=res://tests/unit/combat -gexit

extends "res://tests/helpers/test_base.gd"

const PlayerScript = preload("res://scripts/player/player.gd")
const EnemyScript  = preload("res://scripts/enemy/enemy.gd")
const PaperDollArchetype = preload("res://resources/enemies/paper_doll.tres")

# Mock harness — Player and Enemy are CharacterBody2D scenes that depend on
# scene-tree children. For unit testing we instantiate the scripts directly
# and bypass scene wiring where possible. Where required (health bar, damage
# area), we'll use try/except patterns or signal-only verification.


# ─── AC-01: Player HP decrement + health_changed signal ──────────────────

func test_combat_player_take_damage_decrements_hp_correctly() -> void:
	# Per Story 002 AC-01: Player at current_hp=30, take_damage(8)
	#                      → current_hp=22 AND health_changed(22, 30) emit exactly once
	var player = _make_test_player(30.0, 30.0)
	var signal_count := [0]
	var last_payload := [null]
	player.health_changed.connect(func(cur: float, mx: float):
		signal_count[0] += 1
		last_payload[0] = [cur, mx]
	)

	player.take_damage(8.0)

	assert_float_eq(player.current_hp, 22.0)
	assert_eq(signal_count[0], 1, "health_changed must emit exactly once")
	assert_float_eq(last_payload[0][0], 22.0)
	assert_float_eq(last_payload[0][1], 30.0)
	player.queue_free()


func test_combat_player_take_damage_zero_amount_no_signal() -> void:
	# AC-01 extension: amount=0 → no HP change AND no signal (matches Combat AC-19)
	var player = _make_test_player(50.0, 100.0)
	var signal_count := [0]
	player.health_changed.connect(func(_a, _b): signal_count[0] += 1)

	player.take_damage(0.0)

	assert_float_eq(player.current_hp, 50.0, 0.001, "Zero amount must not change HP")
	assert_eq(signal_count[0], 0, "Zero amount must not emit health_changed")
	player.queue_free()


func test_combat_player_take_damage_negative_amount_no_signal() -> void:
	# Defensive: negative amount must not heal — early-returns
	var player = _make_test_player(50.0, 100.0)
	var signal_count := [0]
	player.health_changed.connect(func(_a, _b): signal_count[0] += 1)

	player.take_damage(-10.0)

	assert_float_eq(player.current_hp, 50.0, 0.001, "Negative amount must not heal")
	assert_eq(signal_count[0], 0, "Negative amount must not emit signal")
	player.queue_free()


func test_combat_player_take_damage_kill_blow_triggers_died() -> void:
	# AC-01 edge: damage = max_hp (one-shot kill) → current_hp=0 AND died fires once
	var player = _make_test_player(8.0, 8.0)
	var health_emits := [0]
	var died_emits := [0]
	player.health_changed.connect(func(_a, _b): health_emits[0] += 1)
	player.died.connect(func(): died_emits[0] += 1)

	player.take_damage(8.0)

	assert_float_eq(player.current_hp, 0.0)
	assert_eq(health_emits[0], 1, "health_changed emits once on kill blow")
	assert_eq(died_emits[0], 1, "died emits exactly once on kill blow")
	player.queue_free()


func test_combat_player_dead_state_silently_drops_further_damage() -> void:
	# After DEFEATED: subsequent take_damage is silently dropped (no signals)
	var player = _make_test_player(5.0, 100.0)
	player.take_damage(10.0)  # kills player
	assert_float_eq(player.current_hp, 0.0)

	var health_emits := [0]
	var died_emits := [0]
	player.health_changed.connect(func(_a, _b): health_emits[0] += 1)
	player.died.connect(func(): died_emits[0] += 1)

	player.take_damage(20.0)  # post-death damage

	assert_float_eq(player.current_hp, 0.0, 0.001, "HP remains 0 after death")
	assert_eq(health_emits[0], 0, "No health_changed signal after death")
	assert_eq(died_emits[0], 0, "No double-died signal")
	player.queue_free()


# ─── AC-20: Enemy overkill clamp + damage_taken signal ───────────────────

func test_combat_enemy_take_damage_overkill_clamps_to_zero() -> void:
	# Per Story 002 AC-20: Enemy at current_hp=5, take_damage(999)
	#                      → current_hp=0 (clamped, NOT -994) AND died fires once
	var enemy = _make_test_enemy(5.0, 24.0)
	var died_emits := [0]
	enemy.died.connect(func(_e: Enemy): died_emits[0] += 1)

	enemy.take_damage(999.0)

	# current_hp checked BEFORE queue_free completes (next frame removes node)
	assert_float_eq(enemy.current_hp, 0.0, 0.001, "Overkill must clamp to 0, not negative")
	assert_eq(died_emits[0], 1, "died emits exactly once on overkill")
	# enemy is already queue_free'd by _die — do not free again


func test_combat_enemy_take_damage_emits_damage_taken_signal() -> void:
	# Story 002 contract addition: Enemy emits damage_taken(current, max, last_damage)
	# Combat GDD r5 Core Rule 3 + Enemy GDD r1 — was missing before Story 002.
	var enemy = _make_test_enemy(20.0, 24.0)
	var damage_taken_payload := [null]
	enemy.damage_taken.connect(func(cur: float, mx: float, last: float):
		damage_taken_payload[0] = [cur, mx, last]
	)

	enemy.take_damage(7.0)

	# Use assert_not_null, NOT assert_ne(x, null): GUT 9.x's assert_ne runs its
	# array diff tool, which calls .size() on the null operand and logs a spurious
	# "Invalid call ... 'size' in base 'Nil'" engine error (tripping the error trap).
	assert_not_null(damage_taken_payload[0], "damage_taken must emit")
	assert_float_eq(damage_taken_payload[0][0], 13.0, 0.001, "current_hp = 20-7 = 13")
	assert_float_eq(damage_taken_payload[0][1], 24.0, 0.001, "max_hp preserved")
	assert_float_eq(damage_taken_payload[0][2], 7.0, 0.001, "last_damage_amount = 7")
	enemy.queue_free()


func test_combat_enemy_damage_taken_does_not_fire_on_zero_amount() -> void:
	# Per Combat AC-19 mirror: damage_taken only fires when amount > 0
	# (zero-amount events use source-side damage_dealt instead)
	var enemy = _make_test_enemy(20.0, 24.0)
	var emits := [0]
	enemy.damage_taken.connect(func(_a, _b, _c): emits[0] += 1)

	enemy.take_damage(0.0)
	enemy.take_damage(-3.0)  # negative also early-returns

	assert_float_eq(enemy.current_hp, 20.0, 0.001, "HP unchanged on amount<=0")
	assert_eq(emits[0], 0, "damage_taken must NOT fire on amount<=0")
	enemy.queue_free()


func test_combat_enemy_take_damage_exact_fatal_triggers_death() -> void:
	# AC-20 explicit edge from story spec: damage = current_hp exactly (no overkill)
	# → still triggers death. Mirrors test #4 for Player but on Enemy path.
	var enemy = _make_test_enemy(5.0, 24.0)
	var died_emits := [0]
	var damage_taken_payload := [null]
	enemy.died.connect(func(_e: Enemy): died_emits[0] += 1)
	enemy.damage_taken.connect(func(cur: float, mx: float, last: float):
		damage_taken_payload[0] = [cur, mx, last]
	)

	enemy.take_damage(5.0)  # exact-fatal — no overkill, just-enough

	assert_float_eq(enemy.current_hp, 0.0, 0.001, "Exact-fatal damage produces 0 HP")
	assert_eq(died_emits[0], 1, "died emits exactly once on exact-fatal")
	assert_not_null(damage_taken_payload[0], "damage_taken still fires on exact-fatal")
	assert_float_eq(damage_taken_payload[0][2], 5.0, 0.001, "last_damage_amount = 5.0")
	# enemy is queue_free'd by _die — do not free again


func test_combat_enemy_dead_state_silently_drops_further_damage() -> void:
	# Mirror of Player dead-state test — Enemy is also inert after death
	var enemy = _make_test_enemy(5.0, 24.0)
	enemy.take_damage(10.0)  # kills enemy
	# After _die(), enemy.queue_free() is called but the node still exists
	# this frame (queue_free is deferred). We can still call methods on it.
	assert_true(enemy._is_dead, "_is_dead flag set after death")

	var damage_emits := [0]
	enemy.damage_taken.connect(func(_a, _b, _c): damage_emits[0] += 1)

	enemy.take_damage(20.0)

	assert_eq(damage_emits[0], 0, "Inert DYING enemy does not emit damage_taken")


# ─── Helpers ──────────────────────────────────────────────────────────────

## Constructs a Player node ready for HP tests. Bypasses the full Player.tscn
## scene since unit tests don't need the visual layer (health bar, level-up
## panel, weapons). Calls `_ready()` of the script directly is not safe —
## instead, instantiate a minimal CharacterBody2D and assign the Player script.
##
## Workaround: load Player.tscn and free child weapon nodes we don't need.
## For now we use direct script instantiation — the Player script will run
## but warnings about missing @onready nodes are expected and ignored.
func _make_test_player(start_hp: float, mx_hp: float) -> Player:
	# Instantiate the player scene to get all @onready references wired
	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	if player_scene == null:
		fail_test("Cannot load Player.tscn — required for HP tests")
		return null
	var player := player_scene.instantiate() as Player
	add_child_autofree(player)
	player.max_hp = mx_hp
	player.current_hp = start_hp
	return player


## Constructs an Enemy with explicit HP values, bypassing archetype.
## Uses Paper Doll archetype for visual children, then overrides HP fields.
func _make_test_enemy(start_hp: float, mx_hp: float) -> Enemy:
	var enemy_scene := load("res://scenes/enemy/Enemy.tscn") as PackedScene
	if enemy_scene == null:
		fail_test("Cannot load Enemy.tscn — required for HP tests")
		return null
	var enemy := enemy_scene.instantiate() as Enemy
	enemy.archetype = PaperDollArchetype  # provides visual config
	add_child_autofree(enemy)
	# Override after _ready (which applies archetype defaults)
	enemy.max_hp = mx_hp
	enemy.current_hp = start_hp
	# Zero XP drop so death tests do NOT spawn an ExperienceOrb. A spawned orb
	# is added via call_deferred to current_scene; in a headless GUT run it ends
	# up orphaned (no current_scene), and its deferred _try_collect_overlapping_bodies
	# calls Area2D.get_overlapping_bodies() while detached from a physics space,
	# which returns null → the engine then calls .size() on null and logs an
	# "Invalid call ... 'size' in base 'Nil'" error on a LATER frame. GUT blames
	# whatever test is running when that deferred error fires (cross-test
	# contamination). Dropping XP here keeps these HP-math tests hermetic;
	# XP-orb spawning is covered separately by the Experience/Pickup suite.
	enemy.xp_drop_value = 0.0
	return enemy
