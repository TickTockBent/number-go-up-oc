extends Node
## Autoload singleton. Bridges game events to Steam via godot-steam (GDExtension).
## Detects the Steam class at runtime; if absent (no GDExtension, no Steam client,
## headless testing), every method no-ops gracefully so the game runs identically
## with or without Steam. The godot-steam GDExtension is NOT shipped prebuilt —
## see AGENTS.md "Steam integration" for how to compile & install it.

const STEAM_APP_ID := 480          # SpaceWar (Valve's test app). Replace with real app ID.
const HEAVY_WALLET_DLC_ID := 0     # Replace with the real DLC app ID when assigned.

signal achievement_unlocked(api_id: String, name: String)
signal dlc_status_changed(heavy_wallet_active: bool)

var steam_available: bool = false
var _steam: Object = null          # Ref to the Steam singleton when available
var _unlocked: Dictionary = {}     # api_id -> true (local cache, works without Steam)
var _idle_seconds: float = 0.0
var _last_click_unix: int = 0
var _stats_tab_open_seconds: float = 0.0
var _run_start_unix: int = 0
var _notation_changes: int = 0

func _ready() -> void:
	_run_start_unix = Time.get_unix_time_from_system()
	_last_click_unix = _run_start_unix
	_detect_steam()
	if steam_available:
		_initialize_steam()
	# Load achievement state from save (GameState carries it).
	_sync_achievements_from_save()
	# Wire game events. SteamIntegration self-subscribes so GameState stays decoupled.
	GameState.number_changed.connect(_on_gs_number_changed)
	GameState.upgrade_purchased.connect(on_upgrade_purchased)
	GameState.prestige_performed.connect(on_prestige_performed)
	GameState.ascension_performed.connect(_on_gs_layer_performed)
	GameState.transcendence_performed.connect(_on_gs_layer_performed)
	FunnyNumbers.sighting_recorded.connect(on_funny_sighting)
	SaveSystem.cheater_detected.connect(_on_cheater)
	GameState.offline_report.connect(_on_offline_report)

func _on_gs_number_changed(_n: float, _t: float) -> void:
	on_number_changed()

func _on_gs_layer_performed(_level: int, _quote: String) -> void:
	evaluate_all()

func _on_cheater() -> void:
	notify_cheater_detected()

func _on_offline_report(_gained: float) -> void:
	# Reconstruct offline seconds from the save's last_seen_unix.
	var elapsed := float(Time.get_unix_time_from_system() - GameState.last_seen_unix)
	if elapsed > 1.0:
		check_offline_return(elapsed)

func _detect_steam() -> void:
	# ClassDB.class_exists is the canonical runtime check for a loaded GDExtension.
	steam_available = ClassDB.class_exists("Steam")
	if steam_available:
		_steam = ClassDB.instantiate("Steam")
		print("[SteamIntegration] godot-steam GDExtension detected.")
	else:
		print("[SteamIntegration] godot-steam not found — running in offline mode. All Steam calls will no-op.")

func _initialize_steam() -> void:
	if _steam == null:
		return
	var response: Dictionary = _steam.steamInitEx(STEAM_APP_ID, false)
	var status: int = int(response.get("status", 1))
	if status > 0:
		print("[SteamIntegration] Steam init failed (status %d): %s" % [status, response.get("verbal", "")])
		steam_available = false
		return
	print("[SteamIntegration] Steam initialized. User: %s" % _steam.getPersonaName())
	_check_dlc()

func _process(delta: float) -> void:
	if steam_available and _steam != null:
		_steam.run_callbacks()
	_track_idle(delta)

# --- Achievement evaluation -------------------------------------------------
## Evaluate all achievements against current GameState. Called periodically and
## on key events. Safe to call repeatedly; only fires unlock once per achievement.
func evaluate_all() -> void:
	for entry in AchievementsDB.ACHIEVEMENTS:
		var api_id: String = entry.api_id
		if _unlocked.get(api_id, false):
			continue
		if _evaluate_condition(api_id):
			unlock(api_id)

