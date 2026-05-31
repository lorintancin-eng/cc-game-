# Visual Entity & Screen Inventory — MythSurvivor

> **Generated**: 2026-05-31
> **Scope**: Full roster (含已设计未实现的 v0.5-v0.6 内容 — 作为完整美术路线图)
> **Sources**: `design/gdd/*.md` (28 GDDs), `design/levels/`, `design/ux/hud.md` + `menu-system.md`, `design/style/07_VISUAL_STYLE_GUIDE.md` + `08_UI_UX_GUIDE.md`, `design/art/art-bible.md`, `design/registry/entities.yaml`, `design/narrative/`

## 状态图例

| 标记 | 含义 |
|---|---|
| ✅ Implemented | 代码已实现（`.tres`/场景/脚本存在） |
| 📋 Designed | GDD 已设计，未实现（v0.4-v0.6） |
| 🔮 Future | v0.5+ 计划，细节未定 |
| **Spec** 列 | 资产规格状态（全部 `Needed` — 尚无 `/asset-spec` 规格文件） |

> **美术基准**：游戏 v0.4 用占位色块剪影 + 程序粒子；正式美术是 v0.7 升级 pass（art-bible §8.9）。角色/敌人为剪影式，非精细 sprite。

---

## Characters / Protagonists (6)

剪影优先（无面孔）。各有唯一 32px 顶冠剪影、专属剪影色、能量条、足部 VFX。Sprite sheet：idle 4-6 / attack 3-4 / hit 2 帧（art-bible §5.4/§8.4）。显示高度 ~48-64px，纵横比 ≥1.8:1。

| # | 角色 | 剪影色 | 标志形状 | 能量条 | 空闲律动 | Build | Spec |
|---|---|---|---|---|---|---|---|
| C00 | 修行者 Cultivator（默认） | 黛灰 #3C3C46 + 朱砂披帛 | 腰间铜铃 + 桃木剑 | 无（基线） | 匀速上下（铃延迟） | ✅ | Needed |
| C01 | 孙悟空 Sun Wukong | 黑红 #3C1E1E | 头顶金色单线圆环（金箍） | 灵气 Spirit-Qi (max 30) | 左右微摆+旋转 | ✅ | Needed |
| C02 | 哪吒 Nezha | 暗红 #8C2828 + 青莲底光 | 脚下莲花座外展 | 三昧真火 (max 100) | 莲花座缓慢旋转 | 📋 | Needed |
| C03 | 杨戬 Yang Jian | 银白 #C8C8D2 | 额间天眼竖线（金色直线）+ 身后三尖两刃刀 | 天眼槽 (max 100) | 几乎静止，天眼偶发金色脉冲 | 📋 | Needed |
| C04 | 女娲 Nuwa | 五色光环（轮换）+ 飘带 + 身后破碎五色石 | 头部五色散射 | 造化·五色轮（每 4s 轮换 金→木→水→火→土） | 五色光环缓慢轮转 | 📋 | Needed |
| C05 | 盘古 Pangu | 灰黑 #232328，体型 1.3-1.4× | 混沌球（黑白旋转，>头部）+ 超大体型 | 开天力 (max 100；+1/s) | 极慢沉降再升浮（呼吸感 ~2.5s） | 📋 | Needed |

> 女娲剪影色"五色轮换"需在 `/asset-spec` 阶段定义循环规格（冲突 #6）。孙悟空七十二变变身形态见 Active Skills VFX。

---

## Enemies / Creatures

`.tres` 驱动的 Polygon2D 剪影（占位），`body_color` 着色，`body_scale` 缩放。显示 ~32-48px。各带 28×4px HP 条。Sheet：idle 2-3 / attack 2-3 帧，单一识别细节。

### Stage 1 — 荒山废庙 (✅ 全部实装)

| # | 敌人 | 类别/原型 | body_scale | 移动 | 识别线索 | Spec |
|---|---|---|---|---|---|---|
| E01 | 游魂 wandering_soul | normal / CHASE | 1.0 | chase | 飘散下摆；灰白魂影 #B4B4B9 基线 | Needed |
| E02 | 狐妖 fox_spirit | normal-fast / CHASE | 0.96 | 最快 (132) | 速度/绕圈 profile | Needed |
| E03 | 鬼火 ghost_flame | normal-weaving / WAVE_CHASE | 0.90 | 正弦摆动 | 飘浮火团，难追踪 | Needed |
| E04 | 纸人 paper_doll | filler / CHASE | 0.82 | chase | 最弱；纸张沙沙波次填充 | Needed |
| E05 | 石魈 stone_golem | tank / CHASE | 1.35 | 慢 (54) | 岩块肩部，移动墙 | Needed |
| E06 | 山魈精英 shanxiao_elite | **elite** / CHASE | 1.55 | chase | 唯一 Stage1 精英；金边 2-3px + 头顶词缀图标 | Needed |

