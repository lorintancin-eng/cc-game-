# Cross-GDD Review Report

> **Date**: 2026-05-27
> **Skill**: `/review-all-gdds` (mode: full — Consistency + Design Theory + Cross-System Scenarios)
> **GDDs Reviewed**: 27 (25 single-system GDDs + 2 UX specs + game-concept + systems-index + entities.yaml)
> **Engine**: Godot 4.6 + GDScript
> **Verdict**: **FAIL** — 5 Blocking consistency + 2 Blocking design theory issues must resolve before architecture work.

---

## Executive Summary

After the 10-GDD design-review pass that brought all 25 single-system GDDs to Approved revision-1, this holistic cross-document audit surfaces **issues that no single-document review could catch**:

- **2 documents (Run State + Stage Director) both claim ownership of the same Node + 9 signals** — only one of them can be right
- **2 contradictions persist from earlier propagation work** (Combat Formula 7 HP=30 leftover; Enemy GDD self-queue_free vs VFX-owns-queue_free)
- **1 dead-code Boss export block in Stage Director** contradicts Boss System's locked canonical archetype values
- **2 deferred OQs (Combat OQ-5 HP playtest; Level Up Pool OQ-2 stack cap)** materially block balance correctness

The 25 GDDs are *individually* sound but *collectively* contain contradictions. This is the value `/review-all-gdds` exists to surface.

---

## Phase 2 — Cross-GDD Consistency Findings

### BLOCKING

#### C-B1 — Run State ↔ Stage Director: ownership conflict for 9 signals + 5-minute clock

**GDDs involved**: `run-state.md`, `stage-director.md`

**Evidence**:
- `run-state.md:11-13`: "Run State is the **stage-level lifecycle manager** — it owns the 5-minute clock, drives the wave-config sequence, schedules the Demon Seal (~2:00) and Elite spawns (3:00 / 4:00), triggers the Boss warning (4:30) and Boss spawn (5:00) ... emits 9 signals."
- `stage-director.md:11-14`: "The Stage Director is the **5-minute pacing engine**. It owns the run's timeline ... emit phase transitions ... reconfigure the EnemySpawner via `apply_wave_config()`"
- Both reference the same `StageDirector` Node (`scripts/system/stage_director.gd`)
- Both claim the same 9 signals (`stage_time_changed`, `boss_warning_started`, `boss_spawned`, `elite_spawned`, `demon_seal_spawned`, `demon_seal_progress_changed`, `demon_seal_completed`, `stage_cleared`, `stage_failed`)
- Downstream GDDs (HUD `hud.md:32-35`, Audio `audio-system.md:71`, Demon Seal `demon-seal.md:36`) all reference "StageDirector" by name

**Why blocking**: Only ONE node exists in code. Architecture cannot map system→signal subscribers if two GDDs both claim ownership.

**Fix**: Pick one canonical owner. Recommended: Run State becomes a thin lifecycle-API wrapper that delegates to Stage Director (which has the actual implementation). Stage Director remains the authoritative GDD for the 9 signals + wave config. Update Run State GDD's Overview + Dependencies to reflect delegation.

#### C-B2 — Stage Director ships dead-code Boss exports contradicting Boss System canonical values

**GDDs involved**: `stage-director.md`, `boss-system.md`, `combat-system.md`, `enemy-system.md`, `entities.yaml`

**Evidence**:
- `stage-director.md:88,206-207`: exports `boss_max_hp=260, boss_damage=16, boss_move_speed=70, boss_scale=1.8`
- `boss-system.md:32-38` (revision-1): "**CANONICAL VALUES are from the archetype `.tres`** (entities.yaml famine_beast) ... `max_hp = 360` (NOT 260, Stage Director's 260 only applies if `boss.archetype == null`, but FamineBeastBoss.tscn always has the archetype, so the 260 is dead code)"
- `entities.yaml:197-204`: `famine_beast: max_hp=360.0, damage=18.0, move_speed=68.0, body_scale=1.7`

**Why blocking**: New contributors reading Stage Director GDD will assume 260/16; existing contributors reading Boss System GDD see 360/18. Architecture story-creation will pull the wrong values.

**Fix**: Stage Director GDD lines 88 + 206-207 must mark `[DEAD-CODE-FALLBACK]` AND add note "Used only if `boss.archetype == null`; FamineBeastBoss.tscn always has archetype, so this block is unreachable in shipping code. Canonical Boss stats: see Boss System GDD §Detailed Rules + entities.yaml famine_beast."

#### C-B3 — Combat Formula 7 example still uses HP=30 (revision-4 propagation gap)