func _evaluate_condition(api_id: String) -> bool:
	match api_id:
		# Progression (uses total_earned — "reach N" means lifetime, per GDD §10.1)
		"NGU_FIRST_NUMBER": return GameState.total_earned >= 1.0
		"NGU_THREE_DIGITS": return GameState.total_earned >= 100.0
		"NGU_KILO": return GameState.total_earned >= 1000.0
		"NGU_THE_K_WORD": return GameState.total_earned >= 10000.0
		"NGU_SIX_FIGURES": return GameState.total_earned >= 100000.0
		"NGU_MILLIONAIRE": return GameState.total_earned >= 1000000.0
		"NGU_EIGHT_DIGITS": return GameState.total_earned >= 10000000.0
		"NGU_BILLIONAIRE": return GameState.total_earned >= 1000000000.0
		"NGU_TRILLIONAIRE": return GameState.total_earned >= 1000000000000.0
		# Funny numbers — based on sighting history
		"NGU_NICE": return GameState.funny_sightings.has("69")
		"NGU_IF_YOU_KNOW": return GameState.funny_sightings.has("67")
		"NGU_BLAZE_IT": return GameState.funny_sightings.has("420")
		"NGU_CALCULATOR_HUMOR": return GameState.funny_sightings.has("80085")
		"NGU_ADV_CALCULATOR_HUMOR": return GameState.funny_sightings.has("8008135")
		"NGU_FLIP_YOUR_PHONE": return GameState.funny_sightings.has("5318008")
		"NGU_NUMBER_OF_THE_BEAST": return GameState.funny_sightings.has("666")
		"NGU_JACKPOT": return GameState.funny_sightings.has("777")
		"NGU_OVER_9000": return GameState.funny_sightings.has("9001")
		"NGU_LEET": return GameState.funny_sightings.has("1337")
		"NGU_THE_ANSWER": return _digit_string_contains("42")
		"NGU_2319": return GameState.funny_sightings.has("2319")
		"NGU_THE_FUSION": return GameState.funny_sightings.has("42069")
		"NGU_YEAH_BABY": return GameState.funny_sightings.has("1738")
		"NGU_NOT_FOUND": return GameState.funny_sightings.has("404")
		# Trap upgrades
		"NGU_ITS_RED": return GameState.red_count >= 1
		"NGU_RED_COLLECTION": return GameState.red_count >= 5
		"NGU_RED_ENTHUSIAST": return GameState.red_count >= 10
		"NGU_RED_IDENTITY": return GameState.red_count >= 25
		"NGU_ALL_RED_EVERYTHING": return GameState.red_count >= 50
		"NGU_SELF_SABOTAGE": return GameState.upgrade_owned("slow") >= 1
		"NGU_TERMINAL_VELOCITY_REVERSE": return _slow_penalty() >= 0.50
		"NGU_ASYMPTOTIC_AGONY": return _slow_penalty() >= 0.90
		"NGU_ZENOS_PARADOX": return _slow_penalty() >= 0.99
		"NGU_MYSTERY_1": return GameState.mystery_count >= 1
		"NGU_MYSTERY_7": return GameState.mystery_count >= 7
		"NGU_THE_SECRET": return GameState.mystery_count >= 49
		# Prestige layers
		"NGU_SAMSARA": return GameState.prestige_level >= 1
		"NGU_PRESTIGE_5": return GameState.prestige_level >= 5
		"NGU_DOUBLE_DIGITS": return GameState.prestige_level >= 10
		"NGU_META_RESET": return GameState.ascension_level >= 1
		"NGU_ASCENSION_5": return GameState.ascension_level >= 5
		"NGU_BEYOND_BEYOND": return GameState.transcendence_level >= 1
		"NGU_FULL_SPECTRUM": return GameState.transcendence_level >= 12
		"NGU_PRESTIGE_60S": return false  # Evaluated at prestige moment via check_prestige_speed()
		# Meta / behavioral
		"NGU_FIRST_CLICK": return GameState.total_clicks >= 1
		"NGU_THOUSAND_CLICKS": return GameState.total_clicks >= 1000
		"NGU_TEN_THOUSAND_CLICKS": return GameState.total_clicks >= 10000
		"NGU_IDLE_HANDS": return _idle_seconds >= 600.0
		"NGU_IDLE_MASTER": return _idle_seconds >= 3600.0
		"NGU_ALT_TABBED": return false  # Evaluated on offline return via check_offline_return()
		"NGU_THE_LONG_STARE": return _stats_tab_open_seconds >= 120.0
		"NGU_CARD_COLLECTOR": return false  # Evaluated via notify_cards_tab_opened()
		"NGU_NOTATION_NERD": return GameState.settings.get("notation", "") == "nerd"
		"NGU_UNHINGED_MODE": return GameState.settings.get("notation", "") == "unhinged"
		"NGU_HEAVY_WALLET": return GameState.heavy_wallet
		"NGU_CAUGHT_RED_HANDED": return SaveSystem.is_cheater_active() or _was_cheater_flagged
		"NGU_TWO_BUTTONS": return GameState.upgrade_owned("slow") >= 1 and GameState.upgrade_owned("anti_slow") >= 1
		"NGU_SPEEDRUN": return GameState.total_earned >= 1000000.0 and _run_elapsed() < 300.0
		"NGU_FULL_EXPERIENCE": return _owns_all_upgrade_types()
		"NGU_YOU_WIN": return is_inf(GameState.number)
		"NGU_NOT_OUR_PROBLEM": return WorkshopManager.player_toggled_pack and WorkshopManager.get_enabled_count() > 0
		"NGU_LIAR": return _notation_changes >= 10
		"NGU_THE_PRESTIGE_PRESTIGE": return false  # Evaluated at prestige moment via check_prestige_speed()
		"NGU_FULL_CIRCLE": return GameState.last_prestige_number > 0 and int(floor(GameState.number)) == GameState.last_prestige_number
		"NGU_67_ACHIEVEMENTS": return _all_others_unlocked(api_id)
		_: return false

var _was_cheater_flagged: bool = false

func _slow_penalty() -> float:
	return 1.0 - GameState.slow_mult

