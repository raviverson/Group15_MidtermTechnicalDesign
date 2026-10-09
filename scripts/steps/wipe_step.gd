class_name WipeStep
extends StepBase
## Wipe/scrub mechanic: drag back-and-forth across the area until clean.
## Optionally the player must first drop the right tool (e.g. clean water) on it.
## params:
##   body_label, area_label
##   axis: "horizontal" | "vertical" | "any"   required stroke direction
##   coverage: float (0..1)                     fraction that must be cleared
##   tools: [{label, correct, effect}]          optional tool tray (wrong tool = strike)
##   dirt_label: String                         e.g. "dirt", "soap", "venom"

const GRID := Vector2i(18, 10)
const BRUSH := 46.0

var _cells: PackedByteArray
var _cleared: int = 0
var _area: DropZone
var _tool_ready: bool = true
var _tool_name: String = ""
var _wrong_dist: float = 0.0
var _last_sign: int = 0
var _reversals: int = 0
var _cursor := Vector2(-999, -999)
var _rng := RandomNumberGenerator.new()


func _build() -> void:
	_rng.seed = 7
	_cells.resize(GRID.x * GRID.y)
	_cells.fill(1)
	var tools: Array = p("tools", [])
	_area = DropZone.new()
	_area.caption = ""
	_area.draw_frame = false
	_area.on_drop = _on_tool_drop
	add_child(_area)
	if tools.size() > 0:
		_tool_ready = false
		build_tray(tools)
		_area.anchor_right = 0.70
	else:
		_area.accepting = false
		_area.anchor_right = 0.92
	_area.anchor_left = 0.08
	_area.anchor_top = 0.22
	_area.anchor_bottom = 0.88
	_area.gui_input.connect(_on_area_input)
	_area.draw.connect(_draw_area)


func _draw() -> void:
	var right := 0.74 if not p("tools", []).is_empty() else 0.96
	draw_body_part(Rect2(size * Vector2(0.04, 0.04), size * Vector2(right - 0.04, 0.92)), str(p("body_label", "Patient")))


func _on_tool_drop(item: Dictionary, card: ItemCard, _zone: DropZone) -> void:
	if done or _tool_ready:
		return
	if item.get("correct", false):
		if card != null:
			card.mark_used()
		_tool_ready = true
		_tool_name = str(item.get("label", ""))
		info.emit("Good! Now wipe %s to clean." % _axis_words())
		_area.queue_redraw()
	else:
		if card != null:
			card.flash_wrong()
			card.mark_wrong()
		fail(str(item.get("effect", item.get("feedback", "That is not the right item."))), bool(item.get("strike", true)), str(item.get("label", "")))


func _axis_words() -> String:
	match str(p("axis", "any")):
		"horizontal": return "left and right"
		"vertical": return "up and down"
	return "back and forth"


func _on_area_input(ev: InputEvent) -> void:
	if done:
		return
	if ev is InputEventMouseButton and ev.pressed and not _tool_ready:
		info.emit("First drag the correct item from the tray onto the wound.")
		return
	if ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) and _tool_ready:
		var rel: Vector2 = ev.relative
		_cursor = ev.position
		var axis := str(p("axis", "any"))
		var along := rel.x if axis == "horizontal" else rel.y
		var across := rel.y if axis == "horizontal" else rel.x
		if axis != "any" and abs(across) > abs(along) * 1.3 and rel.length() > 3.0:
			_wrong_dist += rel.length()
			if _wrong_dist > 420.0:
				_wrong_dist = 0.0
				fail("Wipe %s, gently and in one direction at a time." % _axis_words(), false)
			_area.queue_redraw()
			return
		var s: int = int(signf(along if axis != "any" else rel.x + rel.y))
		if s != 0 and s != _last_sign:
			_reversals += 1
			_last_sign = s
		_scrub(ev.position)
	elif ev is InputEventMouseButton and not ev.pressed:
		_cursor = Vector2(-999, -999)
		_area.queue_redraw()


## Fraction of the area that must be cleaned (content value + difficulty modifier).
func required_coverage() -> float:
	return clampf(float(p("coverage", 0.85)) + mod("coverage_delta", 0.0), 0.3, 0.97)


func cancel_input() -> void:
	_cursor = Vector2(-999, -999)
	if _area != null:
		_area.queue_redraw()


func _scrub(pos: Vector2) -> void:
	var cell := _area.size / Vector2(GRID)
	var changed := false
	for y: int in GRID.y:
		for x: int in GRID.x:
			var i := y * GRID.x + x
			if _cells[i] == 0:
				continue
			var c := (Vector2(x, y) + Vector2(0.5, 0.5)) * cell
			if c.distance_to(pos) <= BRUSH:
				_cells[i] = 0
				_cleared += 1
				changed = true
	if changed:
		var pct := float(_cleared) / float(_cells.size())
		var target := required_coverage()
		progress_changed.emit(clampf(pct / target, 0.0, 1.0))
		if pct >= target:
			complete()
	_area.queue_redraw()


func _draw_area() -> void:
	var a := _area
	var r := Rect2(Vector2.ZERO, a.size)
	a.draw_rect(r.grow(-a.size.x * 0.25), Color(UI.C_WOUND, 0.55))
	var cell := a.size / Vector2(GRID)
	var dirt := UI.C_DIRT
	for y: int in GRID.y:
		for x: int in GRID.x:
			if _cells[y * GRID.x + x] == 1:
				var c := (Vector2(x, y) + Vector2(0.5, 0.5)) * cell
				a.draw_circle(c, min(cell.x, cell.y) * 0.42, Color(dirt, 0.85))
	a.draw_rect(r, UI.C_ORANGE if not _tool_ready else UI.C_BLUE, false, 3.0)
	if not _tool_ready:
		var font := UI.font_bold()
		var msg := "Drop the right item here"
		var w := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var pill := Rect2(a.size / 2.0 - Vector2(w / 2.0 + 18, 22), Vector2(w + 36, 44))
		a.draw_style_box(UI.style(Color(UI.C_ORANGE, 0.95), 22, UI.C_ORANGE.darkened(0.3), 2), pill)
		a.draw_string(font, pill.position + Vector2(18, 30), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	elif _cursor.x > -900:
		a.draw_circle(_cursor, BRUSH, Color(1, 1, 1, 0.6))
		a.draw_arc(_cursor, BRUSH, 0, TAU, 32, UI.C_BLUE, 2.0)
	if _tool_ready and hints_enabled and _cleared == 0:
		var mid := a.size / 2.0
		var axis := str(p("axis", "any"))
		var d := Vector2(140, 0) if axis != "vertical" else Vector2(0, 110)
		a.draw_line(mid - d, mid + d, Color(UI.C_BLUE, 0.6), 6.0)
		for s: int in [-1, 1]:
			var tip := mid + d * s
			var dir := d.normalized() * s
			var n := Vector2(-dir.y, dir.x)
			a.draw_colored_polygon(PackedVector2Array([tip + dir * 16, tip - dir * 8 + n * 14, tip - dir * 8 - n * 14]), Color(UI.C_BLUE, 0.6))
