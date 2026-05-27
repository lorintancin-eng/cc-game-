# Resource Data Framework

> **Status**: Designed (revision-0, awaiting independent /design-review)
> **Author**: claude (reverse-documented from `scripts/enemy/enemy_archetype.gd`, `scripts/character/character_base.gd`, all 7 `resources/enemies/*.tres`, + ARCHITECTURE.md §数据驱动设计)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 4 (数据驱动迭代 — the foundational mechanism for "敌人数值、武器行为、升级、波次和掉落优先通过 Godot Resource 配置")
> **TR Coverage**: TR-data-001
> **Layer**: Foundation (no upstream dependencies)

## Overview

The Resource Data Framework defines **the project's contract for what is data versus what is code**. Game content — enemy stats, weapon parameters, upgrade definitions, wave compositions, loot tables — must live in Godot `.tres` Resource files, NOT in GDScript constants or hardcoded match statements. This GDD codifies the rules, naming, type conventions, and runtime-sharing guarantees that every content system in MythSurvivor must follow.

This is a **standards / framework GDD**, not a gameplay GDD. It produces no in-game behavior; it defines the rules every other system inherits. Without these rules, balance passes require code changes (violating Pillar 4); designers cannot tune values without engineering involvement; and `/balance-check` cannot operate.

Reference ADRs: ADR-0001 (Godot 4.x + GDScript) — the stack choice that makes `.tres` the canonical data format.

## Player Fantasy

Players never see a `.tres` file. They feel its effects:
- **Balance passes ship in hours, not days** — when QA finds 修行者 dies too fast, a designer edits `paper_doll.tres` and the change is live next playtest. Code recompilation is not required.
- **New enemies arrive without a programmer** — a level designer can author `mountain_yokai.tres` from a template, drop it in `resources/enemies/`, and the spawner picks it up if registered.
- **The game's content feels designer-curated, not programmer-derived** — when 修行者's `pickup_radius` is 50 px and 孙悟空's is 60 px, that difference is a design decision recorded in `.tres`, not a magic number buried in a match statement.

Anti-fantasy (what this GDD prevents): players never have a "wait, the enemy I just killed dropped exactly 5.5 XP — that feels like a programmer's first guess" moment. The XP value lives in `wandering_soul.tres` as a numeric field designers can tune.

## Detailed Rules

### Core Rules

1. **All gameplay-tuneable content lives in `.tres` Resource files under `resources/`.** Code defines the *schema* (the Resource subclass with `@export` fields); content authors fill the *values* (the `.tres` instances). This is the prime directive.

2. **A Resource subclass lives in `scripts/<system>/<name>.gd` and `extends Resource`.** Convention:
   - filename: `snake_case.gd` (e.g. `enemy_archetype.gd`)
   - `class_name`: `PascalCase` (e.g. `EnemyArchetype`)
   - all tuneable fields use `@export`
   - all fields have default values (so `.tres` instances are never partially-defined)

3. **A `.tres` instance lives in `resources/<system>/<instance_name>.tres`.** Convention:
   - filename: `snake_case.tres` (e.g. `paper_doll.tres`)
   - one instance per file (no multi-instance `.tres` for tuneable content)
   - file content is Godot's standard format (`[gd_resource type="Resource" script_class="<ClassName>" ...]`)

4. **Resources are read-only at runtime by default.** A system that needs to *mutate* values per-instance (e.g. apply Elite affixes) must call `.duplicate(true)` on the Resource first to get a private copy. Direct mutation of a shared Resource is a bug — it leaks values across all consumers (a Stone Golem with Iron Bones suddenly making EVERY Stone Golem instance have +45% HP).

5. **Resource subclass schema changes require an ADR if they break existing `.tres` files.** Adding a new `@export` field with a default value is backward-compatible (existing `.tres` use the default). Renaming or removing an `@export` field breaks all existing `.tres` references and requires migration. See Edge Cases.

6. **Code may NOT hardcode values that match a `.tres` field's purpose.** If `EnemyArchetype.max_hp` is a field, no `.gd` file may contain `const PAPER_DOLL_HP = 14.0`. The single source of truth is the `.tres`.

7. **Cross-system data references go through `design/registry/entities.yaml`.** When system A consumes a value owned by system B's `.tres`, the value is registered in `entities.yaml` so `/consistency-check` can detect drift. (See Combat GDD's enemy references for the canonical pattern.)

8. **`.tres` files are committed to git as part of the project source.** They are NOT generated build artifacts. Designers edit them as first-class authoring surface; programmers do not regenerate them.

