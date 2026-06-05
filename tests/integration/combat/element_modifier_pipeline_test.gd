## Integration test for Story 005 — weapon-side 相克 (overcoming-cycle) element
## matchup + element tags on weapon/enemy data.
##
## AS-BUILT NOTE: combat has no central Formula 1 pipeline; weapons multiply their
## outgoing damage by ElementMatchup.modifier(weapon.element, target.element) before
## the flat take_damage(amount) call (same shape as Sun Wukong's _get_fire_eyes_modifier).
## These tests exercise that weapon-side path end-to-end + verify the .tres / scene tags.
##
## Covers:
##   - AC-13: metal weapon vs wood target → dealt damage × 1.3
##   - AC-14: metal vs fire → × 0.8; neutral → × 1.0 (unchanged)
##   - Data-driven: swapping the weapon element changes the matchup with no code change
##   - WeaponBase.element_of safe-read (missing property → neutral)
##   - Coverage floor (ADR-0008 anti-dormancy): both Bosses + ≥4 Stage-1 non-neutral
##   - Enemy .tres element assignments match the GDD
##   - The 6 修行者 weapons carry the GDD elements in Player.tscn (read via SceneState)
##
## Run via:
##   "/tmp/Godot_v4.6-stable_win64_console.exe" --headless \
##       -s res://addons/gut/gut_cmdln.gd \
##       -gtest=res://tests/integration/combat/element_modifier_pipeline_test.gd -gexit
## (Only valid element strings are used so no ElementMatchup push_error fires.)

extends "res://tests/helpers/test_base.gd"


## Stub enemy: in-group "enemies", exposes `element`, captures the take_damage amount.
class StubTarget extends Node2D:
	var element: String = "neutral"
	var received_damage: float = -1.0

	func take_damage(amount: float) -> void:
		received_damage = amount


## Factory: an in-tree stub target tagged with [param elem]. In-tree so the
## projectile's is_in_group("enemies") guard passes reliably.
func _make_stub(elem: String) -> StubTarget:
	var s := StubTarget.new()
	s.element = elem
	s.add_to_group("enemies")
	add_child(s)
	autofree(s)
	return s


## Factory: a fresh Flying Sword projectile (metal) with a known base damage.
func _make_metal_sword(base_damage: float) -> FlyingSwordProjectile:
	var p := FlyingSwordProjectile.new()
	p.element = "metal"
	p.damage = base_damage
	p.pierce_count = 1
	autofree(p)
	return p


# ─── AC-13: favorable matchup (metal vs wood) → ×1.3 ─────────────────────────

func test_element_modifier_metal_vs_wood_multiplies_damage_by_1_3() -> void:
	# Arrange
	var proj := _make_metal_sword(10.0)
	var target := _make_stub("wood")

	# Act — exercise the weapon-side hit path
	proj._on_body_entered(target)

	# Assert — 10 × 1.3 = 13
	assert_float_eq(target.received_damage, 13.0, 0.001, "metal vs wood → 10 × 1.3 = 13")


# ─── AC-14: unfavorable matchup (metal vs fire) → ×0.8 ───────────────────────

func test_element_modifier_metal_vs_fire_multiplies_damage_by_0_8() -> void:
	# Arrange
	var proj := _make_metal_sword(10.0)
	var target := _make_stub("fire")

	# Act
	proj._on_body_entered(target)

	# Assert — 10 × 0.8 = 8
	assert_float_eq(target.received_damage, 8.0, 0.001, "metal vs fire → 10 × 0.8 = 8")


# ─── neutral target → ×1.0 (unchanged) ───────────────────────────────────────

func test_element_modifier_metal_vs_neutral_unchanged() -> void:
	# Arrange
	var proj := _make_metal_sword(10.0)
	var target := _make_stub("neutral")

	# Act
	proj._on_body_entered(target)

	# Assert — neutral short-circuit → ×1.0
	assert_float_eq(target.received_damage, 10.0, 0.001, "metal vs neutral → ×1.0 = 10")


# ─── Data-driven: swapping weapon element changes the matchup, no code change ─

