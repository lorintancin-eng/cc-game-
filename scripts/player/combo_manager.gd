class_name ComboManager
extends Node

## Per-Player combo manager — Five Phases Synergy System (相生 generating cycle).
##
## Responsibilities (ADR-0006 §Decision 3):
##   1. Listens to Player.element_inventory_changed (connected AFTER run_initialized
##      fires — ADR-0006 R-2) and recomputes the active-combo set on each change.
##   2. Emits combo_activated(combo_id) once per newly activated combo.
##   3. Connects ONCE to CombatEvents.enemy_killed to handle 燎原 chain burst.
##   4. Exposes read accessors consumed by Player (shield/regen), Weapons (pierce/crit),
##      and the weapon-hit path (frost slow).
##
## This node holds NO gameplay logic for the 5 effects themselves — it only
## tracks activation state and provides parameters.  Effect routing per ADR-0006:
##   燎原  → handled here via CombatEvents.enemy_killed (_on_enemy_killed)
##   熔岩甲 → Player reads get_shield_params() in its damage path / _process
##   春生  → Player reads get_regen_params() for regen tick
##   矿脉精粹 → Weapons read get_pierce_bonus() + get_ore_crit_chance()
##   寒露凝锋 → weapon-hit path reads is_combo_active(COMBO_FROST) + frost duration
##
## Instantiation: add as child of Player; call connect_to_player(player) from
## Player._ready() AFTER seeding element_inventory and emitting run_initialized.
##
## Reference: design/gdd/elements-five-phases.md (revision-4), ADR-0006.

# ─── Constants ────────────────────────────────────────────────────────────────

## Combo IDs — stable string keys used for signals and external lookups.
const COMBO_WILDFIRE: String    = "木生火"   # Wood + Fire  → 燎原
const COMBO_MOLTEN: String      = "火生土"   # Fire + Earth → 熔岩甲
const COMBO_ORE: String         = "土生金"   # Earth + Metal → 矿脉精粹
const COMBO_FROST: String       = "金生水"   # Metal + Water → 寒露凝锋
const COMBO_VERNAL: String      = "水生木"   # Water + Wood → 春生回元

## Generating pairs: each entry is [elem_A, elem_B, combo_id].
## Formula 2: active when inv[A] >= 1 AND inv[B] >= 1.
const _GENERATING_PAIRS: Array = [
	["wood",  "fire",  COMBO_WILDFIRE],
	["fire",  "earth", COMBO_MOLTEN],
	["earth", "metal", COMBO_ORE],
	["metal", "water", COMBO_FROST],
	["water", "wood",  COMBO_VERNAL],
]

## Formula 3 cap: maximum scaling steps beyond activation threshold (total=2).
const MAX_SCALE_STEPS: int = 5

# ── 燎原 (Wildfire Spread) tuning knobs ──────────────────────────────────────
## Base burst radius in pixels at activation (no scaling steps).
const WILDFIRE_BASE_BURST_RADIUS: float = 40.0
## Radius added per Formula 3 scale step.
const WILDFIRE_RADIUS_PER_STEP: float = 8.0
## Burst damage as a fraction of the killing blow damage (Formula 4).
const WILDFIRE_DAMAGE_RATIO: float = 0.5
## Maximum chain links per trigger (Formula 4 / OQ-7 DPS ceiling guard).
const WILDFIRE_MAX_CHAINS: int = 3

# ── 熔岩甲 (Molten Aegis) tuning knobs ──────────────────────────────────────
## Base shield HP at activation.
const MOLTEN_BASE_SHIELD_HP: float = 15.0
## Shield HP added per Formula 3 scale step.
const MOLTEN_SHIELD_PER_STEP: float = 5.0
## Base regen per 5-second tick.
const MOLTEN_BASE_REGEN: float = 3.0
## Regen per 5s added per Formula 3 scale step.
const MOLTEN_REGEN_PER_STEP: float = 1.0
## Seconds after last damage before regen starts.
const MOLTEN_GRACE_PERIOD: float = 2.0

# ── 矿脉精粹 (Ore Refinement) tuning knobs ──────────────────────────────────
## Extra pierce count on projectile weapons when combo is active (always flat +1).
const ORE_PIERCE_BONUS: int = 1
## Crit chance added per Formula 3 scale step (0.02 = 2%).
const ORE_CRIT_CHANCE_PER_STEP: float = 0.02
## Damage multiplier on a 矿脉精粹 critical strike (Formula 8). ×1.5 on success.
const ORE_CRIT_MULTIPLIER: float = 1.5

# ── 寒露凝锋 (Frost Condensation) tuning knobs ──────────────────────────────
## Base slow duration in seconds.
const FROST_BASE_DURATION: float = 1.5
## Slow duration added per Formula 3 scale step.
const FROST_DURATION_PER_STEP: float = 0.3
## Move-speed multiplier applied to slowed enemies (constant, does not scale).
const FROST_SLOW_FACTOR: float = 0.7