### Current Pillar-4 Compliance Status (Code Audit — 2026-05-25)

| Content Type | `.tres`-driven? | Code location | Compliance |
|---|---|---|---|
| Enemy archetypes | ✅ YES | `scripts/enemy/enemy_archetype.gd` + 7 `.tres` files | **COMPLIANT** |
| Weapon parameters | ⚠️ PARTIAL | `WeaponBase` + subclasses use `@export` but no `.tres` files; values live in Player.tscn embedded weapon nodes | **PARTIAL** — scenes carry the values; works in practice but not Resource-shareable |
| Upgrade definitions + deltas | ❌ NO | Hardcoded in `scripts/player/player.gd` `_apply_upgrade` match statement (e.g. TALISMAN_DAMAGE → `+10.0`) | **NON-COMPLIANT** — Player GDD OQ-6 tracks this |
| Wave compositions | ❌ NO | Hardcoded in `scripts/system/enemy_spawner.gd` | **NON-COMPLIANT** — Enemy Spawning GDD will own this |
| Loot tables | ❌ NO | No loot system yet | N/A (not implemented) |
| Character stats | ⚠️ PARTIAL | `CharacterBase` is a Node-extending class with `@export` fields (NOT a Resource); embedded into Player.tscn at scene level | **PARTIAL** — works in practice; eventually should become a Resource for per-character `.tres` files |

**Migration roadmap** (cumulative across future GDDs):
- Player OQ-6: extract upgrade deltas to `resources/upgrades/*.tres`
- Enemy Spawning GDD (when written): extract wave compositions to `resources/waves/*.tres`
- Weapon System GDD (when written): decide whether to extract per-weapon configurations to `resources/weapons/*.tres` (currently scene-embedded)
- Character System GDD (when written): convert CharacterBase from Node-extending to Resource-extending, then move 修行者 / 孙悟空 / 哪吒 stats to `resources/characters/*.tres`

This audit is reality — not aspiration. Future GDDs that touch these systems MUST cite this section when planning migrations.

### When to Use a Resource (Decision Matrix)

| Question | If YES → Use a Resource | If NO → Constant or scene-embedded value |
|---|---|---|
| Will designers tune this value during balance passes? | YES → Resource | If only programmers touch it → constant |
| Are there multiple "instances" with the same shape? (5 enemies, 30 upgrades, 8 weapons) | YES → Resource | If single-purpose (one global config) → AutoLoad or settings |
| Is this value referenced from > 1 system? | YES → Resource (registered in `entities.yaml`) | If isolated to one script → constant in that script |
| Does this value need to ship in a content patch without a code rebuild? | YES → Resource | If shipped as part of build only → constant |
| Is this an engine constraint / safety floor (e.g. `MIN_COOLDOWN`)? | NO → constant in code | (not a tuning knob) |

### Resource Subclass Template

```gdscript
class_name SomeArchetype
extends Resource

# All tuneable fields use @export and have defaults.
# Group related fields with comments. Use Godot 4 typed exports.

# Identity (always first)
@export var display_name: String = "Default Name"
@export var category: StringName = &"normal"

# Stats (numeric, designer-tuneable)
@export var max_hp: float = 24.0
@export var move_speed: float = 90.0
@export var damage: float = 8.0

# Visual hints (artist-tuneable)
@export var body_color: Color = Color(0.73, 0.24, 0.28, 1.0)
@export var body_scale: float = 1.0

# Behavioral flags (per-instance variation)
@export var is_elite: bool = false
@export_enum("Chase", "Wave Chase") var movement_mode: int = 0
```

### .tres File Template

```
[gd_resource type="Resource" script_class="SomeArchetype" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/<system>/<name>.gd" id="1_archetype_script"]

[resource]
script = ExtResource("1_archetype_script")
display_name = "Specific Instance"
max_hp = 14.0
move_speed = 86.0
# Only override fields where instance differs from defaults
```

## Formulas

### Formula 1: Resource sharing safety (when to `.duplicate(true)`)

```
on need_to_mutate_resource(resource: Resource):
    if resource_will_be_shared_by_multiple_consumers:
        local_copy = resource.duplicate(true)   # deep copy
        mutate(local_copy)
    else:
        mutate(resource)  # safe — single consumer
```

**Variables:**

| Variable | Type | Description |
|---|---|---|
| `resource` | Resource | The loaded `.tres` instance (or any Resource) |
| `resource_will_be_shared_by_multiple_consumers` | bool | Determined by usage pattern — if `load("res://...tres")` is called from multiple call-sites OR if the same node references it in multiple places, the answer is YES |

