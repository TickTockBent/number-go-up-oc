extends Node
## Autoload singleton. Procedurally generates all SFX and music stems on _ready
## via AudioSynth (zero shipped audio assets). Manages 4 audio buses (Master,
## Music, SFX, Stinger), adaptive music crossfading by production rate, and
## state-driven effects (red detune, slow half-speed, post-prestige cut).
##
## All synthesized audio is a placeholder. Replace with real .ogg/.wav files by
## dropping them into audio/sfx/ and audio/music/ with matching event IDs.
## Workshop packs (Phase 4) can also override individual sounds.

const AudioSynth := preload("res://src/audio/AudioSynth.gd")

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_STINGER := "Stinger"

# Production rate thresholds for stem layers (GDD §12.1).
const LAYER_PAD := 0           # always on
const LAYER_BASS := 1000.0     # 1K+/s
const LAYER_ARP := 100000.0    # 100K+/s
const LAYER_FULL := 10000000.0 # 10M+/s

# Note frequencies for SFX.
const NOTE_C4 := 261.63
const NOTE_E4 := 329.63
const NOTE_G4 := 392.0
const NOTE_C5 := 523.25
const NOTE_E5 := 659.25
const NOTE_G5 := 783.99
const NOTE_C6 := 1046.50

# --- SFX cache ---
var _sfx: Dictionary = {}          # event_id -> AudioStreamWAV
var _stingers: Dictionary = {}     # pattern -> AudioStreamWAV

# --- Music players (one per stem) ---
var _stem_players: Array = []      # [AudioStreamPlayer x4]
var _stem_volumes: Array = [0.6, 0.0, 0.0, 0.0]  # target volumes per stem
var _post_prestige_cut_remaining: float = 0.0
var _current_layer: int = 0

# --- SFX player pool ---
var _sfx_pool: Array = []
var _sfx_pool_index: int = 0
const SFX_POOL_SIZE := 8

var _audio_initialized: bool = false

func _ready() -> void:
	_setup_buses()
	_generate_sfx()
	_generate_stingers()
	_generate_music_stems()
	_setup_sfx_pool()
	_apply_volume_settings()
	_audio_initialized = true
	# Start music immediately (pad layer only).
	_start_music()

func _setup_buses() -> void:
	# Godot always has Master. Create the others if missing.
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	_ensure_bus(BUS_STINGER)

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, BUS_MASTER)

func _generate_sfx() -> void:
	# Click — soft mechanical click, short.
	_sfx["click"] = AudioSynth.tone(800.0, 0.03, 0.3, "sine")
	# Buy upgrade — cash register cha-ching (two-tone ascending).
	_sfx["buy"] = AudioSynth.chime([NOTE_C5, NOTE_E5, NOTE_G5], 0.06, 0.4)
	# Red button buy — same click but "red" (it's the same sound).
	_sfx["buy_red"] = AudioSynth.tone(800.0, 0.03, 0.3, "sine")
	# Slow button — descending slide whistle.
	_sfx["buy_slow"] = AudioSynth.slide(800.0, 200.0, 0.4, 0.5)
	# Mystery button — static burst.
	_sfx["buy_mystery"] = AudioSynth.noise(0.2, 0.4, true)
	# Prestige — ascending chime sequence, ethereal.
	_sfx["prestige"] = AudioSynth.chime([NOTE_C4, NOTE_E4, NOTE_G4, NOTE_C5, NOTE_E5, NOTE_G5, NOTE_C6], 0.12, 0.5)
	# Ascension — same chime reversed then forward.
	var asc_forward := AudioSynth.chime([NOTE_C4, NOTE_E4, NOTE_G4, NOTE_C5], 0.1, 0.4)
	_sfx["ascension"] = asc_forward
	# Transcendence — single bass note.
	_sfx["transcendence"] = AudioSynth.tone(65.41, 2.0, 0.6, "sine")  # C2
	# Offline return — gentle ping.
	_sfx["offline"] = AudioSynth.tone(NOTE_C6, 0.3, 0.3, "sine")