### Stage 2 — 幽都鬼市 (✅ 全部实装；stage-2-enemies.md 为准)

| # | 敌人 | 类别 | body_scale | 移动 | 识别线索 | Spec |
|---|---|---|---|---|---|---|
| E11 | 灯笼鬼 lantern_ghost | filler / WAVE_CHASE | 0.9 | 飘移摆动 | 鬼市唯一光源；摇晃灯笼辉光（lantern-gold） | Needed |
| E12 | 怨婴 resentful_infant | swarm / CHASE | 0.6 | 极快 (150) | 微小死婴；志怪剪影；群涌（pallid） | Needed |
| E13 | 鬼差 ghost_bailiff | fast hunter / CHASE | 1.05 | 快 (124) | 阴界差役 + 勾魂锁链（indigo-black） | Needed |
| E14 | 镇墓兽 tomb_guardian | tank / CHASE | 1.4 | 慢 (58) | 古墓构造体，移动墙（jade-stone） | Needed |
| E15 | 黑白无常 impermanence_elite | **elite** / CHASE | 1.5 | elite 中偏快 (80) | 谢必安(白无常)，swift 词缀；金边+图标（bone-white） | Needed |
| E16 | 黑无常（可选 iron_bones 双子） | elite variant | — | — | 配对生成，deferred（stage-2 OQ-1） | 🔮 Future |

### Stage 3 — 昆仑残境 (🔮 v0.5 计划，无 `.tres`，仅 06_LEVEL §6.3 名册)

| # | 敌人 | 定位 | Spec |
|---|---|---|---|
| E21 | 山魈（普通版） | 高速 | Needed |
| E22 | 蛇妖 | 远程 | Needed |
| E23 | 黑羽妖 | 飘浮 | Needed |
| E24 | 古阵守卫 | 肉盾/tank | Needed |
| E25 | 古阵守卫精英 | elite | Needed |

---

## Bosses (3)

屏幕级剪影 (120px+) + 子轮廓，朱红边光 4-5px。Attack sheet 6-8 帧。均扩展计划中的 `BossBase`（BossState 机 + 3 技能 + 单向激怒）。

| # | Boss | 关卡 | body_scale | 招式视觉 | 激怒视觉 (≤30%HP) | Build | Spec |
|---|---|---|---|---|---|---|---|
| B01 | 荒年兽 Famine Beast | Stage 1 | 1.7 | 冲撞(红线 240px 0.7s windup) / 爆裂(红环 r58 警告 1.05s→橙爆 0.18s) / 召唤(瞬发) | 体色→深朱砂 #C8240E approx + 红色激怒光环 | ✅ | Needed |
| B02 | 鬼市判官 Ghost Market Judge | Stage 2 | 1.85 | 勾魂锁链(链条 telegraph 0.8s→冲) / 判笔(朱砂红环 r66 警告 1.3s→爆+0.2s 墨迹) / 生死簿召唤(瞬发) | 体色→苍蓝(0.55,0.62,0.95)；判笔半径×1.2(66→79) | ✅ | Needed |
| B03 | 裂境山君 Cracked-Realm Mountain Lord | Stage 3 | TBD | 阵法型 + 大范围伤害（未设计） | TBD | 🔮 v0.5 | Needed |

> 判官持 生死簿(Book of Life&Death) + 判笔(Vermilion Brush) — 标志视觉道具。
> Boss 召唤小怪：荒年兽→纸人+游魂；判官→怨婴+灯笼鬼。

---

## Weapons / 法宝 / Projectiles

投射物 ~8-24px，强制并入 `atlas_projectile.png`。各需投射物/命中 sprite + 拖尾。

### A. 通用 / 修行者武器 (W001-W006, ✅ 实装)

