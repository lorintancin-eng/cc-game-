## 哪吒武器解锁门控（NezhaWeaponBase）。
##   - 默认 starts_locked=false → 开局解锁（火尖枪=初始武器）
##   - starts_locked=true → 开局锁定（混天绫 / 乾坤圈），unlock() 后解锁
## 锁定时 _process 直接 return（停火），由升级池「悟得…」项调用 unlock()。
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/weapon -gexit

extends "res://tests/helpers/test_base.gd"

const NezhaWeaponBaseScript = preload("res://scripts/weapon/nezha/nezha_weapon_base.gd")


func test_weapon_unlocked_by_default() -> void:
	var w = NezhaWeaponBaseScript.new()
	add_child_autofree(w)  # _ready 运行
	assert_true(w.is_unlocked(), "默认 starts_locked=false → 开局解锁")


func test_starts_locked_weapon_is_locked_until_unlock() -> void:
	var w = NezhaWeaponBaseScript.new()
	w.starts_locked = true
	add_child_autofree(w)  # _ready 读 starts_locked → _is_unlocked=false

	assert_false(w.is_unlocked(), "starts_locked=true → 开局锁定")

	w.unlock()
	assert_true(w.is_unlocked(), "unlock() → 解锁")
