# 五行相生 Playtest Checklist (修行者) — 2026-06-06

> **Purpose**: the Stage-0 feel-gate before combo VFX art begins. Each combo's per-frame
> VFX is still pending, so still judge **strength/feel by behaviour/numbers**. BUT combos
> are no longer invisible at the **activation** moment: a gold **banner** now flashes
> `相生 · 金生水 · 寒露凝锋` the first time each pair activates (ComboBanner, HUD-hosted),
> and each upgrade option shows its **element glyph** `【火】` + a `✦ 相生 · 触发连携` hint
> when the pick would trigger a combo. So you can now **see WHICH combo fired and WHEN** —
> judge only its ongoing strength by feel.
>
> **Run as 修行者** (the only character with a ComboManager wired). You start with
> 符箓 (Talisman) → **fire = 1** seeded at run start.

## How elements are gained (to trigger combos fast)
| Element | Fastest source |
|---|---|
| 火 fire | start (符箓) ✓ already 1 · 爆裂符 / 符箓 upgrades |
| 木 wood | **any attribute upgrade** (气血上限 / 身法 / 摄取 / 修为) — wood has NO weapon |
| 金 metal | unlock 飞剑 + 飞剑 upgrades |
| 水 water | unlock 雷法 + 雷法 upgrades |
| 土 earth | unlock 八卦阵 / 山印 + their upgrades |

## Per-combo: how to trigger + what to feel-check

### 1. 水生木 春生回元 (water + wood) — easiest to feel
- **Trigger**: unlock 雷法 (water) + take any attribute upgrade (wood).
- **Feel-check**: HP bar **creeps up** between fights (+2 HP / 4s, even while taking damage); levels come faster (+15% XP). Take more attribute upgrades → regen scales up.
- [ ] HP visibly recovers when not in heavy combat
- [ ] Leveling feels a touch faster

### 2. 火生土 熔岩甲 (fire + earth) — survivability
- **Trigger**: unlock 八卦阵 or 山印 (earth). fire already = 1.
- **Feel-check**: a damage **buffer** — first hits chip a shield (15 HP) before your HP; after ~2s without damage the shield **regenerates**. You should survive a burst you'd normally not.
- [ ] First hits after activation don't drop HP (shield absorbs)
- [ ] Shield comes back after a few seconds of not being hit

### 3. 金生水 寒露凝锋 (metal + water) — crowd control
- **Trigger**: unlock 飞剑 (metal) + 雷法 (water).
- **Feel-check**: enemies you hit **visibly decelerate** (move_speed ×0.7 for 1.5s). With 雷法's multi-target + 飞剑, whole clumps should slow. Pressure curve eases.
- [ ] Hit enemies move noticeably slower
- [ ] A swarm becomes more manageable after you start hitting it

### 4. 土生金 矿脉精粹 (earth + metal) — offense
- **Trigger**: unlock an earth weapon (八卦阵/山印) + 飞剑 (metal).
- **Feel-check**: 飞剑 **pierces 1 more enemy** (hits 4 instead of 3); occasional **crit** spikes (×1.5) on any weapon; 八卦阵 ticks +15%. More earth/metal → higher crit rate.
- [ ] 飞剑 passes through an extra enemy
- [ ] Occasional damage spikes (crits) — watch a single enemy's HP

### 5. 木生火 燎原 (wood + fire) — ⏸️ NOT YET IMPLEMENTED
- Story 006 — chain burst on fire-weapon kills. **Will NOT fire this build** (mechanics pending the DPS playtest gate). Skip; noted for awareness.

## Cross-cutting feel checks
- [ ] **相克 (Story 005)**: 飞剑(金) vs 纸人(木) hits harder (×1.3); vs 鬼火(火) softer (×0.8). Subtle — watch damage numbers if visible, or kill speed.
- [ ] **Build intent**: did picking complementary elements feel meaningful (vs "biggest number")? This is the core pillar test.
- [ ] **Activation cadence**: combos activate ~once per few level-ups — does it feel like a payoff moment (even without VFX)?
- [ ] **No crashes / console errors** during a full run (check the debugger panel).

## Verdict (fill after the run)
- Overall feel: ☐ good → green-light combo VFX art · ☐ needs tuning: ______________
- Any combo that felt off (too weak/strong/unnoticeable): ______________
- The "unnoticeable" ones are the strongest argument for which VFX matters most.

> **After this passes** → combo VFX + element-icon/hint art (specs being authored in parallel via /asset-spec).
