class_name StarRow
extends Control
## Shows N of 3 stars. Font-independent placeholder for star art.
## animate_in() pops earned stars one by one with sparkles (level complete).

@export var stars: int = 0:
	set(v):
		stars = clampi(v, 0, 3)
		queue_redraw()
@export var star_size: float = 18.0

var _scales: Array[float] = [1.0, 1.0, 1.0]


func _init(count: int = 0, size_px: float = 18.0) -> void:
	stars = count
	star_size = size_px
	custom_minimum_size = Vector2(size_px * 2.3 * 3, size_px * 2.3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _center(i: int) -> Vector2:
	var step := size.x / 3.0
	var lift := -star_size * 0.25 if i == 1 and star_size > 24.0 else 0.0
	return Vector2(step * (i + 0.5), size.y / 2.0 + lift)


func animate_in(delay: float = 0.2) -> void:
	if not is_inside_tree():
		return
	for i: int in 3:
		_scales[i] = 0.0 if i < stars else 1.0
	queue_redraw()
	var tw := create_tween()
	tw.tween_interval(delay)
	for i: int in stars:
		var idx := i
		tw.tween_method(func(v: float) -> void:
			_scales[idx] = v
			queue_redraw(), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			FX.burst(self, _center(idx), UI.C_STAR, 20, 200.0)
			Game.sfx("star"))


func _draw() -> void:
	for i: int in 3:
		var filled := i < stars
		if filled and _scales[i] < 0.02:
			UI.draw_star(self, _center(i), star_size, false)
			continue
		var sc := _scales[i] if filled else 1.0
		UI.draw_star(self, _center(i), star_size * sc, filled)
