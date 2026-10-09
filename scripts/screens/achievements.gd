extends Control
## Achievements list (trophy button, storyboard 01).


func _ready() -> void:
	var body := UI.screen(self, "Achievements", on_back, "clinic")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var i := 0
	for a: Dictionary in Database.get_achievements():
		var got: bool = a["unlocked_at"] != null
		var card := UI.panel(UI.C_CREAM if got else Color("#e3ddd2"), 14, 12)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := UI.hbox(14)
		card.add_child(row)
		row.add_child(Icon.new("trophy" if got else "lock", UI.C_STAR if got else UI.C_LOCK, 48))
		var txt := UI.vbox(2)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := UI.label(str(a["title"]), 24, UI.C_PRIMARY_DARK if got else UI.C_MUTED)
		t.add_theme_font_override("font", UI.font_bold())
		txt.add_child(t)
		txt.add_child(UI.label(str(a["description"]), 17, UI.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
		row.add_child(txt)
		grid.add_child(card)
		FX.pop_in(card, 0.04 * i, 0.9)
		i += 1


func on_back() -> void:
	Game.goto("main_menu")
