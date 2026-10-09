extends Node
## Autoload "Database" — all SQLite access goes through here (godot-sqlite v4.9).
##
## Design notes:
## - The DB lives in user:// because res:// is READ-ONLY inside an exported APK.
## - Game content (levels/scenes/tips) is seeded from res://data/content.json
##   into SQLite. Bump "content_version" in the JSON to re-seed content on the
##   next launch; player progress, settings and attempts are never touched by a re-seed.
## - Every finished level is logged in `attempts` so the pilot study can export
##   real usage data (scores, mistakes, time) for evaluation.

const DB_PATH := "user://clinicrush.db"
const CONTENT_PATH := "res://data/content.json"
const SCHEMA_VERSION := 2
const DIFFICULTIES := ["easy", "normal", "hard"]

const DEFAULT_SETTINGS := {
	"sound": "1",
	"music": "1",
	"vibration": "1",
	"language": "en",
}

const ACHIEVEMENTS := [
	["first_aid_rookie", "First Responder", "Complete your first level."],
	["perfect", "Textbook Response", "Earn 3 stars on any level."],
	["no_mistakes", "Steady Hands", "Finish a level with zero mistakes."],
	["hard_clear", "Under Pressure", "Complete any level on Hard."],
	["close_call", "Close Call", "Clear a level with 2 strikes."],
	["all_easy", "First Aider", "Complete every level on Easy."],
	["all_hard", "First Aid Master", "Complete every level on Hard."],
	["cpr_hero", "Rhythm Saves Lives", "Earn 3 stars on Hands-Only CPR."],
]

var db: SQLite
var _ready_ok := false
var _is_open := false
var last_ok := true          ## result of the most recent q() call
var last_error := ""         ## shown on the main menu if the DB could not start


func _ready() -> void:
	open()


func open(path: String = DB_PATH) -> bool:
	close()
	db = SQLite.new()
	db.path = path
	db.foreign_keys = true
	db.verbosity_level = SQLite.QUIET
	if not db.open_db():
		last_error = "Could not open save file: %s" % db.error_message
		push_error("[Database] " + last_error)
		_ready_ok = false
		return false
	_is_open = true
	_create_schema()
	_migrate()
	_seed_settings()
	_seed_achievements()
	_ready_ok = _seed_content()
	if _ready_ok:
		last_error = ""
	return _ready_ok


func is_ok() -> bool:
	return _ready_ok


func close() -> void:
	if db != null and _is_open:
		db.close_db()
	_is_open = false


func _exit_tree() -> void:
	close()


# ---------------------------------------------------------------- low level

## Runs SQL (with optional ? bindings) and returns rows as an Array of Dictionaries.
func q(sql: String, binds: Array = []) -> Array:
	var ok: bool = db.query_with_bindings(sql, binds) if binds.size() > 0 else db.query(sql)
	last_ok = ok
	if not ok:
		push_error("[Database] %s\nSQL: %s" % [db.error_message, sql])
		return []
	return db.query_result.duplicate(true)


func q_one(sql: String, binds: Array = []) -> Dictionary:
	var rows := q(sql, binds)
	return rows[0] if rows.size() > 0 else {}


func _create_schema() -> void:
	var stmts := [
		"""CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)""",
		"""CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)""",
		"""CREATE TABLE IF NOT EXISTS progress (
			level_id INTEGER, difficulty TEXT, completed INTEGER DEFAULT 0,
			best_score INTEGER DEFAULT 0, best_stars INTEGER DEFAULT 0, attempts INTEGER DEFAULT 0,
			PRIMARY KEY(level_id, difficulty))""",
		"""CREATE TABLE IF NOT EXISTS attempts (
			id INTEGER PRIMARY KEY AUTOINCREMENT, level_id INTEGER, difficulty TEXT,
			score INTEGER, max_score INTEGER, stars INTEGER, correct INTEGER, incorrect INTEGER,
			duration_sec REAL, created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			failed INTEGER DEFAULT 0, strikes INTEGER DEFAULT 0)""",
		"""CREATE TABLE IF NOT EXISTS achievements (
			id TEXT PRIMARY KEY, title TEXT, description TEXT, unlocked_at TEXT)""",
	]
	for st: String in stmts:
		q(st)
	_create_content_tables()


