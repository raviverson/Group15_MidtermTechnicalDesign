class_name PatientFace
extends Control
## Placeholder cartoon patient (storyboard kid: brown hair, blue shirt).
## Its expression shows the EFFECT of the player's choice.
## moods: happy, neutral, worried, hurt, sad, angry

const MOODS := ["happy", "neutral", "worried", "hurt", "sad", "angry"]

@export var mood: String = "neutral":
	set(v):
		mood = v if v in MOODS else "neutral"
		queue_redraw()
@export var show_body: bool = true
@export var idle: bool = true

var _t: float = 0.0
var _squash: float = 0.0


func _init(p_mood: String = "neutral", p_body: bool = true) -> void:
	mood = p_mood
	show_body = p_body
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(160, 200) if p_body else Vector2(90, 90)


## Change mood with a little squash-and-stretch.
func react(new_mood: String) -> void:
	mood = new_mood
	_squash = 1.0


func _process(delta: float) -> void:
	_t += delta
	if _squash > 0.0:
		_squash = maxf(0.0, _squash - delta * 3.0)
	if idle or _squash > 0.0:
		queue_redraw()


func _draw() -> void:
	var s := minf(size.x / 160.0, size.y / (200.0 if show_body else 100.0))
	var bob := sin(_t * 2.2) * 3.0 * s if idle else 0.0
	var sq := sin(_squash * PI) * 0.12
	var head_c := Vector2(size.x / 2.0, (62.0 if show_body else 50.0) * s + bob)
	var hr := 44.0 * s
	if show_body:
		var body := Rect2(Vector2(size.x / 2.0 - 52 * s, 112 * s + bob * 0.5), Vector2(104, 88) * s)
		draw_style_box(UI.style(UI.C_SHIRT, int(30 * s), UI.C_SHIRT.darkened(0.35), maxi(2, int(3 * s))), body)
		draw_rect(Rect2(head_c + Vector2(-10, 30) * s, Vector2(20, 22) * s), UI.C_SKIN_DARK)
		# collar
		draw_colored_polygon(PackedVector2Array([head_c + Vector2(-18, 50) * s, head_c + Vector2(0, 62) * s, head_c + Vector2(18, 50) * s]), UI.C_SHIRT.lightened(0.3))
	draw_set_transform(head_c, 0.0, Vector2(1.0 + sq, 1.0 - sq))
	var o := Vector2.ZERO
	# ears + head
	draw_circle(o + Vector2(-hr, 4 * s), 9 * s, UI.C_SKIN_DARK)
	draw_circle(o + Vector2(hr, 4 * s), 9 * s, UI.C_SKIN_DARK)
	draw_circle(o, hr, UI.C_SKIN)
	draw_arc(o, hr, 0, TAU, 48, UI.C_SKIN_DARK, maxf(2.0, 3.0 * s), true)
	# hair
	var hair := PackedVector2Array()
	for i: int in 21:
		var a := PI + i * PI / 20.0
		hair.append(o + Vector2.from_angle(a) * (hr + 3 * s))
	hair.append(o + Vector2(hr * 0.75, -hr * 0.15))
	hair.append(o + Vector2(hr * 0.3, -hr * 0.45))
	hair.append(o + Vector2(-hr * 0.1, -hr * 0.25))
	hair.append(o + Vector2(-hr * 0.5, -hr * 0.45))
	hair.append(o + Vector2(-hr * 0.85, -hr * 0.1))
	draw_colored_polygon(hair, UI.C_HAIR)
	_draw_face(o, s)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_face(o: Vector2, s: float) -> void:
	var ink := Color("#2b1d14")
	var lw := maxf(2.0, 3.2 * s)
	var el := o + Vector2(-15, 2) * s
	var er := o + Vector2(15, 2) * s
	# blush
	draw_circle(o + Vector2(-25, 16) * s, 6 * s, Color(1, 0.45, 0.45, 0.35))
	draw_circle(o + Vector2(25, 16) * s, 6 * s, Color(1, 0.45, 0.45, 0.35))
	match mood:
		"happy":
			draw_arc(el + Vector2(0, 3 * s), 6 * s, PI * 1.1, PI * 1.9, 10, ink, lw, true)
			draw_arc(er + Vector2(0, 3 * s), 6 * s, PI * 1.1, PI * 1.9, 10, ink, lw, true)
			draw_arc(o + Vector2(0, 12) * s, 14 * s, 0.15 * PI, 0.85 * PI, 16, ink, lw, true)
		"neutral":
			draw_circle(el, 4.5 * s, ink)
			draw_circle(er, 4.5 * s, ink)
			draw_line(o + Vector2(-9, 22) * s, o + Vector2(9, 22) * s, ink, lw, true)
		"worried":
			draw_circle(el, 4.5 * s, ink)
			draw_circle(er, 4.5 * s, ink)
			draw_line(el + Vector2(-7, -12) * s, el + Vector2(6, -16) * s, ink, lw, true)
			draw_line(er + Vector2(7, -12) * s, er + Vector2(-6, -16) * s, ink, lw, true)
			draw_arc(o + Vector2(0, 30) * s, 9 * s, 1.15 * PI, 1.85 * PI, 12, ink, lw, true)
			# sweat drop
			draw_circle(o + Vector2(36, -12) * s, 4 * s, Color("#7fc8f8"))
		"hurt":
			draw_line(el + Vector2(-5, -5) * s, el + Vector2(5, 5) * s, ink, lw, true)
			draw_line(el + Vector2(5, -5) * s, el + Vector2(-5, 5) * s, ink, lw, true)
			draw_line(er + Vector2(-5, -5) * s, er + Vector2(5, 5) * s, ink, lw, true)
			draw_line(er + Vector2(5, -5) * s, er + Vector2(-5, 5) * s, ink, lw, true)
			draw_polyline(PackedVector2Array([o + Vector2(-11, 26) * s, o + Vector2(-5, 21) * s, o + Vector2(0, 26) * s, o + Vector2(5, 21) * s, o + Vector2(11, 26) * s]), ink, lw, true)
			draw_circle(o + Vector2(-17, 13) * s, 3.5 * s, Color("#7fc8f8"))
		"sad":
			draw_circle(el, 4.5 * s, ink)
			draw_circle(er, 4.5 * s, ink)
			draw_arc(o + Vector2(0, 32) * s, 11 * s, 1.15 * PI, 1.85 * PI, 12, ink, lw, true)
			draw_line(el + Vector2(0, 6) * s, el + Vector2(0, 16) * s, Color("#7fc8f8"), lw, true)
		"angry":
			draw_circle(el, 4.5 * s, ink)
			draw_circle(er, 4.5 * s, ink)
			draw_line(el + Vector2(-7, -14) * s, el + Vector2(6, -9) * s, ink, lw, true)
			draw_line(er + Vector2(7, -14) * s, er + Vector2(-6, -9) * s, ink, lw, true)
			draw_arc(o + Vector2(0, 30) * s, 10 * s, 1.15 * PI, 1.85 * PI, 12, ink, lw, true)
