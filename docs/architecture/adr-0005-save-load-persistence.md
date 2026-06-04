# ADR-0005: Save/Load Persistence Architecture

## Status
Accepted (2026-06-04 — independent /architecture-review verdict CONCERNS: architecture substantively passes; SaveService contract sound, godot-specialist validated. Unblocks Merit persistence stories.)

## Date
2026-06-04

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core |
| **Knowledge Risk** | MEDIUM (4.4 changed `FileAccess.store_*` return types — but ConfigFile is unaffected; see Risks) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`; validated by `godot-specialist` (2026-06-04) |
| **Post-Cutoff APIs Used** | `ConfigFile.save()/load()` (stable since pre-4.4), `DirAccess.rename` (atomic-write mitigation, deferred). No post-cutoff API is load-bearing. |
| **Verification Required** | (1) `ConfigFile` round-trips all stored Variant types on the target platform; (2) corrupt-file path produces `push_warning` + fresh state, never a crash; (3) if a web export is ever added, `user://` flush behavior (IndexedDB) must be re-validated. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None (Core infrastructure; no upstream ADR) |
| **Enables** | Future settings/cosmetics/statistics persistence ADRs (this sets the format precedent) |
| **Blocks** | Merit System epic — its persistence stories cannot start until this is Accepted |
| **Ordering Note** | Must be Accepted before `/create-stories merit-system`. Independent of the Element System ADR (ADR-0006). |

## Context

### Problem Statement
The Merit System (`design/gdd/merit-system.md`) is the project's **first system requiring between-run persistence**. It must store earned Merit, purchased unlocks, and lifetime statistics across sessions. There is no save/load infrastructure today. The format and ownership chosen here become the **precedent for all future persistence** (settings, cosmetics, statistics), so the decision must be made deliberately rather than ad-hoc inside the Merit code.

### Constraints
- Godot 4.6 / GDScript; LLM knowledge cutoff ~4.3 — post-cutoff APIs verified against engine-reference.
- Project rule: **no singletons for gameplay logic** (`technical-preferences.md` Forbidden Patterns). A persistence service is infrastructure, not gameplay logic, but the boundary must be enforced.
- Project rule: prefer scene composition + dependency injection; introduce a singleton only for a genuine shared-ownership need (`ARCHITECTURE.md` §信号与数据流规则).
- Single-player, offline. No server, no anti-cheat scope — manual save edits are the player's choice.
- Target platform: PC (Windows priority). Web export is not a current target.

### Requirements
- Persist Merit System state per `merit-system.md` Core Rule 8 (`[merit] total`, `[unlocks] node_N`, `[stats]`).
- Save on two discrete events only (run-end merit-earn; unlock-purchase) — `merit-system.md` Core Rule 9. No periodic autosave.
- Corruption/missing file → fresh save + `push_warning`, never crash — `merit-system.md` AC-14/AC-15.
- Extensible: future systems add sections without touching Merit's data or this service's core.
- Survive schema changes across game versions (migration path).

## Decision

Adopt a **single `ConfigFile` save** owned by a thin Core autoload, **`SaveService`**.

1. **Format — `ConfigFile` (.cfg)** at `user://save.cfg`. One file, section-namespaced:
   - `[meta]` — `schema_version: int` (and future global metadata)
   - `[merit]`, `[unlocks]`, `[stats]` — owned by Merit System
   - future: `[settings]`, `[cosmetics]`, … — appended by their owning systems
   - **Rename note**: Merit GDD originally specified `user://merit_save.cfg`; this ADR generalizes to the shared `user://save.cfg` because persistence is now a project-wide service, not Merit-specific. The Merit GDD is updated in sync with this ADR.

2. **Ownership — autoload `SaveService` (Core module)** is the **sole** reader/writer of the file. It is a pure I/O + schema service: it holds **no gameplay logic** (Merit's scoring, unlock-chain, and difficulty rules live in Merit's own nodes; they call `SaveService` only to read/persist primitives). This is a justified infrastructure singleton — many systems persist to one file = a genuine shared-ownership need.

3. **Save triggers — caller-driven.** `SaveService` never decides *when* to save. Owning systems call `SaveService.save()` on their own discrete events (Merit: run-end merit-earn, unlock-purchase). No timer, no autosave.

4. **Versioning — `[meta] schema_version` + ordered migration chain.** On `load()`, if `schema_version < CURRENT_SCHEMA_VERSION`, run `_migrate(from, to)` step-by-step (`_migrate_v1_to_v2()`, …) before exposing data. Missing/absent meta → treat as v1. `CURRENT_SCHEMA_VERSION` starts at `1`.

