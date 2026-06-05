## Unit tests for ComboManager — Five Phases Synergy System (Story 004 / ADR-0006 §Decision 3).
##
## Covers:
##   - Formula 2: each of the 5 generating pairs activates when both elements >= 1
##   - combo_activated signal fires exactly once per newly activated combo
##   - No combo is active on a fresh ComboManager (pre-connection state)
##   - connect_to_player seeds the snapshot from the player's current inventory
##     so a pre-activated combo (Merit Node 11) is detected immediately
##   - connect_to_player is idempotent — calling twice does not double-signal
##   - Formula 3: _scale_steps for each combo (steps = min(A+B-2, MAX_SCALE_STEPS))
##   - Public accessors return 0 / empty dict when combo is inactive
##   - Public accessors return correct values when combo is active and scaled
##   - _on_enemy_killed guard: wrong source element → no burst attempt
##   - _on_enemy_killed guard: wildfire inactive → no burst attempt
##   - _on_enemy_killed guard: null kill_data → no crash
##   - AC-18 / Core Rule 7: all 5 combos coexist from one inventory (no 五行齐全 bonus)
##   - Double-activation: one delta crossing two thresholds fires both combos
##   - Core Rule 6: an activated combo persists when the pair drops below 1+1
##   - R-2 init-order (negative): no combo_activated during seeding, only after connect
##   - Formula 3 scaling at steps=3 for shield / ore-crit / regen accessors
##   - AC-01 canonical incremental path (add earth to fire → 火生土)
##
## NOTE (ADR-0006 Validation): these unit tests prove ComboManager's handler
## LOGIC and activation engine. The CombatEvents.enemy_killed SUBSCRIPTION wired
## in _ready() is NOT exercised here (tests never add the node to the tree, so
## _ready() never runs) — that bus-connection path is integration-tier coverage
## deferred to the 燎原 effect story (Story 006) / combat_events_bus_test.gd.
##
## Instantiation strategy: ComboManager.new() — _ready() looks up the CombatEvents
## autoload via get_node_or_null and only connects if present. Tests never add the
## node to the tree, so _ready() never runs; ComboManager state is driven
## exclusively through _on_inventory_changed and connect_to_player, which only
## need a Player-like object — Player.new() satisfies that without _ready().
##
## Run via:
##   "/tmp/Godot_v4.6-stable_win64_console.exe" --headless --path . \
##       -s res://addons/gut/gut_cmdln.gd \
##       -gtest=res://tests/unit/element/combo_manager_test.gd -gexit

extends "res://tests/helpers/test_base.gd"


## Factory: bare ComboManager (no _ready, no autoload dependency for these tests).
## We bypass _ready() by using _on_inventory_changed directly to feed inventory state.
## autofree() ensures cleanup after each test.
func _make_combo_manager() -> ComboManager:
	var cm := ComboManager.new()
	autofree(cm)
	return cm


## Factory: bare Player (no _ready). Seeds _upgrade_rng for determinism.
func _make_player() -> Player:
	var player := Player.new()
	autofree(player)
	player._upgrade_rng.seed = 0
	return player


## Helper: push a full inventory snapshot into a ComboManager without going
## through Player.  Simulates what connect_to_player triggers after seeding.
func _push_inventory(cm: ComboManager, metal: int, wood: int, water: int, fire: int, earth: int) -> void:
	cm._on_inventory_changed({
		"metal": metal,
		"wood":  wood,
		"water": water,
		"fire":  fire,
		"earth": earth,
	})


# ─── No combo active on fresh instance ───────────────────────────────────────

func test_combo_manager_no_combo_active_on_fresh_instance() -> void:
	# Arrange
	var cm := _make_combo_manager()

	# Assert — none of the 5 combos should be active before any inventory arrives
	assert_false(cm.is_combo_active(ComboManager.COMBO_WILDFIRE), "wildfire inactive on fresh instance")
	assert_false(cm.is_combo_active(ComboManager.COMBO_MOLTEN),   "molten inactive on fresh instance")
	assert_false(cm.is_combo_active(ComboManager.COMBO_ORE),      "ore inactive on fresh instance")
	assert_false(cm.is_combo_active(ComboManager.COMBO_FROST),    "frost inactive on fresh instance")
	assert_false(cm.is_combo_active(ComboManager.COMBO_VERNAL),   "vernal inactive on fresh instance")