# ── 春生回元 (Vernal Restoration) tuning knobs ──────────────────────────────
## Base HP regenerated per 4-second tick.
const VERNAL_BASE_HP_REGEN: float = 2.0
## HP regen per 4s added per Formula 3 scale step.
const VERNAL_HP_REGEN_PER_STEP: float = 1.0
## Base XP orb pickup value bonus (0.15 = +15%, multiplicative).
const VERNAL_BASE_XP_BONUS: float = 0.15
## XP bonus added per Formula 3 scale step.
const VERNAL_XP_BONUS_PER_STEP: float = 0.05

# ─── Signals ──────────────────────────────────────────────────────────────────

## Emitted once per combo the first time it becomes active.
## combo_id is one of the COMBO_* constants (e.g. "火生土").
signal combo_activated(combo_id: String)

# ─── Private state ────────────────────────────────────────────────────────────

## Set of currently active combo IDs (String).  Populated by _recompute_combos.
## Persists for the rest of the run — combos cannot deactivate.
var _active_combos: Dictionary = {}  # combo_id -> true

## Element inventory snapshot (a copy, not a live alias — see _on_inventory_changed).
## Updated on each element_inventory_changed.
var _inventory: Dictionary = {}

## Seeded RNG — deterministic.  Tests may assign rng.seed before instantiation.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ─── Initialisation ───────────────────────────────────────────────────────────

func _ready() -> void:
	# Connect once to the combat event bus for 燎原 chain burst (ADR-0006 §3).
	# Runtime-safe lookup: get_node_or_null genuinely returns null when the
	# CombatEvents autoload is absent (e.g. an isolated test that adds this node
	# to a bare tree). A bare `CombatEvents != null` cannot — the identifier
	# fails to resolve before the comparison runs.
	var bus := get_node_or_null(^"/root/CombatEvents")
	if bus != null:
		bus.enemy_killed.connect(_on_enemy_killed)


## Called by Player._ready() AFTER element_inventory is seeded and
## run_initialized has been emitted (ADR-0006 R-2).
##
## [param player] The owning Player node.  The connection is made here rather
## than in _ready() to guarantee the inventory is fully populated before the
## first inventory-change event is processed.
func connect_to_player(player: Player) -> void:
	if player == null:
		push_error("ComboManager.connect_to_player: player is null.")
		return
	if player.element_inventory_changed.is_connected(_on_inventory_changed):
		return  # idempotent — safe to call twice
	player.element_inventory_changed.connect(_on_inventory_changed)
	# Seed our inventory snapshot from the player's current state so that a
	# combo pre-activated by Merit Node 11 (run-start seed) is detected now.
	_on_inventory_changed(player.element_inventory)


# ─── Public accessors (read-only; consumed by Player / Weapons / hit path) ────

## Returns true if the combo identified by [param combo_id] is currently active.
func is_combo_active(combo_id: String) -> bool:
	return _active_combos.has(combo_id)


## 矿脉精粹: extra pierce count for projectile weapons when 土生金 is active.
## Returns 0 when the combo is inactive.
func get_pierce_bonus() -> int:
	if not is_combo_active(COMBO_ORE):
		return 0
	return ORE_PIERCE_BONUS


## 矿脉精粹: per-hit crit probability (0.0–0.10) for the 土生金 combo.
## Returns 0.0 when the combo is inactive.
## The caller must use maxf(fire_eyes_modifier, ore_crit_roll) — Formula 8.
func get_ore_crit_chance() -> float:
	if not is_combo_active(COMBO_ORE):
		return 0.0
	# steps is already clamped to [0, MAX_SCALE_STEPS] by _scale_steps, so no
	# re-clamp is needed here (matches the other scaling accessors).
	var steps: int = _scale_steps("earth", "metal")
	return float(steps) * ORE_CRIT_CHANCE_PER_STEP


## 矿脉精粹 per-hit crit roll (土生金): returns ORE_CRIT_MULTIPLIER (1.5) on a seeded-RNG
## success at get_ore_crit_chance(), else 1.0 (also 1.0 when the combo is inactive).
## Uses the ComboManager-owned seeded RNG (ADR-0006 R-6) — NOT global randf() — so the
## crit stream is deterministic and test-injectable. Callers fold this into Formula 8
## via maxf(fire_eyes_modifier, this); for 修行者 weapons (no fire eyes) it IS the crit.
func roll_ore_crit() -> float:
	if not is_combo_active(COMBO_ORE):
		return 1.0
	if _rng.randf() < get_ore_crit_chance():
		return ORE_CRIT_MULTIPLIER
	return 1.0