## Content tables are rebuilt from content.json, so they can be dropped freely.
func _create_content_tables() -> void:
	for st: String in [
		"""CREATE TABLE IF NOT EXISTS levels (
			id INTEGER PRIMARY KEY, code TEXT UNIQUE, title TEXT, category TEXT, icon TEXT,
			sort_order INTEGER, scenario TEXT, summary TEXT)""",
		"""CREATE TABLE IF NOT EXISTS scenes (
			id INTEGER PRIMARY KEY AUTOINCREMENT, level_id INTEGER, sort_order INTEGER,
			title TEXT, situation TEXT, prompt TEXT, choices_json TEXT, actions_json TEXT, time_limit REAL,
			FOREIGN KEY(level_id) REFERENCES levels(id) ON DELETE CASCADE)""",
		"""CREATE TABLE IF NOT EXISTS tips (
			id INTEGER PRIMARY KEY AUTOINCREMENT, level_id INTEGER, sort_order INTEGER, text TEXT,
			FOREIGN KEY(level_id) REFERENCES levels(id) ON DELETE CASCADE)""",
	]:
		q(st)


## Upgrades older save files in place. Player progress/attempts/achievements are kept.
func _migrate() -> void:
	var v := int(get_meta_value("schema_version", "0"))
	if v >= SCHEMA_VERSION:
		return
	q("BEGIN TRANSACTION")
	# v1 -> v2: content moved from questions/steps to scenes; levels gained `icon`.
	for t: String in ["questions", "steps", "tips", "scenes", "levels"]:
		q("DROP TABLE IF EXISTS %s" % t)
	_create_content_tables()
	var cols := q("PRAGMA table_info(attempts)").map(func(r: Dictionary) -> String: return str(r["name"]))
	if not "failed" in cols:
		q("ALTER TABLE attempts ADD COLUMN failed INTEGER DEFAULT 0")
	if not "strikes" in cols:
		q("ALTER TABLE attempts ADD COLUMN strikes INTEGER DEFAULT 0")
	set_meta_value("content_version", "0")   # force a re-seed into the new tables
	set_meta_value("schema_version", str(SCHEMA_VERSION))
	q("COMMIT")


func _seed_settings() -> void:
	for k: String in DEFAULT_SETTINGS:
		q("INSERT OR IGNORE INTO settings(key, value) VALUES(?, ?)", [k, DEFAULT_SETTINGS[k]])


func _seed_achievements() -> void:
	for a: Array in ACHIEVEMENTS:
		q("INSERT OR IGNORE INTO achievements(id, title, description, unlocked_at) VALUES(?, ?, ?, NULL)", a)
		q("UPDATE achievements SET title = ?, description = ? WHERE id = ?", [a[1], a[2], a[0]])


## Loads data/content.json into SQLite when its content_version is newer.
## Runs in one transaction: any failure rolls back, leaving the old content intact.
func _seed_content(force: bool = false) -> bool:
	var f := FileAccess.open(CONTENT_PATH, FileAccess.READ)
	if f == null:
		last_error = "Missing %s" % CONTENT_PATH
		push_error("[Database] " + last_error)
		return int(q_one("SELECT COUNT(*) AS n FROM levels").get("n", 0)) > 0
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("levels")) != TYPE_ARRAY:
		last_error = "content.json is not valid JSON"
		push_error("[Database] " + last_error)
		return int(q_one("SELECT COUNT(*) AS n FROM levels").get("n", 0)) > 0
	var version := int(data.get("content_version", 1))
	var current := int(get_meta_value("content_version", "0"))
	if not force and current >= version:
		return true
	q("BEGIN TRANSACTION")
	var ok := true
	for t: String in ["tips", "scenes", "levels"]:
		q("DELETE FROM %s" % t)
		ok = ok and last_ok
	var order := 0
	for lv: Dictionary in data["levels"]:
		order += 1
		var level_id := int(lv["id"])
		q("INSERT INTO levels(id, code, title, category, icon, sort_order, scenario, summary) VALUES(?,?,?,?,?,?,?,?)",
			[level_id, lv["code"], lv["title"], lv.get("category", ""), lv.get("icon", ""), order, lv["scenario"], lv.get("summary", "")])
		ok = ok and last_ok
		var si := 0
		for sd: Dictionary in lv.get("scenes", []):
			si += 1
			q("INSERT INTO scenes(level_id, sort_order, title, situation, prompt, choices_json, actions_json, time_limit) VALUES(?,?,?,?,?,?,?,?)",
				[level_id, si, sd.get("title", "Scene %d" % si), sd.get("situation", ""), sd["prompt"],
				JSON.stringify(sd["choices"]), JSON.stringify(sd.get("actions", [])), float(sd.get("time", 20))])
			ok = ok and last_ok
		var ti := 0
		for t: String in lv.get("tips", []):
			ti += 1
			q("INSERT INTO tips(level_id, sort_order, text) VALUES(?,?,?)", [level_id, ti, t])
			ok = ok and last_ok
	if not ok:
		q("ROLLBACK")
		last_error = "Could not load game content (see log)."
		return false
	set_meta_value("content_version", str(version))
	q("COMMIT")
	return true