**Default rule of thumb:** always `.duplicate(true)` unless you have profiled and proven that sharing is safe AND you control all consumers. Memory cost of a duplicate is negligible for tuning Resources (< 1 KB per instance); correctness cost of a shared-mutation bug is hours of debugging.

**Example:** Enemy spawning Iron Bones Stone Golem:
```
var golem_archetype = preload("res://resources/enemies/stone_golem.tres")
var local_archetype = golem_archetype.duplicate(true)   # safe to mutate
local_archetype.max_hp *= 1.45   # Iron Bones affix
local_archetype.body_color = Color(0.4, 0.4, 0.5, 1.0)  # visual override
enemy.archetype = local_archetype
```

### Formula 2: Resource load count (memory footprint)

For N `.tres` files of average size S KB loaded simultaneously:

`resource_memory_mb = (N × S × duplicate_factor) / 1024`

**Variables:**

| Variable | Type | Range | Description |
|---|---|---|---|
| `N` | int | 1 – 1000 | Count of distinct Resource instances live in memory |
| `S` | float (KB) | 0.5 – 4.0 (typical for tuning Resources) | Average single-Resource size |
| `duplicate_factor` | float | 1.0 (shared) – 5.0 (every consumer duplicates) | How many duplicates per Resource |

**Output Range:** for MythSurvivor MVP (~30 distinct content Resources at S ≈ 1 KB, duplicate_factor ≈ 1.5): `(30 × 1 × 1.5) / 1024 ≈ 0.044 MB`. **Memory cost is negligible** — Resources are cheap, the framework's correctness rules cost ~zero in MB.

**When this formula matters:** if a future content pack adds 1000+ weapon variants × `.duplicate(true)` per per-shot Resource → could push to 5+ MB. Then profile.

## Edge Cases

