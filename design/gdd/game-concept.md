# MythSurvivor 游戏设计文档

## 愿景

MythSurvivor 是一款使用 Godot 4.x 和 GDScript 开发的 2D 俯视角自动战斗 Roguelite 生存游戏。玩家需要在逐渐增强的神话威胁中生存，收集经验，选择升级，并通过自动武器和法宝效果形成每局不同的战斗构筑。

游戏应当快速、清晰、可重复游玩，并通过原创的中国神话灵感敌人、武器、法宝和关卡主题建立辨识度。

## 设计支柱

1. 清晰的生存压力：敌人行为和危险区域应能被玩家快速读懂。
2. 自动战斗与有意义的构筑选择：玩家主要负责移动和走位，攻击由系统自动触发。
3. 原创神话气质：使用中国神话作为灵感，而不是复制任何商业作品的表达。
4. 数据驱动迭代：敌人数值、武器行为、升级、波次和掉落应尽量通过资源或结构化数据配置。
5. 先完成小型 MVP：先实现最小可玩的完整生存循环，再扩展内容。

## 原创性规则

- 不要复制商业游戏的角色、敌人、武器、UI、地图、关卡布局、图标、特效、音频或数值。
- 不要复刻任何现有商业生存 Roguelite 游戏的成长结构、物品池、敌人阵容或调校曲线。
- 所有名称、剪影、机制、数值和呈现方式都必须原创，或以公共领域神话为基础进行新的表达。

## 核心玩法循环

1. 玩家进入一张生存场景。
2. 敌人围绕可游玩区域按波次生成。
3. 玩家手动移动，攻击自动触发。
4. 被击败的敌人掉落经验或资源。
5. 玩家升级，并从少量选项中选择一个升级。
6. 敌人压力随时间逐步增强。
7. 玩家被击败或存活到目标时长后，本局结束。
8. 显示结算结果，后续可接入局外成长。

## MVP 范围

MVP 只包含验证核心循环所需的最小内容：

- 一个可控制的玩家原型。
- 一张竞技场式测试地图。
- 基础摄像机跟随。
- 基础敌人生成。
- 两到三种原创敌人类型。
- 一到两种自动武器。
- 经验收集与升级选择。
- 一个小型原创升级池。
- 生命值、伤害、死亡和单局计时。
- 显示生命、等级、经验、计时和击杀数的 HUD。
- 游戏结束与重新开始流程。
- 便于调试的数据配置。

## MVP 之外的内容

- 多个生态区或大地图。
- 永久局外成长。
- 存档与读档。
- 完整叙事战役。
- 复杂首领阵容；如 MVP 需要，只考虑一个简单终局压力敌人。
- 高级物品稀有度系统。
- 复杂装备背包。
- 最终品质美术和音频。
- 在线功能。

## 题材方向

使用原创方式表达中国神话意象：

- 天庭秩序、山灵、水府、符箓、玉器、青铜铃、月相、香火、纸符、星图、古代异兽和幽冥仪仗等。
- 避免直接套用商业作品中的视觉身份。神话人物可以启发概念，但游戏内设计应使用原创名称、造型、定位和机制。

## 玩家幻想

玩家应感受到自己像一名游走于神怪之夜的修行者或驱邪者，通过符咒、法宝和元素术法组成临时战斗体系，在不断逼近的妖异威胁中生存。

## 战斗方向

- 玩家移动由手动控制。
- 攻击根据冷却、目标规则或区域规则自动触发。
- 武器应拥有不同的目标选择方式和位置关系。
- 伤害数值必须原创，并通过实际试玩调校，不得复制现有游戏。
- MVP 阶段避免隐藏复杂度，优先使用清晰的属性效果：伤害、冷却、范围、投射物数量、移动速度、生命值和拾取半径。

## 成长方向

MVP 成长以单局内成长为主：

- 敌人掉落经验。
- 升级时暂停或减缓游戏，并展示升级选项。
- 升级会修改本局属性或武器行为。
- 升级描述必须简洁，并准确反映机制效果。

MVP 完成后再考虑局外成长。

## MVP 成功标准

MVP 达成时应满足：

- 玩家可以开始一局游戏、移动、生存、击败敌人、获得经验、选择升级，并进入游戏结束或胜利状态。
- 核心系统边界足够清晰，后续可以添加更多敌人、武器和升级，而不需要重写主循环。
- 游戏能呈现原创的中国神话生存动作气质。
- 项目运行时没有 Godot 脚本解析错误或损坏的场景引用。

## Acceptance Criteria

(Mirror of the Chinese "MVP 成功标准" section above, in CCGS-standard English heading for `/adopt`, `/create-stories`, and other skills that grep for `## Acceptance`.)

A run of the MVP build counts as passing if **all** of the following are true:

- [ ] Player can start a run from the main scene without script parse errors
- [ ] Player can move (WASD / arrow keys) and the camera follows
- [ ] At least one enemy type spawns and engages the player
- [ ] At least one auto-fired weapon hits enemies and deals damage
- [ ] Defeated enemies drop XP, and the player can pick it up automatically
- [ ] On level-up, the run pauses and shows 3 upgrade choices; selecting one applies the effect and resumes
- [ ] HUD displays HP / Level / XP / run timer / kill count, all updating live
- [ ] Player HP can reach zero — game-over screen appears, and the player can restart
- [ ] No `.gd` parse errors, no broken `res://` scene references, no orphaned signal connections
- [ ] No copied / clone content from any commercial Roguelite survivor game

Single-system GDDs (per `design/gdd/systems-index.md`) will inherit and extend this list with system-specific verification criteria.
