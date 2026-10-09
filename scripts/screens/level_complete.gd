extends Control
## Storyboard 10 — Level complete: stars pop in, score counts up, confetti.


func _ready() -> void:
	var r: Dictionary = Game.last_result
	var level_id := int(r.get("level_id", Game.current_level_id))
	var lv := Database.get_level(level_id)
	var n := int(lv.get("sort_order", 1))
	var stars := int(r.get("stars", 0))
	var passed := stars >= 1
	UI.background(self, "forest")
	var c := UI.center_in(self)
	var head := ("LEVEL %d COMPLETE!" % n) if passed else "KEEP PRACTICING"
	var parts := UI.card(head, UI.C_PRIMARY if passed else UI.C_ORANGE, 640)
	var card: PanelContainer = parts[0]
	c.add_child(card)
	var body: VBoxContainer = parts[1]
	body.add_child(UI.label("%s - %s" % [lv.get("title", ""), Game.diff_of(str(r.get("difficulty", "easy")))["label"]], 20, UI.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var sr := StarRow.new(stars, 40.0)
	sr.name = "Stars"
	sr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(sr)

	var stats := UI.hbox(14)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(stats)
	var score_box := UI.panel(UI.C_CREAM_DARK, 12, 12)
	score_box.custom_minimum_size = Vector2(220, 0)
	var sv := UI.vbox(0)
	score_box.add_child(sv)
	sv.add_child(UI.label("SCORE", 18, UI.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var score_lbl := UI.title("0", 54, UI.C_PRIMARY_DARK, UI.C_CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	score_lbl.name = "Score"
	sv.add_child(score_lbl)
	sv.add_child(UI.label("of %d" % int(r.get("max_score", 0)), 16, UI.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	stats.add_child(score_box)
	var table := UI.panel(UI.C_CREAM_DARK, 12, 12)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	table.add_child(grid)
	for pair: Array in [["CORRECT", str(int(r.get("correct", 0))), UI.C_GOOD], ["INCORRECT", str(int(r.get("incorrect", 0))), UI.C_RED],
			["STRIKES", "%d / 3" % int(r.get("strikes", 0)), UI.C_RED], ["TIME", "%ds" % int(r.get("duration", 0)), UI.C_BLUE]]:
		grid.add_child(UI.label(pair[0], 18, UI.C_MUTED))
		var v := UI.title(pair[1], 24, pair[2], UI.C_CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
		grid.add_child(v)
	stats.add_child(table)

	if r.get("new_best", false):
		var nb := UI.ribbon("NEW BEST!", UI.C_ORANGE, 20)
		nb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		body.add_child(nb)
		FX.pulse(nb, 1.06, 0.9)
	if r.get("next_unlocked", false):
		body.add_child(UI.label("Next level unlocked!", 20, UI.C_GOOD, HORIZONTAL_ALIGNMENT_CENTER))
	var du := str(r.get("difficulty_unlocked", ""))
	if du != "":
		body.add_child(UI.label("%s mode unlocked for this level!" % Game.diff_of(du)["label"], 19, UI.color_named(str(Game.diff_of(du)["color"])), HORIZONTAL_ALIGNMENT_CENTER))
	if not passed:
		body.add_child(UI.label("You need at least 40% to clear the level. Review the tips and try again!", 18, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	for a: String in r.get("achievements", []):
		var ar := UI.hbox(8)
		ar.alignment = BoxContainer.ALIGNMENT_CENTER
		ar.add_child(Icon.new("trophy", UI.C_STAR, 26))
		ar.add_child(UI.label("Achievement unlocked: %s" % a, 19, UI.C_BLUE))
		body.add_child(ar)

	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	var next_id := Database.get_next_level_id(level_id)
	if passed and next_id != -1 and Database.is_level_unlocked(next_id):
		var nb2 := UI.button("NEXT LEVEL", UI.C_PRIMARY, Vector2(180, 54), 20)
		nb2.name = "Next"
		nb2.pressed.connect(func() -> void:
			Game.current_level_id = next_id
			Game.goto("difficulty_select"))
		row.add_child(nb2)
	var retry := UI.button("RETRY", UI.C_ORANGE, Vector2(130, 54), 20)
	retry.pressed.connect(func() -> void: Game.goto("scenario"))
	row.add_child(retry)
	var tips := UI.button("TIPS", UI.C_BLUE, Vector2(110, 54), 20)
	tips.pressed.connect(func() -> void:
		Game.tips_level_id = level_id
		Game.goto("tips"))
	row.add_child(tips)
	var menu := UI.button("BACK TO MENU", UI.C_BLUE.darkened(0.2), Vector2(190, 54), 20)
	menu.pressed.connect(func() -> void: Game.goto("main_menu"))
	row.add_child(menu)

	FX.pop_in(card, 0.0, 0.75)
	sr.animate_in(0.35)
	FX.count_up(score_lbl, int(r.get("score", 0)), 1.0)
	if passed:
		FX.confetti(self, get_viewport_rect().size.x)
		Game.sfx("win")


func on_back() -> void:
	Game.goto("level_select")
