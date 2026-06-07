class_name ComboBanner
extends Control

## Procedural combo-activation banner (Five Phases 相生 feedback, ASSET-012).
##
## When a 相生 pair first activates, the HUD calls announce(combo_id) and this flashes
## a centred gold line — e.g. "相生 · 金生水 · 寒露凝锋" — with a fade-in / hold / fade-out
## tween. Built entirely in code (the game has no sprite/PNG pipeline): a Label child +
## a Tween, no scene file. The mapping (combo_id → effect name) is the testable core;
## the tween is a runtime-only flourish.
##
## process_mode is ALWAYS so the banner still animates while the LevelUp panel pauses the
## tree (a pick that completes a pair can fire combo_activated during that pause).

## ComboManager combo_id (the 相生 relationship, e.g. "金生水") → its effect name.
const _COMBO_EFFECT_NAMES: Dictionary = {
	"木生火": "燎原",
	"火生土": "熔岩甲",
	"土生金": "矿脉精粹",
	"金生水": "寒露凝锋",
	"水生木": "春生回元",
}

const _FADE_IN: float = 0.25
const _HOLD: float = 1.1
const _FADE_OUT: float = 0.6
const _BANNER_TINT: Color = Color(1.0, 0.902, 0.627)  # warm gold (matches LevelUp 相生 tint)

var _label: Label
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_top = 96.0
	offset_bottom = 160.0

	_label = Label.new()
	_label.name = "BannerLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 28)
	_label.modulate = _BANNER_TINT
	add_child(_label)
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)

	modulate.a = 0.0  # hidden until the first announce()


## Builds the banner line for a combo: "相生 · {relationship} · {effect}", or
## "相生 · {id}" if the id is not a known 相生 relationship (defensive fallback).
## Pure — no node access — so it is unit-testable on a bare instance.
func format_text(combo_id: String) -> String:
	var effect := String(_COMBO_EFFECT_NAMES.get(combo_id, ""))
	if effect.is_empty():
		return "相生 · %s" % combo_id
	return "相生 · %s · %s" % [combo_id, effect]


## Flash the banner for a newly-activated combo. Re-announcing restarts the tween so
## back-to-back activations each get their own flash. No-op until _ready built the label.
func announce(combo_id: String) -> void:
	if _label == null:
		return
	_label.text = format_text(combo_id)

	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, _FADE_IN)
	_tween.tween_interval(_HOLD)
	_tween.tween_property(self, "modulate:a", 0.0, _FADE_OUT)
