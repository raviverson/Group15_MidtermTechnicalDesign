extends Control
## Storyboard 02 — Select level. Locked levels open as the previous one is cleared.


func _ready() -> void:
	var body := UI.screen(self, "Select Level", on_back, "clinic")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	var n := 0
	for lv: Dictionary in Database.get_levels():
		n += 1
		var card := _card(lv, n)
		grid.add_child(card)
		FX.pop_in(card, 0.04 * n, 0.9)


func _card(lv: Dictionary, n: int) -> Control:
	var unlocked: bool = lv["unlocked"]
	var parts := UI.card("LEVEL %d" % n, UI.C_PRIMARY_DARK if unlocked else UI.C_LOCK)
	var card: PanelContainer = parts[0]
	card.name = "Level%d" % n
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body: VBoxContainer = parts[1]
	body.add_theme_constant_override("separation", 2)
	var m: MarginContainer = body.get_parent()
	for side: String in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 8)
	var icon_holder := CenterContainer.new()
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UI.style(UI.C_CREAM_DARK if unlocked else Color("#dcd6cc"), 40, UI.C_BROWN, 2, 6))
	var ic := Icon.new(str(lv.get("icon", "info")), UI.C_RED if unlocked else UI.C_LOCK, 38)
	badge.add_child(ic)
	icon_holder.add_child(badge)
	body.add_child(icon_holder)
	var t := UI.label(str(lv["title"]), 22, UI.C_PRIMARY_DARK if unlocked else UI.C_LOCK, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_override("font", UI.font_bold())
	body.add_child(t)
	for d: String in Game.DIFFICULTY_ORDER:
		var row := UI.hbox(4)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var dl := UI.label(Game.diff_of(d)["label"], 14, UI.C_MUTED)
		dl.custom_minimum_size = Vector2(52, 0)
		row.add_child(dl)
		row.add_child(StarRow.new(int(lv[d]["best_stars"]), 9.0))
		body.add_child(row)
	var b := UI.button("PLAY" if unlocked else "LOCKED", UI.C_PRIMARY, Vector2(0, 40), 18)
	b.name = "Play"
	b.disabled = not unlocked
	if not unlocked:
		var lk := Icon.new("lock", Color.WHITE, 22)
		b.add_child(lk)
		lk.position = Vector2(12, 10)
	b.pressed.connect(func() -> void:
		Game.current_level_id = int(lv["id"])
		Game.goto("difficulty_select"))
	body.add_child(b)
	return card


func on_back() -> void:
	Game.goto("main_menu")
