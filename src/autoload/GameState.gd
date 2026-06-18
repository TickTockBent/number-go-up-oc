extends Node
## Autoload singleton. Single source of truth for game state, the 20fps tick
## loop, derived multiplier math, purchases, and prestige. UI reads from here
## via signals. Never store derived values; recompute from counts.

const TICK_HZ := 20.0
const TICK_DT := 1.0 / TICK_HZ
const PRESTIGE_UNLOCK := 10000.0
const ASCENSION_UNLOCK_LEVEL := 10       # prestige levels required (GDD §6.2)
const TRANSCENDENCE_UNLOCK_LEVEL := 5    # ascension levels required (GDD §6.3)
const OFFLINE_CAP_SECONDS := 8 * 3600
const TRANSCENDENCE_HUE_SHIFT_DEG := 30.0

signal number_changed(number: float, total_earned: float)
signal rate_changed(rate_per_sec: float)
signal upgrade_purchased(id: String, owned: int)
signal prestige_performed(level: int, quote: String)
signal ascension_performed(level: int, quote: String)
signal transcendence_performed(level: int, quote: String)
signal message_emitted(text: String)
signal offline_report(gained: float)
signal red_corruption_changed(red_count: int)

# --- Persistent state -------------------------------------------------------
var number: float = 0.0
var total_earned: float = 0.0
var upgrades: Dictionary = {}          # id -> owned count
var prestige_level: int = 0
var ascension_level: int = 0
var transcendence_level: int = 0
var slow_mult: float = 1.0             # persists through prestige (GDD §6.1)
var red_count: int = 0                 # resets on prestige
var mystery_count: int = 0             # resets on prestige
var funny_sightings: Dictionary = {}   # pattern -> count (NEVER resets)
var total_clicks: int = 0
var run_start_unix: int = 0
var last_seen_unix: int = 0
var settings: Dictionary = {
	"notation": "extended",            # normal | extended | unhinged | nerd
	"offline": true,
	"screen_shake": "on",              # off | on | maximum (GDD §13.1)
	"funny_popups": true,
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"stinger_volume": 1.0,
	"color_override_enabled": false,   # locked unless 1+ transcendence (GDD §13.1)
	"color_override_hue": 0.0,         # 0.0-1.0 HSV hue
}
var heavy_wallet: bool = false         # DLC; set by SteamIntegration DLC detection
var heavy_wallet_acknowledged: bool = false  # player has dismissed the ACCEPT YOUR FATE overlay
var achievements_unlocked: Dictionary = {}  # api_id -> true (persisted across all resets)

# --- Runtime ----------------------------------------------------------------
var _accum: float = 0.0
var _cached_rate: float = 0.0
var _last_int_string: String = ""

func _ready() -> void:
	last_seen_unix = Time.get_unix_time_from_system()
	run_start_unix = last_seen_unix

func _process(delta: float) -> void:
	_accum += delta
	while _accum >= TICK_DT:
		_accum -= TICK_DT
		_tick(TICK_DT)
	_recompute_rate_if_dirty()
	# Emit number change for display (rate-driven or click-driven).
	_emit_number()

func _tick(dt: float) -> void:
	var rate := effective_rate()
	var gained := rate * dt
	if gained != 0.0:
		number += gained
		total_earned += maxf(gained, 0.0)
	_last_int_string = ""  # force funny-number recheck path

# --- Derived multipliers ----------------------------------------------------
## All "all production" multipliers folded together.
func production_mult() -> float:
	var m: float = slow_mult
	m *= prestige_mult()
	m *= ascension_mult()
	m *= transcendence_mult()
	if heavy_wallet:
		m *= 0.99999
	# prod_mult-effect upgrades (green, anti_slow, void, slow handled via slow_mult)
	for id in upgrades:
		var def: Dictionary = UpgradeDB.UPGRADES.get(id, {})
		if def.get("effect_type", "") == "prod_mult" and id != "slow":
			m *= pow(def.effect_value, upgrades[id])
	# Hidden mystery bonus: +0.777% per 7 mystery purchases. Never displayed.
	var hidden_bonuses: int = int(mystery_count / 7)
	m *= pow(1.00777, hidden_bonuses)
	return m

func prestige_mult() -> float:
	return 1.0 + 0.02 * float(prestige_level)

func ascension_mult() -> float:
	return pow(1.1, float(ascension_level))

func transcendence_mult() -> float:
	return 1.0 + 0.05 * float(transcendence_level)

func click_power() -> float:
	var base: float = 1.0
	var mult: float = 1.0
	for id in upgrades:
		var def: Dictionary = UpgradeDB.UPGRADES.get(id, {})
		match def.get("effect_type", ""):
			"click_flat":
				base += def.effect_value * upgrades[id]
			"click_mult":
				mult *= pow(def.effect_value, upgrades[id])
	return base * mult

func has_click_of_god() -> bool:
	return upgrades.get("click_3", 0) > 0

