# Epic: Combat System

> **Layer**: Core
> **GDD**: design/gdd/combat-system.md (revision-4, Approved)
> **Architecture Module**: Core / Combat (per `docs/architecture/ARCHITECTURE.md` §战斗模块 — 伤害传递和自动武器行为)
> **Status**: Ready
> **Stories**: 11 stories — created 2026-05-27 (see table below)

## Stories

| # | Story | Type | Status | ADR | Covers |
|---|-------|------|--------|-----|--------|
| 001 | Damage Tuple + Friendly-Fire Contract | Logic | **Complete** ✅ | ADR-0001 | AC-04, AC-05, AC-19 |
| 002 | HP Application + Overkill Clamp | Logic | Ready | ADR-0001 | AC-01, AC-20 |
| 003 | Death Lifecycle (DYING + single died emit) | Logic | Ready | ADR-0001 | AC-02, AC-03 |
| 004 | WeaponBase Cooldown + Single-Target DPS | Logic | Ready | ADR-0001 | AC-09 + Formula 2 |
| 005 | Pierce Damage (Flying Sword) | Logic | Ready | ADR-0001 | AC-06, AC-07 + Formula 6 |
| 006 | Multi-Target Tick (Bagua Array) | Logic | Ready | ADR-0001 | AC-08-A, AC-08-B + Formula 3 |
| 007 | Enemy → Player Damage Throttle | Logic | Ready | ADR-0001 | AC-10, AC-11, AC-12 + Formula 4 |
| 008 | Aggregate DPS Ceiling (MAX_CONTACT_ATTACKERS = 4) | Integration | Ready | ADR-0001 | AC-13, AC-14 + Formula 7 + Core Rule 8 |
| 009 | Burn Damage Fixed-Step (FPS Independent) | Logic | Ready | ADR-0001 | AC-15, AC-16, AC-17 + Formula 5 |
| 010 | Boss Victory Contract | Integration | Ready | ADR-0001 | AC-18 |
| 011 | Reserved Placeholders + Performance Budget | Integration | Ready | ADR-0001 | AC-21, AC-22 (parked) + TR-core-005 |

**Dependency order**: 001 → (002, 004) → (003 ← 002) → (005, 006 ← 004) → (007 ← 002) → (008 ← 007) → (009 ← 006) → 010 → 011

Pickup work in order — each story's `Depends on:` field tells you what must be DONE before you can start it.

## Overview

Combat is the central data + signal layer that mediates every damage exchange. Defines the 5-field damage tuple `(source, target, amount, damage_type, source_kind)`, 4 damage types (DIRECT / TICK / EXPLOSION / BURN with fixed-step accumulator), 7 mathematical formulas (HP application, weapon DPS, multi-target effective DPS, throttle, burn fixed-step, pierce, aggregate ceiling), and 9 Core Rules including the bidirectional friendly-fire contract (Core Rule 1), DYING state guard (Core Rule 6), and aggregate DPS ceiling `MAX_CONTACT_ATTACKERS = 4` (Core Rule 8 + Formula 7). Implementation is distributed — Combat itself is infrastructure (signal contracts + state machine concepts); concrete code lives in `WeaponBase` subclasses, `Enemy`, and `Player` per the contract.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|---|---|---|
| ADR-0001: Godot 4.x + GDScript | Signal-based damage architecture; Resource-driven weapon/enemy stats; Forward+ renderer | HIGH (Performance Implications section flags GDScript 5-20× slower than C# in hot loops; 50-100 enemy + 200+ projectile target stresses this) |

> **Note**: No Combat-specific ADR exists yet. ADR-0001 covers stack-level. Specific Combat decisions (damage type taxonomy, aggregate ceiling = 4, fixed-step burn) are spec-locked in the GDD but should be promoted to ADRs if they need cross-team enforcement.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|---|---|---|
| TR-core-001 | Manual movement / auto attacks | ADR-0001 ✅ |
| TR-core-005 | 60 FPS sustained @ 50-100 enemies | ADR-0001 ✅ |
| TR-wpn-001 | WeaponBase contract (cooldown / damage / targeting / projectile) | ❌ No ADR — suggested: ADR for Weapon base class contract |
| TR-wpn-002 | 4 damage types (direct / tick / explosion / burn) | ❌ No ADR — suggested: ADR for Damage type taxonomy |
| TR-enemy-002 | Combat feedback (0.1s white flash, screen shake for elite/Boss) | ❌ No ADR — suggested: ADR for Combat feedback signal contract |

> ⚠️ **3 of 5 TRs are untraced** (TR-wpn-001, TR-wpn-002, TR-enemy-002). These are the highest-risk gaps — damage type taxonomy in particular is the contract Status Effects (FT-10) GDD will integrate against (per Combat GDD OQ-1 + damage_dealt payload). Recommend writing these 3 ADRs before `/create-stories combat-system` runs, OR proceeding with stories marked Blocked.

## Definition of Done

This epic is complete when:
- All stories implemented, reviewed, and closed via `/story-done`
- All 22 acceptance criteria from `design/gdd/combat-system.md` verified (including AC-21 and AC-22 placeholders that activate when Active Skills and VFX GDDs land)
- All 9 Core Rules have at least one passing test in `tests/unit/combat/`
- All 7 Formulas verified by deterministic test (especially Formula 5 fixed-step burn must pass at both 30 FPS and 60 FPS — AC-15 + AC-16)
- Aggregate DPS ceiling (Core Rule 8) verified by integration test: 8 enemies in contact → max 4 damage events per frame
- Death lifecycle (Core Rule 4) split test: data-death within 1 frame, visual-death within 0.5s
- Pressure Curve §Per-Phase TTK Budget validated against actual playtest data (per OQ-5)
- All 6 Open Questions resolved or explicitly deferred

## Next Step

Run `/create-stories combat-system` to break this epic into implementable stories.