**GDDs involved**: `combat-system.md`

**Evidence**:
- `combat-system.md:375`: `Player HP=30 survives ~1.3s — within the Pressure Curve §Survival Budget (≥1.0s)`
- Combat revision-4 propagated HP=100 elsewhere (line 35 Pressure Curve, line 40 Survival Budget, line 78 ceiling math)
- Formula 7 example line 375 is a leftover from pre-revision-4

**Why blocking**: Combat GDD's worked examples are the de-facto reference for QA testers and downstream balance work. A contradiction within Combat itself undermines its authority.

**Fix**: Recompute Formula 7 example at HP=100:
- 4 active attackers × 5.88 dps (Paper Doll baseline) = 23.5 dps aggregate (with ceiling)
- Without ceiling, 8 attackers × 5.88 = 47 dps → 100/47 ≈ 2.1s
- With ceiling, 100/23.5 ≈ 4.25s
- Update text accordingly; cite Pressure Curve §Survival Budget HP=100 row

#### C-B4 — Enemy GDD vs VFX GDD: queue_free ownership contradiction

**GDDs involved**: `enemy-system.md`, `vfx-system.md`, `combat-system.md` (Combat AC-22)

**Evidence**:
- `vfx-system.md:14` (revision-1): "**`queue_free()` ownership**: on `died` signal, VFX subscribes, plays dissolve for ≤0.5s, then calls `enemy.queue_free()` itself. Enemy does NOT self-`queue_free` on `died` — VFX is authoritative."
- `vfx-system.md:52-58` Formula 1: "VFX subscribes... plays dissolve, then itself calls `queue_free()` on the enemy node. Enemy does NOT self-`queue_free`."
- `vfx-system.md:96` AC-01: "GIVEN `Combat.died(payload)` fires, WHEN VFX subscriber runs, THEN `play_dissolve(payload.enemy, 0.5)` is invoked AND after 0.5s elapses VFX calls `payload.enemy.queue_free()` (VFX owns the call; Enemy does NOT self-free)."
- `enemy-system.md:43`: "`_is_dead = true` flag set; `velocity = Vector2.ZERO`; XP orb spawned ...; `died(enemy)` signal emitted; **`queue_free()` called**."
- `enemy-system.md:453` AC-09: "GIVEN Enemy with `current_hp = 5`, WHEN `take_damage(15)` is called (overkill), THEN `current_hp = 0` (clamped, not -1) AND `died(self)` is emitted exactly once **AND `queue_free()` is called**."

**Why blocking**: Two GDDs disagree on who frees the node. If Enemy self-frees AND VFX tries to call `queue_free()` after dissolve, the second call hits a freed node (warning or crash). If neither frees, memory leaks. Combat AC-22 (line 554) reserves the contract for VFX GDD to resolve — which it has, but Enemy GDD hasn't propagated.

**Fix**: Enemy GDD Rule 3 (line 43) and AC-09 (line 453) must be rewritten:
- Rule 3: remove "`queue_free()` called" at end; replace with "emit `died(enemy)` signal — VFX subscriber will call `queue_free()` after dissolve (per VFX GDD AC-01)"
- AC-09: remove "AND `queue_free()` is called"; replace with "AND `died(self)` is emitted exactly once. (`queue_free()` is then called by the VFX subscriber after dissolve completes — see VFX AC-01.)"

#### C-B5 — Mirror of C-B4 (Enemy AC-09)

Same root cause as C-B4. Both AC text and Rule text must change in Enemy GDD revision.

---

### WARNING

