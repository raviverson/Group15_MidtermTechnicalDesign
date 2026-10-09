class_name FX
extends RefCounted
## Lightweight animation + particle helpers (tweens and CPUParticles2D only, so they
## run on the Compatibility renderer and low-end Android phones).

static var _dot_tex: Texture2D


## Soft round dot texture generated in code (no image assets needed).
static func dot_texture() -> Texture2D:
	if _dot_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 32
		gt.height = 32
		_dot_tex = gt
	return _dot_tex


static func _keep_pivot_centered(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	if c.has_meta("_fx_pivot"):
		return
	c.set_meta("_fx_pivot", true)
	c.resized.connect(func() -> void:
		if is_instance_valid(c):
			c.pivot_offset = c.size / 2.0)


## Grow slightly on hover, squash on press. Safe on touch screens.
static func hover_bounce(c: Control, s: float = 1.05) -> void:
	_keep_pivot_centered(c)
	c.mouse_entered.connect(func() -> void: _scale_to(c, s, 0.12))
	c.mouse_exited.connect(func() -> void: _scale_to(c, 1.0, 0.12))
	if c is BaseButton:
		var b: BaseButton = c
		b.button_down.connect(func() -> void: _scale_to(c, 0.94, 0.06))
		b.button_up.connect(func() -> void: _scale_to(c, 1.0, 0.1))


static func _scale_to(c: Control, s: float, t: float) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		return
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(s, s), t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Pop a control in (scale + fade). Call after adding it to the tree.
static func pop_in(c: Control, delay: float = 0.0, from_scale: float = 0.8) -> Tween:
	if not c.is_inside_tree():
		return null
	_keep_pivot_centered(c)
	c.modulate.a = 0.0
	c.scale = Vector2(from_scale, from_scale)
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.18).set_delay(delay)
	tw.tween_property(c, "scale", Vector2.ONE, 0.32).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


## Slide in from an offset while fading.
static func slide_in(c: Control, offset: Vector2, delay: float = 0.0) -> void:
	if not c.is_inside_tree():
		return
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.25).set_delay(delay)
	# Use a visual-only translation so containers keep control of layout.
	var target := c.position
	c.position = target + offset
	tw.tween_property(c, "position", target, 0.35).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Horizontal shake (wrong answer). Restores the exact start position.
static func shake(c: Control, strength: float = 12.0, duration: float = 0.35) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		return
	var origin := c.position
	if c.has_meta("_shake_origin"):
		origin = c.get_meta("_shake_origin")
	c.set_meta("_shake_origin", origin)
	var tw := c.create_tween()
	var steps := 6
	for i: int in steps:
		var dx := strength * (1.0 - float(i) / steps) * (1.0 if i % 2 == 0 else -1.0)
		tw.tween_property(c, "position", origin + Vector2(dx, 0), duration / steps)
	tw.tween_property(c, "position", origin, duration / steps)
	tw.tween_callback(func() -> void:
		if is_instance_valid(c):
			c.remove_meta("_shake_origin"))


## Gentle repeating pulse (timer warning, call-to-action).
static func pulse(c: Control, s: float = 1.08, period: float = 0.8) -> Tween:
	if not c.is_inside_tree():
		return null
	_keep_pivot_centered(c)
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "scale", Vector2(s, s), period / 2.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "scale", Vector2.ONE, period / 2.0).set_trans(Tween.TRANS_SINE)
	return tw


## One-shot burst of soft dots (correct = gold/green sparkles, wrong = red puff).
static func burst(parent: Node, pos: Vector2, color: Color, amount: int = 26, speed: float = 260.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = dot_texture()
	p.position = pos
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.8
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 380)
	p.damping_min = 40.0
	p.damping_max = 80.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.6
	var ramp := Gradient.new()
	ramp.set_color(0, color.lightened(0.25))
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	parent.add_child(p)
	p.emitting = true
	_free_after(p, p.lifetime + 0.4)
	return p


## Confetti shower across `width` px from y = top (level complete).
static func confetti(parent: Node, width: float, top: float = -10.0, amount: int = 90) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = Vector2(width / 2.0, top)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(width / 2.0, 4)
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.7
	p.lifetime = 2.6
	p.direction = Vector2.DOWN
	p.spread = 25.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 220.0
	p.gravity = Vector2(0, 260)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 6.0
	p.scale_amount_max = 11.0
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	colors.colors = PackedColorArray([UI.C_STAR, UI.C_RED, UI.C_GOOD, UI.C_BLUE, UI.C_ORANGE])
	colors.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = colors
	parent.add_child(p)
	p.emitting = true
	_free_after(p, p.lifetime + 0.5)
	return p


## Endless slow floating motes for background atmosphere.
static func ambient(parent: Node, rect: Rect2, color: Color = Color(1, 1, 1, 0.35), amount: int = 18) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = dot_texture()
	p.position = rect.get_center()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = rect.size / 2.0
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.direction = Vector2(0.3, -1)
	p.spread = 30.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 20.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.45
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(color, 0.0), color, color, Color(color, 0.0)])
	p.color_ramp = ramp
	parent.add_child(p)
	p.emitting = true
	return p


## "+10" style text that floats up and fades.
static func float_text(parent: Control, pos: Vector2, text: String, color: Color, font_size: int = 30) -> void:
	var l := UI.title(text, font_size, color, color.darkened(0.5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.reset_size()
	l.position = pos - l.size / 2.0
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 70.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


## Count a label up from 0 to `value`.
static func count_up(l: Label, value: int, duration: float = 0.8, fmt: String = "%d") -> void:
	if not l.is_inside_tree():
		l.text = fmt % value
		return
	var tw := l.create_tween()
	tw.tween_method(func(v: float) -> void: l.text = fmt % int(round(v)), 0.0, float(value), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func _free_after(n: Node, seconds: float) -> void:
	if not n.is_inside_tree():
		n.queue_free()
		return
	var tw := n.create_tween()
	tw.tween_interval(seconds)
	tw.tween_callback(n.queue_free)
