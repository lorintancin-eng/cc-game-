# tests/

Test suites for MythSurvivor. Test framework: **GUT** (Godot Unit Test).

## Directory Layout

```
tests/
├── unit/              # Unit tests (one .gd per system, run in isolation)
├── integration/       # Integration tests (multi-system scenarios)
├── fixtures/          # Test data (.tres factories, dummy Resources)
├── helpers/           # Shared test utilities (assertion helpers, factory functions)
└── README.md          # This file
```

## Test Naming Convention

- Files: `[system]_[feature]_test.gd` — e.g. `weapon_cooldown_test.gd`, `enemy_archetype_test.gd`
- Functions inside a file: `test_[scenario]_[expected]` — e.g. `test_zero_health_triggers_death()`

## Installing GUT(Manual — required once)

GUT is a Godot Editor plugin (Addon) and cannot be installed via script.
**You must complete this in the Godot editor:**

1. Open `project.godot` in Godot 4.6 editor
2. Menu: **AssetLib** tab → search `Gut` → install latest version (≥ 9.x for Godot 4)
3. Menu: **Project → Project Settings → Plugins** tab → enable `Gut`
4. Restart the editor
5. A `GUT` panel will appear at the bottom; configure it to scan `res://tests/unit/` and `res://tests/integration/`

After GUT is installed, `addons/gut/` will be at the project root. **Commit `addons/gut/`** so other developers don't have to repeat installation.

## CI Test Runner Command

Once GUT is installed and a first test exists:

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit -gexit
```

This is the command CCGS expects (per `.claude/docs/coding-standards.md` § CI/CD Rules):

> Godot: `godot --headless --script tests/gdunit4_runner.gd`

(We're using GUT instead of gdUnit4 — the equivalent GUT command-line runner is above. Adjust the path in the script as needed once `addons/gut/` exists.)

## Test Categories (BLOCKING vs ADVISORY)

Per `.claude/docs/coding-standards.md` § Testing Standards:

| Story Type | Required Evidence | Gate Level |
|---|---|---|
| Logic (formulas, AI, state machines) | Automated unit test — must pass | BLOCKING |
| Integration (multi-system) | Integration test OR documented playtest | BLOCKING |
| Visual/Feel (animation, VFX, feel) | Screenshot + lead sign-off | ADVISORY |
| UI (menus, HUD, screens) | Manual walkthrough doc OR interaction test | ADVISORY |
| Config/Data (balance tuning) | Smoke check pass | ADVISORY |

**Priority targets** for first tests:
- Balance formulas (damage / XP / level thresholds)
- Weapon damage calculations
- Enemy spawning patterns
- XP / level math

## Determinism Rules

Per `.claude/docs/coding-standards.md` § Automated Test Rules:
- Tests must produce the same result every run — no random seeds, no time-dependent assertions
- Each test sets up and tears down its own state
- No external API / database / file I/O — use dependency injection
- Fixtures in `tests/fixtures/`, not inline magic numbers (exception: boundary-value tests)

## See Also

- `tests/helpers/test_base.gd` — base class for all unit tests
- `.claude/docs/coding-standards.md` — full testing standards
- `.claude/rules/gdscript.md` — code style applies to test files too
