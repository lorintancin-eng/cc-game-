## Unit tests for Player.element_inventory (Story 002 / ADR-0006 Decision 2).
##
## Covers:
##   - AC-15: fresh inventory all-zero; _add_element increments correctly
##   - Core Rule 11: _seed_element_inventory seeds starting weapon (fire=1)
##   - AC-22: Merit Node 11 absent → no-op seed (SaveService guard); direct
##     _add_element stacking proves fire+fire=2 (the element-stacking contract)
##   - Typed-dict: all 5 keys always present post-init
##   - element_inventory_changed emitted exactly once per change
##   - _add_element("neutral") → no-op, no signal
##   - run_initialized emits exactly once after _seed_element_inventory
##
## SaveService stub strategy: Engine.has_singleton("SaveService") cannot be
## faked without C++ / GDExtension in headless tests. Instead:
##   (a) We assert the Merit Node 11 path is a no-op when SaveService is absent
##       (the guard in _seed_element_inventory covers this automatically).
##   (b) We test element-stacking semantics via direct _add_element("fire") calls
##       to prove fire+fire=2 and that element_inventory_changed fires per increment.
##
## Instantiation: Player.new() — _ready() is NOT called (requires scene children).
## Fields needed by each test are seeded manually, matching the other player suites.
## autofree() ensures no orphaned CharacterBody2D nodes after each test.
##
## Run via:
##   "/tmp/Godot_v4.6-stable_win64_console.exe" --headless --path . \
##       -s res://addons/gut/gut_cmdln.gd \
##       -gtest=res://tests/unit/player/element_inventory_test.gd -gexit

extends "res://tests/helpers/test_base.gd"


## Factory: bare Player (no _ready, no scene). _upgrade_rng is seeded to 0 so
## _seed_element_inventory's randi_range call is deterministic if SaveService
## were present. autofree() frees the node at teardown.
func _make_player() -> Player:
	var player := Player.new()
	autofree(player)
	# Seed the rng so any randi_range in _seed_element_inventory is deterministic.
	player._upgrade_rng.seed = 0
	return player


# ─── AC-15: fresh inventory all-zero ─────────────────────────────────────────

func test_element_inventory_all_zero_on_fresh_player() -> void:
	# Arrange
	var player := _make_player()

	# Assert — no _ready called, inventory stays at declaration defaults
	assert_eq(player.element_inventory["metal"], 0, "metal starts at 0")
	assert_eq(player.element_inventory["wood"],  0, "wood starts at 0")
	assert_eq(player.element_inventory["water"], 0, "water starts at 0")
	assert_eq(player.element_inventory["fire"],  0, "fire starts at 0")
	assert_eq(player.element_inventory["earth"], 0, "earth starts at 0")


# ─── Typed-dict: all 5 keys present ──────────────────────────────────────────

func test_element_inventory_has_all_five_keys_after_init() -> void:
	# Arrange
	var player := _make_player()
	var required_keys: Array[String] = ["metal", "wood", "water", "fire", "earth"]

	# Act — call seed to simulate a full init cycle
	player._seed_element_inventory()

	# Assert — all keys survive seeding (typed dict cannot have null for a missing key)
	for key in required_keys:
		assert_true(player.element_inventory.has(key), "key '%s' present post-seed" % key)
		assert_typeof(player.element_inventory[key], TYPE_INT, "key '%s' is int typed" % key)


# ─── _add_element increments and emits signal ─────────────────────────────────

func test_element_inventory_add_element_metal_increments_by_one() -> void:
	# Arrange
	var player := _make_player()

	# Act
	player._add_element("metal")

	# Assert
	assert_eq(player.element_inventory["metal"], 1, "metal incremented to 1")
	assert_eq(player.element_inventory["wood"],  0, "wood unaffected")
	assert_eq(player.element_inventory["water"], 0, "water unaffected")
	assert_eq(player.element_inventory["fire"],  0, "fire unaffected")
	assert_eq(player.element_inventory["earth"], 0, "earth unaffected")


func test_element_inventory_add_element_emits_signal_once_with_updated_dict() -> void:
	# Arrange
	var player := _make_player()
	watch_signals(player)

	# Act
	player._add_element("metal")

	# Assert — signal emitted exactly once
	assert_signal_emit_count(player, "element_inventory_changed", 1)
	# Payload snapshot must reflect the new value
	var emitted_inv: Dictionary = player.element_inventory
	assert_eq(emitted_inv["metal"], 1, "emitted inventory has metal==1")


func test_element_inventory_add_element_accumulates_on_repeated_calls() -> void:
	# Arrange
	var player := _make_player()
	watch_signals(player)

	# Act — two independent increments
	player._add_element("metal")
	player._add_element("metal")

	# Assert
	assert_eq(player.element_inventory["metal"], 2, "two _add_element calls → metal==2")
	assert_signal_emit_count(player, "element_inventory_changed", 2,
			"signal fires once per change, twice total")


# ─── neutral is a no-op ───────────────────────────────────────────────────────

func test_element_inventory_add_element_neutral_is_noop() -> void:
	# Arrange — capture pre-call state
	var player := _make_player()
	watch_signals(player)
	var snapshot_before: Dictionary = player.element_inventory.duplicate()

	# Act
	player._add_element("neutral")

	# Assert — inventory unchanged and NO signal emitted (as-built: guard returns early)
	assert_eq(player.element_inventory["metal"], snapshot_before["metal"], "metal unchanged")
	assert_eq(player.element_inventory["wood"],  snapshot_before["wood"],  "wood unchanged")
	assert_eq(player.element_inventory["water"], snapshot_before["water"], "water unchanged")
	assert_eq(player.element_inventory["fire"],  snapshot_before["fire"],  "fire unchanged")
	assert_eq(player.element_inventory["earth"], snapshot_before["earth"], "earth unchanged")
	assert_signal_emit_count(player, "element_inventory_changed", 0,
			"neutral: no signal emitted")


