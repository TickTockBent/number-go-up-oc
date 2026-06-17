extends Control
## Main scene. Builds the UI tree procedurally and wires it to GameState.
## Layout: big clickable number on top, status bar, prestige panel + upgrade
## list below. Floating click text and funny-number popups render on an overlay.

const COLOR_GREEN := Color("#44ff88")
const COLOR_RED := Color("#ff4444")
const COLOR_GOLD := Color("#ffd84d")
const COLOR_DIM := Color("#888888")
const COLOR_BG := Color("#0a0a0a")
const COLOR_PANEL := Color("#141414")

var _number_label: Label
var _rate_label: Label
var _total_label: Label
var _prestige_label: Label
var _prestige_button: Button
var _message_label: Label
var _upgrade_container: VBoxContainer
var _overlay: Control
var _click_area: Control
var _cheater_overlay: Label

var _upgrade_rows: Dictionary = {}      # id -> {root, name, desc, cost, owned, btn}
var _last_prestige_time: float = 0.0
var _gold_flash_remaining: float = 0.0

func _ready() -> void:
	# Load save on launch (before first tick matters, but GameState already runs).
	var report: Dictionary = SaveSystem.load_on_launch()
	_build_ui()
	_refresh_all_rows()
	_refresh_prestige()
	if report.get("tampered", false):
		_show_cheater()
	elif report.get("loaded", false) and float(report.get("offline_seconds", 0.0)) > 1.0:
		_message_label.text = "While you were gone, the number went up. It didn't miss you."
	# Wire signals.
	GameState.number_changed.connect(_on_number_changed)
	GameState.rate_changed.connect(_on_rate_changed)
	GameState.upgrade_purchased.connect(_on_upgrade_purchased)
	GameState.prestige_performed.connect(_on_prestige_performed)
	GameState.message_emitted.connect(_on_message_emitted)
	GameState.red_corruption_changed.connect(_on_red_corruption_changed)
	FunnyNumbers.popup_fired.connect(_on_funny_popup)
	SaveSystem.cheater_detected.connect(_show_cheater)

func _build_ui() -> void:
	modulate = Color.WHITE
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(PRESET_FULL_RECT)
	root_vbox.offset_left = 16
	root_vbox.offset_top = 16
	root_vbox.offset_right = -16
	root_vbox.offset_bottom = -16
	add_child(root_vbox)

	# Click area (top, large) — clicking anywhere here clicks the number.
	_click_area = Control.new()
	_click_area.custom_minimum_size = Vector2(0, 220)
	_click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_click_area.gui_input.connect(_on_click_area_input)
	root_vbox.add_child(_click_area)

	_number_label = Label.new()
	_number_label.text = "0"
	_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number_label.set_anchors_preset(PRESET_FULL_RECT)
	_number_label.add_theme_font_size_override("font_size", 96)
	_number_label.add_theme_color_override("font_color", COLOR_GREEN)
	_number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_click_area.add_child(_number_label)

	# Status bar.
	var status := HBoxContainer.new()
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(status)
	_rate_label = _make_status_label(status, "/s: 0")
	_total_label = _make_status_label(status, "total: 0")
	_prestige_label = _make_status_label(status, "prestige: 0")

	# Message line.
	_message_label = Label.new()
	_message_label.text = "There is a number. It goes up."
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_color_override("font_color", COLOR_DIM)
	_message_label.add_theme_font_size_override("font_size", 16)
	root_vbox.add_child(_message_label)

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# Lower split: prestige panel (left) + upgrades (right).
	var lower := HBoxContainer.new()
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(lower)

	var left_col := VBoxContainer.new()
	left_col.custom_minimum_size = Vector2(280, 0)
	left_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lower.add_child(left_col)

	_prestige_button = Button.new()
	_prestige_button.text = "PRESTIGE\n(locked — reach 10,000 total)"
	_prestige_button.add_theme_font_size_override("font_size", 18)
	_prestige_button.custom_minimum_size = Vector2(0, 80)
	_prestige_button.pressed.connect(_on_prestige_pressed)
	left_col.add_child(_prestige_button)

	var help := Label.new()
	help.text = "Prestige resets the number and all upgrades for +2% production per level. The slow penalty persists. Suffer."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", COLOR_DIM)
	help.add_theme_font_size_override("font_size", 13)
	help.custom_minimum_size = Vector2(0, 120)
	left_col.add_child(help)

	# Upgrade list (scrollable).
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower.add_child(scroll)
	_upgrade_container = VBoxContainer.new()
	_upgrade_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_upgrade_container)

	_build_upgrade_rows()

	# Overlay for floating text + funny popups.
	_overlay = Control.new()
	_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	# Cheater overlay (hidden until triggered).
	_cheater_overlay = Label.new()
	_cheater_overlay.text = "CHEATER"
	_cheater_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_cheater_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cheater_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cheater_overlay.add_theme_font_size_override("font_size", 128)
	_cheater_overlay.add_theme_color_override("font_color", COLOR_RED)
	_cheater_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cheater_overlay.visible = false
	add_child(_cheater_overlay)

