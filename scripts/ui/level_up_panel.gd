class_name LevelUpPanel
extends CanvasLayer

signal upgrade_selected(upgrade_id: StringName)

## 五行 element → display glyph for the upgrade-option tag (【火】). Glyph carries the
## element identity in text, so it reads in headless and for colour-blind players;
## a per-element colour fill is a screenshot-gated visual enhancement, not the signal.
const _ELEMENT_GLYPHS: Dictionary = {
	"metal": "金",
	"wood": "木",
	"water": "水",
	"fire": "火",
	"earth": "土",
}

## Warm gold tint applied to an option whose pick would trigger a 相生 combo (相生 hint).
const _RESONANCE_TINT: Color = Color(1.0, 0.902, 0.627)

var _option_ids: Array[StringName] = []

@onready var _option_buttons: Array[Button] = [
	$Overlay/Center/Panel/Margin/Content/Options/OptionButton1 as Button,
	$Overlay/Center/Panel/Margin/Content/Options/OptionButton2 as Button,
	$Overlay/Center/Panel/Margin/Content/Options/OptionButton3 as Button,
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED as ProcessMode
	visible = false
	for i in range(_option_buttons.size()):
		_option_buttons[i].pressed.connect(_on_option_pressed.bind(i))


func show_choices(options: Array[Dictionary]) -> void:
	_option_ids.clear()
	for i in range(_option_buttons.size()):
		var button := _option_buttons[i]
		if i >= options.size():
			button.visible = false
			button.disabled = true
			_option_ids.append(&"")
			continue

		var option := options[i]
		var title := String(option.get("title", "悟道"))
		var description := String(option.get("description", ""))
		var upgrade_id := StringName(option.get("id", ""))
		var element := String(option.get("element", "neutral"))
		var would_activate := bool(option.get("would_activate_combo", false))
		button.text = _compose_option_text(element, title, description, would_activate)
		button.modulate = _RESONANCE_TINT if would_activate else Color.WHITE
		button.visible = true
		button.disabled = false
		_option_ids.append(upgrade_id)

	visible = true
	if not _option_buttons.is_empty():
		_option_buttons[0].grab_focus()


## Builds an option's label: element glyph tag (【火】) + title on the first line, the
## description below, plus a 相生 hint line when picking this option would trigger a
## combo. Text (glyph + hint), not colour, carries the meaning — it reads in headless
## and for colour-blind players; the warm modulate is an enhancement, not the signal.
func _compose_option_text(element: String, title: String, description: String, would_activate: bool) -> String:
	var prefix := ""
	if _ELEMENT_GLYPHS.has(element):
		prefix = "【%s】" % String(_ELEMENT_GLYPHS[element])
	var text := "%s%s\n%s" % [prefix, title, description]
	if would_activate:
		text += "\n✦ 相生 · 触发连携"
	return text


func hide_panel() -> void:
	visible = false


func _on_option_pressed(index: int) -> void:
	if index < 0 or index >= _option_ids.size():
		return
	if String(_option_ids[index]).is_empty():
		return

	for button in _option_buttons:
		button.disabled = true

	upgrade_selected.emit(_option_ids[index])
