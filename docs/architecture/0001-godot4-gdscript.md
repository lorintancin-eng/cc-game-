# ADR-0001: 选择 Godot 4.x + GDScript

- **状态**：Accepted
- **日期**：项目初期（PMF 追溯登记于 2026-05-23）
- **决策人**：用户
- **影响版本**：全项目
- **相关任务**：项目奠基

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
