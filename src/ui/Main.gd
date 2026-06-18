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
var _ascension_label: Label
var _transcendence_label: Label
var _prestige_button: Button
var _ascension_button: Button
var _transcendence_button: Button
var _message_label: Label
var _upgrade_container: VBoxContainer
var _overlay: Control
var _click_area: Control
var _cheater_overlay: Label
var _corruption_overlay: ColorRect
var _tab_container: TabContainer
var _wallet_icon: Label
var _wallet_tooltip: Label
var _fate_overlay: Control
var _fate_button: Button
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_remaining: float = 0.0
var _shake_intensity: float = 0.0
var _flicker_remaining: float = 0.0
var _flicker_overlay: ColorRect
var _base_position: Vector2 = Vector2.ZERO
var _ghost_labels: Array = []  # trailing ghost digits for slow penalty
var _ghost_spawn_timer: float = 0.0
var _unhinged_chaos_timer: float = 0.0

# --- Stats tab state --------------------------------------------------------
var _stats_container: VBoxContainer
var _stats_tab_open_seconds: float = 0.0
var _stats_was_visible: bool = false

# --- Settings tab widgets ---------------------------------------------------
var _settings_notation_selector: OptionButton
var _settings_shake_selector: OptionButton
var _settings_color_hue_slider: HSlider
var _settings_color_hue_label: Label

# --- Cards tab --------------------------------------------------------------
var _cards_viewed: bool = false

# --- Workshop tab -----------------------------------------------------------
var _workshop_container: VBoxContainer

var _upgrade_rows: Dictionary = {}      # id -> {root, name, desc, cost, owned, btn}
var _last_prestige_time: float = 0.0
var _gold_flash_remaining: float = 0.0

func _ready() -> void:
	# Load save on launch (before first tick matters, but GameState already runs).
	var report: Dictionary = SaveSystem.load_on_launch()
	_build_ui()
	_refresh_all_rows()
	_refresh_prestige()
	_refresh_ascension()
	_refresh_transcendence()
	_apply_number_color()
	_apply_corruption()
	if report.get("tampered", false):
		_show_cheater()
	elif report.get("loaded", false) and float(report.get("offline_seconds", 0.0)) > 1.0:
		_show_offline_toast(float(report.get("offline_gained", 0.0)))
	# Wire signals.
	GameState.number_changed.connect(_on_number_changed)
	GameState.rate_changed.connect(_on_rate_changed)
	GameState.upgrade_purchased.connect(_on_upgrade_purchased)
	GameState.prestige_performed.connect(_on_prestige_performed)
	GameState.ascension_performed.connect(_on_ascension_performed)
	GameState.transcendence_performed.connect(_on_transcendence_performed)
	GameState.message_emitted.connect(_on_message_emitted)
	GameState.red_corruption_changed.connect(_on_red_corruption_changed)
	GameState.offline_report.connect(_on_offline_report)
	FunnyNumbers.popup_fired.connect(_on_funny_popup)
	SaveSystem.cheater_detected.connect(_show_cheater)
	SteamIntegration.dlc_status_changed.connect(_on_dlc_changed)
	WorkshopManager.packs_changed.connect(_refresh_workshop_list)
	_base_position = position

