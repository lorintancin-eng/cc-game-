# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6 (pinned 2026-02-12 — see `docs/engine-reference/godot/VERSION.md`)
- **Language**: GDScript (primary); Python only for external tooling (none in repo currently)
- **Rendering**: Forward+ (D3D12 on Windows, Vulkan elsewhere)
- **Physics**: Jolt Physics (3D default); 2D uses Godot Physics 2D

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: PC (Windows priority; Linux/macOS via Godot export)
- **Input Methods**: Keyboard/Mouse (WASD + arrows for movement, mouse for UI)
- **Primary Input**: Keyboard
- **Gamepad Support**: Partial (movement only via deadzone in project.godot; full TBD)
- **Touch Support**: None
- **Platform Notes**: Auto-battle Roguelite; movement is the only continuous input — keep input map minimal

## Naming Conventions

See `.claude/rules/gdscript.md` for full GDScript style rules.

- **Classes**: `PascalCase` (e.g., `EnemyStats`, `WeaponBase`)
- **Variables**: `snake_case`
- **Signals/Events**: `snake_case`, past-tense for completed events (`enemy_defeated`, `health_changed`)
- **Files**: `snake_case.gd` / `snake_case.tscn` / `snake_case.tres`
- **Scenes/Prefabs**: `PascalCase.tscn` for top-level scene root nodes; folders `snake_case/`
- **Constants**: `UPPER_SNAKE_CASE`

## Performance Budgets

> Source: `design/gdd/03_CORE_GAMEPLAY.md` §13 性能预期 + `docs/architecture/0001-godot4-gdscript.md` Performance Implications.

- **Target Framerate**: 60 FPS sustained on a mid-range desktop (Win10/11, GTX 1060 / RX 580 class). 30 FPS minimum acceptable for the Boss-fight edge case (Boss + summons + 100+ enemies + 200+ projectiles).
- **Frame Budget**: 16.67 ms / frame (60 FPS). Worst-case allowance during Boss fights: 33.33 ms / frame (30 FPS) for ≤5 seconds.
- **Draw Calls**: ≤ 2000 in steady-state combat. Forward+ renderer on D3D12 handles this comfortably; flag any sustained spike above 3000 for `/perf-profile`.
- **Memory Ceiling**: ≤ 1 GB resident process memory on the target hardware. 2D Roguelite with .tres-driven content should not exceed this; investigate any leak that pushes past 1.5 GB.

## Testing

- **Framework**: TBD (run `/test-setup` to scaffold GUT or gdUnit4)
- **Minimum Coverage**: TBD per system; balance formulas + combat math are BLOCKING
- **Required Tests**: Balance formulas, weapon damage, enemy spawning, XP/level math

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- **No clones**: Do not copy any commercial Roguelite survivor game's assets, characters, UI, maps, naming, growth structure, or balance values (see `README.md` 原创性政策)
- **No singletons for gameplay logic**: prefer scene composition + dependency injection
- **No hardcoded balance**: enemies/weapons/upgrades/waves must be `.tres` Resource-driven
- **No `$"../../X/Y/Z"` paths**: brittle long node paths are banned (see `.claude/rules/gdscript.md`)
- **No silent failures in gameplay**: use `push_error()` for illegal state

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- ADR-0001: Godot 4 + GDScript — `docs/architecture/0001-godot4-gdscript.md`
- ADR-0003: Sun Wukong active skills design — `docs/architecture/0003-sun-wukong-active-skills.md`

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: `godot-specialist`
- **Language/Code Specialist**: `godot-gdscript-specialist`
- **Shader Specialist**: `godot-shader-specialist`
- **UI Specialist**: `godot-gdscript-specialist` (no separate Godot UI specialist; UI is `.tscn` + GDScript)
- **Additional Specialists**: `godot-gdextension-specialist` (only if/when native code is added)
- **Routing Notes**: Project is GDScript-only. Use `godot-csharp-specialist` only if user opts into C# for a specific system.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| `.gd` (GDScript) | `godot-gdscript-specialist` |
| `.gdshader` / shader material | `godot-shader-specialist` |
| `.tscn` (UI scenes — HUD, panels) | `godot-gdscript-specialist` |
| `.tscn` (gameplay scenes) | `godot-specialist` |
| `.tres` (Resource data) | `godot-specialist` |
| `project.godot` / engine config | `godot-specialist` |
| GDExtension / native (`.cpp`, `.rs`) | `godot-gdextension-specialist` |
| General architecture review | `godot-specialist` |
