extends Control
## Storyboard 03 — Select difficulty: Easy / Normal / Hard.
## Normal unlocks after Easy is cleared on this level; Hard after Normal.


func _ready() -> void:
	var lv := Database.get_level(Game.current_level_id)
	var body := UI.screen(self, "%s - Select Difficulty" % lv.get("title", ""), on_back, "clinic")
	var row := UI.hbox(26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var i := 0
	for d: String in Game.DIFFICULTY_ORDER:
		var card := _card(d)
		row.add_child(card)
		FX.pop_in(card, 0.08 * i, 0.85)
		i += 1


func _card(d: String) -> Control:
	var cfg: Dictionary = Game.diff_of(d)
	var unlocked := Database.is_difficulty_unlocked(Game.current_level_id, d)
	var color := UI.color_named(str(cfg["color"])) if unlocked else UI.C_LOCK
	var parts := UI.card(str(cfg["label"]).to_upper(), color, 330)
	var card: PanelContainer = parts[0]
	card.name = str(cfg["label"])
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var body: VBoxContainer = parts[1]
	var fc := CenterContainer.new()
	var face := PatientFace.new(str(cfg["face"]) if unlocked else "neutral", false)
	face.custom_minimum_size = Vector2(100, 100)
	face.idle = unlocked
	fc.add_child(face)
	body.add_child(fc)
	for bullet: String in cfg["bullets"]:
		var r := UI.hbox(8)
		r.add_child(Icon.new("check", color, 20))
		r.add_child(UI.label(bullet, 20))
		body.add_child(r)
	var r2 := UI.hbox(8)
	r2.add_child(Icon.new("heart", UI.C_RED, 20))
	r2.add_child(UI.label("3 strikes = stage failed", 18, UI.C_MUTED))
	body.add_child(r2)
	var prog := Database.get_progress(Game.current_level_id, d)
	var stars := StarRow.new(int(prog["best_stars"]), 18.0)
	stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(stars)
	body.add_child(UI.label("Best score: %d" % int(prog["best_score"]), 17, UI.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var prev := ""
	var idx := Game.DIFFICULTY_ORDER.find(d)
	if idx > 0:
		prev = str(Game.diff_of(Game.DIFFICULTY_ORDER[idx - 1])["label"])
	var b := UI.button("START" if unlocked else "Clear %s first" % prev, color, Vector2(0, 56), 22)
	b.name = "Start"
	b.disabled = not unlocked
	b.pressed.connect(func() -> void:
		Game.current_difficulty = d
		Game.goto("scenario"))
	body.add_child(b)
	return card


func on_back() -> void:
	Game.goto("level_select")