func _build_ui() -> void:
	modulate = Color.WHITE
	_tab_container = TabContainer.new()
	_tab_container.set_anchors_preset(PRESET_FULL_RECT)
	_tab_container.offset_left = 8
	_tab_container.offset_top = 8
	_tab_container.offset_right = -8
	_tab_container.offset_bottom = -8
	add_child(_tab_container)

	_build_game_tab()
	_build_stats_tab()
	_build_cards_tab()
	_build_settings_tab()
	_build_workshop_tab()

	# --- Overlays (siblings of TabContainer, above everything) ---------------

	# Red-button corruption overlay — washes red over the UI at 20+ red buttons.
	_corruption_overlay = ColorRect.new()
	_corruption_overlay.color = Color(1.0, 0.1, 0.1, 0.0)
	_corruption_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_corruption_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corruption_overlay.z_index = 50
	add_child(_corruption_overlay)

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

	# Wallet icon — appears left of the number when Heavy Wallet DLC is active.
	_wallet_icon = Label.new()
	_wallet_icon.text = "[$]"
	_wallet_icon.add_theme_font_size_override("font_size", 16)
	_wallet_icon.add_theme_color_override("font_color", COLOR_GOLD)
	_wallet_icon.set_anchors_preset(PRESET_CENTER_LEFT)
	_wallet_icon.offset_left = 12
	_wallet_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_wallet_icon.visible = false
	_click_area.add_child(_wallet_icon)
	_wallet_tooltip = Label.new()
	_wallet_tooltip.text = "$4.99"
	_wallet_tooltip.add_theme_font_size_override("font_size", 12)
	_wallet_tooltip.add_theme_color_override("font_color", COLOR_DIM)
	_wallet_tooltip.visible = false
	_wallet_tooltip.z_index = 200
	add_child(_wallet_tooltip)
	_wallet_icon.mouse_entered.connect(func(): _wallet_tooltip.visible = true)
	_wallet_icon.mouse_exited.connect(func(): _wallet_tooltip.visible = false)

	# ACCEPT YOUR FATE overlay — shown on first Heavy Wallet DLC detection.
	_fate_overlay = Control.new()
	_fate_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_fate_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_fate_overlay.z_index = 300
	_fate_overlay.visible = false
	add_child(_fate_overlay)
	var fate_bg := ColorRect.new()
	fate_bg.color = Color(0.02, 0.02, 0.02, 0.92)
	fate_bg.set_anchors_preset(PRESET_FULL_RECT)
	fate_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_fate_overlay.add_child(fate_bg)
	var fate_vbox := VBoxContainer.new()
	fate_vbox.set_anchors_preset(PRESET_CENTER)
	fate_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	fate_vbox.custom_minimum_size = Vector2(500, 0)
	_fate_overlay.add_child(fate_vbox)
	var fate_title := Label.new()
	fate_title.text = "HEAVY WALLET EQUIPPED"
	fate_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fate_title.add_theme_font_size_override("font_size", 28)
	fate_title.add_theme_color_override("font_color", COLOR_GOLD)
	fate_vbox.add_child(fate_title)
	var fate_text := Label.new()
	fate_text.text = "\nAll number production has been permanently reduced by 0.001%.\n\nThis cannot be undone. This cannot be uninstalled. This cannot be refunded after the number goes up even once.\n\nYou paid $4.99 for this. The base game was $0.99.\n\nThank you for your support."
	fate_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fate_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fate_text.add_theme_font_size_override("font_size", 16)
	fate_text.add_theme_color_override("font_color", COLOR_DIM)
	fate_vbox.add_child(fate_text)
	_fate_button = Button.new()
	_fate_button.text = "ACCEPT YOUR FATE"
	_fate_button.add_theme_font_size_override("font_size", 20)
	_fate_button.custom_minimum_size = Vector2(0, 50)
	_fate_button.pressed.connect(_on_fate_accepted)
	fate_vbox.add_child(_fate_button)

	# Offline return toast — appears at top center, auto-dismisses.
	_toast_panel = PanelContainer.new()
	_toast_panel.set_anchors_preset(PRESET_CENTER_TOP)
	_toast_panel.custom_minimum_size = Vector2(500, 0)
	_toast_panel.z_index = 150
	_toast_panel.visible = false
	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color(0.08, 0.08, 0.08, 0.95)
	toast_style.border_color = Color(0.3, 0.3, 0.3, 0.8)
	toast_style.set_border_width_all(1)
	toast_style.set_corner_radius_all(6)
	toast_style.set_content_margin_all(16)
	_toast_panel.add_theme_stylebox_override("panel", toast_style)
	add_child(_toast_panel)
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 16)
	_toast_label.add_theme_color_override("font_color", COLOR_GREEN)
	_toast_panel.add_child(_toast_label)

	# Background flicker overlay — flashes at 1M+ click power.
	_flicker_overlay = ColorRect.new()
	_flicker_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	_flicker_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_flicker_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flicker_overlay.z_index = 40
	add_child(_flicker_overlay)

func _build_game_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Game"
	_tab_container.add_child(tab)

	# Click area (top, large) — clicking anywhere here clicks the number.
	_click_area = Control.new()
	_click_area.custom_minimum_size = Vector2(0, 220)
	_click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_click_area.gui_input.connect(_on_click_area_input)
	tab.add_child(_click_area)

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
	tab.add_child(status)
	_rate_label = _make_status_label(status, "/s: 0")
	_total_label = _make_status_label(status, "total: 0")
	_prestige_label = _make_status_label(status, "prestige: 0")
	_ascension_label = _make_status_label(status, "ascension: 0")
	_transcendence_label = _make_status_label(status, "transc.: 0")

	# Message line.
	_message_label = Label.new()
	_message_label.text = "There is a number. It goes up."
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_color_override("font_color", COLOR_DIM)
	_message_label.add_theme_font_size_override("font_size", 16)
	tab.add_child(_message_label)

	var sep := HSeparator.new()
	tab.add_child(sep)

	# Lower split: prestige panel (left) + upgrades (right).
	var lower := HBoxContainer.new()
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(lower)

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

	_ascension_button = Button.new()
	_ascension_button.text = "ASCEND\n(locked — reach prestige 10)"
	_ascension_button.add_theme_font_size_override("font_size", 18)
	_ascension_button.add_theme_color_override("font_color", COLOR_GOLD)
	_ascension_button.custom_minimum_size = Vector2(0, 70)
	_ascension_button.pressed.connect(_on_ascension_pressed)
	left_col.add_child(_ascension_button)

	_transcendence_button = Button.new()
	_transcendence_button.text = "TRANSCEND\n(locked — reach ascension 5)"
	_transcendence_button.add_theme_font_size_override("font_size", 18)
	_transcendence_button.add_theme_color_override("font_color", Color("#cc44ff"))
	_transcendence_button.custom_minimum_size = Vector2(0, 70)
	_transcendence_button.pressed.connect(_on_transcendence_pressed)
	left_col.add_child(_transcendence_button)

	var help := Label.new()
	help.text = "Prestige: +2%/lvl (slow persists). Ascend at prestige 10: x1.1/lvl, resets prestige + slow. Transcend at ascension 5: +5%/lvl, full reset, number shifts hue 30°/lvl."
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

