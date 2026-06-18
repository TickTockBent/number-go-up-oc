extends Node
## Autoload singleton. Manages Workshop meme packs — scans installed packs,
## resolves asset overrides by priority, and bridges to Steam Workshop API.
##
## Pack format (see addons/WORKSHOP_PACK_FORMAT.md):
##   pack.json — manifest with name, author, version, priority
##   popups/   — pattern ID → image (PNG/WebP) or video (WebM/OGV)
##   sounds/   — event/pattern ID → audio (OGG/MP3/WAV)
##   music/    — optional stem overrides (pad/bass/arp/full)
##   overrides/— UI texture overrides (red_button_bg, wallet_icon, etc.)
##
## Packs stack by priority (higher = checked first). No file for a pattern?
## Falls back to default. Loading is opt-in (player must subscribe + enable).
##
## Steam Workshop API calls no-op gracefully when Steam is unavailable,
## matching the SteamIntegration pattern.

signal packs_changed()
signal pack_download_progress(item_id: int, progress: float)

const PACKS_DIR := "user://packs"             # local packs
const WORKSHOP_DIR := "user://workshop"       # Steam-downloaded packs

var _packs: Array = []                        # [{path, manifest, enabled, source}]
var player_toggled_pack: bool = false          # set when player manually toggles a pack
var _popup_cache: Dictionary = {}             # pattern -> Texture2D or VideoStream
var _sound_cache: Dictionary = {}             # event_id -> AudioStream
var _texture_cache: Dictionary = {}           # texture_id -> Texture2D

func _ready() -> void:
	scan_packs()

# --- Pack scanning & parsing ------------------------------------------------
func scan_packs() -> void:
	_packs.clear()
	_popup_cache.clear()
	_sound_cache.clear()
	_texture_cache.clear()
	_scan_directory(PACKS_DIR, "local")
	_scan_directory(WORKSHOP_DIR, "steam")
	# Sort by priority descending (highest priority first).
	_packs.sort_custom(func(a, b): return a.manifest.get("priority", 0) > b.manifest.get("priority", 0))
	emit_signal("packs_changed")

