# Character System

> **Status**: Approved (revision-0 — first-try PASS, 0 blockers)
> **Author**: claude (reverse-documented from `scripts/character/character_base.gd` + `active_skill_character.gd` + `sun_wukong_v2.gd` + 02_CHARACTER_DESIGN.md + ADR-0003)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 2 (build choice — character is the highest-level construction decision), Pillar 3 (神话气质 — characters embody myth-figure identities)
> **TR Coverage**: TR-char-001 (6 characters planned), TR-char-002 (Sun Wukong active skills exception), TR-char-003 (signal contracts for HUD)
> **Layer**: Feature/Alpha (depends on Player, Weapon System; consumed by Level Up, HUD)

## Overview

The Character System provides **the identity layer** between Player (the scene-runtime) and the specific 神 the player embodies. CharacterBase is a Node-extending class attached as a child of Player.tscn — at character-select time, its `max_health`, `move_speed`, `pickup_radius`, `initial_weapon_id`, and `element` override Player's defaults. CharacterBase also defines per-character behavior hooks: `_on_kill`, `_on_damaged`, `_on_energy_full` (for characters with an energy bar mechanic) and `_get_allowed_upgrade_ids` for upgrade pool filtering.

**Two-tier class hierarchy**:
- `CharacterBase` (extends Node) — base for auto-battle characters (修行者, 哪吒 future, 杨戬 future, 女娲 future, 盘古 future)
- `ActiveSkillCharacter extends CharacterBase` — Sun Wukong's exception per ADR-0003 (4 skill slots, 1/2/3/4 key triggers)

**v0.4 implementation**: only 修行者 (default, no energy bar, no active skills) + 孙悟空 v2 (ActiveSkillCharacter subclass) are fully implemented. Other 4 characters are designed in 02_CHARACTER_DESIGN.md but not coded.

**Pillar 4 partial compliance**: CharacterBase is Node-extending (NOT Resource-extending). Per Resource Data Framework GDD audit, this is "PARTIAL" — Pillar 4 ideal would have `.tres`-per-character. Tech debt; tracked in OQ-1.

Reference: 02_CHARACTER_DESIGN.md (designer-flavor doc), ADR-0003 (Sun Wukong exception), SUN_WUKONG_V2_DESIGN.md (concrete arrangement), Player GDD (CharacterBase override mechanic), Level Up GDD (upgrade pool filter).

## Player Fantasy

Character is the **highest-level identity choice** the player makes — once per run.

> "I open the character-select panel. 修行者 is the safe choice — auto-battle, balanced stats, no special mechanic. Or 弼马温 (孙悟空) — 4 active skills on 1-2-3-4 keys, no energy bar, but I have to remember to press them and time them. Or — coming in a future patch — 哪吒 with three-flames energy, 杨戬 with天眼 single-target burst, 女娲 with five-element cycle, 盘古 with channel-and-burst. Each one shapes the whole 5-minute run."

When Character System works invisibly, the player feels:
- **Identity matters** — picking 孙悟空 vs 修行者 changes the moment-to-moment input pattern, not just stats
- **Mythological grounding** — each character is recognizably a god from public-domain Chinese myth (per originality policy)
- **Replayability** — 6 characters × different builds = 6+ distinct run flavors per session

Anti-fantasy: characters that all feel like reskins of 修行者 with stat tweaks (Sun Wukong v1 was this — corrected by ADR-0003 / v2 active skills). Energy bars that don't visibly matter. Locked-roster gates that block experimentation.

## Detailed Rules

### Core Rules

1. **CharacterBase is the identity carrier** — `extends Node` (NOT Resource), attached to Player.tscn at scene authoring time as a child node. Player reads CharacterBase fields at runtime via `get_node` or direct child reference (`_character_base`).

