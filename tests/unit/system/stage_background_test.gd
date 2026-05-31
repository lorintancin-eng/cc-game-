## Validates the per-stage background color system (Art Bible §4.4 / §6.2).
##
## Guards: (1) StageConfig's default world base is 黛黑 with no shift; (2) each stage
## authors the correct color temperature (荒山 cool / 幽都 warm / 交易 warm-paper);
## (3) Background.resolve_base_color blends + clamps so 黛黑 stays dominant
## (§4.6 rule 2: ≥55% of frame ⇒ resolved base must read ink-dark, never gold).
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/system -gexit

extends "res://tests/helpers/test_base.gd"

const BackgroundScript = preload("res://scripts/system/background.gd")
const StageOneConfigScript = preload("res://scripts/resources/stage_one_config.gd")
const StageTwoConfigScript = preload("res://scripts/resources/stage_two_config.gd")
const InterludeConfigScript = preload("res://scripts/resources/ghost_market_interlude_config.gd")

const INK_BLACK := Color(0.094, 0.086, 0.110)
## §4.6 rule 2: the resolved base must stay ink-dominant. Gold (#DCB450 ≈ 0.86) is
## nowhere near this — any stage whose brightest channel exceeds this is a palette bug.
const INK_DOMINANT_MAX_CHANNEL := 0.25


func _max_channel(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b))


# ─── StageConfig default ───────────────────────────────────────────────────

func test_stage_config_default_background_is_ink_black_no_shift() -> void:
	# Arrange / Act
	var config := StageConfig.new()
	# Assert: default base is 黛黑 and there is NO temperature shift (strength 0).
	assert_float_eq(config.background_color.r, INK_BLACK.r, 0.001, "default base r = 黛黑")
	assert_float_eq(config.background_color.g, INK_BLACK.g, 0.001, "default base g = 黛黑")
	assert_float_eq(config.background_color.b, INK_BLACK.b, 0.001, "default base b = 黛黑")
	assert_float_eq(config.ambient_tint_strength, 0.0, 0.001, "default strength = no shift")


# ─── per-stage color temperature (Art Bible §4.4) ──────────────────────────

func test_stage_one_background_is_cool_blue_grey() -> void:
	# Arrange / Act
	var config := StageOneConfigScript.build()
	# Assert: 荒山 authored as a cool blue-grey shift (blue channel dominant).
	assert_float_eq(config.ambient_tint.r, 0.16, 0.001, "stage1 tint r")
	assert_float_eq(config.ambient_tint.g, 0.19, 0.001, "stage1 tint g")
	assert_float_eq(config.ambient_tint.b, 0.28, 0.001, "stage1 tint b")
	assert_float_eq(config.ambient_tint_strength, 0.14, 0.001, "stage1 strength")
	assert_true(config.ambient_tint.b > config.ambient_tint.r, "stage1 is cool (blue > red)")


func test_stage_two_background_is_warm_ash_yellow() -> void:
	# Arrange / Act
	var config := StageTwoConfigScript.build()
	# Assert: 幽都 authored as a warm ash-yellow shift (red/green over blue).
	assert_float_eq(config.ambient_tint.r, 0.30, 0.001, "stage2 tint r")
	assert_float_eq(config.ambient_tint.g, 0.25, 0.001, "stage2 tint g")
	assert_float_eq(config.ambient_tint.b, 0.16, 0.001, "stage2 tint b")
	assert_float_eq(config.ambient_tint_strength, 0.13, 0.001, "stage2 strength")
	assert_true(config.ambient_tint.r > config.ambient_tint.b, "stage2 is warm (red > blue)")


func test_interlude_background_is_warm_paper_not_gold() -> void:
	# Arrange / Act
	var config := InterludeConfigScript.build()
	var resolved := BackgroundScript.resolve_base_color(
		config.background_color, config.ambient_tint, config.ambient_tint_strength)
	# Assert: warm toward 旧纸黄 but the RESOLVED base stays ink-dark (never gold).
	assert_float_eq(config.ambient_tint.r, 0.34, 0.001, "interlude tint r")
	assert_float_eq(config.ambient_tint_strength, 0.16, 0.001, "interlude strength")
	assert_true(resolved.r >= resolved.b, "interlude is warm (red >= blue)")
	assert_true(_max_channel(resolved) < INK_DOMINANT_MAX_CHANNEL,
		"interlude resolved base stays ink-dark (not gold): max channel %f" % _max_channel(resolved))


# ─── Background.resolve_base_color blend + clamp ────────────────────────────

func test_background_resolve_blends_toward_tint() -> void:
	# Arrange / Act: pure black lerped 25% toward white = 0.25 grey.
	var resolved := BackgroundScript.resolve_base_color(Color.BLACK, Color.WHITE, 0.25)
	# Assert
	assert_float_eq(resolved.r, 0.25, 0.001, "lerp 25% toward white")
	assert_float_eq(resolved.g, 0.25, 0.001, "lerp 25% toward white")
	assert_float_eq(resolved.b, 0.25, 0.001, "lerp 25% toward white")


func test_background_resolve_clamps_strength_to_max() -> void:
	# Arrange / Act: strength 1.0 must clamp to MAX_TINT_STRENGTH so 黛黑 can't be erased.
	var resolved := BackgroundScript.resolve_base_color(Color.BLACK, Color.WHITE, 1.0)
	# Assert
	assert_float_eq(resolved.r, BackgroundScript.MAX_TINT_STRENGTH, 0.001,
		"strength clamped to MAX_TINT_STRENGTH")


# ─── §4.6 rule 2: every stage stays ink-dominant ───────────────────────────

func test_all_stages_resolved_base_stays_ink_dominant() -> void:
	# Arrange
	var configs := [
		StageOneConfigScript.build(),
		StageTwoConfigScript.build(),
		InterludeConfigScript.build(),
	]
	# Act / Assert: no authored stage may push the resolved base out of ink-dark range.
	for config in configs:
		var resolved := BackgroundScript.resolve_base_color(
			config.background_color, config.ambient_tint, config.ambient_tint_strength)
		assert_true(_max_channel(resolved) < INK_DOMINANT_MAX_CHANNEL,
			"%s resolved base ink-dominant: max channel %f" % [config.stage_id, _max_channel(resolved)])
