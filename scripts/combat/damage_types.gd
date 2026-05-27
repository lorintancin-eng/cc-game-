class_name DamageTypes
extends RefCounted

## Damage type taxonomy and payload contract for MythSurvivor's combat system.
##
## This is a static helper class (RefCounted). Do NOT add it as an autoload or
## attach it to the scene tree — it is a contract/enum holder only.
##
## The signal damage_dealt(payload: Dictionary) is declared on each individual
## weapon/enemy source node (not here). This class only defines the payload shape
## so all emitters and receivers share the same contract. Signal placement per
## Story 001 implementation note 2 and Control Manifest "Forbidden: Singletons".
##
## Reference: design/gdd/combat-system.md §Core Rule 2, TR-wpn-002.

## The four damage application modes (TR-wpn-002).
enum DamageType {
	DIRECT,      ## Single-hit weapon contact (e.g. flying sword, talisman)
	TICK,        ## Periodic damage over time (e.g. Bagua Array aura)
	EXPLOSION,   ## Area-of-effect radius burst (e.g. explosive talisman impact)
	BURN,        ## Ground-based DPS zone, fixed-step accumulator (e.g. thunder strike patch)
}

## Who originated the damage event (Combat GDD Core Rule 2).
enum SourceKind {
	WEAPON,      ## Player weapon — subject to friendly-fire skip per Core Rule 1
	ENEMY,       ## Enemy contact or projectile — may damage player
	ENVIRONMENT, ## World hazard (fire patch, trap) — DOES damage player per Edge Cases
}


## Returns true if this event should be skipped for [param target] due to
## friendly-fire rules.
##
## Friendly-fire skip applies when source_kind == WEAPON and the target is
## in the "player" or "allies" group. Environment damage (ENVIRONMENT) bypasses
## the skip and always damages the player (Combat GDD Edge Cases).
##
## [param source_kind] The SourceKind of the damage event.
## [param target]      The Node being tested for friendly-fire immunity.
static func is_friendly_fire(source_kind: SourceKind, target: Node) -> bool:
	if source_kind != SourceKind.WEAPON:
		return false
	return target.is_in_group(&"player") or target.is_in_group(&"allies")


## Constructs a validated damage payload Dictionary.
##
## All 5 keys are always present: source, target, amount, damage_type,
## source_kind. Negative [param amount] is clamped to 0.0 — no healing
## through this path (AC-19 edge case). Invalid enum values trigger push_error.
##
## [param source]      The Node that is the origin of the damage.
## [param target]      The Node receiving the damage.
## [param amount]      Raw damage quantity (clamped to >= 0.0).
## [param damage_type] A DamageType enum value.
## [param source_kind] A SourceKind enum value.
## [returns] Dictionary with keys: source, target, amount, damage_type, source_kind.
static func make_payload(
	source: Node,
	target: Node,
	amount: float,
	damage_type: DamageType,
	source_kind: SourceKind
) -> Dictionary:
	if damage_type < DamageType.DIRECT or damage_type > DamageType.BURN:
		push_error("DamageTypes.make_payload: invalid damage_type value %d" % damage_type)
	if source_kind < SourceKind.WEAPON or source_kind > SourceKind.ENVIRONMENT:
		push_error("DamageTypes.make_payload: invalid source_kind value %d" % source_kind)
	if amount < 0.0:
		push_warning("DamageTypes.make_payload: negative amount %.3f clamped to 0.0 (no healing-via-damage allowed)" % amount)
	var clamped_amount: float = maxf(amount, 0.0)
	return {
		"source": source,
		"target": target,
		"amount": clamped_amount,
		"damage_type": damage_type,
		"source_kind": source_kind,
	}


## Validates that [param payload] is a well-formed damage payload.
##
## Returns true if all 5 keys are present with valid types and in-range enum
## values. Returns false and calls push_error for any violation (AC-05 edge case).
##
## In Godot 4, [code]is Node[/code] check passes for already-freed nodes
## (dangling references). [code]validate_payload[/code] therefore also runs
## [code]is_instance_valid()[/code] to catch freed-node cases — preventing
## crashes when callers obtain nodes from collision callbacks that may
## already be queued for deletion.
##
## [param payload] Dictionary to validate.
static func validate_payload(payload: Dictionary) -> bool:
	const REQUIRED_KEYS: Array[String] = [
		"source", "target", "amount", "damage_type", "source_kind"
	]
	for key in REQUIRED_KEYS:
		if not payload.has(key):
			push_error("DamageTypes.validate_payload: missing key '%s'" % key)
			return false

	# Source: must be a Node AND not freed. Allow null (some sources are
	# environmental hazards that have no Node origin — e.g. status patches).
	# But if non-null, must be a live Node instance.
	var source_val = payload["source"]
	if source_val != null:
		if not (source_val is Node):
			push_error("DamageTypes.validate_payload: 'source' must be a Node or null")
			return false
		if not is_instance_valid(source_val):
			push_error("DamageTypes.validate_payload: 'source' is a freed Node (dangling reference)")
			return false

	# Target: must be a non-null Node and not freed. Damage with no target is meaningless.
	var target_val = payload["target"]
	if target_val == null:
		push_error("DamageTypes.validate_payload: 'target' must not be null")
		return false
	if not (target_val is Node):
		push_error("DamageTypes.validate_payload: 'target' must be a Node")
		return false
	if not is_instance_valid(target_val):
		push_error("DamageTypes.validate_payload: 'target' is a freed Node (dangling reference)")
		return false

	if not (payload["amount"] is float):
		push_error("DamageTypes.validate_payload: 'amount' must be a float")
		return false
	if not (payload["damage_type"] is int):
		push_error("DamageTypes.validate_payload: 'damage_type' must be an int (DamageType enum)")
		return false
	if not (payload["source_kind"] is int):
		push_error("DamageTypes.validate_payload: 'source_kind' must be an int (SourceKind enum)")
		return false

	var dt: int = payload["damage_type"]
	if dt < DamageType.DIRECT or dt > DamageType.BURN:
		push_error("DamageTypes.validate_payload: damage_type value %d out of range" % dt)
		return false

	var sk: int = payload["source_kind"]
	if sk < SourceKind.WEAPON or sk > SourceKind.ENVIRONMENT:
		push_error("DamageTypes.validate_payload: source_kind value %d out of range" % sk)
		return false

	return true