# ─── Formula 2: each generating pair activates at threshold ──────────────────

func test_combo_manager_wildfire_activates_when_wood_and_fire_both_one() -> void:
	# Arrange
	var cm := _make_combo_manager()

	# Act — wood=1, fire=1 → 木生火 threshold met
	_push_inventory(cm, 0, 1, 0, 1, 0)

	# Assert
	assert_true(cm.is_combo_active(ComboManager.COMBO_WILDFIRE),
			"COMBO_WILDFIRE active when wood>=1 and fire>=1")
	assert_false(cm.is_combo_active(ComboManager.COMBO_MOLTEN),  "molten not activated")
	assert_false(cm.is_combo_active(ComboManager.COMBO_ORE),     "ore not activated")
	assert_false(cm.is_combo_active(ComboManager.COMBO_FROST),   "frost not activated")
	assert_false(cm.is_combo_active(ComboManager.COMBO_VERNAL),  "vernal not activated")


func test_combo_manager_molten_activates_when_fire_and_earth_both_one() -> void:
	# Arrange
	var cm := _make_combo_manager()

	# Act — fire=1, earth=1 → 火生土 threshold met
	_push_inventory(cm, 0, 0, 0, 1, 1)

	# Assert
	assert_true(cm.is_combo_active(ComboManager.COMBO_MOLTEN),
			"COMBO_MOLTEN active when fire>=1 and earth>=1")
	assert_false(cm.is_combo_active(ComboManager.COMBO_WILDFIRE), "wildfire not activated")


func test_combo_manager_ore_activates_when_earth_and_metal_both_one() -> void:
	# Arrange
	var cm := _make_combo_manager()

	# Act — earth=1, metal=1 → 土生金 threshold met
	_push_inventory(cm, 1, 0, 0, 0, 1)

	# Assert
	assert_true(cm.is_combo_active(ComboManager.COMBO_ORE),
			"COMBO_ORE active when earth>=1 and metal>=1")
	assert_false(cm.is_combo_active(ComboManager.COMBO_MOLTEN), "molten not activated")


func test_combo_manager_frost_activates_when_metal_and_water_both_one() -> void:
	# Arrange
	var cm := _make_combo_manager()

	# Act — metal=1, water=1 → 金生水 threshold met
	_push_inventory(cm, 1, 0, 1, 0, 0)

	# Assert
	assert_true(cm.is_combo_active(ComboManager.COMBO_FROST),
			"COMBO_FROST active when metal>=1 and water>=1")
	assert_false(cm.is_combo_active(ComboManager.COMBO_ORE), "ore not activated")


func test_combo_manager_vernal_activates_when_water_and_wood_both_one() -> void:
	# Arrange
	var cm := _make_combo_manager()

	# Act — water=1, wood=1 → 水生木 threshold met
	_push_inventory(cm, 0, 1, 1, 0, 0)

	# Assert
	assert_true(cm.is_combo_active(ComboManager.COMBO_VERNAL),
			"COMBO_VERNAL active when water>=1 and wood>=1")
	assert_false(cm.is_combo_active(ComboManager.COMBO_FROST), "frost not activated")


# ─── combo_activated signal fires exactly once per combo ─────────────────────

func test_combo_manager_combo_activated_emits_once_on_first_activation() -> void:
	# Arrange
	var cm := _make_combo_manager()
	watch_signals(cm)

	# Act — trigger 木生火
	_push_inventory(cm, 0, 1, 0, 1, 0)

	# Assert — signal fired exactly once with the correct combo id.
	# NOTE: assert_signal_emitted_with_parameters' 4th arg is `index` (int), NOT a
	# message — passing a String there crashes GUT's internal compare. Index 0 =
	# the first (and only) emission.
	assert_signal_emit_count(cm, "combo_activated", 1,
			"combo_activated fires once for the first activation")
	assert_signal_emitted_with_parameters(cm, "combo_activated",
			[ComboManager.COMBO_WILDFIRE], 0)


