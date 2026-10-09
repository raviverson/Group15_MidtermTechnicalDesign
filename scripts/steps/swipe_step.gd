class_name SwipeStep
extends StepBase
## Directional swipe mechanic (lean forward, back blows, abdominal thrusts,
## elevate a limb, scrape a stinger...).
## params:
##   body_label, action_label
##   direction: "up" | "down" | "left" | "right" | "horizontal" | "vertical"
##   count: int            number of correct swipes required
##   wrong_feedback: String
##   wrong_strike: bool      true when the wrong direction is a dangerous procedure (e.g. tilting head back)

const MIN_DIST := 70.0

var _start := Vector2.ZERO
var _pressing: bool = false
var _count: int = 0
var _flash: float = 0.0


func _dir_vec() -> Vector2:
	match str(p("direction", "up")):
		"up": return Vector2.UP
		"down": return Vector2.DOWN
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
		"horizontal": return Vector2.RIGHT
		"vertical": return Vector2.DOWN
	return Vector2.UP


func _matches(v: Vector2) -> bool:
	var d := str(p("direction", "up"))
	var horizontal: bool = absf(v.x) > absf(v.y)
	match d:
		"horizontal": return horizontal
		"vertical": return not horizontal
	return v.normalized().dot(_dir_vec()) > 0.75


func _gui_input(ev: InputEvent) -> void:
	if done:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_start = ev.position
			_pressing = true
		elif _pressing:
			_pressing = false
			_judge(ev.position - _start)


func cancel_input() -> void:
	_pressing = false


func _judge(v: Vector2) -> void:
	if v.length() < MIN_DIST:
		info.emit("Swipe further - make a firm, full motion.")
		return
	if _matches(v):
		_count += 1
		_flash = 1.0
		Game.sfx("swipe")
		var need := int(p("count", 1))
		progress_changed.emit(float(_count) / need)
		if _count >= need:
			complete()
	else:
		fail(str(p("wrong_feedback", "Wrong direction. Swipe %s." % str(p("direction", "up")))), bool(p("wrong_strike", false)), "Wrong direction")
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = max(0.0, _flash - delta * 3.0)
		queue_redraw()


func _draw() -> void:
	draw_body_part(Rect2(size * Vector2(0.04, 0.04), size * Vector2(0.92, 0.92)), str(p("body_label", "Patient")))
	var c := size * Vector2(0.5, 0.55)
	var d: Vector2 = _dir_vec() * minf(size.x, size.y) * 0.28
	var col := UI.C_BLUE.lerp(UI.C_GOOD, _flash)
	if hints_enabled or _count == 0:
		var dirn := str(p("direction", "up"))
		if dirn == "horizontal" or dirn == "vertical":
			draw_arrow(c, c + d, Color(col, 0.7))
			draw_arrow(c, c - d, Color(col, 0.7))
		else:
			draw_arrow(c - d, c + d, Color(col, 0.7), 10.0)
	draw_text_centered("%s  %d / %d" % [str(p("action_label", "Swipe")), _count, int(p("count", 1))], size * Vector2(0.5, 0.2), 26, UI.C_TEXT)


## Test hook.
func debug_swipe(v: Vector2) -> void:
	_judge(v)
