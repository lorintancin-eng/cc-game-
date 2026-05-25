class_name LevelUpPanel
extends CanvasLayer

signal upgrade_selected(upgrade_id: StringName)

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
		button.text = "%s\n%s" % [title, description]
		button.visible = true
		button.disabled = false
		_option_ids.append(upgrade_id)

	visible = true
	if not _option_buttons.is_empty():
		_option_buttons[0].grab_focus()


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
