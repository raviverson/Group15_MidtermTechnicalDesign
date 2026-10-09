extends Control
## Storyboard 11 — Tips / Learn more. Readable any time, even for locked levels
## (learning content should never be gated behind gameplay).

var _list: VBoxContainer
var _ribbon: PanelContainer
var _buttons: Dictionary = {}


func _ready() -> void:
	var body := UI.screen(self, "Tips / Learn More", on_back, "clinic")
	var row := UI.hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var side := UI.vbox(8)
	side.custom_minimum_size = Vector2(250, 0)
	row.add_child(side)
	var parts := UI.card("TIP", UI.C_BLUE)
	var card: PanelContainer = parts[0]
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(card)
	_ribbon = card.get_child(0).get_child(0)
	var cbody: VBoxContainer = parts[1]
	cbody.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inner := UI.hbox(16)
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cbody.add_child(inner)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(scroll)
	_list = UI.vbox(10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var kitc := CenterContainer.new()
	kitc.add_child(Icon.new("kit", Color.WHITE, 130))
	inner.add_child(kitc)
	var levels := Database.get_levels()
	for lv: Dictionary in levels:
		var b := UI.button(str(lv["title"]), UI.C_PRIMARY, Vector2(0, 46), 19)
		b.pressed.connect(_show.bind(lv))
		side.add_child(b)
		_buttons[int(lv["id"])] = b
	var start: Dictionary = levels[0] if levels.size() > 0 else {}
	for lv: Dictionary in levels:
		if int(lv["id"]) == Game.tips_level_id:
			start = lv
	if not start.is_empty():
		_show(start)
	var em := UI.hbox(8)
	em.add_child(Icon.new("medic", Color.WHITE, 26))
	em.add_child(UI.title("Emergency hotline (Philippines): 911", 18, Color.WHITE, UI.C_RED))
	body.add_child(em)


func _show(lv: Dictionary) -> void:
	var l: Label = _ribbon.get_node("Text")
	l.text = "TIP: FOR %s" % str(lv["title"]).to_upper()
	for id: int in _buttons:
		UI.recolor_button(_buttons[id], UI.C_ORANGE if id == int(lv["id"]) else UI.C_PRIMARY)
	for c: Node in _list.get_children():
		c.queue_free()
	var i := 0
	for t: String in Database.get_tips(int(lv["id"])):
		i += 1
		var r := UI.hbox(10)
		var num := UI.ribbon(str(i), UI.C_PRIMARY, 16)
		num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		r.add_child(num)
		var tl := UI.label(t, 20, UI.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(tl)
		_list.add_child(r)
		FX.pop_in(r, 0.03 * i, 0.95)


func on_back() -> void:
	Game.goto("main_menu")