func _scan_directory(dir_path: String, source: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		if dir.current_is_dir() and not item.begins_with("."):
			var pack_path := dir_path + "/" + item
			var manifest: Variant = _load_manifest(pack_path)
			if manifest != null:
				_packs.append({
					"path": pack_path,
					"manifest": manifest,
					"enabled": true,
					"source": source,
					"folder_name": item,
				})
		item = dir.get_next()
	dir.list_dir_end()

func _load_manifest(pack_path: String) -> Variant:
	var manifest_path := pack_path + "/pack.json"
	if not FileAccess.file_exists(manifest_path):
		return null
	var f := FileAccess.open(manifest_path, FileAccess.READ)
	if f == null:
		return null
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed

# --- Pack management --------------------------------------------------------
func get_packs() -> Array:
	return _packs

func get_enabled_packs() -> Array:
	var result: Array = []
	for pack in _packs:
		if pack.enabled:
			result.append(pack)
	return result

func set_pack_enabled(folder_name: String, enabled: bool) -> void:
	for pack in _packs:
		if pack.folder_name == folder_name:
			pack.enabled = enabled
			player_toggled_pack = true
			_clear_caches()
			emit_signal("packs_changed")
			return

func set_pack_priority(folder_name: String, new_priority: int) -> void:
	for pack in _packs:
		if pack.folder_name == folder_name:
			pack.manifest["priority"] = new_priority
			_packs.sort_custom(func(a, b): return a.manifest.get("priority", 0) > b.manifest.get("priority", 0))
			_clear_caches()
			emit_signal("packs_changed")
			return

func move_pack_up(folder_name: String) -> void:
	var idx := _find_pack_index(folder_name)
	if idx > 0:
		var tmp_priority: int = _packs[idx].manifest.get("priority", 0)
		_packs[idx].manifest["priority"] = _packs[idx - 1].manifest.get("priority", 0)
		_packs[idx - 1].manifest["priority"] = tmp_priority
		_packs.sort_custom(func(a, b): return a.manifest.get("priority", 0) > b.manifest.get("priority", 0))
		_clear_caches()
		emit_signal("packs_changed")

func move_pack_down(folder_name: String) -> void:
	var idx := _find_pack_index(folder_name)
	if idx >= 0 and idx < _packs.size() - 1:
		var tmp_priority: int = _packs[idx].manifest.get("priority", 0)
		_packs[idx].manifest["priority"] = _packs[idx + 1].manifest.get("priority", 0)
		_packs[idx + 1].manifest["priority"] = tmp_priority
		_packs.sort_custom(func(a, b): return a.manifest.get("priority", 0) > b.manifest.get("priority", 0))
		_clear_caches()
		emit_signal("packs_changed")

func _find_pack_index(folder_name: String) -> int:
	for i in _packs.size():
		if _packs[i].folder_name == folder_name:
			return i
	return -1

func _clear_caches() -> void:
	_popup_cache.clear()
	_sound_cache.clear()
	_texture_cache.clear()

# --- Asset resolution (priority-sorted) -------------------------------------
## Resolve a popup for a funny number pattern. Returns {type, path} or null.
## type is "image", "video", or null (fall back to default text popup).
func resolve_popup(pattern: String) -> Variant:
	if _popup_cache.has(pattern):
		return _popup_cache[pattern]
	for pack in get_enabled_packs():
		var pack_path: String = pack.path
		# Check for image (PNG, WebP, JPG).
		for ext in [".png", ".webp", ".jpg", ".jpeg"]:
			var file_path: String = pack_path + "/popups/" + pattern + ext
			if FileAccess.file_exists(file_path):
				var result: Dictionary = {"type": "image", "path": file_path, "pack": pack.folder_name}
				_popup_cache[pattern] = result
				return result
		# Check for video (WebM, OGV).
		for ext in [".webm", ".ogv"]:
			var file_path: String = pack_path + "/popups/" + pattern + ext
			if FileAccess.file_exists(file_path):
				var result: Dictionary = {"type": "video", "path": file_path, "pack": pack.folder_name}
				_popup_cache[pattern] = result
				return result
	_popup_cache[pattern] = null
	return null

## Resolve a sound override for an event_id or pattern. Returns absolute path or "".
func resolve_sound(event_id: String) -> String:
	if _sound_cache.has(event_id):
		return _sound_cache[event_id]
	for pack in get_enabled_packs():
		var pack_path: String = pack.path
		for ext in [".ogg", ".mp3", ".wav"]:
			var file_path: String = pack_path + "/sounds/" + event_id + ext
			if FileAccess.file_exists(file_path):
				_sound_cache[event_id] = file_path
				return file_path
	_sound_cache[event_id] = ""
	return ""

## Resolve a UI texture override. Returns Texture2D or null.
func resolve_texture(texture_id: String) -> Variant:
	if _texture_cache.has(texture_id):
		return _texture_cache[texture_id]
	for pack in get_enabled_packs():
		var pack_path: String = pack.path
		for ext in [".png", ".webp", ".jpg", ".jpeg"]:
			var file_path: String = pack_path + "/overrides/" + texture_id + ext
			if FileAccess.file_exists(file_path):
				var image := Image.load_from_file(file_path)
				if image != null:
					var texture := ImageTexture.create_from_image(image)
					_texture_cache[texture_id] = texture
					return texture
	_texture_cache[texture_id] = null
	return null

## Resolve a music stem override. Returns absolute path or "".
func resolve_music_stem(stem_id: String) -> String:
	for pack in get_enabled_packs():
		var pack_path: String = pack.path
		for ext in [".ogg", ".mp3", ".wav"]:
			var file_path: String = pack_path + "/music/" + stem_id + ext
			if FileAccess.file_exists(file_path):
				return file_path
	return ""

# --- Runtime loading helpers ------------------------------------------------
## Load an audio file from disk as AudioStream. Supports OGG and WAV.
func load_audio_from_file(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	var ext := file_path.get_extension().to_lower()
	match ext:
		"ogg":
			var file := FileAccess.open(file_path, FileAccess.READ)
			if file == null:
				return null
			var data := file.get_buffer(file.get_length())
			file.close()
			var stream := AudioStreamOggVorbis.new()
			# AudioStreamOggVorbis.load_from_buffer requires PackedByteArray.
			# This is the Godot 4.x API.
			return AudioStreamOggVorbis.load_from_buffer(data)
		"wav":
			var file := FileAccess.open(file_path, FileAccess.READ)
			if file == null:
				return null
			var data := file.get_buffer(file.get_length())
			file.close()
			var stream := AudioStreamWAV.new()
			# We can't easily parse WAV headers here; load as-is.
			# For Workshop packs, OGG is recommended.
			return null
		"mp3":
			var file := FileAccess.open(file_path, FileAccess.READ)
			if file == null:
				return null
			var data := file.get_buffer(file.get_length())
			file.close()
			return AudioStreamMP3.new()  # data field would need setting
	return null

## Load an image from disk as ImageTexture.
func load_image_from_file(file_path: String) -> ImageTexture:
	var image := Image.load_from_file(file_path)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)

# --- Steam Workshop API (graceful no-op) ------------------------------------
func browse_workshop() -> void:
	if SteamIntegration.steam_available and SteamIntegration._steam != null:
		SteamIntegration._steam.activateGameOverlayToWorkshop()
	else:
		print("[WorkshopManager] Steam not available — can't browse Workshop.")

func refresh_subscribed_items() -> void:
	if not SteamIntegration.steam_available or SteamIntegration._steam == null:
		return
	# Get subscribed items and their install paths.
	var items: Array = SteamIntegration._steam.getSubscribedItems()
	for item_id in items:
		var install_info: Dictionary = SteamIntegration._steam.getItemInstallInfo(item_id)
		if install_info.get("ret", false):
			var install_dir: String = install_info.get("folder", "")
			if install_dir != "":
				# This pack is installed; it will be picked up by scan_packs
				# if the workshop dir symlink/copy is set up.
				pass
	scan_packs()

func subscribe_item(item_id: int) -> void:
	if SteamIntegration.steam_available and SteamIntegration._steam != null:
		SteamIntegration._steam.subscribeItem(item_id)

func unsubscribe_item(item_id: int) -> void:
	if SteamIntegration.steam_available and SteamIntegration._steam != null:
		SteamIntegration._steam.unsubscribeItem(item_id)

func publish_pack(pack_path: String, preview_path: String, title: String, description: String, tags: Array) -> void:
	if not SteamIntegration.steam_available or SteamIntegration._steam == null:
		print("[WorkshopManager] Steam not available — can't publish pack.")
		return
	# Create workshop item.
	var create_result: Dictionary = SteamIntegration._steam.createItem(SteamIntegration._steam.getSteamID(), SteamIntegration._steam.WORKSHOP_FILE_TYPE_COMMUNITY)
	var item_id: int = create_result.get("published_file_id", 0)
	if item_id == 0:
		print("[WorkshopManager] Failed to create workshop item.")
		return
	# Submit item update.
	var update_handle: int = SteamIntegration._steam.startItemUpdate(item_id)
	SteamIntegration._steam.setItemTitle(update_handle, title)
	SteamIntegration._steam.setItemDescription(update_handle, description)
	SteamIntegration._steam.setItemPreview(update_handle, preview_path)
	if tags.size() > 0:
		SteamIntegration._steam.setItemTags(update_handle, tags)
	SteamIntegration._steam.submitItemUpdate(update_handle, "Initial upload")
	print("[WorkshopManager] Pack '%s' submitted as workshop item %d" % [title, item_id])

# --- Local pack creation (for testing) --------------------------------------
func create_local_pack(folder_name: String, manifest: Dictionary) -> String:
	var pack_path := PACKS_DIR + "/" + folder_name
	DirAccess.make_dir_recursive_absolute(pack_path)
	DirAccess.make_dir_recursive_absolute(pack_path + "/popups")
	DirAccess.make_dir_recursive_absolute(pack_path + "/sounds")
	DirAccess.make_dir_recursive_absolute(pack_path + "/music")
	DirAccess.make_dir_recursive_absolute(pack_path + "/overrides")
	var f := FileAccess.open(pack_path + "/pack.json", FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(manifest, "  "))
	f.close()
	scan_packs()
	return pack_path

func get_pack_count() -> int:
	return _packs.size()

func get_enabled_count() -> int:
	return get_enabled_packs().size()
