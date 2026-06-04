class_name ElementMatchup
extends RefCounted

## Stateless 相克 (overcoming-cycle) damage modifier lookup.
##
## Returns one of {0.8, 1.0, 1.3} based on the Five Phases overcoming cycle
## (金克木, 木克土, 土克水, 水克火, 火克金). This is NOT the 相生 (generating)
## combo system — that is handled by ComboManager (Stories 004, 006-010).
##
## Usage:
##   var mod: float = ElementMatchup.modifier("metal", "wood")  # → 1.3
##   var mod: float = ElementMatchup.modifier("wood", "metal")  # → 0.8
##   var mod: float = ElementMatchup.modifier("metal", "fire")  # → 0.8
##
## Reference: design/gdd/elements-five-phases.md Formula 1, TR-elem-001,
##            ADR-0006 §Decision (ElementMatchup).

## Damage bonus when the source element overcomes the target element (相克).
## Registry key: favorable_element_modifier
const FAVORABLE_MOD: float = 1.3

## Damage penalty when the source element is overcome by the target element.
## Registry key: unfavorable_element_modifier
const UNFAVORABLE_MOD: float = 0.8

## The closed set of valid element strings.
const _VALID_ELEMENTS: Array[String] = [
	"metal", "wood", "water", "fire", "earth", "neutral",
]

## The five favorable (overcoming) pairs encoded as "src>tgt" strings.
## Built once at class load time — zero per-call allocation in modifier().
## Cycle: metal→wood, wood→earth, earth→water, water→fire, fire→metal (金木土水火).
const _FAVORABLE_PAIRS: Dictionary = {
	"metal>wood": true,
	"wood>earth": true,
	"earth>water": true,
	"water>fire": true,
	"fire>metal": true,
}


## Returns the 相克 element modifier for a source element hitting a target element.
##
## Logic (Five Phases Formula 1):
##   1. If either element is "neutral" → 1.0 (no elemental interaction).
##   2. If src overcomes tgt (favorable pair) → FAVORABLE_MOD (1.3).
##   3. If tgt overcomes src (unfavorable pair) → UNFAVORABLE_MOD (0.8).
##   4. Same element or unrelated pair → 1.0.
## Invalid element strings trigger push_error and are treated as neutral (1.0).
##
## Per-hit hot path: lookup is a Dictionary.has() call — O(1), no allocation.
##
## [param src] The element string of the damage source (weapon/character).
## [param tgt] The element string of the damage target (enemy).
## [returns]   One of {0.8, 1.0, 1.3}.
static func modifier(src: String, tgt: String) -> float:
	# Validate both elements against the closed set.
	if src not in _VALID_ELEMENTS:
		push_error("ElementMatchup.modifier: unknown src element '" + src + "'. Valid elements: " + str(_VALID_ELEMENTS) + ". Treating as neutral.")
		return 1.0
	if tgt not in _VALID_ELEMENTS:
		push_error("ElementMatchup.modifier: unknown tgt element '" + tgt + "'. Valid elements: " + str(_VALID_ELEMENTS) + ". Treating as neutral.")
		return 1.0

	# Neutral short-circuit — no elemental interaction on either side.
	if src == "neutral" or tgt == "neutral":
		return 1.0

	# Check favorable direction (src overcomes tgt).
	var key: String = src + ">" + tgt
	if _FAVORABLE_PAIRS.has(key):
		return FAVORABLE_MOD

	# Check unfavorable direction (tgt overcomes src → src is at a disadvantage).
	var reverse_key: String = tgt + ">" + src
	if _FAVORABLE_PAIRS.has(reverse_key):
		return UNFAVORABLE_MOD

	# Same element or unrelated pair.
	return 1.0