func test_combo_manager_combo_activated_does_not_re_emit_on_second_inventory_change() -> void:
	# Arrange
	var cm := _make_combo_manager()
	_push_inventory(cm, 0, 1, 0, 1, 0)  # first activation
	watch_signals(cm)                     # start watching AFTER first activation

	# Act — push another change that does not activate a new combo
	_push_inventory(cm, 0, 2, 0, 2, 0)

	# Assert — no further combo_activated for a combo already in _active_combos
	assert_signal_emit_count(cm, "combo_activated", 0,
			"combo_activated does not re-emit for an already-active combo")


# ─── connect_to_player seeds snapshot correctly ───────────────────────────────

func test_combo_manager_connect_to_player_detects_preactivated_combo() -> void:
	# Arrange — seed the player's inventory to fire=1 (Talisman) before connecting
	var player := _make_player()
	player._add_element("fire")
	player._add_element("wood")  # wood=1 + fire=1 → 木生火 should fire immediately
	var cm := _make_combo_manager()
	watch_signals(cm)

	# Act — connect after inventory is populated (mirrors Player._ready() ordering)
	cm.connect_to_player(player)

	# Assert — the snapshot taken in connect_to_player sees wood>=1 and fire>=1
	assert_true(cm.is_combo_active(ComboManager.COMBO_WILDFIRE),
			"pre-activated combo detected immediately on connect_to_player")
	assert_signal_emit_count(cm, "combo_activated", 1,
			"combo_activated fires once during connect_to_player snapshot")


func test_combo_manager_connect_to_player_is_idempotent() -> void:
	# Arrange
	var player := _make_player()
	player._add_element("fire")
	var cm := _make_combo_manager()
	cm.connect_to_player(player)
	watch_signals(cm)

	# Act — second connect call must be a no-op
	cm.connect_to_player(player)
	# Now push an inventory change; if connected twice the signal count would be 2
	player._add_element("wood")

	# Assert — only 1 signal per inventory change (not 2 from a double connection)
	assert_signal_emit_count(cm, "combo_activated", 1,
			"connect_to_player is idempotent: second call does not double-wire the signal")


# ─── Formula 3: scale steps ───────────────────────────────────────────────────

func test_combo_manager_scale_steps_zero_at_activation_threshold() -> void:
	# Arrange — exactly at threshold: wood=1, fire=1 → steps = max(2-2, 0) = 0
	var cm := _make_combo_manager()
	_push_inventory(cm, 0, 1, 0, 1, 0)

	# Assert via get_wildfire_burst_radius (steps=0 → base radius only)
	assert_float_eq(cm.get_wildfire_burst_radius(), ComboManager.WILDFIRE_BASE_BURST_RADIUS,
			0.001, "burst radius equals base when steps=0")


func test_combo_manager_scale_steps_increases_with_extra_elements() -> void:
	# Arrange — wood=2, fire=2 → steps = min(4-2, 5) = 2
	var cm := _make_combo_manager()
	_push_inventory(cm, 0, 2, 0, 2, 0)

	var expected_radius: float = (
		ComboManager.WILDFIRE_BASE_BURST_RADIUS +
		2.0 * ComboManager.WILDFIRE_RADIUS_PER_STEP
	)

	# Assert
	assert_float_eq(cm.get_wildfire_burst_radius(), expected_radius,
			0.001, "burst radius scales correctly at steps=2")


func test_combo_manager_scale_steps_clamps_at_max_scale_steps() -> void:
	# Arrange — metal=10, water=10 → total=20 → steps clamped to MAX_SCALE_STEPS=5
	var cm := _make_combo_manager()
	_push_inventory(cm, 10, 0, 10, 0, 0)

	var expected_duration: float = (
		ComboManager.FROST_BASE_DURATION +
		float(ComboManager.MAX_SCALE_STEPS) * ComboManager.FROST_DURATION_PER_STEP
	)

	# Assert — get_frost_duration uses metal+water scale steps, clamped at MAX_SCALE_STEPS
	assert_float_eq(cm.get_frost_duration(), expected_duration,
			0.001, "frost duration is clamped at MAX_SCALE_STEPS")


