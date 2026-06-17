extends Node
## Headless test runner. Run with:
##   godot --headless tests/TestRunner.tscn
## Exits non-zero on any failure. Autoloads load because we run as a scene.

const UPGRADE_DB := preload("res://src/data/UpgradeDB.gd")
const FUNNY_DB := preload("res://src/data/FunnyNumberDB.gd")
const FMT := preload("res://src/data/NumberFormatter.gd")

var _passed := 0
var _failed := 0

func _ready() -> void:
	# Prevent the test run from clobbering the player's real save file.
	SaveSystem.save_enabled = false
	print("=== NUMBER GOES UP — test runner ===")
	_test_formatter()
	_test_funny_priority()
	_test_click_and_buy()
	_test_cost_scaling()
	_test_rate_and_mult()
	_test_slow_persists_through_prestige()
	_test_mystery_hidden_bonus()
	_test_save_roundtrip()
	print("=== results: %d passed, %d failed ===" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _ok(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  %s" % name)
	else:
		_failed += 1
		print("  FAIL  %s" % name)

func _reset_state() -> void:
	GameState.number = 0.0
	GameState.total_earned = 0.0
	GameState.upgrades.clear()
	GameState.prestige_level = 0
	GameState.ascension_level = 0
	GameState.transcendence_level = 0
	GameState.slow_mult = 1.0
	GameState.red_count = 0
	GameState.mystery_count = 0
	GameState.funny_sightings.clear()
	GameState.total_clicks = 0
	GameState.mark_rate_dirty()

## Grant effectively-infinite funds and buy, so tests can focus on mechanics.
func _grant_buy(id: String) -> void:
	GameState.number = 1.0e15
	GameState.total_earned = max(GameState.total_earned, 1.0e15)
	assert(GameState.buy(id), "grant_buy failed for " + id)

func _test_formatter() -> void:
	print("[formatter]")
	_ok(FMT.format(1234.0, "extended") == "1,234", "extended commas")
	_ok(FMT.format(9999999.0, "extended") == "9,999,999", "extended 7-digit visible")
	_ok(FMT.format(10000000.0, "extended") == "10M", "extended abbreviates at 10M")
	_ok(FMT.format(15000.0, "normal") == "15K", "normal abbreviates at 5 digits")
	_ok(FMT.format(9999.0, "normal") == "9,999", "normal full below 10K")
	_ok(FMT.format(80085.0, "unhinged") == "80085", "unhinged no commas")
	_ok(FMT.format(15000.0, "nerd") == "1.5e4", "nerd scientific")
	_ok(FMT.format(8008135.0, "unhinged") == "8008135", "unhinged full boobies visible")

func _test_funny_priority() -> void:
	print("[funny numbers]")
	# 69 is a substring of 169.
	_ok(FUNNY_DB.match("169") != null, "detects 69 in 169")
	_ok(FUNNY_DB.match("169").pattern == "69", "169 -> 69")
	# 8008135 contains 8008, 80085, 8008135 — longest wins.
	var m: Variant = FUNNY_DB.match("8008135")
	_ok(m != null and m.pattern == "8008135", "8008135 -> BOOBIES (longest)")
	# 80085 contains 8008 and 80085 — 80085 wins (longer).
	m = FUNNY_DB.match("80085")
	_ok(m != null and m.pattern == "80085", "80085 -> BOOBS")
	_ok(FUNNY_DB.match("88888") == null, "no match returns null")

func _test_click_and_buy() -> void:
	print("[click & buy]")
	_reset_state()
	_ok(GameState.click_power() == 1.0, "base click power 1")
	GameState.click()
	_ok(GameState.number == 1.0, "click adds 1")
	_ok(GameState.total_clicks == 1, "click counted")
	# Give number to afford click_1 (cost 10).
	GameState.number = 100.0
	GameState.total_earned = 100.0
	var bought := GameState.buy("click_1")
	_ok(bought, "buy click_1 succeeds")
	_ok(GameState.upgrade_owned("click_1") == 1, "click_1 owned=1")
	_ok(GameState.click_power() == 2.0, "click power now 2")
	# Second click_1 costs 10*1.15 = 11.5.
	_ok(absf(GameState.upgrade_cost("click_1") - 11.5) < 0.01, "second click_1 cost 11.5")
	# Insufficient funds.
	GameState.number = 1.0
	_ok(not GameState.buy("auto_3"), "buy auto_3 fails when broke")

func _test_cost_scaling() -> void:
	print("[cost scaling]")
	_ok(absf(UPGRADE_DB.cost("auto_1", 0) - 15.0) < 0.001, "auto_1 base cost 15")
	_ok(absf(UPGRADE_DB.cost("auto_1", 1) - 15.0 * 1.15) < 0.001, "auto_1 cost x1.15")
	_ok(absf(UPGRADE_DB.cost("auto_1", 10) - 15.0 * pow(1.15, 10)) < 0.001, "auto_1 cost x1.15^10")

func _test_rate_and_mult() -> void:
	print("[rate & multipliers]")
	_reset_state()
	_grant_buy("auto_1")  # +1/s
	_ok(absf(GameState.effective_rate() - 1.0) < 0.001, "auto_1 gives 1/s")
	_grant_buy("auto_2")  # +5/s
	_ok(absf(GameState.effective_rate() - 6.0) < 0.001, "auto_1+auto_2 = 6/s")
	# Prestige +2%.
	GameState.prestige_level = 1
	GameState.mark_rate_dirty()
	_ok(absf(GameState.effective_rate() - 6.0 * 1.02) < 0.001, "prestige +2% applies to rate")
	# Slow button halves-ish after 7 buys (0.9^7).
	_reset_state()
	for i in 7:
		_grant_buy("slow")
	_ok(absf(GameState.slow_mult - pow(0.9, 7)) < 0.001, "slow_mult = 0.9^7")

func _test_slow_persists_through_prestige() -> void:
	print("[prestige]")
	_reset_state()
	GameState.total_earned = 10000.0
	_grant_buy("slow")
	_grant_buy("slow")
	var slow_before := GameState.slow_mult
	_ok(GameState.can_prestige(), "can prestige at 10K total")
	GameState.prestige()
	_ok(GameState.prestige_level == 1, "prestige level 1")
	_ok(GameState.number == 0.0, "number reset on prestige")
	_ok(GameState.upgrades.is_empty(), "upgrades reset on prestige")
	_ok(GameState.red_count == 0, "red count reset on prestige")
	_ok(absf(GameState.slow_mult - slow_before) < 0.001, "slow_mult PERSISTS through prestige")
	_ok(absf(GameState.prestige_mult() - 1.02) < 0.001, "prestige mult = 1.02")

func _test_mystery_hidden_bonus() -> void:
	print("[mystery hidden bonus]")
	_reset_state()
	_grant_buy("auto_1")  # 1/s baseline
	var rate_before_any := GameState.effective_rate()
	# Buy 6 mystery buttons — no hidden bonus yet (bonus at every 7th).
	for i in 6:
		_grant_buy("mystery")
	GameState.mark_rate_dirty()
	_ok(absf(GameState.effective_rate() - rate_before_any) < 0.0001, "6 mystery: no bonus yet")
	# 7th triggers +0.777%.
	_grant_buy("mystery")
	GameState.mark_rate_dirty()
	_ok(absf(GameState.effective_rate() - rate_before_any * 1.00777) < 0.001, "7th mystery: +0.777% hidden")
	# 14th triggers a second (7 more: 7 -> 14).
	for i in 7:
		_grant_buy("mystery")
	GameState.mark_rate_dirty()
	_ok(absf(GameState.effective_rate() - rate_before_any * pow(1.00777, 2)) < 0.001, "14th mystery: 2nd hidden bonus")

func _test_save_roundtrip() -> void:
	print("[save roundtrip]")
	_reset_state()
	_grant_buy("auto_2")
	GameState.number = 12345.6
	GameState.total_earned = 99999.0
	GameState.prestige_level = 3
	GameState.slow_mult = 0.81
	GameState.funny_sightings = {"69": 5, "420": 2}
	var snap: Dictionary = GameState.serialize()
	snap.erase("_checksum")
	# Simulate a fresh load.
	_reset_state()
	GameState.deserialize(snap)
	_ok(absf(GameState.number - 12345.6) < 0.01, "number restored")
	_ok(absf(GameState.total_earned - 99999.0) < 0.01, "total_earned restored")
	_ok(GameState.upgrade_owned("auto_2") == 1, "upgrades restored")
	_ok(GameState.prestige_level == 3, "prestige restored")
	_ok(absf(GameState.slow_mult - 0.81) < 0.001, "slow_mult restored")
	_ok(GameState.funny_sightings.get("69", 0) == 5, "funny sightings restored")
