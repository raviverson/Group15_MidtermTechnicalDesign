class_name HoldStep
extends StepBase
## Press-and-hold mechanic (apply pressure, pinch nose, keep under cool water...).
## Letting go early is a mistake and resets progress.
## params:
##   body_label, target_label
##   seconds: float        real seconds the player must hold
##   sim_minutes: float    what that represents in real life (shown on screen)
##   release_feedback: String

var _holding: bool = false
var _progress: float = 0.0
var _center := Vector2.ZERO
var _radius: float = 90.0


func _draw() -> void:
	draw_body_part(Rect2(size * Vector2(0.04, 0.04), size * Vector2(0.92, 0.92)), str(p("body_label", "Patient")))
	_center = size * Vector2(0.5, 0.55)
	_radius = min(size.x, size.y) * 0.2
	var col := UI.C_GOOD if _holding else UI.C_BLUE
	draw_circle(_center, _radius, Color(col, 0.25))
	draw_arc(_center, _radius, 0, TAU, 64, col, 4.0, true)
	if _progress > 0.0:
		draw_arc(_center, _radius + 14, -PI / 2.0, -PI / 2.0 + TAU * _progress, 64, UI.C_GOOD, 12.0, true)
	draw_text_centered(str(p("target_label", "Press here")), _center + Vector2(0, -10), 22, UI.C_TEXT)
	var sim := float(p("sim_minutes", 0))
	var sub := "HOLD" if not _holding else "Holding..."
	if sim > 0.0:
		sub = "%d / %d min" % [int(round(sim * _progress)), int(sim)]
	draw_text_centered(sub, _center + Vector2(0, 22), 20, UI.C_MUTED)


func _gui_input(ev: InputEvent) -> void:
	if done:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed and ev.position.distance_to(_center) <= _radius * 1.15:
			_holding = true
		elif not ev.pressed and _holding:
			_release()
	elif ev is InputEventMouseMotion and _holding:
		if ev.position.distance_to(_center) > _radius * 1.5:
			_release()
	queue_redraw()


func cancel_input() -> void:
	_holding = false
	queue_redraw()


func _release() -> void:
	_holding = false
	if _progress > 0.08 and _progress < 1.0:
		fail(str(p("release_feedback", "Don't let go early! Keep steady, continuous pressure.")), false)
		_progress = 0.0
		progress_changed.emit(0.0)


func _process(delta: float) -> void:
	if done or not _holding:
		return
	_progress = minf(1.0, _progress + delta / maxf(0.3, float(p("seconds", 6.0)) * mod("hold_mult", 1.0)))
	progress_changed.emit(_progress)
	queue_redraw()
	if _progress >= 1.0:
		_holding = false
		complete()


## Test hook so automated runs can simulate a full hold.
func debug_force_hold(seconds: float) -> void:
	_holding = true
	_process(seconds)