| # | Finding | GDD(s) | Quick Fix? |
|---|---|---|---|
| C-W01 | Combat 5 bidirectional checks still ⏳ — all downstream GDDs now exist | `combat-system.md:409-414` | ✅ 5-min |
| C-W02 | Enemy Spawning ⏳ bidirectional check not closed | `enemy-spawning.md:197-199` | ✅ 5-min |
| C-W03 | Enemy GDD has zero Targeting references; needs Targeting dep row | `enemy-system.md` Dependencies | ✅ 5-min |
| C-W04 | Boss System lacks Bidirectional check subsection | `boss-system.md` | ✅ 10-min |
| C-W05 | Boss interrupt-immunity (Rule 10) vs Immobilize velocity-zero — see Scenario S4 | `boss-system.md:72,202`, `active-skills.md:81,210`, `status-effects.md:121,154` | needs design decision |
| C-W06 | Pickup radius 3-way conflict (50+bonus vs 34+bonus vs 34+bonus) — flagged as OQ-2 in all 3 | `player-system.md:222`, `experience-progression.md:107`, `pickup-system.md:77` | needs design decision |
| C-W07 | Combat line 235 says 火眼金睛 = 1.2 fixed; Active Skills says 1.20–1.55 stacked | `combat-system.md:235` | ✅ 5-min |
| C-W08 | Enemy GDD must clarify source-side `damage_dealt` is weapon's responsibility | `enemy-system.md:215-216` | ✅ 5-min |
| C-W09 | Combat line 399 references nonexistent `find_in_radius` primitive | `combat-system.md:399`, `targeting-system.md:186-187` | ✅ 5-min |
| C-W10 | Demon Seal `required_seconds` Tuning Knob duplicated (Demon Seal correctly delegates already) | `demon-seal.md:79-83` | ✅ 5-min |
| C-W11 | Boss HP 360 vs late-game player DPS — Boss may die in 4s, Enrage never triggers | see D-W3 | needs design decision |
| C-W12 | Player AC-14 ↔ Combat AC-19 zero-damage consistency — verified compatible | — | none needed |
| C-W13 | Enemy AC-09 ↔ Combat AC-03 double-death consistency — verified compatible | — | none needed |
| C-W14 | Demon Seal AC-08 (25 points at 50%) — no conflicts | — | none needed |
| C-W15 | Combat AC-21 + Active Skills AC-08 pipeline — consistent | — | none needed |
| C-W16 | Combat AC-22 + VFX AC-01 + Enemy AC-09 three-way contract — fix per C-B4 | see C-B4 | covered above |
| C-W17 | HUD AC-10 + Combat Feedback AC-06 + Audio AC-04 heartbeat 3-way — consistent ✅ | — | none needed |

---

## Phase 3 — Game Design Holism Findings

### BLOCKING

#### D-B1 — Player HP=100 vs Pressure Curve design intent HP=30; survival windows 3× longer than intended

**GDDs involved**: `combat-system.md`, `player-system.md`, all Enemy archetype `.tres`, `stage-director.md` wave configs

**Evidence**:
- `combat-system.md:36-40`: "Player MUST survive ... Surrounded by 4 simultaneous Paper Dolls for at least **4.25 seconds** before death ... Design note: HP=100 produces noticeably longer survival windows than the originally-planned HP=30 (4.25s vs 1.3s)"
- `combat-system.md:78`: "Without the ceiling, 8+ enemies of similar damage = 47+ dps and an HP=100 player dies in ~2.1 seconds — still a failure of the Familiarisation budget (which expects no death risk in minute 1) but less spectacularly fast than the HP=30 scenario originally documented"
- `player-system.md:283`: "(NOTE: Combat GDD §Pressure Curve assumes HP=30 as design intent; current 修行者 ships at 100 — see OQ-1 for propagation path.)"
- `combat-system.md:562` (OQ-5): "**The recomputed survival windows are wider than originally designed** ... Two valid balance directions: (a) raise enemy `damage` across `.tres` files to compress TTKs back toward 1-3 hits, OR (b) Lower Player base HP toward 50-60."

**Why blocking — compound impact**:
- ALL downstream curves (Enemy damage values, Stage Director wave ramps, Boss HP 360) were tuned against design intent HP=30
- Pillar 1 ("清晰的生存压力 / clear survival pressure") is materially weaker than designed
- The Familiarisation phase (0:00-1:00) was designed to have "no death risk"; current numbers leak that promise
- The Risk/Reward phase (2:00-3:00) was designed for ~9 hits-to-die; current numbers give 17+

**Fix sequence**:
1. Run v0.4 playtest with current values; record actual death timings
2. Resolve Combat OQ-5 — pick path (a) raise enemy damage OR (b) lower Player HP
3. Update Enemy archetype `.tres` OR Player.tscn / CharacterBase
4. Re-validate Stage Director wave ramp against the chosen baseline
5. Update Combat GDD Pressure Curve + Per-Phase TTK Budget to match shipped values
6. Run `/propagate-design-change` to cascade

#### D-B2 — Level Up Pool OQ-2 — no per-upgrade stack cap; Talisman 4×stacked already exceeds Combat's 5× ceiling

**GDDs involved**: `level-up-pool.md`, `combat-system.md`, `weapon-system.md`