| # | 武器 | 流派 | 攻击模式 | VFX 色 | Spec |
|---|---|---|---|---|---|
| W001 | 追魂符 Talisman | 符法 | 追踪投射，nearest-1，12° 散布 | 朱砂红 | Needed |
| W002 | 飞剑 Flying Sword | 剑修 | 定向穿刺 (3 hits) | 银白/寒蓝 | Needed |
| W003 | 雷电符咒 Thunder Law | 雷法 | 区域打击，K-nearest，r72 | 紫白/银电 | Needed |
| W004 | 八卦阵 Bagua Array | 阵法 | 旋转 tick 光环，r82 | 青铜金 | Needed |
| W005 | 爆裂符 Explosive Talisman | 符法 | 投射 + 爆炸 (r58) | 朱砂红 | Needed |
| W006 | 山河印 Mountain Seal | 法宝 | 重型范围砸 (r118) | 朱金 | Needed |

### B. 孙悟空武器 (W101 ✅ / W102-103 主动技能)

| # | 武器 | 攻击模式 | 视觉 | Spec |
|---|---|---|---|---|
| W101 | 如意金箍棒 Jingu Bang v2 | 近身旋转棒 (r90，持续) | 简化棒剪影，顺时针旋转 | Needed |
| W102 | 金箍棒·变长 | 定向突刺，屏幕级 (600px) + 击退 | 棒延伸至屏幕边 | Needed |
| W103 | 毫毛分身（武器形态） | 召唤 3 小猴投射→自爆 (r70) | 小猴剪影，接触爆炸 | Needed |

### C. 角色专属武器 (📋 v0.4-v0.6 设计)

| # | 武器 | 角色 | 攻击模式 | 视觉/元素 | Spec |
|---|---|---|---|---|---|
| W201 | 火尖枪 | 哪吒 | 定向穿刺 + 灼烧地面 | 火红，火拖尾 | Needed |
| W202 | 混天绫 | 哪吒 | 区域束缚 + DOT + 减速 | 符法朱砂，绫带区域 | Needed |
| W203 | 乾坤圈 | 哪吒 | 自动锁定 + 返回（回旋镖） | 朱金，旋转环 | Needed |
| W301 | 三尖两刃刀 | 杨戬 | 近战 3-hit，90° 扇形 | 银白，斩弧 | Needed |
| W302 | 哮天犬 | 杨戬 | 召唤宠物（自主追击 + 减速） | 黑色狼崽剪影 + 绿色双瞳 | Needed |
| W303 | 天眼真火 | 杨戬 | 全屏锁定激光（最低 HP） | 雷法紫白，光束 | Needed |
| W401 | 补天石 | 女娲 | 天降单点，元素 = 当前五色轮 | 五色（变化） | Needed |
| W402 | 五色丝 | 女娲 | 玩家下方持续区域 (r120) | 五色丝线 | Needed |
| W403 | 造人术 | 女娲 | 召唤短命分身 | 分身剪影 | Needed |
| W501 | 开天斧 | 盘古 | 巨型十字斩 (600×600 屏幕级) | 法宝，巨大十字 | Needed |
| W502 | 阴阳二气 | 盘古 | 双追踪球（阴减速 + 阳灼烧 + 融合） | 黑白双球 | Needed |
| W503 | 开辟 | 盘古 | 全屏清场（终极） | 屏幕级爆发 | Needed |

### D. 进化武器 (🔮 v0.6+，概念)
万符归宗 / 七杀剑阵 / 五雷正法 / 乾坤护体阵 / 镇岳神印 / 如意万千 / 三才合击 — 现有武器的视觉变体。

---

## Active Skills VFX (孙悟空, ✅ 实装；键 1-4)

| # | 技能 | VFX 描述 | Spec |
|---|---|---|---|
| AS1 | 毫毛分身 Hair Clones | 2-3 独立 AI 小猴剪影单位生成，各自索敌 | Needed |
| AS2 | 筋斗云 Cloud Step | 冲刺 200px + 无敌帧（云拖尾 VFX） | Needed |
| AS3 | 七十二变 72 Transformations | 玩家剪影变 5 形态之一 + 青烟环：giant_ape / golden_eagle / stone_monkey / dragon_shadow / spirit_fox（Lv4 强制 giant_ape） | Needed |
| AS4 | 定身术 Immobilize | AOE 冻结 (r150-280)；Lv3+ 结束爆发 (dmg35, r100)；**无视觉指示器**（status OQ-2） | Needed |
| AS5 | 火眼金睛 Fire Eyes（被动） | 对精英/Boss 增伤 (1.2-1.55×)；无 HUD/VFX 指示（stack 0-7，OQ-6） | Needed |

