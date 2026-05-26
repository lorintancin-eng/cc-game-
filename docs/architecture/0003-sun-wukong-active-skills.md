# ADR-0003: 孙悟空特例 — 主动技能与项目自动战斗设计的冲突

- **状态**：Accepted
- **日期**：2026-05-23
- **决策人**：用户
- **影响版本**：v0.4+（推翻 v0.3 孙悟空实施重做）
- **相关任务**：v0.4 孙悟空 v2 重做

---

## Status

Accepted

## ADR Dependencies

- **Depends on ADR-0001** — assumes Godot 4.x + GDScript stack for Input Map + signal architecture.
- **Supersedes v0.3 孙悟空 design** (see `production/archive/v0.3/V0_3_CHARACTERS.md` §4.2). The v0.3 implementation (灵气-based passive skills) is fully replaced by v2 (4 active skills bound to keys 1/2/3/4).
- **No other ADR currently depends on this one.** Future ADRs about additional active-skill characters would inherit this decision's framework.

## Engine Compatibility

- **Engine**: Godot 4.6
- **Subsystems used**:
  - `Input` singleton + `InputMap` (project.godot) — additional `active_skill_1` ~ `active_skill_4` actions to be added at implementation time
  - Signal architecture for `skill_triggered(slot)`, `cooldown_started(slot, duration)`, `cooldown_ended(slot)`
  - `Timer` nodes per active skill (or single coalesced cooldown manager)
- **API-version risk**: input handling is stable across 4.x; no post-4.3 API risk. UI HUD cooldown rendering may use `TextureProgressBar` (stable).
- **Cross-reference**: `docs/engine-reference/godot/VERSION.md` for any post-4.3 input API features (gamepad rumble, haptics) if future iterations target controllers.

## GDD Requirements Addressed

- `design/narrative/02_CHARACTER_DESIGN.md` §4.2 — 孙悟空角色定位(必须加显式说明:孙悟空是项目内唯一主动技能角色)
- `design/narrative/SUN_WUKONG_V2_DESIGN.md` — 完整 v2 设计稿(4 主动技能 + 火眼金睛被动 + 金箍棒普攻)
- `design/gdd/04_SKILL_DESIGN.md` §2.2 — 招唤系流派(v0.3+),孙悟空的毫毛分身是该流派的实例
- `design/gdd/game-concept.md` §战斗方向 — 需加附注 "允许个别角色突破自动战斗约束作为玩法多样性"

## Performance Implications

**Active skill input latency**:
- Target: ≤1 frame from key press to skill trigger (16.67ms @60 FPS)
- Implementation must use `_input(event)` or `_unhandled_input(event)` — NOT polling in `_process()`
- Cooldown checks happen on key event, not per-frame

**HUD overhead**:
- 4 cooldown indicators redraw only when state changes (signal-driven), not per frame
- Per `.claude/rules/gdscript.md` §UI Code: "HUD updates should be event-driven"

**Combined load**:
- Worst case: 4 skills triggered within 1 second + 50+ enemies + 200+ projectiles → still within 16.67ms budget per profiling assumptions in ADR-0001
- `毫毛分身` (hair clone) skill spawns 1-3 AI units — these count toward enemy/ally simulation budget. Spawn cap enforced in skill data resource.

**Re-evaluation triggers**:
- Frame time spike on skill activation under heavy load
- Hair clone units degrade FPS — fall back to fewer clones or simpler AI
- If 4 active skills feel sluggish vs. auto-battle responsiveness → revisit input pipeline

---

## 1. 背景与问题

MythSurvivor 在 v0.2 设计阶段就明确定位为 **"俯视角自动战斗 Roguelite 生存游戏"**，参考 Vampire Survivors 模式：

- **玩家手动**：移动 / 走位 / 升级三选一
- **游戏自动**：攻击 / 技能释放 / 目标选择

此设计写入：
- [game-concept.md](../../design/gdd/game-concept.md) §核心玩法循环
- [03_CORE_GAMEPLAY.md](../03_CORE_GAMEPLAY.md) §3 玩家行为契约
- [02_CHARACTER_DESIGN.md](../02_CHARACTER_DESIGN.md) §1.2 - 全角色自动战斗

v0.3 实施的孙悟空（3 武器 + 灵气 + 七十二变）严格遵守此设计。

2026-05-23 用户提出孙悟空 v2 重设计，**其中 4 个新技能（毫毛分身 / 筋斗云 / 七十二变 / 定身术）需要玩家主动按键释放**。这与项目自动战斗定位**直接冲突**。

## 2. 决策

**孙悟空作为唯一一个具有主动技能的角色，作为项目玩法多样性的特例存在。**

