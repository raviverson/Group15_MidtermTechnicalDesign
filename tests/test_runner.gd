extends Node
## Headless logic test suite:
##   A. StageRunner state machine (unit + 3000-run fuzz for finiteness/invariants)
##   B. Database: content v2, v1->v2 migration, unlock chain, failed attempts
##   C. Gesture steps: strike vs technique classification, difficulty modifiers
##   D. Scenario screen: every level x every difficulty (perfect, 2 strikes, 3-strike fail),
##      consequence card after every choice, timeouts, timers, hints, penalties,
##      pause, double-tap guards
##   E. Every screen loads
## Run:  godot --headless res://tests/test_runner.tscn   (exit 0 = all pass)

var _fails: int = 0
var _passes: int = 0
var _rng := RandomNumberGenerator.new()


func check(cond: bool, what: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("FAIL: ", what)


func _ready() -> void:
	Game.test_mode = true
	_rng.seed = 12345
	await get_tree().process_frame
	_fresh_db("user://test_clinicrush.db")
	_test_runner_unit()
	_test_runner_fuzz()
	_test_database()
	_test_migration()
	_fresh_db("user://test_clinicrush.db")
	await _test_steps()
	await _test_scenario_all_levels()
	await _test_scenario_details()
	_test_progression()
	await _test_screens()
	print("RESULT: %d passed, %d failed" % [_passes, _fails])
	Database.open()
	get_tree().quit(1 if _fails > 0 else 0)


func _fresh_db(path: String) -> void:
	Database.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(Database.open(path), "db opens: %s" % path)


# ================================================================== A. runner

func _scenes_fixture() -> Array:
	var mk := func(t: String, n_actions: int) -> Dictionary:
		var acts: Array = []
		for i: int in n_actions:
			acts.append({"title": "%s-act%d" % [t, i], "type": "hold"})
		return {"title": t, "choices": [
			{"label": t + "-ok", "correct": true, "effect": t + " good effect", "mood": "happy"},
			{"label": t + "-bad", "correct": false, "effect": t + " bad effect", "mood": "hurt"},
			{"label": t + "-bad2", "correct": false, "effect": t + " bad effect 2"}], "actions": acts}
	return [mk.call("A", 1), mk.call("B", 0), mk.call("C", 2)]


func _test_runner_unit() -> void:
	var S := StageRunner.State
	# --- perfect run
	var r := StageRunner.new(_scenes_fixture(), 3)
	check(r.state == S.DECISION, "runner starts in DECISION")
	check(r.max_score() == 60, "max_score = 10 x (3 decisions + 3 actions) (got %d)" % r.max_score())
	var o := r.choose(0)
	check(o["correct"] and o["effect"] == "A good effect" and r.state == S.DECISION_RESULT, "correct choice -> effect shown, DECISION_RESULT")
	check(r.proceed() == S.ACTION, "after correct decision -> ACTION")
	check(r.action_done("done!")["correct"] and r.state == S.ACTION_RESULT, "action done -> ACTION_RESULT")
	check(r.proceed() == S.DECISION and r.scene_idx == 1, "scene A finished -> scene B decision")
	r.choose(0)
	check(r.proceed() == S.DECISION and r.scene_idx == 2, "scene without actions goes straight to next scene")
	r.choose(0)
	r.proceed()
	r.action_done()
	check(r.proceed() == S.ACTION and r.action_idx == 1, "second action of the same scene")
	r.action_done()
	check(r.proceed() == S.COMPLETE and r.is_over() and not r.is_failed(), "all scenes done -> COMPLETE")
	check(r.final_score() == 60 and r.stars() == 3 and r.strikes == 0, "perfect: 60/60, 3 stars, 0 strikes")

	# --- invalid calls are no-ops in every state
	r = StageRunner.new(_scenes_fixture(), 3)
	check(r.action_done().is_empty() and r.action_strike("x", "y").is_empty() and not r.action_technique_error(), "action calls ignored in DECISION")
	check(r.proceed() == S.DECISION, "proceed ignored in DECISION")
	check(r.choose(-1).is_empty() and r.choose(99).is_empty(), "out-of-range choice ignored")
	r.choose(1)
	check(r.choose(0).is_empty() and r.timeout().is_empty(), "double choose / timeout ignored in DECISION_RESULT")
	check(r.strikes == 1, "wrong choice = 1 strike")
	var log0: Dictionary = r.mistakes_log[0]
	check(log0["chosen"] == "A-bad" and log0["correct_procedure"] == "A-ok" and log0["effect"] == "A bad effect", "mistake mlog records choice, effect, correct procedure")
	check(r.proceed() == S.ACTION, "wrong decision still moves FORWARD into the correct procedure")
	check(r.choose(0).is_empty() and r.proceed() == S.ACTION, "choose/proceed ignored during ACTION")

	# --- 3 strikes: fails exactly on the 3rd, after its effect is shown
	r = StageRunner.new(_scenes_fixture(), 3)
	r.choose(1)
	r.proceed()
	r.action_done()
	r.proceed()
	o = r.choose(2)
	check(r.strikes == 2 and not o["failed_now"], "2 strikes: not failed yet")
	check(r.proceed() == S.DECISION, "2 strikes: continues to next scene")
	o = r.choose(1)
	check(o["failed_now"] and r.state == S.DECISION_RESULT, "3rd strike: effect card shown first (DECISION_RESULT)")
	check(r.proceed() == S.FAILED and r.is_failed() and r.is_over(), "3rd strike -> FAILED after continue")
	check(r.stars() == 0, "failed stage = 0 stars")
	var before := [r.score, r.strikes, r.scene_idx]
	r.choose(0)
	r.timeout()
	r.action_done()
	r.action_strike("a", "b")
	r.proceed()
	check(r.state == S.FAILED and [r.score, r.strikes, r.scene_idx] == before, "FAILED is terminal: every call is a no-op")

	# --- strikes inside an action
	r = StageRunner.new(_scenes_fixture(), 4)
	r.choose(1)
	r.proceed()
	o = r.action_strike("Toothpaste", "traps heat")
	check(o["strike"] and r.state == S.STRIKE_RESULT and r.strikes == 2 and r.score == -4, "in-action wrong procedure = strike + penalty")
	check(r.proceed() == S.ACTION and r.action_idx == 0, "after strike card: same procedure continues")
	r.action_strike("Ice", "damages skin")
	check(r.proceed() == S.FAILED, "3rd strike inside an action -> FAILED")

	# --- technique errors: points only
	r = StageRunner.new(_scenes_fixture(), 5)
	r.choose(0)
	r.proceed()
	check(r.action_technique_error() and r.strikes == 0 and r.score == 5 and r.incorrect == 1, "technique error: -penalty, no strike")
	check(r.state == S.ACTION, "technique error keeps the action going")

	# --- timeouts
	r = StageRunner.new(_scenes_fixture(), 3)
	o = r.timeout()
	check(o["strike"] and o.get("timeout", false) and r.strikes == 1 and r.state == S.DECISION_RESULT, "decision timeout = strike (hesitation)")
	check(o["effect"] == StageRunner.HESITATE_EFFECT, "decision timeout shows hesitation effect")
	r.proceed()
	r.action_done()
	r.proceed()
	r.choose(0)
	r.proceed()
	r.choose(0)
	r.proceed()   # scene C, action 0
	o = r.timeout()
	check(r.state == S.TIMEOUT_RESULT and r.strikes == 2, "action timeout = strike")
	check(r.proceed() == S.COMPLETE, "action timeout skips the rest of the scene (moves forward, never loops)")
	check(r.stars() <= 1, "2 strikes caps stars at 1 (got %d)" % r.stars())

	# --- star caps
	r = StageRunner.new(_scenes_fixture(), 0)
	r.choose(1)
	r.proceed()
	r.action_done()
	r.proceed()
	r.choose(0)
	r.proceed()
	r.choose(0)
	r.proceed()
	r.action_done()
	r.proceed()
	r.action_done()
	r.proceed()
	check(r.state == S.COMPLETE and r.strikes == 1 and r.stars() == 2, "1 strike caps stars at 2 (got %d)" % r.stars())

	# --- empty stage
	r = StageRunner.new([], 3)
	check(r.state == S.COMPLETE and r.max_score() == 0, "empty stage completes immediately")


## Random play: invariants must hold after EVERY call, and the stage must always end.
func _test_runner_fuzz() -> void:
	var S := StageRunner.State
	var violations := 0
	var unfinished := 0
	for run: int in 3000:
		var scenes: Array = []
		for s: int in _rng.randi_range(1, 5):
			var choices: Array = []
			var nch := _rng.randi_range(2, 4)
			var good := _rng.randi_range(0, nch - 1)
			for c: int in nch:
				choices.append({"label": "c%d" % c, "correct": c == good, "effect": "e%d" % c})
			var acts: Array = []
			for a: int in _rng.randi_range(0, 3):
				acts.append({"title": "a%d" % a})
			scenes.append({"title": "s%d" % s, "choices": choices, "actions": acts})
		var r := StageRunner.new(scenes, _rng.randi_range(0, 5))
		var last_scene := 0
		var decisions_entered := 1
		var calls := 0
		while not r.is_over() and calls < 400:
			calls += 1
			var was_state := r.state
			match _rng.randi_range(0, 6):
				0: r.choose(_rng.randi_range(-1, 4))
				1: r.timeout()
				2: r.action_done()
				3: r.action_strike("x", "y")
				4: r.action_technique_error()
				_: r.proceed()
			if r.state == S.DECISION and was_state != S.DECISION:
				decisions_entered += 1
			if r.strikes > 3 or r.scene_idx < last_scene or r.scene_idx > scenes.size():
				violations += 1
			if r.state == S.ACTION and (r.action_idx < 0 or r.action_idx >= r.current_actions().size()):
				violations += 1
			if r.state == S.FAILED and r.strikes != 3:
				violations += 1
			if r.state == S.COMPLETE and r.strikes >= 3:
				violations += 1
			last_scene = r.scene_idx
		if decisions_entered > scenes.size():
			violations += 1   # a scene was decided twice -> loop
		if not r.is_over():
			# random calls may just be unlucky; finish with a progress-only policy
			var guard := 0
			while not r.is_over() and guard < 200:
				guard += 1
				match r.state:
					S.DECISION: r.choose(0)
					S.ACTION: r.action_done()
					_: r.proceed()
			if not r.is_over():
				unfinished += 1
		var st := r.state
		r.choose(0)
		r.proceed()
		r.timeout()
		if r.state != st:
			violations += 1
	check(violations == 0, "fuzz: 3000 random stages, invariants hold (violations=%d)" % violations)
	check(unfinished == 0, "fuzz: every stage terminates (unfinished=%d)" % unfinished)


# ================================================================== B. database

func _test_database() -> void:
	var levels := Database.get_levels()
	check(levels.size() == 8, "8 levels seeded (got %d)" % levels.size())
	check(levels[0]["unlocked"] and not levels[1]["unlocked"], "only level 1 unlocked at start")
	for lv: Dictionary in levels:
		var id := int(lv["id"])
		var scenes := Database.get_scenes(id)
		check(scenes.size() >= 3, "%s has >= 3 scenes (3 wrong picks must be possible)" % lv["code"])
		check(Database.get_tips(id).size() >= 3, "%s has tips" % lv["code"])
		for sc: Dictionary in scenes:
			var where := "%s/%s" % [lv["code"], sc["title"]]
			var ch: Array = sc["choices"]
			check(ch.size() >= 2, "%s: >= 2 choices" % where)
			check(ch.filter(func(c: Dictionary) -> bool: return c.get("correct", false)).size() == 1, "%s: exactly one correct choice" % where)
			check(ch.all(func(c: Dictionary) -> bool: return str(c.get("effect", "")).length() > 10), "%s: every choice has an effect" % where)
			for a: Dictionary in sc["actions"]:
				check(str(a.get("type", "")) in ["drag_drop", "wipe", "hold", "swipe", "rhythm", "wrap", "sequence"], "%s: known action type" % where)
				var prm: Dictionary = a["params"]
				for it: Dictionary in prm.get("items", []) + prm.get("tools", []) + prm.get("targets", []) + prm.get("distractors", []):
					check(it.get("correct", false) or str(it.get("effect", "")) != "", "%s: wrong option '%s' has an effect" % [where, it.get("label", "")])
				check(float(a.get("time", 30)) >= 15.0, "%s: action has a sane time" % where)
	for d: String in ["easy", "normal", "hard"]:
		check(Database.is_difficulty_unlocked(1, d) == (d == "easy"), "start: only Easy unlocked (%s)" % d)
	check(Database.next_difficulty("easy") == "normal" and Database.next_difficulty("normal") == "hard" and Database.next_difficulty("hard") == "", "difficulty chain easy->normal->hard")
	Database.set_setting("vibration", false)
	check(not Database.get_setting_bool("vibration"), "setting saved")
	Database.set_setting("vibration", true)
	Database._seed_content(true)
	check(Database.get_levels().size() == 8 and Database.get_scenes(1).size() == 3, "re-seed is idempotent")
	# failed attempt: stored, does not clear or unlock anything
	var res := Database.record_attempt(1, "easy", {"score": 20, "max_score": 60, "stars": 2, "correct": 2, "incorrect": 3, "duration": 9.0, "failed": true, "strikes": 3})
	check(int(Database.get_progress(1, "easy")["completed"]) == 0, "failed run does not clear the level (even if stars were passed)")
	check(res["achievements"].is_empty() and not res["next_unlocked"] and res["difficulty_unlocked"] == "", "failed run unlocks nothing")
	var row := Database.q_one("SELECT failed, strikes, stars FROM attempts ORDER BY id DESC LIMIT 1")
	check(int(row["failed"]) == 1 and int(row["strikes"]) == 3 and int(row["stars"]) == 0, "failed attempt logged with failed=1, strikes=3, stars=0")
	# a clear unlocks the next difficulty and level
	res = Database.record_attempt(1, "easy", {"score": 50, "max_score": 60, "stars": 2, "correct": 5, "incorrect": 1, "duration": 9.0, "failed": false, "strikes": 1})
	check(res["difficulty_unlocked"] == "normal" and res["next_unlocked"], "Easy clear unlocks Normal + next level")
	res = Database.record_attempt(1, "normal", {"score": 50, "max_score": 60, "stars": 2, "correct": 5, "incorrect": 1, "duration": 9.0, "failed": false, "strikes": 1})
	check(res["difficulty_unlocked"] == "hard" and not res["next_unlocked"], "Normal clear unlocks Hard")
	Database.reset_progress()


## A save file from the previous version must upgrade without losing progress.
func _test_migration() -> void:
	var path := "user://test_migrate.db"
	Database.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var old := SQLite.new()
	old.path = path
	old.verbosity_level = SQLite.QUIET
	old.open_db()
	for s: String in [
		"CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)",
		"INSERT INTO meta VALUES('schema_version','1'),('content_version','1')",
		"CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)",
		"INSERT INTO settings VALUES('vibration','0')",
		"CREATE TABLE levels (id INTEGER PRIMARY KEY, code TEXT UNIQUE, title TEXT, category TEXT, sort_order INTEGER, scenario TEXT, patient_label TEXT, summary TEXT)",
		"INSERT INTO levels VALUES(1,'minor_cut','Minor Cuts','',1,'x','Knee','')",
		"CREATE TABLE questions (id INTEGER PRIMARY KEY AUTOINCREMENT, level_id INTEGER, sort_order INTEGER, prompt TEXT, choices_json TEXT, correct_index INTEGER, explanation TEXT, time_limit REAL)",
		"CREATE TABLE steps (id INTEGER PRIMARY KEY AUTOINCREMENT, level_id INTEGER, sort_order INTEGER, title TEXT, type TEXT, instruction TEXT, hint TEXT, success_text TEXT, time_limit REAL, params_json TEXT)",
		"CREATE TABLE tips (id INTEGER PRIMARY KEY AUTOINCREMENT, level_id INTEGER, sort_order INTEGER, text TEXT)",
		"CREATE TABLE progress (level_id INTEGER, difficulty TEXT, completed INTEGER DEFAULT 0, best_score INTEGER DEFAULT 0, best_stars INTEGER DEFAULT 0, attempts INTEGER DEFAULT 0, PRIMARY KEY(level_id, difficulty))",
		"INSERT INTO progress VALUES(1,'easy',1,40,3,2)",
		"CREATE TABLE attempts (id INTEGER PRIMARY KEY AUTOINCREMENT, level_id INTEGER, difficulty TEXT, score INTEGER, max_score INTEGER, stars INTEGER, correct INTEGER, incorrect INTEGER, duration_sec REAL, created_at TEXT DEFAULT CURRENT_TIMESTAMP)",
		"INSERT INTO attempts(level_id,difficulty,score,max_score,stars,correct,incorrect,duration_sec) VALUES(1,'easy',40,40,3,4,0,30)",
		"CREATE TABLE achievements (id TEXT PRIMARY KEY, title TEXT, description TEXT, unlocked_at TEXT)",
		"INSERT INTO achievements VALUES('first_aid_rookie','First Responder','x','2026-10-01')",
	]:
		old.query(s)
	old.close_db()
	check(Database.open(path), "v1 save opens with v2 code")
	check(Database.get_meta_value("schema_version") == "2", "schema upgraded to v2")
	check(Database.q("SELECT name FROM sqlite_master WHERE name IN ('questions','steps')").is_empty(), "old content tables dropped")
	check(Database.get_scenes(1).size() == 3 and Database.get_levels().size() == 8, "new content seeded after migration")
	check(int(Database.get_progress(1, "easy")["best_stars"]) == 3 and Database.is_level_unlocked(2), "player progress survives migration")
	check(Database.is_difficulty_unlocked(1, "normal") and not Database.is_difficulty_unlocked(1, "hard"), "old Easy clear unlocks Normal (not Hard)")
	check(not Database.get_setting_bool("vibration"), "settings survive migration")
	var cols := Database.q("PRAGMA table_info(attempts)").map(func(c: Dictionary) -> String: return str(c["name"]))
	check("failed" in cols and "strikes" in cols, "attempts gained failed/strikes columns")
	check(int(Database.q_one("SELECT COUNT(*) AS n FROM attempts")["n"]) == 1, "old attempts kept")
	check(Database.get_achievements().any(func(a: Dictionary) -> bool: return a["id"] == "first_aid_rookie" and a["unlocked_at"] != null), "unlocked achievements kept")
	check(Database.open(path) and Database.get_meta_value("schema_version") == "2", "re-opening a migrated save is a no-op")


# ================================================================== C. steps

func _host() -> Control:
	var host := Control.new()
	host.size = Vector2(1100, 520)
	add_child(host)
	return host


func _make_step(cls: Variant, params: Dictionary, host: Control, diff_key: String = "easy", hints: bool = true) -> StepBase:
	var s: StepBase = cls.new()
	s.setup(params, hints, diff_key)
	host.add_child(s)
	s.size = host.size
	return s


func _test_steps() -> void:
	var host := _host()
	await get_tree().process_frame
	var mlog: Array = []
	var hook := func(s: StepBase) -> void:
		s.mistake.connect(func(m: String, strike: bool, chosen: String) -> void: mlog.append([m, strike, chosen]))

	var dd: DragDropStep = _make_step(DragDropStep, {"items": [{"label": "Good", "correct": true}, {"label": "Bad", "correct": false, "effect": "bad thing"}],
		"targets": [{"label": "Neck", "correct": false, "effect": "neck bad"}, {"label": "Chest", "correct": true}]}, host)
	hook.call(dd)
	await get_tree().process_frame
	var zones := dd.find_children("*", "DropZone", true, false)
	var bad_card := ItemCard.new()
	bad_card.item = {"label": "Bad", "correct": false, "effect": "bad thing"}
	host.add_child(bad_card)
	dd._on_drop(bad_card.item, bad_card, zones[1])
	check(mlog.size() == 1 and mlog[0][1] == true and mlog[0][0] == "bad thing" and mlog[0][2] == "Bad", "drag: wrong item = STRIKE with its effect")
	check(bad_card.tried_wrong and bad_card._get_drag_data(Vector2.ZERO) == null, "drag: wrong item locked after its consequence (no double strike)")
	var good_card := ItemCard.new()
	good_card.item = {"label": "Good", "correct": true}
	host.add_child(good_card)
	dd._on_drop(good_card.item, good_card, zones[0])
	check(mlog.size() == 2 and mlog[1][1] == true and mlog[1][0] == "neck bad", "drag: wrong target = STRIKE")
	check(not zones[0].accepting, "drag: wrong target locked after its consequence")
	dd._on_drop(good_card.item, good_card, zones[1])
	check(dd.done, "drag: correct item on correct target completes")

	mlog.clear()
	var wp: WipeStep = _make_step(WipeStep, {"axis": "horizontal", "coverage": 0.85, "tools": [{"label": "Water", "correct": true}, {"label": "Mud", "correct": false, "effect": "infection"}]}, host, "hard")
	hook.call(wp)
	await get_tree().process_frame
	var mud := ItemCard.new()
	mud.item = {"label": "Mud", "correct": false, "effect": "infection"}
	host.add_child(mud)
	wp._on_tool_drop(mud.item, mud, null)
	check(mlog.size() == 1 and mlog[0][1] == true, "wipe: wrong tool = STRIKE")
	wp._on_tool_drop({"label": "Water", "correct": true}, null, null)
	wp._wrong_dist = 1000.0
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(0, 30)
	ev.position = Vector2(50, 50)
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	wp._on_area_input(ev)
	check(mlog.size() == 2 and mlog[1][1] == false, "wipe: wrong axis = technique (no strike)")
	check(is_equal_approx(wp.required_coverage(), 0.9), "wipe: Hard needs 90%% coverage (got %.2f)" % wp.required_coverage())
	var wpe: WipeStep = _make_step(WipeStep, {"coverage": 0.85}, host, "easy")
	check(is_equal_approx(wpe.required_coverage(), 0.8), "wipe: Easy needs 80% coverage")
	var area: DropZone = wp._area
	for y: int in range(0, int(area.size.y) + 40, 25):
		for x: int in range(0, int(area.size.x) + 40, 25):
			wp._scrub(Vector2(x, y))
	check(wp.done, "wipe: completes at full coverage")

	mlog.clear()
	var hd_easy: HoldStep = _make_step(HoldStep, {"seconds": 2.0}, host, "easy")
	var hd_hard: HoldStep = _make_step(HoldStep, {"seconds": 2.0}, host, "hard")
	hook.call(hd_easy)
	hd_easy.debug_force_hold(1.0)
	hd_hard.debug_force_hold(1.0)
	check(hd_easy._progress > hd_hard._progress, "hold: Easy fills faster than Hard (hold_mult)")
	hd_easy._release()
	check(mlog.size() == 1 and mlog[0][1] == false, "hold: early release = technique")
	hd_easy.debug_force_hold(5.0)
	check(hd_easy.done, "hold completes")

	mlog.clear()
	var sw: SwipeStep = _make_step(SwipeStep, {"direction": "down", "count": 1}, host)
	var sw2: SwipeStep = _make_step(SwipeStep, {"direction": "down", "count": 1, "wrong_strike": true}, host)
	hook.call(sw)
	hook.call(sw2)
	sw.debug_swipe(Vector2(0, -200))
	sw2.debug_swipe(Vector2(0, -200))
	check(mlog.size() == 2 and mlog[0][1] == false and mlog[1][1] == true, "swipe: wrong direction is technique unless wrong_strike (tilting head back)")
	sw.debug_swipe(Vector2(0, 200))
	check(sw.done, "swipe completes")

	mlog.clear()
	var rh: RhythmStep = _make_step(RhythmStep, {"count": 10, "bpm_min": 100, "bpm_max": 120, "pass_ratio": 0.7}, host, "hard")
	hook.call(rh)
	for i: int in 10:
		rh.tap(i * 1.0)
	check(mlog.size() == 1 and mlog[0][1] == false and not rh.done, "rhythm: too slow = technique, cycle restarts")
	for i: int in 10:
		rh.tap(100.0 + i * 60.0 / 110.0)
	check(rh.done, "rhythm: 110 bpm passes")
	# slack: 6/9 good = 0.67 fails Hard (0.7) but passes Easy (0.55)
	for dk: String in ["hard", "easy"]:
		var r2: RhythmStep = _make_step(RhythmStep, {"count": 10, "bpm_min": 100, "bpm_max": 120, "pass_ratio": 0.7}, host, dk)
		var t := 0.0
		r2.tap(t)
		for i: int in 9:
			t += 60.0 / 110.0 if i < 6 else 0.8
			r2.tap(t)
		check(r2.done == (dk == "easy"), "rhythm: 67%% in rhythm -> %s %s" % [dk, "passes" if dk == "easy" else "fails"])

	mlog.clear()
	var wr: WrapStep = _make_step(WrapStep, {"turns": 1}, host)
	hook.call(wr)
	await get_tree().process_frame
	var ctr := wr._center()
	var rad := (wr._r_in() + wr._r_out()) / 2.0
	for i: int in 10:
		wr.move_to(ctr + Vector2.from_angle(i * TAU / 40.0) * rad)
	for i: int in range(10, -20, -1):
		wr.move_to(ctr + Vector2.from_angle(i * TAU / 40.0) * rad)
	check(mlog.size() >= 1 and mlog.all(func(e: Array) -> bool: return e[1] == false), "wrap: reversing = technique")

	mlog.clear()
	var sq: SequenceStep = _make_step(SequenceStep, {"order": ["A", "B"], "distractors": [{"label": "X", "effect": "x bad"}]}, host)
	hook.call(sq)
	await get_tree().process_frame
	for b: Button in sq._buttons:
		if b.get_meta("entry")["index"] == 1:
			sq._on_pressed(b)
	for b: Button in sq._buttons:
		if b.get_meta("entry")["index"] == -1:
			sq._on_pressed(b)
			check(b.disabled, "sequence: distractor locked after its consequence")
	check(mlog.size() == 2 and mlog[0][1] == false and mlog[1][1] == true and mlog[1][0] == "x bad", "sequence: wrong order = technique, dangerous action = STRIKE")
	sq.debug_solve()
	check(sq.done, "sequence completes")
	host.queue_free()
	await get_tree().process_frame


# ================================================================== D. scenario

func _scenario(level_id: int, d: String) -> Variant:
	Game.current_level_id = level_id
	Game.current_difficulty = d
	Game.last_result = {}
	var sc: Variant = load("res://scenes/scenario.tscn").instantiate()
	add_child(sc)
	await get_tree().process_frame
	return sc


func _solve(step: Variant, act: Dictionary) -> void:
	var prm: Dictionary = act["params"]
	match act["type"]:
		"drag_drop":
			for z: Node in step.find_children("*", "DropZone", true, false):
				if z.zone_data.get("correct", false):
					for it: Dictionary in prm["items"]:
						if it.get("correct", false):
							step._on_drop(it, null, z)
		"wipe":
			for it: Dictionary in prm.get("tools", []):
				if it.get("correct", false):
					step._on_tool_drop(it, null, null)
			var area: DropZone = step._area
			for y: int in range(0, int(area.size.y) + 40, 25):
				for x: int in range(0, int(area.size.x) + 40, 25):
					step._scrub(Vector2(x, y))
		"hold":
			step.debug_force_hold(999.0)
		"swipe":
			var v: Vector2 = step._dir_vec() * 200.0
			for i: int in int(prm.get("count", 1)):
				step.debug_swipe(v)
		"rhythm":
			for i: int in int(prm.get("count", 30)):
				step.tap(i * 60.0 / 110.0)
		"wrap":
			var ctr: Vector2 = step._center()
			var rad: float = (step._r_in() + step._r_out()) / 2.0
			for i: int in int(prm.get("turns", 3)) * 45:
				step.move_to(ctr + Vector2.from_angle(i * TAU / 40.0) * rad)
		"sequence":
			step.debug_solve()


func _wrong_slot(sc: Variant) -> int:
	var right: int = sc.current_correct_slot()
	return 0 if right != 0 else 1


## The consequence card must be up and show the given effect text.
func _card_shows(sc: Variant, effect: String) -> bool:
	if sc.overlay_kind() != "result":
		return false
	var lbls: Array = sc.find_children("Effect", "Label", true, false)
	return lbls.size() > 0 and (lbls[lbls.size() - 1] as Label).text == effect


func _play(sc: Variant, wrong_scenes: Array, label: String) -> Dictionary:
	var S := StageRunner.State
	sc.start()
	var guard := 0
	var info := {"cards": 0, "card_ok": true, "timer_stopped": true}
	while not sc.runner.is_over() and guard < 80:
		guard += 1
		await get_tree().process_frame
		match sc.runner.state:
			S.DECISION:
				var idx: int = sc.runner.scene_idx
				var slot: int = _wrong_slot(sc) if idx in wrong_scenes else sc.current_correct_slot()
				var ch: Dictionary = sc.runner.current_scene()["choices"][sc._choice_order[slot]]
				sc.choose(slot)
				info["cards"] += 1
				if not _card_shows(sc, str(ch["effect"])):
					info["card_ok"] = false
				await get_tree().process_frame
				var tl: float = sc.time_left()
				await get_tree().process_frame
				if sc.time_left() != tl:
					info["timer_stopped"] = false
				sc.choose(slot)   # double tap must be ignored
				sc.continue_stage()
			S.ACTION:
				await get_tree().process_frame
				_solve(sc.current_step, sc.runner.current_action())
				if sc.overlay_kind() != "result":
					info["card_ok"] = false
				info["cards"] += 1
				sc.continue_stage()
			_:
				sc.continue_stage()
	check(guard < 80, "%s: stage finished without looping" % label)
	sc.queue_free()
	await get_tree().process_frame
	return info


func _test_scenario_all_levels() -> void:
	for lv: Dictionary in Database.get_levels():
		var id := int(lv["id"])
		for d: String in Game.DIFFICULTY_ORDER:
			var tag := "%s/%s" % [lv["code"], d]
			# perfect run
			var sc: Variant = await _scenario(id, d)
			var info: Dictionary = await _play(sc, [], tag + " perfect")
			var r: Dictionary = Game.last_result
			check(not r.get("failed", true) and int(r.get("stars", 0)) == 3 and int(r.get("strikes", -1)) == 0, "%s: perfect run = 3 stars (got %s)" % [tag, r.get("stars")])
			check(int(r.get("score", 0)) == int(r.get("max_score", -1)), "%s: perfect score = max" % tag)
			check(info["card_ok"] and info["timer_stopped"], "%s: effect card after every choice, timer frozen on it" % tag)
			# fail run: wrong on the first 3 scenes
			sc = await _scenario(id, d)
			await _play(sc, [0, 1, 2], tag + " fail")
			r = Game.last_result
			check(r.get("failed", false) and int(r.get("strikes", 0)) == 3 and int(r.get("stars", 9)) == 0, "%s: 3 wrong procedures -> STAGE FAILED" % tag)
			check(r.get("mistakes", []).size() == 3, "%s: failed review lists the 3 mistakes" % tag)
			# 2 wrong = still clears (close call), capped at 1 star
			sc = await _scenario(id, d)
			await _play(sc, [0, 1], tag + " 2 strikes")
			r = Game.last_result
			check(not r.get("failed", true) and int(r.get("strikes", 0)) == 2 and int(r.get("stars", 0)) <= 1, "%s: 2 strikes clears with <= 1 star" % tag)


func _test_scenario_details() -> void:
	var S := StageRunner.State
	# --- difficulty SPEC (hard-coded on purpose: tests must not read the values they check)
	var spec := {
		"easy": {"timer": 37.5, "penalty": 2, "hints": "always"},
		"normal": {"timer": 30.0, "penalty": 3, "hints": "after_mistake"},
		"hard": {"timer": 25.0, "penalty": 5, "hints": "never"},
	}
	for d: String in Game.DIFFICULTY_ORDER:
		var sc: Variant = await _scenario(1, d)   # scene 1 of Minor Cuts is authored as 25 s
		sc.start()
		var expect: float = spec[d]["timer"]
		check(absf(sc.time_left() - expect) < 0.5, "%s: decision timer = %.1fs (got %.1f)" % [d, expect, sc.time_left()])
		check(int(Game.diff_of(d)["penalty"]) == int(spec[d]["penalty"]) and str(Game.diff_of(d)["hints"]) == spec[d]["hints"], "%s: penalty/hints match spec" % d)
		sc.queue_free()
		await get_tree().process_frame
	# modifiers must get strictly harder Easy -> Normal -> Hard
	var e: Dictionary = Game.diff_of("easy")
	var n: Dictionary = Game.diff_of("normal")
	var h: Dictionary = Game.diff_of("hard")
	check(float(e["time_mult"]) > float(n["time_mult"]) and float(n["time_mult"]) > float(h["time_mult"]), "time gets shorter with difficulty")
	check(float(e["rhythm_slack"]) > float(n["rhythm_slack"]) and float(n["rhythm_slack"]) >= float(h["rhythm_slack"]), "CPR tolerance gets stricter")
	check(float(e["coverage_delta"]) < float(n["coverage_delta"]) and float(n["coverage_delta"]) < float(h["coverage_delta"]), "wipe coverage gets stricter")
	check(float(e["hold_mult"]) < float(n["hold_mult"]) and float(n["hold_mult"]) < float(h["hold_mult"]), "holds get longer")

	# --- decision timeout = strike + TIME'S UP card
	var sc2: Variant = await _scenario(2, "normal")
	sc2.start()
	sc2._time_left = 0.01
	await get_tree().process_frame
	await get_tree().process_frame
	check(sc2.runner.strikes == 1 and sc2.runner.state == S.DECISION_RESULT and sc2.overlay_kind() == "result", "decision timeout -> strike + effect card")
	sc2.continue_stage()
	await get_tree().process_frame
	check(sc2.runner.state == S.ACTION, "after timeout card: perform the correct procedure")
	# --- action timeout = strike, skips to next scene
	sc2._time_left = 0.01
	await get_tree().process_frame
	await get_tree().process_frame
	check(sc2.runner.state == S.TIMEOUT_RESULT and sc2.runner.strikes == 2, "action timeout -> strike")
	sc2.continue_stage()
	check(sc2.runner.state == S.DECISION and sc2.runner.scene_idx == 1, "action timeout moves forward to next scene")
	sc2.queue_free()
	await get_tree().process_frame

	# --- hints: easy on, normal after mistake, hard never; penalties per difficulty
	for d: String in Game.DIFFICULTY_ORDER:
		var sc: Variant = await _scenario(2, d)   # nosebleed: scene 0 action = swipe
		sc.start()
		sc.choose(sc.current_correct_slot())
		sc.continue_stage()
		await get_tree().process_frame
		var st: StepBase = sc.current_step
		var mode: String = Game.diff_of(d)["hints"]
		check(st.hints_enabled == (mode == "always"), "%s: hints at step start = %s" % [d, mode == "always"])
		var before: int = sc.runner.score
		st.fail("slip", false)
		check(sc.runner.score == before - int(Game.diff_of(d)["penalty"]) and sc.runner.strikes == 0, "%s: technique penalty = %d, no strike" % [d, Game.diff_of(d)["penalty"]])
		check(st.hints_enabled == (mode != "never"), "%s: hints after a mistake = %s" % [d, mode != "never"])
		sc.queue_free()
		await get_tree().process_frame

	# --- in-action strike keeps the same step (progress kept), 3rd strike fails
	var sc3: Variant = await _scenario(4, "easy")   # burn: scene 0 actions = swipe, hold
	sc3.start()
	sc3.choose(_wrong_slot(sc3))                     # strike 1
	sc3.continue_stage()
	await get_tree().process_frame
	var step: StepBase = sc3.current_step
	step.fail("dangerous", true, "Ice")              # strike 2
	check(sc3.runner.state == S.STRIKE_RESULT and sc3.overlay_kind() == "result", "in-action wrong procedure -> effect card")
	sc3.continue_stage()
	await get_tree().process_frame
	check(sc3.current_step == step and sc3.runner.state == S.ACTION, "after strike card the same step continues (progress kept)")
	step.fail("dangerous again", true, "Toothpaste")  # strike 3
	var conts: Array = sc3.find_children("Continue", "Button", true, false)
	check(conts.size() > 0 and (conts[conts.size() - 1] as Button).text == "SEE RESULTS", "3rd strike card says SEE RESULTS")
	sc3.continue_stage()
	check(sc3.runner.state == S.FAILED and Game.last_result.get("failed", false), "3rd strike inside an action -> STAGE FAILED")
	sc3.queue_free()
	await get_tree().process_frame

	# --- pause freezes timer and blocks input; double continue is safe; back button
	var sc4: Variant = await _scenario(1, "easy")
	sc4.start()
	sc4._show_pause()
	var t0: float = sc4.time_left()
	for i: int in 5:
		await get_tree().process_frame
	check(sc4.time_left() == t0, "pause freezes the timer")
	sc4.choose(sc4.current_correct_slot())
	check(sc4.runner.state == S.DECISION, "cannot choose while paused")
	sc4.resume_game()
	sc4.choose(sc4.current_correct_slot())
	sc4.continue_stage()
	sc4.continue_stage()
	check(sc4.runner.state == S.ACTION and sc4.runner.scene_idx == 0, "double CONTINUE advances once")
	await get_tree().process_frame
	sc4.on_back()
	check(sc4.is_paused(), "back button pauses during play")
	sc4.on_back()
	check(not sc4.is_paused(), "back button again resumes")
	sc4.queue_free()
	await get_tree().process_frame


func _test_progression() -> void:
	check(Database.is_level_unlocked(8), "all levels unlocked after clearing each")
	for d: String in Game.DIFFICULTY_ORDER:
		check(Database.is_difficulty_unlocked(1, d), "%s unlocked after clearing the chain" % d)
	var ids := Database.get_achievements().filter(func(a: Dictionary) -> bool: return a["unlocked_at"] != null).map(func(a: Dictionary) -> String: return a["id"])
	for a: String in ["first_aid_rookie", "perfect", "no_mistakes", "hard_clear", "all_easy", "all_hard", "cpr_hero", "close_call"]:
		check(a in ids, "achievement unlocked: %s" % a)
	var failed_rows := int(Database.q_one("SELECT COUNT(*) AS n FROM attempts WHERE failed = 1")["n"])
	check(failed_rows >= 24, "every failed run logged (got %d)" % failed_rows)
	Database.reset_progress()
	check(not Database.is_level_unlocked(2) and not Database.is_difficulty_unlocked(1, "normal"), "reset re-locks levels and difficulties")


# ================================================================== E. screens

func _test_screens() -> void:
	Game.last_result = {"level_id": 1, "difficulty": "normal", "score": 30, "max_score": 60, "stars": 0, "correct": 3, "incorrect": 3,
		"duration": 20.0, "failed": true, "strikes": 3, "mistakes": [{"scene": "Clean", "chosen": "Leaf", "effect": "infected", "correct_procedure": "Water"}]}
	for s: String in ["main_menu", "level_select", "difficulty_select", "scenario", "level_complete", "stage_failed", "tips", "settings", "achievements"]:
		var ps: PackedScene = load("res://scenes/%s.tscn" % s)
		check(ps != null, "scene %s loads" % s)
		if ps == null:
			continue
		var n: Node = ps.instantiate()
		var scr: Script = n.get_script()
		check(scr != null and scr.can_instantiate(), "screen %s script compiles" % s)
		add_child(n)
		await get_tree().process_frame
		await get_tree().process_frame
		check(n.get_child_count() > 0, "screen %s built UI" % s)
		check(n.has_method("on_back"), "screen %s handles back button" % s)
		n.queue_free()
		await get_tree().process_frame
