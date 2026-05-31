# Active Session State

> **Last Updated**: 2026-05-31 (自主实现全部完成：3 待办✅ + 背景✅ + 攻击✅ + 人物✅，233 测试全绿，未提交)

## 自主实现进度 (2026-05-31, 用户授权自主执行, 不提交)

**3 待办 ✅**:
- C-01/C-02 已同步 `08_UI_UX_GUIDE.md §4.1/§4.4`
- §8.7 Godot 4.4-4.6 导入器已核实（breaking-changes 无 2D 导入变更；确认 shader uniform Texture2D→Texture 补入 §8.8）

**① 背景模组 ✅ (227/227 测试绿)**:
- 新增 `scripts/system/background.gd`(class_name Background, CanvasLayer -100) + `scenes/system/Background.tscn`(黛黑底 ColorRect)
- `StageConfig` 加 `background_color`/`ambient_tint`/`ambient_tint_strength` 视觉字段
- `StageDirector` 加 `background` export + 兄弟回退 `_find_background()` + 在 `_apply_stage_config_values()` 应用
- `Main.tscn` 接入 Background + StageDirector.background 接线 + MovementReference 重整为暮云灰氛围层
- Stage1 蓝灰冷(0.16,0.19,0.28 @0.14) / Stage2 阴黄暖(0.30,0.25,0.16 @0.13) / 交易暖纸(0.34,0.30,0.22 @0.16, 不到金黄)
- 新测试 `tests/unit/system/stage_background_test.gd`(7 用例) — 验证黛黑主导 §4.6

**② 攻击模组 ✅ (233/233 测试绿)**: 6 武器 18 处颜色对齐 §4 五色语法 —
- 追魂符/爆裂符(符法)→朱砂红 #C83232；飞剑(剑修)→银白 blade/寒蓝 spine/去金护手；雷法→银电(银白+鬼火青#5078B4, 脱离纯青水色)；八卦阵(阵法,未见 .tscn 跳过)；山河印(法宝)→朱金(金黄环+朱砂印, 去绿)；爆炸→朱砂红环+暖白闪核
- 文件：TalismanProjectile/FlyingSwordProjectile/ExplosiveTalismanProjectile/ExplosiveImpact/ThunderStrike/MountainSealImpact .tscn
- 受击闪白(V01) 未做——属未建的 Combat Feedback 服务，记为后续

**③ 人物模组 ✅ (233/233 测试绿)**:
- 调色：修行者 body 青绿→黛灰 #3C3C46；孙悟空 body 橙→黑红 #3C1E1E(§4.1)；两者 HP 条 fill→朱砂红 #C83232，bg→黛黑(§4)
- 标志形状(§5.1)：修行者加铜铃 BellMark(金黄, Body 子节点)；孙悟空加金箍 Circlet(金黄 Line2D 椭圆环, Body 子节点) — 兼作黑红暗身的高对比定位锚(§5.2 第三层)
- idle 律动(§5.3)：新 `scripts/system/idle_bob.gd`(class_name IdleBob, ±1.5px/1.0s, 纯视觉不碰碰撞/移动) + 两场景 IdleBob 节点 targeting Body
- 新测试 `tests/unit/system/idle_bob_test.gd`(6 用例, sine 数学)

## 视觉验证说明
- 自动证据：233/233 GUT 测试绿（含 live Main.tscn 集成烟雾，证明所有改动场景加载无误）+ 背景混色/idle 数学逻辑测试
- 视觉保真（颜色/剪影外观）按测试标准属 ADVISORY「截图 + lead 签核」，headless 无法渲染——**待你运行游戏截图签核**
- 未新增 ADR：背景走现有 ADR-0004(StageConfig 数据驱动)，IdleBob 为 cosmetic 组件；如需正式 ADR 可后补
- **未提交**（全局规则，等你 review）

## Session Extract — Stage 2 testable foundation COMPLETE (2026-05-30 continuation)

**All headless-testable Stage 2 content + logic is built and CI-locked (172 tests, green).** What remains is live scene wiring that cannot be verified without the user's playtest.

### This continuation's commits (all CI-green)
| Commit | Step | Content | Tests |
|---|---|---|---|
| `fd723d2` | 6d | **StageTwoConfig** — assembles Stage 2 (幽都鬼市): waves of the 5 new enemies, Judge boss, demon_seal=null, trade_stall_config (r1 values). Mirrors StageOneConfig code-builder. | +8 (133) |
| `64629d6` | 6c-1 | **TradeFormulas** — Ghost Market trade math: Formula 1 (dmg + minf ceiling), 2 (HP cost 15/20/25), 3 (XP cost 60/80/110/150), 4 (demon_tide → DemonTideSpec) + Blood-Pact floor lock + market_unease. Single source of truth. | +20 (153) |
| `37a744f` | 6c-2 | **TradeStallState** — pure stall state machine (DORMANT→AVAILABLE→TRADING→SPENT/EXPIRED): warm-up / 25s linger / 1s hold-threshold (reset-on-move) / boss-suppress / decline-preserves-linger. Testable core, thin-shell pattern. | +19 (172) |
| `d9c1d2c` | 4·1a | **RunDirector** (config provider) — Stage 1→2 sequence + index + advance/run_completed signals + StageDirector optional `run_director` hook. | +9 (181) |
| `21d9232` | 4·1b | **Wire RunDirector into Main.tscn** — StageDirector pulls Stage 1 config from RunDirector. ✅ PLAYTEST PASS (user confirmed Stage 1 byte-identical 2026-05-30). | (181) |
| `8dfaf5f`,`21a1748` | 4·2a | **Transition building blocks** (additive, no live change): Player.heal(), EnemySpawner.clear_all_enemies(), StageDirector.reset_for_stage() + _clamp_stage_values() extraction + stage_advance_requested signal. | +13 (195) |
| `a00f673` | 4·2b | **LIVE Stage 1→2 transition** — _on_boss_died branches (has_next_stage → stage_advance_requested vs stage_cleared); RunDirector advances + reset_for_stage + heals +40%; Main.tscn wires stage_director. | +2 (197) |
| `9fd7b57` | tune | **3-min stages + 怪浪 + 1.5× XP** (user request): stage_duration 300→180, 4 waves (0/0:40/1:20/2:00), wave 3 = final-minute swarm (max 80/84 @ interval 0.3), demon-seal/elite/trade times rescaled, all 11 enemy XP ×~1.5. Tests synced. ⚠️ feel playtest-gated. Design docs now lag (propagate-change follow-up). | +1 (198) |
| `30a9344` | B·B1 | **Phase B start — Player Yin Debt (阴债) timed speed buff**: `apply_yin_debt_speed(bonus, duration)` + `_tick_yin_debt` + `_yin_debt_speed_bonus`/`_remaining` (separate from `_speed_multiplier` so transforms don't clash); _physics_process ticks + applies (bonus 0 = movement unchanged). 6 tests. | +6 (204) |

### 📋 PHASE B PLAN — Ghost Market Trade live wiring (in progress)
**Interface map** (from Explore agent, 2026-05-30): `_apply_upgrade(StringName)` reuses weapon/stat upgrades (damage upgrades are FLAT, not %); there's a `_damage_multiplier` field (line 85) Blood Pact can likely use (verify it's read by combat); pause pattern mirrors `scripts/ui/level_up_panel.gd` (CanvasLayer + PROCESS_MODE_WHEN_PAUSED + save/restore `get_tree().paused`); `_is_selecting_upgrade` flag gates input; player in group `"player"` (Player.tscn root). Costs/validation already in `TradeFormulas`; stall states in `TradeStallState`.

