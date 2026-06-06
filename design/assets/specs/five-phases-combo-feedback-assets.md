# Asset Specs — System: Five Phases Combo Feedback

> **Source**: `design/gdd/elements-five-phases.md` (Stories 007–012, mechanics locked + in main)
> **Art Bible**: `design/art/art-bible.md` (esp. §3 Shape Language, §4.3 五行色 sub-palette, §7 UI, §8 Asset Standards)
> **Generated**: 2026-06-06 (via /asset-spec, art-director pass)
> **Status**: 12 assets specced / 0 approved / 0 in production / 0 done
>
> **Gate**: these are the deferred *visual half* of the Five Phases combos. The mechanics
> are live + tested in main, but production of these assets should follow a **feel-playtest
> sign-off** (`production/qa/five-phases-playtest-checklist.md`) so VFX timing/intensity
> matches the final mechanic feel.

> ### ⚠ FORM CORRECTION (2026-06-06) — procedural GDScript, NOT PNG sprites
> The §8 Asset-Standards format (PNG atlas) below is the Art Bible's **generic** standard.
> The **as-built game is 100% procedural** — there is no `assets/` dir, no sprite pipeline;
> player/enemy silhouettes, bars, and HUD are all Godot primitives (Polygon2D / `_draw` /
> theme StyleBoxes / `GPUParticles2D`). So these assets are produced as **procedural GDScript**,
> not exported PNGs:
> - **Element icons (ASSET-006…010)** → render as an **element glyph tag** (`【火】`/`【金】`…)
>   in the LevelUp option label — **DONE** in `level_up_panel.gd` (`_compose_option_text`).
>   Glyph + text carry the meaning (headless- and colour-blind-safe); the per-element **colour
>   fill** (the hexes in the table above) is the remaining *enhancement*, applied via a runtime
>   theme StyleBox once a screenshot sign-off confirms the look. No PNG needed.
> - **相生 hint (ASSET-011)** → a text hint line (`✦ 相生 · 触发连携`) + warm-gold `modulate` on
>   the triggering option — **DONE** in the same method. Border-glow polish is screenshot-gated.
> - **Combo VFX (ASSET-001…005)** + **banner (ASSET-012)** → to be built as `GPUParticles2D` /
>   `_draw` / a runtime `CanvasLayer` Label, anchored to the hexes above — NOT sprite sheets.
>
> **Tooling note**: the `nano-banana` AI-image CLI is **not installed** in this environment, and
> would be the wrong tool regardless (AI raster ≠ this game's procedural vocabulary). "Production"
> of these = **content-session GDScript** (this session's lane), not an image-gen / PNG-export pass.

## Resolved Five Phases element sub-palette (Art Bible §4.3 — already sanctioned)
The element colors are a **designed second tier**, distinct from the semantic 主调板. There is
no palette conflict — §4.3 authorizes them. Every icon + VFX below anchors to these exact hexes:

| Element | Hex | Character | Must NOT be confused with |
|---|---|---|---|
| 金 Metal | `#F5EBC8` | 新铸白金 / 刀锋冷月光 | 主调·金黄 `#DCB450` (rarity/elite edge-light) |
| 木 Wood | `#5A965A` | 活物质感 / 竹在风中 | — (no world color is green; reads as elemental signal) |
| 水 Water | `#3C82B4` | 月光下的河面 | **主调·鬼火青 `#5078B4`** (XP/修为 bar) — ~10° hue / ~8% sat apart |
| 火 Fire | `#DC5032` | 更橙更亮的灼热感 | 主调·朱砂红 `#C83232` (HP bar / Boss 边光) |
| 土 Earth | `#AA8246` | 土壤感 / 承重的山岩 | 主调·旧纸黄 `#D2C3A5` (§4.3 BANS 旧纸黄 in element VFX) |

**Fire priority rule (§4.3 执行规则)**: any fire-element VFX simultaneous with Boss 朱砂红 edge-light must reduce its global brightness/alpha so 朱砂红 keeps perceptual priority (applies to 燎原 during Boss phase).
**Background convention**: all VFX/icons render on world底色 黛黑 `#18161C`; 白闪 is excluded from the vocabulary (§2) — use dark, not white.

---

## ASSET-001 — 燎原 Wildfire Burst (VFX, 木生火)

| Field | Value |
|---|---|
| Category | VFX / Particles |
| Dimensions | 80×80px canvas, 6–8 frame sprite sheet (+ short chain-trail sheet) |
| Format | PNG → `atlas_vfx_particles.png` (1024²) |
| Naming | `vfx_wildfire_burst_loop.png` / `vfx_wildfire_chain_trail.png` |
| Budget (§8.6) | 60–80 particles, ≤50/system, 0.3–0.5s life; ≤3 burst instances (chain cap) |

**Visual**: Compact detonation of upward-spiraling embers at the kill point (40–80px radius by depth) — hot center `#DC5032` bleeding to ash-grey `#302D37` smoke wisps; chain shown as a 3–5 spark directional trail to the next target. Acute upward angles (§3.1 destruction geometry), area-constrained so the player silhouette keeps竖向 dominance. Burst flash 0.15s / trail 0.2s / smoke fade 0.4s.
**Gen prompt**: `Chinese ink-wash pixel sprite sheet, 水墨 fire-burst VFX, 6-8 frames 80x80px. Hot center #DC5032, mid-ring #C86420, outer ash smoke #302D37, transparent bg. Upward-angling ember shards radiating from center, asymmetric spiral, acute fragments; 3px edge trail particles (chain). Final frames: embers fall, grey smoke dissipates. Mood: paper igniting in wind, quick pop NOT large explosion. Negative: no rounded soft glow, no modern shine, no white core, no bloom, no characters.`
**Anchors**: §4.3 火红 (not 朱砂红) + 执行规则 (yield to Boss); §3.1 acute=destruction; §1 原则三 氛围层从属 (brief duration).

## ASSET-002 — 熔岩甲 Molten Ring + Break (VFX, 火生土)

| Field | Value |
|---|---|
| Category | VFX (AnimatedSprite2D, rotation-driven — not a particle system) |
| Dimensions | 96×96px, center-hollow ring frame + break-burst sub-sheet |
| Format | PNG → `atlas_vfx_particles.png` |
| Naming | `vfx_molten_ring_idle.png` / `vfx_molten_break_burst.png` |
| Budget | ring = 1 sprite (0 extra GPUParticles); break burst ≤20 particles, 0.3s |

**Visual**: Slow-rotating ring of 6–8 lava-stone arc segments (gaps make it read small) at ~1.5× character radius. Base earth-brown `#AA8246`, inner-edge molten cracks `#DC5032` (both pair elements visible). Depletion: segments darken toward `#302D37`, crack-glow narrows. Break (HP=0): all flash `#F0A060` 0.1s then scatter (4–6 debris, 0.3s) → faint smoke ring. Regen: crack-glow slow pulse (1.5s) at low intensity. 3–4 color tiers only (§6.2).
**Gen prompt**: `Chinese ink-wash pixel orbital shield ring, 96x96px center-hollow, single frame (rotated in-engine). 6-8 arc-segment stones in broken ring (~15% gaps), base #AA8246, inner molten cracks #DC5032, depleted darkens to #302D37. Rough stone outer edge, molten inner edge. 3-4 tiers. Mood: spinning wall of heated stone, NOT a magic circle. Break frame: segments flash #F0A060 then explode outward. Negative: no perfect circle, no bloom, no white, no shield bubble.`
**Anchors**: §4.3 土 base + 火红 cracks; §3.4 negative-space silhouette reading; §1 原则三 (low brightness keeps subordinate); §8.6 (sprite not particles).

## ASSET-003 — 矿脉精粹 Crit Flash + Pierce Shine (VFX, 土生金)

| Field | Value |
|---|---|
| Category | VFX (two sub-elements) |
| Dimensions | pierce shine 32×8px (1 frame); crit burst 48×48px (4 frames) |
| Format | PNG → `atlas_vfx_particles.png` |
| Naming | `vfx_ore_pierce_gleam.png` / `vfx_ore_crit_burst.png` |
| Budget | crit ≤6 particles 0.2s; pierce shine = 1 sprite frame |

**Visual**: **Pierce shine** — a 2–3px horizontal metal-white `#F5EBC8` glint across the projectile's leading edge on pass-through (0.06s), reads "sharp enough to keep going". **Crit flash** — on a crit proc: enemy silver silhouette flash (1 frame `#F5EBC8`) → 4–6 acute metal shards (`#F5EBC8`→`#AA8246` tips) scatter, 0.2s; crit damage number +25% font, `#F5EBC8`. Shards are 刃器 acute geometry (§3.3).
**Gen prompt**: `Chinese ink-wash pixel combat VFX. A) pierce gleam: 32x8px horizontal near-white #F5EBC8 strip fading to transparent at ends, sword-edge reflection. B) crit burst: 4-frame 48x48px — f1 silver silhouette flash #F5EBC8, f2-3 4-6 acute shards radiating, body #F5EBC8 tips toward #AA8246, f4 fade. Mood: precise blade finding its angle, restrained NOT flashy. Negative: no soft glow, no circular burst, no warm yellow, no rounded shards.`
**Anchors**: §4.3 金白 (sharpness register; NOT elite 金黄 §4.6 R4); §3.3 刃器 acute; §8.6 minimal particles.

## ASSET-004 — 寒露凝锋 Frost Overlay + Hit Burst (VFX, 金生水)

| Field | Value |
|---|---|
| Category | VFX (modulate overlay + hit burst) |
| Dimensions | overlay 64×64px (tiled/modulate over enemy); hit burst 48×48px 4 frames |
| Format | PNG → `atlas_vfx_particles.png` |
| Naming | `vfx_frost_overlay_tile.png` / `vfx_frost_hit_burst.png` |

**Visual**: Semi-transparent water-blue `#3C82B4` wash (~35% opacity) over the slowed enemy's silhouette (cooler + edge-brighter, does not replace its color) + 4–6 asymmetric frost crystals (3–5px, near-white `#C8DFF0`, NOT snowflake symmetry). On apply: 6–8 ice-spray particles upward/outward (0.25s). Fades over 0.3s on slow expiry. **Test**: at 35% the enemy's灰度 silhouette must stay fully readable (§1 原则三).
**Gen prompt**: `Chinese ink-wash pixel frost status overlay, 64x64px modulate-over-enemy. Blue wash #3C82B4 35% opacity + 4-6 asymmetric ice-splinter crystals #C8DFF0 (acute fragments, NOT snowflake). Separate 4-frame 48x48 hit burst: f1 center flash, f2-3 6-8 ice shards upward #3C82B4→#C8DFF0, f4 fade. Mood: trapped-in-ice, clinical NOT magical aura. Negative: no snowflake symmetry, no soft glow, no warm tones.`
**Anchors**: §4.3 水蓝 (NOT 鬼火青 §4.6 R4 — production risk, see top); §1 原则三 (silhouette readable under 35%); §3.1 acute ice = metal condensing.

## ASSET-005 — 春生回元 Leaf Drift (VFX, 水生木)

| Field | Value |
|---|---|
| Category | VFX (player-attached GPUParticles2D, idle between ticks) |
| Dimensions | 16×24px per frame, 4-frame leaf sheet |
| Format | PNG → `atlas_vfx_particles.png` |
| Naming | `vfx_vernal_leaf_drift.png` |
| Budget | ≤5 particles per 4s tick, 0.8s life, **0 active between ticks** |

**Visual**: On each 4s regen tick, 3–5 wood-green `#5A965A` leaf silhouettes (elongated ovals 2–4×6–8px, asymmetric bamboo/willow, single darker `#3D6E3D` vein, tilted 15–35°) drift up 20–30px and fade (0.8s). XP orbs in range get a faint 20% `#5A965A` tint. **No persistent aura** (would fight the player silhouette) — the quietest of the 5, by design (slow lifeline).
**Gen prompt**: `Chinese ink-wash botanical pixel particle, 16x24px 4-frame leaf. Green #5A965A body, #3D6E3D single vein, fade to transparent tip. Elongated asymmetric bamboo/willow leaf, tilted 15-35°, brushstroke quality. Drift up 1-2px/frame + fade + ±5° rotation. Mood: a single leaf drifting in still air, barely-there NOT a healing sparkle. Negative: no bright glow, no white sparks, no flowers, no symmetry, no magic circle.`
**Anchors**: §4.3 木绿; §1 原则三 (definitive test — invisible to inattentive eye); §3.2 organic curve = 生命力; §8.6 (parked idle between ticks).

## ASSET-006…010 — Five Element Icons (UI, 16×16px)

| Field | Value |
|---|---|
| Category | UI Icon |
| Dimensions | 16×16px (readable at 12×12 min) |
| Format | PNG → `atlas_ui_hud.png` (2048²) |
| Naming | `icon_element_{metal,wood,water,fire,earth}.png` |
| Style | §7.3 印章简化风 — bold ≥2px strokes, filled, negative space carries info, on 黛黑 `#18161C`; outline NOT 正圆/正六边形 (reserved) |

- **ASSET-006 金 Metal** `#F5EBC8`: vertical blade-rhombus (sharp top, broader base) + 1px guard notch upper-third. *Gen*: `16x16 seal icon, near-white #F5EBC8 vertical rhombus/blade on black #18161C, 1px guard notch, ≥2px strokes. Negative: no border frame, no gradient, no character glyph, no circle.`
- **ASSET-007 木 Wood** `#5A965A`: vertical bamboo stem (2px) with 2 node-bands at 1/3 & 2/3 + 2–3 diagonal 1px leaf hints. *Gen*: `16x16 seal icon, green #5A965A vertical bamboo stem on black, two horizontal node bands, 2-3 diagonal leaf lines. Negative: no leaf clusters, no tree, no glow.`
- **ASSET-008 水 Water** `#3C82B4`: 三水 radical — 3 stacked shallow S-strokes (short/mid/long, 2px), downward-widening negative space. *Gen*: `16x16 seal icon, sky-blue #3C82B4 three horizontal wave strokes (6/9/12px) on black, 三水 composition. Negative: no drop, no splash, no circle.`
- **ASSET-009 火 Fire** `#DC5032`: upward flame teardrop (acute top) + 2 flanking tongues at 20–25°, concave base waist. *Gen*: `16x16 seal icon, orange-red #DC5032 upward flame teardrop + 2 minor flanking flames on black, acute point, concave base. Use #DC5032 NOT #C83232. Negative: no circular base, no glow, no candle softness.`
- **ASSET-010 土 Earth** `#AA8246`: 山 radical — flat-topped central peak (blunt, NOT pointed) + 2 minor humps over a base stroke. *Gen*: `16x16 seal icon, yellow-brown #AA8246 mountain (flat-topped central peak + 2 humps + base stroke) on black. Use #AA8246 NOT #DCB450. Negative: no pointed peak, no warm gold, no texture detail.`

**Anchors**: §4.3 element sub-palette; §7.3 印章简化风 (12px readable); §4 intro (shape must disambiguate without color — flat-top 土 vs pointed 火).

## ASSET-011 — 相生! Proximity Hint (UI border + tooltip, runtime-rendered)

| Field | Value |
|---|---|
| Category | UI (runtime modulate on the card border node — no separate texture) |
| Dimensions | applies to the 128×192px (2:3) upgrade card |
| Naming | runtime; no asset file |

**Visual**: When taking a card would activate a NEW combo, the card gains a 2px outer border in the **would-activate element's** 五行 hex, **slow breathe** (1.2s, opacity 60→100→60 — readiness, NOT danger). Tooltip "激活 [combo name]" below the description in 思源宋体 12px (element hex), preceded by an 8×8 element icon. Card size/background unchanged — restraint preserves the 升级暂停 ritual庄严 (§2 状态二).
**Gen prompt** (mockup): `Chinese ink-wash upgrade card, vertical rounded-rect, body 旧纸黄 #D2C3A5 85%. Pulsing 2px outer border in target element hex (金#F5EBC8/木#5A965A/水#3C82B4/火#DC5032/土#AA8246), body static. Bottom tooltip 12px 宋体 element-color "激活[combo]" + 8x8 element icon. 128x192. Mood: candle lit in a manuscript margin, quiet readiness NOT achievement banner. Negative: no bloom, no bg color change, no size pulse, no celebration particles.`
**Anchors**: §2 状态二 (quiet breathe ≤ ritual rhythm); §3.3 决策对象=书页竖向; §7.5 C-05 (≤2px hover stroke); §4.6 R4 (五行色 in element context = sanctioned).

## ASSET-012 — Combo-Activation Banner (UI, CanvasLayer text — runtime)

| Field | Value |
|---|---|
| Category | UI (CanvasLayer Label — no texture beyond fonts) |
| Dimensions | full-width band, center screen, 1.5s |
| Naming | runtime; loads 汇文明朝体 |

**Visual**: On combo activation during the level-up pause: 2 centered lines for 1.5s — L1 combo name (e.g. "火生土") 汇文明朝体 28–32px in the **generating** element hex (`#DC5032`); L2 effect name (e.g. "熔岩甲") 18px in the **generated** element hex (`#AA8246`); thin `#18161C` 60% band behind for readability. Fade-in 0.2s (Ease-In, §7.4 典籍展开 — no scale), fade-out 0.4s from t=1.1s. Simultaneous: a full-screen element-color tint (`#DC5032` for 火生土) at **8–12% opacity, 0.3s** — a felt "world pulse", NOT 白闪 (§2 excludes white).
**Gen prompt** (mockup): `Chinese calligraphic 2-line banner, 水墨 ink-on-paper. Top "火生土" 汇文明朝体 #DC5032 ~30px, bottom "熔岩甲" #AA8246 ~18px, thin dark band #18161C 60% behind. Static t=0.3s state. Mood: a mythological inscription being revealed NOT a level-up popup. Negative: no particle burst, no scale-in, no border decoration, no text glow, no modern font.`
**Anchors**: §2 状态二 (during pause, 庄严 register); §7.2 汇文明朝体 = 神话命名层; §7.4 opacity-fade no-scale; §4.3 执行规则 (tint = 火红 not 朱砂红, 8–12% so no Boss conflict); §1 原则一 红光可读.

---

## Production notes
- **Atlases**: VFX → `atlas_vfx_particles.png` (1024²); icons → `atlas_ui_hud.png` (2048²) per §8.5.
- **⚠ Production risk**: 水蓝 `#3C82B4` (element) vs 鬼火青 `#5078B4` (XP/修为 bar) look alike to non-experts and co-exist on screen (frost overlay on enemies + XP bar in HUD). The handoff brief MUST name both values + their exclusive contexts.
- **Gate**: produce after the feel-playtest sign-off; VFX timing should match final mechanic feel (006 燎原 VFX waits for its mechanic).