func base_rate() -> float:
	var r: float = 0.0
	for id in upgrades:
		var def: Dictionary = UpgradeDB.UPGRADES.get(id, {})
		match def.get("effect_type", ""):
			"rate_flat":
				r += def.effect_value * upgrades[id]
			"rate_pct_current":
				r += def.effect_value * upgrades[id] * number
	return r

func effective_rate() -> float:
	return base_rate() * production_mult()

func click_value() -> float:
	if has_click_of_god():
		return effective_rate()
	return click_power() * production_mult()

# --- Actions ----------------------------------------------------------------
func click() -> void:
	var v := click_value()
	number += v
	total_earned += maxf(v, 0.0)
	total_clicks += 1

func buy(id: String) -> bool:
	if not UpgradeDB.UPGRADES.has(id):
		return false
	var owned: int = upgrades.get(id, 0)
	var cost := UpgradeDB.cost(id, owned)
	if number < cost:
		return false
	# Void button: sacrifice half current number as part of its cost.
	if id == "void":
		number *= 0.5
	number -= cost
	owned += 1
	upgrades[id] = owned
	_recompute_rate()
	# Trap-specific bookkeeping & flavor.
	match id:
		"red":
			red_count += 1
			emit_signal("message_emitted", UpgradeDB.red_button_message(red_count))
			emit_signal("red_corruption_changed", red_count)
		"slow":
			slow_mult *= 0.9
			emit_signal("message_emitted", UpgradeDB.slow_message(1.0 - slow_mult))
		"mystery":
			mystery_count += 1
			emit_signal("message_emitted", UpgradeDB.mystery_message(mystery_count))
		"void":
			emit_signal("message_emitted", "Half your number, gone. The rest works 25% harder now.")
	emit_signal("upgrade_purchased", id, owned)
	_recompute_rate()
	return true

func can_prestige() -> bool:
	return total_earned >= PRESTIGE_UNLOCK

func prestige() -> void:
	if not can_prestige():
		return
	prestige_level += 1
	var quote := _prestige_quote()
	_reset_run()
	emit_signal("prestige_performed", prestige_level, quote)
	_recompute_rate()

func _reset_run() -> void:
	number = 0.0
	upgrades.clear()
	red_count = 0
	mystery_count = 0
	# slow_mult persists across prestige (GDD §6.1). Resets on ascension only.
	run_start_unix = Time.get_unix_time_from_system()

const _PRESTIGE_QUOTES: Array = [
	"The number has been reset. It remembers nothing. But you do.",
	"Was it worth it? Yes. The number goes up faster now.",
	"Prestige Level Up. The void is 2% more generous.",
	"You sacrificed everything. You gained almost nothing. Perfect.",
	"The number is reborn. It doesn't know it died.",
	"Reset complete. The number has forgotten its past life.",
	"All that progress, gone. But the PERCENTAGE. The percentage remains.",
	"Samsara. The cycle continues. The number goes up.",
	"The number before was a different number. This is a new number. It doesn't know you yet.",
	"Somewhere in the code, a variable was set to zero. That's all prestige is.",
]

func _prestige_quote() -> String:
	return _PRESTIGE_QUOTES[randi() % _PRESTIGE_QUOTES.size()]

# --- Layer 2: Ascension (GDD §6.2) -----------------------------------------
## Unlock at prestige level 10. Resets everything prestige resets, plus prestige
## levels return to 0. Slow penalty resets here (and only here, before transcendence).
## Reward: x1.1 production per level (folded via ascension_mult).
func can_ascend() -> bool:
	return prestige_level >= ASCENSION_UNLOCK_LEVEL

func ascend() -> void:
	if not can_ascend():
		return
	ascension_level += 1
	var quote := _ascension_quote()
	# Layer-1 reset, then clear prestige levels and slow penalty.
	_reset_run()
	prestige_level = 0
	slow_mult = 1.0
	emit_signal("ascension_performed", ascension_level, quote)
	_recompute_rate()

const _ASCENSION_QUOTES: Array = [
	"You have ascended beyond prestige. The number doesn't know what that means. It goes up.",
	"Your prestiges are gone. You are left with a multiplier and a sense of loss.",
	"Ascension complete. The meta-number acknowledges you.",
	"The number goes up faster now, but at what cost? Exactly 0 cost. Ascension is free.",
	"You reset the reset. The number respects the recursion.",
]

func _ascension_quote() -> String:
	return _ASCENSION_QUOTES[randi() % _ASCENSION_QUOTES.size()]

# --- Layer 3: Transcendence (GDD §6.3) -------------------------------------
## Unlock at ascension level 5. Resets EVERYTHING except: transcendence counter,
## funny number sightings, total clicks (achievement progress), settings, DLC.
## Reward: +5% production per level + permanent hue shift of the number (30°/level).
func can_transcend() -> bool:
	return ascension_level >= TRANSCENDENCE_UNLOCK_LEVEL

