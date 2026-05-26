# Adoption Plan

> **Generated**: 2026-05-25
> **Project phase**: Production
> **Engine**: Godot 4.6
> **Template version**: CCGS v1.0+ (Donchitos/Claude-Code-Game-Studios)

Work through these steps in order. Check off each item as you complete it.
Re-run `/adopt` anytime to check remaining gaps.

---

## Audit Summary

| Severity | Count | Description |
|---|---|---|
| 🔴 BLOCKING | 3 | Template skills malfunction without these |
| 🟠 HIGH | 7 | Unsafe to run `/create-stories` or `/story-readiness` |
| 🟡 MEDIUM | 12 | Quality degradation |
| ⚪ LOW | 3 | Optional improvements |

**Estimated remediation**: 4-6 hours (BLOCKING ~30 min, HIGH ~2-3 h, MEDIUM 推迟到 retrofit 时)

---

## Key Insight: 不要强求宏观 GDD 合规

MythSurvivor 的 3 个 PMF 编号 GDD(`03_CORE_GAMEPLAY` / `04_SKILL_DESIGN` / `05_ENEMY_DESIGN`)本质上是**跨系统的总览文档**,不是 CCGS 的"每系统一个 GDD"模型。

**不要去改它们的章节结构。** 它们作为参考资料保留即可。真正合规的是 systems-index 里规划的 25 个**单系统 GDD**(将来通过 `/design-system [slug]` 写)。

因此本 plan 中 MEDIUM 等级的"GDD 章节缺失"项目大部分会**自然解决** —— 当你按 systems-index 的 Recommended Design Order 写新单系统 GDD 时,这些新文件会遵守 8 章节标准。

---

## Step 1: Fix Blocking Gaps

### 1.1 ✅ B-1: systems-index.md Status 列非法值(已在 plan 写入前修复)

- **问题**:Status 列有 22 行使用 `"Implemented (no GDD)"` / `"Implemented (covered by ...)"` 等带括号的非法值,会断 `/gate-check`、`/create-stories`、`/architecture-review` 的精确字符串匹配
- **修复**:全部改为 `Not Started`,并在表格上方加 Note 说明代码状态(见 Progress Tracker)
- **状态**:✅ 已完成 — 见 `design/gdd/systems-index.md` 当前版本
- [x] B-1 closed

### 1.2 🔴 B-2: ADR-0001 缺 `## Status` 章节

- **文件**:`docs/architecture/0001-godot4-gdscript.md`
- **问题**:状态信息在 metadata block(`- **状态**:Accepted`),但 `/story-readiness` 和 `/architecture-review` 用 `grep -E "^## Status"` 找不到,会**静默通过所有 ADR 检查**
- **修复**:加 `## Status` 章节,内容为 `Accepted`(已是项目实际状态)
- **命令**:`/architecture-decision retrofit docs/architecture/0001-godot4-gdscript.md` 或手动编辑
- **预估**:5 min
- [ ] B-2 closed

### 1.3 🔴 B-3: ADR-0003 缺 `## Status` 章节

- **文件**:`docs/architecture/0003-sun-wukong-active-skills.md`
- **问题**:同 B-2
- **修复**:加 `## Status` 章节,内容为 `Accepted`
- **命令**:`/architecture-decision retrofit docs/architecture/0003-sun-wukong-active-skills.md` 或手动编辑
- **预估**:5 min
- [ ] B-3 closed

---

## Step 2: Fix High-Priority Gaps

### 2.1 🟠 H-1: ADR-0001 缺 `## ADR Dependencies`

- **问题**:`/architecture-review` 依赖排序失效;ADR 间关系不可追踪
- **修复**:加 `## ADR Dependencies` 章节。0001 是基础决策,可写 `None — foundational decision`
- **预估**:5 min
- [ ] H-1 closed

### 2.2 🟠 H-2: ADR-0001 缺 `## Engine Compatibility`

