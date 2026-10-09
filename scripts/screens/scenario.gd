extends Control
## Storyboard 04-09 — one stage, driven by StageRunner (pure logic):
##   SCENARIO intro -> [scene: choose A/B -> EFFECT card -> perform procedure -> EFFECT card] x N
##   -> Level complete   |   3 strikes -> Stage Failed
## This screen only renders the runner's state and forwards player input to it.

const STEP_TYPES := {
	"drag_drop": preload("res://scripts/steps/drag_drop_step.gd"),
	"wipe": preload("res://scripts/steps/wipe_step.gd"),
	"hold": preload("res://scripts/steps/hold_step.gd"),
	"swipe": preload("res://scripts/steps/swipe_step.gd"),
	"rhythm": preload("res://scripts/steps/rhythm_step.gd"),
	"wrap": preload("res://scripts/steps/wrap_step.gd"),
	"sequence": preload("res://scripts/steps/sequence_step.gd"),
}
const RESULT_STATES := [StageRunner.State.DECISION_RESULT, StageRunner.State.ACTION_RESULT,
	StageRunner.State.STRIKE_RESULT, StageRunner.State.TIMEOUT_RESULT]

var level: Dictionary
var runner: StageRunner
var diff: Dictionary
var current_step: StepBase
var started: bool = false

var _step_key: String = ""
var _time_left: float = 0.0
var _timer_on: bool = false
var _paused: bool = false
var _paused_total: float = 0.0
var _pause_started: float = 0.0
var _start_time: float = 0.0
var _choice_buttons: Array[Button] = []
var _choice_order: Array = []          # display slot -> original choice index
var _scene_mistake: bool = false       # for "hints after a mistake" (Normal)
var _timer_warned: bool = false
var _pulse_tw: Tween

# UI
var _content: Control
var _title_ribbon: PanelContainer
var _hearts: StrikeMeter
var _score_lbl: Label
var _timer_lbl: Label
var _timer_pill: PanelContainer
var _progress: ProgressBar
var _bar: PanelContainer
var _bar_lbl: Label
var _tracker: HBoxContainer
var _overlay: Control
var _overlay_kind: String = ""        # "", "result", "tips", "pause"
var _face: PatientFace


func _ready() -> void:
	diff = Game.diff()
	level = Database.get_level(Game.current_level_id)
	if level.is_empty():
		push_error("Scenario: level %d not found" % Game.current_level_id)
		Game.goto("level_select")
		return
	runner = StageRunner.new(Database.get_scenes(Game.current_level_id), int(diff["penalty"]))
	_start_time = Time.get_ticks_msec() / 1000.0
	_build_ui()
	_show_intro()


# ================================================================== UI scaffold

func _build_ui() -> void:
	UI.background(self, "park")
	var root := UI.vbox(8)
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 14
	root.offset_right = -14
	root.offset_top = 10
	root.offset_bottom = -10

	var top := UI.hbox(10)
	root.add_child(top)
	var pause := UI.icon_button("pause", UI.C_PRIMARY_DARK, 50)
	pause.pressed.connect(_show_pause)
	top.add_child(pause)
	_title_ribbon = UI.ribbon("", UI.C_PRIMARY_DARK, 20)
	_title_ribbon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title_ribbon)
	var hp := _pill(UI.C_PRIMARY_DARK)
	_hearts = StrikeMeter.new(30.0)
	hp.add_child(_hearts)
	top.add_child(hp)
	var sp := _pill(UI.C_PRIMARY_DARK)
	var srow := UI.hbox(6)
	srow.add_child(Icon.new("star", Color.WHITE, 26))
	_score_lbl = UI.title("0", 22, Color.WHITE, UI.C_PRIMARY_DARK.darkened(0.4), HORIZONTAL_ALIGNMENT_LEFT)
	_score_lbl.custom_minimum_size = Vector2(46, 0)
	srow.add_child(_score_lbl)
	sp.add_child(srow)
	top.add_child(sp)
	_timer_pill = _pill(UI.C_PRIMARY_DARK)
	var trow := UI.hbox(6)
	trow.add_child(Icon.new("clock", Color.WHITE, 26))
	_timer_lbl = UI.title("--:--", 22, Color.WHITE, UI.C_PRIMARY_DARK.darkened(0.4), HORIZONTAL_ALIGNMENT_LEFT)
	_timer_lbl.custom_minimum_size = Vector2(64, 0)
	trow.add_child(_timer_lbl)
	_timer_pill.add_child(trow)
	top.add_child(_timer_pill)

	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(0, 10)
	_progress.show_percentage = false
	_progress.max_value = 1.0
	_progress.step = 0.001
	_progress.add_theme_stylebox_override("fill", UI.style(UI.C_STAR, 5, Color.TRANSPARENT, 0, 0))
	_progress.add_theme_stylebox_override("background", UI.style(Color(0, 0, 0, 0.18), 5, Color.TRANSPARENT, 0, 0))
	root.add_child(_progress)

	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(_content)

	_bar = UI.panel(UI.C_CREAM, 14, 10)
	_bar.custom_minimum_size = Vector2(0, 64)
	root.add_child(_bar)
	var brow := UI.hbox(10)
	_bar.add_child(brow)
	brow.add_child(Icon.new("info", UI.C_BLUE, 30))
	_bar_lbl = UI.label("", 20, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	_bar_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brow.add_child(_bar_lbl)

	_tracker = UI.hbox(8)
	_tracker.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_tracker)
	_refresh_tracker()


