class_name ToggleSwitch
extends Control
## Pill ON/OFF switch like storyboard frame 12 (animated knob).

signal toggled(on: bool)

var on: bool = false
var _k: float = 0.0   # knob position 0..1


func _init(initial: bool = false) -> void:
	on = initial
	_k = 1.0 if on else 0.0
	custom_minimum_size = Vector2(96, 44)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE


func set_on(v: bool, emit: bool = true) -> void:
	if v == on:
		return
	on = v
	if is_inside_tree():
		var tw := create_tween()
		tw.tween_method(func(x: float) -> void:
			_k = x
			queue_redraw(), _k, 1.0 if on else 0.0, 0.15).set_trans(Tween.TRANS_QUAD)
	else:
		_k = 1.0 if on else 0.0
	queue_redraw()
	if emit:
		toggled.emit(on)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		if Rect2(Vector2.ZERO, size).has_point(ev.position):
			Game.sfx("tap")
			set_on(not on)
			accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var col := UI.C_LOCK.lerp(UI.C_GOOD, _k)
	draw_style_box(UI.style(col, int(size.y / 2.0), col.darkened(0.3), 2, 0), r)
	var font := UI.font_bold()
	var txt := "ON" if on else "OFF"
	var tx := 12.0 if on else size.x - 12.0 - font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(tx, size.y / 2.0 + 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	var kr := size.y / 2.0 - 4.0
	var kx := lerpf(kr + 4.0, size.x - kr - 4.0, _k)
	draw_circle(Vector2(kx, size.y / 2.0 + 1), kr, Color(0, 0, 0, 0.2))
	draw_circle(Vector2(kx, size.y / 2.0), kr, Color.WHITE)