func _build_stats_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Stats"
	_tab_container.add_child(scroll)
	_stats_container = VBoxContainer.new()
	_stats_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_stats_container)

func _refresh_stats_tab() -> void:
	for child in _stats_container.get_children():
		child.queue_free()
	var notation: String = GameState.settings["notation"]

	var title := Label.new()
	title.text = "STATISTICS"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	_stats_container.add_child(title)

	_stats_container.add_child(HSeparator.new())

	var general := Label.new()
	general.text = "GENERAL"
	general.add_theme_font_size_override("font_size", 18)
	general.add_theme_color_override("font_color", COLOR_DIM)
	_stats_container.add_child(general)
	_add_stat_row("Current number", NumberFormatter.format(GameState.number, notation))
	_add_stat_row("Total earned (lifetime)", NumberFormatter.format(GameState.total_earned, notation))
	_add_stat_row("Production rate", NumberFormatter.format(GameState.effective_rate(), notation) + "/s")
	_add_stat_row("Click power", NumberFormatter.format(GameState.click_value(), notation))
	_add_stat_row("Total clicks", str(GameState.total_clicks))
	_add_stat_row("Prestige level", str(GameState.prestige_level))
	_add_stat_row("Ascension level", str(GameState.ascension_level))
	_add_stat_row("Transcendence level", str(GameState.transcendence_level))
	_add_stat_row("Red buttons owned", str(GameState.red_count))
	_add_stat_row("Mystery buttons owned", str(GameState.mystery_count))
	var penalty := 1.0 - GameState.slow_mult
	_add_stat_row("Slow penalty", "%.1f%%" % (penalty * 100.0))
	if GameState.heavy_wallet:
		_add_stat_row("Heavy Wallet", "ACTIVE (\u22120.001% production, permanent, you paid for this)")

	_stats_container.add_child(HSeparator.new())

	var funny_header := Label.new()
	funny_header.text = "FUNNY NUMBER SIGHTINGS"
	funny_header.add_theme_font_size_override("font_size", 18)
	funny_header.add_theme_color_override("font_color", COLOR_DIM)
	_stats_container.add_child(funny_header)

	if GameState.funny_sightings.is_empty():
		var none := Label.new()
		none.text = "None yet. The number hasn't been funny."
		none.add_theme_color_override("font_color", COLOR_DIM)
		none.add_theme_font_size_override("font_size", 14)
		_stats_container.add_child(none)
	else:
		for entry in FunnyNumberDB.REGISTRY:
			var pattern: String = entry.pattern
			var count: int = GameState.funny_sightings.get(pattern, 0)
			if count == 0:
				continue
			var row := HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_stats_container.add_child(row)
			var color_swatch := ColorRect.new()
			color_swatch.color = Color.from_string(entry.color, COLOR_GOLD)
			color_swatch.custom_minimum_size = Vector2(20, 20)
			row.add_child(color_swatch)
			var label := Label.new()
			label.text = "  %s (%s)" % [entry.label, pattern]
			label.add_theme_font_size_override("font_size", 16)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			var count_lbl := Label.new()
			count_lbl.text = str(count)
			count_lbl.add_theme_font_size_override("font_size", 16)
			count_lbl.add_theme_color_override("font_color", COLOR_GOLD)
			count_lbl.custom_minimum_size = Vector2(60, 0)
			count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(count_lbl)

	_stats_container.add_child(HSeparator.new())

	var stare_label := Label.new()
	stare_label.text = "...are you still looking at this?"
	stare_label.add_theme_color_override("font_color", COLOR_DIM)
	stare_label.add_theme_font_size_override("font_size", 12)
	stare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_container.add_child(stare_label)

func _add_stat_row(label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_container.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 15)
	val.add_theme_color_override("font_color", COLOR_GREEN)
	val.custom_minimum_size = Vector2(200, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)

func _build_cards_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Cards"
	_tab_container.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "STEAM TRADING CARDS"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "You can't actually collect them here. This is just a viewer. Steam handles the real ones."
	subtitle.add_theme_color_override("font_color", COLOR_DIM)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)
	for card in CardsDB.CARDS:
		var card_panel := PanelContainer.new()
		card_panel.custom_minimum_size = Vector2(140, 180)
		var style := StyleBoxFlat.new()
		style.bg_color = Color.from_string(card.bg_color, Color("#1a1a1a"))
		style.border_color = CardsDB.rarity_color(card.rarity)
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(12)
		card_panel.add_theme_stylebox_override("panel", style)
		grid.add_child(card_panel)
		var card_vbox := VBoxContainer.new()
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card_panel.add_child(card_vbox)
		var num_label := Label.new()
		num_label.text = card.number
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_label.add_theme_font_size_override("font_size", 32)
		num_label.add_theme_color_override("font_color", CardsDB.rarity_color(card.rarity))
		card_vbox.add_child(num_label)
		var rarity_label := Label.new()
		rarity_label.text = CardsDB.rarity_name(card.rarity)
		rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_label.add_theme_font_size_override("font_size", 12)
		rarity_label.add_theme_color_override("font_color", CardsDB.rarity_color(card.rarity))
		card_vbox.add_child(rarity_label)
		if card.dlc:
			var dlc_label := Label.new()
			dlc_label.text = "DLC"
			dlc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			dlc_label.add_theme_font_size_override("font_size", 10)
			dlc_label.add_theme_color_override("font_color", COLOR_GOLD)
			card_vbox.add_child(dlc_label)

