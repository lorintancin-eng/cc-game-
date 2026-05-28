## Unit tests for the aggregate contact-damage ceiling (Combat Story 008,
## Core Rule 8 + Formula 7) — AC-13 selection logic.
##
## The ceiling rule is: at most MAX_CONTACT_ATTACKERS (4) enemies may apply
## contact damage to the player on any single frame, and the chosen ones are
## the MOST-RECENTLY-ENTERED contacts. The selection is implemented as the pure
## static function Player.select_allowed_attackers(attackers, max), which this
## suite verifies deterministically WITHOUT physics or timing.
##
## NOT covered here (requires manual playtest — physics broadphase + Area2D
## overlap of 8 real enemies cannot be reliably simulated headlessly):
##   - The Area2D wiring (Enemy.register/unregister_contact_attacker)
##   - The Survival Budget feel target (~4.25s vs 4 Paper Dolls at HP=100)
## Those are flagged in story-008 as playtest-pending.
##
## AC-14 (player death sequence on a fatal hit) is already satisfied by the
## pre-existing Player.take_damage/_die guard chain (verified in
## hp_application_test.gd test_combat_player_* cases) — not re-tested here.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/combat -gexit

extends "res://tests/helpers/test_base.gd"

const PlayerScript = preload("res://scripts/player/player.gd")

const MAX: int = 4  # mirror of Player.MAX_CONTACT_ATTACKERS for readable assertions


# Build a contact-entry list. `specs` is an Array of [id, entry_time] pairs.
# Enemy stand-ins are plain Strings — select_allowed_attackers only stores and
# compares the value, so no Node management / physics is needed.
func _entries(specs: Array) -> Array:
	var out: Array = []
	for spec in specs:
		out.append({"enemy": spec[0], "entry_time": spec[1]})
	return out


# ─── Under / at the cap → everyone attacks ───────────────────────────────

func test_combat_aggregate_ceiling_under_cap_returns_all() -> void:
	# Arrange — 3 attackers, cap 4.
	var attackers := _entries([["e0", 0.0], ["e1", 0.1], ["e2", 0.2]])
	# Act
	var allowed: Array = PlayerScript.select_allowed_attackers(attackers, MAX)
	# Assert — all 3 fit under the ceiling.
	assert_eq(allowed.size(), 3, "under-cap: all attackers allowed")
	assert_true(allowed.has("e0") and allowed.has("e1") and allowed.has("e2"),
		"under-cap: every attacker present")


func test_combat_aggregate_ceiling_exactly_at_cap_returns_all() -> void:
	# Arrange — exactly 4 attackers, cap 4.
	var attackers := _entries([["e0", 0.0], ["e1", 0.1], ["e2", 0.2], ["e3", 0.3]])
	# Act
	var allowed: Array = PlayerScript.select_allowed_attackers(attackers, MAX)
	# Assert — no queueing at the boundary.
	assert_eq(allowed.size(), 4, "at-cap: all 4 allowed, none queued")


# ─── Over the cap → most-recently-entered win (AC-13 core) ───────────────

func test_combat_aggregate_ceiling_over_cap_keeps_four_most_recent() -> void:
	# Arrange — AC-13 canonical: 8 Paper Dolls, entry times 0.0 … 0.7.
	var attackers := _entries([
		["e0", 0.0], ["e1", 0.1], ["e2", 0.2], ["e3", 0.3],
		["e4", 0.4], ["e5", 0.5], ["e6", 0.6], ["e7", 0.7],
	])
	# Act
	var allowed: Array = PlayerScript.select_allowed_attackers(attackers, MAX)
	# Assert — exactly the 4 most-recently-entered (e4..e7); the older 4 excluded.
	assert_eq(allowed.size(), 4, "over-cap: capped to MAX_CONTACT_ATTACKERS")
	for recent in ["e4", "e5", "e6", "e7"]:
		assert_true(allowed.has(recent), "most-recent attacker %s must be allowed" % recent)
	for old in ["e0", "e1", "e2", "e3"]:
		assert_false(allowed.has(old), "older attacker %s must be gated out" % old)


func test_combat_aggregate_ceiling_five_attackers_excludes_oldest() -> void:
	# Arrange — count = MAX + 1; the single oldest entry must be queued.
	var attackers := _entries([
		["oldest", 1.0], ["a", 2.0], ["b", 3.0], ["c", 4.0], ["newest", 5.0],
	])
	# Act
	var allowed: Array = PlayerScript.select_allowed_attackers(attackers, MAX)
	# Assert
	assert_eq(allowed.size(), 4, "five attackers → 4 fire")
	assert_false(allowed.has("oldest"), "the single oldest attacker is queued out")
	assert_true(allowed.has("newest"), "the newest attacker always fires")


# ─── Selection is by entry_time, not array insertion order ───────────────

func test_combat_aggregate_ceiling_selects_by_entry_time_not_position() -> void:
	# Arrange — array order is shuffled relative to entry_time. The 4 highest
	# entry_times are 0.9, 0.8, 0.7, 0.6 (ids hi1..hi4), regardless of position.
	var attackers := _entries([
		["hi1", 0.9], ["lo1", 0.1], ["hi3", 0.7], ["lo2", 0.2],
		["hi2", 0.8], ["lo3", 0.3], ["hi4", 0.6],
	])
	# Act
	var allowed: Array = PlayerScript.select_allowed_attackers(attackers, MAX)
	# Assert
	assert_eq(allowed.size(), 4, "7 attackers → 4 fire")
	for hi in ["hi1", "hi2", "hi3", "hi4"]:
		assert_true(allowed.has(hi), "%s (high entry_time) must be selected" % hi)
	for lo in ["lo1", "lo2", "lo3"]:
		assert_false(allowed.has(lo), "%s (low entry_time) must be excluded" % lo)


# ─── Degenerate inputs ───────────────────────────────────────────────────

func test_combat_aggregate_ceiling_empty_returns_empty() -> void:
	var allowed: Array = PlayerScript.select_allowed_attackers([], MAX)
	assert_eq(allowed.size(), 0, "no contacts → no allowed attackers")
