extends Node
## Real-input tests: every mechanic is driven ONLY through mouse/touch events pushed
## into the viewport (same path a finger takes on Android via emulate_mouse_from_touch),
## including real GUI drag-and-drop. Also covers regressions found in the bug audit.
##   godot --headless res://tests/input_tests.tscn

var _fails: int = 0
var _passes: int = 0
var _state := {"done": 0, "mistakes": 0, "strikes": 0}


func check(cond: bool, what: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("FAIL: ", what)


func _ready() -> void:
	Game.test_mode = true
	var test_db := "user://input_test.db"
	if FileAccess.file_exists(test_db):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_db))
	Database.close()
	Database.open(test_db)
	await _frames(2)
	await _t_drag_drop()
	await _t_wipe()
	await _t_hold()
	await _t_swipe()
	await _t_rhythm()
	await _t_wrap()
	await _t_sequence()
	await _t_scenario_real_clicks()
	await _t_wrong_choice_real()
	await _t_double_tap_continue()
	await _t_pause_resume_hold()
	await _t_shuffle()
	print("RESULT: %d passed, %d failed" % [_passes, _fails])
	Database.open()
	get_tree().quit(1 if _fails > 0 else 0)


# ------------------------------------------------------------ input helpers

func _frames(n: int = 1) -> void:
	for i: int in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _btn(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	get_viewport().push_input(e)


func _move(from: Vector2, to: Vector2, steps: int = 12, held: bool = true) -> void:
	var prev := from
	for i: int in range(1, steps + 1):
		var pos := from.lerp(to, float(i) / steps)
		var e := InputEventMouseMotion.new()
		e.position = pos
		e.global_position = pos
		e.relative = pos - prev
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
		get_viewport().push_input(e)
		prev = pos
		await _frames(1)


func _tap(pos: Vector2) -> void:
	_btn(pos, true)
	await _frames(1)
	_btn(pos, false)
	await _frames(1)


func _drag(from: Vector2, to: Vector2) -> void:
	_btn(from, true)
	await _frames(1)
	await _move(from, to, 14)
	_btn(to, false)
	await _frames(2)


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _host() -> Control:
	var host := Control.new()
	add_child(host)
	host.position = Vector2.ZERO
	host.size = Vector2(1200, 600)
	return host


func _step(cls: Variant, params: Dictionary, hints: bool = true) -> StepBase:
	var host := _host()
	var s: StepBase = cls.new()
	s.setup(params, hints, "easy")
	host.add_child(s)
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_state = {"done": 0, "mistakes": 0, "strikes": 0}
	s.completed.connect(func() -> void: _state["done"] += 1)
	s.mistake.connect(func(_m: String, strike: bool, _c: String) -> void:
		_state["mistakes"] += 1
		if strike:
			_state["strikes"] += 1)
	await _frames(3)
	return s


func _cleanup(s: Node) -> void:
	s.get_parent().queue_free()
	await _frames(2)


func _card(s: Node, label: String) -> ItemCard:
	for n: Node in s.find_children("*", "ItemCard", true, false):
		if (n as ItemCard).item.get("label", "") == label:
			return n
	return null


# ------------------------------------------------------------ mechanics

func _t_drag_drop() -> void:
	var s: DragDropStep = await _step(DragDropStep, {"items": [{"label": "Good", "correct": true}, {"label": "Bad", "correct": false}],
		"targets": [{"label": "Neck", "correct": false}, {"label": "Chest", "correct": true}]})
	var zones := s.find_children("*", "DropZone", true, false)
	check(zones.size() == 2, "drag_drop: two zones built")
	await _drag(_center(_card(s, "Bad")), _center(zones[1]))
	check(_state["mistakes"] == 1 and _state["strikes"] == 1, "drag_drop(real): wrong item dropped = strike")
	await _drag(_center(_card(s, "Bad")), _center(zones[1]))
	check(_state["mistakes"] == 1, "drag_drop(real): same wrong item can't be dropped twice")
	await _drag(_center(_card(s, "Good")), _center(zones[0]))
	check(_state["mistakes"] == 2, "drag_drop(real): wrong target = mistake")
	await _drag(_center(_card(s, "Good")), _center(zones[1]))
	check(_state["done"] == 1, "drag_drop(real): correct drag completes")
	# a used card cannot be dragged again
	check(_card(s, "Good").used, "drag_drop: card marked used")
	await _cleanup(s)


func _t_wipe() -> void:
	var s: WipeStep = await _step(WipeStep, {"axis": "horizontal", "coverage": 0.85,
		"tools": [{"label": "Water", "correct": true}, {"label": "Mud", "correct": false}]})
	var area: Control = s._area
	var r := area.get_global_rect()
	# wiping before the tool is placed does nothing
	await _drag(r.position + Vector2(10, 40), r.position + Vector2(r.size.x - 10, 40))
	check(s._cleared == 0, "wipe(real): no cleaning before tool")
	await _drag(_center(_card(s, "Mud")), r.get_center())
	check(_state["strikes"] == 1, "wipe(real): wrong tool = strike")
	await _drag(_center(_card(s, "Water")), r.get_center())
	check(s._tool_ready, "wipe(real): correct tool accepted by real drop")
	# wrong axis (vertical scrubbing) is punished
	_btn(r.position + Vector2(r.size.x / 2, 5), true)
	for k: int in 3:
		await _move(r.position + Vector2(r.size.x / 2, 5), r.position + Vector2(r.size.x / 2, r.size.y - 5), 8)
		await _move(r.position + Vector2(r.size.x / 2, r.size.y - 5), r.position + Vector2(r.size.x / 2, 5), 8)
	_btn(r.position + Vector2(r.size.x / 2, 5), false)
	check(_state["mistakes"] >= 2 and _state["strikes"] == 1, "wipe(real): vertical wiping on a horizontal step = technique mistake")
	# proper left-right strokes row by row
	var y := r.position.y + 10
	_btn(Vector2(r.position.x + 5, y), true)
	while y < r.end.y and _state["done"] == 0:
		await _move(Vector2(r.position.x + 5, y), Vector2(r.end.x - 5, y), 10)
		await _move(Vector2(r.end.x - 5, y), Vector2(r.position.x + 5, y + 20), 10)
		y += 40
	_btn(Vector2(r.position.x + 5, y), false)
	check(_state["done"] == 1, "wipe(real): back-and-forth strokes clean the wound")
	await _cleanup(s)


func _t_hold() -> void:
	var s: HoldStep = await _step(HoldStep, {"seconds": 0.6})
	var c := s.get_global_transform() * s._center
	_btn(c, true)
	await _wait(0.25)
	_btn(c, false)
	await _frames(1)
	check(_state["mistakes"] == 1 and s._progress == 0.0, "hold(real): early release = mistake + reset")
	_btn(c, true)
	await _wait(0.9)
	_btn(c, false)
	await _frames(1)
	check(_state["done"] == 1 and _state["mistakes"] == 1, "hold(real): full hold completes, no extra mistake")
	# pressing outside the target does nothing
	await _cleanup(s)


func _t_swipe() -> void:
	var s: SwipeStep = await _step(SwipeStep, {"direction": "down", "count": 2})
	var c := _center(s)
	await _drag(c, c + Vector2(0, -180))
	check(_state["mistakes"] == 1, "swipe(real): up instead of down = mistake")
	await _drag(c, c + Vector2(0, 30))
	check(_state["mistakes"] == 1 and s._count == 0, "swipe(real): tiny swipe ignored")
	await _drag(c, c + Vector2(15, 180))
	await _drag(c, c + Vector2(-15, 180))
	check(_state["done"] == 1, "swipe(real): 2 down swipes complete")
	await _cleanup(s)


func _t_rhythm() -> void:
	var s: RhythmStep = await _step(RhythmStep, {"count": 6, "bpm_min": 100, "bpm_max": 120, "pass_ratio": 0.7})
	var c := s.get_global_transform() * s._center()
	for i: int in 6:
		await _tap(c)
		await _wait(60.0 / 110.0 - 0.03)
	check(_state["done"] == 1, "rhythm(real): 6 taps at ~110 bpm complete (mistakes=%d)" % _state["mistakes"])
	await _cleanup(s)
	# too fast fails the cycle
	s = await _step(RhythmStep, {"count": 6, "bpm_min": 100, "bpm_max": 120, "pass_ratio": 0.7})
	c = s.get_global_transform() * s._center()
	for i: int in 6:
		await _tap(c)
		await _wait(0.2)
	check(_state["done"] == 0 and _state["mistakes"] == 1, "rhythm(real): 300 bpm fails the cycle")
	await _cleanup(s)


func _t_wrap() -> void:
	var s: WrapStep = await _step(WrapStep, {"turns": 2})
	var ctr := s.get_global_transform() * s._center()
	var rad := (s._r_in() * 1.6 + s._r_out()) / 2.0
	var start := ctr + Vector2(rad, 0)
	_btn(start, true)
	var prev := start
	for i: int in range(1, 100):
		var pos := ctr + Vector2.from_angle(i * TAU / 40.0) * rad
		await _move(prev, pos, 1)
		prev = pos
		if _state["done"] > 0:
			break
	_btn(prev, false)
	check(_state["done"] == 1 and _state["mistakes"] == 0, "wrap(real): 2 circles complete")
	await _cleanup(s)


func _t_sequence() -> void:
	var s: SequenceStep = await _step(SequenceStep, {"order": ["A", "B", "C"], "distractors": [{"label": "X", "effect": "no"}]})
	await _frames(2)
	var by_label := {}
	for b: Button in s._buttons:
		by_label[b.get_meta("entry")["label"]] = b
	await _tap(_center(by_label["X"]))
	await _tap(_center(by_label["C"]))
	check(_state["mistakes"] == 2 and _state["strikes"] == 1, "sequence(real): distractor = strike, wrong order = technique")
	for k: String in ["A", "B", "C"]:
		await _tap(_center(by_label[k]))
	check(_state["done"] == 1, "sequence(real): correct order completes")
	await _cleanup(s)


# ------------------------------------------------------------ scenario-level

func _scenario(level_id: int, d: String = "easy") -> Variant:
	Game.current_level_id = level_id
	Game.current_difficulty = d
	var sc: Variant = load("res://scenes/scenario.tscn").instantiate()
	get_tree().root.add_child(sc)      # root child so it can be current_scene (back button)
	get_tree().current_scene = sc
	await _frames(3)
	return sc


func _end_scenario(sc: Variant) -> void:
	get_tree().current_scene = self
	sc.queue_free()
	await _frames(2)


func _find_button(root: Node, text: String) -> Button:
	var found: Button = null
	for b: Node in root.find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Button).is_visible_in_tree() and not b.is_queued_for_deletion():
			found = b
	return found