func transcend() -> void:
	if not can_transcend():
		return
	transcendence_level += 1
	var quote := _transcendence_quote()
	# Full wipe. funny_sightings, total_clicks, settings, heavy_wallet persist.
	number = 0.0
	total_earned = 0.0
	upgrades.clear()
	prestige_level = 0
	ascension_level = 0
	slow_mult = 1.0
	red_count = 0
	mystery_count = 0
	run_start_unix = Time.get_unix_time_from_system()
	emit_signal("transcendence_performed", transcendence_level, quote)
	_recompute_rate()

const _TRANSCENDENCE_QUOTES: Array = [
	"Up.", "Number.", "Again.", "Why.", "Up.", "Still.", "Here.", "Going.", "Up.",
]

func _transcendence_quote() -> String:
	return _TRANSCENDENCE_QUOTES[randi() % _TRANSCENDENCE_QUOTES.size()]

## Number color for the current transcendence level. Base green hue shifted 30°
## per level; at level 12 the hue wraps back to green (GDD §6.3).
const _BASE_NUMBER_COLOR := Color("#44ff88")
func transcendence_color() -> Color:
	if transcendence_level == 0:
		return _BASE_NUMBER_COLOR
	var base_hue := _BASE_NUMBER_COLOR.h
	var base_sat := _BASE_NUMBER_COLOR.s
	var base_val := _BASE_NUMBER_COLOR.v
	var shift := TRANSCENDENCE_HUE_SHIFT_DEG / 360.0 * float(transcendence_level)
	var hue := fmod(base_hue + shift, 1.0)
	return Color.from_hsv(hue, base_sat, base_val)

# --- Cost / unlock helpers for UI ------------------------------------------
func upgrade_cost(id: String) -> float:
	return UpgradeDB.cost(id, upgrades.get(id, 0))

func upgrade_owned(id: String) -> int:
	return upgrades.get(id, 0)

func tier_visible(tier: int) -> bool:
	return UpgradeDB.tier_unlocked(tier, total_earned)

# --- Offline progress -------------------------------------------------------
func apply_offline_progress(elapsed_seconds: float) -> float:
	var capped: float = minf(elapsed_seconds, OFFLINE_CAP_SECONDS)
	var gained := effective_rate() * capped
	number += gained
	total_earned += maxf(gained, 0.0)
	emit_signal("offline_report", gained)
	return gained

# --- Emission helpers -------------------------------------------------------
var _rate_dirty: bool = true

func _recompute_rate_if_dirty() -> void:
	if _rate_dirty:
		_recompute_rate()

func _recompute_rate() -> void:
	_cached_rate = effective_rate()
	_rate_dirty = false
	emit_signal("rate_changed", _cached_rate)

func _emit_number() -> void:
	emit_signal("number_changed", number, total_earned)

func mark_rate_dirty() -> void:
	_rate_dirty = true

# --- Save/restore (used by SaveSystem) -------------------------------------
func serialize() -> Dictionary:
	return {
		"number": number,
		"total_earned": total_earned,
		"upgrades": upgrades.duplicate(true),
		"prestige_level": prestige_level,
		"ascension_level": ascension_level,
		"transcendence_level": transcendence_level,
		"slow_mult": slow_mult,
		"red_count": red_count,
		"mystery_count": mystery_count,
		"funny_sightings": funny_sightings.duplicate(true),
		"total_clicks": total_clicks,
		"run_start_unix": run_start_unix,
		"last_seen_unix": last_seen_unix,
		"settings": settings.duplicate(true),
		"heavy_wallet": heavy_wallet,
		"heavy_wallet_acknowledged": heavy_wallet_acknowledged,
		"achievements_unlocked": achievements_unlocked.duplicate(true),
		"version": 1,
	}

func deserialize(data: Dictionary) -> void:
	number = float(data.get("number", 0.0))
	total_earned = float(data.get("total_earned", 0.0))
	upgrades = data.get("upgrades", {}).duplicate(true)
	prestige_level = int(data.get("prestige_level", 0))
	ascension_level = int(data.get("ascension_level", 0))
	transcendence_level = int(data.get("transcendence_level", 0))
	slow_mult = float(data.get("slow_mult", 1.0))
	red_count = int(data.get("red_count", 0))
	mystery_count = int(data.get("mystery_count", 0))
	funny_sightings = data.get("funny_sightings", {}).duplicate(true)
	total_clicks = int(data.get("total_clicks", 0))
	run_start_unix = int(data.get("run_start_unix", Time.get_unix_time_from_system()))
	last_seen_unix = int(data.get("last_seen_unix", Time.get_unix_time_from_system()))
	settings = data.get("settings", settings).duplicate(true)
	# Migrate screen_shake from old bool format to string.
	var ss: Variant = settings.get("screen_shake", "on")
	if ss is bool:
		settings["screen_shake"] = "on" if ss else "off"
	heavy_wallet = bool(data.get("heavy_wallet", false))
	heavy_wallet_acknowledged = bool(data.get("heavy_wallet_acknowledged", false))
	achievements_unlocked = data.get("achievements_unlocked", {}).duplicate(true)
	mark_rate_dirty()