---

## Environment / Terrain (每关 4 层 Parallax + Tileset + 叙事母题)

水墨剪影风，3-4 色阶，柔化 1-2px 羽化边缘，假阴影。Tileset 64×64。L0 黛黑变体(0.1-0.2) / L1 暮云灰(0.3-0.4) / L2 主战斗层(1.0) / L3 前景氛围半透 50-70%(1.2-1.5)。

### Stage 1 — 荒山废庙 ✅
- **色温**：蓝灰冷偏 (+15-20%)。几何：折断线。
- **Tileset/道具**：庙宇地基石台、倒塌山门残碣、断裂石柱(倾斜 5-25°)、锈蚀香炉、枯树树根、旧符纸。
- **叙事母题 6**：倒塌镇妖石碑、纸钱+香灰(低密度白烟)、锁链残断(拖痕出屏)、倒置法器(桃木剑尖向下)、枯荷池遗迹、半开庙门(+仓皇足迹)。

### Stage 2 — 幽都鬼市 ✅ (战斗) + 鬼市间隙 ✅ (交易)
- **色温**：灰黄/阴黄 (+20-25%)。几何：有机曲线。鬼火密度 +40%。
- **Tileset/道具**：地面裂缝(分叉)、阴界石碑(左倾 3-8°)、鬼市摊位(外鼓顶+压扁柜台)、水滴形灯笼(摇摆，鬼火青内发光)、鬼市拱门(不对称)、摊位帘布(半透 60%)。
- **叙事母题 6**：灯笼有光无摊主、账本+算盘、阴币堆叠、碎镜面(暮云灰填充，离 LeavePortal ≥200px)、引路幡旗(1:5，±5° 摇)、空置轿椅(铺垫判官)。
- **交易间隙**：复用 Stage2 环境但 Contemplative 情绪，色温暖向旧纸黄(不向金黄)，道具密度更高(中型≤12/小型≤20)，允许半透前景遮挡物。

### Stage 3 — 昆仑残境 🔮 v0.5
- **色**：昆仑石色 #E8DDBB(~40% 亮度)。几何：正多边形 + 同心圆(破碎)。
- **道具**：浮空阵台(漂移 ±3px/8-12s)、灵脉沟渠遗迹(同心圆断开)、仙人石阶(倾斜 10-30°)、古阵符文地面(八卦布局，临近发光)、浮空石(可破获奖励)。
- **叙事母题 4**：未完成封印符文、刻名祭柱残件、悬而未落灵脉能量球、镌神明印记残臂。

---

## Functional Objects (~6)

| # | 物体 | 视觉/形状 | 行为 | Build | Spec |
|---|---|---|---|---|---|
| F01 | 镇妖碑 Demon Seal | 正六边形底座 + 垂直方尖柱；进度环 Line2D r44(48 点满，顺时针填充)；碰撞 r72/80 | 2:00 风险收益；8s 封印；压力爬升 | ✅ | Needed |
| F02 | 鬼商摊 Trade Stall | 内弯屋顶弧 + 矩形柜台；AVAILABLE 时幽光；~1s 入区填充条 | Area2D；交易间隙；3 商品 + Leave | ✅ | Needed |
| F03 | LeavePortal 离开门户 | 立式椭圆 + 内部涡旋切线；鬼火青 #5078B4 | 走入式出口（鬼市无时限） | ✅ | Needed |
| F04 | 经验球 Experience Orb | 正圆形（场景唯一"完美几何"）；鬼火青；~8-16px | 拾取半径内自动收集 | ✅ | Needed |
| F05 | 法宝残匣 Weapon-pickup | TBD | 镇妖碑奖励变体（随机武器解锁） | 📋 | Needed |
| F06 | HealthOrb / GoldOrb | TBD | 自动收集 | 🔮 | Needed |

> 镇妖碑完成奖励变体(06_LEVEL §4.3)：XP 爆发 / 即时升级 / HP 恢复 30-50% / 5s 护盾 / 武器解锁 / 临时增益 +50%。

---

## VFX / Particles (~28 事件)

GPUParticles2D 用于瞬时爆发；CanvasItem shader 用于常驻光环(vfx OQ-1)。调色：朱砂红/青铜金/鬼火青/黑红妖气。上限：≤50 粒子/效果，Boss 战 ≤900 粒子 + ≤18 系统。