2. **CharacterBase fields override Player defaults** at spawn (per Player GDD Core Rule 5):
   - `character_id: String` (e.g. "cultivator" / "sun_wukong" / "nezha")
   - `display_name: String` (e.g. "修行者" / "齐天大圣")
   - `max_health: float = 100.0` (overrides Player's 100 default)
   - `move_speed: float = 200.0` (overrides Player's 180 default — note: Player.tscn 修行者 CharacterBase = 180, NOT 200)
   - `pickup_radius: float = 50.0`
   - `initial_weapon_id: String` (which weapon is enabled at spawn)
   - `energy_bar_config: Dictionary` (per-character energy bar; empty for 修行者)
   - `unlock_condition: Dictionary` (v0.3 default: all unlocked)
   - `element: String = "neutral"` (五行属性; locked at neutral until v0.5+)

3. **Per-character behavior hooks** — subclasses override these (CharacterBase provides no-op defaults):
   - `_on_energy_full() -> void` — energy bar maxed (孙悟空 v1 triggered 七十二变 here; v2 deprecated)
   - `_get_allowed_upgrade_ids() -> Array[String]` — filter upgrade pool entries by character
   - `_on_kill(enemy: Node) -> void` — kill callback (e.g. 孙悟空 +1 灵气, 哪吒 build flame)
   - `_on_damaged(amount: float) -> void` — damage callback (e.g. 哪吒 +10 真火)

4. **ActiveSkillCharacter extends CharacterBase** (per ADR-0003) — adds 4-slot active-skill state machine. **Sun Wukong v2 is the ONLY character of this subclass** (per ADR-0003 carve-out).
   - 4 cooldown timers (one per skill slot 0-3)
   - 4 max_cd values
   - 4 unlocked flags (default false; unlocked at Lv5/10/15/20 via Level Up GDD's skill-choice queue)
   - 4 skill levels (0 = locked, 1-4 = unlocked)
   - Per-frame cooldown countdown in `_process(delta)`
   - `cast_skill(slot)` called by Player on key 1/2/3/4 press; returns true if cooldown ready + unlocked
   - `skill_cooldown_changed(slot, remaining, max_cd, unlocked)` signal for HUD

5. **Auto-battle characters (CharacterBase)** do NOT have active skills. Per ADR-0003 — only Sun Wukong is a special case. 修行者 + future 哪吒/杨戬/女娲/盘古 follow the auto-fire weapon contract.

6. **Per-character energy bar (optional)** — `energy_bar_config` dict has keys: `max_value` (e.g. 30.0 for 孙悟空 灵气), `fill_color`, `label` (e.g. "灵气" / "三昧真火"), `auto_trigger` (true for arc-style auto-cast; false for player-held). HUD reads this. Empty dict = no energy bar (修行者).

7. **Element field (Pillar future)** — `element: String = "neutral"`. v0.4 all characters are neutral. v0.5+ Elements GDD (FT-11) will assign 五行 elements per character + activate damage modifiers (per Combat GDD OQ-4, element_modifier slot).

8. **Character selection at run start** — `CharacterSelectPanel` (scenes/ui/CharacterSelectPanel.tscn) shows 2 options in v0.4 (修行者 + 弼马温). Player chooses; the selected character's CharacterBase becomes the active config; weapons unlock based on `initial_weapon_id`. Character is locked for the duration of the run (no mid-run switch).

### Character Roster (Designed vs Implemented)

| Character | Status | Implementation | Energy Bar | Initial Weapon | Defining Mechanic |
|---|---|---|---|---|---|
| 修行者 (Cultivator) | ✅ Implemented | CharacterBase (Node, no subclass) | None | Talisman | Baseline; pure auto-battle |
| 弼马温 (Sun Wukong v2) | ✅ Implemented | ActiveSkillCharacter → SunWukongV2 | None (uses cooldowns) | Jingu Bang (special) | 4 active skills on 1/2/3/4 (per ADR-0003) |
| 哪吒 (Nezha) | 📋 Designed only | Not coded | "三昧真火" (build-on-damage) | TBD | Damage-build resource, fire-themed weapons |
| 杨戬 (Yang Jian) | 📋 Designed only | Not coded | "天眼槽" (manual-hold) | TBD | Single-target burst on energy expend |
| 女娲 (Nuwa) | 📋 Designed only | Not coded | "五色轮" (5-element cycle) | TBD | Element-cycling auto-cast |
| 盘古 (Pangu) | 📋 Designed only | Not coded | "开天力" (channel-and-burst) | TBD | Slow channel, big burst |

Per 02_CHARACTER_DESIGN.md §1.2 (v0.3 implementation range): 修行者 + 孙悟空 only. Other 4 deferred to v0.4+ per design intent.

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Player** (C-01, Approved) | CharacterBase → Player | Player reads CharacterBase fields at spawn (`max_health`, `move_speed`, `pickup_radius`, `initial_weapon_id`); attaches CharacterBase as scene child |
| **Weapon System** (FT-03, Approved) | CharacterBase → Weapon | `initial_weapon_id` enables/disables Player's child weapon nodes at spawn |
| **Level Up & Upgrade Pool** (FT-05, Approved) | CharacterBase → Level Up | `_get_allowed_upgrade_ids()` filters upgrade pool; ActiveSkillCharacter contributes `_pending_skill_choices` at Lv5/10/15/20 |
| **Active Skills** (FT-07, future) | ActiveSkillCharacter → Active Skills | ActiveSkillCharacter manages 4 cooldown slots; `cast_skill(slot)` triggered by Player on 1/2/3/4 key press |
| **HUD** (P-01, future) | ActiveSkillCharacter → HUD | HUD subscribes to `skill_cooldown_changed(slot, remaining, max_cd, unlocked)` for 4 cooldown indicators (per ADR-0003 + Sun Wukong v2 design) |
| **Combat** (C-03, Approved) | CharacterBase → Combat (kill callback) | `_on_kill(enemy)` fires when an enemy dies (Player-side hook); `_on_damaged(amount)` on Player damage |
| **Elements GDD** (FT-19, future v0.5+) | CharacterBase → Combat | `element` field will activate `element_modifier` in Combat Formula 1 |
| **Resource Data Framework** (F-02, Approved) | (partial) | CharacterBase is Node-extending, not Resource-extending — Pillar 4 partial (OQ-1) |

## Formulas

### Formula 1: Stat override at character select

```python
on character_select(chosen_character: CharacterBase):
    _character_base = chosen_character
    max_hp = _character_base.max_health
    move_speed = _character_base.move_speed
    # pickup_radius read on-demand (no Player-level field override)
    
    # Enable initial weapon
    for weapon in Player's weapon children:
        weapon.enabled = (weapon.weapon_id == _character_base.initial_weapon_id)
    
    # Set 5行 element (used by Combat Formula 1 element_modifier slot when Elements GDD lands)
    _element = _character_base.element
```

Per Player GDD Core Rule 5 + AC-16/AC-17.

### Formula 2: ActiveSkillCharacter cooldown countdown

```gdscript
on _process(delta):
    for slot in range(4):
        if _skill_cooldowns[slot] > 0.0:
            var prev_ceil = ceili(_skill_cooldowns[slot])
            _skill_cooldowns[slot] = max(_skill_cooldowns[slot] - delta, 0.0)
            # THROTTLED emit (ADR-0003 2026-05-28): only on integer-second change or reaching 0
            if ceili(_skill_cooldowns[slot]) != prev_ceil or _skill_cooldowns[slot] == 0.0:
                skill_cooldown_changed.emit(slot, _skill_cooldowns[slot], max_cd, unlocked)
```

Per-frame **countdown**, but **throttled emit** (~1/sec/slot): the signal fires only when the integer-second value changes or the cooldown hits 0 — the HUD label shows whole seconds, so sub-second emits are invisible and suppressed. Enforced by `skill_cooldown_emit_throttle_test.gd` (ADR-0003). Discrete events (cast/level-up/CD-bonus) emit separately.

### Formula 3: Skill cast eligibility

```gdscript
on cast_skill(slot):
    if slot < 0 or slot > 3: return false
    if not _skill_unlocked[slot]: return false
    if _skill_cooldowns[slot] > 0.0: return false
    
    var success = _on_cast_skill(slot)  # subclass override
    if success:
        _skill_cooldowns[slot] = _skill_max_cds[slot]
        skill_cooldown_changed.emit(slot, max_cd, max_cd, true)
    return success
```

Per ADR-0003 + ActiveSkillCharacter.gd:67-80.

### Formula 4: Upgrade pool filter

```gdscript
on Level Up panel.show_choices(options):
    if _character_base._get_allowed_upgrade_ids().is_empty():
        # Default: no filter, show all options
        pass
    else:
        options = [opt for opt in options if opt.id in _character_base._get_allowed_upgrade_ids()]
```

Per TR-wpn-003 + Level Up GDD Core Rule 3. v0.4 default: empty list = no filter (all upgrades visible).

## Edge Cases

- **If Player.tscn has no CharacterBase child** (debug scene): Player uses its own `max_hp = 100`, `move_speed = 180` defaults. Game playable but no character identity.
- **If CharacterBase has `max_health = 0`**: Player's max_hp = 0 → immediate death on first damage. Should be clamped on character-select panel (no validated character ships with 0 hp). Defensive: Player.tscn fallback (100) doesn't trigger because CharacterBase is present.
- **If `initial_weapon_id` doesn't match any of Player's 6 weapons**: no weapons enabled at spawn → Player is defenseless. Should be caught by character-select validation. Tracked as OQ-2.
- **If `_get_allowed_upgrade_ids()` returns empty list**: upgrade pool is unfiltered (all show). This is the default `_get_allowed_upgrade_ids()` returning `[]` — correct behavior.
- **If `_get_allowed_upgrade_ids()` returns list with no overlap to current pool**: panel shows 0 options. Soft-lock. Should validate against current pool state.
- **If a character switches mid-run** (impossible in v0.4 — locked at spawn): would orphan the previous character's state. Edge case prevented by run-lifecycle design.
- **If ActiveSkillCharacter is loaded but no skills are registered**: `_skill_cooldowns` array exists but all `_skill_unlocked = false`. `cast_skill(slot)` always returns false. Acceptable — skills unlock via Level Up GDD's skill-choice queue.
- **If `cast_skill(slot)` is called outside ActiveSkillCharacter subclass** (e.g. 修行者 receives key 1 press): Player checks `if _character_base is ActiveSkillCharacter` before routing. 修行者 ignores 1-4 key presses gracefully.
- **If Sun Wukong v2 reaches Lv20 (all 4 skills at max)**: skill-choice queue's `get_skill_choices()` returns empty; Level Up panel skips skill choices. Regular upgrade panel still works.
- **If `energy_bar_config` is malformed** (missing keys): HUD should defensively check `dict.has("max_value")` etc. before reading. Defensive code in HUD GDD.

## Dependencies

| Dependency | Type | Direction | Interface |
|---|---|---|---|
| **Player** (C-01, Approved) | Hard | Bidirectional | Player owns CharacterBase as scene child; reads its fields |
| **Weapon System** (FT-03, Approved) | Hard | CharacterBase → Weapon | `initial_weapon_id` enables a specific weapon at spawn |
| **Resource Data Framework** (F-02, Approved) | Soft (partial) | CharacterBase is Node, not Resource | OQ-1 tracks migration to Resource for `.tres`-per-character |
| **Active Skills** (FT-07, future) | Hard | ActiveSkillCharacter ↔ Active Skills | 4 cooldown slots; `cast_skill(slot)` API |
| **Level Up & Upgrade Pool** (FT-05, Approved) | Hard | CharacterBase → Level Up | `_get_allowed_upgrade_ids()` filter; skill-choice queue for ActiveSkillCharacter |
| **Combat** (C-03, Approved) | Soft | CharacterBase → Combat | `_on_kill(enemy)` + `_on_damaged(amount)` hooks |
| **Elements** (FT-11, future v0.5+) | Soft | CharacterBase → Elements | `element` field for damage-modifier pipeline |
| **HUD** (P-01, future) | Soft | ActiveSkillCharacter → HUD | `skill_cooldown_changed` for 4 cooldown UI indicators |

**Bidirectional check:**
- Player GDD lists CharacterBase as Hard dependency (override at spawn) ✅
- Weapon System GDD references `initial_weapon_id` ✅
- Level Up GDD lists CharacterBase filter as upgrade-pool input ✅
- ADR-0003 is the foundational decision driving ActiveSkillCharacter ✅

## Tuning Knobs

| Knob | Owner | Design-safe range | Default | Effect at extremes |
|---|---|---|---|---|
| `CharacterBase.max_health` | Per-character config (Player.tscn embedded) | 30 – 200 | 100 (修行者), other characters TBD | Lowers TTK Player survival budget |
| `CharacterBase.move_speed` | Per-character config | 100 – 300 | 180 (修行者), 200 (default) | Fox Spirit's 132 is hard-outrun threshold |
| `CharacterBase.pickup_radius` | Per-character config | 30 – 120 | 50 (修行者) | Base for Player GDD Formula 5 |
| `CharacterBase.initial_weapon_id` | Per-character config | enum (talisman / flying_sword / etc.) | "talisman" (修行者) | Defines opening DPS profile |
| `CharacterBase.energy_bar_config.max_value` | Per-character (only if has energy bar) | 10 – 100 | varies | Lower = faster trigger, higher = rarer |
| `CharacterBase.element` | Per-character (v0.5+) | enum (neutral / metal / wood / water / fire / earth) | "neutral" | Activates Combat Formula 1 element_modifier slot |
| `ActiveSkillCharacter.max_cd` (per slot) | Per-character (only Sun Wukong v2) | 3 – 30s | per skill | Lower = spammy, higher = cinematic |
| Number of characters in roster | Hardcoded (CharacterSelectPanel) | 1 – 8 typical | 2 (v0.4) | More = decision fatigue at select |

## Acceptance Criteria

**AC-01** **GIVEN** Player.tscn instantiation with CharacterBase as child (修行者: max_health=100, move_speed=180, pickup_radius=50, initial_weapon_id="talisman"), **WHEN** scene loads, **THEN** Player.max_hp = 100 AND Player.move_speed = 180 AND only Talisman weapon is enabled (other 5 weapons disabled).

**AC-02** **GIVEN** CharacterBase with `_get_allowed_upgrade_ids()` returning empty list, **WHEN** Level Up panel queries, **THEN** all upgrades from base pool are visible (no filter).

**AC-03** **GIVEN** an ActiveSkillCharacter subclass (Sun Wukong v2) AND skill slot 0 is unlocked AND `_skill_cooldowns[0] = 0.0`, **WHEN** `cast_skill(0)` is called, **THEN** `_on_cast_skill(0)` runs AND `_skill_cooldowns[0] = max_cd` AND `skill_cooldown_changed(0, max_cd, max_cd, true)` emits AND returns true.

**AC-04** **GIVEN** ActiveSkillCharacter with `_skill_unlocked[1] = false`, **WHEN** `cast_skill(1)` is called, **THEN** returns false AND no cooldown change AND no signal emit.

**AC-05** **GIVEN** ActiveSkillCharacter with `_skill_cooldowns[2] = 0.5` (still on cooldown), **WHEN** `cast_skill(2)` is called, **THEN** returns false AND no skill activation.

**AC-06** **GIVEN** ActiveSkillCharacter with all 4 slots on cooldown, **WHEN** the run advances 1.0s (20 frames at `delta=0.05`), **THEN** each cooldown decrements by 1.0 total AND `skill_cooldown_changed` fires **~4 times** (≈once per slot, on its integer-second crossing) — NOT 80 times. Throttled emit per ADR-0003 / `skill_cooldown_emit_throttle_test.gd`.

**AC-07** **GIVEN** a CharacterBase (not ActiveSkillCharacter subclass) AND key 1 is pressed, **WHEN** Player routes input, **THEN** `cast_skill` is NOT called (Player checks `is ActiveSkillCharacter` first) AND no error.

**AC-08** **GIVEN** Player kills an enemy, **WHEN** Combat fires `died(enemy)`, **THEN** CharacterBase `_on_kill(enemy)` is called (subclass override may build energy or do nothing for 修行者).

**AC-09** **GIVEN** Player takes 10 damage, **WHEN** Combat fires `damage_taken(...)`, **THEN** CharacterBase `_on_damaged(10)` is called (subclass override may build resource for future 哪吒 etc.).

**AC-10** **GIVEN** Sun Wukong v2 reaches Player Level 5, **WHEN** Level Up queue processes, **THEN** `_pending_skill_choices` activates AND `ActiveSkillCharacter.get_skill_choices()` returns 3 skill options (per Level Up GDD AC-07).

**AC-11** **GIVEN** CharacterBase.element = "neutral" (v0.4 all), **WHEN** Combat Formula 1 applies, **THEN** `element_modifier = 1.0` (no effect).

## Open Questions

- **OQ-1** (Migrate CharacterBase to Resource for `.tres`-per-character — Pillar 4 compliance): CharacterBase currently extends Node (not Resource). Per Resource Data Framework GDD compliance audit, this is "PARTIAL". The future 6-character roster cannot scale as Node-embedded class subclasses — every new character would need a `class_name X extends CharacterBase` script. **Resolution candidate**: convert CharacterBase to `class_name CharacterBase extends Resource`; create `resources/characters/cultivator.tres`, `sun_wukong.tres`, etc. Behavior hooks (_on_kill, _on_damaged) move to a separate `CharacterBehavior` Resource subclass referenced from CharacterBase. **Owner**: lead-programmer + systems-designer. **Estimated cost**: 3-5 hours refactor + 2 character migrations. **Target**: before adding 哪吒 / 杨戬 (v0.5+).
- **OQ-2** (Validate `initial_weapon_id` at character-select): currently no validation that `initial_weapon_id` matches an existing weapon child of Player. Misconfig = no weapons at spawn = defenseless Player. **Resolution candidate**: add validation in CharacterSelectPanel `_select_character` — verify the chosen character's `initial_weapon_id` exists in Player's weapon roster; show error if not. **Owner**: lead-programmer + qa-lead. **Target**: pre-release polish.
- **OQ-3** (Energy bar mechanic for non-active-skill characters): the design 02_CHARACTER_DESIGN.md describes 哪吒 (三昧真火 build-on-damage), 杨戬 (天眼槽 manual-hold), 女娲 (五色轮 5-element cycle), 盘古 (开天力 channel-and-burst) — all need energy bars + special triggers. v0.4 only Sun Wukong's "cooldown-bar" UI exists (per ActiveSkillCharacter). When 哪吒+ are coded, where does energy-bar HUD logic live? **Resolution candidate**: extend CharacterBase with `energy_max_value`, `energy_current_value` fields + `energy_gained(amount)`, `energy_consumed(amount)` signals; HUD subscribes. Each character subclass overrides accumulation logic. **Owner**: ux-designer + systems-designer. **Target**: when 哪吒 GDD is written.
- **OQ-4** (Character-select panel UI design): v0.4 panel shows 2 buttons (修行者 + 弼马温). When all 6 characters are coded, panel becomes 6 options — UI needs to scale (grid? carousel?). **Resolution candidate**: when 4th character ships, redesign panel as 2x3 grid with character preview images. **Owner**: ux-designer. **Target**: post-MVP.
- **OQ-5** (CharacterBase.move_speed default 200 vs 修行者 actual 180): the class default in `character_base.gd` is `move_speed = 200`, but Player.tscn's embedded 修行者 CharacterBase overrides to 180. Per Player GDD R-2 finding. Tracked. **Resolution candidate**: align the class default to the shipping 修行者 value (180), since 修行者 is the canonical baseline character. **Owner**: lead-programmer.

## Registry Updates Recorded

**Cross-doc consistency**:
- 修行者 (cultivator) CharacterBase config: max_health=100, move_speed=180 (Player.tscn override), pickup_radius=50, initial_weapon_id="talisman", energy_bar_config={}, element="neutral" — register in entities.yaml as constants if cross-doc references emerge
- 弼马温 (Sun Wukong v2): ActiveSkillCharacter subclass; 4 skill slots; per ADR-0003

## Revision Log

| Revision | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass from `character_base.gd` (114 lines) + `active_skill_character.gd` (130 lines) + 02_CHARACTER_DESIGN.md + ADR-0003 + SUN_WUKONG_V2_DESIGN.md. 8 required CCGS sections + Open Questions + Registry. Documents two-tier class hierarchy (CharacterBase / ActiveSkillCharacter), 6-character planned roster (2 implemented + 4 designed-only), 4 behavior hooks (_on_energy_full, _get_allowed_upgrade_ids, _on_kill, _on_damaged), 4-slot cooldown state for ActiveSkillCharacter, energy_bar_config dict pattern, element field for v0.5+ Elements GDD. 11 ACs. 5 OQs: Resource migration (OQ-1, same as Resource Data audit + Player OQ-6 family), initial_weapon_id validation (OQ-2), energy-bar HUD for non-active-skill characters (OQ-3), UI scaling at 6-character roster (OQ-4), move_speed default divergence (OQ-5, same as Player R-2). |
