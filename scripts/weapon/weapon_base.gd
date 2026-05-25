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
