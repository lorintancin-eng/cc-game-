class_name WeaponBase
extends Node2D

const MIN_COOLDOWN: float = 0.05
const MIN_ATTACK_RANGE: float = 1.0
const MIN_PROJECTILE_LIFETIME: float = 0.05

@export var damage: float = 8.0
@export var cooldown: float = 0.9
@export var projectile_speed: float = 360.0
@export var attack_range: float = 280.0
@export var projectile_lifetime: float = 1.2
## Five Phases 相克 element (Story 005 / ADR-0006). Immutable weapon identity
## (GDD Core Rule 2) — set per-weapon in the scene (Player.tscn). "neutral" =
## no elemental interaction. Drives ElementMatchup.modifier(element, target).
@export var element: String = "neutral"

var _cooldown_remaining: float = 0.0


func _process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if _cooldown_remaining > 0.0:
		return

	_try_attack()
	_cooldown_remaining = _get_cooldown()


func _try_attack() -> bool:
	return false


func _get_damage() -> float:
	return maxf(damage, 0.0)


func _get_cooldown() -> float:
	return maxf(cooldown, MIN_COOLDOWN)


func _get_projectile_speed() -> float:
	return maxf(projectile_speed, 0.0)


func _get_attack_range() -> float:
	return maxf(attack_range, MIN_ATTACK_RANGE)


func _get_projectile_lifetime() -> float:
	return maxf(projectile_lifetime, MIN_PROJECTILE_LIFETIME)


## Safely reads the Five Phases element of [param node], returning "neutral" when
## the node has no `element` property (e.g. a non-enemy body). Used by weapons and
## projectiles to compute the 相克 matchup multiplier (Story 005 / ADR-0006).
static func element_of(node: Node) -> String:
	var e: Variant = node.get("element")
	return e if e is String else "neutral"


## Returns the ComboManager of the Player that owns this weapon (null if none).
## Weapons are children of the Player, so the owner is get_parent(). Direct-fire
## weapons call this at their hit site; projectiles instead carry a `combo_manager`
## reference passed at spawn (they are detached from the player).
func owner_combo_manager() -> ComboManager:
	var p := get_parent()
	if p is Player:
		return (p as Player).get_combo_manager()
	return null


## Applies the on-hit 相生 combo effects to a single [param target] and returns the
## final damage (Stories 008 + 009). 寒露凝锋 (金生水) applies the refresh-only frost
## slow; 矿脉精粹 (土生金) multiplies damage by the per-hit seeded crit roll (1.0/1.5).
## Centralised here so all 6 修行者 weapon hit sites (direct + projectile) share one
## path. A null [param cm] (no combo system, e.g. another character) is a no-op pass.
static func apply_combo_effects(cm: ComboManager, target: Node, base_damage: float) -> float:
	if cm == null:
		return base_damage
	# 寒露凝锋 frost slow — apply on hit while 金生水 active (target owns its slow state).
	if cm.is_combo_active(ComboManager.COMBO_FROST) and target.has_method("apply_frost_slow"):
		target.apply_frost_slow(ComboManager.FROST_SLOW_FACTOR, cm.get_frost_duration())
	# 矿脉精粹 crit — multiply by the per-hit crit roll while 土生金 active.
	return base_damage * cm.roll_ore_crit()