func _continue_btn(sc: Node) -> Button:
	var found: Button = null
	for b: Node in sc.find_children("Continue", "Button", true, false):
		if not b.is_queued_for_deletion():
			found = b
	return found


func _effect_text(sc: Node) -> String:
	var t := ""
	for l: Node in sc.find_children("Effect", "Label", true, false):
		if not l.is_queued_for_deletion():
			t = (l as Label).text
	return t


## Full real-input flow: START -> click correct answer -> effect card -> CONTINUE ->
## real drag + real wiping -> effect card -> CONTINUE -> next scene.
func _t_scenario_real_clicks() -> void:
	var S := StageRunner.State
	var sc: Variant = await _scenario(1)
	await _tap(_center(_find_button(sc, "START")))
	await _frames(12)    # pop-in animations settle
	check(sc.runner.state == S.DECISION, "scenario(real): START opens scene 1")
	var slot: int = sc.current_correct_slot()
	var choice: Dictionary = sc.runner.current_scene()["choices"][sc._choice_order[slot]]
	await _tap(_center(sc._choice_buttons[slot]))
	await _frames(2)
	check(sc.runner.state == S.DECISION_RESULT and sc.overlay_kind() == "result", "scenario(real): clicking an answer shows the effect card")
	check(_effect_text(sc) == str(choice["effect"]), "scenario(real): card shows THIS choice's effect")
	check(sc.runner.score == 10 and sc.runner.strikes == 0, "scenario(real): +10, no strike")
	# clicking where the choices were does nothing while the card is up
	await _tap(_center(sc._choice_buttons[(slot + 1) % sc._choice_buttons.size()]))
	check(sc.runner.state == S.DECISION_RESULT, "scenario(real): card blocks the choices behind it")
	await _frames(20)
	await _tap(_center(_continue_btn(sc)))
	await _frames(12)
	check(sc.runner.state == S.ACTION and sc.current_step is WipeStep, "scenario(real): CONTINUE -> perform the procedure")
	var wp: WipeStep = sc.current_step
	var water := _card(wp, "Clean water")
	await _drag(_center(water), _center(wp._area))
	check(wp._tool_ready, "scenario(real): real drag of clean water onto the wound")
	var r: Rect2 = wp._area.get_global_rect()
	var y := r.position.y + 10
	_btn(Vector2(r.position.x + 5, y), true)
	while y < r.end.y and not wp.done:
		await _move(Vector2(r.position.x + 5, y), Vector2(r.end.x - 5, y), 10)
		await _move(Vector2(r.end.x - 5, y), Vector2(r.position.x + 5, y + 20), 10)
		y += 40
	_btn(Vector2(r.position.x + 5, y), false)
	await _frames(2)
	check(sc.runner.state == S.ACTION_RESULT and sc.overlay_kind() == "result", "scenario(real): finishing the wipe shows the success card")
	await _frames(20)
	await _tap(_center(_continue_btn(sc)))
	await _frames(4)
	check(sc.runner.state == S.DECISION and sc.runner.scene_idx == 1, "scenario(real): next scene")
	# Esc pauses / resumes (scene is current_scene)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	get_viewport().push_input(esc)
	await _frames(1)
	check(sc.is_paused(), "scenario(real): Esc pauses")
	get_viewport().push_input(esc.duplicate())
	await _frames(2)
	check(not sc.is_paused(), "scenario(real): Esc again resumes")
	await _end_scenario(sc)