Remaining increments (each small + reversible; B3+ are LIVE / playtest-gated):
- **B1 ✅** Yin Debt timed speed buff (`30a9344`).
- **B3a ✅** (`2b264ab`) Player trade methods: begin/end_trade (pause), execute_blood_pact/soul_codex/yin_debt, _blood_pact_stacks, _owned_weapons. 6 tests.
- **B3b ✅** (`7c7ae57`) TradePanel UI (dumb presenter) + scene — 3 offers + Leave + 5s fuse.
- **B3c ✅** (`c5d5821`) TradeStall Area2D node + scene — wraps TradeStallState; body_entered + hold polling; 朱砂 glow + fill bar.
- **B3d ✅** (`35429f6`) StageDirector orchestration + Main.tscn wiring — spawns stalls, builds offers inline (TradeFormulas + player state), applies buffs, boss-suppress, market_unease. **⚠️ PLAYTEST-PENDING — the whole live loop.**
- **B4 ✅** (`5bff677`) demon tide on trade: `EnemySpawner.spawn_burst(count)` (current-pool burst) + `StageDirector.spawn_demon_tide(n, unease)` (TradeFormulas.demon_tide → normals burst + Impermanence elites, dead/stage-end guard). Wired in `_on_trade_offer_chosen`: Blood Pact/Soul Codex immediate, Yin Debt delayed ~13.5s via `_pending_tides` ticked in `_process`. Burst-only (sustained interval pressure = future). Live/playtest-gated.
- **Subsequent stages ✅** (`814ee90`) — user request "做后续关卡". `StageConfig.difficulty_multiplier` (scales wave count↑ + interval↓; 1.0=no-op) applied in `_apply_current_wave_config`. RunDirector sequence now 4 stages: Stage1, Stage2, 荒山·再临(×1.4), 鬼市·深渊(×1.7) → final victory. Easily extended/looped. Per-enemy stat + boss scaling = future.
- **B5 (remaining, LIVE)** HUD Trade-pause state (suppress low-HP overlay during panel) — minor polish.