| # | VFX | 触发 | 时长 | 描述 | Build | Spec |
|---|---|---|---|---|---|---|
| V01 | 受击闪白 Hit flash | damage_taken | 0.1s | 白色 tint；0.05s 节流 | ⚠️ 未实现 | Needed |
| V02 | 死亡消散 Death dissolve | died | ≤0.5s | sprite 淡出 + 黑烟 puff | ✅ | Needed |
| V03 | 死亡 XP 迸出 | enemy death | — | 黑烟散 + XP 球迸出 | ✅ | Needed |
| V04 | 投射物拖尾 | weapon fire | per-lifetime | 按武器色编码 | ✅ | Needed |
| V05 | 八卦阵旋纹 | always-on | 持续 | 旋转青铜金三才纹 | ✅ | Needed |
| V06 | 落雷 Thunder strike | thunder hit | 0.3s | 天降鬼火青/紫白电 | ✅ | Needed |
| V07 | 爆炸 Explosion | explosive impact | ~0.18s | 橙/红半径爆发 | ✅ | Needed |
| V08 | 镇妖碑封印辉光 | sealing | 持续 | 环周柔脉冲 | ✅ | Needed |
| V09 | 封印金阵 Seal complete | seal_completed | 0.6s | 金色爆发 + 射线，古阵纹扩展 | ✅ | Needed |
| V10 | 悟道闪光 Level-Up | upgrade_applied | 0.4s | 玩家周柔白脉冲 + 选卡时朱砂/金法印粒子 | ✅ | Needed |
| V11 | Boss 冲撞 telegraph | windup | 0.7s | 半透朱砂危险线 | ✅ | Needed |
| V12 | Boss 爆裂 telegraph | warning | 1.05/1.3s | 半透红环扩展 | ✅ | Needed |
| V13 | Boss 召唤 | summon | 瞬时 | (v0.4 无特殊 VFX) | ✅ | Needed |
| V14 | Boss 激怒光环 | HP≤30% | 持续 | 体色变 + 光环(荒年兽深朱砂/判官苍蓝) | ✅ | Needed |
| V15 | 暴击反馈 Crit (v0.4+) | crit | 短暂 | 闪白+震屏+特殊粒子；色盲:"!"前缀+斜纹 | 📋 | Needed |
| V16 | 精英命中 | elite damage | 短暂 | 闪白 + 词缀色微爆 | 📋 | Needed |
| V17 | 灼烧 Burn DOT | burn type | per 0.1s tick | (⚠️未实现；地面燃烧环) | 📋 | Needed |
| V18 | 减速拖尾 Slow trail | slowed enemy | 持续 | (⚠️未实现) | 📋 | Needed |
| V19 | 定身冻结 Immobilize | 定身术 | duration | 敌冻结(无视觉指示) | ⚠️ | Needed |
| V20 | 妖王临近 vignette | 4:30 warning | 渐进 | 屏边暗红 #5A1818 vignette 加深 + 背景粒子向中央聚拢 | 📋 | Needed |
| V21 | Boss 登场闪黑 | Boss enters | 0.12s | 全局黑闪(非白) + 边光"点亮"扩展 | 📋 | Needed |
| V22 | 道消身陨去色 | HP=0 | ~0.8s | 色彩→水墨黑白；法器残光 1.5s 熄灭；镜头下坠 0.2s | 📋 | Needed |
| V23 | 镇妖碑生成信标 | seal spawn | 1s | (⚠️保留 — 需加 1s 信标闪) | 📋 | Needed |
| V24 | 胜利时间缓速 | Boss death | ~1.5s | time-scale 0.8x→0.5x→0x | 📋 | Needed |
| V25 | 状态图标/叠层 | per-status | 持续 | (⚠️保留 — burn/slow/iron-bones 叠层) | 📋 | Needed |
| V26 | 筋斗云冲刺拖尾 | 筋斗云 | dash | 云拖尾 | 📋 | Needed |
| V27 | 七十二变青烟 | 七十二变 | transform | 青烟环 + 形态切换 | ✅ | Needed |
| V28 | 五行元素命中反馈 | element match (v0.5) | 短暂 | 元素色粒子爆发 + 独特 SFX + 伤害"+/-" | 🔮 | Needed |

---

## UI Screens (8)

`CanvasLayer`, `process_mode = WHEN_PAUSED`。决定类卡片=竖向圆角矩形(古典书页,~12%)；状态条=横向斜切矩形(古兵器,无圆角)。

