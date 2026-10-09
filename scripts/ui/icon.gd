class_name Icon
extends Control
## Simple vector icons drawn in code (storyboard legend style). Swap for textures later.
## Kinds: clock check cross heart heart_broken lock star gear trophy info medic
##        arrow_left pause kit bandage drop foot flame bee person lungs

@export var kind: String = "info":
	set(v):
		kind = v
		queue_redraw()
@export var color: Color = Color.WHITE:
	set(v):
		color = v
		queue_redraw()


func _init(p_kind: String = "info", p_color: Color = Color.WHITE, px: float = 0.0) -> void:
	kind = p_kind
	color = p_color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if px > 0.0:
		custom_minimum_size = Vector2(px, px)


## Map a 24x24 design grid into this control's rect (centered square).
func _u() -> float:
	return minf(size.x, size.y) / 24.0


func _o() -> Vector2:
	var s := minf(size.x, size.y)
	return (size - Vector2(s, s)) / 2.0


func P(x: float, y: float) -> Vector2:
	return _o() + Vector2(x, y) * _u()


func _draw() -> void:
	var u := _u()
	var w := maxf(1.5, 2.2 * u)
	var c := color
	match kind:
		"clock":
			draw_circle(P(12, 12), 10 * u, c, false, w, true)
			draw_line(P(12, 12), P(12, 6), c, w, true)
			draw_line(P(12, 12), P(16, 14), c, w, true)
		"check":
			draw_polyline(PackedVector2Array([P(4, 12.5), P(10, 18), P(20, 6)]), c, w * 1.4, true)
		"cross":
			draw_line(P(5, 5), P(19, 19), c, w * 1.4, true)
			draw_line(P(19, 5), P(5, 19), c, w * 1.4, true)
		"heart", "heart_broken":
			var pts := _heart_points()
			draw_colored_polygon(pts, c)
			draw_circle(P(8.2, 8.5), 1.6 * u, Color(1, 1, 1, 0.45))
			if kind == "heart_broken":
				draw_polyline(PackedVector2Array([P(12, 6), P(10, 10.5), P(13.5, 13), P(11, 20)]), Color(0.15, 0.1, 0.1, 0.9), w, true)
		"lock":
			draw_rect(Rect2(P(5, 11), Vector2(14, 10) * u), c)
			draw_arc(P(12, 11), 4.5 * u, PI, TAU, 16, c, w, true)
			draw_circle(P(12, 15.5), 1.5 * u, Color(0, 0, 0, 0.5))
		"star":
			UI.draw_star(self, P(12, 12.5), 10.5 * u, true)
		"gear":
			for i: int in 8:
				var a := i * TAU / 8.0
				draw_line(P(12, 12) + Vector2.from_angle(a) * 6 * u, P(12, 12) + Vector2.from_angle(a) * 10 * u, c, w * 1.6)
			draw_circle(P(12, 12), 7 * u, c)
			draw_circle(P(12, 12), 3 * u, Color(0, 0, 0, 0.35))
		"trophy":
			draw_colored_polygon(PackedVector2Array([P(6, 3), P(18, 3), P(17, 10), P(12, 14), P(7, 10)]), c)
			draw_arc(P(6, 7), 3 * u, PI / 2, PI * 1.5, 10, c, w, true)
			draw_arc(P(18, 7), 3 * u, -PI / 2, PI / 2, 10, c, w, true)
			draw_rect(Rect2(P(10.5, 13), Vector2(3, 4) * u), c)
			draw_rect(Rect2(P(7, 17), Vector2(10, 3.5) * u), c)
		"info":
			draw_circle(P(12, 12), 10 * u, c)
			var ink := Color(0, 0, 0, 0.55) if c.get_luminance() > 0.5 else Color.WHITE
			draw_circle(P(12, 7), 1.6 * u, ink)
			draw_line(P(12, 10.5), P(12, 18), ink, w * 1.3)
		"medic":
			draw_circle(P(12, 12), 11 * u, Color.WHITE)
			draw_rect(Rect2(P(9.5, 4.5), Vector2(5, 15) * u), UI.C_RED)
			draw_rect(Rect2(P(4.5, 9.5), Vector2(15, 5) * u), UI.C_RED)
		"arrow_left":
			draw_polyline(PackedVector2Array([P(14, 5), P(7, 12), P(14, 19)]), c, w * 1.5, true)
			draw_line(P(8, 12), P(19, 12), c, w * 1.5, true)
		"pause":
			draw_rect(Rect2(P(6.5, 5), Vector2(4, 14) * u), c)
			draw_rect(Rect2(P(13.5, 5), Vector2(4, 14) * u), c)
		"kit":
			draw_rect(Rect2(P(2, 7), Vector2(20, 14) * u), UI.C_RED)
			draw_rect(Rect2(P(8, 4), Vector2(8, 3.5) * u), UI.C_RED.darkened(0.3), false, w)
			draw_rect(Rect2(P(10.5, 9.5), Vector2(3, 9) * u), Color.WHITE)
			draw_rect(Rect2(P(7.5, 12.5), Vector2(9, 3) * u), Color.WHITE)
		"bandage":
			draw_set_transform(P(12, 12), -PI / 4, Vector2.ONE)
			draw_rect(Rect2(Vector2(-11, -4) * u, Vector2(22, 8) * u), Color("#e9b98c"))
			draw_rect(Rect2(Vector2(-4, -4) * u, Vector2(8, 8) * u), Color("#f6dcc0"))
			for d: Vector2 in [Vector2(-8, -1.5), Vector2(-8, 1.5), Vector2(8, -1.5), Vector2(8, 1.5)]:
				draw_circle(d * u, 0.7 * u, Color("#b98a5e"))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"drop":
			draw_colored_polygon(PackedVector2Array([P(12, 2), P(18, 13), P(16.5, 18.5), P(12, 21), P(7.5, 18.5), P(6, 13)]), c)
			draw_circle(P(12, 15), 6 * u, c)
			draw_circle(P(10, 14), 1.5 * u, Color(1, 1, 1, 0.5))
		"foot":
			draw_colored_polygon(PackedVector2Array([P(8, 2), P(14, 2), P(14, 14), P(21, 17), P(21, 21), P(6, 21), P(7, 14)]), c)
			draw_line(P(7, 8), P(14, 8), Color(1, 1, 1, 0.6), w)
		"flame":
			draw_colored_polygon(PackedVector2Array([P(12, 2), P(18, 11), P(18, 16), P(15, 21), P(9, 21), P(6, 16), P(6, 12), P(9, 13), P(10, 8)]), UI.C_ORANGE)
			draw_colored_polygon(PackedVector2Array([P(12, 11), P(15, 16), P(13.5, 20), P(10.5, 20), P(9, 16)]), UI.C_STAR)
		"bee":
			draw_circle(P(8, 8), 4 * u, Color(1, 1, 1, 0.75))
			draw_circle(P(16, 8), 4 * u, Color(1, 1, 1, 0.75))
			draw_circle(P(12, 14), 7 * u, UI.C_STAR)
			draw_line(P(7, 13), P(17, 13), Color(0.15, 0.1, 0.05), w * 1.3)
			draw_line(P(7.5, 17), P(16.5, 17), Color(0.15, 0.1, 0.05), w * 1.3)
		"person":
			draw_circle(P(12, 6), 4 * u, c)
			draw_colored_polygon(PackedVector2Array([P(5, 22), P(6, 13), P(12, 11), P(18, 13), P(19, 22)]), c)
		"lungs":
			draw_line(P(12, 2), P(12, 10), c, w * 1.4)
			draw_colored_polygon(PackedVector2Array([P(10.5, 9), P(4, 12), P(3, 20), P(10.5, 20)]), c)
			draw_colored_polygon(PackedVector2Array([P(13.5, 9), P(20, 12), P(21, 20), P(13.5, 20)]), c)
		_:
			draw_circle(P(12, 12), 9 * u, c)


func _heart_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in 40:
		var t := i * TAU / 40.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(P(12.0 + x * 0.62, 11.5 + y * 0.62))
	return pts