func _build_settings_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Settings"
	_tab_container.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	# Notation mode
	_add_settings_label(vbox, "Notation Mode")
	_settings_notation_selector = OptionButton.new()
	_settings_notation_selector.add_item("Normal Person", 0)
	_settings_notation_selector.add_item("Number Enjoyer", 1)
	_settings_notation_selector.add_item("Unhinged", 2)
	_settings_notation_selector.add_item("Nerd", 3)
	_settings_notation_selector.item_selected.connect(_on_notation_changed)
	vbox.add_child(_settings_notation_selector)
	_sync_notation_selector()

	# Screen shake
	_add_settings_label(vbox, "Screen Shake")
	_settings_shake_selector = OptionButton.new()
	_settings_shake_selector.add_item("Off", 0)
	_settings_shake_selector.add_item("On", 1)
	_settings_shake_selector.add_item("MAXIMUM", 2)
	_settings_shake_selector.item_selected.connect(_on_shake_changed)
	vbox.add_child(_settings_shake_selector)
	_sync_shake_selector()

	# Toggles
	_add_toggle(vbox, "Offline Progress", "offline", _on_toggle_changed)
	_add_toggle(vbox, "Funny Number Popups", "funny_popups", _on_toggle_changed)

	# Volume sliders (no audio backend yet — Phase 3 will wire these)
	vbox.add_child(HSeparator.new())
	_add_settings_label(vbox, "Audio (placeholders — audio system coming in Phase 3)")
	_add_volume_slider(vbox, "Master", "master_volume")
	_add_volume_slider(vbox, "Music", "music_volume")
	_add_volume_slider(vbox, "SFX", "sfx_volume")
	_add_volume_slider(vbox, "Funny Number Stinger", "stinger_volume")

	# Number color override (locked unless 1+ transcendence)
	vbox.add_child(HSeparator.new())
	_add_settings_label(vbox, "Number Color Override")
	var can_override := GameState.transcendence_level > 0
	if not can_override:
		var locked := Label.new()
		locked.text = "Locked. Reach transcendence level 1 to unlock."
		locked.add_theme_color_override("font_color", COLOR_DIM)
		locked.add_theme_font_size_override("font_size", 13)
		vbox.add_child(locked)
	else:
		_settings_color_hue_slider = HSlider.new()
		_settings_color_hue_slider.min_value = 0.0
		_settings_color_hue_slider.max_value = 1.0
		_settings_color_hue_slider.step = 0.01
		_settings_color_hue_slider.value = GameState.settings.get("color_override_hue", 0.0)
		_settings_color_hue_slider.custom_minimum_size = Vector2(300, 0)
		_settings_color_hue_slider.value_changed.connect(_on_color_hue_changed)
		vbox.add_child(_settings_color_hue_slider)
		_settings_color_hue_label = Label.new()
		_settings_color_hue_label.text = "Hue: %.0f\u00b0" % (_settings_color_hue_slider.value * 360.0)
		_settings_color_hue_label.add_theme_color_override("font_color", COLOR_DIM)
		_settings_color_hue_label.add_theme_font_size_override("font_size", 13)
		vbox.add_child(_settings_color_hue_label)

func _build_workshop_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Workshop"
	_tab_container.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "STEAM WORKSHOP"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Community meme packs for funny number popups. We are not responsible for what the community does with this."
	subtitle.add_theme_color_override("font_color", COLOR_DIM)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	# Browse Workshop button.
	var browse_btn := Button.new()
	browse_btn.text = "Browse Workshop on Steam"
	browse_btn.add_theme_font_size_override("font_size", 16)
	browse_btn.custom_minimum_size = Vector2(0, 40)
	browse_btn.pressed.connect(_on_browse_workshop)
	vbox.add_child(browse_btn)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh Installed Packs"
	refresh_btn.add_theme_font_size_override("font_size", 14)
	refresh_btn.pressed.connect(_on_refresh_packs)
	vbox.add_child(refresh_btn)

	vbox.add_child(HSeparator.new())

	var packs_header := Label.new()
	packs_header.text = "INSTALLED PACKS"
	packs_header.add_theme_font_size_override("font_size", 18)
	packs_header.add_theme_color_override("font_color", COLOR_DIM)
	vbox.add_child(packs_header)

	# Pack list container — rebuilt on scan.
	_workshop_container = vbox
	_refresh_workshop_list()

