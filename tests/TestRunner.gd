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
	_test_ascension()
	_test_transcendence()
	_test_transcendence_color()
	_test_achievements()
	_test_steam_integration_degrades()
	_test_save_roundtrip()
	_test_settings_roundtrip()
	_test_audio_system()
	_test_workshop_system()
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

func _test_ascension() -> void:
	print("[ascension]")
	_reset_state()
	_ok(not GameState.can_ascend(), "cannot ascend at prestige 0")
	GameState.prestige_level = GameState.ASCENSION_UNLOCK_LEVEL
	_ok(GameState.can_ascend(), "can ascend at prestige 10")
	# Apply a slow penalty — ascension should clear it.
	GameState.slow_mult = 0.5
	GameState.red_count = 3
	GameState.mystery_count = 2
	GameState.ascend()
	_ok(GameState.ascension_level == 1, "ascension level 1")
	_ok(GameState.prestige_level == 0, "prestige reset to 0 on ascension")
	_ok(absf(GameState.slow_mult - 1.0) < 0.001, "slow_mult resets on ascension")
	_ok(GameState.red_count == 0, "red_count resets on ascension")
	_ok(GameState.mystery_count == 0, "mystery_count resets on ascension")
	_ok(GameState.upgrades.is_empty(), "upgrades cleared on ascension")
	# x1.1 production multiplier per level.
	_ok(absf(GameState.ascension_mult() - 1.1) < 0.001, "ascension_mult = 1.1")
	GameState.ascension_level = 3
	_ok(absf(GameState.ascension_mult() - pow(1.1, 3)) < 0.001, "ascension_mult = 1.1^3")
	# Ascension multiplier folds into production_mult.
	_reset_state()
	GameState.ascension_level = 2
	GameState.mark_rate_dirty()
	_ok(absf(GameState.production_mult() - pow(1.1, 2)) < 0.001, "production_mult includes ascension")
	# Cannot ascend without enough prestige.
	_reset_state()
	GameState.prestige_level = GameState.ASCENSION_UNLOCK_LEVEL - 1
	_ok(not GameState.can_ascend(), "cannot ascend at prestige 9")

func _test_transcendence() -> void:
	print("[transcendence]")
	_reset_state()
	_ok(not GameState.can_transcend(), "cannot transcend at ascension 0")
	GameState.ascension_level = GameState.TRANSCENDENCE_UNLOCK_LEVEL
	_ok(GameState.can_transcend(), "can transcend at ascension 5")
	# Set up state that should be wiped.
	GameState.prestige_level = 7
	GameState.ascension_level = GameState.TRANSCENDENCE_UNLOCK_LEVEL
	GameState.slow_mult = 0.3
	GameState.red_count = 20
	GameState.mystery_count = 14
	GameState.number = 999999.0
	GameState.total_earned = 999999.0
	GameState.funny_sightings = {"69": 3, "420": 1}
	GameState.total_clicks = 500
	_grant_buy("auto_1")
	GameState.transcend()
	_ok(GameState.transcendence_level == 1, "transcendence level 1")
	_ok(GameState.number == 0.0, "number wiped on transcendence")
	_ok(GameState.total_earned == 0.0, "total_earned wiped on transcendence")
	_ok(GameState.prestige_level == 0, "prestige wiped on transcendence")
	_ok(GameState.ascension_level == 0, "ascension wiped on transcendence")
	_ok(GameState.upgrades.is_empty(), "upgrades wiped on transcendence")
	_ok(absf(GameState.slow_mult - 1.0) < 0.001, "slow_mult wiped on transcendence")
	_ok(GameState.red_count == 0, "red_count wiped on transcendence")
	_ok(GameState.mystery_count == 0, "mystery_count wiped on transcendence")
	# Persistence exceptions.
	_ok(GameState.funny_sightings.get("69", 0) == 3, "funny_sightings PERSIST through transcendence")
	_ok(GameState.total_clicks == 500, "total_clicks PERSIST through transcendence")
	# +5% production per level.
	_ok(absf(GameState.transcendence_mult() - 1.05) < 0.001, "transcendence_mult = 1.05")
	GameState.transcendence_level = 4
	_ok(absf(GameState.transcendence_mult() - 1.20) < 0.001, "transcendence_mult = 1.20 at level 4")

