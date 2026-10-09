class_name Backdrop
extends Control
## Painted placeholder environments matching the storyboard settings:
##   "park"   - outdoor schoolyard/park (scenario frames 04-09)
##   "clinic" - clinic interior (main menu, frame 01)
##   "forest" - darker forest green (results / overlays)
## Static drawing (redrawn only on resize) + a few ambient motes.

var kind: String = "park":
	set(v):
		kind = v
		queue_redraw()
var ambient: bool = true
var _motes: CPUParticles2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	queue_redraw()
	if not ambient:
		return
	if _motes == null:
		_motes = FX.ambient(self, Rect2(Vector2.ZERO, size), Color(1, 1, 0.9, 0.35), 16)
	else:
		_motes.position = size / 2.0
		_motes.emission_rect_extents = size / 2.0


func _vgrad(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _tree(base: Vector2, h: float, col: Color) -> void:
	draw_rect(Rect2(base + Vector2(-h * 0.06, -h * 0.35), Vector2(h * 0.12, h * 0.35)), Color("#6b4a2e"))
	draw_circle(base + Vector2(0, -h * 0.62), h * 0.3, col)
	draw_circle(base + Vector2(-h * 0.2, -h * 0.45), h * 0.22, col.darkened(0.08))
	draw_circle(base + Vector2(h * 0.2, -h * 0.47), h * 0.22, col.lightened(0.05))


func _draw() -> void:
	var w := size.x
	var h := size.y
	match kind:
		"clinic":
			_vgrad(Rect2(0, 0, w, h * 0.72), Color("#cfe3d0"), Color("#b6d1b9"))
			# wainscot + floor
			draw_rect(Rect2(0, h * 0.58, w, h * 0.14), Color("#8fb59a"))
			draw_rect(Rect2(0, h * 0.58, w, 6), Color("#6f9a7c"))
			_vgrad(Rect2(0, h * 0.72, w, h * 0.28), Color("#c9a77a"), Color("#a9845a"))
			for i: int in 12:
				draw_line(Vector2(i * w / 11.0, h * 0.72), Vector2(i * w / 11.0 - 80, h), Color(0, 0, 0, 0.06), 2)
			# window with sky
			var win := Rect2(w * 0.06, h * 0.12, w * 0.22, h * 0.32)
			_vgrad(win, Color("#9fd3f5"), Color("#d8f0ff"))
			draw_circle(win.position + Vector2(win.size.x * 0.3, win.size.y * 0.75), win.size.x * 0.25, Color("#7cbf6e"))
			draw_rect(win, Color("#f4efe4"), false, 10)
			draw_line(Vector2(win.get_center().x, win.position.y), Vector2(win.get_center().x, win.end.y), Color("#f4efe4"), 6)
			# medical cross sign
			var sc := Vector2(w * 0.83, h * 0.2)
			draw_circle(sc, 46, Color.WHITE)
			draw_rect(Rect2(sc + Vector2(-12, -32), Vector2(24, 64)), UI.C_RED)
			draw_rect(Rect2(sc + Vector2(-32, -12), Vector2(64, 24)), UI.C_RED)
			# counter + plant
			draw_rect(Rect2(w * 0.68, h * 0.55, w * 0.3, h * 0.22), Color("#e9e3d3"))
			draw_rect(Rect2(w * 0.68, h * 0.55, w * 0.3, 10), Color("#cfc6b0"))
			draw_rect(Rect2(w * 0.03, h * 0.62, 50, 70), Color("#b5643c"))
			for d: Vector2 in [Vector2(10, -10), Vector2(40, -20), Vector2(25, -40), Vector2(0, -35), Vector2(50, -45)]:
				draw_circle(Vector2(w * 0.03, h * 0.62) + d, 22, Color("#4f9a52"))
		"forest":
			_vgrad(Rect2(0, 0, w, h), Color("#2f6b45"), Color("#173826"))
			for i: int in 9:
				_tree(Vector2(i * w / 8.0 + 40, h * 1.02), h * 0.55, Color("#245a39"))
		_:
			# park / schoolyard
			_vgrad(Rect2(0, 0, w, h * 0.62), Color("#8fcbe8"), Color("#e4f3e7"))
			draw_circle(Vector2(w * 0.85, h * 0.14), 46, Color(1, 0.97, 0.75, 0.9))
			draw_circle(Vector2(w * 0.85, h * 0.14), 70, Color(1, 0.97, 0.75, 0.25))
			for i: int in 14:
				draw_circle(Vector2(i * w / 13.0, h * 0.6), 60 + (i % 3) * 18, Color("#7fae6f"))
			for i: int in 7:
				_tree(Vector2(i * w / 6.0 + 30 + (i % 2) * 40, h * 0.66), h * 0.42, Color("#3f8a4a"))
			_vgrad(Rect2(0, h * 0.62, w, h * 0.38), Color("#86c46a"), Color("#5c9e4b"))
			# path
			draw_colored_polygon(PackedVector2Array([Vector2(w * 0.42, h * 0.62), Vector2(w * 0.5, h * 0.62), Vector2(w * 0.7, h), Vector2(w * 0.28, h)]), Color("#d9c39a"))