# ─── Accessor correctness when inactive ──────────────────────────────────────

func test_combo_manager_accessors_return_zero_or_empty_when_inactive() -> void:
	# Arrange — fresh instance, no inventory
	var cm := _make_combo_manager()

	# Assert all accessors return their inactive sentinel values
	assert_eq(cm.get_pierce_bonus(), 0, "get_pierce_bonus returns 0 when inactive")
	assert_float_eq(cm.get_ore_crit_chance(), 0.0, 0.001,
			"get_ore_crit_chance returns 0.0 when inactive")
	assert_true(cm.get_shield_params().is_empty(),
			"get_shield_params returns empty dict when inactive")
	assert_true(cm.get_regen_params().is_empty(),
			"get_regen_params returns empty dict when inactive")
	assert_float_eq(cm.get_frost_duration(), 0.0, 0.001,
			"get_frost_duration returns 0.0 when inactive")
	assert_float_eq(cm.get_wildfire_burst_radius(), 0.0, 0.001,
			"get_wildfire_burst_radius returns 0.0 when inactive")


# ─── Accessor correctness when active ────────────────────────────────────────

func test_combo_manager_accessors_return_correct_values_when_combos_active() -> void:
	# Arrange — activate ore (earth=1, metal=1) and vernal (water=1, wood=1) at steps=0
	var cm := _make_combo_manager()
	_push_inventory(cm, 1, 1, 1, 0, 1)  # metal=1, wood=1, water=1, earth=1

	# Assert ore (土生金): pierce bonus == ORE_PIERCE_BONUS, crit == steps(0) * per_step == 0.0
	assert_eq(cm.get_pierce_bonus(), ComboManager.ORE_PIERCE_BONUS,
			"get_pierce_bonus returns ORE_PIERCE_BONUS when ore combo active")
	assert_float_eq(cm.get_ore_crit_chance(), 0.0, 0.001,
			"get_ore_crit_chance is 0.0 at steps=0 (earth=1+metal=1 → total==2)")

	# Assert vernal (水生木): hp_per_4s == base, xp_bonus == base (steps=0)
	var regen_params := cm.get_regen_params()
	assert_false(regen_params.is_empty(), "get_regen_params not empty when vernal active")
	assert_float_eq(float(regen_params.get("hp_per_4s", 0.0)),
			ComboManager.VERNAL_BASE_HP_REGEN, 0.001,
			"regen hp_per_4s equals base when steps=0")
	assert_float_eq(float(regen_params.get("xp_bonus", 0.0)),
			ComboManager.VERNAL_BASE_XP_BONUS, 0.001,
			"regen xp_bonus equals base when steps=0")


# ─── _on_enemy_killed guards ─────────────────────────────────────────────────

func test_combo_manager_on_enemy_killed_noop_when_source_element_not_fire() -> void:
	# Arrange — activate wildfire so the element check is the only guard.
	# watch_signals must be called AFTER the activation push: a second
	# watch_signals call does NOT reset GUT's accumulated emit count.
	var cm := _make_combo_manager()
	_push_inventory(cm, 0, 1, 0, 1, 0)  # wildfire active (pre-watch)
	watch_signals(cm)

	# Act — kill from "metal" source, not "fire"
	var kill_data := EnemyKillData.new("metal", 50.0, Vector2.ZERO)
	cm._on_enemy_killed(kill_data)

	# Assert — no combo_activated (wildfire is already active, no new combos triggered)
	# This test validates the source_element guard does not crash and does not
	# erroneously trigger a second activation signal.
	assert_signal_emit_count(cm, "combo_activated", 0,
			"non-fire kill does not produce a combo_activated")