### ✅ TRANSITION FIX (`ed03f4b`) — CONFIRMED by playtest
Transition worked (user reached 鬼市 + saw a stall). Fixed via sibling-lookup fallback (typed-NodePath @export didn't resolve on the instanced sub-scene). Console prints the path on stage end.

### 🔧 PLAYTEST FIXES + 鬼市 RESTRUCTURE (2026-05-30, user feedback)
- **Stall never opened** (`069e70b`): player+enemies share collision layer 1 → physical push → "stand still" hold broke under swarm. Fixed → presence-based hold (in-zone 1s, like DemonSeal) + `get_overlapping_bodies()` polling.
- **鬼市 → trade INTERLUDE** (`21b6452` R1 + `1df6268` R2, user request "打完每关先进鬼市再进下一关"): 鬼市 is no longer a combat stage — it's a calm trade interlude between combat stages.
  - `StageConfig.is_interlude`; StageDirector `_end_stage` refactor (boss death + interlude timeout share it); interlude disables passive spawning, auto-advances at stage_duration; boss-warning suppressed.
  - `GhostMarketInterludeConfig.build()` (25s, 3 early stalls, pool wave for tides, no boss/seal). StageTwoConfig stalls removed → 幽都 is a pure combat stage (判官).
  - **RunDirector sequence now 7 interleaved**: 荒山 → 鬼市间隙 → 幽都(判官) → 鬼市间隙 → 荒山·再临(×1.4) → 鬼市间隙 → 幽都·深渊(×1.7) → victory. CI **216 tests**.
  - ⚠️ PLAYTEST-PENDING: the interlude flow (calm room, stalls reachable, trade→tide, auto-advance to next combat stage).
- **B5 HUD trade-pause** still remaining (minor).

### 🅱️🅲️🅳️ AUTONOMOUS BATCH (2026-05-30, user: "BCD逐步完成，全权交由你做主")
- **B-1 ✅** (`a7e5225`) Soul Codex variety: `Player.pick_trade_upgrade()` (level-up-pool pick, D-B2-capped, bad-luck protection) → real weapon-aware offer, not the talisman placeholder.
- **B-2 ✅** (`0b8a178`) demon tide sustained pressure: initial burst + 2 half-size follow-up bursts over the window (interlude has no passive spawn, so the tide IS the threat). `_emit_tide_burst` extracted; `_pending_tides` entries unified to {remaining, normals, elites}.
- **B-3 ✅** (`25c14ac`) Blood Pact confirm: lightweight double-press on the destructive card (no new UI nodes).
- **B-5 MOOT** — no low-HP red-edge overlay exists in the code (GDD OQ-3 hypothetical never built); nothing to suppress.
- **C ✅** (`b270dd0`) per-stage enemy + boss STAT scaling (max_hp + damage, gentle ×0.5/×0.6 of the difficulty bump; sets the spawned node's public fields only — frozen enemy.gd untouched). Combined with wave-volume scaling, remix stages are genuinely harder.
- **D ✅** (`997c902`) design-doc sync (subagent, 5 files): ghost-market-trade.md → revision-2 (interlude reality), ADR-0004, stage-2-enemies, boss-system, systems-index — all dated, divergences marked [AS BUILT]/[简化], original intent preserved. Subagent flagged 2 code findings → task chips: Blood Pact 5× ceiling not enforced (MVP ×1.52 max, moot); Famine Beast 18-vs-36 damage (FamineBeast frozen — owner decision).
- **B-4 ✅** (`21cdfa4`) ALSO fixed a real BUG (interlude per-stage stall state wasn't reset → 2nd+ interludes spawned no stalls) + added interlude early-exit.
- **DEFERRED (noted, design calls):** B-4 interlude early-exit (tide-escape wrinkle — fixed 25s works for now); B-6 remove diagnostic prints (KEPT — they aid the pending playtest, low-noise, fire once per stage-end/trade); C-3 endless looping (kept finite 7-stage for a clear victory).

> **CI 216 tests green throughout.** Remaining playtest-pending: the full interlude loop + trade polish (Soul Codex variety, sustained tide, blood-pact confirm) + difficulty escalation feel.

### 🔧 PLAYTEST FIXES round 2 (2026-05-30/31, user feedback on the interlude)
- **Stalls never opened** (`eb1e4f0`): `trade_panel` typed-NodePath @export didn't resolve on the instanced StageDirector sub-scene (SAME quirk as run_director) → `_on_trade_requested` saw null + bounced the stall. Fix: `_find_trade_panel()` sibling lookup in _ready + _on_trade_requested.
- **鬼市 no time limit** (`5850d63`, user "鬼市不要有限时"): removed the 25s auto-advance. New **LeavePortal** (cyan exit gate spawned ~320px above the player) — stand in it ~0.6s to advance whenever ready. Interlude stage_duration → 600 (failsafe only); stall linger 20→300s. Also fixed a real bug: stalls/portal live under the spawn parent (not the EnemySpawner) so clear_all_enemies missed them → they persisted into the next combat stage; reset_for_stage now queue_frees them.
- ⚠️ KNOWN (noted, not yet fixed): HUD shows stale "妖王降临" status carried from the previous stage on transition; interlude HUD shows a "_ /10:00" countdown (cosmetic — no real limit). Both minor HUD-reset polish.

### 🧪 NEW CAPABILITY: local headless Godot 4.6 + LIVE integration smoke (2026-05-31, `0832d48`)
- Downloaded a working **Godot 4.6** headless binary to `/tmp/Godot_v4.6-stable_win64.exe` — I can now run the suites + scenes LOCALLY (not just CI). Interactive *play* still needs a human; headless logic/flow does not.
- **`tests/integration/interlude_flow_test.gd`** (4 tests, now in the CI integration suite): loads the REAL `scenes/Main.tscn` and drives the flow — verifies `run_director`/`trade_panel`/`stage_director` NodePath exports resolve, the boss-death→interlude transition fires, the interlude spawns its 3 stalls + LeavePortal, and no boss spawns. Catches the exact class of bug the `.new()`-based unit tests miss (the NodePath-bind failures we hit twice by playtest).
- It **immediately earned its keep**: caught that `run_director` was resolved only LAZILY (in `_end_stage`) — null for the whole stage until the boss died — while `trade_panel` resolved eagerly in `_ready`. Fixed: `run_director`'s sibling fallback is now eager in `_ready` too. Zero behaviour change to stage-1 config sourcing.
- **220 tests green** (216 unit + 4 integration), verified BOTH locally and in CI.
- 📌 Hygiene note (NOT done, debatable): the repo has no committed `.gd.uid` files (Godot 4.4+ regenerates them per import; CI works without them). Committing them is the Godot 4.4+ best practice for UID stability but is a separate, broader call — left for the user.

- **B2 (folded into B3d)** — offers built inline in StageDirector._build_trade_offers (no separate generator). Soul Codex MVP = talisman_damage placeholder; Blood Pact MVP = ×1.15 owned-weapon damage (not GDD Formula 1 additive-on-base yet).

(historical detailed B3 plan below:)
- **B3 (LIVE, the playable slice):**
  - `scripts/system/trade_stall.gd` + `scenes/system/TradeStall.tscn` — Area2D owning a `TradeStallState`; body_entered/exited + position polling for the 1s hold; visual glow + fill bar; emits `trade_opened/declined/expired`. Spawn-position like DemonSeal.
  - `scripts/ui/trade_panel.gd` + `scenes/ui/TradePanel.tscn` — mirror LevelUpPanel: 3 offer buttons (血契/魂典/阴债) + 离开 + fuse timer (5s auto-decline) + Blood Pact confirm step. Builds offers from TradeFormulas + player state; disabled offers shown greyed.
  - Player integration: `_is_in_trade` flag + pause save/restore (mirror `_is_selecting_upgrade`); apply buffs — Blood Pact (`max_hp -= TradeFormulas.blood_pact_max_hp_cost(n)`, clamp current_hp, `_damage_multiplier *= 1.15` or weapon boost), Soul Codex (`current_xp = spend_soul_codex_xp(...)` + `_apply_upgrade(weapon_id)`), Yin Debt (`apply_yin_debt_speed(0.2, 45)`).
  - StageDirector: spawn stalls at `trade_stall_config.stall_spawn_times`; connect `trade_completed` → tide; suppress during boss.
- **B4 (LIVE)** demon tide on trade: `EnemySpawner.spawn_burst(count, pool, weights)` + `StageDirector.spawn_demon_tide(trade_n, unease)` using `TradeFormulas.demon_tide` (+ death/stage-end guard); Yin Debt delayed ~13.5s.
- **B5 (LIVE)** HUD Trade-pause state (suppress low-HP overlay during panel).

⚠️ Blood Pact damage: simplest = `_damage_multiplier *= 1.15` if combat reads it (CHECK first via grep `_damage_multiplier`); else flat boost to owned weapons or reuse `_apply_upgrade(talisman_damage)`. Soul Codex weapon-unlock can reuse `_set_weapon_unlocked` + an unlock upgrade_id.

### ⛔ PHASE BOUNDARY — increment 2 (live transition) DONE, awaiting playtest
All CI-testable work DONE (197 tests). 1b PASS confirmed by playtest. **2b (the live Stage 1→2 transition) is committed but needs the user's playtest** — beating the Stage-1 boss (饕餮) should now advance INTO Stage 2 (幽都鬼市, new enemies + Judge) instead of showing victory, with a +40% heal; the victory screen should appear only after beating the Stage-2 Judge.

**If 2b PASS → Phase B (6c trade live wiring):** TradeStall Area2D node (wraps tested TradeStallState) + TradePanel UI + StageDirector demon-tide spawn (immediate + Yin Debt delayed) + Player `_is_in_trade`/pause/`_apply_upgrade`/max_hp + HUD Trade-pause state. Then the Stage-2 Judge becomes the run-victory (run_completed → final screen — currently stage_cleared already does this since Stage 2 is the last stage).

Build each in small reversible commits; user playtests each checkpoint. Stage 1 must stay PASS throughout (FamineBeast files remain zero-diff).

---


## Session Extract — Stage 2 content design COMPLETE (2026-05-29)
User: "开发计划和开发权限全部交给你...一直执行" (full delegation). Direction chosen: **new stage + enemies + boss**; sequential progression (one life to the bottom); hook = **鬼市交易 (Ghost Market Trade)**.

### Design artifacts (all committed + pushed, all pending /design-review in a fresh session)
| Doc | Commit | Content |
|---|---|---|
| `design/gdd/ghost-market-trade.md` | `72827f9` | Trade mechanic GDD (economy-designer + systems-designer). 3 trades (血契/魂典/阴债), demon-tide penalty, 5 formulas, 12 ACs, 13 knobs, 5 OQs. Blood Pact +8%/base, cap 3 = 4.99× ≤ 5× ceiling. |
| `design/gdd/stage-2-enemies.md` | `f3b2221` | 5 archetypes (灯笼鬼/怨婴/鬼差/镇墓兽/黑白无常), .tres-ready stats, tuned ~30-40% above Stage 1 for mid-game entry. |
| `design/gdd/boss-system.md` r2 | `e1725d4` | Ghost Market Judge (鬼市判官) — 480 HP, 勾魂锁链/判笔/生死簿召唤/审判终结. Resolves OQ-3 (BossBase refactor). |
| `docs/architecture/0004-multi-stage-stageconfig.md` | `b5036af` | StageConfig Resource + RunDirector. 6-step migration, golden-test-gated, Stage 1 byte-identical. Status: Proposed. |
| entities.yaml + systems-index | (in above) | + ghost_merchant_stall, ghost_market_judge, 5 enemies, 3 trade constants; system #26. |

### IMPLEMENTATION PLAN (ADR-0004 migration) — progress 2026-05-30
1. ✅ **DONE** (`b3fa3b4`) Resource classes (WaveConfig/EliteSpawnEvent/DemonSealConfig/StageConfig/TradeStallConfig).
2. ✅ **DONE** (`c75cafa`) Stage 1 config as DATA — `StageOneConfig.build()` (code builder, extracted verbatim from stage_director.gd) + 6-func validation test (pools/elites/demon-seal). Note: chose a code builder over hand-written `.tres` (can't run Godot locally to validate `.tres` format; `.tres` serialization is an editor follow-up). CI 110 tests.
2b. ✅ **DONE** (`6d3fc3c`) `StageConfig.get_active_wave()` data-driven wave selection + golden test pinning Stage-1 outputs at t=0/60/120/180/270 to the hardcoded constants (5 funcs). The selection logic + the whole Stage-1 config are now validated in ISOLATION (zero live-director change yet).
3. ✅ **DONE + PLAYTEST-VERIFIED** (`795a209`) StageDirector reads `stage_config` (default `StageOneConfig.build()`). User playtested Stage 1 → **PASS** (byte-identical live). Removed the 5 `_get_wave_*` fns + WAVE_*_START_TIME + archetype preloads + the 2 hardcoded elites; wave selection = `get_active_wave`, elites iterate `elite_events`. `pool.assign()` handles the typed-array conversion. The data-driven stage foundation is now LIVE-VERIFIED.

### Strategy after Stage-1 PASS: front-load headless-testable CONTENT, batch live-wiring for playtest
6a. ✅ **DONE** (`f253da7`) 5 Ghost Market enemy `.tres` (lantern_ghost/resentful_infant/ghost_bailiff/tomb_guardian/impermanence_elite) + load test (6 funcs, preload-validated). Caught + fixed a design-doc bug: Lantern Ghost wave_amplitude 24 → 0.6 (it's a unit-relative weave multiplier, not pixels). CI **116 tests**.
6b. ✅ **DONE** (`95ac762`) Ghost Market Judge boss — built STANDALONE (not BossBase), so FamineBeast/Enemy untouched (git-verified zero diff → Stage 1 boss zero regression). judge.tres + ghost_market_judge.gd (mirrors FamineBeast: 勾魂锁链 hook/判笔 brush/生死簿 summon/审判终结 enrage + brush radius ×1.2) + GhostMarketJudge.tscn (node-for-node mirror) + 9 tests. CI **125 tests**. BossBase DRY refactor (OQ-3) deferred until both bosses are a regression surface. ⚠️ live boss feel needs playtest when Stage 2 is reachable.
6c. ⏳ Trade system LOGIC (ghost-market-trade.md r1) — Blood Pact max-HP cost / Soul Codex / Yin Debt delayed tide / TradeStall state machine / market_unease / demon-tide selection. Mostly NEW code (low regression risk); pure logic is unit-testable. The TradeStall Area2D + TradePanel UI need live playtest.
6d. ⏳ StageTwoConfig (StageOneConfig-equivalent: 鬼市 wave pools + Judge boss + trade config) + load test.
4. ⏳ RunDirector + 5. sequencing — **⚠️ HIGH RISK + CI-UNTESTABLE live scene wiring** (Player-spawn/pause/GameOverPanel ownership move + Main.tscn restructure). Build in small reversible commits; the user playtests each. This is the LAST batch (ties the verified pieces together).

### ✅ ghost-market-trade.md — revision-1 COMPLETE (2026-05-29, commit b53ba32)
Two reviews (in-session 5-specialist + user's independent fresh-session) both → MAJOR REVISION. Independent review caught 3 the author missed (stale Formula 4 DPS / Blood Pact too-weak / auto-entry hijack). **All 10 blockers + key recommended addressed in revision-1** (systems-designer cascade per owner-locked decisions; claude audited). Owner decision OQ-2 = permanent max-HP reduction. Key fixes: Formula 1 structural clamp minf(…, base×5); 火眼金睛 honesty; Formula 4 recomputed (elite 0/0/1/1, Impermanence); Yin Debt delayed tide; hold-threshold entry; timed-pause fuse; tide-on-panel; n=global; market_unease FOMO; AC overhaul. Optional: re-review in fresh session for final Approve, or accept revision-1.
(historical) original verdict detail below:
- 🔴 **REAL BUG (cross-system)**: Formula 1's "≤5× ceiling" claim is FALSE. Blood Pact +8% interacts MULTIPLICATIVELY with Sun Wukong 火眼金睛 (crit slot 1.2-1.55×): worst case 39.92 × 1.55 = **7.74× over base** (breaks the 5× ceiling by 55%). Formula 1 only checked source_modifier, ignored the crit pipeline stage. Affects Combat, not just trades — bites once Blood Pact is implemented.
- 🔴 Pause-based panel kills the gambler fantasy + makes "always trade" the dominant line (fake choice). Root: pause chosen for impl convenience, fantasy written around it.
- 🔴 阴债 Yin Debt structurally dominant (its +20% speed buff self-negates its own demon-tide penalty).
- 🔴 Consequence opacity: panel doesn't show the tide it summons → blind bet, violates Pillar 1.
- 🔴 AC-06/07/09 untestable as written; F2/F3/F4 escalation + death-guard + D-B2-revalidation have ZERO ACs.
- **2 OWNER FORKS awaiting user**: (1) decision-moment feel — timed-pause [CD rec] / real-time / spatial / keep-paused; (2) make the tide a real cost — rebalance 阴债 + harsher tide [rec] / exempt tide from 4-attacker ceiling / both / accept-mild.
- **~80% are pure fixes** claude cascades once the forks settle: Formula 1 crit-slot fix, false-claim correction, Formula 4 clamp, AC rewrites + 5 new ACs, UX specs (disabled-reason / silent-expiry / confirm-step), n-index disambiguation, HP-floor window.
- Enemy roster + ADR-0004/StageConfig are largely independent of these trade forks; Stage 1 migration (impl steps 2-3) is trade-free and safe to advance meanwhile.

### ⚠️ Process note / recommendation
- The 3 new GDDs + boss r2 are **pending /design-review** (must be a FRESH session — cannot self-run). ADR-0004 is **Proposed** (recommend /architecture-review).
- Proceeding to implementation under delegated authority; steps 1-3 are golden-test-gated and keep Stage 1 identical, so low risk even pre-review.
- **Accumulated playtest-pending items** (from earlier): Story 008 aggregate-ceiling feel, D-B2 cap balance, + now all Stage 2 numbers.

### Test suite: 99 tests, CI green (last verified run 7bf3b39-era; weapon+balance coverage milestone).

---

## Session Extract — D-B2 upgrade stack cap implemented (2026-05-29)

## Session Extract — D-B2 upgrade stack cap implemented (2026-05-29)
- **Found + closed a real design-vs-code gap**: Level Up Pool GDD r2 specified a per-upgrade `max_stacks` cap (D-B2 resolution — prevents stacking past the Combat 5× ceiling) with exact values + mechanism, but `scripts/player/player.gd` never implemented it (no pick counter, no cap filter). Upgrades could be taken unlimited times.
- Implemented faithfully (commit `063da34`): `_upgrade_pick_count` dict (String-keyed) + `_get_upgrade_max_stacks(id)` suffix-categorized caps (damage 3 / pierce 2 / count 3 / cooldown 5 / unlock 1 / else 5) + `_get_upgrade_pool` filter before shuffle. Cap values are GDD starting points, playtest-tunable.
- Test: `tests/unit/player/upgrade_stack_cap_test.gd` (5 funcs). GDD status line updated to note code landed. Test suite **94 → 99, CI green**.
- ⚠️ Minor gameplay impact (caps 3-5 rarely hit in a 5-8 level-up run) but a playtest should confirm builds still feel good (GDD line 213).


## Session Extract — balance-math coverage (2026-05-29, continued)
- Test suite **80 → 94, all green**. Two BLOCKING-per-coding-standards balance areas now covered:
  - **Player XP / level-up curve** — `tests/unit/player/player_progression_test.gd` (8 funcs). Commits `3ab474e` + `022d843` (fix: TestPlayer subclass stubs `_queue_upgrade_choices` to avoid get_tree().paused crash on tree-detached instance). Curve `ceil(prev×1.28+6)` = 18→30→45→64; overflow carry; multi-level; gain multiplier; dead/zero guards; monotonic floor.
  - **Enemy elite stat modifiers** — `tests/unit/enemy/enemy_elite_modifiers_test.gd` (6 funcs). Commit `c7e3de8`. Base hp/dmg/speed multipliers + iron_bones/swift affix compounding + min-floor clamp + configure_elite public flow.
- Technique settled for tree-coupled units: instantiate script via `.new()`, seed post-_ready fields by hand, subclass-and-stub side-effect methods that touch get_tree() (e.g. `_queue_upgrade_choices`).

### Test coverage scoreboard (94 total)
- Combat core: damage tuple, HP application, aggregate ceiling (008)
- All 6 Cultivator weapons: talisman / flying sword / thunder / bagua / explosive / mountain seal
- Sun Wukong: 火眼金睛 modifier, skill-cooldown throttle
- Player: XP/level progression curve
- Enemy: elite stat modifiers
- System: demon-seal OQ-4 guard

### Remaining testable targets (future, lower priority)
- Enemy spawner wave configs / spawn-interval scaling
- Stage Director wave-progression thresholds (_get_wave_config_index)
- Level Up Pool upgrade selection + max_stacks (D-B2 cap — closes a known balance risk)
- Sun Wukong skill unlock progression (5/10/15/20) + add_fire_eyes_bonus cap

---

## Session Extract — weapon hardening milestone (2026-05-29)
- User mandate: "你全权负责持续开发" (full ownership of continuous development).
- **Milestone: every Cultivator weapon now has automated regression coverage.** Commit `146a693`. Test suite 64 → **80, all green**.
- Reviewed all 4 remaining weapons before testing — all correct, zero production changes needed:
  - Thunder Law: N-nearest insertion-sort targeting + AOE shared-dedup across strikes (5 tests)
  - Explosive Talisman: confirmed "direct + explosion" double-application on primary is GDD-intended (weapon-system.md L59/L142-145), not a bug (4 tests)
  - Mountain Seal: nearest-target + large-radius slam (4 tests)
  - Talisman projectile: single-target _has_hit guard (3 tests)
- Test patterns settled: drive methods directly (no physics signals), suppress weapon auto-_process, assert per-enemy hit_count (stray-node immune), `add_child_autoqfree` for self-queue_free projectiles.
- Impact nodes (ExplosiveImpact, MountainSealImpact) confirmed VISUAL-ONLY (no damage) — clean VFX/damage separation.

### Weapon coverage status
| Weapon | Covered | Test file |
|---|---|---|
| Talisman (追魂符) | ✅ | talisman_projectile_test.gd |
| Flying Sword (飞剑) | ✅ | flying_sword_pierce_test.gd |
| Thunder Law (雷法) | ✅ | thunder_law_targeting_test.gd |
| Bagua Array (八卦阵) | ✅ | bagua_array_tick_test.gd |
| Explosive Talisman (爆裂符) | ✅ | explosive_talisman_test.gd |
| Mountain Seal (镇山印) | ✅ | mountain_seal_test.gd |
| Sun Wukong 火眼金睛 modifier | ✅ | fire_eyes_modifier_test.gd |
| Sun Wukong JinguBang/CloudStep/Transform72 | ⬜ not yet (complex / some MVP-simplified) |

Next candidate (high value, pure math, explicitly required by coding-standards.md "XP/level math is BLOCKING"): **Player XP / level-up progression curve tests** — likely uncovered.


## Session Extract — weapon regression coverage (2026-05-28, continued)
- **Story 005 (Flying Sword pierce)** ✅ — `tests/unit/weapon/flying_sword_pierce_test.gd` (4 funcs): AC-06 multi-target full damage, AC-07 dedup-by-instance_id, capacity guard, non-enemy filter. Commit `859e089`. Pierce was implemented + correct but had ZERO coverage — now protected.
- **Story 006 (Bagua Array multi-target tick)** ✅ — `tests/unit/weapon/bagua_array_tick_test.gd` (4 funcs): AC-08-A all-in-radius hit, Formula 3 full-damage-each (no split), AC-08-B outside-radius ignored, multi-tick accumulation. Commit `c992190`.
- Both test-only (zero production change), drive methods directly (no physics-signal dependency), assert per-enemy hit_count (immune to stray group nodes).
- Test suite **50 → 64 unit tests, all green**. CI run c992190 ✅.
- Remaining Combat stories are mostly reverse-doc (004 weapon cooldown, 007 throttle — already implemented) or speculative infra (009 burn accumulator — no consuming weapon yet). Highest-value verifiable work (new mechanic 008 + coverage for shipping weapons) is done.


## Session Extract — Combat Story 008 (2026-05-28, after CI repair)
- **Story 008 — Aggregate DPS Ceiling (MAX_CONTACT_ATTACKERS=4)** — genuinely new gameplay logic (constant didn't exist before). Commit `38dfa07`, CI green.
- Player gains a contact-attacker list + pure static `select_allowed_attackers(attackers, max)`; Enemy registers/unregisters on damage-area overlap + gates `_try_damage_player` through `is_contact_attacker_allowed` (has_method-guarded → zero regression).
- AC-13 selection logic ✅ unit-tested (`tests/unit/combat/aggregate_ceiling_test.gd`, 6 funcs). AC-14 (player death sequence) already satisfied by existing take_damage/_die.
- ⏳ **Playtest-pending**: full 8-enemy Area2D physics overlap + Survival Budget feel (~4.25s vs 4 Paper Dolls @ HP=100). Cannot verify headlessly. Story 008 marked "Logic done ⏳" in EPIC.md.
- Test suite now **56 unit tests, all green**.

## Session Extract — autonomous-sprint 2026-05-28
- User mandate: "按你思路一直干到底；直到需要我操作的地方再找我" (run until blocked)
- 13 commits pushed to main. **CI now GREEN for the first time since /test-setup** (run 7bf3b39 ✅).

### Phase A — gameplay + UX + defect sprint (4 features)
| # | Commit | Item |
|---|--------|------|
| 1 | `08d3259` | Sun Wukong 火眼金睛 wiring (HairClone + Immobilize) — 4 files, 10-func test |
| 2 | `b20baa1` | HUD Boss HP bar (consumes Story 002 damage_taken signal) |
| 3 | `d5da405` | HUD Demon Seal progress bar (replaces text-only %) |
| 4 | `2c0ec2c` | Demon Seal OQ-4 fix (corpse XP orbs guard) + 4-func test + demon-seal.md r2 |
| 5 | `f1a58ac` | session-state intermediate checkpoint |
| 6 | `53d7c08` | Skill cooldown emit throttle (60× signal reduction) + ADR-0003 amend + 5-func test |

### Phase B — CI was silently broken; full repair (7 commits)
**CRITICAL DISCOVERY**: CI had been RED since /test-setup but for INFRASTRUCTURE reasons — Story 001 & 002 were marked "complete" with tests that **never actually ran in CI**. Layers peeled back one at a time:
| # | Commit | CI bug fixed |
|---|--------|------|
| 7 | `2584bb1` | `-gtest=<dir>` → `-gdir=<dir>` (GUT treats -gtest as a script path) + `mkdir -p reports` |
| 8 | `89c70c4` | gutconfig `prefix:"test_"` required `test_*_test.gd` filenames; our convention is `*_test.gd` → set prefix `""` → tests finally discovered |
| 9 | `168c733` | `failure_error_types` exclude `push_error` (tests intentionally trigger defensive push_error) |
| 10 | `ea0fa0d` | skill_cooldown test parse error (`:=` on Variant-returning `get_signal_emit_count`) |
| 11 | `aa56900` | hp_application `xp_drop_value=0` hygiene + freed_source test (Godot 4 auto-nulls freed dict refs) |
| 12 | `5b7c896` | the real 2-failure cause: `assert_ne(array, null)` trips GUT's `_diff_array` → `.size()` on null → use `assert_not_null` |
| 13 | `7bf3b39` | grant `checks: write` so dorny/test-reporter can publish → **CI fully green** |

**Final CI state**: 50 unit tests + integration tests pass; JUnit report publishes. Run `gh run list` shows 7bf3b39 = success.

Key technical wins:
- **Real gameplay bug fixed**: Sun Wukong 火眼金睛 passive now applies to all weapons, not just JinguBangV2.
- **Story 002 signal proven**: BossPanel HUD consumes `damage_taken` end-to-end.
- **OQ-4 + defect #2 closed**: post-death XP orb guard; skill cooldown emit throttle.
- **CI integrity restored**: 47→50 test functions across 5 files were sitting UNRUN; now all green and gating. Future "story complete" claims are now trustworthy.

Blockers: None.

⚠️ **Process lesson for future stories**: never trust a green "Run GUT tests" step alone — confirm the JUnit summary shows `Tests > 0`. A misconfigured runner exits 0 with "Nothing was run."

Next options (no user decision needed):
- **Combat Story 003 (Death Lifecycle / DYING state)** — next in epic order. Note: requires VFX subscriber before removing Enemy.queue_free(); currently no VFX system, so the queue_free-decoupling part should be deferred or stubbed.
- **Combat Story 007 (Enemy→Player Damage Throttle)** — also unblocked.
- **HUD minimap pip for off-camera Demon Seal** (Demon Seal OQ-3).

---

## Session Extract — /dev-story 2026-05-27
- Story: production/epics/combat-system/story-001-damage-tuple-friendly-fire.md — Damage Tuple + Friendly-Fire Contract
- Files changed: scripts/combat/damage_types.gd, tests/unit/combat/damage_tuple_test.gd
- Test written: tests/unit/combat/damage_tuple_test.gd (11 → 18 test functions covering AC-04/05/19 + edge cases)
- Blockers: None
- Next: /code-review then /story-done — DONE

## Session Extract — /story-done 2026-05-27
- Verdict: ✅ COMPLETE
- Story: production/epics/combat-system/story-001-damage-tuple-friendly-fire.md — Damage Tuple + Friendly-Fire Contract
- Tech debt logged: 3 items (RefCounted-vs-Object cosmetic; _COUNT sentinel; tests/README.md vs test-standards.md naming convention conflict)
- Next recommended: Story 002 (HP Application + Overkill Clamp) — `/story-readiness production/epics/combat-system/story-002-hp-application-overkill.md`
- Also unblocked: Stories 003, 004, 005, 006, 007 — all 9 downstream Combat stories per epic dependency order

## Session Extract — /story-done 2026-05-27 (Story 002)
- Verdict: ✅ COMPLETE
- Story: production/epics/combat-system/story-002-hp-application-overkill.md — HP Application + Overkill Clamp
- **First story that MODIFIED existing game code** (scripts/enemy/enemy.gd — added damage_taken signal + emit)
- Closes Enemy GDD r1 OQ-1 (missing damage_taken signal — tech debt resolved)
- Code review: APPROVED WITH SUGGESTIONS (0 required, 3 suggestions; 1 applied)
- Tests: tests/unit/combat/hp_application_test.gd (10 functions covering AC-01 + AC-20 + 6 edges)
- Next recommended: Story 003 (Death Lifecycle / DYING state) — depends on Story 002 ✅
- Also unblocked: Story 007 (Enemy→Player Damage Throttle)

---


> **Last Hand-Off**: All 25/25 single-system GDDs authored (commit d89ab1a). 15 Approved + 10 Designed-pending-review. Now spawning design-reviewer for the 10 pending GDDs to upgrade them to Approved.

---

## Current Task

**Phase: COMPLETE — Design-review pass for 10 Designed-pending-review GDDs**

All 25/25 GDDs are now Approved (revision-1 across all 10 reviewed). Cross-doc fixes propagated. systems-index Progress Tracker updated. Final commit pending.

---

## Design Review Pass Summary (2026-05-27)

| GDD | Verdict | Revision Outcome |
|---|---|---|
| demon-seal.md | CONCERNS (2B+3R+1NTH) | r1 Approved — collision radius 72 corrected; death-during-seal edge case rewritten; AC-08 25 points; HUD relay path; OQ-4 tracks code defect |
| elements-five-phases.md | CONCERNS (2B+4R) | r1 Approved — TR-CORE-005 ref dropped; element field marked RESERVED in Enemy GDD; algorithmic matchup statement; AC-04 worked example |
| menu-system.md | CONCERNS (3B+4R+5NTH) | r1 Approved — HUD owns GameOverPanel trigger (not panel); Input Contract section; AC-04 reload mechanism; localization OQ-4 |
| audio-system.md | CONCERNS (0B+7R+6NTH) | r1 Approved — coalesce 50ms consistency; Formula 1 complete (damage_intensity + LOUDEN_STEP); heartbeat trigger moved to Combat Feedback; originality policy → Rule 9 |
| vfx-system.md | NEEDS REVISION (3B+7R+6NTH) | r1 Approved — Formula 1 owns queue_free; photosensitivity ≤3 Hz per WCAG 2.3.1; colorblind "!" icon + diagonal stripes; always-on 60-particle reserve; palette anchored to 朱砂/青铜/鬼火 |
| status-effects.md | MAJOR REVISION (3B+3R+3NTH) | r1 Approved — Inventory ❌/🟡/✅ honesty (1/6 implemented); Stacking Matrix; 9 ACs GIVEN/WHEN/THEN; Combat.damage_dealt pipeline (Rule 6) |
| combat-feedback.md | MAJOR REVISION (2B+5R+4NTH) | r1 Approved — per-target flash throttle (was global bug); heartbeat 3-way split (CF trigger / HUD visual / Audio sound); hit-stop scope statement; AC-07 zero-damage defense |
| hud.md | MAJOR REVISION (5B+5R+5NTH) | r1 Approved — added demon_seal/boss_spawned/upgrade_applied subscriptions; Information Architecture; 5 accessibility hooks; 13 ACs |
| boss-system.md | MAJOR REVISION (4B+5R+4NTH) | r1 Approved — Enrage mechanic (HP≤0.3 trigger); summon archetypes corrected (Paper Doll + Wandering Soul); BossState enum; 22 Tuning Knobs; canonical HP=360 |
| active-skills.md | MAJOR REVISION (5B+4R+4NTH) | r1 Approved — 火眼金睛 contract (Combat reservation honored); ADR-0003 scope-creep guard; per-frame emit acknowledged; TBD → shipped defaults; Per-Skill Specifications |

**Cross-doc fixes applied**:
- stage-director.md line 177 (DemonSeal death-during-seal — code-truth defect now documented + OQ-4 tracks fix)
- HUD ↔ Combat Feedback heartbeat ownership joint resolution (Combat Feedback owns trigger; HUD owns visual; Audio owns sound)

**Defects surfaced for v0.4.x patch**:
1. `_on_demon_seal_completed` missing `_is_stage_failed` guard (8 XP orbs spawn post-death)
2. ADR-0003 amendment needed for per-frame `skill_cooldown_changed` emit exception
3. Enemy GDD `element: String = "neutral"` field addition (when v0.5 Elements activates)

---

## Session Extract — /review-all-gdds 2026-05-27
- Verdict: **FAIL** (5 BLOCKING consistency + 2 BLOCKING design theory)
- GDDs reviewed: 27 (25 single-system + 2 UX + game-concept + systems-index + entities.yaml)
- Flagged for revision: run-state, stage-director, combat-system, enemy-system, level-up-pool (5 — flipped to Needs Revision in systems-index)
- Blocking consistency: C-B1 Run State↔Stage Director ownership conflict; C-B2 Stage Director dead-code Boss exports (260/16 vs 360/18); C-B3 Combat Formula 7 HP=30 leftover; C-B4/B5 Enemy self-queue_free vs VFX queue_free authority
- Blocking design theory: D-B1 Player HP=100 vs Pressure Curve HP=30 design intent (Combat OQ-5 unresolved); D-B2 Level Up Pool no per-upgrade stack cap (Talisman 4× = 6×, exceeds Combat 5× ceiling)
- Warning items: 17 consistency + 5 design theory + 4 cross-system scenario
- Recommended next: address 6 Tier-1 blockers before /create-architecture or /create-stories; v0.4 playtest needed for D-B1 path decision
- Report: design/gdd/gdd-cross-review-2026-05-27.md

---

**Previously completed phase**:

Pending list:
1. Demon Seal (`design/gdd/demon-seal.md`) — Vertical Slice
2. Boss System (`design/gdd/boss-system.md`) — Vertical Slice
3. Status Effects (`design/gdd/status-effects.md`) — Vertical Slice
4. Combat Feedback (`design/gdd/combat-feedback.md`) — Vertical Slice
5. HUD (`design/ux/hud.md`) — MVP UI
6. Menu System (`design/ux/menu-system.md`) — MVP UI
7. Active Skills (`design/gdd/active-skills.md`) — Alpha
8. Elements / 五行 (`design/gdd/elements-five-phases.md`) — Full Vision
9. Audio (`design/gdd/audio-system.md`) — Full Vision
10. VFX (`design/gdd/vfx-system.md`) — Full Vision

Approach: 3 parallel batches of design-reviewer subagents.

---

## Previously Completed

**Combat GDD revision-1 (after /design-review MAJOR REVISION NEEDED)** — completed, approved in revision-3.

Reviewer flagged 8 BLOCKERS + 10 RECOMMENDED REVISIONS. All 8 blockers addressed
in revision-1; most of the 10 recommended also addressed in the same revision.

Key changes from revision-0:
- Added Pressure Curve § (TTK budget, hits-to-die per phase, incoming DPS targets)
- Renamed "Detailed Design" → "Detailed Rules" (CCGS tooling grep compat)
- Added Core Rule 6 (DYING guard), Rule 7 (zero-damage throttle preserve),
  Rule 8 (aggregate DPS ceiling MAX=4), Rule 9 (per-enemy throttle independence)
- Damage tuple extended with `source_kind` for friendly-fire enforcement
- Formula 1 extended with multiplier pipeline (source / crit / element / pierce)
- Formula 2 clamp embedded inline
- Formula 3 added hits_per_tick cap (MAX_HITS_PER_TICK = 20)
- Formula 4 init rule made explicit (no grace period)
- NEW Formula 5: Burn fixed-step accumulator (frame-rate independent)
- NEW Formula 6: Pierce damage (full damage per pierce, falloff slot reserved)
- NEW Formula 7: Aggregate DPS ceiling
- Death lifecycle split: data-death (1 frame) vs visual-death (≤ 0.5s dissolve)
- Signal payload contracts explicit: died / damage_taken / health_changed
- HP bar trigger via damage_taken (was undefined)
- AC count: 10 → 20 (added friendly fire AC, tuple AC, deterministic burn ACs,
  pierce_count = 0 AC, aggregate ceiling AC, etc.)
- 2 new OQs: TTK validation, ceiling tiebreak determinism

Status changed to "Needs Revision" pending re-review.

---

## Status

| Item | Value |
|---|---|
| Project Stage | Production |
| Review Mode | lean |
| Active Milestone | v0.4-qa (planning) |
| Systems Index | ✅ Combat row updated to Designed |
| Single-System GDDs | **1 / 25** (Combat ✅ — pending /design-review) |
| Adoption Plan | ✅ All BLOCKING + HIGH closed |
| Tests Scaffold | ✅ tests/ ready (GUT addon manual install pending) |
| Entity Registry | ✅ 7 enemies updated with combat-system.md reference; 4 new formulas registered |
| Sprint Status | v0.4-qa planning |

---

## Files Touched This Session

- `design/gdd/combat-system.md` — new (548 lines, 8 required + 3 optional sections)
- `design/registry/entities.yaml` — 7 enemies' referenced_by += combat-system.md; target_framerate += combat-system.md; 4 new formula entries
- `design/gdd/systems-index.md` — Combat row Status → Designed; Progress Tracker updated to 1/25
- `production/session-state/active.md` — this file

---

## Combat GDD Highlights

- **Reverse-documented** from existing code, not invented
- **4 damage types** locked into contract: direct / tick / explosion / burn
- **4 formulas** registered:
  - `damage_application_formula`: `new_hp = max(0, current_hp - damage_amount)`
  - `weapon_dps_formula`: `dps = damage / cooldown`
  - `multi_target_effective_dps`: `(damage × hits_per_tick) / tick_rate`
  - `damage_interval_throttle`: per-enemy hit throttle
- **10 acceptance criteria** in GIVEN-WHEN-THEN format (testable by QA)
- **4 open questions** flagged for future GDDs (crit support, status pipeline integration, five-phase scaling)
- **TR coverage**: TR-core-001, TR-core-005, TR-wpn-001, TR-wpn-002, TR-enemy-002

---

## Recommended Next Actions

1. **Run `/design-review design/gdd/combat-system.md` in a fresh session** — independent critique of the Combat GDD (CCGS requires fresh session for design-review)
2. **Or continue down the design order**: `/design-system player-system` (next in retrofit order — Player is #2 bottleneck with 6 downstream dependencies)
3. **Or jump to a smaller system** to maintain momentum: `/design-system camera-system` (S effort, 1 session)
4. **`/consistency-check`** — now that Combat formulas + entity references are registered, re-run to verify cross-doc consistency

---

## Art Bible — 2026-05-31

**文件位置**: `design/art/art-bible.md`

**完成状态**: ✅ 全 9 章完成
- ✅ 第 1 章：视觉身份声明 — "阴墨镇妖，红光可读" + 三原则
- ✅ 第 2 章：氛围与情绪 — 六状态完整情绪/光源/能量定义
- ✅ 第 3 章：形状语言 — 三域几何系统 + 角色剪影哲学 + UI 形状仲裁法则
- ✅ 第 4 章：色彩系统 — 主调五色语法 + 五行色系统 + 色盲安全规程 + 八条强制规则 + 昆仑石色 + 交易间隙色温上限
- ✅ 第 5 章：角色美术方向 — 玩家阵营统一语言 + 四层辨认规则 + 无面孔姿态哲学 + 2D 精灵细节哲学
- ✅ 第 6 章：环境设计语言 — 三时态建筑（荒山/幽都/昆仑）+ 水墨四层 Parallax + 道具密度 + 12 个环境叙事母题
- ✅ 第 7 章：UI/HUD 视觉方向 — 半拟物 + 宋体三层 + 印章简化图标 + 动效双人格 + 6 项 UX 对齐裁定
- ✅ 第 8 章：资产规范 — 格式/命名/尺寸层级 + 内存 300MB 子预算 + draw call 合图策略 + 粒子上限 + Godot 导入设置 + 占位三约束 + 8 项冲突裁定
- ✅ 第 9 章：参考方向 — 风之旅人 + 皮影戏 + 木刻版画 + 敦煌壁画 + 宋元水墨 + 反参考清单

**待传播项**:
- 第 7 章 C-01 → `08 §4.1`（气血危险：朱红边框 → 亮度脉冲/心跳）
- 第 7 章 C-02 → `08 §4.4`（4:30 计时器：变朱红 → 保持旧纸黄 + 震动/字号）
- 第 8 章 §8.7 多处 Godot 4.4-4.6 导入器行为待对照 `docs/engine-reference/godot/` 核实

**关联文件**: 整合了 `design/style/07_VISUAL_STYLE_GUIDE.md` + `design/style/08_UI_UX_GUIDE.md` 的已有内容

---

## Recovery Instructions

If session crashes, in a new session:
1. Read this file
2. Read `design/art/art-bible.md` for latest art direction state
3. Read `design/gdd/combat-system.md` (latest single-system GDD)
4. Read `design/gdd/systems-index.md` Recommended Design Order
5. Continue with next system in order