- 孙悟空：金箍棒普攻自动，4 主动技能玩家按 1/2/3/4 键释放，火眼金睛被动。
- 修行者、哪吒、杨戬、女娲、盘古：**保持全自动战斗设计**（按 cooldown / 目标规则自动释放）。

## 3. 候选方案

### 方案 A：拒绝主动技能，孙悟空仍全自动
- 优点：保持游戏定位纯粹，所有角色一致
- 缺点：放弃用户期望的孙悟空玩法深度，损失"花果山齐天大圣"的操作感

### 方案 B：整个游戏转向半自动（所有角色都加主动技能）
- 优点：玩法深度提升
- 缺点：**推翻 GDD 与所有已完成系统**；6 个未来神祇都要重设计；Vampire Survivors 风格的核心受众流失

### 方案 C（选定）：孙悟空特例 + 其他角色保持全自动
- 优点：保留游戏定位的同时提供玩法多样性；玩家可在"省心刷"（全自动角色）和"操作猴"（孙悟空）间切换
- 缺点：需要在 02_CHARACTER 加显式说明，避免设计混乱

## 4. 选定方案与理由

**选 C**。理由：

1. **保护已立的游戏定位**：GDD 和 v0.2 全套系统不动，新方向不会引发雪崩重构
2. **角色定位多样化**：孙悟空"操作派"，修行者/哪吒/杨戬"省心派"，女娲"阵地派"，盘古"蓄力派" — **每个角色玩感真正不同**
3. **风险隔离**：主动技能系统的实现只影响孙悟空模块，不影响其他角色
4. **可逆**：未来如果验证主动技能玩法不受欢迎，孙悟空可以回退为全自动，不影响其他角色

## 5. 影响与后果

### 5.1 正面影响

- 玩家有 2 套玩法可选（全自动 + 半自动），扩展受众
- 孙悟空作为"招牌角色"有更深的操作空间
- 项目仍然是 Vampire Survivors 类型，定位清晰

### 5.2 负面影响 / 代价

- 需要新建**输入响应系统**（v0.3 没有按键映射）
- 需要新建**技能 cooldown UI**（HUD 加 4 个技能图标 + 倒计时）
- 需要新建**主动技能基类**（继承关系：CharacterBase → ActiveSkillCharacter → SunWukong）
- **v0.3 孙悟空全部代码作废**（约 800 行）
- v0.3 sun_wukong.gd 灵气机制不再需要（七十二变改为按键触发）

### 5.3 后续行动

- [ ] 在 02_CHARACTER_DESIGN §4.2 加显式说明："孙悟空是项目内唯一主动技能角色"
- [ ] 在 game-concept.md 加附注："允许个别角色突破自动战斗约束作为玩法多样性"
- [ ] 创建 SunWukong v2 完整设计稿（见 docs/SUN_WUKONG_V2_DESIGN.md）
- [ ] v0.3 合并 main 后，开新分支 codex/character-sun-wukong-v2 重做
- [ ] 设计输入响应系统 + cooldown UI 系统

## 6. 用户的关键设计决定（2026-05-23）

| 维度 | 决定 |
|---|---|
| 半自动适用范围 | 仅孙悟空特例（其他角色保持全自动） |
| 4 主动技能键位 | 1 / 2 / 3 / 4 数字键 |
| 火眼金睛 | 被动技能，开局自带，对精英/Boss +20% 伤害 |
| 升级系统 | 普通升级照常（含修行者技能机制）；每 5 级**额外**选 1 主动技能 |
| 金箍棒 | "真无 cd" — 每帧在范围内检测伤害（沿用 v0.3 旋转模式底层）|
| v0.3 代码 | 推翻重做（删除现有 wukong_* 代码）|

## 7. 相关决策

- 取代了：v0.3 孙悟空设计（[archive/v0.3/V0_3_CHARACTERS.md](../archive/v0.3/V0_3_CHARACTERS.md) §4.2）
- 被取代：无
- 关联：[SUN_WUKONG_V2_DESIGN.md](../SUN_WUKONG_V2_DESIGN.md)

## 8. 参考资料

- [game-concept.md](../../design/gdd/game-concept.md) — 项目原始自动战斗定位
- [03_CORE_GAMEPLAY.md](../03_CORE_GAMEPLAY.md) §3 — 玩家行为契约
- [SUN_WUKONG_V2_DESIGN.md](../SUN_WUKONG_V2_DESIGN.md) — v2 完整设计稿

## 9. 变更日志

| 日期 | 变更 |
|---|---|
| 2026-05-23 | 创建，记录孙悟空特例决策 |