func _pill(color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UI.style(color, 22, color.darkened(0.3), 2, 8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	p.add_theme_stylebox_override("panel", sb)
	return p


func _set_title(text: String) -> void:
	var l: Label = _title_ribbon.get_node("Text")
	l.text = text.to_upper()


func _set_bar(text: String, color: Color = UI.C_CREAM) -> void:
	_bar_lbl.text = text
	var sb := UI.style(color, 14, color.darkened(0.25) if color != UI.C_CREAM else UI.C_BROWN, 3, 10)
	_bar.add_theme_stylebox_override("panel", sb)
	_bar_lbl.add_theme_color_override("font_color", UI.C_TEXT if color == UI.C_CREAM else Color.WHITE)


func _clear_content() -> void:
	for c: Node in _content.get_children():
		c.queue_free()
	current_step = null
	_step_key = ""
	_choice_buttons.clear()
	_face = null


func _refresh_tracker() -> void:
	for c: Node in _tracker.get_children():
		c.queue_free()
	for i: int in runner.scenes.size():
		var done := i < runner.scene_idx or runner.state == StageRunner.State.COMPLETE
		var cur := i == runner.scene_idx and started and not runner.is_over()
		var col := UI.C_GOOD if done else (UI.C_ORANGE if cur else Color(0.35, 0.35, 0.3, 0.75))
		var pill := _pill(col)
		var row := UI.hbox(6)
		if done:
			row.add_child(Icon.new("check", Color.WHITE, 18))
		else:
			row.add_child(UI.title(str(i + 1), 16, Color.WHITE, col.darkened(0.4)))
		row.add_child(UI.title(str(runner.scenes[i].get("title", "")), 16, Color.WHITE, col.darkened(0.4)))
		pill.add_child(row)
		_tracker.add_child(pill)


func _refresh_score(delta_points: int = 0) -> void:
	_score_lbl.text = str(maxi(0, runner.score))
	if delta_points != 0 and _score_lbl.is_inside_tree():
		var pos := _score_lbl.get_global_rect().get_center() - global_position + Vector2(0, 70)
		FX.float_text(self, pos, ("+%d" if delta_points > 0 else "%d") % delta_points, UI.C_STAR if delta_points > 0 else UI.C_RED, 26)


# ================================================================== timer

func _start_timer(seconds: float) -> void:
	_time_left = maxf(1.0, seconds * float(diff["time_mult"]))
	_timer_on = true
	_timer_warned = false
	_stop_pulse()
	_timer_lbl.add_theme_color_override("font_color", Color.WHITE)
	_update_timer_label()


func _resume_timer() -> void:
	if _time_left > 0.0:
		_timer_on = true


func _stop_pulse() -> void:
	if _pulse_tw != null and _pulse_tw.is_valid():
		_pulse_tw.kill()
	_pulse_tw = null
	if _timer_pill != null:
		_timer_pill.scale = Vector2.ONE


func _process(delta: float) -> void:
	if not _timer_on or _paused or _overlay != null:
		return
	_time_left -= delta
	_update_timer_label()
	if _time_left <= 5.0 and not _timer_warned:
		_timer_warned = true
		_timer_lbl.add_theme_color_override("font_color", Color("#ffd166"))
		_pulse_tw = FX.pulse(_timer_pill, 1.1, 0.5)
	if _time_left <= 0.0:
		_timer_on = false
		_stop_pulse()
		_on_timeout()


func _update_timer_label() -> void:
	var t: int = maxi(0, ceili(_time_left))
	_timer_lbl.text = "%d:%02d" % [floori(t / 60.0), t % 60]


func time_left() -> float:
	return _time_left


func timer_running() -> bool:
	return _timer_on and not _paused and _overlay == null


# ================================================================== flow

func _show_intro() -> void:
	_clear_content()
	_set_title("Scenario: %s" % level.get("title", ""))
	_timer_lbl.text = "--:--"
	var parts := _scene_layout("worried", "SCENARIO: %s" % str(level.get("title", "")).to_upper())
	var body: VBoxContainer = parts[1]
	body.add_child(UI.label(str(level.get("scenario", "")), 23, UI.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
	body.add_child(UI.label("What should you do?", 24, UI.C_RED))
	body.add_child(UI.label("%s mode - you have %d hearts. Each wrong procedure breaks one." % [diff["label"], StageRunner.MAX_STRIKES], 16, UI.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	var b := UI.button("START", UI.C_PRIMARY, Vector2(220, 58))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(start)
	body.add_child(b)
	_set_bar("Read the situation carefully, then press START.")


## Leaves the intro. Public for tests.
func start() -> void:
	if started:
		return
	started = true
	_enter_state()


## Shows whatever the runner's current state needs.
func _enter_state() -> void:
	_refresh_tracker()
	_hearts.set_strikes(runner.strikes, false)
	match runner.state:
		StageRunner.State.DECISION:
			_show_decision()
		StageRunner.State.ACTION:
			_show_action()
		StageRunner.State.FAILED, StageRunner.State.COMPLETE:
			_finish()


## Left: patient. Right: cream card. Returns [card, body].
func _scene_layout(mood: String, header: String) -> Array:
	var row := UI.hbox(28)
	_content.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_face = PatientFace.new(mood, true)
	_face.custom_minimum_size = Vector2(230, 300)
	_face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_face)
	var parts := UI.card(header, UI.C_PRIMARY_DARK, 780)
	var card: PanelContainer = parts[0]
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(card)
	FX.pop_in(card, 0.05)
	return parts


func _show_decision() -> void:
	_clear_content()
	_scene_mistake = false
	var sc := runner.current_scene()
	_set_title("Scene %d of %d - %s" % [runner.scene_idx + 1, runner.scenes.size(), sc.get("title", "")])
	_progress.value = float(runner.scene_idx) / float(maxi(1, runner.scenes.size()))
	var parts := _scene_layout("worried", "SCENARIO: %s" % str(level.get("title", "")).to_upper())
	var body: VBoxContainer = parts[1]
	if str(sc.get("situation", "")) != "":
		body.add_child(UI.label(str(sc["situation"]), 21, UI.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
	var prompt := UI.label(str(sc.get("prompt", "What do you do?")), 25, UI.C_PRIMARY_DARK, HORIZONTAL_ALIGNMENT_LEFT, true)
	prompt.add_theme_font_override("font", UI.font_bold())
	body.add_child(prompt)
	var choices: Array = sc.get("choices", [])
	_choice_order = range(choices.size())
	_choice_order.shuffle()   # correct answer is never in a fixed slot
	var letters := "ABCDEFGH"
	for i: int in choices.size():
		var ch: Dictionary = choices[_choice_order[i]]
		var b := UI.choice_button(letters[i], str(ch.get("label", "")))
		b.pressed.connect(choose.bind(i))
		body.add_child(b)
		_choice_buttons.append(b)
		FX.pop_in(b, 0.15 + i * 0.07, 0.9)
	_set_bar("Choose the correct procedure.")
	_start_timer(float(sc.get("time_limit", 20)))


## Display slot of the correct choice (for tests).
func current_correct_slot() -> int:
	var choices: Array = runner.current_scene().get("choices", [])
	for slot: int in _choice_order.size():
		if choices[_choice_order[slot]].get("correct", false):
			return slot
	return -1


## Player taps choice in display slot i. Public so tests can drive it.
func choose(i: int) -> void:
	if i < 0 or i >= _choice_order.size() or _paused:
		return
	var right := current_correct_slot()
	var outcome := runner.choose(int(_choice_order[i]))
	if outcome.is_empty():
		return   # not in DECISION state (double tap etc.)
	_timer_on = false
	_stop_pulse()
	for j: int in _choice_buttons.size():
		var b := _choice_buttons[j]
		b.disabled = true
		if j == right:
			UI.set_choice_state(b, "correct")
		elif j == i:
			UI.set_choice_state(b, "wrong")
		else:
			UI.set_choice_state(b, "dim")
	if not outcome["correct"]:
		_scene_mistake = true
		if i < _choice_buttons.size():
			FX.shake(_choice_buttons[i])
	_show_result(outcome, "decision")


func _show_action() -> void:
	var act := runner.current_action()
	var key := "%d:%d" % [runner.scene_idx, runner.action_idx]
	if key == _step_key and current_step != null and is_instance_valid(current_step) and not current_step.done:
		# Same procedure continues after a strike card: keep its progress, resume timer.
		_resume_timer()
		_set_bar(_instruction_text(act), UI.C_CREAM)
		return
	_clear_content()
	_step_key = key
	var acts := runner.current_actions()
	_set_title("Step %d of %d - %s" % [runner.action_idx + 1, acts.size(), act.get("title", "")])
	var script: Variant = STEP_TYPES.get(str(act.get("type", "")))
	if script == null:
		push_error("Unknown step type: %s" % act.get("type", ""))
		# Treat as done so the stage can never get stuck.
		runner.action_done("")
		runner.proceed()
		_enter_state()
		return
	var step: StepBase = script.new()
	step.setup(act.get("params", {}), _hints_on(), Game.current_difficulty, diff)
	_content.add_child(step)
	step.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	step.completed.connect(_on_step_completed)
	step.mistake.connect(_on_step_mistake)
	step.info.connect(func(msg: String) -> void: _set_bar(msg, UI.C_BLUE))
	step.progress_changed.connect(func(v: float) -> void: _progress.value = v)
	current_step = step
	_progress.value = 0.0
	_set_bar(_instruction_text(act))
	FX.pop_in(step, 0.0, 0.95)
	_start_timer(float(act.get("time", 30)))


func _hints_on() -> bool:
	match str(diff["hints"]):
		"always": return true
		"after_mistake": return _scene_mistake
	return false


func _instruction_text(act: Dictionary) -> String:
	var t := str(act.get("instruction", ""))
	if _hints_on() and str(act.get("hint", "")) != "":
		t += "   (Hint: %s)" % act["hint"]
	return t


func _on_step_completed() -> void:
	var act := runner.current_action()
	var outcome := runner.action_done(str(act.get("success", "Well done!")))
	if outcome.is_empty():
		return
	_timer_on = false
	_stop_pulse()
	_show_result(outcome, "action")


func _on_step_mistake(msg: String, strike: bool, chosen: String) -> void:
	if runner.state != StageRunner.State.ACTION:
		return
	if strike:
		var outcome := runner.action_strike(chosen if chosen != "" else "Wrong procedure", msg)
		if outcome.is_empty():
			return
		_timer_on = false
		if current_step != null:
			current_step.cancel_input()
		_after_mistake_hints()
		_show_result(outcome, "action_strike")
	else:
		if runner.action_technique_error():
			_refresh_score(-int(diff["penalty"]))
			_set_bar("%s   (-%d)" % [msg, int(diff["penalty"])], UI.C_RED)
			FX.shake(_bar, 6.0, 0.25)
			_after_mistake_hints()


func _after_mistake_hints() -> void:
	_scene_mistake = true
	if current_step != null and str(diff["hints"]) == "after_mistake":
		current_step.set_hints(true)


func _on_timeout() -> void:
	if current_step != null:
		current_step.stop()
	var outcome := runner.timeout()
	if outcome.is_empty():
		return
	_show_result(outcome, "timeout")


## Leave a consequence card. Public so tests can drive it.
func continue_stage() -> void:
	if not (runner.state in RESULT_STATES) or _paused:
		return
	_hide_overlay()
	runner.proceed()
	_enter_state()


func _finish() -> void:
	_timer_on = false
	_stop_pulse()
	if current_step != null:
		current_step.stop()
	var failed := runner.is_failed()
	var r := {
		"level_id": Game.current_level_id,
		"difficulty": Game.current_difficulty,
		"score": runner.final_score(),
		"max_score": runner.max_score(),
		"stars": runner.stars(),
		"correct": runner.correct,
		"incorrect": runner.incorrect,
		"strikes": runner.strikes,
		"failed": failed,
		"mistakes": runner.mistakes_log.duplicate(true),
		"duration": Time.get_ticks_msec() / 1000.0 - _start_time - _paused_total,
	}
	r.merge(Database.record_attempt(Game.current_level_id, Game.current_difficulty, r))
	Game.last_result = r
	Game.goto("stage_failed" if failed else "level_complete")


# ================================================================== overlays

func _make_overlay(kind: String) -> void:
	_hide_overlay()
	_overlay_kind = kind
	_overlay = Control.new()
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.12, 0.08, 0.55)
	_overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.modulate.a = 0.0
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.15)


func _hide_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_overlay_kind = ""


## Storyboard 09 — the EFFECT of the chosen procedure, shown after every choice.
func _show_result(outcome: Dictionary, source: String) -> void:
	_make_overlay("result")
	var ok: bool = outcome["correct"]
	var is_timeout: bool = outcome.get("timeout", false)
	var head := "WELL DONE!" if ok else ("TIME'S UP!" if is_timeout else "OH NO!")
	var col := UI.C_GOOD if ok else (UI.C_ORANGE if is_timeout else UI.C_RED)
	var c := UI.center_in(_overlay)
	var parts := UI.card(head, col, 720)
	var card: PanelContainer = parts[0]
	card.name = "ResultCard"
	c.add_child(card)
	var body: VBoxContainer = parts[1]
	var row := UI.hbox(22)
	body.add_child(row)
	var face := PatientFace.new("happy", false)
	face.custom_minimum_size = Vector2(150, 150)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(face)
	face.react(str(outcome.get("mood", "happy" if ok else "hurt")))
	var info_col := UI.vbox(8)
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_col)
	var chosen := str(outcome.get("chosen", ""))
	if chosen != "" and not chosen.begins_with("("):
		var what := "You chose:" if source == "decision" else "You did:"
		info_col.add_child(UI.label("%s %s" % [what, chosen], 17, UI.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	var eff := UI.label(str(outcome.get("effect", "")), 23, UI.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	eff.name = "Effect"
	eff.add_theme_font_override("font", UI.font_bold())
	eff.custom_minimum_size = Vector2(480, 0)
	info_col.add_child(eff)
	var meter: StrikeMeter = null
	if not ok:
		var proc := str(outcome.get("correct_procedure", ""))
		if proc != "" and source != "action_strike":
			info_col.add_child(UI.label("Correct procedure: %s" % proc, 19, UI.C_GOOD.darkened(0.2), HORIZONTAL_ALIGNMENT_LEFT, true))
		var srow := UI.hbox(10)
		meter = StrikeMeter.new(26.0)
		srow.add_child(meter)
		meter.set_strikes(int(outcome["strikes"]) - 1, false)
		srow.add_child(UI.label("Strike %d of %d" % [int(outcome["strikes"]), StageRunner.MAX_STRIKES], 19, UI.C_RED))
		info_col.add_child(srow)
	var pts_text := "+%d Points" % StageRunner.POINTS
	if not ok:
		pts_text = ("-%d Points" % int(diff["penalty"])) if source == "action_strike" else "+0 Points"
	body.add_child(UI.label(pts_text, 22, UI.C_PRIMARY_DARK if ok else UI.C_RED, HORIZONTAL_ALIGNMENT_CENTER))
	var btns := UI.hbox(16)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(btns)
	var tips := UI.button("VIEW TIPS", UI.C_BLUE, Vector2(190, 54), 20)
	tips.pressed.connect(_show_tips_overlay)
	btns.add_child(tips)
	var cont_text := "CONTINUE"
	if outcome.get("failed_now", false):
		cont_text = "SEE RESULTS"
	elif not ok and source == "decision" and runner.current_actions().size() > 0:
		cont_text = "DO IT RIGHT"
	elif source == "action_strike":
		cont_text = "TRY AGAIN"
	var cont := UI.button(cont_text, UI.C_PRIMARY if ok or not outcome.get("failed_now", false) else UI.C_RED, Vector2(220, 54), 20)
	cont.name = "Continue"
	cont.pressed.connect(continue_stage)
	btns.add_child(cont)
	FX.pop_in(card, 0.0, 0.7)
	# ---- feedback FX ----
	_hearts.set_strikes(runner.strikes, true)
	if meter != null:
		meter.set_strikes(int(outcome["strikes"]), true)
	_refresh_score(StageRunner.POINTS if ok else (-int(diff["penalty"]) if source == "action_strike" else 0))
	var burst_pos := get_viewport_rect().size / 2.0 + Vector2(0, -150)
	if ok:
		FX.burst(_overlay, burst_pos, UI.C_STAR, 34, 320.0)
		FX.burst(_overlay, burst_pos, UI.C_GOOD, 20, 260.0)
		Game.sfx("correct")
		if _face != null:
			_face.react("happy")
	else:
		FX.burst(_overlay, burst_pos, UI.C_RED, 26, 240.0)
		# wait for the CenterContainer to place the card before shaking it
		var tw := card.create_tween()
		tw.tween_interval(0.12)
		tw.tween_callback(func() -> void: FX.shake(card, 14.0, 0.4))
		Game.sfx("wrong")
		Game.vibrate(150)
		if _face != null:
			_face.react("hurt")
	_set_bar(head, col)


func _show_tips_overlay() -> void:
	if _overlay_kind != "result":
		return
	_make_overlay("tips")
	var c := UI.center_in(_overlay)
	var parts := UI.card("TIP: %s" % str(level.get("title", "")).to_upper(), UI.C_BLUE, 680)
	c.add_child(parts[0])
	var body: VBoxContainer = parts[1]
	var row := UI.hbox(16)
	body.add_child(row)
	var lst := UI.vbox(6)
	lst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lst)
	var i := 0
	for t: String in Database.get_tips(Game.current_level_id):
		i += 1
		var l := UI.label("%d. %s" % [i, t], 18, UI.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
		l.custom_minimum_size = Vector2(500, 0)
		lst.add_child(l)
	row.add_child(Icon.new("kit", Color.WHITE, 90))
	var b := UI.button("GOT IT", UI.C_PRIMARY, Vector2(200, 54), 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(continue_stage)
	body.add_child(b)
	FX.pop_in(parts[0], 0.0, 0.85)


func _show_pause() -> void:
	if _overlay != null or _paused or not started or runner.is_over():
		return
	_paused = true
	_pause_started = Time.get_ticks_msec() / 1000.0
	if current_step != null:
		current_step.cancel_input()
		current_step.process_mode = Node.PROCESS_MODE_DISABLED
	_make_overlay("pause")
	var c := UI.center_in(_overlay)
	var parts := UI.card("PAUSED", UI.C_PRIMARY_DARK, 380)
	c.add_child(parts[0])
	var v: VBoxContainer = parts[1]
	var resume := UI.button("RESUME", UI.C_PRIMARY)
	resume.pressed.connect(resume_game)
	var restart := UI.button("RESTART", UI.C_ORANGE)
	restart.pressed.connect(func() -> void: Game.goto("scenario"))
	var quit := UI.button("QUIT TO LEVELS", UI.C_RED)
	quit.pressed.connect(func() -> void: Game.goto("level_select"))
	for b: Button in [resume, restart, quit]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(b)
	FX.pop_in(parts[0], 0.0, 0.85)


func resume_game() -> void:
	if not _paused:
		return
	_paused = false
	_paused_total += Time.get_ticks_msec() / 1000.0 - _pause_started
	_hide_overlay()
	if current_step != null and is_instance_valid(current_step):
		current_step.process_mode = Node.PROCESS_MODE_INHERIT


func is_paused() -> bool:
	return _paused


func overlay_kind() -> String:
	return _overlay_kind


## Auto-pause when the app goes to background (phone call, home button).
func _notification(what: int) -> void:
	var lost_focus := what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile")
	if what == NOTIFICATION_APPLICATION_PAUSED or lost_focus:
		if is_inside_tree() and _content != null:
			_show_pause()


## Android back / Esc: paused -> resume; tips -> continue; playing -> pause; intro -> back.
func on_back() -> void:
	if _paused:
		resume_game()
	elif _overlay_kind == "tips":
		continue_stage()
	elif _overlay == null:
		if started:
			_show_pause()
		else:
			Game.goto("difficulty_select")
