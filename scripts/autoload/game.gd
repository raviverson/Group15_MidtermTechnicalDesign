extends Node
## Autoload "Game" — session state, difficulty rules, scene routing (with fade
## transitions), global theme, feedback hooks.

## Difficulty modifiers. Strikes are always 3 (core rule); everything else scales.
##   time_mult      x every decision/action timer
##   hints          "always" | "after_mistake" | "never"
##   penalty        points lost per technique error / in-action wrong pick
##   rhythm_slack   subtracted from CPR pass ratio (more forgiving)
##   coverage_delta added to the wipe coverage needed
##   hold_mult      x seconds a hold must last
const DIFFICULTY := {
	"easy": {"label": "Easy", "color": "good", "face": "happy",
		"time_mult": 1.5, "hints": "always", "penalty": 2,
		"rhythm_slack": 0.15, "coverage_delta": -0.05, "hold_mult": 0.8,
		"bullets": ["More time", "Hints always on", "Lower penalty"]},
	"normal": {"label": "Normal", "color": "orange", "face": "neutral",
		"time_mult": 1.2, "hints": "after_mistake", "penalty": 3,
		"rhythm_slack": 0.05, "coverage_delta": 0.0, "hold_mult": 1.0,
		"bullets": ["Standard time", "Hints after a mistake", "Medium penalty"]},
	"hard": {"label": "Hard", "color": "red", "face": "angry",
		"time_mult": 1.0, "hints": "never", "penalty": 5,
		"rhythm_slack": 0.0, "coverage_delta": 0.05, "hold_mult": 1.2,
		"bullets": ["Less time", "No hints", "Higher penalty"]},
}
const DIFFICULTY_ORDER := ["easy", "normal", "hard"]

var current_level_id: int = 1
var current_difficulty: String = "easy"
var last_result: Dictionary = {}
var tips_level_id: int = -1   ## -1 = open tips on first level
var test_mode: bool = false   ## set by tests to block scene changes

var _fade_layer: CanvasLayer
var _fade: ColorRect
var _transitioning: bool = false


func _ready() -> void:
	get_tree().set_auto_accept_quit(true)
	get_tree().set_quit_on_go_back(false)   # Android back button handled below
	get_tree().root.theme = UI.build_theme()
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(UI.C_PRIMARY_DARK, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func diff() -> Dictionary:
	return DIFFICULTY.get(current_difficulty, DIFFICULTY["easy"])


func diff_of(key: String) -> Dictionary:
	return DIFFICULTY.get(key, DIFFICULTY["easy"])


## Scene change with a short fade. Re-entrant calls during a transition are ignored,
## so double-tapping a menu button can never load two scenes.
func goto(scene: String) -> void:
	if test_mode or _transitioning:
		return
	_transitioning = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP   # swallow taps while fading
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.16)
	tw.tween_callback(func() -> void:
		get_tree().change_scene_to_file("res://scenes/%s.tscn" % scene))
	tw.tween_interval(0.05)
	tw.tween_property(_fade, "color:a", 0.0, 0.22)
	tw.tween_callback(func() -> void:
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_transitioning = false)


func is_transitioning() -> bool:
	return _transitioning


func vibrate(ms: int = 80) -> void:
	if Database.get_setting_bool("vibration"):
		Input.vibrate_handheld(ms)


## Audio hook — no assets yet. Drop .ogg/.wav files in res://audio/sfx/<name>.* later.
func sfx(sfx_name: String) -> void:
	if not Database.get_setting_bool("sound"):
		return
	for ext: String in [".ogg", ".wav"]:
		var path := "res://audio/sfx/%s%s" % [sfx_name, ext]
		if ResourceLoader.exists(path):
			var player := AudioStreamPlayer.new()
			player.stream = load(path)
			add_child(player)
			player.finished.connect(player.queue_free)
			player.play()
			return


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()


## Esc on desktop behaves like the Android back button (handy when testing on PC).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back()


func back() -> void:
	if _transitioning:
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("on_back"):
		scene.call("on_back")
	else:
		get_tree().quit()