| # | 界面 | Build | 内容 | Spec |
|---|---|---|---|---|
| U01 | 主菜单 Main Menu | 📋 | Start/Continue/Options/Quit（当前直接进角色选择） | Needed |
| U02 | 角色选择 择神而行 | ✅ | v0.4 两按钮(修行者/弼马温)；扩展为 2×3 网格+预览 | Needed |
| U03 | HUD | ✅ | 见 HUD Elements | Needed |
| U04 | 升级面板 悟道三选一 | ✅ | 3 功法卡片；古卷展开仪式；首选项自动焦点 | Needed |
| U05 | 交易面板 鬼市交易 | ✅ | 3 商品卡(血契/魂典/阴债)+Leave；妖潮预览；5s 引线；血契双击确认 | Needed |
| U06 | 道消身陨 GameOver | ✅ | 结算数据+"再入劫境"；黑白水墨；极简文字 | Needed |
| U07 | 封印完成 StageClear | 📋 (v0.4 并入 GameOver) | 胜利总结；金阵；"封印完成"卷轴 | Needed |
| U08 | 入定 Pause Menu | 📋 | Continue/Restart/Quit（ESC 当前未绑定） | Needed |

---

## HUD Elements (~16)

背景旧纸黄半透(≤75%)。旧纸黄上文字须黛黑/暮云灰(art-bible §7.5 C-03)。数字=等宽体；标签=思源宋体；标题=汇文明朝体。

| # | 元素 | 位置 | 视觉 | Spec |
|---|---|---|---|---|
| H01 | 气血条 + 数值 | 顶左 | 朱砂红 #C83232 条 + "气血 N/M" 等宽(≥14px,色盲必需) | Needed |
| H02 | 修为条 | 顶左 | 青蓝 #5078B4 条 + "修为"标签 + current/required | Needed |
| H03 | 境界 Level | 顶左 | "境界 N" | Needed |
| H04 | 历劫时间 Timer | 顶中 | "MM:SS / 03:00" 等宽；4:30→旧纸黄+震动/字号(非红,C-02) | Needed |
| H05 | 镇妖数 Kill Count | 顶右 | "镇妖数 N" | Needed |
| H06 | Stage Status | 顶中 | boss 警告/通关/失败文字 | Needed |
| H07 | 妖王预警横幅 | 顶中坠入 | "妖王降临" 朱砂红白底，垂直震颤 | Needed |
| H08 | Boss HP 条 | 顶中叠层 | 横向矩形 + 内缩边框(铭文牌匾) | Needed |
| H09 | 镇妖碑进度条 | 世界空间/HUD 顶中 | 六边形轮廓(匹配碑座) | Needed |
| H10 | 能量条 EnergyPanel(角色专属) | 底左 | 灵气(孙,圆环)/三昧真火(哪吒,火苗)/天眼槽(杨戬)/造化五色轮(女娲)/开天力(盘古)；修行者隐藏 | Needed |
| H11 | 技能槽 SkillPanel(孙悟空) | 底右 | 4 冷却指示器(圆形扇形进度) | Needed |
| H12 | 低血心跳叠层 | 全屏 | 红 tint + 亮度脉冲/心跳(非红边框闪,C-01)；<25%HP 触发 | Needed |
| H13 | 升级确认 toast | 中屏 | upgrade_applied 时 1.5s 提示 | Needed |
| H14 | 精英词缀图标 | 精英 HP 条上 | 印章简化(20-24px,金黄,按词缀形状区分:iron_bones/swift) | Needed |
| H15 | 伤害浮动数字 | 目标上方 | (⚠️可选 v0.4+,未实现)暴击 off-white+红光，0.05s 合并 | Needed |
| H16 | 五色轮指示器(女娲) | 底左能量区 | 当前+下个元素+倒计时 | Needed |

---

## Audio (SFX / Music / Ambient — 仅描述)

3 总线(SFX/Music/UI under Master)。v0.4 未实现。原创或公共领域中国神话来源；无商业游戏模仿。

