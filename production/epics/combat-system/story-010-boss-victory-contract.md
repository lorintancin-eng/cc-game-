# Story 010: Boss Victory Contract

> **Epic**: Combat System
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-25.1
> **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/combat-system.md` + `design/gdd/boss-system.md`
**Requirement**: `TR-enemy-002` (combat feedback for Boss death victory state)

**ADR Governing Implementation**: ADR-0001: Godot 4.x + GDScript
**ADR Decision Summary**: Boss extends Enemy; `died` signal payload carries `is_boss = true` flag for Run State victory branch.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Use `is_in_group("bosses")` to set `payload.is_boss = true`; do not introduce a separate Boss class hierarchy per Control Manifest Feature Layer "Boss class extends Enemy (not a separate class hierarchy)".

**Control Manifest Rules (Feature Layer)**:
- Required: Boss class extends Enemy (not a separate hierarchy)
- Required: Run-end signal `died()` with `payload.is_boss` enables victory branch

---

## Acceptance Criteria

*From GDD `design/gdd/combat-system.md` + `design/gdd/boss-system.md`:*

- [ ] **AC-18**: Famine Beast Boss (`max_hp = 360, xp_drop_value = 0, is_boss = true`), total weapon damage of 360 applied → Boss emits `died(payload)` exactly once AND `payload.is_boss == true` AND Experience system spawns NO XP orb AND Run State receives victory transition trigger

---

## Implementation Notes

*Per Combat GDD AC-18 + Death Lifecycle (Story 003) + Boss System GDD canonical archetype:*

1. Boss extends Enemy via `class_name FamineBeastBoss extends Enemy` (already exists per project audit; verify Boss state machine — see Boss System GDD).
2. On `_ready()`, Boss adds itself to `bosses` group AND forces `xp_drop_value = 0`:
   ```gdscript
   func _ready() -> void:
       super._ready()
       add_to_group("bosses")
       xp_drop_value = 0.0  # Boss never drops XP — victory IS the reward
   ```
3. `died` payload (per Combat GDD signal contract):
   ```gdscript
   func _die() -> void:
       # ... Story 003 base implementation
       died.emit({
           "enemy": self,
           "position": global_position,
           "xp_drop_value": xp_drop_value,  # 0 for Boss
           "archetype_name": archetype.display_name,
           "is_boss": is_in_group("bosses")  # true for Boss
       })
   ```
4. Experience system consumer-side check: `if payload.xp_drop_value > 0: spawn_orb(payload.position, payload.xp_drop_value)` — automatic NO-OP for Boss (zero drop_value).
5. Run State consumer:
   ```gdscript
   # In Stage Director:
   func _on_boss_died(payload: Dictionary) -> void:
       if not payload.is_boss:
           return  # safety guard
       _is_stage_cleared = true
       stage_cleared.emit(elapsed_time)
       enemy_spawner.set_spawning_enabled(false)
   ```
6. Per Boss System GDD r1 canonical values: `max_hp = 360` from `entities.yaml` famine_beast archetype (NOT Stage Director's dead-code 260 — see C-B2 resolution).

---

## Out of Scope

- Boss attack abilities (Enrage, Charge, Burst, Summon — Boss System epic)
- Stage Director scene state (Run State epic)
- XP orb spawn mechanism (Experience epic — this story only verifies the absence of spawn)

---

## QA Test Cases

**AC-18**: Boss death victory chain
- **Given**: Famine Beast Boss instance in scene with `current_hp = 360, max_hp = 360, xp_drop_value = 0`, added to `bosses` group; Stage Director connected to Boss `died` signal
- **When**: Total damage of 360 applied (single or summed) via `take_damage()`
- **Then**: In order:
  1. `damage_taken(0, 360, last_damage)` emits ONCE
  2. `_is_dead = true` flag set
  3. `died(payload)` emits ONCE with `payload.is_boss == true`, `payload.xp_drop_value == 0`, `payload.archetype_name == "Famine Beast"`
  4. Experience system handler sees `payload.xp_drop_value <= 0` → does NOT spawn an XP orb
  5. Stage Director's `_on_boss_died` fires → `_is_stage_cleared = true` AND `stage_cleared(elapsed_time)` emits AND enemy spawner is disabled
- **Edge cases**: Overkill (damage = 999 against 360 HP) → still single `died` emit; player dies on same frame as Boss → `stage_failed` and `stage_cleared` race (Stage Director GDD line 179 flags this — `stage_failed` wins by both terminal-flag guards)

**Cross-doc consistency check** (verify against Boss System GDD AC-02 + AC-03):
- Boss System GDD AC-02 mirrors this story's expectations on `is_boss = true` and no XP orb
- Boss System GDD AC-03 covers Stage Director's `_on_boss_died` (Run State side) — this story validates the Combat-side contract that emits the signal

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combat/boss_victory_test.gd` — must exist and pass; OR documented playtest (playtest-2026-05-27 Run 3 covers this)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (HP application), Story 003 (death lifecycle — Boss death is special case of generic death)
- Unlocks: Boss System epic's full Enrage / Charge / Burst / Summon stories (those depend on the death contract being firm)
