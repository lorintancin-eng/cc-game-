# Asset Manifest

> Last updated: 2026-06-06

## Progress Summary

| Total | Needed | In Progress | Done | Approved |
|-------|--------|-------------|------|----------|
| 12 | 3 | 7 | 0 | 0 |

> **FORM CORRECTION (2026-06-06)**: the game is 100% procedural (no PNG pipeline) — these
> assets ship as **procedural GDScript** (glyphs / `_draw` / `GPUParticles2D` / theme), not
> sprite PNGs. See the spec's FORM CORRECTION callout. Status legend below:
> **Needed** = not started · **Glyph done** = text/headless form shipped, colour-fill enhancement screenshot-gated.

## Assets by Context

### System: Five Phases Combo Feedback
Spec file: `design/assets/specs/five-phases-combo-feedback-assets.md` · Source: `design/gdd/elements-five-phases.md`
**Gate**: VFX (001–005, 012) produce after the feel-playtest sign-off (`production/qa/five-phases-playtest-checklist.md`).

| Asset ID | Name | Category | Status | Notes |
|----------|------|----------|--------|-------|
| ASSET-001 | 燎原 Wildfire Burst | VFX | Needed | 木生火 · waits on Story 006 mechanic |
| ASSET-002 | 熔岩甲 Molten Ring + Break | VFX | Needed | 火生土 (Story 007 ✓) · `GPUParticles2D`/`_draw` |
| ASSET-003 | 矿脉精粹 Crit Flash + Pierce Shine | VFX | Needed | 土生金 (Story 008 ✓) · `GPUParticles2D`/`_draw` |
| ASSET-004 | 寒露凝锋 Frost Overlay + Hit Burst | VFX | Needed | 金生水 (Story 009 ✓) · `GPUParticles2D`/`_draw` |
| ASSET-005 | 春生回元 Leaf Drift | VFX | Needed | 水生木 (Story 010 ✓) · `GPUParticles2D`/`_draw` |
| ASSET-006 | 金 Metal element icon | UI Icon | Glyph done | `【金】` in LevelUp label (`_compose_option_text`); `#F5EBC8` colour-fill screenshot-gated |
| ASSET-007 | 木 Wood element icon | UI Icon | Glyph done | `【木】`; `#5A965A` colour-fill screenshot-gated |
| ASSET-008 | 水 Water element icon | UI Icon | Glyph done | `【水】`; `#3C82B4` colour-fill (≠ 鬼火青) screenshot-gated |
| ASSET-009 | 火 Fire element icon | UI Icon | Glyph done | `【火】`; `#DC5032` colour-fill (≠ 朱砂红) screenshot-gated |
| ASSET-010 | 土 Earth element icon | UI Icon | Glyph done | `【土】`; `#AA8246` colour-fill (≠ 旧纸黄) screenshot-gated |
| ASSET-011 | 相生! Proximity Hint | UI | Glyph done | `✦ 相生 · 触发连携` line + gold modulate (Story 011 UI half); border-glow polish screenshot-gated |
| ASSET-012 | Combo-Activation Banner | UI | Glyph done | `ComboBanner` (`scripts/ui/combo_banner.gd`) flashes `相生 · 金生水 · 寒露凝锋` on activation, HUD-hosted; font/placement/anim-timing screenshot-gated |

## Element sub-palette (Art Bible §4.3 — authoritative for all element assets)
金 `#F5EBC8` · 木 `#5A965A` · 水 `#3C82B4` · 火 `#DC5032` · 土 `#AA8246`
⚠ 水蓝 `#3C82B4` ≠ 鬼火青 `#5078B4` (XP bar) · 火红 `#DC5032` ≠ 朱砂红 `#C83232` (HP/Boss) · 土 `#AA8246` ≠ 旧纸黄 `#D2C3A5`