**Evidence**:
- `level-up-pool.md:170-179`: "For a Talisman build at level 10 with 4 Talisman damage upgrades stacked: base damage = 8.0, after 4 × UPGRADE_TALISMAN_DAMAGE (+10 each) = 8 + 40 = 48 damage ... This is the balance ceiling concern — per Combat GDD §Tuning Knobs warning. 4 stacks of +10 on a base-8 weapon = **6× effective damage**."
- `combat-system.md:458`: "Stacked `source_modifier` from level-up pool can push `final_damage` past the design-safe range. `/balance-check` should flag any build path that exceeds **5.0× cumulative damage multiplier**."
- `level-up-pool.md:193`: "no per-upgrade cap in v0.4 — see OQ-2"
- `level-up-pool.md:255` OQ-2: still open

**Why blocking — compound with D-B1**:
- Combined with HP=100 (D-B1), early game is trivially safe AND late game one-shots Boss
- Flying Sword + pierce stacks compound (D-W1) → effective DPS scales linearly with stacks
- Boss HP=360 (D-W3) → Enrage at 30% HP = 108 HP — never triggers if player one-shots Boss

**Fix**:
1. Add `max_stacks` field to upgrade definitions in `level-up-pool.md` Detailed Rules
2. Suggested defaults: 3 for damage upgrades, 5 for cooldown upgrades, 2 for pierce
3. Combat 5× ceiling must be enforced (filter at pool generation OR clamp in `_apply_upgrade`)
4. Re-run `level-up-pool.md` Formula 4 worked example with caps; verify all builds stay ≤ 5×

### WARNING

| # | Finding | GDD(s) |
|---|---|---|
| D-W1 | Flying Sword + pierce_count → linear DPS scaling dominant strategy | `weapon-system.md:122-126`, `level-up-pool.md:74`, `combat-system.md:341` |
| D-W2 | XP overflow late-run (positive feedback no sink; no XP-consumption upgrade) | `player-system.md:181-191`, `experience-progression.md` |
| D-W3 | Boss HP=360 vs late-game stacked player DPS — Enrage may never trigger | `combat-system.md:449-450`, `boss-system.md:58-67` |
| D-W4 | Active Skills pillar mapping inconsistent with `game-concept.md:12` Pillar 2 auto-battle text | `active-skills.md:6`, `game-concept.md:12` |
| D-W5 | Sun Wukong fantasy diverges from `game-concept.md:72` "exorcist/practitioner" identity | `active-skills.md:26-29`, `character-system.md:32`, `game-concept.md:72` |

### INFO (no action needed)

- Progression loop is unambiguously single-source (XP → level → upgrade). No competing loops.
- Player attention budget holds: movement is only continuous input; Sun Wukong exception bounded by ADR-0003.
- No anti-pillar (originality) violations detected across 27 GDDs.

---

## Phase 4 — Cross-System Scenario Walkthroughs

### Scenarios walked: 4

**S1 — Boss kill during seal completion** (⚠️ WARNING)
- Combat → Boss → Stage Director → Demon Seal → Experience
- If `progress_seconds` hits `required_seconds` AFTER `stage_cleared` fires, `_on_demon_seal_completed` has NO `_is_stage_cleared` guard → 8 XP reward orbs spawn around victorious player
- Symmetric to Demon Seal OQ-4 (already tracked for `_is_stage_failed`); same fix path covers both

**S2 — Multi-level XP cascade from Boss kill burst** (⚠️ WARNING)
- Experience → Player → Level Up Pool → Run State → HUD
- Player GDD Formula 4 documents the cascade; Level Up Pool §3 documents `_pending_level_choices` queue
- **Joint contract** (does `paused = true` set mid-while-loop prevent further enqueuing on same frame?) is **underspecified**
- Recommended: add Detailed Rule clarifying cascade is queue-based, not panel-stacking

**S3 — Player death during seal active** (🟡 WARNING — already tracked)
- Player → Demon Seal → Stage Director → HUD → Audio → Menu
- Already documented in Demon Seal r1 OQ-4 (`_on_demon_seal_completed` missing `_is_stage_failed` guard)
- Player remains in "player" group (no queue_free on death), `_players_in_range > 0` persists, seal continues ticking
- **Same fix as S1**

