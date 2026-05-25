# 归档目录

本目录用于存放**已被新文档替代或仅有历史价值**的旧文档。

---

## 归档结构

按版本组织：

```
archive/
├── v0.2/
│   ├── core_gameplay_v_02.md       # 内容已迁入 03_CORE_GAMEPLAY.md
│   ├── QA_V0_2_CHECKLIST.md        # 内容已迁入 11_ACCEPTANCE_CHECKLIST.md
│   ├── RELEASE_NOTES_V0_2.md       # 历史归档（草稿状态）
│   └── TASKS.md                    # 内容已迁入 10_TASK_BACKLOG.md
└── v0.3/
    └── V0_3_CHARACTERS.md          # 内容已迁入 02_CHARACTER_DESIGN.md
```

---

## 归档策略

| 文档类型 | 归档时机 |
|---|---|
| 单版本设计文档 | 内容迁入通用文档后 |
| 单版本任务清单 | 该版本所有任务完成且合入 main 后 |
| 单版本 QA 清单 | 同上 |
| 单版本 release notes | 发布后立即归档（哪怕仅为草稿） |
| 已废弃 ADR | 状态变为 Deprecated 后 |

---

## Phase 2 迁移计划

在 PMF Phase 2 时将以下文档移到本目录：

| 源文档 | 目标位置 |
|---|---|
| docs/core_gameplay_v_02.md | docs/archive/v0.2/core_gameplay_v_02.md |
| docs/QA_V0_2_CHECKLIST.md | docs/archive/v0.2/QA_V0_2_CHECKLIST.md |
| docs/RELEASE_NOTES_V0_2.md | docs/archive/v0.2/RELEASE_NOTES_V0_2.md |
| docs/TASKS.md | docs/archive/v0.2/TASKS.md |
| docs/V0_3_CHARACTERS.md | docs/archive/v0.3/V0_3_CHARACTERS.md |

迁移完成后，根目录 docs/ 下不再存在带版本号的散文档。

---

## 引用归档文档

其他文档引用归档内容时使用相对路径：

```markdown
详见 [archive/v0.2/core_gameplay_v_02.md](archive/v0.2/core_gameplay_v_02.md)
```

---

## 不要在此目录创建新文档

归档目录只接收"曾经活跃，现在归档"的文档。新文档应放在 `docs/` 根目录或对应子目录。
