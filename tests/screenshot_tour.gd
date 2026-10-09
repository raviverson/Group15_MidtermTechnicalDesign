extends Node
## Dev tool: renders every screen + every mechanic + consequence cards to PNGs.
##   godot res://tests/screenshot_tour.tscn -- <output_dir>
## (needs a real display / xvfb, not --headless)

var out_dir: String = "user://shots"


func _ready() -> void:
	Game.test_mode = true
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Database.close()
	Database.open("user://tour.db")
	Database.reset_progress()
	var ok := {"score": 50, "max_score": 60, "stars": 3, "correct": 6, "incorrect": 0, "duration": 30.0, "failed": false, "strikes": 0}
	Database.record_attempt(1, "easy", ok)
	Database.record_attempt(1, "normal", ok)
	Database.record_attempt(2, "easy", {"score": 30, "max_score": 50, "stars": 2, "correct": 3, "incorrect": 1, "duration": 30.0, "failed": false, "strikes": 1})
	for s: String in ["main_menu", "level_select", "achievements", "settings", "tips"]:
		await _shot_scene(s, s)
	Game.current_level_id = 2
	await _shot_scene("difficulty_select", "difficulty_select")
	Game.last_result = {"level_id": 1, "difficulty": "easy", "score": 60, "max_score": 60, "stars": 3, "correct": 6, "incorrect": 0, "strikes": 0,
		"duration": 52.0, "new_best": true, "next_unlocked": true, "difficulty_unlocked": "normal", "achievements": ["First Responder"]}
	await _shot_scene("level_complete", "level_complete", 1.6)
	Game.last_result = {"level_id": 4, "difficulty": "normal", "score": 10, "max_score": 60, "stars": 0, "correct": 1, "incorrect": 3, "strikes": 3, "failed": true, "duration": 40.0,
		"mistakes": [{"scene": "Cool", "chosen": "Put toothpaste on it", "effect": "Toothpaste traps heat in the skin. The burn gets deeper and may become infected.", "correct_procedure": "Remove watches/rings and cool the burn under cool running water"},
			{"scene": "Cool", "chosen": "Ice cubes", "effect": "Ice damages the burned skin.", "correct_procedure": ""},
			{"scene": "Cover", "chosen": "With cotton balls", "effect": "Cotton fibers stick to the burn and are painful to remove.", "correct_procedure": "Loosely, with cling film or a clean non-stick dressing"}]}
	await _shot_scene("stage_failed", "stage_failed", 1.2)

	# gameplay
	var sc: Variant = await _open_scenario(1, "easy")
	await _snap("play_01_intro", 0.5)
	sc.start()
	await _snap("play_02_decision", 0.6)
	sc.choose(sc.current_correct_slot())
	await _snap("play_03_result_correct", 0.5)
	sc.continue_stage()
	await _snap("play_04_wipe_tool", 0.4)
	var wp: Variant = sc.current_step
	for it: Dictionary in sc.runner.current_action()["params"]["tools"]:
		if it["correct"]:
			wp._on_tool_drop(it, null, null)
	for x: int in range(0, 360, 18):
		wp._scrub(Vector2(x, 90 + (x % 50)))
	await _snap("play_05_wipe_progress")
	_close(sc)

	sc = await _open_scenario(4, "normal")
	sc.start()
	await get_tree().process_frame
	var wrong: int = 0 if sc.current_correct_slot() != 0 else 1
	sc.choose(wrong)
	await _snap("play_06_result_wrong", 0.6)
	sc.continue_stage()
	await _snap("play_07_swipe", 0.4)
	_close(sc)

	sc = await _open_scenario(2, "easy")
	await _advance(sc, 1)       # to scene 1 action (hold)
	sc.current_step.debug_force_hold(2.5)
	await _snap("play_08_hold", 0.2)
	_close(sc)

	sc = await _open_scenario(3, "easy")
	sc.start()
	sc.choose(sc.current_correct_slot())
	sc.continue_stage()
	await _snap("play_09_sequence", 0.4)
	await _advance(sc, 2, false)
	await get_tree().process_frame
	var wr: Variant = sc.current_step
	var ctr: Vector2 = wr._center()
	var rad: float = (wr._r_in() + wr._r_out()) / 2.0
	for i: int in 60:
		wr.move_to(ctr + Vector2.from_angle(i * TAU / 40.0) * rad)
	await _snap("play_10_wrap", 0.2)
	_close(sc)

	sc = await _open_scenario(8, "easy")
	await _advance(sc, 1)
	await _snap("play_11_drag_targets", 0.4)
	_close(sc)
	sc = await _open_scenario(8, "easy")
	await _advance(sc, 2)
	for i: int in 12:
		sc.current_step.tap(i * 0.53)
	await _snap("play_12_rhythm", 0.2)
	sc._show_pause()
	await _snap("play_13_pause", 0.4)
	_close(sc)
	get_tree().quit()


func _open_scenario(level_id: int, d: String) -> Variant:
	Game.current_level_id = level_id
	Game.current_difficulty = d
	var sc: Variant = load("res://scenes/scenario.tscn").instantiate()
	add_child(sc)
	await get_tree().process_frame
	return sc


## Play correctly until the first action of scene `scene_idx` is on screen.
func _advance(sc: Variant, scene_idx: int, do_start: bool = true) -> void:
	var S := StageRunner.State
	if do_start:
		sc.start()
	var guard := 0
	while guard < 40:
		guard += 1
		await get_tree().process_frame
		if sc.runner.state == S.ACTION and sc.runner.scene_idx == scene_idx:
			return
		match sc.runner.state:
			S.DECISION:
				sc.choose(sc.current_correct_slot())
			S.ACTION:
				sc.runner.action_done("")
			_:
				sc.continue_stage()


func _close(sc: Variant) -> void:
	sc.queue_free()


func _snap(shot_name: String, wait: float = 0.0) -> void:
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	for i: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot_name + ".png"))
	print("saved ", shot_name)


func _shot_scene(s: String, shot: String, wait: float = 0.7) -> void:
	var node: Node = load("res://scenes/%s.tscn" % s).instantiate()
	add_child(node)
	await _snap(shot, wait)
	node.queue_free()
	await get_tree().process_frame
