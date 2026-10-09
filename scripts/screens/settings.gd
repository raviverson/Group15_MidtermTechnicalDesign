extends Control
## Storyboard 12 — Settings (saved in SQLite `settings` table).

const LANGUAGES := [["en", "English"], ["fil", "Filipino (content not yet translated)"]]


func _ready() -> void:
	var body := UI.screen(self, "Settings", on_back, "clinic")
	var c := CenterContainer.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(c)
	var parts := UI.card("SETTINGS", UI.C_PRIMARY_DARK, 600)
	c.add_child(parts[0])
	var v: VBoxContainer = parts[1]
	v.add_theme_constant_override("separation", 16)
	for pair: Array in [["sound", "Sound"], ["music", "Music"], ["vibration", "Vibration"]]:
		var key: String = pair[0]
		var row := UI.hbox(16)
		var name_lbl := UI.label(str(pair[1]).to_upper(), 24)
		name_lbl.add_theme_font_override("font", UI.font_bold())
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		var sw := ToggleSwitch.new(Database.get_setting_bool(key))
		sw.name = "Toggle_" + key
		sw.toggled.connect(func(on: bool) -> void: Database.set_setting(key, on))
		row.add_child(sw)
		v.add_child(row)
	var lang_row := UI.hbox(16)
	var ll := UI.label("LANGUAGE", 24)
	ll.add_theme_font_override("font", UI.font_bold())
	lang_row.add_child(ll)
	var opt := OptionButton.new()
	opt.add_theme_font_size_override("font_size", 18)
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cur := Database.get_setting("language")
	for i: int in LANGUAGES.size():
		opt.add_item(LANGUAGES[i][1], i)
		if LANGUAGES[i][0] == cur:
			opt.select(i)
	opt.item_selected.connect(func(i: int) -> void: Database.set_setting("language", LANGUAGES[i][0]))
	lang_row.add_child(opt)
	v.add_child(lang_row)
	var reset_row := UI.hbox(16)
	var rl := UI.label("RESET PROGRESS", 24)
	rl.add_theme_font_override("font", UI.font_bold())
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_row.add_child(rl)
	var reset := UI.button("RESET", UI.C_ORANGE, Vector2(140, 48), 20)
	reset.pressed.connect(_confirm_reset)
	reset_row.add_child(reset)
	v.add_child(reset_row)
	v.add_child(UI.label("Save file: %s" % ProjectSettings.globalize_path(Database.DB_PATH), 13, UI.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	FX.pop_in(parts[0], 0.0, 0.85)


func _confirm_reset() -> void:
	var d := ConfirmationDialog.new()
	d.title = "Reset progress"
	d.dialog_text = "Erase all stars, scores and achievements?\nThis cannot be undone."
	add_child(d)
	d.confirmed.connect(func() -> void:
		Database.reset_progress()
		Game.goto("settings"))
	d.popup_centered()


func on_back() -> void:
	Game.goto("main_menu")