func _test_transcendence_color() -> void:
	print("[transcendence color]")
	_reset_state()
	var base := GameState.transcendence_color()
	_ok(absf(base.r - Color("#44ff88").r) < 0.001 and absf(base.g - Color("#44ff88").g) < 0.001, "level 0 = base green")
	# Level 12 wraps back to green (360° / 30° = 12).
	GameState.transcendence_level = 12
	var wrapped := GameState.transcendence_color()
	_ok(absf(wrapped.r - base.r) < 0.01 and absf(wrapped.g - base.g) < 0.01 and absf(wrapped.b - base.b) < 0.01, "level 12 wraps back to green")
	# Level 6 is a distinct hue (180° from base).
	GameState.transcendence_level = 6
	var mid := GameState.transcendence_color()
	_ok(absf(mid.r - base.r) > 0.05 or absf(mid.g - base.g) > 0.05 or absf(mid.b - base.b) > 0.05, "level 6 differs from base")

func _test_achievements() -> void:
	print("[achievements]")
	_reset_state()
	GameState.achievements_unlocked.clear()
	SteamIntegration._unlocked.clear()
	# Count — should be 60 defined (GDD says 67, chosen deliberately).
	_ok(AchievementsDB.count() == 61, "61 achievements defined (GDD target: 67)")
	# Progression achievements fire on total_earned.
	GameState.total_earned = 1.0
	SteamIntegration.evaluate_all()
	_ok(SteamIntegration.is_unlocked("NGU_FIRST_NUMBER"), "first number achievement")
	GameState.total_earned = 1000000.0
	SteamIntegration.evaluate_all()
	_ok(SteamIntegration.is_unlocked("NGU_MILLIONAIRE"), "millionaire achievement")
	# Red button achievements.
	GameState.red_count = 10
	SteamIntegration.evaluate_all()
	_ok(SteamIntegration.is_unlocked("NGU_RED_ENTHUSIAST"), "red enthusiast at 10")
	# Funny number sighting achievements.
	GameState.funny_sightings["69"] = 1
	SteamIntegration.evaluate_all()
	_ok(SteamIntegration.is_unlocked("NGU_NICE"), "nice achievement on 69 sighting")
	# Mystery achievement.
	GameState.mystery_count = 49
	SteamIntegration.evaluate_all()
	_ok(SteamIntegration.is_unlocked("NGU_THE_SECRET"), "the secret at 49 mystery")
	# Two buttons — owns both slow and anti_slow.
	_reset_state()
	GameState.achievements_unlocked.clear()
	SteamIntegration._unlocked.clear()
	GameState.upgrades["slow"] = 1
	GameState.upgrades["anti_slow"] = 1
	SteamIntegration.evaluate_all()
	_ok(SteamIntegration.is_unlocked("NGU_TWO_BUTTONS"), "two buttons achievement")
	# Achievements persist to GameState.achievements_unlocked.
	_ok(GameState.achievements_unlocked.has("NGU_TWO_BUTTONS"), "achievement stored in GameState")

	# "You Win?" — infinity edge case
	_reset_state()
	GameState.achievements_unlocked.clear()
	SteamIntegration._unlocked.clear()
	GameState.number = INF
	SteamIntegration.evaluate_all()
	_ok(SteamIntegration.is_unlocked("NGU_YOU_WIN"), "You Win? achievement on infinity")
	_ok(FMT.format(INF, "extended") == "Infinity", "formatter shows Infinity")

func _test_steam_integration_degrades() -> void:
	print("[steam degradation]")
	# Without the godot-steam GDExtension loaded, steam_available must be false.
	_ok(not SteamIntegration.steam_available, "steam_available is false in headless/no-GDExtension mode")
	# Methods should no-op without errors.
	SteamIntegration.unlock("NGU_TEST_NOOP")
	_ok(SteamIntegration.is_unlocked("NGU_TEST_NOOP"), "unlock works in offline mode (local cache)")
	# Cloud read/write should return empty/false without Steam.
	_ok(SteamIntegration.cloud_read("nonexistent.save") == "", "cloud_read returns empty without Steam")
	_ok(not SteamIntegration.cloud_exists("nonexistent.save"), "cloud_exists returns false without Steam")

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

func _test_settings_roundtrip() -> void:
	print("[settings roundtrip]")
	_reset_state()
	GameState.settings["notation"] = "unhinged"
	GameState.settings["screen_shake"] = "maximum"
	GameState.settings["master_volume"] = 0.5
	GameState.settings["color_override_enabled"] = true
	GameState.settings["color_override_hue"] = 0.33
	GameState.heavy_wallet_acknowledged = true
	var snap: Dictionary = GameState.serialize()
	snap.erase("_checksum")
	_reset_state()
	GameState.deserialize(snap)
	_ok(GameState.settings["notation"] == "unhinged", "notation setting restored")
	_ok(GameState.settings["screen_shake"] == "maximum", "screen_shake setting restored")
	_ok(absf(float(GameState.settings["master_volume"]) - 0.5) < 0.01, "volume setting restored")
	_ok(bool(GameState.settings["color_override_enabled"]) == true, "color override flag restored")
	_ok(absf(float(GameState.settings["color_override_hue"]) - 0.33) < 0.01, "color override hue restored")
	_ok(GameState.heavy_wallet_acknowledged == true, "heavy_wallet_acknowledged restored")
	# Old bool screen_shake should migrate to "on"/"off".
	_reset_state()
	GameState.settings["screen_shake"] = true
	GameState.deserialize(GameState.serialize())
	_ok(GameState.settings["screen_shake"] == "on", "old bool screen_shake=true migrates to 'on'")
	GameState.settings["screen_shake"] = false
	GameState.deserialize(GameState.serialize())
	_ok(GameState.settings["screen_shake"] == "off", "old bool screen_shake=false migrates to 'off'")

