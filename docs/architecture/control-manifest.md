# Control Manifest — MythSurvivor

**Manifest Version**: 2026-05-25.1

> Flat programmer rules sheet. Required / Forbidden / Guardrails per layer.
> Stories embed this version; `/story-done` checks for staleness.
>
> Source: `.claude/rules/gdscript.md` + `docs/architecture/ARCHITECTURE.md` +
> `.claude/docs/technical-preferences.md` + ADR-0001 + ADR-0003.

---

## Global Rules (apply to every layer)

### Required
- Typed GDScript everywhere — function return types declared, non-obvious variable types declared
- Single responsibility per `.gd` file
- Snake_case filenames + variables + functions; PascalCase class names + scene roots
- All public APIs have doc comments
- Every system uses signals (past-tense names: `health_changed`, `enemy_defeated`, `upgrade_selected`)
- `push_error()` for illegal state; `push_warning()` for recoverable issues
- Validate required `@onready` references in `_ready()` before using

### Forbidden
- Hardcoded balance values in `.gd` (use `.tres` Resource files)
- Fragile long paths like `$"../../SomeManager/DeepChild"`
- Singletons for gameplay logic (use scene composition + dependency injection)
- Silent failures in core gameplay
- Copying any commercial Roguelite survivor game's assets / characters / UI / maps / naming / growth structure / balance values
- Force-pushing to `main`
- Bypassing pre-commit hooks (`--no-verify`)
- Reading `.env*` files or committing secrets

### Guardrails
- Performance budget: 60 FPS sustained, 16.67 ms frame budget — see `.claude/docs/technical-preferences.md` §Performance Budgets
- Engine API risk: LLM training cutoff is ~Godot 4.3; project pinned to 4.6 — verify any post-4.3 API against `docs/engine-reference/godot/VERSION.md`
- Test framework: GUT (to be installed via `/test-setup`). Balance formulas + combat math tests are BLOCKING

---

## Foundation Layer

Systems: Input, Resource Data Framework, Run State.

### Required
- `Input` actions defined in `project.godot` Input Map (`move_up/down/left/right`, future `active_skill_1..4`)
- `.tres` Resource subclasses for every content type (Enemy, Weapon, Upgrade, Wave, Loot)
- Signal-driven run state transitions (`run_started`, `run_paused`, `run_ended`)

### Forbidden
- `Input.is_action_pressed()` polling in `_process()` for one-shot events — use `_input(event)` instead
- Modifying `.tres` schemas without an ADR documenting the change
- Mutating shared `Resource` instances at runtime (use `.duplicate(true)`)

### Guardrails
- Input action names must match across `project.godot` and code (no string typos)

---

## Core Layer

Systems: Player, Camera, Combat, Enemy, Targeting.

### Required
- Player movement uses `move_up/down/left/right` Input actions (no hardcoded keys)
- Combat damage applied via signals (`damage_dealt(amount, target)`) — never direct property writes across systems
- Enemy archetype: base `Enemy` class + per-enemy `.tres` (see TR-ENEMY-001)
- Targeting: weapons consult a shared `Targeting` service, do not iterate enemy lists themselves

### Forbidden
- Direct `target.hp -= damage` from one system into another — use the Combat signal contract
- Per-enemy AI logic that hardcodes specific archetype behaviors (drives archetype pattern violation)
- Player script referencing UI script (player publishes signals; UI subscribes)

### Guardrails
- Each Core system lives in `scripts/[system]/` with a single `[system]_base.gd` + variants
- Collision shapes start as simple primitives (Circle / Capsule). Add complexity only when profiling proves necessary

---

## Feature Layer

Systems: Enemy Spawning, Stage Director, Weapon System, Experience & Progression, Level Up & Upgrade Pool, Character System, Active Skills, Demon Seal, Boss System, Status Effects, Elements, Pickup.

### Required
- Weapons inherit from `WeaponBase` (see TR-WPN-001); cooldown + targeting handled by base
- Damage types limited to: direct / tick / explosion / burn (TR-WPN-002) — no ad-hoc variants
- Upgrade pool filtered by current character (TR-WPN-003)
- XP collection via signal `experience_collected(amount)` → `Experience` system consumes
- Sun Wukong is the only character with active skills (ADR-0003); other characters must remain fully auto-battle

### Forbidden
- Weapon A calling Weapon B directly — weapons are independent
- Direct child-node modification across systems
- Adding new damage types without an ADR amendment
- Implementing active skills on characters other than Sun Wukong without a new ADR

### Guardrails
- Stage Director timeline values configurable via `.tres` (not hardcoded magic numbers)
- Status effects (burn / immobilize / tick) extensible via subclass — base contract preserves type taxonomy
- Boss class extends Enemy (not a separate class hierarchy)

---

## Presentation Layer

Systems: HUD, Menu System, Combat Feedback.

### Required
- HUD updates event-driven (subscribe to gameplay signals, not poll per frame)
- Menu screens are independent `.tscn` files in `scenes/ui/`
- Combat feedback (white flash, screen shake) triggered via signals, never per-frame loops

### Forbidden
- UI scripts owning gameplay state (HP, XP, level — these live in gameplay systems)
- UI scripts modifying gameplay state directly (UI emits intent, gameplay decides)
- Per-frame `label.text = ...` updates without a state-change predicate

### Guardrails
- `@onready` for all required child node references
- UI string concatenation must be localization-ready (no inline string literals for player-facing text — future i18n)

---

## Polish Layer

Systems: Audio, VFX.

### Required
- Audio buses separated: SFX / Music / UI (set in project.godot Audio Bus Layout)
- VFX runs as independent scene branches under a dedicated `VFXRoot` node; never replicated per enemy

### Forbidden
- Polish layer code committed to `main` before Production gate is closed
- Loading audio / VFX synchronously in hot paths

### Guardrails
- Audio asset license + provenance documented (see `README.md` 原创性政策)
- VFX particle counts capped per scene; profile before raising caps

---

## Cross-Layer Rules

### Signals are the only cross-layer communication
- Foundation publishes input events → Core consumes
- Core publishes gameplay events (`enemy_defeated`, `damage_dealt`) → Feature consumes
- Feature publishes progression events (`upgrade_selected`, `level_reached`) → Presentation consumes
- Presentation never calls back into Feature/Core/Foundation (one-way data flow)

### File-extension routing (specialist agents)
Per `.claude/docs/technical-preferences.md` §File Extension Routing:

| Extension | Specialist |
|---|---|
| `.gd` | `godot-gdscript-specialist` |
| `.gdshader` | `godot-shader-specialist` |
| `.tscn` (gameplay) | `godot-specialist` |
| `.tscn` (UI) | `godot-gdscript-specialist` |
| `.tres` | `godot-specialist` |
| `project.godot` | `godot-specialist` |

---

## Manifest Change Log

| Version | Date | Changes |
|---|---|---|
| 2026-05-25.1 | 2026-05-25 | Initial brownfield-import baseline. Synthesized from `.claude/rules/gdscript.md`, ARCHITECTURE.md, technical-preferences.md, ADR-0001, ADR-0003. |
