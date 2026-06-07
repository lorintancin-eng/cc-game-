## Unit tests for ComboBanner.format_text — the testable core of the procedural
## combo-activation banner (ASSET-012). The fade tween is a runtime-only flourish and
## is NOT asserted here (it needs the node in a tree + a rendered frame); we call the
## pure mapping on a bare instance (no _ready, so no Label/Tween are built).
extends GutTest


func _make_banner() -> ComboBanner:
	var banner := ComboBanner.new()
	autofree(banner)
	return banner


func test_combo_banner_format_text_frost_shows_relationship_and_effect() -> void:
	# Arrange
	var banner := _make_banner()

	# Act — 金生水 is the 寒露凝锋 combo
	var text := banner.format_text("金生水")

	# Assert — banner reads "相生 · {relationship} · {effect}"
	assert_eq(text, "相生 · 金生水 · 寒露凝锋",
			"frost combo banner must show both the relationship and the effect name")


func test_combo_banner_format_text_covers_all_five_generating_combos() -> void:
	# Arrange
	var banner := _make_banner()
	var expected := {
		"木生火": "相生 · 木生火 · 燎原",
		"火生土": "相生 · 火生土 · 熔岩甲",
		"土生金": "相生 · 土生金 · 矿脉精粹",
		"金生水": "相生 · 金生水 · 寒露凝锋",
		"水生木": "相生 · 水生木 · 春生回元",
	}

	# Act / Assert — every 相生 relationship maps to its effect name
	for combo_id in expected.keys():
		assert_eq(banner.format_text(combo_id), String(expected[combo_id]),
				"combo %s must map to its effect name" % combo_id)


func test_combo_banner_format_text_unknown_id_falls_back_to_relationship_only() -> void:
	# Arrange
	var banner := _make_banner()

	# Act — an id that is not a known 相生 relationship
	var text := banner.format_text("金克木")

	# Assert — defensive fallback shows the id without an effect suffix
	assert_eq(text, "相生 · 金克木",
			"an unknown combo id must fall back to the relationship-only label")
