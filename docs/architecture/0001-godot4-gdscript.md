# ADR-0001: 选择 Godot 4.x + GDScript

- **状态**：Accepted
- **日期**：项目初期（PMF 追溯登记于 2026-05-23）
- **决策人**：用户
- **影响版本**：全项目
- **相关任务**：项目奠基

---

## Status

Accepted

## ADR Dependencies

None — this is a foundational decision. All other ADRs in this project assume Godot 4.x + GDScript as the implementation stack.

## Engine Compatibility

- **Engine**: Godot 4.x (project pinned to Godot 4.6 — see `docs/engine-reference/godot/VERSION.md`)
- **API-version risk**: LLM training cutoff is approximately Godot 4.3. Versions 4.4 / 4.5 / 4.6 introduced changes the model does not know about (Jolt physics default, AccessKit accessibility, D3D12 on Windows default, glow rework, shader baker, variadic args, `@abstract`). Always cross-reference `docs/engine-reference/godot/VERSION.md` before suggesting post-4.3 APIs.
- **Renderer / Physics**: Forward+ renderer, Jolt Physics for 3D (project is 2D — uses Godot Physics 2D), D3D12 default on Windows.
- **Language version**: GDScript 2.0 (Godot 4.x). Typed GDScript required wherever feasible (`.claude/rules/gdscript.md`).

## GDD Requirements Addressed

This ADR is foundational and addresses requirements implied by every GDD in the project. Specifically:

- `design/gdd/game-concept.md` — requires "Godot 4.x + GDScript" stack in §愿景
- `design/gdd/03_CORE_GAMEPLAY.md` — assumes scene-composition + signal-driven runtime
- `docs/architecture/ARCHITECTURE.md` — entire architecture document is Godot-specific

Once single-system GDDs exist (per `design/gdd/systems-index.md` retrofit order), each will reference this ADR as the stack assumption.

## Performance Implications

**GDScript performance trade-off**: GDScript is interpreted and roughly 5–20× slower than equivalent C# or C++ in hot loops. For MythSurvivor (50–100 enemies + 200+ projectiles target per §性能预期), this matters in:

- `_physics_process()` per-enemy AI tick — kept simple, no expensive per-frame allocations
- Projectile collision detection — uses Godot's native physics (C++), GDScript only orchestrates
- Damage application loop — currently profile-clean, but a future bottleneck if status effects multiply

**Mitigations adopted**:
- Data-driven config via `Resource` (.tres) — avoids GDScript content lookup overhead
- Simple collision shapes (Circle/Capsule) — physics layer handles most cost in C++
- Object pooling deferred until `/perf-profile` shows actual stutter

**Re-evaluation triggers**:
- Frame time exceeds 16.67ms (60 FPS budget) under realistic encounter load
- GDExtension (C++) considered for damage / spawning / AI hot paths if profiling proves necessary
- C# port considered only for full-project rewrite scenario (currently rejected — see §3 alternatives)

---

## 1. 背景与问题

启动 MythSurvivor 项目时需要选择游戏引擎和编程语言。游戏定位：2D 俯视角自动战斗 Roguelite 生存游戏，预期玩家屏幕同时存在大量敌人和投射物。

## 2. 决策

**使用 Godot 4.x + GDScript 作为唯一开发栈。**

## 3. 候选方案

### 方案 A：Godot 4.x + GDScript（选定）
- 优点：开源免费、对 2D 友好、场景组合简单、信号机制成熟、社区活跃
- 缺点：GDScript 性能不如 C#/C++、生态比 Unity 小

### 方案 B：Unity + C#
- 优点：生态成熟、性能强、商业资源丰富
- 缺点：商业 License 限制、对独立开发者越来越不友好（pricing 变动史）

### 方案 C：自研引擎 / 其他（如 LÖVE / Bevy）
- 优点：完全控制
- 缺点：开发时间过长，不符合"快速做出 MVP"目标

## 4. 选定方案与理由

Godot 4.x + GDScript：
- 完全开源，无任何商业限制
- 对 2D 俯视角 Survivor 类游戏支持充分
- 场景组合 + 信号机制契合"小而清晰"的架构理念
- GDScript 学习成本低，便于快速迭代

性能担忧通过架构层面规避：
- 数据驱动配置（Resource）
- 对象池（必要时）
- 简单碰撞形状

## 5. 影响与后果

### 5.1 正面影响

- 零 License 成本
- 快速迭代
- 跨平台导出简单
- 文档与代码风格统一（[CODE_STYLE.md](../CODE_STYLE.md)）

### 5.2 负面影响 / 代价

- 大量敌人 / 投射物可能成为性能瓶颈
- GDScript 类型系统弱于 C#
- 部分高级功能（如复杂阴影）需用 C++ GDExtension（暂不需要）

### 5.3 后续行动

- [x] 建立 [CODE_STYLE.md](../CODE_STYLE.md)
- [x] 建立 [ARCHITECTURE.md](../ARCHITECTURE.md)
- [ ] 性能瓶颈出现时考虑对象池
- [ ] v1.0 前评估是否需要 GDExtension 优化热点

## 6. 相关决策

- 取代了：无（初始决策）
- 被取代：无

## 7. 参考资料

- [Godot 4.x 官方文档](https://docs.godotengine.org/en/stable/)
- [AGENTS.md](../../AGENTS.md) §技术基线

## 8. 变更日志

| 日期 | 变更 |
|---|---|
| 2026-05-23 | PMF 追溯登记 |