func _generate_stingers() -> void:
	# Default stinger — synth chirp.
	_stingers["_default"] = AudioSynth.tone(880.0, 0.15, 0.4, "sine")
	# 69 — "Nice." (single low tone placeholder for voice).
	_stingers["69"] = AudioSynth.tone(220.0, 0.4, 0.5, "triangle")
	# OVER 9000 — distorted scream (clipped noise).
	var scream := AudioSynth.noise(0.3, 0.7, false)
	_stingers["9001"] = scream
	# 666 — reversed piano chord.
	var chord := AudioSynth.chime([NOTE_C4, NOTE_E4 - 1.0, NOTE_G4 - 2.0], 0.5, 0.4)
	_stingers["666"] = AudioSynth.reversed(chord)
	# 420 — chill lo-fi hit with vinyl crackle.
	var lofi := AudioSynth.tone(330.0, 0.5, 0.3, "triangle")
	_stingers["420"] = lofi
	# BOOBS/BOOBIES/BOOB — calculator beep sequence (ascending).
	var beeps := AudioSynth.chime([660.0, 880.0, 1100.0], 0.08, 0.4)
	_stingers["80085"] = beeps
	_stingers["8008135"] = beeps
	_stingers["8008"] = beeps
	# WE GOT A 2319 — alarm klaxon.
	_stingers["2319"] = AudioSynth.klaxon(0.5, 0.5)

func _generate_music_stems() -> void:
	# Stem 1: pad — soft, minimal, nearly subliminal.
	_stem_players.append(_make_stem_player(AudioSynth.loop([110.0, 165.0, 220.0], 4.0, 0.3, "sine")))
	# Stem 2: bass pulse — gentle bass at 100 BPM.
	_stem_players.append(_make_stem_player(AudioSynth.bass_loop(55.0, 4.0, 100.0, 0.3)))
	# Stem 3: arpeggiated synth.
	_stem_players.append(_make_stem_player(AudioSynth.arp_loop([220.0, 277.18, 329.63, 277.18], 0.2, 4.0, 0.2)))
	# Stem 4: full mix — the track is actually a banger now.
	_stem_players.append(_make_stem_player(AudioSynth.full_loop(4.0, 0.25)))

func _make_stem_player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS_MUSIC
	player.autoplay = true
	add_child(player)
	player.volume_db = -80.0  # start silent, crossfade in
	return player

func _setup_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_sfx_pool.append(player)

func _start_music() -> void:
	# Stem 0 (pad) starts playing at target volume.
	_set_stem_volume(0, _stem_volumes[0])

func _process(delta: float) -> void:
	if not _audio_initialized:
		return
	_update_music_layers(delta)
	_update_music_effects(delta)
	_crossfade_stems(delta)

# --- Music layer management -------------------------------------------------
func _update_music_layers(delta: float) -> void:
	if _post_prestige_cut_remaining > 0.0:
		# During post-prestige cut: only pad, at reduced volume.
		_stem_volumes = [0.3, 0.0, 0.0, 0.0]
		return
	var rate := GameState.effective_rate()
	var new_layer := 0
	if rate >= LAYER_FULL:
		new_layer = 4
	elif rate >= LAYER_ARP:
		new_layer = 3
	elif rate >= LAYER_BASS:
		new_layer = 2
	else:
		new_layer = 1
	if new_layer != _current_layer:
		_current_layer = new_layer
	# Set target volumes: all layers up to current are audible.
	_stem_volumes[0] = 0.6
	_stem_volumes[1] = 0.5 if _current_layer >= 2 else 0.0
	_stem_volumes[2] = 0.4 if _current_layer >= 3 else 0.0
	_stem_volumes[3] = 0.45 if _current_layer >= 4 else 0.0

