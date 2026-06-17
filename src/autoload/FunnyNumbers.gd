extends Node
## Autoload singleton. Monitors the integer floor of the current number for
## funny patterns. Maintains a 2.5s global cooldown and permanent sighting
## counts (which never reset, even on transcendence — GDD §7.5).

const COOLDOWN_SECONDS := 2.5

signal popup_fired(entry: Dictionary)
signal sighting_recorded(pattern: String, total: int)

var _cooldown_remaining: float = 0.0
var _last_checked_int: int = -1

func _process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	poll()

func poll() -> void:
	if not GameState.settings.get("funny_popups", true):
		return
	if _cooldown_remaining > 0.0:
		return
	var current_int := int(floor(GameState.number))
	if current_int == _last_checked_int:
		return
	_last_checked_int = current_int
	if current_int < 0:
		return
	var digit_string := str(current_int)
	var entry: Variant = FunnyNumberDB.match(digit_string)
	if entry == null:
		return
	_fire(entry)

func _fire(entry: Dictionary) -> void:
	_cooldown_remaining = COOLDOWN_SECONDS
	var pattern: String = entry.pattern
	var total: int = GameState.funny_sightings.get(pattern, 0) + 1
	GameState.funny_sightings[pattern] = total
	emit_signal("sighting_recorded", pattern, total)
	emit_signal("popup_fired", entry)
