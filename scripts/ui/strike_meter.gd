class_name StrikeMeter
extends HBoxContainer
## Three hearts = three chances. Each strike breaks one heart (with a burst).

const MAX := 3

var strikes: int = 0
var _hearts: Array[Icon] = []


func _init(px: float = 34.0) -> void:
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i: int in MAX:
		var h := Icon.new("heart", UI.C_RED, px)
		_hearts.append(h)
		add_child(h)


func set_strikes(n: int, animate: bool = true) -> void:
	var prev := strikes
	strikes = clampi(n, 0, MAX)
	for i: int in MAX:
		# Hearts break from the right.
		var broken := i >= MAX - strikes
		var h := _hearts[i]
		h.kind = "heart_broken" if broken else "heart"
		h.color = Color("#7d7470") if broken else UI.C_RED
	if animate and strikes > prev and is_inside_tree():
		for i: int in range(MAX - strikes, MAX - prev):
			var h := _hearts[i]
			FX.burst(self, h.position + h.size / 2.0, UI.C_RED, 18, 180.0)
			h.pivot_offset = h.size / 2.0
			var tw := h.create_tween()
			tw.tween_property(h, "scale", Vector2(1.6, 1.6), 0.12)
			tw.tween_property(h, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
