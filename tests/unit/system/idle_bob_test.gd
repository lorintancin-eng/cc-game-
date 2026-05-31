## Validates IdleBob.bob_offset — the pure sine displacement used for the player's
## cosmetic idle bob (Art Bible §5.3). The bob FEEL is visual (not automated, per the
## testing standards' "What NOT to Automate"); this guards only the deterministic math:
## a full sine cycle per period, bounded by amplitude, zero-period safe.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/system -gexit

extends "res://tests/helpers/test_base.gd"

const IdleBobScript = preload("res://scripts/system/idle_bob.gd")

const AMP := 2.0
const PERIOD := 1.0


func test_idle_bob_offset_at_zero_is_zero() -> void:
	# Arrange / Act / Assert: sine starts at 0.
	assert_float_eq(IdleBobScript.bob_offset(0.0, AMP, PERIOD), 0.0, 0.001, "t=0 → 0")


func test_idle_bob_offset_quarter_period_is_positive_amplitude() -> void:
	# Act: a quarter cycle reaches +amplitude (sin 90°).
	assert_float_eq(IdleBobScript.bob_offset(PERIOD * 0.25, AMP, PERIOD), AMP, 0.001,
		"quarter period → +amplitude")


func test_idle_bob_offset_half_period_returns_to_zero() -> void:
	# Act: half a cycle crosses zero (sin 180°).
	assert_float_eq(IdleBobScript.bob_offset(PERIOD * 0.5, AMP, PERIOD), 0.0, 0.001,
		"half period → 0")


func test_idle_bob_offset_three_quarter_period_is_negative_amplitude() -> void:
	# Act: three quarters reaches -amplitude (sin 270°).
	assert_float_eq(IdleBobScript.bob_offset(PERIOD * 0.75, AMP, PERIOD), -AMP, 0.001,
		"three-quarter period → -amplitude")


func test_idle_bob_offset_never_exceeds_amplitude() -> void:
	# Arrange / Act / Assert: bounded by amplitude across a full cycle (sampled).
	for i in range(40):
		var t := float(i) * 0.05
		var offset: float = IdleBobScript.bob_offset(t, AMP, PERIOD)
		assert_true(absf(offset) <= AMP + 0.001, "|offset| <= amplitude at t=%f (got %f)" % [t, offset])


func test_idle_bob_offset_zero_period_is_finite_no_crash() -> void:
	# Act: period 0 is floored internally (no divide-by-zero); result must be finite.
	var offset: float = IdleBobScript.bob_offset(0.5, AMP, 0.0)
	assert_true(is_finite(offset), "zero period yields a finite offset (no divide-by-zero)")
	assert_true(absf(offset) <= AMP + 0.001, "zero-period offset still bounded by amplitude")