func test_combo_manager_on_enemy_killed_noop_when_wildfire_inactive() -> void:
	# Arrange — do NOT activate wildfire
	var cm := _make_combo_manager()
	watch_signals(cm)
	_push_inventory(cm, 0, 0, 0, 1, 0)  # only fire=1, wood=0 → wildfire NOT active

	# Act — fire kill arrives but wildfire combo is inactive
	var kill_data := EnemyKillData.new("fire", 100.0, Vector2.ZERO)
	cm._on_enemy_killed(kill_data)

	# Assert — no combo signal, no crash
	assert_signal_emit_count(cm, "combo_activated", 0,
			"fire kill with inactive wildfire does not emit combo_activated")


func test_combo_manager_on_enemy_killed_null_kill_data_does_not_crash() -> void:
	# Arrange
	var cm := _make_combo_manager()
	_push_inventory(cm, 0, 1, 0, 1, 0)  # wildfire active

	# Act — null guard must prevent any NullReference errors
	cm._on_enemy_killed(null)

	# Assert — still active, no crash occurred (test itself proves no exception)
	assert_true(cm.is_combo_active(ComboManager.COMBO_WILDFIRE),
			"ComboManager remains valid after null kill_data call")


# ─── AC-18 / Core Rule 7: all 5 combos coexist (no 五行齐全 bonus) ─────────────

func test_combo_manager_all_five_combos_active_when_every_element_present() -> void:
	# Arrange — fresh manager, watch from the start to count total activations
	var cm := _make_combo_manager()
	watch_signals(cm)

	# Act — a single inventory with all 5 elements >= 1
	_push_inventory(cm, 1, 1, 1, 1, 1)

	# Assert — all 5 generating combos coexist
	assert_true(cm.is_combo_active(ComboManager.COMBO_WILDFIRE), "木生火 active")
	assert_true(cm.is_combo_active(ComboManager.COMBO_MOLTEN),   "火生土 active")
	assert_true(cm.is_combo_active(ComboManager.COMBO_ORE),      "土生金 active")
	assert_true(cm.is_combo_active(ComboManager.COMBO_FROST),    "金生水 active")
	assert_true(cm.is_combo_active(ComboManager.COMBO_VERNAL),   "水生木 active")
	# Exactly 5 activations — no special 五行齐全 bonus combo appears
	assert_signal_emit_count(cm, "combo_activated", 5,
			"all 5 combos activate, no extra bonus (no 五行齐全)")


# ─── Double-activation: one delta crosses two thresholds ─────────────────────

func test_combo_manager_single_change_activates_two_combos() -> void:
	# Arrange — wood=1, earth=1 present but no combo yet (fire=0)
	var cm := _make_combo_manager()
	_push_inventory(cm, 0, 1, 0, 0, 1)
	assert_false(cm.is_combo_active(ComboManager.COMBO_WILDFIRE), "precondition: 木生火 inactive")
	assert_false(cm.is_combo_active(ComboManager.COMBO_MOLTEN),   "precondition: 火生土 inactive")
	watch_signals(cm)  # watch AFTER the no-op setup push

	# Act — add fire: crosses BOTH 木生火 (wood+fire) and 火生土 (fire+earth) thresholds
	_push_inventory(cm, 0, 1, 0, 1, 1)

	# Assert — both combos activate from one delta, two distinct signals
	assert_true(cm.is_combo_active(ComboManager.COMBO_WILDFIRE), "木生火 active after adding fire")
	assert_true(cm.is_combo_active(ComboManager.COMBO_MOLTEN),   "火生土 active after adding fire")
	assert_signal_emit_count(cm, "combo_activated", 2,
			"single inventory delta crossing two thresholds fires combo_activated twice")


# ─── Core Rule 6: persistence guard (pair drops below 1+1) ───────────────────

