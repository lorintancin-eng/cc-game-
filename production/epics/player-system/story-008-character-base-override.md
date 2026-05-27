# Story 008: CharacterBase Override + Initial Weapon Unlock

> **Epic**: Player System | **Status**: Ready | **Layer**: Core | **Type**: Integration | **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-25.1 | **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/player-system.md` + `design/gdd/character-system.md`
**Requirement**: TR-core-001 (CharacterBase as Resource-as-Node override at character select)
**ADR Governing Implementation**: ADR-0001 + ADR-0003. **Engine**: Godot 4.6 | **Risk**: MEDIUM (Character System GDD's CharacterBase pattern is partially compliant with Pillar 4 — see Resource Data Framework r0 audit).

**Control Manifest Rules (Feature Layer)**:
- Required: Sun Wukong is the only character with active skills (ADR-0003); other characters must remain fully auto-battle
- Required: Upgrade pool filtered by current character (TR-wpn-003)

---

## Acceptance Criteria

- [ ] **AC-16**: Player.tscn default `max_hp = 100` → CharacterBase Resource with `max_health = 80` attached at character-select → Player's effective `max_hp` = 80 AND first `health_changed` emit reports `(80, 80)`
- [ ] **AC-17**: Player with `CharacterBase.initial_weapon_id = "talisman"` → run starts → Talisman child enabled AND other 5 weapons (FlyingSword/ThunderLaw/BaguaArray/ExplosiveTalisman/MountainSeal) DISABLED

## Implementation Notes

Per Player GDD Core Rule 5 + Character System GDD:
```gdscript
@export var max_hp: float = 100.0  # default; CharacterBase overrides
@export var move_speed: float = 180.0  # default

var character_base: CharacterBase = null

func attach_character_base(base: CharacterBase) -> void:
    character_base = base
    # Override stats per Core Rule 5
    max_hp = base.max_health
    current_hp = base.max_health
    move_speed = base.move_speed
    # initial_weapon_id triggers per-weapon unlock
    for weapon_node in [$TalismanWeapon, $FlyingSwordWeapon, $ThunderLawWeapon,
                          $BaguaArrayWeapon, $ExplosiveTalismanWeapon, $MountainSealWeapon]:
        weapon_node.set_unlocked(false)
    var initial_weapon := get_node_or_null(_weapon_path_for_id(base.initial_weapon_id))
    if initial_weapon:
        initial_weapon.set_unlocked(true)
    # Element field for future 五行 (Elements GDD v0.5+)
    # element = base.element  # reserved

    health_changed.emit(current_hp, max_hp)  # AC-16: first emit reports post-override values

func _weapon_path_for_id(weapon_id: StringName) -> NodePath:
    match weapon_id:
        &"talisman": return ^"TalismanWeapon"
        &"flying_sword": return ^"FlyingSwordWeapon"
        &"thunder_law": return ^"ThunderLawWeapon"
        # ... etc
        _: return NodePath("")
```

**Note on ADR-0003**: If `character_base is ActiveSkillCharacter` (e.g. Sun Wukong), additional `_input(event)` routing for skill_1..4 keys is required — but that's the Active Skills epic's concern. Player just exposes a hook for it.

**Out-of-scope finding (Character System GDD r0 audit)**: CharacterBase is a Node-extending class with @export fields, NOT a Resource per Pillar 4. Tech debt — out of scope for this story; this story implements what the code ships.

## Out of Scope

- ActiveSkillCharacter input routing (Active Skills epic)
- CharacterBase Resource refactor (Resource Data Framework epic tech debt)
- 五行 element field consumption (Elements epic — v0.5+)
- CharacterSelectPanel UI (Menu System epic)

## QA Test Cases

**AC-16**: max_hp override
- Given: Player.tscn loaded with default `max_hp = 100, current_hp = 100`; CharacterBase mock with `max_health = 80`
- When: `attach_character_base(mock_base)` called at character-select time
- Then: `max_hp == 80` AND `current_hp == 80` AND `health_changed.emit(80, 80)` fired once
- Edge: max_health = 0 (defensive) → defensive clamp at 1; CharacterBase not attached → defaults remain (dev/debug scene support per Edge Case)

**AC-17**: initial_weapon_id enables only one weapon
- Given: Player with all 6 weapon child nodes; CharacterBase with `initial_weapon_id = "talisman"`
- When: `attach_character_base(mock_base)` called
- Then: `$TalismanWeapon._unlocked == true` AND `$FlyingSwordWeapon._unlocked == false` AND `$ThunderLawWeapon._unlocked == false` AND `$BaguaArrayWeapon._unlocked == false` AND `$ExplosiveTalismanWeapon._unlocked == false` AND `$MountainSealWeapon._unlocked == false`
- Edge: initial_weapon_id = "" or invalid → no weapon enabled (Player has 0 attacks until first unlock upgrade); 弼马温 with initial_weapon_id = "jingu_bang" → JinguBangV2 enabled (per Sun Wukong v2 design)

**Sun Wukong (ActiveSkillCharacter) integration smoke**:
- Given: SunWukongV2 CharacterBase instance (subclass of ActiveSkillCharacter)
- When: `attach_character_base(wukong_base)` called
- Then: `character_base is ActiveSkillCharacter == true` AND Player's `_input(event)` handler routes keys 1-4 to `cast_skill(0..3)` (verified via Active Skills epic Story 001)

## Test Evidence
**Required**: `tests/integration/player/character_base_override_test.gd` — must exist and pass
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 002 (HP signal), Story 005 (weapon unlock mechanism)
- Unlocks: CharacterSelectPanel + ActiveSkillCharacter wiring
