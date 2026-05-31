# 道具/拾取物系统 ·「镇妖四宝」(Quick Design Spec)

> 状态：`[设计完→实现中]` — 2026-05-31
> 用户已批准：**全 4 个道具** + **敌死概率 / 精英Boss 必掉**。
> 参考：Vampire Survivors（烤鸡/吸尘器/念珠/钟表）。补充既有 `design/gdd/pickup-system.md`（经验球）。

---

## 1. Overview

地面掉落的**一次性消耗道具**：玩家走过去**踩上即触发**（存在式 Area2D，同鬼市摊位/传送门），效果立即结算。
暗黑志怪主题本地化。敌人死亡时按概率掉落。

## 2. 四宝（对标 VS 经典四件套）

| 道具 | 效果 | 数值(初拟,可调) | 视觉(占位) | 对标 |
|---|---|---|---|---|
| **灵丹** | 回复气血 | max_hp × **30%** | 朱砂红丹丸 | 烤鸡 |
| **聚灵符** | 吸取全屏经验灵光 | 全部 orb 即时收取 | 青蓝符纸 | 吸尘器 |
| **镇妖雷符** | 全屏妖物受伤 | **100** 伤(秒小怪/削精英Boss) | 金紫雷符 | 念珠 |
| **定身钟** | 全屏妖物冻结 | **3 秒**(Boss 减速×0.5) | 古铜钟 | 钟表 |

## 3. 掉落规则

- 普通敌死亡 **4%** 概率掉 1 个；**精英 / Boss 必掉**（100%）。
- 掉落**随机种类**；**低血时灵丹权重×2**（HP<50% 更易掉回血，同 VS）。
- 掉在死亡位置；存活 ~15s 后消失（避免堆积）。

## 4. 架构（数据驱动 + 可测 + 不碰冻结文件）

- **`PickupConfig`** (Resource)：type / 掉率 / 各效果参数。`PickupCatalog` 代码构建 4 个配置（同 StageOneConfig 模式）。
- **`Pickup`** (Area2D 节点 + 场景)：`pickup_type` + 参数；存在式检测(玩家在组 `player`)；踩上 → 按类型施放效果 → queue_free。`set_deferred("monitoring", true)`（死亡回调可能在物理刷新中）。
  - 灵丹 → `player.heal(player.max_hp × frac)`
  - 聚灵符 → 迭代组 `experience_orbs`：`player.gain_experience(orb.xp_value)` + `orb.queue_free()`
  - 镇妖雷符 → 迭代组 `enemies`：`take_damage(dmg)`
  - 定身钟 → 生成 **`TimeStop`** 节点(计时 3s)
- **`TimeStop`** (Node2D)：duration 内每帧把组 `enemies` 的 `velocity` 归零(Boss ×0.5)，到期 queue_free。复用混天绫领域模式(全屏、无伤)。
- **`PickupDropper`**(挂 Main / StageDirector 旁)：连 `EnemySpawner.enemy_killed(enemy)` → 掷概率(看 `is_elite` / 组 `bosses`)→ 选类型(低血权重)→ 在 `enemy.global_position` 生成 Pickup。
- **ExperienceOrb 改 1 行**：`_ready()` 加 `add_to_group(&"experience_orbs")`(非冻结文件)，供磁铁查找。

## 5. 已验证接口(调研)

`player.heal(amount)` / `player.max_hp` / `player.gain_experience(xp)`；`EnemySpawner.enemy_killed(enemy:Enemy)`；`enemy.is_elite`、组 `bosses`、`take_damage`、`velocity`、组 `enemies`；玩家根在组 `player`；Area2D `get_overlapping_bodies()`。

## 6. 实现切片(CI 绿逐片)

- **P1**：本规格 ✅
- **P2**：ExperienceOrb 加组 + `PickupDrops` 纯逻辑(掉率/选类型/低血加权/回血量) + 6 单测 ✅ `f64962a`
- **P3**：`Pickup` 节点 + 4 效果(heal/magnet/purge/freeze + TimeStop) + 场景 + 4 测试 ✅ `2829f96`
- **P4**：StageDirector 接 `enemy_killed` 掉落(精英/Boss必掉、低血灵丹加权) + 2 集成测试 ✅ `2ae3489`
- **✅ 镇妖四宝 = DONE**(P1-P4),281 测试绿。美术外观(占位多边形 + 颜色)交并行美术会话贴皮。

## 7. 约束

- **冻结文件不碰**：`enemy.gd`/`famine_beast_boss.gd`/`Enemy.tscn`/`FamineBeastBoss.tscn`。清屏/冻结只调 enemy 公共 API。
- **数据驱动**：道具数值走 PickupConfig，不硬编码。
- **原创**：自创"镇妖四宝"演绎,不抄 VS 美术/命名/数值。