func test_combo_manager_combo_persists_when_pair_drops_below_threshold() -> void:
	# Arrange — activate 木生火 (wood=1, fire=1)
	var cm := _make_combo_manager()
	_push_inventory(cm, 0, 1, 0, 1, 0)
	assert_true(cm.is_combo_active(ComboManager.COMBO_WILDFIRE), "precondition: 木生火 active")

	# Act — a later inventory drops the pair below 1+1 (defensive: increment-only
	# means this cannot happen in-game, but the persistence guard must hold)
	_push_inventory(cm, 0, 0, 0, 0, 0)

	# Assert — Core Rule 6: an activated combo never deactivates
	assert_true(cm.is_combo_active(ComboManager.COMBO_WILDFIRE),
			"Core Rule 6: combo persists even when the pair drops below threshold")


# ─── R-2 init-order (negative): no emit during seeding, only after connect ───

func test_combo_manager_no_combo_activated_during_seeding_only_after_connect() -> void:
	# Arrange — a Player seeded into a combo-satisfying state, and a ComboManager
	# that is NOT yet connected. This models Player._ready() ordering: the seed
	# happens BEFORE connect_to_player (which Player calls after run_initialized).
	var player := _make_player()
	var cm := _make_combo_manager()
	watch_signals(cm)

	# Act 1 — seed the inventory to wood=1, fire=1 WITHOUT connecting cm.
	# R-2: cm must observe NOTHING during the seeding window.
	player._add_element("wood")
	player._add_element("fire")
	assert_signal_emit_count(cm, "combo_activated", 0,
			"R-2: no combo_activated emitted during seeding (cm not yet connected)")

	# Act 2 — now connect (the post-run_initialized step)
	cm.connect_to_player(player)

	# Assert — the combo fires exactly once, only at/after connect
	assert_signal_emit_count(cm, "combo_activated", 1,
			"R-2: combo_activated fires once, only after connect_to_player")
	assert_true(cm.is_combo_active(ComboManager.COMBO_WILDFIRE), "木生火 active post-connect")


# ─── Formula 3 scaling at steps=3 (GDD example values) ───────────────────────

func test_combo_manager_shield_params_scale_at_steps_three() -> void:
	# Arrange — 火生土: fire=2, earth=3 → total=5 → steps=3 (GDD Formula 5 example)
	var cm := _make_combo_manager()
	_push_inventory(cm, 0, 0, 0, 2, 3)

	# Act
	var params := cm.get_shield_params()

	# Assert — max_hp = 15 + 3*5 = 30; regen = 3 + 3*1 = 6
	assert_false(params.is_empty(), "shield params non-empty when 火生土 active")
	assert_float_eq(float(params.get("max_hp", 0.0)), 30.0, 0.001, "shield max_hp at steps=3 == 30")
	assert_float_eq(float(params.get("regen", 0.0)), 6.0, 0.001, "shield regen at steps=3 == 6")


func test_combo_manager_ore_crit_chance_scales_at_steps_three() -> void:
	# Arrange — 土生金: earth=2, metal=3 → total=5 → steps=3
	var cm := _make_combo_manager()
	_push_inventory(cm, 3, 0, 0, 0, 2)

	# Act + Assert — crit = 3 * 0.02 = 0.06
	assert_float_eq(cm.get_ore_crit_chance(), 0.06, 0.001, "ore crit at steps=3 == 0.06")


func test_combo_manager_regen_params_scale_at_steps_three() -> void:
	# Arrange — 水生木: water=2, wood=3 → total=5 → steps=3 (GDD Formula 7 example)
	var cm := _make_combo_manager()
	_push_inventory(cm, 0, 3, 2, 0, 0)

	# Act
	var params := cm.get_regen_params()

	# Assert — hp_per_4s = 2 + 3*1 = 5; xp_bonus = 0.15 + 3*0.05 = 0.30
	assert_false(params.is_empty(), "regen params non-empty when 水生木 active")
	assert_float_eq(float(params.get("hp_per_4s", 0.0)), 5.0, 0.001, "regen hp_per_4s at steps=3 == 5")
	assert_float_eq(float(params.get("xp_bonus", 0.0)), 0.30, 0.001, "regen xp_bonus at steps=3 == 0.30")


# ─── AC-01 canonical incremental path (add earth to fire → 火生土) ───────────