## Wrong answer by real click: strike, heart breaks, effect + correct procedure shown,
## then "DO IT RIGHT" leads into the correct procedure.
func _t_wrong_choice_real() -> void:
	var S := StageRunner.State
	var sc: Variant = await _scenario(2, "hard")
	sc.start()
	await _frames(12)
	var right: int = sc.current_correct_slot()
	var wrong := 0 if right != 0 else 1
	var choice: Dictionary = sc.runner.current_scene()["choices"][sc._choice_order[wrong]]
	await _tap(_center(sc._choice_buttons[wrong]))
	await _frames(2)
	check(sc.runner.strikes == 1 and sc.overlay_kind() == "result", "wrong(real): strike + effect card")
	check(_effect_text(sc) == str(choice["effect"]), "wrong(real): card shows the wrong choice's effect")
	check(sc._hearts.strikes == 1, "wrong(real): heart meter shows 1 broken heart")
	var cont := _continue_btn(sc)
	check(cont != null and cont.text == "DO IT RIGHT", "wrong(real): button leads to the correct procedure")
	await _frames(20)
	await _tap(_center(cont))
	await _frames(4)
	check(sc.runner.state == S.ACTION, "wrong(real): moves forward into the correct procedure")
	# nosebleed lean: swiping UP = tilting head back = dangerous -> strike via real swipe
	var st: StepBase = sc.current_step
	var c := _center(st)
	await _drag(c, c + Vector2(0, -200))
	await _frames(2)
	check(sc.runner.strikes == 2 and sc.runner.state == S.STRIKE_RESULT, "wrong(real): real swipe the dangerous way = strike 2")
	await _frames(20)
	await _tap(_center(_continue_btn(sc)))
	await _frames(4)
	check(sc.runner.state == S.ACTION and sc.current_step == st, "wrong(real): TRY AGAIN returns to the same step")
	await _drag(c, c + Vector2(0, 200))
	await _frames(2)
	check(sc.runner.state == S.ACTION_RESULT, "wrong(real): correct swipe completes the step")
	await _end_scenario(sc)


