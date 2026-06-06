## Unit tests for the weapon-side application of 矿脉精粹 crit (Story 008, 土生金) and
## 寒露凝锋 frost slow (Story 009, 金生水) — both delivered through the shared
## WeaponBase.apply_combo_effects() helper that every 修行者 weapon hit site calls.
##
## Covers:
##   - ComboManager.roll_ore_crit: inactive → 1.0; zero-chance → never crits;
##     seeded → deterministic + reproducible + in {1.0, 1.5}
##   - apply_combo_effects: ore crit multiplies damage (deterministic via seeded RNG);
##     frost slow applied to the target when 金生水 active; both at once; null cm pass-through
##   - FlyingSwordWeapon pierce guard (no owner → no bonus)
##
## Uses a real Enemy as the hit target (it owns apply_frost_slow + element + move_speed)
## and a real ComboManager driven via _on_inventory_changed. autofree() teardown.

extends "res://tests/helpers/test_base.gd"


func _make_cm(metal: int, water: int, earth: int) -> ComboManager:
	var cm := ComboManager.new()
	autofree(cm)
	cm._on_inventory_changed({"metal": metal, "wood": 0, "water": water, "fire": 0, "earth": earth})
	return cm


func _make_target(speed: float) -> Enemy:
	var e := Enemy.new()
	autofree(e)
	e.move_speed = speed
	return e


# ─── ComboManager.roll_ore_crit ──────────────────────────────────────────────

func test_roll_ore_crit_inactive_returns_one() -> void:
	var cm := _make_cm(0, 0, 0)  # 土生金 inactive
	assert_float_eq(cm.roll_ore_crit(), 1.0, 0.001, "no 土生金 → no crit (×1.0)")


func test_roll_ore_crit_zero_chance_never_crits() -> void:
	# 土生金 active at the activation threshold (earth=1, metal=1 → steps=0 → chance 0.0)
	var cm := _make_cm(1, 0, 1)
	cm._rng.seed = 0
	for i in range(40):
		assert_float_eq(cm.roll_ore_crit(), 1.0, 0.001, "0%% chance → never crits")


func test_roll_ore_crit_seeded_deterministic_and_in_range() -> void:
	# 土生金 at max steps (earth=5, metal=5 → steps=5 → chance 0.10)
	var cm := _make_cm(5, 0, 5)
	cm._rng.seed = 42
	var crits := 0
	for i in range(200):
		var r := cm.roll_ore_crit()
		assert_true(r == 1.0 or r == ComboManager.ORE_CRIT_MULTIPLIER,
				"roll is exactly 1.0 or 1.5")
		if r > 1.0:
			crits += 1
	assert_true(crits > 0, "some crits occur over 200 rolls at 10%%")
	# Reproducible: same seed → same crit count (seeded RNG, ADR-0006 R-6)
	cm._rng.seed = 42
	var crits2 := 0
	for i in range(200):
		if cm.roll_ore_crit() > 1.0:
			crits2 += 1
	assert_eq(crits, crits2, "same seed → identical crit count (deterministic)")


# ─── apply_combo_effects: ore crit ───────────────────────────────────────────

func test_apply_combo_effects_multiplies_damage_by_ore_crit() -> void:
	# Arrange — 土生金 active (high chance), 金生水 inactive (no frost noise)
	var cm := _make_cm(5, 0, 5)
	cm._rng.seed = 777
	var expected_roll := cm.roll_ore_crit()  # consumes one randf
	cm._rng.seed = 777                        # re-seed to reproduce the same roll
	var target := _make_target(100.0)

	# Act
	var result := WeaponBase.apply_combo_effects(cm, target, 10.0)

	# Assert — damage × the (deterministic) crit roll
	assert_float_eq(result, 10.0 * expected_roll, 0.001, "ore crit multiplies dealt damage")


func test_apply_combo_effects_no_ore_combo_passes_damage_through() -> void:
	var cm := _make_cm(0, 0, 0)  # nothing active
	var target := _make_target(100.0)
	assert_float_eq(WeaponBase.apply_combo_effects(cm, target, 10.0), 10.0, 0.001,
			"no combos → damage unchanged")


# ─── apply_combo_effects: frost slow ─────────────────────────────────────────

func test_apply_combo_effects_applies_frost_slow_when_jinshengshui_active() -> void:
	# Arrange — 金生水 active (metal+water), 土生金 inactive (no crit noise: earth=0)
	var cm := _make_cm(1, 1, 0)
	var target := _make_target(100.0)

	# Act
	var result := WeaponBase.apply_combo_effects(cm, target, 10.0)

	# Assert — frost applied to the target; damage unchanged (no 土生金 crit)
	assert_float_eq(target.frost_slow_factor(), 0.7, 0.001, "金生水 → frost slow applied on hit")
	assert_float_eq(target._effective_move_speed(), 70.0, 0.001, "target slowed to 70")
	assert_float_eq(result, 10.0, 0.001, "no 土生金 → damage unchanged")


func test_apply_combo_effects_both_combos_apply_frost_and_crit() -> void:
	# Arrange — metal+water+earth all high → BOTH 金生水 and 土生金 active
	var cm := _make_cm(5, 5, 5)
	cm._rng.seed = 2024
	var expected_roll := cm.roll_ore_crit()
	cm._rng.seed = 2024
	var target := _make_target(100.0)

	# Act
	var result := WeaponBase.apply_combo_effects(cm, target, 20.0)

	# Assert — frost on target AND crit on damage
	assert_float_eq(target.frost_slow_factor(), 0.7, 0.001, "frost applied")
	assert_float_eq(result, 20.0 * expected_roll, 0.001, "crit applied")


func test_apply_combo_effects_null_cm_is_passthrough() -> void:
	# Arrange — no ComboManager (e.g. another character's weapon)
	var target := _make_target(100.0)

	# Act + Assert — no crit, no frost
	assert_float_eq(WeaponBase.apply_combo_effects(null, target, 10.0), 10.0, 0.001,
			"null cm → damage unchanged")
	assert_float_eq(target.frost_slow_factor(), 1.0, 0.001, "null cm → no frost")


# ─── FlyingSword pierce guard ────────────────────────────────────────────────

func test_flying_sword_pierce_count_no_owner_returns_base() -> void:
	# Arrange — weapon not parented to a Player → owner_combo_manager() is null
	var weapon := FlyingSwordWeapon.new()
	autofree(weapon)
	weapon.pierce_count = 3

	# Act + Assert — no ComboManager → no pierce bonus, base pierce only
	assert_eq(weapon._get_pierce_count(), 3, "no owner ComboManager → base pierce (no +1)")
