class_name CharacterBase
extends Node

## 角色基类（Character Base）
##
## 为 MythSurvivor 所有玩家角色提供共享接口与字段。
## 采用方案 C：本类 extends Node，作为玩家场景的子节点挂载。
## 玩家场景根节点仍 extends CharacterBody2D，处理物理 / 碰撞。
##
## v0.3 起，所有角色（修行者、孙悟空、哪吒 等）都通过此基类提供：
## - 共享属性字段（生命 / 移速 / 拾取等）
## - 专属能量条配置（每个角色不同）
## - 升级池过滤接口（按角色过滤可见升级项）
## - 行为回调（击杀 / 受伤 / 能量满）
##
## 详见 docs/02_CHARACTER_DESIGN.md §3

# 角色专属能量满时触发，供 HUD 和子类（如 SunWukong）emit；基类自己不 emit
@warning_ignore("UNUSED_SIGNAL")
signal energy_full_triggered

# ─────────────────────────────────────────────
# 标识与显示
# ─────────────────────────────────────────────

## 唯一角色 ID，例 "cultivator" / "sun_wukong" / "nezha"
@export var character_id: String

## 角色显示名，例 "修行者" / "齐天大圣"
@export var display_name: String

# ─────────────────────────────────────────────
# 基础属性
# ─────────────────────────────────────────────

## 气血上限
@export var max_health: float = 100.0

## 移动速度（像素 / 秒）
@export var move_speed: float = 200.0

## 拾取半径（像素）
@export var pickup_radius: float = 50.0

# ─────────────────────────────────────────────
# 初始装备
# ─────────────────────────────────────────────

## 开局自动装备的武器 ID（对应 04_SKILL_DESIGN.md 武器总表）
@export var initial_weapon_id: String

# ─────────────────────────────────────────────
# 专属能量条配置
# ─────────────────────────────────────────────

## 角色专属能量条配置
##
## 期望键（feature-worker / HUD 实施时必须遵守）：
##   "max_value": float       能量条最大值，例 30.0（灵气）
##   "fill_color": Color      进度条颜色
##   "label": String          能量名称，例 "灵气" / "三昧真火" / "天眼槽"
##   "auto_trigger": bool     满时是否自动触发（true: 孙悟空、女娲；false: 杨戬可手动留蓄）
##
## 修行者无能量条，此字段保持空 Dictionary 即可。
@export var energy_bar_config: Dictionary

# ─────────────────────────────────────────────
# 解锁条件
# ─────────────────────────────────────────────

## 角色解锁条件（v0.3 未启用门控，所有角色默认解锁）
@export var unlock_condition: Dictionary

# ─────────────────────────────────────────────
# 五行属性（v0.4+ 启用）
# ─────────────────────────────────────────────

## 角色五行属性，影响伤害克制
## 合法值："neutral" / "metal" / "wood" / "water" / "fire" / "earth"
## v0.3 阶段保持 "neutral"，v0.4 启用五行系统后再分配
@export var element: String = "neutral"

# ─────────────────────────────────────────────
# 共享行为接口（子类按需 override）
# ─────────────────────────────────────────────

## 专属能量满时调用。
## 子类（孙悟空：触发七十二变；女娲：切换五色轮 等）override 实现具体逻辑。
## 注意：基类同时发出 energy_full_triggered signal，便于 HUD 等外部订阅，
## 不要在 override 中阻止 signal 发出。
func _on_energy_full() -> void:
	pass

## 返回该角色允许出现在升级池中的升级项 ID 列表。
## 由升级池（player.gd 的 _get_upgrade_pool）调用过滤。
## 返回 String 数组，每个元素应与升级池字典的 "id" 键匹配。
func _get_allowed_upgrade_ids() -> Array[String]:
	return []

## 击杀敌人回调。子类按需充能（如孙悟空 +1 灵气，精英 +5）。
## 参数类型 Node 而非 Enemy，避免循环依赖。
func _on_kill(enemy: Node) -> void:
	pass

## 玩家受伤回调。子类按需充能（如哪吒受伤 +10 真火）。
func _on_damaged(amount: float) -> void:
	pass