func test_combo_manager_ac01_adding_earth_to_fire_activates_molten() -> void:
	# Arrange — AC-01 canonical sequence: {fire:1, earth:0}, no combo yet
	var cm := _make_combo_manager()
	_push_inventory(cm, 0, 0, 0, 1, 0)
	assert_false(cm.is_combo_active(ComboManager.COMBO_MOLTEN), "precondition: 火生土 inactive at fire=1")
	watch_signals(cm)  # watch AFTER the setup push

	# Act — apply an Earth upgrade → {fire:1, earth:1}
	_push_inventory(cm, 0, 0, 0, 1, 1)

	# Assert — combo_activated("火生土") fires exactly once
	assert_signal_emit_count(cm, "combo_activated", 1, "AC-01: one activation when earth added to fire")
	assert_signal_emitted_with_parameters(cm, "combo_activated", [ComboManager.COMBO_MOLTEN], 0)
	assert_true(cm.is_combo_active(ComboManager.COMBO_MOLTEN), "AC-01: 火生土 active")


# ─── Formula 3 scaling at steps=3 for the remaining two accessors ────────────
# (Closes the asymmetry flagged by /code-review: shield/ore/regen had steps=3
#  tests; frost + wildfire only had steps=0/2/5. All five now pinned at steps=3.)

func test_combo_manager_frost_duration_scales_at_steps_three() -> void:
	# Arrange — 金生水: metal=2, water=3 → total=5 → steps=3
	var cm := _make_combo_manager()
	_push_inventory(cm, 2, 0, 3, 0, 0)

	# Act + Assert — duration = 1.5 + 3*0.3 = 2.4
	assert_float_eq(cm.get_frost_duration(), 2.4, 0.001, "frost duration at steps=3 == 2.4")


func test_combo_manager_wildfire_burst_radius_scales_at_steps_three() -> void:
	# Arrange — 木生火: wood=2, fire=3 → total=5 → steps=3 (GDD Formula 4 example)
	var cm := _make_combo_manager()
	_push_inventory(cm, 0, 2, 0, 3, 0)

	# Act + Assert — radius = 40 + 3*8 = 64
	assert_float_eq(cm.get_wildfire_burst_radius(), 64.0, 0.001, "burst radius at steps=3 == 64")


# ─── connect_to_player(null) guard — push_error, no crash, no state change ────

func test_combo_manager_connect_to_player_null_does_not_crash() -> void:
	# Arrange
	var cm := _make_combo_manager()
	watch_signals(cm)

	# Act — null player must be guarded (push_error + early return), not crash
	cm.connect_to_player(null)

	# Assert — ComboManager remains valid: no combos activated, no signal
	assert_false(cm.is_combo_active(ComboManager.COMBO_WILDFIRE),
			"no combo active after connect_to_player(null)")
	assert_signal_emit_count(cm, "combo_activated", 0,
			"connect_to_player(null) emits no combo_activated")


# ─── Snapshot isolation — _inventory is a copy, not a live alias ─────────────
# Regression guard for the .duplicate() fix: if _on_inventory_changed ever aliases
# the caller's dict again, a post-call mutation would leak into cm's accessors.

func test_combo_manager_inventory_snapshot_isolated_from_caller_mutation() -> void:
	# Arrange — 木生火 active at steps=3 (wood=2, fire=3 → radius 64)
	var cm := _make_combo_manager()
	var inv: Dictionary = {"metal": 0, "wood": 2, "water": 0, "fire": 3, "earth": 0}
	cm._on_inventory_changed(inv)
	assert_float_eq(cm.get_wildfire_burst_radius(), 64.0, 0.001, "precondition: radius 64 at steps=3")

	# Act — mutate the dict the caller passed, AFTER the call returned
	inv["wood"] = 0
	inv["fire"] = 0

	# Assert — cm's internal snapshot is unaffected (still steps=3 → radius 64).
	# An aliasing regression would drop steps to 0 here → radius 40.
	assert_float_eq(cm.get_wildfire_burst_radius(), 64.0, 0.001,
			"snapshot isolates cm from post-call caller mutation (.duplicate guard)")