func _run_elapsed() -> float:
	return float(Time.get_unix_time_from_system() - _run_start_unix)

func _digit_string_contains(pattern: String) -> bool:
	var current_int := int(floor(GameState.number))
	return str(current_int).find(pattern) != -1

func _owns_all_upgrade_types() -> bool:
	for id in UpgradeDB.UPGRADES.keys():
		if GameState.upgrade_owned(id) < 1:
			return false
	return true

func _all_others_unlocked(exclude_id: String) -> bool:
	for entry in AchievementsDB.ACHIEVEMENTS:
		if entry.api_id == exclude_id:
			continue
		if not _unlocked.get(entry.api_id, false):
			return false
	return true

# --- Unlock -----------------------------------------------------------------
func unlock(api_id: String) -> void:
	if _unlocked.get(api_id, false):
		return
	_unlocked[api_id] = true
	GameState.achievements_unlocked[api_id] = true
	var entry: Variant = AchievementsDB.get_by_api_id(api_id)
	var name: String = api_id
	if entry != null:
		name = entry.name
	if steam_available and _steam != null:
		_steam.setAchievement(api_id)
		_steam.storeStats()
	emit_signal("achievement_unlocked", api_id, name)
	print("[SteamIntegration] Achievement unlocked: %s (%s)" % [name, api_id])
	# Check the meta-achievement after each unlock.
	if api_id != "NGU_67_ACHIEVEMENTS" and _all_others_unlocked("NGU_67_ACHIEVEMENTS"):
		unlock("NGU_67_ACHIEVEMENTS")

func is_unlocked(api_id: String) -> bool:
	return _unlocked.get(api_id, false)

# --- Event hooks (called by GameState/UI) ----------------------------------
func on_number_changed() -> void:
	evaluate_all()

func on_funny_sighting(_pattern: String, _total: int) -> void:
	evaluate_all()

func on_upgrade_purchased(_id: String, _owned: int) -> void:
	evaluate_all()

func on_prestige_performed(_level: int, _quote: String) -> void:
	check_prestige_speed()
	evaluate_all()

func on_click() -> void:
	_idle_seconds = 0.0
	_last_click_unix = Time.get_unix_time_from_system()
	evaluate_all()

func check_prestige_speed() -> void:
	var run_time: float = float(Time.get_unix_time_from_system() - GameState.run_start_unix)
	if run_time < 60.0 and GameState.prestige_level >= 1:
		unlock("NGU_PRESTIGE_60S")
	if run_time < 5.0 and GameState.prestige_level >= 1:
		unlock("NGU_THE_PRESTIGE_PRESTIGE")

func check_offline_return(offline_seconds: float) -> void:
	if offline_seconds >= float(GameState.OFFLINE_CAP_SECONDS):
		unlock("NGU_ALT_TABBED")

func notify_cheater_detected() -> void:
	_was_cheater_flagged = true
	unlock("NGU_CAUGHT_RED_HANDED")

func notify_cards_tab_opened() -> void:
	unlock("NGU_CARD_COLLECTOR")

func notify_stats_tab_open(delta: float) -> void:
	_stats_tab_open_seconds += delta
	if _stats_tab_open_seconds >= 120.0:
		unlock("NGU_THE_LONG_STARE")

func reset_stats_tab_timer() -> void:
	_stats_tab_open_seconds = 0.0

func notify_notation_changed() -> void:
	_notation_changes += 1
	if _notation_changes >= 10:
		unlock("NGU_LIAR")

# --- Idle tracking ----------------------------------------------------------
func _track_idle(delta: float) -> void:
	var now := Time.get_unix_time_from_system()
	if now - _last_click_unix >= 1:
		_idle_seconds += delta
	if _idle_seconds >= 600.0:
		evaluate_all()

# --- DLC --------------------------------------------------------------------
func _check_dlc() -> void:
	if HEAVY_WALLET_DLC_ID == 0:
		return
	if not steam_available or _steam == null:
		return
	var installed: bool = _steam.isDLCInstalled(HEAVY_WALLET_DLC_ID)
	if installed != GameState.heavy_wallet:
		GameState.heavy_wallet = installed
		GameState.mark_rate_dirty()
		emit_signal("dlc_status_changed", installed)

func check_dlc_on_launch() -> void:
	_check_dlc()

# --- Cloud saves ------------------------------------------------------------
func cloud_write(filename: String, data: String) -> void:
	if not steam_available or _steam == null:
		return
	_steam.fileWrite(filename, data)

func cloud_read(filename: String) -> String:
	if not steam_available or _steam == null:
		return ""
	if not _steam.fileExists(filename):
		return ""
	return _steam.fileRead(filename)

func cloud_exists(filename: String) -> bool:
	if not steam_available or _steam == null:
		return false
	return _steam.fileExists(filename)

# --- Save integration -------------------------------------------------------
func _sync_achievements_from_save() -> void:
	for api_id in GameState.achievements_unlocked:
		_unlocked[api_id] = true

func serialize_unlocked() -> Dictionary:
	return _unlocked.duplicate(true)