### SFX 类别
| # | 类别 | 描述 |
|---|---|---|
| A01 | 武器命中(每武器,≤0.15s) | 朱砂笔触感/铜铃震/雷霆轻响 |
| A02 | 玩家受伤 | 短促闷响(避免过度刺激) |
| A03 | 敌人接触(每原型) | 石魈沉重/狐妖低语/鬼火闪烁/纸人沙沙/游魂呜咽 |
| A04 | 敌人死亡 | 纸钱飘散/散烟；3 变体通用 sting 池 |
| A05 | Boss 技能提示 | 冲撞:windup 咆哮+砸；爆裂:升调哨+裂；召唤:召唤嗡鸣 |
| A06 | Boss 激怒 | 戏剧兽吼 + 环境音乐变调 |
| A07 | Boss 死亡 | 长鸣钟 + 散烟 + 1s 静默 |
| A08 | 升级悟道(≤0.8s) | 古铃 + 风过 |
| A09 | 镇妖碑封印(≤1s) | 金色调钟/持续低频钟声 |
| A10 | 妖王降临 | 山崩 + 兽吼 + 钟鼓 |
| A11 | 低血心跳 | 环境心跳层(<25%HP 淡入) |
| A12 | XP 球拾取/UI/交易 | 柔和提示音 |

### 音乐(每关)
| # | 关卡 | 方向 |
|---|---|---|
| M01 | 一·荒山古道 | 古琴 + 低频弦乐 + 风过山道 |
| M02 | 二·幽都鬼市 | 阴冷笛 + 鬼市嘈杂底噪 + 铜铃 |
| M03 | 三·昆仑残境(v0.5) | 法器钟磬 + 持续低频 + 风雷 |
| M04 | Boss 音乐 | 张力曲，鼓 + 鬼声采样；boss_spawned 时 0.3s 交叉淡入，SFX 总线 duck -3dB |
| M05 | 胜利/静默 cue | stage_cleared 时静默/胜利 cue |

**音量基线**：主音乐 60% / 音效 80% / 警示 100% / 环境 40%（UI 90% 最响）。

---

## Other

- **字体**(需授权/采购)：思源宋体(正文/信息)、汇文明朝体 或 方正清刻本悦宋(神话命名)、Roboto Mono/JetBrains Mono(数字)。
- **叙事/过场文本**：文白夹杂古风；摊主黑话("以血换力，可愿？")；开场过场文字淡出露出首波游魂。
- **6 状态光照调色板**(引擎后处理,非 sprite)：探索(冷中性)/升级(暖烛旧纸黄)/妖王临近(冷蓝紫月食)/Boss(暗红 vs 冷蓝双源)/封印完成(金破晓前)/道消身陨(冷蓝黑水墨)。
- **图集需求**(art-bible §8.5)：atlas_enemy_common(2048²)、atlas_enemy_elite、atlas_projectile(1024×2048)、atlas_pickup(512²)、atlas_ui_hud(2048²)、atlas_vfx_particles(1024²)。玩家+Boss 独立 sheet。
- **镜头震屏**：保留 API(Camera GDD)；Boss/精英命中 + 爆炸触发；需限频防光敏。
- **五行元素 VFX 色**(v0.5)：金白 #F5EBC8 / 木青 #5A965A / 水蓝 #3C82B4 / 火红 #DC5032 / 土黄 #AA8246 — 区别于主调色板。

---

## 已废弃 / 被取代（不进生产）

- **06_LEVEL_DESIGN.md §6.2 旧 Stage-2 名册**：妖僧残念(光环)、镜妖精英(镜妖)，及"灯笼鬼自爆/鬼差远程"的旧描述——**全部被 stage-2-enemies.md 实装名册取代**，不生成资产规格。

---

## 冲突 / 歧义记录（来自 GDD 扫描）

1. **Stage-2 名册冲突**（已在上方"已废弃"处理）：06_LEVEL 旧名册 vs 实装名册。
2. **关卡时长**：文档 5 分钟(300s) vs 实装 3 分钟(180s)，7 关交错结构。HUD 计时器可能显示 /05:00 或 /03:00。
3. **荒年兽伤害**：GDD 散文处写 18，`.tres` 实装 36（D-B1 ×2.0，已于本会话修复 GDD）。仅文字，不影响资产。
4. **交易 buff 简化**：血契实装为 ×1.15/层乘法（非加法 ceiling-clamp）；魂典=通用池抽取。无资产影响。
5. **七十二变双定义**：灵气满自动触发(v0.2) vs 键-3 主动技能(v2/ADR-0003)。实装=主动技能。同一小猴+青烟视觉。
6. **女娲剪影色**："五色轮换"需在 `/asset-spec` 定义循环规格。
7. **镇妖碑半径**：72px(碰撞) vs 80px(06_LEVEL)；视觉环 44px 不变。
