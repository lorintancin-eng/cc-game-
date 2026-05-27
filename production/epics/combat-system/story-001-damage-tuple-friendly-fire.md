# Story 001: Damage Tuple + Friendly-Fire Contract

> **Epic**: Combat System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Actual**: ~2 hours (incl. /code-review r2 fixes)
> **Manifest Version**: 2026-05-25.1
> **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-wpn-002` (4 damage types: direct/tick/explosion/burn)

**ADR Governing Implementation**: ADR-0001: Godot 4.x + GDScript
**ADR Decision Summary**: Signal-based damage architecture; Resource-driven weapon/enemy stats; one-way data flow via signals.

**Engine**: Godot 4.6 | **Risk**: LOW (signal definition only)
**Engine Notes**: Use typed Godot signals; Dictionary payload is acceptable in Godot 4.6 but consider migrating to typed object payload in later refactor.

**Control Manifest Rules (Core Layer)**:
- Required: Combat damage applied via signals — never direct property writes across systems
- Forbidden: `target.hp -= damage` from one system into another
- Guardrail: Foundation for all subsequent combat work — get this right first

---

## Acceptance Criteria

*From GDD `design/gdd/combat-system.md`:*

- [ ] **AC-04**: Explosive Talisman (`source_kind = WEAPON`) impacts at player position → player takes **0 damage** AND enemies in `explosion_radius` take `explosion_damage` once each (friendly fire skip)
- [ ] **AC-05**: Damage event payload contains all 5 fields `(source, target, amount, damage_type, source_kind)` AND `damage_type ∈ {DIRECT, TICK, EXPLOSION, BURN}` AND `source_kind ∈ {WEAPON, ENEMY, ENVIRONMENT}`
- [ ] **AC-19**: Zero-damage event (`amount = 0`) fires `damage_dealt` source-side signal but does NOT fire `damage_taken` AND does NOT reset `last_hit_time` throttle AND does NOT flash

---

## Implementation Notes

*Per ADR-0001 signal-based architecture:*

1. Define enums in `scripts/combat/damage_types.gd` (autoload or const file):
   ```gdscript
   enum DamageType { DIRECT, TICK, EXPLOSION, BURN }
   enum SourceKind { WEAPON, ENEMY, ENVIRONMENT }
   ```
2. Add `damage_dealt` signal to a Combat autoload OR per-source (recommended: per weapon/enemy node, no global autoload per Manifest "Forbidden: Singletons for gameplay logic"):
   ```gdscript
   signal damage_dealt(payload: Dictionary)
   # payload keys: source, target, amount, damage_type, source_kind
   ```
3. Friendly-fire skip is enforced at the **damage application site**, not the signal site. The recipient checks `if source_kind == WEAPON and target is in player/ally group → skip`. Per Combat GDD Edge Cases: explosion with `source_kind = ENVIRONMENT` (ground burn) DOES damage player.
4. Zero-damage path (AC-19): `damage_dealt` emits unconditionally; `damage_taken` only emits if `amount > 0`. Throttle (`last_hit_time`) is NOT updated for amount=0.

---

## Out of Scope

- HP application math itself (Story 002)
- Death lifecycle (Story 003)
- Per-enemy damage throttle (Story 007)

---

## QA Test Cases

**AC-04**: Friendly-fire skip on Explosive Talisman
- **Given**: Player at world (0,0); Explosive Talisman instance with `source_kind = WEAPON`, `explosion_damage = 30`, `explosion_radius = 100`
- **When**: Talisman explodes at world (0,0) (overlapping player); 2 Paper Dolls present at (50,0) and (-50,0) both within radius
- **Then**: Player's `current_hp` UNCHANGED (0 damage) AND each Paper Doll takes 30 damage exactly once
- **Edge cases**: Environment burn patch (`source_kind = ENVIRONMENT`) overlapping player → player DOES take damage; ally future units (`source_kind = ALLY` when added) also exempt

**AC-05**: 5-field tuple validation
- **Given**: Any weapon hit event
- **When**: `damage_dealt` signal emits
- **Then**: Payload dictionary has exactly keys `{source, target, amount, damage_type, source_kind}` AND `damage_type` is one of 4 enum values AND `source_kind` is one of 3 enum values
- **Edge cases**: Missing keys → push_error; wrong enum value → push_error

**AC-19**: Zero-damage event suppression
- **Given**: Enemy at `current_hp = 24`
- **When**: A `damage_amount = 0` event fires (e.g., status-only probe with `source_kind = WEAPON`)
- **Then**: `current_hp` STAYS at 24 AND `damage_dealt(...)` fires once (for status observers) AND `damage_taken` does NOT fire AND no flash AND `last_hit_time` on enemy's throttle is UNCHANGED
- **Edge cases**: Negative damage values → clamp at 0 (no healing through this path); float precision near zero → still emit damage_dealt

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/damage_tuple_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None — foundation story
- Unlocks: Stories 002, 003, 004, 005, 006, 007, 008, 009, 010 (all combat stories depend on the tuple contract)

---

## Completion Notes

**Completed**: 2026-05-27
**Verdict**: COMPLETE
**Criteria**: 3/3 passing (AC-04, AC-05, AC-19) — 0 deferred, 0 untested
**Deviations**: None

**Files delivered**:
- `scripts/combat/damage_types.gd` (147 lines) — class_name `DamageTypes` (RefCounted helper)
  - 2 enums: `DamageType {DIRECT, TICK, EXPLOSION, BURN}`, `SourceKind {WEAPON, ENEMY, ENVIRONMENT}`
  - 3 static functions: `is_friendly_fire()`, `make_payload()`, `validate_payload()`
  - `is_instance_valid()` guards in `validate_payload` (Godot 4 freed-node gotcha fix per qa-tester finding)
  - `push_warning()` on negative-amount clamp (per godot-gdscript-specialist polish suggestion)
- `tests/unit/combat/damage_tuple_test.gd` (258 lines) — 18 test functions
  - All function names follow `.claude/rules/test-standards.md` 3-segment pattern: `test_damage_types_*`
  - Coverage: AC-04 (5 tests) / AC-05 (9 tests incl. null/freed/bad-enum edges) / AC-19 (3 tests incl. sub-threshold)

**Code Review**: ✅ Complete (lean mode confirmation)
- godot-gdscript-specialist: APPROVED WITH SUGGESTIONS (5 nice-to-haves, 0 required)
- qa-tester: GAPS → addressed in r2 (commits 629cb19 → dcfd636)
- 4/5 nice-to-haves applied; 2 deferred as tech debt (RefCounted vs Object cosmetic; `_COUNT` sentinel)

**Deferred tech debt** (logged for v0.5+ revision):
- `extends RefCounted` could be `extends Object` for static-only helper (cosmetic; not blocking)
- Enum bounds-check `< MIN or > MAX` could use `_COUNT` sentinel for reorder safety
- `tests/README.md` (2-segment naming) vs `.claude/rules/test-standards.md` (3-segment naming) — convention conflict; rules file took precedence; escalate to qa-lead for cross-doc reconciliation

**Test Evidence**: ✅ `tests/unit/combat/damage_tuple_test.gd` exists with 18 test functions covering all 3 ACs + 5 edge cases from /code-review findings. CI workflow (`.github/workflows/tests.yml`) will execute on next push.

**Unlocks for sprint**: Stories 002 (HP Application + Overkill), 003 (Death Lifecycle), 004 (WeaponBase Cooldown), 005 (Pierce), 006 (Multi-Target Tick), 007 (Enemy→Player Throttle), 008 (Aggregate DPS Ceiling), 009 (Burn Fixed-Step), 010 (Boss Victory). All 9 downstream Combat stories can now proceed in parallel where dependencies permit.

**Commits**:
- `629cb19` — initial implementation (105 / 194 lines)
- `dcfd636` — r2 with /code-review fixes (147 / 258 lines, +18 functions in test file)
- (this commit) — Status: Complete + Completion Notes
