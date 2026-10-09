extends Control
## 3 strikes -> STAGE FAILED. Turns the failure into learning: shows every wrong
## procedure, its effect, and the correct procedure.


func _ready() -> void:
	var r: Dictionary = Game.last_result
	var lv := Database.get_level(int(r.get("level_id", Game.current_level_id)))
	UI.background(self, "forest")
	var c := UI.center_in(self)
	var parts := UI.card("STAGE FAILED", UI.C_RED, 860)
	var card: PanelContainer = parts[0]
	c.add_child(card)
	var body: VBoxContainer = parts[1]
	var top := UI.hbox(24)
	body.add_child(top)
	var face := PatientFace.new("sad", false)
	face.custom_minimum_size = Vector2(130, 130)
	top.add_child(face)
	var col := UI.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(col)
	col.add_child(UI.label("%s - %s" % [lv.get("title", ""), Game.diff_of(str(r.get("difficulty", "easy")))["label"]], 20, UI.C_MUTED))
	col.add_child(UI.label("The patient needed the right procedure. You made %d wrong choices." % int(r.get("strikes", 3)), 22, UI.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
	var meter := StrikeMeter.new(34.0)
	meter.set_strikes(int(r.get("strikes", 3)), false)
	col.add_child(meter)

	body.add_child(UI.ribbon("WHAT WENT WRONG", UI.C_PRIMARY_DARK, 18))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 230)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var lst := UI.vbox(10)
	lst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lst)
	var n := 0
	for m: Dictionary in r.get("mistakes", []):
		n += 1
		var item := UI.vbox(2)
		item.add_child(UI.label("%d. %s - %s" % [n, m.get("scene", ""), m.get("chosen", "")], 18, UI.C_RED, HORIZONTAL_ALIGNMENT_LEFT, true))
		item.add_child(UI.label(str(m.get("effect", "")), 17, UI.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
		if str(m.get("correct_procedure", "")) != "":
			item.add_child(UI.label("Correct: %s" % m["correct_procedure"], 17, UI.C_GOOD.darkened(0.2), HORIZONTAL_ALIGNMENT_LEFT, true))
		lst.add_child(item)
		FX.pop_in(item, 0.25 + n * 0.12, 0.95)

	var row := UI.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	var retry := UI.button("RETRY", UI.C_ORANGE, Vector2(180, 56), 22)
	retry.name = "Retry"
	retry.pressed.connect(func() -> void: Game.goto("scenario"))
	row.add_child(retry)
	var tips := UI.button("VIEW TIPS", UI.C_BLUE, Vector2(180, 56), 22)
	tips.pressed.connect(func() -> void:
		Game.tips_level_id = int(r.get("level_id", 1))
		Game.goto("tips"))
	row.add_child(tips)
	var levels := UI.button("LEVELS", UI.C_PRIMARY_DARK, Vector2(160, 56), 22)
	levels.pressed.connect(on_back)
	row.add_child(levels)
	FX.pop_in(card, 0.0, 0.75)
	FX.burst(self, get_viewport_rect().size / 2.0 + Vector2(0, -240), UI.C_RED, 30, 260.0)
	Game.sfx("fail")
	Game.vibrate(250)


func on_back() -> void:
	Game.goto("level_select")