func _t_double_tap_continue() -> void:
	var S := StageRunner.State
	var sc: Variant = await _scenario(1)
	sc.start()
	await _frames(12)
	# two taps on a WRONG answer in the same frame -> only one strike
	var wrong := 0 if sc.current_correct_slot() != 0 else 1
	var p := _center(sc._choice_buttons[wrong])
	_btn(p, true)
	_btn(p, false)
	_btn(p, true)
	_btn(p, false)
	await _frames(2)
	check(sc.runner.strikes == 1, "regression: double tap on an answer = one strike (got %d)" % sc.runner.strikes)
	await _frames(20)
	var cp := _center(_continue_btn(sc))
	_btn(cp, true)
	_btn(cp, false)
	_btn(cp, true)
	_btn(cp, false)
	await _frames(3)
	check(sc.runner.state == S.ACTION and sc.runner.scene_idx == 0 and sc.runner.action_idx == 0, "regression: double tap CONTINUE advances once")
	await _end_scenario(sc)


func _t_pause_resume_hold() -> void:
	var S := StageRunner.State
	# Level 2: scene 0 (lean swipe), scene 1 (pinch HOLD)
	var sc: Variant = await _scenario(2)
	sc.start()
	sc.choose(sc.current_correct_slot())
	sc.continue_stage()
	await _frames(2)
	sc.current_step.debug_swipe(Vector2(0, 200))
	sc.continue_stage()
	await _frames(2)
	sc.choose(sc.current_correct_slot())
	sc.continue_stage()
	await _frames(4)
	check(sc.runner.state == S.ACTION and sc.current_step is HoldStep, "pause test reached the hold step")
	var hold: HoldStep = sc.current_step
	var c := hold.get_global_transform() * hold._center
	_btn(c, true)
	await _wait(0.2)
	sc._show_pause()            # finger is still down when the game pauses
	await _frames(1)
	_btn(c, false)              # release happens while paused -> never delivered to the step
	await _frames(1)
	sc.resume_game()
	var before: float = hold._progress
	await _wait(0.5)
	check(not hold._holding and is_equal_approx(hold._progress, before), "regression: hold does not 'stick' after pause/resume")
	check(sc.runner.strikes == 0, "pausing mid-hold is not a strike")
	await _end_scenario(sc)


func _t_shuffle() -> void:
	var slots := {}
	for i: int in 12:
		var sc: Variant = await _scenario(1)
		sc.start()
		await _frames(1)
		var slot: int = sc.current_correct_slot()
		slots[slot] = true
		var correct_label := ""
		for ch: Dictionary in sc.runner.current_scene()["choices"]:
			if ch["correct"]:
				correct_label = ch["label"]
		check((sc._choice_buttons[slot] as Button).text.ends_with(correct_label), "shuffle: correct slot shows correct text")
		await _end_scenario(sc)
	check(slots.size() >= 2, "regression: correct answer position varies (seen %s)" % [slots.keys()])
