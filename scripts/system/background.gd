class_name Background
extends CanvasLayer

## The world's ink-dark base layer (Art Bible §4.1 / §4.4 / §6.2).
##
## A screen-space CanvasLayer (layer = -100) holding a single full-rect Base
## ColorRect. It renders BEHIND the gameplay World and always covers the viewport
## at any resolution, so 黛黑 is guaranteed to be the frame's dominant color
## (§4.6 rule 2: 黛黑 ≥ 55%). The StageDirector calls [method apply_stage_visuals]
## per stage to shift the base SUBTLY toward that stage's color temperature:
## Stage 1 荒山 cool blue-grey, Stage 2 幽都 warm ash-yellow, interlude warm 旧纸黄.
##
## This is the L0 base layer only. The atmospheric depth layers (L1-L3 parallax,
## §6.2) are a later art pass — this establishes the "world is ink-dark" foundation
## that every other visual reads against.

## 黛黑 #18161C — the canonical world base (Art Bible §4.1). Fallback when a stage
## supplies no background_color.
const INK_BLACK: Color = Color(0.094, 0.086, 0.110)

## Upper bound on the temperature shift, so the base can never stop reading as
## 黛黑 (§4.6 rule 2). Stages author strengths well below this (~0.12-0.16).
const MAX_TINT_STRENGTH: float = 0.4

@onready var _base: ColorRect = $Base


func _ready() -> void:
	if _base == null:
		push_error("Background scene is missing its Base ColorRect child.")


## Sets the world base to [param base_color] shifted toward [param ambient_tint]
## by [param tint_strength] (Art Bible §4.4). Strength is clamped so 黛黑 stays
## dominant. Safe to call before/after _ready and repeatedly (per stage transition).
func apply_stage_visuals(base_color: Color, ambient_tint: Color, tint_strength: float) -> void:
	if _base == null:
		push_warning("Background.apply_stage_visuals called before Base ColorRect resolved.")
		return
	_base.color = resolve_base_color(base_color, ambient_tint, tint_strength)


## Pure blend used by [method apply_stage_visuals]. Static so it is unit-testable
## without instancing the CanvasLayer. Clamps [param tint_strength] to
## [constant MAX_TINT_STRENGTH] to keep 黛黑 dominant (§4.6 rule 2).
static func resolve_base_color(base_color: Color, ambient_tint: Color, tint_strength: float) -> Color:
	return base_color.lerp(ambient_tint, clampf(tint_strength, 0.0, MAX_TINT_STRENGTH))
