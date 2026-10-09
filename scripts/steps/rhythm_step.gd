class_name RhythmStep
extends StepBase
## Rhythm tapping (chest compressions at 100–120 per minute).
## params:
##   body_label, target_label
##   bpm_min, bpm_max: float
##   count: int               compressions in one cycle
##   pass_ratio: float        fraction of taps that must be in-rhythm (minus difficulty rhythm_slack)

var _times: Array[float] = []
var _good: int = 0
var _taps: int = 0
var _last_bpm: float = 0.0
var _pulse: float = 0.0
var _guide_t: float = 0.0
var _feedback: String = ""
var _clock: float = 0.0


func _center() -> Vector2:
	return size * Vector2(0.5, 0.56)


func _radius() -> float:
	return min(size.x, size.y) * 0.18


func _gui_input(ev: InputEvent) -> void:
	if done:
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.position.distance_to(_center()) <= _radius() * 1.4:
			tap(_clock)
		else:
			info.emit("Push on the center of the chest.")


## Registers a compression at time t (seconds). Public so tests can drive it.
func tap(t: float) -> void:
	if done:
		return
	_pulse = 1.0
	_taps += 1
	Game.sfx("compress")
	if _times.size() > 0:
		var dt := t - _times[_times.size() - 1]
		if dt > 2.5:
			# Long pause: compressions were interrupted, start the cycle again.
			fail("Don't stop! Pauses in compressions stop blood flow. Start the cycle again.", false)
			_reset()
			_times.append(t)
			_taps = 1
			return
		_last_bpm = 60.0 / max(0.01, dt)
		if _last_bpm < float(p("bpm_min", 100)):
			_feedback = "Faster!"
		elif _last_bpm > float(p("bpm_max", 120)):
			_feedback = "Slower!"
		else:
			_feedback = "Good rhythm"
			_good += 1
	_times.append(t)
	var need := int(p("count", 30))
	progress_changed.emit(float(_taps) / need)
	if _taps >= need:
		var ratio: float = float(_good) / float(maxi(1, need - 1))
		var pass_ratio := float(p("pass_ratio", 0.7)) - mod("rhythm_slack", 0.0)
		if ratio >= pass_ratio:
			complete()
		else:
			fail("Only %d%% of compressions were 100-120 per minute. Try the cycle again." % int(ratio * 100), false)
			_reset()
	queue_redraw()


## A pause/app switch is not the player's fault: restart timing silently.
func cancel_input() -> void:
	if _times.size() > 0:
		_times.clear()
		_times.append(_clock)


func _reset() -> void:
	_times.clear()
	_good = 0
	_taps = 0
	_feedback = ""
	progress_changed.emit(0.0)


func _process(delta: float) -> void:
	_clock += delta
	_pulse = max(0.0, _pulse - delta * 5.0)
	_guide_t += delta
	queue_redraw()


func _draw() -> void:
	draw_body_part(Rect2(size * Vector2(0.04, 0.04), size * Vector2(0.92, 0.92)), str(p("body_label", "Chest")))
	var c := _center()
	var r := _radius() * (1.0 - 0.12 * _pulse)
	draw_circle(c, r, Color(UI.C_RED, 0.25 + 0.4 * _pulse))
	draw_arc(c, r, 0, TAU, 64, UI.C_RED, 4.0, true)
	draw_text_centered(str(p("target_label", "Center of chest")), c, 20)
	if hints_enabled:
		# Metronome guide at 110 bpm
		var beat := fmod(_guide_t, 60.0 / 110.0) / (60.0 / 110.0)
		draw_arc(c, _radius() * 1.35, 0, TAU, 64, Color(UI.C_BLUE, 1.0 - beat), 6.0, true)
	draw_text_centered("Compressions %d / %d" % [_taps, int(p("count", 30))], size * Vector2(0.5, 0.18), 26)
	var bpm_txt := "--" if _last_bpm <= 0.0 else str(int(_last_bpm))
	draw_text_centered("Rate: %s per min   %s" % [bpm_txt, _feedback], size * Vector2(0.5, 0.88), 22, UI.C_PRIMARY_DARK)