# ---------------------------------------------------------------- meta / settings

func get_meta_value(key: String, default: String = "") -> String:
	var r := q_one("SELECT value FROM meta WHERE key = ?", [key])
	return str(r["value"]) if r.has("value") and r["value"] != null else default


func set_meta_value(key: String, value: String) -> void:
	q("INSERT OR REPLACE INTO meta(key, value) VALUES(?, ?)", [key, value])


func get_setting(key: String) -> String:
	var r := q_one("SELECT value FROM settings WHERE key = ?", [key])
	return str(r["value"]) if r.has("value") else str(DEFAULT_SETTINGS.get(key, ""))


func get_setting_bool(key: String) -> bool:
	return get_setting(key) == "1"


func set_setting(key: String, value: Variant) -> void:
	var v := ("1" if value else "0") if typeof(value) == TYPE_BOOL else str(value)
	q("INSERT OR REPLACE INTO settings(key, value) VALUES(?, ?)", [key, v])


# ---------------------------------------------------------------- content

func get_levels() -> Array:
	var rows := q("SELECT * FROM levels ORDER BY sort_order")
	for r: Dictionary in rows:
		r["unlocked"] = is_level_unlocked(int(r["id"]))
		for d: String in DIFFICULTIES:
			r[d] = get_progress(int(r["id"]), d)
	return rows


func get_level(level_id: int) -> Dictionary:
	return q_one("SELECT * FROM levels WHERE id = ?", [level_id])


func get_next_level_id(level_id: int) -> int:
	var cur := get_level(level_id)
	if cur.is_empty():
		return -1
	var r := q_one("SELECT id FROM levels WHERE sort_order > ? ORDER BY sort_order LIMIT 1", [int(cur["sort_order"])])
	return int(r["id"]) if r.has("id") else -1


## Scenes with parsed `choices` and `actions` (gesture step definitions).
func get_scenes(level_id: int) -> Array:
	var rows := q("SELECT * FROM scenes WHERE level_id = ? ORDER BY sort_order", [level_id])
	for r: Dictionary in rows:
		var c: Variant = JSON.parse_string(str(r["choices_json"]))
		r["choices"] = c if typeof(c) == TYPE_ARRAY else []
		var acts: Variant = JSON.parse_string(str(r["actions_json"]))
		var clean: Array = []
		if typeof(acts) == TYPE_ARRAY:
			for a: Variant in acts:
				if typeof(a) == TYPE_DICTIONARY:
					var ad: Dictionary = a
					if typeof(ad.get("params")) != TYPE_DICTIONARY:
						ad["params"] = {}
					clean.append(ad)
		r["actions"] = clean
	return rows


func get_tips(level_id: int) -> Array:
	return q("SELECT text FROM tips WHERE level_id = ? ORDER BY sort_order", [level_id]).map(func(r: Dictionary) -> String: return r["text"])


# ---------------------------------------------------------------- progress

func get_progress(level_id: int, difficulty: String) -> Dictionary:
	var r := q_one("SELECT * FROM progress WHERE level_id = ? AND difficulty = ?", [level_id, difficulty])
	if r.is_empty():
		return {"level_id": level_id, "difficulty": difficulty, "completed": 0, "best_score": 0, "best_stars": 0, "attempts": 0}
	return r


## Level 1 is always open; every other level opens once the previous one is cleared (any difficulty).
func is_level_unlocked(level_id: int) -> bool:
	var cur := get_level(level_id)
	if cur.is_empty():
		return false
	var prev := q_one("SELECT id FROM levels WHERE sort_order < ? ORDER BY sort_order DESC LIMIT 1", [int(cur["sort_order"])])
	if prev.is_empty():
		return true
	var done := q_one("SELECT 1 AS ok FROM progress WHERE level_id = ? AND completed = 1", [int(prev["id"])])
	return not done.is_empty()


## Easy opens with the level; Normal after Easy is cleared; Hard after Normal is cleared.
func is_difficulty_unlocked(level_id: int, difficulty: String) -> bool:
	match difficulty:
		"easy":
			return is_level_unlocked(level_id)
		"normal":
			return is_level_unlocked(level_id) and int(get_progress(level_id, "easy")["completed"]) == 1
		"hard":
			return is_level_unlocked(level_id) and int(get_progress(level_id, "normal")["completed"]) == 1
	return false


