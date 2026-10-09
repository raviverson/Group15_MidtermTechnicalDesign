class_name WrapStep
extends StepBase
## Circular "wrap the bandage" gesture around a limb.
## params:
##   body_label, limb_label
##   turns: float      full circles required
##   reverse_feedback: String

var _angle: float = 0.0
var _last_angle: float = NAN
var _back: float = 0.0
var _dragging: bool = false


func _center() -> Vector2:
	return size * Vector2(0.5, 0.55)


func _r_in() -> float:
	return min(size.x, size.y) * 0.12


func _r_out() -> float:
	return min(size.x, size.y) * 0.42


func _gui_input(ev: InputEvent) -> void:
	if done:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_dragging = ev.pressed
		_last_angle = NAN
	elif ev is InputEventMouseMotion and _dragging:
		move_to(ev.position)


func cancel_input() -> void:
	_dragging = false
	_last_angle = NAN


## Feeds a pointer position. Public so tests can drive a circle.
func move_to(pos: Vector2) -> void:
	var off := pos - _center()
	var dist := off.length()
	if dist < _r_in() or dist > _r_out():
		var was_inside := not is_nan(_last_angle)
		_last_angle = NAN
		if hints_enabled and was_inside:
			info.emit("Circle around the %s, not on top of it." % str(p("limb_label", "limb")))
		return
	var a := off.angle()
	if not is_nan(_last_angle):
		var da := wrapf(a - _last_angle, -PI, PI)
		if _angle != 0.0 and sign(da) != sign(_angle) and abs(da) > 0.01:
			_back += abs(da)
			if _back > PI * 0.6:
				_back = 0.0
				fail(str(p("reverse_feedback", "Keep wrapping in the same direction, overlapping each layer.")), false)
		else:
			_back = max(0.0, _back - abs(da))
			_angle += da
	_last_angle = a
	var need := TAU * float(p("turns", 3))
	progress_changed.emit(clampf(abs(_angle) / need, 0.0, 1.0))
	queue_redraw()
	if abs(_angle) >= need:
		complete()


func _draw() -> void:
	draw_body_part(Rect2(size * Vector2(0.04, 0.04), size * Vector2(0.92, 0.92)), str(p("body_label", "Patient")))
	var c := _center()
	draw_circle(c, _r_in() * 1.6, UI.C_SKIN_DARK)
	draw_text_centered(str(p("limb_label", "Limb")), c, 20, Color.WHITE)
	draw_arc(c, (_r_in() * 1.6 + _r_out()) / 2.0, 0, TAU, 64, Color(UI.C_BLUE, 0.25), (_r_out() - _r_in() * 1.6), true)
	var turns_done: float = absf(_angle) / TAU
	var layers := int(ceil(turns_done))
	for i: int in layers:
		var frac: float = min(1.0, turns_done - i)
		draw_arc(c, _r_in() * 1.6 + 8 + i * 10, 0, TAU * frac, 64, Color("#f4f4f4"), 10.0, true)
	if hints_enabled and _angle == 0.0:
		draw_arc(c, _r_out() * 0.85, -PI / 2, PI, 48, Color(UI.C_BLUE, 0.8), 6.0, true)
		draw_arrow(c + Vector2(-_r_out() * 0.85, -20), c + Vector2(-_r_out() * 0.85, 10), Color(UI.C_BLUE, 0.8), 6.0)
	draw_text_centered("Wraps %.1f / %d" % [turns_done, int(p("turns", 3))], Vector2(size.x * 0.2, size.y * 0.2), 24)
