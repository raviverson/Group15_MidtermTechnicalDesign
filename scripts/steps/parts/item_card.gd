class_name ItemCard
extends Button
## Draggable first-aid item tile. Same pattern as the template's drag_drop_script.gd:
## _get_drag_data() packages the item and sets a preview that follows the finger.
## A wrong item, once tried, turns red and is locked: its consequence was already
## shown, so the same mistake can't burn a second strike by accident.

var item: Dictionary = {}:
	set(v):
		item = v
		text = str(v.get("label", "?"))
var used: bool = false
var tried_wrong: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(0, 66)
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_theme_font_size_override("font_size", 18)
	add_theme_font_override("font", UI.font_bold())
	_restyle(UI.C_CREAM, UI.C_TEXT)
	pressed.connect(func() -> void: Game.sfx("tap"))
	FX.hover_bounce(self, 1.04)


func _restyle(c: Color, font_col: Color) -> void:
	for k: String in ["normal", "hover", "pressed", "disabled"]:
		var bg := c.lightened(0.12) if k == "hover" else c
		var sb := UI.style(bg, 12, c.darkened(0.4) if c != UI.C_CREAM else UI.C_BROWN, 2, 10)
		sb.border_width_bottom = 5
		add_theme_stylebox_override(k, sb)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(key, font_col)


func mark_used() -> void:
	used = true
	disabled = true
	text = "%s  - used" % item.get("label", "")
	_restyle(UI.C_GOOD, Color.WHITE)


func mark_wrong() -> void:
	tried_wrong = true
	disabled = true
	_restyle(UI.C_RED, Color.WHITE)


func flash_wrong() -> void:
	_restyle(Color("#f6c9c9"), UI.C_TEXT)
	if not is_inside_tree():
		return
	FX.shake(self, 8.0, 0.3)
	var tw := create_tween()   # owned by this node: dies with it, never fires on a freed card
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void:
		if not used and not tried_wrong:
			_restyle(UI.C_CREAM, UI.C_TEXT))


func _get_drag_data(_at_position: Vector2) -> Variant:
	if used or tried_wrong:
		return null
	var preview_btn := Button.new()
	preview_btn.text = text
	preview_btn.size = Vector2(size.x, 66)
	preview_btn.add_theme_font_override("font", UI.font_bold())
	preview_btn.add_theme_stylebox_override("normal", UI.style(Color("#fff7d6"), 12, UI.C_ORANGE, 3))
	preview_btn.add_theme_color_override("font_color", UI.C_TEXT)
	preview_btn.modulate.a = 0.92
	preview_btn.rotation = -0.06
	var preview := Control.new()
	preview.add_child(preview_btn)
	preview_btn.position = -0.5 * preview_btn.size
	set_drag_preview(preview)
	return {"kind": "item", "item": item, "card": self}
