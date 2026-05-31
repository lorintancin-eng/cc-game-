class_name IdleBob
extends Node

## Subtle cosmetic vertical bob for a character's visual silhouette (Art Bible §5.3).
##
## A gentle ±1-2px sine bob over ~0.8-1.2s helps the player keep track of their own
## character among a crowd of static enemies (§5.3: "运动本身是注意力吸附器"). It is
## VISUAL ONLY — it offsets the target Node2D's LOCAL position.y around its initial
## value and never touches the CharacterBody2D root, its CollisionShape, or movement,
## so gameplay is completely unaffected. Reusable across all player characters.

## The Node2D to bob — typically the character's Body silhouette (its signature-mark
## children bob with it).
@export var target_path: NodePath
## Bob height in pixels (§5.3: 1-2px — subtle, reads as presence not motion noise).
@export var amplitude: float = 1.5
## Full bob cycle length in seconds (§5.3: 0.8-1.2s).
@export var period: float = 1.0

var _target: Node2D
var _base_y: float = 0.0
var _elapsed: float = 0.0


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node2D
	if _target == null:
		push_warning("IdleBob has no valid target Node2D at %s." % [target_path])
		return
	_base_y = _target.position.y


func _process(delta: float) -> void:
	if _target == null:
		return
	_elapsed += delta
	_target.position.y = _base_y + bob_offset(_elapsed, amplitude, period)


## Pure bob displacement (px) at [param elapsed] seconds. Static + side-effect-free
## so it is unit-testable without a scene. [param period] is floored to avoid a
## divide-by-zero; the curve is a full sine cycle per period.
static func bob_offset(elapsed: float, amplitude: float, period: float) -> float:
	return sin(elapsed / maxf(period, 0.01) * TAU) * amplitude
