# Stage 1 Regression Check — after StageConfig migration (ADR-0004 Step 3)

> **Purpose**: confirm the data-driven StageDirector (commit `795a209`) plays Stage 1
> (荒山古道) **byte-identically** to the old hardcoded version. The golden unit tests
> (110 passing) prove the config VALUES match; this playtest proves the LIVE
> `apply_wave_config` integration is unchanged — the one thing CI cannot run.
>
> **How**: open `scenes/Main.tscn`, press F5, play one full ~5-minute Stage 1 run.
> Watch the Output panel for any red `push_error`. Mark each ✅/❌ + note anything off.

## What changed (so you know what to watch)
Only the SOURCE of the stage timeline moved (hardcoded → `StageOneConfig.build()`).
The numbers are identical. So **anything that feels different is a bug to report.**

## Checklist

| Time | Expected (unchanged from before) | ✅/❌ | Notes |
|---|---|---|---|
| 0:00 | Game launches; character select works; Stage 1 starts; enemies begin spawning | | |
| 0:00–1:00 | Only **Paper Doll + Wandering Soul** spawn; interval feels ~1.35s; ≤18 on screen | | |
| 1:00 | **Fox Spirit + Ghost Flame** join the pool; density rises (interval ~1.08s, ≤24) | | |
| 2:00 | **Stone Golem** joins (interval ~0.90s, ≤32) | | |
| 2:00 | **镇妖碑 (Demon Seal)** appears; standing in it raises pressure; completing it drops ~8 XP orbs | | |
| 3:00 | **Shanxiao Elite (铁骨/iron_bones)** spawns once, ~420px away (HUD "妖气暴涨"? no — that's boss) | | |
| 3:00 | density rises again (interval ~0.72s, ≤42) | | |
| 4:00 | **Shanxiao Elite (疾风/swift)** spawns once (faster elite) | | |
| 4:30 | **"妖气暴涨，妖王即将降临"** boss warning fires; density peaks (interval ~0.55s, ≤56) | | |
| 5:00 | **饕餮 (Famine Beast)** spawns; normal-enemy density thins (boss-phase clamp); 3 abilities (冲撞/爆裂/召唤) | | |
| Boss ≤30% HP | **暴怒 (Enrage)**: body turns dark-cinnabar + aura, faster, abilities more frequent | | |
| Boss death | **"封印完成"** + victory/結算 panel; run ends | | |
| Any death | Player death → **"道消身陨"** + game-over panel | | |
| Whole run | **No red `push_error` in Output**; pacing/difficulty feels the same as the last v0.4 run | | |

## Verdict
- [ ] **PASS** — Stage 1 is unchanged. Step 3 migration is clean → safe to build RunDirector (Step 4) on top.
- [ ] **FAIL** — something differs (describe below). Do NOT proceed to Step 4; report what changed so the migration can be fixed.

**Observations / anything off**:
_______________________________________________

> After playtest: tell Claude "Stage 1 PASS" (or describe the failure). Then implementation continues from Step 4 (RunDirector).