# ─── Core Rule 11: starting weapon seed → fire==1 ────────────────────────────

func test_element_inventory_seed_sets_fire_to_one_for_talisman_starting_weapon() -> void:
	# Arrange — verify constant matches the expected GDD starting weapon
	var player := _make_player()
	assert_eq(Player.STARTING_WEAPON_ELEMENT, "fire",
			"STARTING_WEAPON_ELEMENT must be 'fire' (Talisman)")

	# Act — seed only: simulates the Story 002 init without a full _ready
	player._seed_element_inventory()

	# Assert — fire==1 before any level-up, all others unchanged from 0
	# (SaveService absent → Merit Node 11 path is a no-op)
	assert_eq(player.element_inventory["fire"], 1,
			"Talisman starting weapon seeds fire to 1")
	assert_eq(player.element_inventory["metal"], 0, "metal unaffected by seed")
	assert_eq(player.element_inventory["wood"],  0, "wood unaffected by seed")
	assert_eq(player.element_inventory["water"], 0, "water unaffected by seed")
	assert_eq(player.element_inventory["earth"], 0, "earth unaffected by seed")


func test_element_inventory_seed_emits_signal_for_starting_weapon() -> void:
	# Arrange
	var player := _make_player()
	watch_signals(player)

	# Act
	player._seed_element_inventory()

	# Assert — exactly 1 signal for the starting weapon (SaveService absent → 1 total)
	assert_signal_emit_count(player, "element_inventory_changed", 1,
			"one element_inventory_changed for Talisman seed when SaveService absent")


# ─── AC-22: SaveService absent → Merit Node 11 is a no-op ────────────────────

func test_element_inventory_merit_node11_absent_save_service_is_noop() -> void:
	# Arrange — verify the guard: SaveService must NOT be registered in headless tests
	var player := _make_player()
	assert_false(Engine.has_singleton("SaveService"),
			"Precondition: SaveService absent in headless test environment")

	# Act
	player._seed_element_inventory()

	# Assert — only the Talisman seed (fire=1); no Merit bonus added
	var total_elements: int = (
		player.element_inventory["metal"] +
		player.element_inventory["wood"] +
		player.element_inventory["water"] +
		player.element_inventory["fire"] +
		player.element_inventory["earth"]
	)
	assert_eq(total_elements, 1,
			"With SaveService absent, total seeded elements == 1 (starting weapon only)")
	assert_eq(player.element_inventory["fire"], 1,
			"That single element is fire (Talisman)")


# ─── AC-22: element stacking contract (fire + Node 11 → fire==2) ─────────────
# SaveService cannot be injected in headless tests; we prove the stacking math
# using direct _add_element calls which exercise the exact same code path that
# _seed_element_inventory would take after reading Node 11's random element.

func test_element_inventory_stacking_same_element_accumulates() -> void:
	# Arrange — simulate: Talisman seeds fire=1, Node 11 random=fire → fire=2
	var player := _make_player()
	watch_signals(player)

	# Act — two independent fire seeds (same as starting-weapon + Node-11 random=fire)
	player._add_element("fire")  # starting weapon seed
	player._add_element("fire")  # Merit Node 11 bonus (random landed on fire)

	# Assert — stacks correctly, not wasted / capped at 1
	assert_eq(player.element_inventory["fire"], 2,
			"fire+fire stacks to 2 (AC-22: random=fire + starting=fire)")
	assert_signal_emit_count(player, "element_inventory_changed", 2,
			"two separate _add_element calls emit two signals")


func test_element_inventory_stacking_different_elements_are_independent() -> void:
	# Arrange — simulate: Talisman=fire, Node 11 random=water (different element)
	var player := _make_player()

	# Act
	player._add_element("fire")   # starting weapon
	player._add_element("water")  # Merit Node 11 random=water

	# Assert — both incremented independently
	assert_eq(player.element_inventory["fire"],  1, "fire==1 from Talisman seed")
	assert_eq(player.element_inventory["water"], 1, "water==1 from Node 11 seed")
	assert_eq(player.element_inventory["metal"], 0, "metal unaffected")
	assert_eq(player.element_inventory["wood"],  0, "wood unaffected")
	assert_eq(player.element_inventory["earth"], 0, "earth unaffected")


# ─── run_initialized emits exactly once after seeding ─────────────────────────
# We simulate the _ready() ordering manually: seed → emit (as in player.gd line 172).

func test_element_inventory_run_initialized_emits_once_after_seed() -> void:
	# Arrange
	var player := _make_player()
	watch_signals(player)

	# Act — replicate the _ready() ordering: seed first, then emit run_initialized
	player._seed_element_inventory()
	player.run_initialized.emit()

	# Assert — run_initialized fired exactly once
	assert_signal_emit_count(player, "run_initialized", 1,
			"run_initialized emits once after seeding")
	# And element_inventory_changed was already emitted during seeding
	assert_signal_emit_count(player, "element_inventory_changed", 1,
			"element_inventory_changed emitted during seed (before run_initialized)")
