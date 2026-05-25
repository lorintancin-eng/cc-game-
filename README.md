# MythSurvivor

MythSurvivor 是一个使用 Godot 4.6 开发的 2D 俯视角自动战斗 Roguelite 生存游戏项目，题材灵感来自中国神话。

当前版本：v0.4-pre-qa。项目使用 [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) 模板进行开发治理。

## 核心方向

- 游戏引擎：Godot 4.6（Forward+ 渲染，Jolt Physics，D3D12 on Windows）
- 编程语言：GDScript
- 玩法形态：俯视角生存场景、自动攻击、敌人波次、升级选择、拾取物和单局成长
- 题材方向：原创中国神话灵感世界观、敌人、法宝、武器和关卡主题
- 初始平台：优先面向 PC

## 原创性政策

本项目不得复刻任何现有商业游戏的素材、角色、UI、地图、命名、成长结构或数值平衡。中国神话只作为宽泛灵感来源。所有设计、资源、调校和表现都必须是 MythSurvivor 的原创内容，或来自许可证兼容的合法资源。

## 仓库

- 主仓库：<https://github.com/lorintancin-eng/cc-game->

## 项目结构

```text
res://
  scripts/          # GDScript 玩法代码（character / enemy / player / system / ui / weapon）
  scenes/           # Godot 场景文件
  resources/        # Godot .tres 资源（敌人配置等）
  project.godot     # Godot 项目入口
  icon.svg          # 应用图标

design/             # 游戏设计文档（gdd / narrative / levels / style）
docs/               # 技术文档（architecture / engine-reference）
production/         # 生产管理（milestones / sprints / qa / archive）
.claude/            # CCGS agent / skill / hook / rules 配置
```

## 主要设计文档入口

- 游戏设计：`design/gdd/game-concept.md`
- 核心玩法：`design/gdd/03_CORE_GAMEPLAY.md`
- 角色设计：`design/narrative/02_CHARACTER_DESIGN.md`
- 孙悟空 v2：`design/narrative/SUN_WUKONG_V2_DESIGN.md`
- 技术架构：`docs/architecture/ARCHITECTURE.md`
- 版本路线图：`production/milestones/roadmap.md`
- 任务待办：`production/sprints/backlog.md`

## 开发约定

- 代码风格：`.claude/rules/gdscript.md`
- 协作协议：`docs/COLLABORATIVE-DESIGN-PRINCIPLE.md`
- 工作流指南：`docs/WORKFLOW-GUIDE.md`
- 起点命令：`/start`（CCGS 引导）或 `/project-stage-detect`（项目状态分析）

## 当前状态

MVP v0.1 已完成并发布，v0.2 功能完成，v0.3 角色系统设计中（孙悟空），v0.4 待 QA。