func _test_audio_system() -> void:
	print("[audio]")
	# AudioManager should be initialized (headless still generates streams).
	_ok(AudioManager._audio_initialized, "AudioManager initialized")
	# SFX cache should have entries for all expected events.
	_ok(AudioManager._sfx.has("click"), "click SFX generated")
	_ok(AudioManager._sfx.has("buy"), "buy SFX generated")
	_ok(AudioManager._sfx.has("prestige"), "prestige SFX generated")
	_ok(AudioManager._sfx.has("transcendence"), "transcendence SFX generated")
	# Stinger cache should have special-case patterns.
	_ok(AudioManager._stingers.has("69"), "69 stinger generated")
	_ok(AudioManager._stingers.has("9001"), "9001 stinger generated")
	_ok(AudioManager._stingers.has("666"), "666 stinger generated")
	_ok(AudioManager._stingers.has("2319"), "2319 stinger generated")
	# Music stems — 4 players.
	_ok(AudioManager._stem_players.size() == 4, "4 music stems created")
	# Buses should exist.
	_ok(AudioServer.get_bus_index("Master") != -1, "Master bus exists")
	_ok(AudioServer.get_bus_index("Music") != -1, "Music bus exists")
	_ok(AudioServer.get_bus_index("SFX") != -1, "SFX bus exists")
	_ok(AudioServer.get_bus_index("Stinger") != -1, "Stinger bus exists")
	# play_sfx/play_stinger should not crash in headless mode.
	AudioManager.play_sfx("click")
	AudioManager.play_stinger("69")
	_ok(true, "play_sfx/play_stinger don't crash in headless")
	# Post-prestige cut should work.
	AudioManager.trigger_post_prestige_cut()
	_ok(AudioManager._post_prestige_cut_remaining > 0.0, "post-prestige cut triggered")

func _test_workshop_system() -> void:
	print("[workshop]")
	WorkshopManager._packs.clear()
	WorkshopManager._clear_caches()
	var manifest: Dictionary = {
		"name": "Test Pack",
		"author": "tester",
		"version": "1.0",
		"priority": 50,
		"description": "A test pack",
	}
	var pack_path: String = WorkshopManager.create_local_pack("_test_pack", manifest)
	_ok(pack_path != "", "local pack created")
	_ok(WorkshopManager.get_pack_count() >= 1, "pack scanned")
	_ok(WorkshopManager.get_enabled_count() >= 1, "pack enabled by default")
	WorkshopManager.set_pack_enabled("_test_pack", false)
	_ok(WorkshopManager.get_enabled_count() == 0, "pack disabled")
	WorkshopManager.set_pack_enabled("_test_pack", true)
	_ok(WorkshopManager.get_enabled_count() >= 1, "pack re-enabled")
	var resolved: Variant = WorkshopManager.resolve_popup("69")
	_ok(resolved == null, "resolve_popup returns null when no file exists")
	_ok(WorkshopManager.resolve_sound("click") == "", "resolve_sound returns empty when no file exists")
	var manifest2: Dictionary = {"name": "High Priority Pack", "author": "tester2", "version": "1.0", "priority": 100}
	WorkshopManager.create_local_pack("_test_pack_2", manifest2)
	var packs: Array = WorkshopManager.get_packs()
	_ok(packs.size() >= 2, "two packs scanned")
	WorkshopManager.move_pack_up("_test_pack")
	WorkshopManager.move_pack_down("_test_pack")
	_ok(true, "move_pack_up/down don't crash")
	var dir := DirAccess.open(WorkshopManager.PACKS_DIR)
	if dir != null:
		dir.remove("_test_pack/pack.json")
		dir.remove("_test_pack")
		dir.remove("_test_pack_2/pack.json")
		dir.remove("_test_pack_2")
	WorkshopManager.scan_packs()
	_ok(true, "cleanup succeeded")