## 熔岩甲: shield parameters for Player's damage path.
## Returns a Dictionary with keys {max_hp, regen, grace} when 火生土 is active,
## or an empty Dictionary when inactive (caller must check is_combo_active first
## or treat an empty dict as inactive).
func get_shield_params() -> Dictionary:
	if not is_combo_active(COMBO_MOLTEN):
		return {}
	var steps: int = _scale_steps("fire", "earth")
	return {
		"max_hp": MOLTEN_BASE_SHIELD_HP + float(steps) * MOLTEN_SHIELD_PER_STEP,
		"regen": MOLTEN_BASE_REGEN + float(steps) * MOLTEN_REGEN_PER_STEP,
		"grace": MOLTEN_GRACE_PERIOD,
	}


## 春生回元: regen parameters for Player's tick.
## Returns a Dictionary with keys {hp_per_4s, xp_bonus} when 水生木 is active,
## or an empty Dictionary when inactive.
func get_regen_params() -> Dictionary:
	if not is_combo_active(COMBO_VERNAL):
		return {}
	var steps: int = _scale_steps("water", "wood")
	return {
		"hp_per_4s": VERNAL_BASE_HP_REGEN + float(steps) * VERNAL_HP_REGEN_PER_STEP,
		"xp_bonus": VERNAL_BASE_XP_BONUS + float(steps) * VERNAL_XP_BONUS_PER_STEP,
	}


## 寒露凝锋: slow duration in seconds for the 金生水 combo.
## Returns 0.0 when inactive.  FROST_SLOW_FACTOR is a public constant.
func get_frost_duration() -> float:
	if not is_combo_active(COMBO_FROST):
		return 0.0
	var steps: int = _scale_steps("metal", "water")
	return FROST_BASE_DURATION + float(steps) * FROST_DURATION_PER_STEP


## 燎原: burst radius in pixels for the 木生火 combo.
## Returns 0.0 when inactive.
func get_wildfire_burst_radius() -> float:
	if not is_combo_active(COMBO_WILDFIRE):
		return 0.0
	var steps: int = _scale_steps("wood", "fire")
	return WILDFIRE_BASE_BURST_RADIUS + float(steps) * WILDFIRE_RADIUS_PER_STEP


# ─── Private helpers ──────────────────────────────────────────────────────────

## Formula 3: returns the number of scaling bonus steps for a generating pair.
## steps = min(inv[A] + inv[B] - 2, MAX_SCALE_STEPS)
## Returns 0 at activation threshold (total == 2) and clamps at MAX_SCALE_STEPS.
func _scale_steps(elem_a: String, elem_b: String) -> int:
	var total: int = int(_inventory.get(elem_a, 0)) + int(_inventory.get(elem_b, 0))
	return mini(maxi(total - 2, 0), MAX_SCALE_STEPS)


## Formula 2: returns true when both elements of the pair are >= 1.
func _pair_active(elem_a: String, elem_b: String) -> bool:
	return int(_inventory.get(elem_a, 0)) >= 1 and int(_inventory.get(elem_b, 0)) >= 1


# ─── Signal callbacks ─────────────────────────────────────────────────────────

## Receives Player.element_inventory_changed and recomputes the active-combo set.
## Fires combo_activated for any pair that becomes active for the first time.
## This is the only write path for _active_combos — no per-frame polling.
func _on_inventory_changed(inventory: Dictionary) -> void:
	# Copy, not alias: Player emits and mutates its live element_inventory dict
	# in place. Duplicating (5 int keys, cheap) gives true snapshot semantics so
	# accessors can never observe an unsignalled mutation.
	_inventory = inventory.duplicate()
	for pair in _GENERATING_PAIRS:
		var elem_a: String = pair[0]
		var elem_b: String = pair[1]
		var combo_id: String = pair[2]
		if _active_combos.has(combo_id):
			continue  # already active — combos never deactivate
		if _pair_active(elem_a, elem_b):
			_active_combos[combo_id] = true
			combo_activated.emit(combo_id)


## Handles CombatEvents.enemy_killed for the 燎原 (Wildfire) combo.
##
## If the kill source element is "fire" AND 木生火 is active, this method
## would spawn the chain burst (Formula 4).  In this story the burst spawning
## itself is stubbed — the activation check and parameter computation are wired;
## the actual scene-level burst spawn will be implemented in Story 006 when
## the VFX/explosion scene exists.
##
## The method is functional: it guards correctly and computes burst_radius /
## burst_damage — callers (tests) can verify those values via the accessors.
func _on_enemy_killed(kill_data: EnemyKillData) -> void:
	if kill_data == null:
		return
	if kill_data.source_element != "fire":
		return
	if not is_combo_active(COMBO_WILDFIRE):
		return
	# Story 006 will call _spawn_wildfire_burst(kill_data, 0) here.
	# For now: activation + parameter guards are in place.
	var _burst_radius: float = get_wildfire_burst_radius()
	var _burst_damage: float = kill_data.damage * WILDFIRE_DAMAGE_RATIO
	# Burst spawning deferred to Story 006 (VFX scene dependency).
	# _spawn_wildfire_burst(kill_data.position, _burst_damage, _burst_radius, WILDFIRE_MAX_CHAINS)
