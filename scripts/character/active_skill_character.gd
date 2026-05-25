class_name ActiveSkillCharacter
extends CharacterBase

## 主动技能角色基类（v0.4 引入）
##
## 管理 4 个主动技能槽的 cooldown 状态。
## 子类（如 SunWukongV2）通过 _register_skill() 注册槽位 + max_cd，
## 通过 override _on_cast_skill() 实现具体技能逻辑。
##
## ⚠️ ActiveSkillCharacter 是项目内**唯一**面向"主动按键释放"角色的基类。
## 其他全自动角色（修行者 / 哪吒 / 杨戬 / 女娲 / 盘古）不应继承此类。
## 详见 docs/decisions/0003-sun-wukong-active-skills.md

# 4 个技能槽中任一槽的 cooldown / unlocked 状态变化时 emit
# 参数：slot (0-3), remaining (秒), max_cd (秒), unlocked
signal skill_cooldown_changed(slot: int, remaining: float, max_cd: float, unlocked: bool)

# ─────────────────────────────────────────────
# 4 槽状态数组（固定长度 4）
# ─────────────────────────────────────────────

var _skill_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _skill_max_cds: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _skill_unlocked: Array[bool] = [false, false, false, false]
var _skill_names: Array[String] = ["", "", "", ""]
# W211: 每槽当前技能等级（0=未解锁，1-4=已解锁等级）
var _skill_levels: Array[int] = [0, 0, 0, 0]


# 每帧推进 4 槽 cooldown
func _process(delta: float) -> void:
	for slot in range(4):
		if _skill_cooldowns[slot] > 0.0:
			_skill_cooldowns[slot] = maxf(_skill_cooldowns[slot] - delta, 0.0)
			# 通知 HUD（每帧都 emit 让倒计时显示流畅）
			skill_cooldown_changed.emit(
				slot,
				_skill_cooldowns[slot],
				_skill_max_cds[slot],
				_skill_unlocked[slot]
			)


# 注册一个技能槽（子类调用，通常在 _init 或 _ready）
# slot: 0-3 对应键位 1-4
# skill_name: 技能名（如"毫毛分身"），W213 角色选择 UI 可显示
# max_cd: 该技能 cooldown 秒数
# initial_unlock: 默认 false（待 Lv5/10/15/20 解锁）。true 表示开局自带 Lv1。
#   孙悟空 v2 设计：4 主动技能全部 initial_unlock=false，靠每 5 级选择解锁
func _register_skill(slot: int, skill_name: String, max_cd: float, initial_unlock: bool = false) -> void:
	if slot < 0 or slot > 3:
		push_warning("ActiveSkillCharacter._register_skill: invalid slot %d" % slot)
		return
	# 元数据：name 和 max_cd 总是写入，供后续解锁时复用
	_skill_names[slot] = skill_name
	_skill_max_cds[slot] = max_cd
	_skill_cooldowns[slot] = 0.0
	if initial_unlock:
		_skill_unlocked[slot] = true
		if _skill_levels[slot] == 0:
			_skill_levels[slot] = 1
	# 主动 emit 一次，让 HUD（即使已 _ready）能收到初始状态 / 锁定状态
	skill_cooldown_changed.emit(slot, 0.0, max_cd, _skill_unlocked[slot])


# 玩家按 1/2/3/4 键时由 player.gd 转发到这里（W212 接入）
# 返回 true 表示成功释放（cooldown 启动）
func cast_skill(slot: int) -> bool:
	if slot < 0 or slot > 3:
		return false
	if not _skill_unlocked[slot]:
		return false
	if _skill_cooldowns[slot] > 0.0:
		return false
	# 调用子类 override
	var success: bool = _on_cast_skill(slot)
	if success:
		_skill_cooldowns[slot] = _skill_max_cds[slot]
		skill_cooldown_changed.emit(slot, _skill_cooldowns[slot], _skill_max_cds[slot], true)
	return success


# 子类 override 实现具体技能逻辑
# 返回 true 表示技能成功释放（基类会启动 cooldown），false 表示释放失败（不消耗 cooldown）
func _on_cast_skill(_slot: int) -> bool:
	return false


# 查询接口（HUD 或调试用）
func get_skill_cooldown(slot: int) -> float:
	if slot < 0 or slot > 3:
		return 0.0
	return _skill_cooldowns[slot]


func get_skill_max_cd(slot: int) -> float:
	if slot < 0 or slot > 3:
		return 0.0
	return _skill_max_cds[slot]


func is_skill_unlocked(slot: int) -> bool:
	if slot < 0 or slot > 3:
		return false
	return _skill_unlocked[slot]