5. **Corruption/missing handling.** If `ConfigFile.load()` returns non-`OK` (parse error, missing file): `push_warning`, initialize a fresh in-memory state (`schema_version = CURRENT`, empty sections), and **do not crash**. The corrupt file is **not overwritten** until the next legitimate `save()`, so a player can manually recover it.

6. **No encryption.** Deferred by design: a local single-player merit save is not high-stakes, and any embedded key ships in plaintext (security theater). `ConfigFile.save_encrypted()` exists if a future need arises.

### Architecture Diagram

```
            ┌─────────────────────────────────────────────┐
            │  SaveService (autoload, Core) — sole file I/O │
            │  • _config: ConfigFile (in-memory)            │
            │  • load() / save() -> Error                   │
            │  • get_value / set_value / reset              │
            │  • _migrate(from, to)                         │
            │  signals: save_completed, save_loaded         │
            └───────────────▲───────────────┬──────────────┘
              read/persist   │  set_value()  │  save()
                             │               │
        ┌────────────────────┴───┐   ┌───────┴───────────────┐
        │ MeritLedger / MeritRun │   │ (future) SettingsMenu │
        │ owns scoring + unlock  │   │ CosmeticsManager …    │
        │ logic; no file access  │   │                       │
        └────────────────────────┘   └───────────────────────┘
                          │ writes only to user://save.cfg
                          ▼
                  user://save.cfg   [meta][merit][unlocks][stats]…
```

### Key Interfaces

```gdscript
# Autoload: SaveService  (Core module — registered in project.godot Autoload)
# Pure infrastructure. NO gameplay logic.

func load() -> Error                                  # called once at boot; runs migration
func save() -> Error                                  # called by owners on discrete events
func get_value(section: String, key: String, default: Variant = null) -> Variant
func set_value(section: String, key: String, value: Variant) -> void   # in-memory; persisted on save()
func get_section(section: String) -> Dictionary       # all keys in a section (empty if absent)
func reset() -> void                                  # wipe to fresh state (for "reset progress")

signal save_completed(success: bool)    # success == (err == OK) — broadcast for UI "Saved" toast
signal save_loaded(schema_version: int) # fired after load() + migration complete

const CURRENT_SCHEMA_VERSION: int = 1
const SAVE_PATH: String = "user://save.cfg"
```

**Consumer contract**: systems connect with the typed callable form (`SaveService.save_completed.connect(_on_saved)`), never the deprecated string form. Systems store **primitives only** (ints, floats, Strings, bools, and ConfigFile-native Variants) — never custom `Resource` subclasses, `Object` references, or `Callable`s (see Risks 3c).

## Alternatives Considered

### Alternative 1: JSON via FileAccess + JSON.stringify/parse
- **Description**: Serialize a nested Dictionary to JSON text in `user://save.json`.
- **Pros**: Ubiquitous format; easy to inspect; supports arbitrary nesting.
- **Cons**: Manual serialization; **loses Godot Variant typing** on round-trip (Vector2/Color/etc. become arrays/strings needing manual re-encode); larger corruption surface; touches the 4.4-changed `FileAccess.store_*` API directly.
- **Rejection Reason**: The save data is flat key-value per section — nesting is unneeded. ConfigFile round-trips Variants natively with less code and less corruption surface.

### Alternative 2: Resource (.tres) via ResourceSaver/ResourceLoader
- **Description**: Define a `SaveData` Resource with `@export` fields, save with `ResourceSaver.save()`.
- **Pros**: Strong typing; editor-inspectable; integrates with Godot's resource system.
- **Cons**: **Class-refactor fragility** — renaming a `class_name` or removing an `@export` silently breaks loading of existing saves; `.tres` is designed for game-content authored in-editor, not mutable player-profile data; heavier; a refactor could brick every player's save.
- **Rejection Reason**: Player saves must survive code refactors. `.tres` couples the save format to class shape — unacceptable for cross-version persistence.

### Alternative 3: Per-system save files (merit.cfg, settings.cfg, …)
- **Description**: Each system owns its own file.
- **Pros**: Strong isolation; a corrupt merit file doesn't touch settings.
- **Cons**: No single atomic backup/transfer; more file handles; no shared `[meta]`/migration; harder for the player to back up one "save".
- **Rejection Reason**: One file with namespaced sections is simpler to back up, version, and migrate. Section isolation already prevents cross-system key collision.

## Consequences