**S4 — Immobilize on Boss during Boss CHARGE_WINDUP** (⚠️ WARNING — cross-doc rule conflict)
- Active Skills → Boss → Status Effects → Combat
- Boss Rule 10 says "interrupt-immune" but Immobilize per-frame writes `velocity = Vector2.ZERO`
- Net effect: Boss enters CHARGE state but is mechanically frozen → contradictory player messaging
- **Recommended fix**: Boss Rule 10 must clarify "interrupt-immune" excludes velocity-zeroing AOEs OR Immobilize must check `target.is_in_group("bosses")` and skip Boss (mirror of Lv4 `_can_break_elite` mechanic)

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|---|---|---|---|
| `run-state.md` OR `stage-director.md` | Ownership conflict (C-B1) — pick one canonical | Consistency | Blocking |
| `stage-director.md` | Dead-code Boss exports (C-B2) | Consistency | Blocking |
| `combat-system.md` | Formula 7 HP=30 leftover (C-B3) | Consistency | Blocking |
| `enemy-system.md` | Self-queue_free contradicts VFX (C-B4/C-B5) | Consistency | Blocking |
| `combat-system.md` | OQ-5 HP=100 playtest resolution (D-B1) | Design Theory | Blocking |
| `level-up-pool.md` | OQ-2 stack cap (D-B2) | Design Theory | Blocking |
| `combat-system.md` | 火眼金睛 1.20–1.55 range, find_in_radius stale ref, bidirectional ⏳ closure | Consistency | Warning |
| `boss-system.md` | Rule 10 interrupt-immunity clarification (C-W05/S4); bidirectional check (C-W04) | Consistency | Warning |
| `enemy-system.md` | Add Targeting dep row + damage_dealt note (C-W03/C-W08) | Consistency | Warning |
| `enemy-spawning.md` | Close ⏳ bidirectional checks (C-W02) | Consistency | Warning |
| `demon-seal.md` | Mark required_seconds tuning knob as Stage-Director-delegated (C-W10) | Consistency | Warning |
| `game-concept.md` | Pillar 2 ADR-0003 carve-out (D-W4); Player Fantasy includes Sun Wukong identity (D-W5) | Design Theory | Warning |
| `level-up-pool.md` | Address Flying Sword pierce cap (D-W1) | Design Theory | Warning |

---

## Verdict: **FAIL**

**Reasoning**: 5 Blocking consistency issues + 2 Blocking design theory issues. Architecture cannot be safely built on documents that contradict each other (Run State vs Stage Director ownership; Enemy vs VFX queue_free authority; Stage Director vs Boss canonical stats) AND on balance ceilings that are factually unset (HP=100 stale; Talisman stack cap absent).

The 25 GDDs are *individually* sound (all revision-1 Approved). They are *collectively* incoherent in these specific places. Resolving the 7 blockers brings the documents back to a consistent baseline.

---

## Required Actions Before Re-Running

### Tier 1 — Resolve before any architecture / story work (BLOCKING)

1. **Pick C-B1 canonical owner** (Run State OR Stage Director) — affects all 9 downstream signal subscriptions
2. **Update Stage Director C-B2** — mark 260/16 exports as dead-code fallback
3. **Update Combat Formula 7 C-B3** — recompute example at HP=100
4. **Rewrite Enemy Rule 3 + AC-09 (C-B4/C-B5)** — delegate `queue_free` to VFX
5. **Resolve Combat OQ-5 (D-B1)** — run v0.4 playtest → pick HP=100 retention with raised enemy damage OR Player HP=50-60 → `/propagate-design-change`
6. **Add Level Up Pool max_stacks (D-B2)** — enforce Combat 5× ceiling hard cap

### Tier 2 — Resolve before pre-Production gate-check (WARNING)

- 17 consistency warnings (most are 5-30 minute single-doc edits — ⏳ → ✅ closures)
- 5 design warnings (Sun Wukong pillar carve-out, Flying Sword pierce cap, Boss Enrage validation)
- 4 scenario warnings (Demon Seal `_is_stage_cleared` guard, multi-level cascade rule, Boss Immobilize interaction)

### Tier 3 — Future tooling debt

- `/balance-check` skill must enforce Combat 5× ceiling
- CI guard: grep for `extends ActiveSkillCharacter` to enforce ADR-0003 scope-creep guard (per `active-skills.md:35`)
- `/consistency-check` skill should run after every GDD revision to prevent drift

---

## Cross-Reference Index

| Authority Source | Used By |
|---|---|
| `design/gdd/game-concept.md` (pillars + MVP scope) | All 25 system GDDs |
| `design/gdd/systems-index.md` (dependency map + status) | `/create-epics`, `/create-stories`, `/gate-check` |
| `design/registry/entities.yaml` (7 entities + 11 formulas + 6 constants) | All combat-touching GDDs |
| `docs/architecture/0003-sun-wukong-active-skills.md` (ADR) | `active-skills.md`, `character-system.md` |
| `docs/architecture/tr-registry.yaml` (TR-IDs) | `combat-system.md`, all single-system GDDs |

---

*Generated by `/review-all-gdds` on 2026-05-27. Re-run after Tier 1 blockers are resolved to upgrade verdict.*