func _refresh_workshop_list() -> void:
	# Remove old pack entries (everything after the header).
	var children := _workshop_container.get_children()
	var start_idx := 0
	for i in children.size():
		if children[i] is Label and children[i].text == "INSTALLED PACKS":
			start_idx = i + 1
			break
	for i in range(children.size() - 1, start_idx, -1):
		children[i].queue_free()

	var packs := WorkshopManager.get_packs()
	if packs.is_empty():
		var none := Label.new()
		none.text = "\nNo packs installed. Subscribe to packs on the Steam Workshop, or create your own and place them in the packs folder."
		none.add_theme_color_override("font_color", COLOR_DIM)
		none.add_theme_font_size_override("font_size", 14)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_workshop_container.add_child(none)
		return

	for pack in packs:
		var manifest: Dictionary = pack.manifest
		var pack_row := HBoxContainer.new()
		pack_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_workshop_container.add_child(pack_row)

		# Enable/disable toggle.
		var toggle := CheckButton.new()
		toggle.button_pressed = pack.enabled
		toggle.toggled.connect(_on_pack_toggled.bind(pack.folder_name))
		pack_row.add_child(toggle)

		# Pack info.
		var info_col := VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pack_row.add_child(info_col)
		var name_lbl := Label.new()
		name_lbl.text = manifest.get("name", pack.folder_name)
		name_lbl.add_theme_font_size_override("font_size", 16)
		info_col.add_child(name_lbl)
		var author_lbl := Label.new()
		author_lbl.text = "by %s  |  v%s  |  priority: %d  |  source: %s" % [
			manifest.get("author", "unknown"),
			manifest.get("version", "?"),
			manifest.get("priority", 0),
			pack.source,
		]
		author_lbl.add_theme_color_override("font_color", COLOR_DIM)
		author_lbl.add_theme_font_size_override("font_size", 12)
		info_col.add_child(author_lbl)
		if manifest.has("description"):
			var desc_lbl := Label.new()
			desc_lbl.text = manifest.get("description", "")
			desc_lbl.add_theme_color_override("font_color", COLOR_DIM)
			desc_lbl.add_theme_font_size_override("font_size", 12)
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info_col.add_child(desc_lbl)

		# Priority up/down buttons.
		var up_btn := Button.new()
		up_btn.text = "\u2191"
		up_btn.custom_minimum_size = Vector2(36, 36)
		up_btn.pressed.connect(_on_pack_up.bind(pack.folder_name))
		pack_row.add_child(up_btn)
		var down_btn := Button.new()
		down_btn.text = "\u2193"
		down_btn.custom_minimum_size = Vector2(36, 36)
		down_btn.pressed.connect(_on_pack_down.bind(pack.folder_name))
		pack_row.add_child(down_btn)

func _on_browse_workshop() -> void:
	WorkshopManager.browse_workshop()

func _on_refresh_packs() -> void:
	WorkshopManager.scan_packs()
	_refresh_workshop_list()

func _on_pack_toggled(enabled: bool, folder_name: String) -> void:
	WorkshopManager.set_pack_enabled(folder_name, enabled)

func _on_pack_up(folder_name: String) -> void:
	WorkshopManager.move_pack_up(folder_name)
	_refresh_workshop_list()

func _on_pack_down(folder_name: String) -> void:
	WorkshopManager.move_pack_down(folder_name)
	_refresh_workshop_list()

