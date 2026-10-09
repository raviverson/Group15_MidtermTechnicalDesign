class_name DropZone
extends Control
## Target that accepts ItemCard drops (template's _can_drop_data/_drop_data pattern).
## `on_drop` is called with (item: Dictionary, card: ItemCard, zone: DropZone).

var caption: String = ""
var zone_data: Dictionary = {}
var on_drop: Callable
var accepting: bool = true
var draw_frame: bool = true
var highlight: bool = false
var good: bool = false
var bad: bool = false
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var ok: bool = accepting and typeof(data) == TYPE_DICTIONARY and data.get("kind", "") == "item"
	if highlight != ok:
		highlight = ok
		queue_redraw()
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	highlight = false
	queue_redraw()
	if on_drop.is_valid():
		on_drop.call(data["item"], data["card"], self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		if highlight:
			highlight = false
			queue_redraw()


func _process(delta: float) -> void:
	if draw_frame and not good and not bad:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if not draw_frame:
		return
	var col := UI.C_GOOD if good else (UI.C_RED if bad else (UI.C_ORANGE if highlight else UI.C_BLUE))
	var glow := 0.12 + (0.08 * (0.5 + 0.5 * sin(_t * 4.0)) if not good and not bad else 0.0)
	var sb := UI.style(Color(col, glow + (0.12 if highlight else 0.0)), 18, col, 4)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	# target rings
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.28
	draw_arc(c, r, 0, TAU, 40, Color(col, 0.35), 3.0, true)
	draw_arc(c, r * 0.55, 0, TAU, 32, Color(col, 0.35), 3.0, true)
	var font := UI.font_bold()
	var fs := 22
	var w := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2((size.x - w) / 2.0, size.y / 2.0 + 8), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col.darkened(0.35))
