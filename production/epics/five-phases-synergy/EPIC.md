# Epic: Five Phases Synergy (五行相生协同)

> **Layer**: Feature (Gameplay)
> **GDD**: design/gdd/elements-five-phases.md (revision-4)
> **Architecture Module**: Combat (element_modifier / crit_multiplier slots) + Element System (ElementMatchup util, ComboManager Player-child node, CombatEvents autoload)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories five-phases-synergy`

## Overview

Five Phases Synergy turns the flat additive upgrade pool into a synergy-driven build layer. Weapons and upgrades carry one of the Five Phases (金木水火土); accumulating items across generating-cycle pairs (相生) activates 5 passive combo effects (燎原 chain-burst / 熔岩甲 shield / 矿脉精粹 pierce+crit / 寒露凝锋 frost-slow / 春生回元 regen+XP), while the overcoming cycle (相克) adds a ×1.3/×0.8 weapon-vs-enemy damage modifier. Architecturally it fills Combat's reserved `element_modifier` and `crit_multiplier` pipeline slots (ADR-0007), reads the per-archetype `element` field (ADR-0008), and adds three new pieces per ADR-0006: a stateless `ElementMatchup` lookup, a Player-owned `element_inventory: Dictionary[String,int]`, a signal-driven `ComboManager` (Player child), and a `CombatEvents` autoload bus (so 燎原 reacts to enemy deaths without per-enemy signal connections at 84-enemy scale).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0006: Element System Pipeline (Accepted) | ElementMatchup lookup; element_inventory typed Dict owned by Player; ComboManager per-Player node; CombatEvents autoload bus; crit `maxf()` pull model + seeded RNG | MEDIUM |
| ADR-0007: Combat Damage Pipeline (Accepted) | Fills `element_modifier` (pre-clamp) + `crit_multiplier` reserved slots; `MAX_FINAL_DAMAGE_PER_HIT=200` clamp bounds combo stacking | LOW |
| ADR-0008: Enemy Archetype (Accepted) | `element` field per archetype (anti-dormancy floor: both Bosses + ≥4 Stage-1 non-neutral) | MEDIUM-HIGH (84-enemy perf shared) |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-elem-001 | `ElementMatchup.modifier(src,tgt)→{0.8,1.0,1.3}` filling Combat Formula 1 slot | ADR-0006 ✅ |
| TR-elem-002 | Player `element_inventory: Dictionary[String,int]`, seeded `_ready()`, typed | ADR-0006 ✅ |
| TR-elem-003 | ComboManager (Player child, signal-driven) recompute on inventory change; `combo_activated` | ADR-0006 ✅ |
| TR-elem-004 | 燎原 via `CombatEvents.enemy_killed` bus (value-only payload), NOT per-enemy connect; EXPLOSION-type bypass | ADR-0006 ✅ |
| TR-elem-005 | crit_multiplier `maxf(fire_eyes, ore_crit)` pull model + seeded RNG | ADR-0006 ✅ |

**Coverage: 5/5 traced ✅** (all TR-elem covered by Accepted ADR-0006). No untraced requirements.

## Suggested Story Sequencing (dependency order)

1. **Foundation**: `ElementMatchup` lookup util (Combat) + Player `element_inventory` (typed, seeded) + `CombatEvents` autoload bus + `ComboManager` skeleton (signal-driven recompute, `combo_activated`).
2. **Matchup modifier**: wire `ElementMatchup` into Combat Formula 1's `element_modifier` slot; element tags on 6 weapons + 13 enemies (`.tres`).
3. **The 5 combos** (each its own story): 燎原 (CombatEvents-driven chain burst) → 熔岩甲 (shield, pipeline-after-Formula-1) → 矿脉精粹 (pierce + crit `maxf`) → 寒露凝锋 (frost_slow status, refresh-only — coordinate with Status Effects) → 春生回元 (regen + XP).
4. **Upgrade-pool integration**: element icons + "相生!" combo-proximity hint on LevelUpPanel.
5. **Ghost Market**: 五行灵珠 (Phase Bead) stall + element tags on Blood Pact / Soul Codex.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/elements-five-phases.md` (AC-01..AC-22) are verified
- All Logic/Integration stories have passing test files in `tests/` (ElementMatchup 25-pair table, combo activation Formula 2, crit `maxf`, frost refresh-only)
- The 燎原 DPS-ceiling playtest gate (OQ-7 / ADR-0006 R-4) is signed off before 燎原 ships
- Visual/Feel stories (combo VFX, element icons) have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories five-phases-synergy` to break this epic into implementable stories.