- **问题**:post-cutoff Godot API 风险无法追踪(LLM cutoff ~4.3,项目用 4.6)
- **修复**:加 `## Engine Compatibility` 章节,说明 Godot 4.6 + Jolt + D3D12 兼容性,引用 `docs/engine-reference/godot/VERSION.md`
- **预估**:10 min
- [ ] H-2 closed

### 2.3 🟠 H-3: ADR-0003 缺 `## ADR Dependencies`

- **问题**:同 H-1。0003 取代了 v0.3 孙悟空设计,应记录此依赖
- **修复**:加 `## ADR Dependencies` 章节,引用 v0.3 孙悟空设计(已废止)和 ADR-0001
- **预估**:5 min
- [ ] H-3 closed

### 2.4 🟠 H-4: ADR-0003 缺 `## Engine Compatibility`

- **问题**:同 H-2。主动技能输入系统在 Godot 4.6 Input map 上有特定约束
- **修复**:加 `## Engine Compatibility` 章节
- **预估**:10 min
- [ ] H-4 closed

### 2.5 🟠 H-5: 缺 `docs/architecture/tr-registry.yaml`(TR 注册表)

- **问题**:Story 无法引用稳定 TR-ID(`TR-MOV-001` 等),staleness 检查失效
- **修复**:运行 `/architecture-review` —— 即使 ADR 已存在,该命令也会 bootstrap TR 注册表(从 ADR Status 字段读取)
- **依赖**:必须先完成 B-2、B-3(`## Status` 章节存在,否则 review 报错)
- **预估**:1 session(review 对大项目可能较长)
- [ ] H-5 closed

### 2.6 🟠 H-6: 缺 `docs/architecture/control-manifest.md`(控制清单)

- **问题**:Story 没有 layer-level rules sheet,/dev-story 缺乏程序员侧约束
- **修复**:运行 `/create-control-manifest`
- **依赖**:必须先完成 H-5(manifest 引用 TR 注册表)
- **预估**:30 min
- [ ] H-6 closed

### 2.7 🟠 H-7: 4 个 GDD 都缺 `## Acceptance Criteria` 章节

- **问题**:`/create-stories` 从 GDD 提取验收标准生成 story checklist,缺章节会导致 stories 没 acceptance criteria
- **修复策略**:
  - 宏观 GDD(`03_CORE` / `04_SKILL` / `05_ENEMY`):**不动**(它们是参考文档,不应该承担 single-system GDD 职责)
  - `game-concept.md`:把 "MVP 成功标准" 章节重命名/补充为 "Acceptance Criteria",这样 `/create-stories` 能识别
  - 25 个单系统 GDD:在 `/design-system` 写新 GDD 时遵守 8 章节标准
- **预估**:10 min(仅 game-concept.md)
- [ ] H-7 closed

---

## Step 3: Bootstrap Infrastructure

> 这一步在 BLOCKING + HIGH 都修完后做。

### 3.1 注册现有需求(创建 tr-registry.yaml)
依赖 B-2、B-3。运行 `/architecture-review` —— 该命令同时关闭 H-5。
- [ ] tr-registry.yaml 已创建

### 3.2 创建 control-manifest
依赖 3.1。运行 `/create-control-manifest` —— 关闭 H-6。
- [ ] docs/architecture/control-manifest.md 已创建

### 3.3 创建 sprint tracking file
v0.4 QA 任务转 sprint 时同时建。运行 `/sprint-plan v0.4-qa`。
- [ ] production/sprint-status.yaml 已创建

### 3.4 设置 stage.txt
- [x] 已完成(Production)— `/project-stage-detect` 已写

### 3.5 architecture-traceability.md
由 `/architecture-review` Phase 8 自动生成。
- [ ] docs/architecture/architecture-traceability.md 已创建

---

## Step 4: Medium-Priority Gaps

### 4.1 🟡 M-1/M-2: ADR 缺 `## GDD Requirements Addressed`(2 个 ADR)