func _make_status_label(parent: Container, text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", COLOR_DIM)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.custom_minimum_size = Vector2(200, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(lbl)
	return lbl

func _build_upgrade_rows() -> void:
	# Build a row per tier, in tier order, skipping locked tiers.
	# We rebuild visibility on refresh; rows are created once.
	var ids_by_tier: Dictionary = {}
	for id in UpgradeDB.UPGRADES.keys():
		var def: Dictionary = UpgradeDB.UPGRADES[id]
		var t: int = def.tier
		if not ids_by_tier.has(t):
			ids_by_tier[t] = []
		ids_by_tier[t].append(id)
	for t in ids_by_tier.keys():
		ids_by_tier[t].sort()
	for t in range(0, UpgradeDB.Tier.size()):
		if not ids_by_tier.has(t):
			continue
		var header := Label.new()
		header.text = UpgradeDB.TIERS[t].name
		header.add_theme_color_override("font_color", COLOR_GOLD)
		header.add_theme_font_size_override("font_size", 16)
		_upgrade_container.add_child(header)
		for id in ids_by_tier[t]:
			_add_upgrade_row(id)

func _add_upgrade_row(id: String) -> void:
	var def: Dictionary = UpgradeDB.UPGRADES[id]
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_container.add_child(row)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_col)
	var name_lbl := Label.new()
	name_lbl.text = def.name
	name_lbl.add_theme_font_size_override("font_size", 16)
	if id == "red":
		name_lbl.add_theme_color_override("font_color", COLOR_RED)
	name_col.add_child(name_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = def.desc
	desc_lbl.add_theme_color_override("font_color", COLOR_DIM)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	name_col.add_child(desc_lbl)

	var owned_lbl := Label.new()
	owned_lbl.text = "0"
	owned_lbl.custom_minimum_size = Vector2(60, 0)
	owned_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owned_lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(owned_lbl)

	var btn := Button.new()
	btn.text = "0"
	btn.custom_minimum_size = Vector2(130, 0)
	btn.pressed.connect(_on_buy.bind(id))
	row.add_child(btn)

	_upgrade_rows[id] = {"root": row, "name": name_lbl, "desc": desc_lbl, "owned": owned_lbl, "btn": btn, "tier": def.tier}

func _refresh_all_rows() -> void:
	for id in _upgrade_rows:
		_refresh_row(id)

func _refresh_row(id: String) -> void:
	var row: Dictionary = _upgrade_rows[id]
	var tier: int = row.tier
	var visible := GameState.tier_visible(tier)
	row.root.visible = visible
	if not visible:
		return
	var owned: int = GameState.upgrade_owned(id)
	var cost := GameState.upgrade_cost(id)
	row.owned.text = str(owned)
	row.btn.text = NumberFormatter.format(cost, GameState.settings["notation"])
	row.btn.disabled = GameState.number < cost

func _refresh_prestige() -> void:
	if GameState.can_prestige():
		var gain := "+%d (level %d → %d)" % [1, GameState.prestige_level, GameState.prestige_level + 1]
		_prestige_button.text = "PRESTIGE\n%s\n(+2%% production, permanent)" % gain
		_prestige_button.disabled = false
	else:
		_prestige_button.text = "PRESTIGE\n(locked — reach 10,000 total)"
		_prestige_button.disabled = true
	_prestige_label.text = "prestige: %d" % GameState.prestige_level

func _process(delta: float) -> void:
	if _gold_flash_remaining > 0.0:
		_gold_flash_remaining = maxf(_gold_flash_remaining - delta, 0.0)
		if _gold_flash_remaining == 0.0:
			_apply_number_color()
	_refresh_all_rows()
	_refresh_prestige()
	# Cheater overlay stays visible while penalty active.
	_cheater_overlay.visible = SaveSystem.is_cheater_active()

# --- Signal handlers --------------------------------------------------------
func _on_number_changed(number: float, total: float) -> void:
	if SaveSystem.is_cheater_active():
		_number_label.text = "CHEATER"
	else:
		_number_label.text = NumberFormatter.format(number, GameState.settings["notation"])
	_total_label.text = "total: " + NumberFormatter.format(total, GameState.settings["notation"])
	# Unhinged mode: shrink font as digits grow.
	if GameState.settings["notation"] == "unhinged":
		var digits := _number_label.text.length()
		var size := int(clamp(96 - (digits - 1) * 1.5, 12, 96))
		_number_label.add_theme_font_size_override("font_size", size)

func _on_rate_changed(rate: float) -> void:
	_rate_label.text = "/s: " + NumberFormatter.format(rate, GameState.settings["notation"])

func _on_upgrade_purchased(id: String, owned: int) -> void:
	_refresh_row(id)

func _on_prestige_performed(level: int, quote: String) -> void:
	_message_label.text = quote
	_gold_flash_remaining = 1.0
	_apply_number_color()
	_refresh_all_rows()

func _on_message_emitted(text: String) -> void:
	_message_label.text = text

func _on_red_corruption_changed(red_count: int) -> void:
	_apply_number_color()

func _on_funny_popup(entry: Dictionary) -> void:
	_spawn_funny_popup(entry)

# --- Input ------------------------------------------------------------------
func _on_click_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_do_click()
	elif event.is_action_pressed("click"):
		_do_click()

func _do_click() -> void:
	GameState.click()
	var value := GameState.click_value()
	_spawn_floating_text("+" + NumberFormatter.format(value, GameState.settings["notation"]))

func _on_buy(id: String) -> void:
	GameState.buy(id)

func _on_prestige_pressed() -> void:
	GameState.prestige()

# --- Color / corruption -----------------------------------------------------
func _apply_number_color() -> void:
	if _gold_flash_remaining > 0.0:
		_number_label.add_theme_color_override("font_color", COLOR_GOLD)
		return
	if GameState.red_count >= 6:
		_number_label.add_theme_color_override("font_color", COLOR_RED)
	else:
		_number_label.add_theme_color_override("font_color", COLOR_GREEN)

# --- Floating text & popups -------------------------------------------------
func _spawn_floating_text(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", COLOR_GREEN)
	lbl.add_theme_font_size_override("font_size", 24)
	var area_rect := _click_area.get_global_rect()
	lbl.position = Vector2(
		randf_range(area_rect.position.x + 40, area_rect.position.x + area_rect.size.x - 40),
		randf_range(area_rect.position.y + 40, area_rect.position.y + area_rect.size.y - 40)
	)
	_overlay.add_child(lbl)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 90, 1.0)
	tween.tween_property(lbl, "modulate:a", 0.0, 1.0)
	tween.chain().tween_callback(lbl.queue_free)

func _spawn_funny_popup(entry: Dictionary) -> void:
	var lbl := Label.new()
	lbl.text = entry.label
	var color := Color.from_string(entry.color, COLOR_GOLD)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", int(entry.size))
	var screen := get_viewport_rect().size
	lbl.position = Vector2(
		screen.x * randf_range(0.10, 0.70),
		screen.y * randf_range(0.15, 0.45)
	)
	lbl.rotation = deg_to_rad(randf_range(-25.0, 25.0))
	lbl.z_index = 100
	_overlay.add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "scale", Vector2(1.5, 1.5), 0.15).from(Vector2(0.2, 0.2))
	tween.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.15)
	tween.parallel().tween_property(lbl, "position:y", lbl.position.y - 90, 2.2)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 2.2)
	tween.chain().tween_callback(lbl.queue_free)

func _show_cheater() -> void:
	_message_label.text = "Nice try."
