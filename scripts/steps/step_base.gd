class_name StepBase
extends Control
## Base class for every first-aid action minigame (the "perform the procedure" part).
## Created by the Scenario screen from SQLite params; reports back through signals.
## Steps never touch scoring/strikes directly - the StageRunner decides.
##
## mistake(message, strike, chosen):
##   strike = true  -> the player picked a WRONG PROCEDURE (wrong item, wrong spot,
##                     dangerous action). Costs one of the 3 strikes; its effect is shown.
##   strike = false -> a TECHNIQUE slip (wrong wipe direction, let go early, off rhythm).
##                     Costs points only.

signal completed
signal mistake(message: String, strike: bool, chosen: String)
signal progress_changed(value: float)   ## 0..1, drives the progress bar
@warning_ignore("unused_signal")
signal info(message: String)            ## neutral guidance (not a mistake), emitted by subclasses

var params: Dictionary = {}
var mods: Dictionary = {}       ## difficulty modifiers (see Game.DIFFICULTY)
var hints_enabled: bool = true
var done: bool = false
var difficulty: String = "easy"


func setup(step_params: Dictionary, hints: bool, diff_key: String, diff_mods: Dictionary = {}) -> void:
	params = step_params
	hints_enabled = hints
	difficulty = diff_key
	mods = diff_mods if not diff_mods.is_empty() else Game.diff_of(diff_key)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## Override: create child nodes.
func _build() -> void:
	pass


## Turn hints on mid-step (Normal difficulty: hints appear after a mistake).
func set_hints(on: bool) -> void:
	hints_enabled = on
	queue_redraw()


func complete() -> void:
	if done:
		return
	done = true
	cancel_input()
	progress_changed.emit(1.0)
	Game.sfx("correct")
	completed.emit()


func fail(msg: String, strike: bool = false, chosen: String = "") -> void:
	if done:
		return
	Game.sfx("wrong")
	Game.vibrate(120 if strike else 60)
	mistake.emit(msg, strike, chosen)


## Called on timeout / stage end — freeze input.
func stop() -> void:
	cancel_input()
	done = true


## Override: forget any finger currently held down (pause, app switch, focus loss,
## consequence card) WITHOUT counting it as a mistake.
func cancel_input() -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_VISIBILITY_CHANGED:
		cancel_input()


func p(key: String, default: Variant = null) -> Variant:
	return params.get(key, default)


func mod(key: String, default: float) -> float:
	return float(mods.get(key, default))


# ---------- shared placeholder drawing ----------

## Draws the patient's body part as a soft skin shape on a cream "stage" with a
## caption tag. Replace with art later.
func draw_body_part(rect: Rect2, caption: String) -> void:
	var stage := UI.style(Color(UI.C_CREAM, 0.92), 22, UI.C_BROWN, 3)
	stage.shadow_color = Color(0, 0, 0, 0.18)
	stage.shadow_size = 6
	draw_style_box(stage, rect)
	var skin := rect.grow(-18)
	skin.position.y += 26
	skin.size.y -= 26
	var sb := UI.style(UI.C_SKIN, 60, UI.C_SKIN_DARK, 4)
	draw_style_box(sb, skin)
	# soft highlight for a bit of volume
	draw_style_box(UI.style(Color(1, 1, 1, 0.18), 50), Rect2(skin.position + Vector2(20, 12), Vector2(skin.size.x * 0.5, skin.size.y * 0.25)))
	# caption tag
	var font := UI.font_bold()
	var fs := 18
	var w := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 28
	var tag := Rect2(Vector2(rect.position.x + 14, rect.position.y + 8), Vector2(w, 30))
	draw_style_box(UI.style(UI.C_PRIMARY_DARK, 8), tag)
	draw_string(font, tag.position + Vector2(14, 21), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func draw_text_centered(text: String, center: Vector2, fs: int = 22, color: Color = UI.C_TEXT) -> void:
	var font := UI.font_bold()
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, center + Vector2(-sz.x / 2.0, sz.y / 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func draw_arrow(from: Vector2, to: Vector2, color: Color, width: float = 8.0) -> void:
	draw_line(from, to, color, width, true)
	var dir := (to - from).normalized()
	var n := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([to + dir * 18, to - dir * 10 + n * 18, to - dir * 10 - n * 18]), color)


## Builds the item tray used by drag steps (cards follow the drag-and-drop template).
func build_tray(items: Array, on_side_right: bool = true) -> VBoxContainer:
	var holder := UI.panel(Color(UI.C_CREAM, 0.95), 16, 12)
	add_child(holder)
	holder.anchor_left = 0.775 if on_side_right else 0.02
	holder.anchor_right = 0.985 if on_side_right else 0.225
	holder.anchor_top = 0.02
	holder.anchor_bottom = 0.98
	var tray := UI.vbox(10)
	holder.add_child(tray)
	tray.add_child(UI.ribbon("ITEMS", UI.C_PRIMARY_DARK, 16))
	var shuffled := items.duplicate()
	shuffled.shuffle()
	for it: Dictionary in shuffled:
		var card := ItemCard.new()
		card.item = it
		tray.add_child(card)
	return tray