func _add_settings_label(parent: Container, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	parent.add_child(lbl)

func _add_toggle(parent: Container, label_text: String, settings_key: String, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var btn := CheckButton.new()
	btn.button_pressed = bool(GameState.settings.get(settings_key, true))
	btn.toggled.connect(callback.bind(settings_key))
	row.add_child(btn)

func _add_volume_slider(parent: Container, label_text: String, settings_key: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.custom_minimum_size = Vector2(160, 0)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = GameState.settings.get(settings_key, 1.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_volume_changed.bind(settings_key))
	row.add_child(slider)

func _sync_notation_selector() -> void:
	var mode: String = GameState.settings.get("notation", "extended")
	match mode:
		"normal": _settings_notation_selector.selected = 0
		"extended": _settings_notation_selector.selected = 1
		"unhinged": _settings_notation_selector.selected = 2
		"nerd": _settings_notation_selector.selected = 3

func _sync_shake_selector() -> void:
	var mode: String = GameState.settings.get("screen_shake", "on")
	match mode:
		"off": _settings_shake_selector.selected = 0
		"on": _settings_shake_selector.selected = 1
		"maximum": _settings_shake_selector.selected = 2

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

func _refresh_ascension() -> void:
	if GameState.can_ascend():
		_ascension_button.text = "ASCEND\nlevel %d → %d\n(x1.1 production/lvl, resets prestige + slow)" % [GameState.ascension_level, GameState.ascension_level + 1]
		_ascension_button.disabled = false
	else:
		_ascension_button.text = "ASCEND\n(locked — reach prestige %d)" % GameState.ASCENSION_UNLOCK_LEVEL
		_ascension_button.disabled = true
	_ascension_label.text = "ascension: %d" % GameState.ascension_level

func _refresh_transcendence() -> void:
	if GameState.can_transcend():
		_transcendence_button.text = "TRANSCEND\nlevel %d → %d\n(+5%%/lvl, full reset, hue shift)" % [GameState.transcendence_level, GameState.transcendence_level + 1]
		_transcendence_button.disabled = false
	else:
		_transcendence_button.text = "TRANSCEND\n(locked — reach ascension %d)" % GameState.TRANSCENDENCE_UNLOCK_LEVEL
		_transcendence_button.disabled = true
	_transcendence_label.text = "transc.: %d" % GameState.transcendence_level

func _process(delta: float) -> void:
	if _gold_flash_remaining > 0.0:
		_gold_flash_remaining = maxf(_gold_flash_remaining - delta, 0.0)
		if _gold_flash_remaining == 0.0:
			_apply_number_color()
	_refresh_all_rows()
	_refresh_prestige()
	_refresh_ascension()
	_refresh_transcendence()
	_check_heavy_wallet()
	_update_toast(delta)
	_update_shake(delta)
	_update_flicker(delta)
	_update_slow_ghost(delta)
	_process_rapid_click(delta)
	_update_unhinged_chaos(delta)
	# Cheater overlay stays visible while penalty active.
	_cheater_overlay.visible = SaveSystem.is_cheater_active()

func _track_tab_activity(delta: float) -> void:
	var current_tab := _tab_container.current_tab
	# Stats tab — "The Long Stare" achievement (2 min stare, no input).
	var stats_visible := (current_tab == 1)
	if stats_visible:
		if not _stats_was_visible:
			_stats_was_visible = true
			_refresh_stats_tab()
		_stats_tab_open_seconds += delta
		SteamIntegration.notify_stats_tab(delta)
	else:
		_stats_was_visible = false
		SteamIntegration.reset_stats_tab_timer()
	# Cards tab — "Card Collector" achievement on first view.
	if current_tab == 2 and not _cards_viewed:
		_cards_viewed = true
		SteamIntegration.notify_cards_tab_opened()

func _check_heavy_wallet() -> void:
	_wallet_icon.visible = GameState.heavy_wallet
	if GameState.heavy_wallet and not GameState.heavy_wallet_acknowledged:
		_fate_overlay.visible = true
	# Position the tooltip near the wallet icon.
	if _wallet_tooltip.visible:
		var icon_pos := _wallet_icon.get_global_position()
		_wallet_tooltip.position = Vector2(icon_pos.x, icon_pos.y - 20)

func _show_offline_toast(gained: float) -> void:
	var notation: String = GameState.settings["notation"]
	var text := "While you were gone, the number went up by " + NumberFormatter.format(gained, notation) + ". It didn't miss you."
	if GameState.heavy_wallet:
		text += "\n(0.001% less than it would have been without the DLC.)"
	_toast_label.text = text
	_toast_panel.visible = true
	_toast_panel.modulate.a = 1.0
	_toast_remaining = 5.0

func _update_toast(delta: float) -> void:
	if not _toast_panel.visible:
		return
	_toast_remaining -= delta
	if _toast_remaining <= 0.0:
		_toast_panel.visible = false
		return
	if _toast_remaining < 1.0:
		_toast_panel.modulate.a = _toast_remaining

# --- Screen shake & flicker (GDD §4.1) --------------------------------------
func _trigger_shake(click_value: float) -> void:
	var mode: String = GameState.settings.get("screen_shake", "on")
	if mode == "off":
		return
	if mode == "maximum":
		_shake_intensity = 8.0
		_flicker_remaining = 0.15
		return
	if click_value >= 1000000.0:
		_shake_intensity = 8.0
		_flicker_remaining = 0.15
	elif click_value >= 10000.0:
		_shake_intensity = 3.0

func _update_shake(delta: float) -> void:
	if _shake_intensity > 0.0:
		var offset := Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
		position = _base_position + offset
		_shake_intensity = maxf(_shake_intensity - delta * 30.0, 0.0)
		if _shake_intensity == 0.0:
			position = _base_position

func _update_flicker(delta: float) -> void:
	if _flicker_remaining > 0.0:
		_flicker_remaining = maxf(_flicker_remaining - delta, 0.0)
		_flicker_overlay.color.a = _flicker_remaining * 3.0
	else:
		_flicker_overlay.color.a = 0.0

func _update_slow_ghost(delta: float) -> void:
	# GDD §3.3: slow penalty active — subtle trailing ghost effect on digits.
	var slow_penalty := 1.0 - GameState.slow_mult
	if slow_penalty < 0.20:
		_ghost_spawn_timer = 0.0
		return
	_ghost_spawn_timer += delta
	var spawn_interval := lerpf(0.3, 0.08, slow_penalty)
	if _ghost_spawn_timer < spawn_interval:
		return
	_ghost_spawn_timer = 0.0
	# Spawn a faint ghost of the current number text.
	var ghost := Label.new()
	ghost.text = _number_label.text
	ghost.horizontal_alignment = _number_label.horizontal_alignment
	ghost.vertical_alignment = _number_label.vertical_alignment
	ghost.set_anchors_preset(PRESET_FULL_RECT)
	ghost.add_theme_font_size_override("font_size", _number_label.get_theme_font_size("font_size"))
	ghost.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 0.3))
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(ghost)
	var tween := create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(ghost.queue_free)

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
	_gold_flash_remaining = 10.0
	_apply_number_color()
	_refresh_all_rows()
	AudioManager.on_prestige()

func _on_ascension_performed(level: int, quote: String) -> void:
	_message_label.text = quote
	_gold_flash_remaining = 10.0
	_apply_number_color()
	_refresh_all_rows()
	AudioManager.on_ascension()

func _on_transcendence_performed(level: int, quote: String) -> void:
	_message_label.text = quote
	_apply_number_color()
	_refresh_all_rows()
	AudioManager.on_transcendence()

func _on_message_emitted(text: String) -> void:
	_message_label.text = text

func _on_red_corruption_changed(red_count: int) -> void:
	_apply_number_color()
	_apply_corruption()

func _on_funny_popup(entry: Dictionary) -> void:
	_spawn_funny_popup(entry)
	AudioManager.play_stinger(entry.pattern)

func _on_dlc_changed(_active: bool) -> void:
	_check_heavy_wallet()

func _on_offline_report(_gained: float) -> void:
	AudioManager.on_offline_return()
# --- Input ------------------------------------------------------------------
func _on_click_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_do_click()
	elif event.is_action_pressed("click"):
		_do_click()

func _unhandled_input(event: InputEvent) -> void:
	# Controller/Deck mapping (GDD §14).
	if event.is_action_pressed("gamepad_click"):
		_do_click()
	elif event.is_action_pressed("gamepad_tab_switch"):
		_cycle_tab()
	# Right trigger = rapid click (handled via _process polling).

var _rapid_click_accumulator: float = 0.0
func _process_rapid_click(delta: float) -> void:
	if Input.is_action_pressed("gamepad_rapid_click"):
		_rapid_click_accumulator += delta
		if _rapid_click_accumulator >= 0.1:  # 10 clicks/s
			_rapid_click_accumulator = 0.0
			_do_click()
	else:
		_rapid_click_accumulator = 0.0

func _cycle_tab() -> void:
	var count := _tab_container.get_tab_count()
	_tab_container.current_tab = (_tab_container.current_tab + 1) % count

func _update_unhinged_chaos(delta: float) -> void:
	# GDD §3.2: Unhinged mode — the number pushes other elements around.
	if GameState.settings["notation"] != "unhinged":
		_unhinged_chaos_timer = 0.0
		return
	_unhinged_chaos_timer += delta
	if _unhinged_chaos_timer < 2.0:
		return
	_unhinged_chaos_timer = 0.0
	# Apply a brief chaotic nudge to a random upgrade row.
	var ids := _upgrade_rows.keys()
	if ids.is_empty():
		return
	var pick: String = ids[randi() % ids.size()]
	var row: Dictionary = _upgrade_rows[pick]
	var root: Control = row.get("root", null)
	if root == null:
		return
	var tween := create_tween()
	var offset_x := randf_range(-6.0, 6.0)
	var rot := randf_range(-0.02, 0.02)
	tween.tween_property(root, "position:x", root.position.x + offset_x, 0.3).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(root, "rotation", rot, 0.3)
	tween.chain().tween_property(root, "position:x", root.position.x, 0.4)
	tween.parallel().tween_property(root, "rotation", 0.0, 0.4)

func _do_click() -> void:
	GameState.click()
	SteamIntegration.on_click()
	var value := GameState.click_value()
	_spawn_floating_text("+" + NumberFormatter.format(value, GameState.settings["notation"]))
	_trigger_shake(value)
	AudioManager.play_sfx("click")

func _on_buy(id: String) -> void:
	GameState.buy(id)
	# SFX: red/slow/mystery have special sounds; everything else uses buy.
	match id:
		"red": AudioManager.play_sfx("buy_red")
		"slow": AudioManager.play_sfx("buy_slow")
		"mystery": AudioManager.play_sfx("buy_mystery")
		_: AudioManager.play_sfx("buy")

func _on_prestige_pressed() -> void:
	GameState.prestige()

func _on_ascension_pressed() -> void:
	GameState.ascend()

func _on_transcendence_pressed() -> void:
	GameState.transcend()

func _on_fate_accepted() -> void:
	GameState.heavy_wallet_acknowledged = true
	_fate_overlay.visible = false

# --- Settings handlers ------------------------------------------------------
func _on_notation_changed(index: int) -> void:
	match index:
		0: GameState.settings["notation"] = "normal"
		1: GameState.settings["notation"] = "extended"
		2: GameState.settings["notation"] = "unhinged"
		3: GameState.settings["notation"] = "nerd"
	SteamIntegration.notify_notation_changed()
	GameState.mark_rate_dirty()
	_apply_number_color()

func _on_shake_changed(index: int) -> void:
	match index:
		0: GameState.settings["screen_shake"] = "off"
		1: GameState.settings["screen_shake"] = "on"
		2: GameState.settings["screen_shake"] = "maximum"

func _on_toggle_changed(pressed: bool, settings_key: String) -> void:
	GameState.settings[settings_key] = pressed

func _on_volume_changed(value: float, settings_key: String) -> void:
	GameState.settings[settings_key] = value
	AudioManager.update_volumes_from_settings()

func _on_color_hue_changed(value: float) -> void:
	GameState.settings["color_override_hue"] = value
	GameState.settings["color_override_enabled"] = true
	if _settings_color_hue_label:
		_settings_color_hue_label.text = "Hue: %.0f\u00b0" % (value * 360.0)
	_apply_number_color()

# --- Color / corruption -----------------------------------------------------
func _apply_number_color() -> void:
	if _gold_flash_remaining > 0.0:
		# Fade from gold to actual color over the remaining duration.
		var base_color: Color
		if GameState.red_count >= 6:
			base_color = COLOR_RED
		elif GameState.settings.get("color_override_enabled", false) and GameState.transcendence_level > 0:
			var hue: float = GameState.settings.get("color_override_hue", 0.0)
			base_color = Color.from_hsv(hue, 0.6, 1.0)
		elif GameState.transcendence_level > 0:
			base_color = GameState.transcendence_color()
		else:
			base_color = COLOR_GREEN
		var t := _gold_flash_remaining / 10.0
		var blended := COLOR_GOLD.lerp(base_color, 1.0 - t)
		_number_label.add_theme_color_override("font_color", blended)
		return
	if GameState.red_count >= 6:
		_number_label.add_theme_color_override("font_color", COLOR_RED)
	elif GameState.settings.get("color_override_enabled", false) and GameState.transcendence_level > 0:
		var hue: float = GameState.settings.get("color_override_hue", 0.0)
		_number_label.add_theme_color_override("font_color", Color.from_hsv(hue, 0.6, 1.0))
	elif GameState.transcendence_level > 0:
		_number_label.add_theme_color_override("font_color", GameState.transcendence_color())
	else:
		_number_label.add_theme_color_override("font_color", COLOR_GREEN)

func _apply_corruption() -> void:
	var red := GameState.red_count
	var opacity: float = 0.0
	if red >= 50:
		# Everything is red. The background. The text. The buy buttons. Everything.
		opacity = 0.55
	elif red >= 20:
		# UI develops a red tint, ramping up from 20 to 50.
		opacity = 0.15 + (float(red - 20) / 30.0) * 0.40
	_corruption_overlay.color.a = opacity

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
	var pattern: String = entry.pattern
	var override: Variant = WorkshopManager.resolve_popup(pattern)
	if override != null and typeof(override) == TYPE_DICTIONARY:
		var override_type: String = override.type
		match override_type:
			"image":
				_spawn_image_popup(override.path, entry)
				return
			"video":
				_spawn_video_popup(override.path, entry)
				return
	# Default: text popup.
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

func _spawn_image_popup(file_path: String, entry: Dictionary) -> void:
	var texture := WorkshopManager.load_image_from_file(file_path)
	if texture == null:
		_spawn_funny_popup(entry)  # fallback to text
		return
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var max_size := 300
	if texture.get_width() > max_size or texture.get_height() > max_size:
		var scale_factor: float = float(max_size) / max(texture.get_width(), texture.get_height())
		rect.custom_minimum_size = Vector2(texture.get_width() * scale_factor, texture.get_height() * scale_factor)
	else:
		rect.custom_minimum_size = Vector2(texture.get_width(), texture.get_height())
	var screen := get_viewport_rect().size
	rect.position = Vector2(
		screen.x * randf_range(0.10, 0.70),
		screen.y * randf_range(0.15, 0.45)
	)
	rect.rotation = deg_to_rad(randf_range(-15.0, 15.0))
	rect.z_index = 100
	_overlay.add_child(rect)
	var tween := create_tween()
	tween.tween_property(rect, "scale", Vector2(1.5, 1.5), 0.15).from(Vector2(0.2, 0.2))
	tween.tween_property(rect, "scale", Vector2(1.0, 1.0), 0.15)
	tween.parallel().tween_property(rect, "position:y", rect.position.y - 90, 2.2)
	tween.parallel().tween_property(rect, "modulate:a", 0.0, 2.2)
	tween.chain().tween_callback(rect.queue_free)

func _spawn_video_popup(file_path: String, entry: Dictionary) -> void:
	var stream := load_video_stream(file_path)
	if stream == null:
		_spawn_image_popup(file_path, entry)  # try as image, then fallback
		return
	var player := VideoStreamPlayer.new()
	player.stream = stream
	player.autoplay = true
	player.loop = false
	player.custom_minimum_size = Vector2(320, 240)
	var screen := get_viewport_rect().size
	player.position = Vector2(
		screen.x * randf_range(0.10, 0.60),
		screen.y * randf_range(0.15, 0.40)
	)
	player.z_index = 100
	_overlay.add_child(player)
	var tween := create_tween()
	tween.tween_property(player, "scale", Vector2(1.5, 1.5), 0.15).from(Vector2(0.2, 0.2))
	tween.tween_property(player, "scale", Vector2(1.0, 1.0), 0.15)
	tween.parallel().tween_property(player, "position:y", player.position.y - 90, 2.2)
	tween.parallel().tween_property(player, "modulate:a", 0.0, 2.2)
	tween.chain().tween_callback(player.queue_free)

func load_video_stream(file_path: String) -> VideoStream:
	var ext := file_path.get_extension().to_lower()
	if ext == "ogv":
		return load(file_path) as VideoStream
	# WebM support depends on engine build; try loading.
	var loaded: Variant = load(file_path)
	if loaded is VideoStream:
		return loaded
	return null

func _show_cheater() -> void:
	_message_label.text = "Nice try."