- **If a `.tres` file references a Resource subclass `.gd` that no longer exists** (the `.gd` was renamed or deleted): Godot opens the project but the `.tres` shows as broken. Solution: never delete a Resource subclass without first migrating all `.tres` files. Use an ADR to track schema changes.
- **If a Resource subclass adds a new `@export` field**: existing `.tres` files use the default value silently. **Backward-compatible.** No ADR needed.
- **If a Resource subclass renames an `@export` field**: existing `.tres` files lose the value (the renamed field reads default). **Breaking change** — write an ADR and a migration script (sed-replace across all matching `.tres` files).
- **If two systems mutate the same shared Resource at the same time**: undefined behavior — last writer wins, the other system may read a transient state. Always `.duplicate(true)` before mutation.
- **If a Resource is loaded with `preload("res://..tres")` AND then mutated in one consumer**: the mutation leaks to ALL future consumers that `preload` the same path (Godot caches preloaded resources). Always duplicate after preload if mutation is intended.
- **If a `.tres` value is set outside the design-safe range** (e.g. `Enemy.max_hp = -5`): the consuming system is responsible for clamping (per the consuming GDD's Tuning Knobs). The framework does NOT enforce ranges at the Resource layer. (Future improvement: Resource-level validation via `_validate_property` — see Open Questions.)
- **If a `.tres` file has fields removed from its schema**: Godot loads the file but warns about the unknown property. The unknown field is silently dropped. This is fine for cleanup, but check before deleting fields someone might still be authoring against.
- **If a designer creates a `.tres` file in the wrong directory**: the spawner / loader won't find it. Path conventions are not enforced by the engine — they're enforced by the consuming system's `Glob` pattern. Document the expected path in each consuming GDD.
- **If a Resource references another Resource via an `@export var other_resource: Resource` field** (nested references): both must be loaded in dependency order. Godot's `load_steps` count in the `.tres` header tracks this; do not edit it manually.

## Dependencies

| Dependency | Type | Direction | Interface |
|---|---|---|---|
| **(none — Foundation)** | — | — | The framework is the foundation; it has no upstream design dependencies. All other content systems are downstream consumers. |

**Downstream consumers (Hard — they cannot function without this contract):**

| Consumer | Status | What they consume |
|---|---|---|
| **Enemy** (C-04, Approved GDD) | ✅ Currently compliant | `EnemyArchetype` + 7 `.tres` files |
| **Combat** (C-03, Approved GDD) | ✅ Currently compliant | Reads weapon/enemy `.tres` via the WeaponBase + Enemy nodes |
| **Player** (C-01, Approved GDD) | ⚠️ Partial — OQ-6 tracks upgrade migration | Will own upgrade `.tres` per Player OQ-6 |
| **Enemy Spawning** (FT-01, future GDD) | ❌ Will own wave `.tres` migration | Wave compositions belong in `resources/waves/` |
| **Weapon System** (FT-03, future GDD) | ❌ Will decide whether to own weapon `.tres` | Currently scene-embedded; future decision |
| **Character System** (FT-06, future GDD) | ⚠️ CharacterBase is Node, not Resource | Eventual migration to `resources/characters/*.tres` |
| **Level Up & Upgrade Pool** (FT-05, future GDD) | ❌ Will own upgrade pool `.tres` | Same source as Player OQ-6 |

**Bidirectional check:**
- Combat GDD line 387 lists "Resource Data Framework | Hard | Combat depends on | `.tres` Resource subclasses for weapon and enemy stats" ✅
- Player GDD lists "Resource Data Framework (F-02) | Hard | Player depends on | CharacterBase is a Resource (.tres) per Pillar 4" ⚠️ Currently CharacterBase is Node-extending; mark this as known divergence
- Enemy GDD (Approved) cites this framework ✅

## Tuning Knobs

This GDD is the **framework that defines tuning** — the knobs ARE the `.tres` field values across all content `.tres` files. The framework itself has no runtime-tuneable values.

**Framework-level conventions (not runtime knobs, but ADR-amendable):**

| Convention | Default | Change rule |
|---|---|---|
| Resource subclass file naming | `snake_case.gd` | Lock — change requires renaming all consuming code |
| `.tres` file naming | `snake_case.tres` | Lock — change requires renaming all consumer Glob patterns |
| Resource directory layout | `resources/<system>/<instance>.tres` | Lock — change requires updating ALL `load()` / `preload()` paths |
| Mutation safety default | `.duplicate(true)` before mutation | Lock — exceptions require profiling proof + comment |
| Backward-compat policy | Add new `@export` only; never rename / remove without ADR + migration script | Lock |

## Acceptance Criteria

Numbered for traceability into `/create-stories`. ACs target the framework's correctness guarantees, not the content within.

### AC group: Schema conformance

**AC-01** **GIVEN** any file under `scripts/<system>/<name>.gd` that declares `class_name X extends Resource`, **WHEN** the file is loaded by Godot, **THEN** all fields tuned by content authors are declared `@export` AND all `@export` fields have default values (no orphan `@export var foo: Type` without `= ...`).

**AC-02** **GIVEN** any `.tres` file under `resources/`, **WHEN** Godot loads the file, **THEN** no console warning fires about unknown properties OR missing script reference.

**AC-03** **GIVEN** the project, **WHEN** `grep -rE "^const [A-Z_]+_HP" scripts/` is run, **THEN** zero results (no enemy HP / weapon damage / upgrade delta hardcoded as constants). Note: this AC is **currently failing** — Player.gd hardcodes upgrade deltas. Player OQ-6 tracks resolution.

### AC group: Mutation safety

**AC-04** **GIVEN** an Iron Bones Stone Golem spawning, **WHEN** the spawner mutates the `max_hp` value (×1.45), **THEN** other Stone Golems spawning in the same run still have `max_hp = 70` (NOT 70 × 1.45). Verified via `assert_eq(stone_golem_normal.max_hp, 70.0)` immediately after Iron Bones mutation in test.

**AC-05** **GIVEN** a Resource loaded via `preload("res://resources/enemies/paper_doll.tres")` in two scripts, **WHEN** script A modifies the loaded Resource without `.duplicate(true)`, **THEN** script B's reference sees the modified value (proving the safety rule's importance — this is the failure mode to prevent, not allow).

### AC group: Backward compatibility

**AC-06** **GIVEN** an existing `paper_doll.tres` file, **WHEN** `EnemyArchetype` is updated to add a new `@export var elemental_resistance: float = 0.0` field, **THEN** `paper_doll.tres` loads cleanly AND `paper_doll.elemental_resistance == 0.0` (default applied).

