extends Node
## Autoload singleton. JSON save to user://number_go_up.save. A lightweight
## checksum detects tampering purely to trigger the "CHEATER" cosmetic penalty
## and achievement (GDD §9.3). No anti-cheat; players are free to cheat.

const SAVE_PATH := "user://number_go_up.save"
const CHEATER_PENALTY_SECONDS := 60.0

signal cheater_detected()

var cheater_penalty_remaining: float = 0.0
var save_enabled: bool = true        # test runner sets this false to avoid clobbering real saves

func _ready() -> void:
	# Wire autosave on a 5s interval.
	var timer := Timer.new()
	timer.name = "AutosaveTimer"
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(_autosave)
	add_child(timer)

func _autosave() -> void:
	if not save_enabled:
		return
	if GameState.number > 0.0 or GameState.total_clicks > 0 or GameState.prestige_level > 0:
		save_game()

func _exit_tree() -> void:
	if not save_enabled:
		return
	# Last-chance save on quit.
	GameState.last_seen_unix = Time.get_unix_time_from_system()
	save_game()

## Load on launch. Returns true if a valid save was applied.
func load_on_launch() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {"loaded": false}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {"loaded": false, "error": "read_failed"}
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"loaded": false, "error": "parse_failed"}
	var data: Dictionary = parsed

	# Checksum verification.
	var stored_checksum: String = data.get("_checksum", "")
	data.erase("_checksum")
	var computed := _checksum(data)
	var tampered: bool = (stored_checksum != computed)

	GameState.deserialize(data)

	# Offline progress (only if not tampered — tamper runs the cheater path).
	var elapsed := 0.0
	if not tampered and GameState.settings.get("offline", true):
		var now := Time.get_unix_time_from_system()
		elapsed = maxf(float(now - GameState.last_seen_unix), 0.0)
		if elapsed > 1.0:
			GameState.apply_offline_progress(elapsed)
	GameState.last_seen_unix = Time.get_unix_time_from_system()

	if tampered:
		_trigger_cheater_penalty()

	return {"loaded": true, "tampered": tampered, "offline_seconds": elapsed}

func save_game() -> void:
	GameState.last_seen_unix = Time.get_unix_time_from_system()
	var data: Dictionary = GameState.serialize()
	data["_checksum"] = _checksum(data)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveSystem: could not open save file for write.")
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()

func _checksum(data: Dictionary) -> String:
	# Stable JSON (sorted keys) then SHA-256. Not security, just tamper detection.
	var text := JSON.stringify(data, "", false, true)
	return text.sha256_text()

func _trigger_cheater_penalty() -> void:
	cheater_penalty_remaining = CHEATER_PENALTY_SECONDS
	emit_signal("cheater_detected")

func _process(delta: float) -> void:
	if cheater_penalty_remaining > 0.0:
		cheater_penalty_remaining = maxf(cheater_penalty_remaining - delta, 0.0)

func is_cheater_active() -> bool:
	return cheater_penalty_remaining > 0.0