# 火眼金睛接口：返回对该 target 的伤害倍率（W206 预留）
# 默认返回 1.0（无加成）；SunWukong v2 子类 override 实现"对精英/Boss +20%"
func get_damage_modifier(_target: Node) -> float:
	return 1.0


# W211: 返回主动技能升级选项（供 LevelUpPanel 显示，最多 3 项 — LevelUpPanel 只有 3 按钮）
# 注意：每个槽的 name / max_cd 由子类（如 SunWukongV2）通过 _register_skill 预先注册。
# 未注册的槽（_skill_names[slot] == ""）跳过，避免显示"技能 N"占位项。
func get_skill_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for slot in range(4):
		var lv: int = _skill_levels[slot]
		var skill_name: String = _skill_names[slot]
		if skill_name == "":
			# 子类未注册该槽，跳过（避免出现"技能 N"占位项）
			continue
		if lv == 0:
			# 未解锁
			choices.append({
				"id": "wukong_skill_unlock_%d" % slot,
				"title": "悟得 %s" % skill_name,
				"description": "解锁第 %d 槽主动技能 Lv1" % (slot + 1),
			})
		elif lv < 4:
			# 可升级
			choices.append({
				"id": "wukong_skill_upgrade_%d" % slot,
				"title": "%s 精进" % skill_name,
				"description": "%s Lv%d → Lv%d" % [skill_name, lv, lv + 1],
			})
		# lv == 4 已满，跳过
	# LevelUpPanel 只有 3 按钮，限制返回前 3 项
	if choices.size() > 3:
		choices = choices.slice(0, 3)
	return choices


# W211: 应用主动技能升级（解锁或升级）
# id 格式: "wukong_skill_unlock_N" 或 "wukong_skill_upgrade_N"
# 注意：当前实现只更新 _skill_levels 状态（用于 HUD 显示和后续选项过滤），
# 武器/技能脚本实际等级同步将在 W212（SunWukongV2 场景接入）时实现。
func apply_skill_upgrade(id: String) -> void:
	if not id.begins_with("wukong_skill_"):
		return
	var slot: int = -1
	var is_unlock: bool = false
	var suffix: String = ""
	if id.begins_with("wukong_skill_unlock_"):
		is_unlock = true
		suffix = id.substr("wukong_skill_unlock_".length())
	elif id.begins_with("wukong_skill_upgrade_"):
		suffix = id.substr("wukong_skill_upgrade_".length())
	else:
		push_warning("ActiveSkillCharacter.apply_skill_upgrade: unknown id format: %s" % id)
		return
	# 防御性校验：suffix 必须是 0-3 的整数
	if not suffix.is_valid_int():
		push_warning("ActiveSkillCharacter.apply_skill_upgrade: invalid slot suffix: %s" % id)
		return
	slot = int(suffix)
	if slot < 0 or slot > 3:
		push_warning("ActiveSkillCharacter.apply_skill_upgrade: slot out of range: %d" % slot)
		return
	# 子类必须先 _register_skill 才能解锁 / 升级
	if _skill_names[slot] == "":
		push_warning("ActiveSkillCharacter.apply_skill_upgrade: slot %d not registered" % slot)
		return
	if is_unlock:
		# 解锁：从 lv 0 → 1（name 和 max_cd 已由 _register_skill 写入）
		if _skill_levels[slot] == 0:
			_skill_levels[slot] = 1
			_skill_unlocked[slot] = true
			skill_cooldown_changed.emit(slot, 0.0, _skill_max_cds[slot], true)
	else:
		# 升级：lv N → N+1（上限 4）
		if _skill_levels[slot] >= 1 and _skill_levels[slot] < 4:
			_skill_levels[slot] += 1
			skill_cooldown_changed.emit(slot, _skill_cooldowns[slot], _skill_max_cds[slot], true)


# W211: 查询当前技能等级
func get_skill_level(slot: int) -> int:
	if slot < 0 or slot > 3:
		return 0
	return _skill_levels[slot]


## W213: 降低指定技能槽的 cooldown 上限（用于升级项 cooldown -2s / -5s）
## 不影响 _skill_cooldowns（当前正在 tick 的计时）
## min_cd 防御：cooldown 不可低于 1.0s
## HUD 防御：若当前 remaining > new max，clamp 防止进度条溢出
func reduce_skill_max_cd(slot: int, amount: float) -> void:
	if slot < 0 or slot > 3:
		return
	_skill_max_cds[slot] = maxf(_skill_max_cds[slot] - amount, 1.0)
	_skill_cooldowns[slot] = minf(_skill_cooldowns[slot], _skill_max_cds[slot])
	# 通知 HUD 更新 max_cd 显示
	skill_cooldown_changed.emit(slot, _skill_cooldowns[slot], _skill_max_cds[slot], _skill_unlocked[slot])