func test_element_modifier_data_driven_weapon_element_change_changes_result() -> void:
	# Arrange — same base damage, same wood target, two different weapon elements
	var metal_proj := _make_metal_sword(10.0)
	var t_metal := _make_stub("wood")
	var water_proj := FlyingSwordProjectile.new()
	water_proj.element = "water"  # water vs wood = unrelated pair → 1.0
	water_proj.damage = 10.0
	water_proj.pierce_count = 1
	autofree(water_proj)
	var t_water := _make_stub("wood")

	# Act
	metal_proj._on_body_entered(t_metal)
	water_proj._on_body_entered(t_water)

	# Assert — different element → different result (13 vs 10) with no code change
	assert_float_eq(t_metal.received_damage, 13.0, 0.001, "metal vs wood → 13")
	assert_float_eq(t_water.received_damage, 10.0, 0.001, "water vs wood → 10 (unrelated)")
	assert_ne(t_metal.received_damage, t_water.received_damage,
			"swapping the weapon element changes the matchup result")


# ─── WeaponBase.element_of safe-read ─────────────────────────────────────────

func test_element_of_returns_neutral_for_node_without_element() -> void:
	# Arrange
	var bare := Node2D.new()
	autofree(bare)
	var tagged := _make_stub("fire")

	# Assert — missing property → neutral; present property → its value
	assert_eq(WeaponBase.element_of(bare), "neutral", "node without element → neutral")
	assert_eq(WeaponBase.element_of(tagged), "fire", "node with element → its value")


# ─── Coverage floor (ADR-0008 anti-dormancy): bosses + ≥4 Stage-1 non-neutral ─

func test_element_coverage_floor_bosses_and_stage1_nonneutral() -> void:
	# Both Bosses must carry a non-neutral element
	for boss in ["famine_beast", "judge"]:
		var arch: Resource = load("res://resources/enemies/%s.tres" % boss)
		assert_ne(String(arch.element), "neutral",
				"%s boss must carry a non-neutral element" % boss)

	# ≥4 of the 6 Stage-1 enemies must be non-neutral
	var stage1 := ["paper_doll", "wandering_soul", "fox_spirit", "ghost_flame", "stone_golem", "shanxiao_elite"]
	var nonneutral := 0
	for slug in stage1:
		var arch: Resource = load("res://resources/enemies/%s.tres" % slug)
		if String(arch.element) != "neutral":
			nonneutral += 1
	assert_true(nonneutral >= 4, "≥4 Stage-1 enemies non-neutral (got %d)" % nonneutral)


# ─── Enemy .tres element assignments match the GDD (matchup-critical spot-check) ─

func test_element_tres_assignments_match_gdd() -> void:
	var expected := {
		"paper_doll": "wood", "ghost_flame": "fire", "stone_golem": "earth",
		"shanxiao_elite": "metal", "famine_beast": "earth", "judge": "metal",
	}
	for slug in expected:
		var arch: Resource = load("res://resources/enemies/%s.tres" % slug)
		assert_eq(String(arch.element), expected[slug], "%s element tag" % slug)


# ─── Weapon scene tags: 6 修行者 weapons carry GDD elements (SceneState, no instantiation) ─

func test_player_scene_weapon_elements_match_gdd() -> void:
	var packed: PackedScene = load("res://scenes/player/Player.tscn")
	var state := packed.get_state()
	var expected := {
		"TalismanWeapon": "fire", "FlyingSwordWeapon": "metal", "ThunderLawWeapon": "water",
		"BaguaArrayWeapon": "earth", "ExplosiveTalismanWeapon": "fire", "MountainSealWeapon": "earth",
	}
	for node_name in expected:
		assert_eq(_scene_node_element(state, node_name), expected[node_name],
				"%s element in Player.tscn" % node_name)


## Reads a node's `element` property override from a packed SceneState without
## instantiating the scene. Returns "<not found>" if the node or property is absent.
func _scene_node_element(state: SceneState, node_name: String) -> String:
	for i in range(state.get_node_count()):
		if state.get_node_name(i) == node_name:
			for p in range(state.get_node_property_count(i)):
				if state.get_node_property_name(i, p) == "element":
					return str(state.get_node_property_value(i, p))
	return "<not found>"
