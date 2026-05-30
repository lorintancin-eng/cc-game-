class_name TradePanel
extends CanvasLayer

## Ghost Market trade panel (鬼市交易). Mirrors LevelUpPanel's pause-time UI pattern
## (CanvasLayer + PROCESS_MODE_WHEN_PAUSED + focus grab) but is a DUMB presenter:
## it shows 3 pre-built offers (+ Leave) and a burning-fuse timer, and emits the
## player's choice. The caller (StageDirector) builds the offers from TradeFormulas
## + player state and applies the chosen buff — the panel owns no game logic.
##
## Offer dict keys: title, description, cost_label, tide_label, disabled (bool).

signal offer_chosen(index: int)
signal declined

const FUSE_SECONDS: float = 5.0

var _active: bool = false
var _fuse_remaining: float = 0.0
var _offers: Array = []
var _pending_confirm_index: int = -1  # destructive (Blood Pact) offer armed for confirm

@onready var _offer_buttons: Array[Button] = [
	$Overlay/Center/Panel/Margin/Content/Options/OfferButton1 as Button,
	$Overlay/Center/Panel/Margin/Content/Options/OfferButton2 as Button,
	$Overlay/Center/Panel/Margin/Content/Options/OfferButton3 as Button,
]
@onready var _leave_button: Button = $Overlay/Center/Panel/Margin/Content/Options/LeaveButton
@onready var _fuse_label: Label = $Overlay/Center/Panel/Margin/Content/FuseLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED as ProcessMode
	visible = false
	for i in range(_offer_buttons.size()):
		_offer_buttons[i].pressed.connect(_on_offer_pressed.bind(i))
	_leave_button.pressed.connect(_on_leave_pressed)


func _process(delta: float) -> void:
	if not _active:
		return
	# The fuse keeps running while the tree is paused — restores time pressure.
	_fuse_remaining = maxf(_fuse_remaining - delta, 0.0)
	_fuse_label.text = "引线 %.1fs" % _fuse_remaining
	if _fuse_remaining <= 0.0:
		_decline()


## Shows the panel with [param offers] (Array[Dictionary]). Disabled offers are
## greyed but visible (the gamble is always informed — Pillar 1).
func show_offers(offers: Array) -> void:
	_offers = offers
	_pending_confirm_index = -1
	for i in range(_offer_buttons.size()):
		var button := _offer_buttons[i]
		if i >= offers.size():
			button.visible = false
			button.disabled = true
			continue
		var o: Dictionary = offers[i]
		button.text = "%s — %s\n代价: %s\n潮汐: %s" % [
			String(o.get("title", "")),
			String(o.get("description", "")),
			String(o.get("cost_label", "")),
			String(o.get("tide_label", "")),
		]
		button.visible = true
		button.disabled = bool(o.get("disabled", false))

	_fuse_remaining = FUSE_SECONDS
	_fuse_label.text = "引线 %.1fs" % _fuse_remaining
	_active = true
	visible = true
	_grab_first_enabled()


func hide_panel() -> void:
	_active = false
	visible = false


func _grab_first_enabled() -> void:
	for b in _offer_buttons:
		if b.visible and not b.disabled:
			b.grab_focus()
			return
	_leave_button.grab_focus()  # all offers locked → only Leave is selectable


func _on_offer_pressed(index: int) -> void:
	if not _active or index < 0 or index >= _offers.size():
		return
	# Destructive trades (Blood Pact — permanent max-HP cost) require a confirm:
	# the first press arms it, a second press commits. Other trades commit at once.
	var is_destructive := String(_offers[index].get("kind", "")) == "blood_pact"
	if is_destructive and _pending_confirm_index != index:
		_pending_confirm_index = index
		_offer_buttons[index].text = "⚠ 再按一次以确认 · 以血换力"
		return
	_active = false
	offer_chosen.emit(index)


func _on_leave_pressed() -> void:
	_decline()


func _decline() -> void:
	if not _active:
		return
	_active = false
	declined.emit()