### Positive
- One well-defined persistence service; all future systems extend it by adding a section — no new file-I/O code per system.
- Native Variant round-trip → minimal serialization code, fewer bugs.
- Migration chain makes schema evolution safe across game versions.
- `SaveService` is unit-testable in isolation (pure I/O, no gameplay coupling); callers can be tested with a stub.

### Negative
- An autoload singleton is introduced — the first in the project. Accepted because persistence is a genuine shared-ownership need and the service holds no gameplay logic. Must be guarded against scope-creep (no rules/logic may migrate into it).
- A single file means a corruption event affects all sections at once (mitigated by the non-destructive corruption handling — the bad file is preserved for manual recovery).

### Risks
- **Atomic-write safety (R-1)**: `ConfigFile.save()` writes directly with no atomic-swap. A crash mid-write leaves a partial file. *Mitigation (deferred post-MVP)*: write to `user://save.cfg.tmp`, verify `OK`, then `DirAccess.rename(tmp, "user://save.cfg")`. Tracked for the implementation sprint; acceptable to ship MVP without it given the rare write cadence (2 events/run).
- **Custom Resource / Object / Callable cannot round-trip (R-2)**: ConfigFile does not serialize object instances or Callables. Systems MUST store primitive representations (IDs, counts) and reconstruct objects at load. Enforced by the consumer contract above.
- **Web export `user://` is async IndexedDB (R-3)**: not a current target (PC-first). If web export is added, `save()` must be followed by a forced IndexedDB flush (`JavaScriptBridge.eval("saveFiles()")` or equivalent) or data is silently lost on tab close. Documented so a future web port re-validates.
- **FileAccess 4.4 change is a NON-ISSUE here (R-4, documentation guard)**: `FileAccess.store_*` returning `bool` (4.4) does NOT affect `ConfigFile`, which wraps file I/O internally. A future maintainer auditing "FileAccess return types changed in 4.4" should NOT touch this service. Recorded to prevent a false-positive audit.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| merit-system.md | Core Rule 8: save via `ConfigFile` at `user://merit_save.cfg`, sections `[merit]/[unlocks]/[stats]` | Confirms ConfigFile; generalizes path to shared `user://save.cfg` + adds `[meta]`; GDD updated in sync |
| merit-system.md | Core Rule 9: save on merit-earn + unlock-purchase only, no autosave | Caller-driven `save()` triggers; service never auto-saves |
| merit-system.md | AC-14: missing save file → fresh save, no error | Corruption/missing handling §Decision 5 |
| merit-system.md | AC-15: corrupted save → `push_warning`, fresh state, no crash | Corruption handling §Decision 5; corrupt file preserved |
| merit-system.md | §Save/Load: format must extend to future systems (settings, cosmetics, stats) | Section-namespaced single file; `[meta]` schema_version + migration |
| merit-system.md | §Run Metrics Contract: `[stats]` (total_runs, best_survival_time, …) | `[stats]` section via `get_value`/`set_value` primitives |

## Performance Implications
- **CPU**: Negligible. `save()`/`load()` fire on discrete events (≈2 saves/run, 1 load/boot), not per-frame. ConfigFile parse of a small flat file is sub-millisecond.
- **Memory**: One in-memory `ConfigFile` holding a few hundred bytes of primitives. Negligible against the 1 GB ceiling.
- **Load Time**: One file read at boot. Well under any budget.
- **Network**: N/A (offline single-player).

## Migration Plan
No existing save data exists (first persistence system) — nothing to migrate from. The migration *mechanism* (`_migrate(from, to)` chain on `schema_version`) is built now so that future schema changes are safe. `CURRENT_SCHEMA_VERSION = 1`; the first real migration appears only when a future change bumps it to 2.

## Validation Criteria
- `SaveService` unit tests: round-trip each stored Variant type; `load()` of a missing file yields fresh state + `push_warning` (no crash); `load()` of a deliberately corrupted file yields fresh state + preserves the corrupt file; `set_value`→`save()`→`load()`→`get_value` returns the written value.
- Migration test: a v1 file loaded under `CURRENT_SCHEMA_VERSION = 2` (simulated) runs `_migrate_v1_to_v2` and exposes upgraded data.
- Integration: Merit run-end `save()` then relaunch shows persisted Merit/unlocks (Merit epic AC).

## Related Decisions
- ADR-0001 (Godot 4 + GDScript) — language/engine baseline.
- ADR-0006 (Element System pipeline) — sibling v0.5 foundation ADR (independent).
- `design/gdd/merit-system.md` — the GDD this ADR unblocks.
- TR registry: registers new domain `TR-save-*` (TR-save-001 format, -002 ownership/API, -003 versioning/migration, -004 corruption handling).
