extends Control
## Storyboard 01 — Main menu (clinic interior, logo, stacked colored buttons).


func _ready() -> void:
	UI.background(self, "clinic")
	var c := UI.center_in(self)
	var row := UI.hbox(60)
	c.add_child(row)

	var col := UI.vbox(12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var logo := UI.hbox(10)
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	logo.add_child(UI.title("CLINIC", 72, Color.WHITE, UI.C_PRIMARY_DARK))
	logo.add_child(UI.title("RUSH", 72, Color("#ffe08a"), UI.C_PRIMARY_DARK))
	logo.add_child(Icon.new("medic", Color.WHITE, 64))
	col.add_child(logo)
	var tag := UI.ribbon("LEARN. ACT. SAVE LIVES.", UI.C_RED, 20)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(tag)
	var entries := [
		["PLAY", UI.C_PRIMARY, func() -> void: Game.goto("level_select")],
		["SETTINGS", UI.C_BLUE, func() -> void: Game.goto("settings")],
		["ACHIEVEMENTS", UI.C_ORANGE, func() -> void: Game.goto("achievements")],
		["TIPS / LEARN MORE", UI.C_PRIMARY_DARK, func() -> void:
			Game.tips_level_id = -1
			Game.goto("tips")],
		["QUIT", UI.C_RED, func() -> void: get_tree().quit()],
	]
	var i := 0
	for e: Array in entries:
		var b := UI.button(e[0], e[1], Vector2(330, 56), 24)
		b.name = str(e[0]).replace(" / ", "_").replace(" ", "_")
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(e[2])
		col.add_child(b)
		FX.pop_in(b, 0.1 + i * 0.07, 0.85)
		i += 1
	var note := UI.label("For learning only - not a substitute for certified first-aid training.\nIn an emergency, call 911.", 15, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(note)
	if not Database.is_ok():
		col.add_child(UI.label("Save data problem: %s" % Database.last_error, 18, UI.C_RED, HORIZONTAL_ALIGNMENT_CENTER, true))

	var kid := PatientFace.new("happy", true)
	kid.custom_minimum_size = Vector2(240, 320)
	kid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(kid)
	FX.pop_in(logo, 0.0, 0.6)

	# bottom-right quick icons (storyboard: trophy + gear)
	var quick := UI.hbox(10)
	add_child(quick)
	quick.anchor_left = 1.0
	quick.anchor_top = 1.0
	quick.anchor_right = 1.0
	quick.anchor_bottom = 1.0
	quick.offset_left = -136
	quick.offset_top = -74
	quick.offset_right = -18
	quick.offset_bottom = -16
	var tro := UI.icon_button("trophy", UI.C_ORANGE, 54)
	tro.pressed.connect(func() -> void: Game.goto("achievements"))
	quick.add_child(tro)
	var gear := UI.icon_button("gear", UI.C_BLUE, 54)
	gear.pressed.connect(func() -> void: Game.goto("settings"))
	quick.add_child(gear)


## Android back on the menu exits (platform convention). On PC, Esc does nothing here.
func on_back() -> void:
	if OS.has_feature("mobile"):
		get_tree().quit()
