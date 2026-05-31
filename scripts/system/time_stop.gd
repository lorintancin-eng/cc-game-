class_name TimeStop
extends Node2D

## 定身钟的全屏冻结场（道具效果）。duration 秒内，每帧把组 enemies 的 velocity 归零
## （Boss 仅减速 ×0.5，避免 trivial 化），到期销毁。复用混天绫领域模式（全屏、无伤害）。
## 仅调用 enemy 公共 API（velocity / 组），不碰冻结的 enemy.gd。

const BOSS_SLOW_FACTOR: float = 0.5

var duration: float = 3.0

var _elapsed: float = 0.0


func setup(new_duration: float) -> void:
	duration = maxf(new_duration, 0.1)
	_elapsed = 0.0


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_apply_freeze()
	if _elapsed >= duration:
		queue_free()


## 普通/精英敌 velocity 归零（定身）；Boss ×0.5（减速）。每帧调用。
func _apply_freeze() -> void:
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if not enemy is Node2D:
			continue
		if not "velocity" in enemy:
			continue
		if enemy.is_in_group(&"bosses"):
			enemy.set("velocity", (enemy.get("velocity") as Vector2) * BOSS_SLOW_FACTOR)
		else:
			enemy.set("velocity", Vector2.ZERO)
