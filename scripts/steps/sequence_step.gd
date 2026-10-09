class_name SequenceStep
extends StepBase
## Tap actions in the correct order (check safety -> call 911 -> ...).
## params:
##   order: [String]                    labels in the correct order
##   distractors: [{label, effect}]   wrong actions mixed in (tapping one = strike)
##   prompt: String

var _next: int = 0
var _buttons: Array[Button] = []


func _build() -> void:
	var c := CenterContainer.new()
	add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parts := UI.card(str(p("prompt", "Tap the actions in the correct order.")).to_upper(), UI.C_PRIMARY_DARK, 940)
	c.add_child(parts[0])
	var body: VBoxContainer = parts[1]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	body.add_child(grid)
	var entries: Array = []
	var order: Array = p("order", [])
	for i: int in order.size():
		entries.append({"label": order[i], "index": i})
	for d: Dictionary in p("distractors", []):
		entries.append({"label": d["label"], "index": -1, "effect": d.get("effect", d.get("feedback", ""))})
	entries.shuffle()
	for e: Dictionary in entries:
		var b := UI.choice_button("-", str(e["label"]))
		b.text = str(e["label"])
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(440, 62)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("entry", e)
		b.pressed.connect(_on_pressed.bind(b))
		grid.add_child(b)
		_buttons.append(b)


func _on_pressed(b: Button) -> void:
	if done:
		return
	var e: Dictionary = b.get_meta("entry")
	var idx := int(e["index"])
	if idx == _next:
		b.disabled = true
		b.text = "%d. %s" % [idx + 1, e["label"]]
		UI.set_choice_state(b, "correct")
		_next += 1
		var total: int = p("order", []).size()
		progress_changed.emit(float(_next) / total)
		if _next >= total:
			complete()
	elif idx == -1:
		b.disabled = true
		UI.set_choice_state(b, "wrong")
		var eff := str(e.get("effect", ""))
		fail(eff if eff != "" else "That action is not part of correct first aid here.", true, str(e["label"]))
	else:
		fail("Not yet - \"%s\" comes later. What should happen first?" % e["label"], false)


## Test hook: press the correct buttons in order.
func debug_solve() -> void:
	for i: int in p("order", []).size():
		for b: Button in _buttons:
			if int(b.get_meta("entry")["index"]) == i:
				_on_pressed(b)