- **修复**:`/architecture-decision retrofit` 或手动加章节,引用相关 GDD
- **预估**:10 min × 2
- [ ] M-1 (ADR-0001) closed
- [ ] M-2 (ADR-0003) closed

### 4.2 🟡 M-3: 缺 `production/sprint-status.yaml`

- 见 3.3
- [ ] M-3 closed

### 4.3 🟡 M-4: 缺 `docs/architecture/architecture-traceability.md`

- 见 3.5
- [ ] M-4 closed

### 4.4 🟡 M-5/M-6/M-7: 3 个 PMF GDD 用中文章节名

- `03_CORE_GAMEPLAY.md` / `04_SKILL_DESIGN.md` / `05_ENEMY_DESIGN.md`
- **状态**:**接受现状**(按 Key Insight)。新单系统 GDD 写时遵守 8 章节英文标准
- [x] 接受现状 — 不修

### 4.5 🟡 M-8 ~ M-11: 4 个 GDD 缺 Player Fantasy 章节

- **状态**:`game-concept.md` 的"玩家幻想"章节(中文)语义匹配。其他 3 个宏观 GDD 不要求(参考文档)。新单系统 GDD 写时遵守
- [x] 接受现状 — game-concept.md 已有"玩家幻想",其他不补

### 4.6 🟡 M-12: tech-preferences Performance Budgets 4 项 `[TO BE CONFIGURED]`

- **文件**:`.claude/docs/technical-preferences.md`
- **修复**:填入 60 FPS / 16.67ms frame budget / draw call 上限 / memory 上限。可从 03_CORE §13 复制
- **预估**:5 min
- [ ] M-12 closed

---

## Step 5: Low-Priority Improvements

### 5.1 ⚪ L-1: ADR-0001 缺 `## Performance Implications`

- **修复**:加章节,说明 Godot/GDScript 选择对性能的影响(GDScript 解析开销 vs C# 编译性能)
- **预估**:10 min
- [ ] L-1 closed

### 5.2 ⚪ L-2: ADR-0003 缺 `## Performance Implications`

- **修复**:加章节,说明主动技能输入系统的性能影响
- **预估**:10 min
- [ ] L-2 closed

### 5.3 ⚪ L-3: ADR 命名格式 `0001-*.md` vs CCGS 推荐 `adr-0001-*.md`

- **现状**:`0001-godot4-gdscript.md`、`0003-sun-wukong-active-skills.md`
- **修复选项**:
  - A) 重命名为 `adr-0001-godot4-gdscript.md` 等(需更新跨文档引用)
  - B) 保持现状(/adopt 用 glob `adr-*.md`,可能找不到,但实际可用 `[0-9]*.md` glob)
- **建议**:**B,保持现状**。重命名收益低风险大
- [x] 接受现状 — 不改名

---

## What to Expect from Existing Stories

MythSurvivor 当前 **没有 production/epics/ 下的 story 文件**。`production/sprints/backlog.md` 是宏观 backlog,不是 CCGS story 格式。

未来 `/sprint-plan` + `/create-stories` 会生成符合 CCGS 格式的 stories(每个含 TR-ID、ADR 引用、acceptance criteria checkbox)。

---

## Execution Order(推荐)

1. **现在**:B-2 + B-3 + H-1 ~ H-4(全是手工编辑两个 ADR,~ 35 min)
2. **接下来**:H-7(改 game-concept.md 章节名,~ 10 min)
3. **然后**:Step 3 Bootstrap(`/architecture-review` → `/create-control-manifest`,~ 1-2 sessions)
4. **再后面**:`/test-setup`(装 GUT,从 systems-index task 4)
5. **最后**:M-12(填 perf budgets)+ L-1/L-2(ADR 性能章节)
6. **不修**:M-5 ~ M-11 接受现状(按 Key Insight)、L-3 不改 ADR 名

---

## Re-run

完成 Step 1-3 后,再次运行 `/adopt` 验证 BLOCKING 和 HIGH 全清。新 run 反映当前状态(不 diff)。