## The difficulty that becomes available after clearing `difficulty`, or "".
func next_difficulty(difficulty: String) -> String:
	var i := DIFFICULTIES.find(difficulty)
	return DIFFICULTIES[i + 1] if i >= 0 and i + 1 < DIFFICULTIES.size() else ""


## Saves a finished (or failed) run.
## r: {score, max_score, stars, correct, incorrect, duration, failed, strikes}
## Returns {new_best, achievements: [titles], next_unlocked, difficulty_unlocked: "" | "normal" | "hard"}.
func record_attempt(level_id: int, difficulty: String, r: Dictionary) -> Dictionary:
	var failed := bool(r.get("failed", false))
	var stars := 0 if failed else clampi(int(r["stars"]), 0, 3)
	var score := maxi(0, int(r["score"]))
	var cleared := stars >= 1
	var next_id := get_next_level_id(level_id)
	var was_next_unlocked := next_id != -1 and is_level_unlocked(next_id)
	var nd := next_difficulty(difficulty)
	var was_diff_unlocked := nd == "" or is_difficulty_unlocked(level_id, nd)
	var prev := get_progress(level_id, difficulty)
	var new_best := cleared and score > int(prev["best_score"])
	q("INSERT INTO attempts(level_id, difficulty, score, max_score, stars, correct, incorrect, duration_sec, failed, strikes) VALUES(?,?,?,?,?,?,?,?,?,?)",
		[level_id, difficulty, score, int(r["max_score"]), stars, int(r["correct"]), int(r["incorrect"]),
		float(r["duration"]), 1 if failed else 0, int(r.get("strikes", 0))])
	q("""INSERT INTO progress(level_id, difficulty, completed, best_score, best_stars, attempts) VALUES(?,?,?,?,?,1)
		ON CONFLICT(level_id, difficulty) DO UPDATE SET
		completed = MAX(completed, excluded.completed),
		best_score = MAX(best_score, excluded.best_score),
		best_stars = MAX(best_stars, excluded.best_stars),
		attempts = attempts + 1""",
		[level_id, difficulty, 1 if cleared else 0, score if cleared else 0, stars])
	var unlocked: Array = [] if not cleared else _check_achievements(level_id, difficulty, r)
	return {
		"new_best": new_best,
		"achievements": unlocked,
		"next_unlocked": next_id != -1 and not was_next_unlocked and is_level_unlocked(next_id),
		"difficulty_unlocked": nd if (nd != "" and not was_diff_unlocked and is_difficulty_unlocked(level_id, nd)) else "",
	}


func _check_achievements(level_id: int, difficulty: String, r: Dictionary) -> Array:
	var got: Array = []
	var stars := int(r["stars"])
	if stars >= 1:
		_unlock("first_aid_rookie", got)
	if stars == 3:
		_unlock("perfect", got)
	if stars >= 1 and int(r["incorrect"]) == 0:
		_unlock("no_mistakes", got)
	if stars >= 1 and difficulty == "hard":
		_unlock("hard_clear", got)
	if stars >= 1 and int(r.get("strikes", 0)) == 2:
		_unlock("close_call", got)
	var total := int(q_one("SELECT COUNT(*) AS n FROM levels")["n"])
	if total > 0 and _cleared_count("easy") >= total:
		_unlock("all_easy", got)
	if total > 0 and _cleared_count("hard") >= total:
		_unlock("all_hard", got)
	var lv := get_level(level_id)
	if lv.get("code", "") == "cpr" and stars == 3:
		_unlock("cpr_hero", got)
	return got


func _cleared_count(difficulty: String) -> int:
	return int(q_one("SELECT COUNT(*) AS n FROM progress p JOIN levels l ON l.id = p.level_id WHERE p.difficulty = ? AND p.completed = 1", [difficulty])["n"])


func _unlock(id: String, got: Array) -> void:
	var row := q_one("SELECT title, unlocked_at FROM achievements WHERE id = ?", [id])
	if row.is_empty() or row["unlocked_at"] != null:
		return
	q("UPDATE achievements SET unlocked_at = CURRENT_TIMESTAMP WHERE id = ?", [id])
	got.append(row["title"])


func get_achievements() -> Array:
	return q("SELECT * FROM achievements ORDER BY rowid")


func reset_progress() -> void:
	q("DELETE FROM progress")
	q("DELETE FROM attempts")
	q("UPDATE achievements SET unlocked_at = NULL")