func _update_music_effects(delta: float) -> void:
	if _post_prestige_cut_remaining > 0.0:
		_post_prestige_cut_remaining = maxf(_post_prestige_cut_remaining - delta, 0.0)
		return
	# Red button detune (GDD §12.1: 20+ detune, 50+ noticeably off-key).
	var red := GameState.red_count
	var pitch_scale := 1.0
	if red >= 50:
		pitch_scale = 0.92
	elif red >= 20:
		pitch_scale = 1.0 - (float(red - 20) / 30.0) * 0.08
	# 99% slow penalty: half speed, bass drops octave.
	var slow_penalty := 1.0 - GameState.slow_mult
	if slow_penalty >= 0.99:
		pitch_scale *= 0.5
	for player in _stem_players:
		player.pitch_scale = pitch_scale

func _crossfade_stems(delta: float) -> void:
	var fade_speed := 2.0  # seconds to full volume
	for i in _stem_players.size():
		var player: AudioStreamPlayer = _stem_players[i]
		var target: float = _stem_volumes[i]
		var current_db := player.volume_db
		var target_db := linear_to_db(target) if target > 0.001 else -80.0
		player.volume_db = lerpf(current_db, target_db, delta * fade_speed)

# --- SFX playback -----------------------------------------------------------
func play_sfx(event_id: String) -> void:
	if not _audio_initialized:
		return
	# Check for Workshop pack override first.
	var override_path := WorkshopManager.resolve_sound(event_id)
	if override_path != "":
		var override_stream: Variant = WorkshopManager.load_audio_from_file(override_path)
		if override_stream is AudioStream:
			_play_on_pool(override_stream, event_id)
			return
	# Fall back to synthesized SFX.
	var stream: AudioStreamWAV = _sfx.get(event_id)
	if stream == null:
		return
	_play_on_pool(stream, event_id)

func _play_on_pool(stream: AudioStream, event_id: String) -> void:
	var player: AudioStreamPlayer = _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE
	# Click pitch varies ±5% (GDD §12.2).
	if event_id == "click":
		player.pitch_scale = randf_range(0.95, 1.05)
	else:
		player.pitch_scale = 1.0
	player.stream = stream
	player.play()

func play_stinger(pattern: String) -> void:
	if not _audio_initialized:
		return
	# Check for Workshop pack override first.
	var override_path := WorkshopManager.resolve_sound(pattern)
	if override_path != "":
		var override_stream: Variant = WorkshopManager.load_audio_from_file(override_path)
		if override_stream is AudioStream:
			_play_stinger_on_stream(override_stream)
			return
	# Fall back to synthesized stinger.
	var stream: AudioStreamWAV = _stingers.get(pattern, _stingers["_default"])
	_play_stinger_on_stream(stream)

func _play_stinger_on_stream(stream: AudioStream) -> void:
	var player: AudioStreamPlayer = _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE
	player.bus = BUS_STINGER
	player.stream = stream
	player.play()
	# Reset bus for next SFX.
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(player):
		player.bus = BUS_SFX

# --- Event hooks ------------------------------------------------------------
func on_prestige() -> void:
	play_sfx("prestige")
	trigger_post_prestige_cut()

func on_ascension() -> void:
	play_sfx("ascension")
	trigger_post_prestige_cut()

func on_transcendence() -> void:
	play_sfx("transcendence")

func on_offline_return() -> void:
	play_sfx("offline")

func trigger_post_prestige_cut() -> void:
	# GDD §12.1: everything cuts out except a single held note for 30s.
	_post_prestige_cut_remaining = 30.0
	_current_layer = 0

# --- Volume settings --------------------------------------------------------
func _apply_volume_settings() -> void:
	_set_bus_volume(BUS_MASTER, float(GameState.settings.get("master_volume", 1.0)))
	_set_bus_volume(BUS_MUSIC, float(GameState.settings.get("music_volume", 0.8)))
	_set_bus_volume(BUS_SFX, float(GameState.settings.get("sfx_volume", 1.0)))
	_set_bus_volume(BUS_STINGER, float(GameState.settings.get("stinger_volume", 1.0)))

func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(linear))

func update_volumes_from_settings() -> void:
	_apply_volume_settings()

func _set_stem_volume(idx: int, linear: float) -> void:
	if idx >= _stem_players.size():
		return
	var player: AudioStreamPlayer = _stem_players[idx]
	player.volume_db = linear_to_db(linear) if linear > 0.001 else -80.0