**AC-07** **GIVEN** an existing `paper_doll.tres` file that sets `max_hp = 14.0`, **WHEN** `EnemyArchetype` is updated to rename `max_hp` → `hit_points`, **THEN** `paper_doll.hit_points == 24.0` (the new field's default, NOT 14.0 — the renamed field's value is lost). Conclusion: rename requires migration. (This AC documents the failure mode; the project's correct response is to author and run a migration script.)

### AC group: Registry consistency

**AC-08** **GIVEN** a value V exists in both a `.tres` field (e.g. `paper_doll.max_hp = 14.0`) AND in `design/registry/entities.yaml` under that entity, **WHEN** `/consistency-check` runs, **THEN** the two values match. If they diverge, `/consistency-check` flags the conflict.

**AC-09** **GIVEN** an entity is referenced by 2+ GDDs (e.g. `paper_doll` is referenced by Combat, Player, Enemy, Level GDDs), **WHEN** `entities.yaml` is inspected for that entity, **THEN** the `referenced_by` array lists all referencing GDDs.

### AC group: Path conventions

**AC-10** **GIVEN** a content `.tres` file, **WHEN** the file path is inspected, **THEN** the path follows `resources/<system>/<instance>.tres` (e.g. `resources/enemies/paper_doll.tres`). Files in `resources/` root without a `<system>` subdirectory are non-compliant.

## Open Questions

- **OQ-1** (Resource-level validation): Godot 4.x supports `_validate_property` for runtime validation. Should the framework mandate that Resource subclasses implement validation for their `@export` fields (e.g. `max_hp >= 0`)? **Pro**: catches authoring errors at editor load time. **Con**: boilerplate. **Resolution candidate**: opt-in per Resource — `EnemyArchetype` should validate (numeric clamps), `CharacterBase` doesn't need it (just a config carrier). **Owner**: lead-programmer + systems-designer. **Target**: when first invalid `.tres` value ships and causes a bug.
- **OQ-2** (`.tres` schema migration tooling): When a Resource subclass changes a field name, all matching `.tres` files break silently (per AC-07). No tooling currently exists to detect or auto-migrate. **Resolution candidate**: a `tools/migrate_tres.gd` headless script that takes a from-name / to-name pair + a path Glob. **Owner**: tools-programmer. **Target**: first schema-breaking change (currently none planned for MVP).
- **OQ-3** (Per-character `.tres` Resource migration timing): CharacterBase is currently Node-extending and embedded into Player.tscn at scene level. Migrating to Resource-extending and per-character `.tres` files would unblock the planned 6-character roster (修行者 / 孙悟空 / 哪吒 / 杨戬 / 女娲 / 盘古) — currently 孙悟空 v2 is a code subclass (`SunWukongV2 extends ActiveSkillCharacter`), which doesn't scale. **Resolution candidate**: in Character System GDD (FT-06), make this the primary architectural decision. **Owner**: game-designer + lead-programmer. **Target**: Character System GDD authoring.
- **OQ-4** (Hot reload during Godot editor playtest): when a designer edits a `.tres` while the game is running in the editor, does the change take effect immediately or only on next scene load? **Empirically**: Godot 4.x reloads Resources on `.tres` save IF the consumer holds the Resource by reference (not deep copy). This means runtime `.duplicate(true)` copies do NOT hot-reload. Trade-off: safety (no shared mutation) vs. iteration speed (live editing). **Resolution**: document the trade-off; designers can temporarily skip `.duplicate(true)` in their dev branch for fast iteration but must restore for shipping. **Owner**: tools-programmer. **Target**: include in dev guide.

---

## Registry Updates Recorded

This GDD does not directly add entries to `design/registry/entities.yaml` (it is a framework GDD, not a content GDD). It governs the registry's existence — entities, items, formulas, and constants are catalogued in `entities.yaml` per this framework's `referenced_by` convention.

**Cross-doc consistency**: This GDD's existence is referenced by:
- Combat GDD line 387 (Resource Data Framework as Hard dependency)
- Player GDD lines 233, 392 (Hard dependency + OQ-6 upgrade migration)
- Enemy GDD (Approved — cites this as the foundation for enemy archetypes)
- Future Enemy Spawning, Weapon System, Character System, Level Up GDDs will all reference this framework

## Revision Log

| Revision | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc by /design-system | First pass authored from `scripts/enemy/enemy_archetype.gd` (only `extends Resource` in the project), all 7 `resources/enemies/*.tres`, + audit of CharacterBase / WeaponBase / upgrade hardcoding. 8 required CCGS sections + Visual/Audio omitted (framework has no visual surface) + UI omitted (no UI) + Open Questions + Registry Updates. Honest about Pillar-4 compliance status: 1/6 content categories fully compliant; 2/6 partial; 3/6 non-compliant. Migration roadmap documented in Detailed Rules §Pillar-4 Compliance Status. |
