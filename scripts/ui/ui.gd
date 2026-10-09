class_name UI
extends RefCounted
## Storyboard-style placeholder visual kit (dark-green ribbons, cream parchment cards,
## chunky 3D buttons, gold stars). Every color/style lives here so artists can swap in
## real textures later without touching gameplay code.

const C_BG := Color("#dfe9d3")
const C_PRIMARY := Color("#3f8f4f")
const C_PRIMARY_DARK := Color("#1f4a33")
const C_CREAM := Color("#fbf1d9")
const C_CREAM_DARK := Color("#efdcb4")
const C_BROWN := Color("#8a6a3e")
const C_TEXT := Color("#3a2e1f")
const C_MUTED := Color("#7a6a55")
const C_RED := Color("#d9473f")
const C_BLUE := Color("#3d79c4")
const C_ORANGE := Color("#e8892b")
const C_GOOD := Color("#43a04f")
const C_LOCK := Color("#9c958a")
const C_SKIN := Color("#f2c49b")
const C_SKIN_DARK := Color("#c98e63")
const C_WOUND := Color("#b8323a")
const C_DIRT := Color("#7a5a3a")
const C_STAR := Color("#f5b82e")
const C_HAIR := Color("#3b2a20")
const C_SHIRT := Color("#3d79c4")

static var _font_bold: FontVariation
static var _font_regular: FontVariation


static func font_bold() -> Font:
	if _font_bold == null:
		_font_bold = FontVariation.new()
		_font_bold.base_font = ThemeDB.fallback_font
		_font_bold.variation_embolden = 0.9
	return _font_bold


static func font_regular() -> Font:
	if _font_regular == null:
		_font_regular = FontVariation.new()
		_font_regular.base_font = ThemeDB.fallback_font
		_font_regular.variation_embolden = 0.35
	return _font_regular


static func color_named(n: String) -> Color:
	match n:
		"good": return C_GOOD
		"orange": return C_ORANGE
		"red": return C_RED
		"blue": return C_BLUE
	return C_PRIMARY


## Global theme applied to the root window: every Label/Button/Panel inherits it.
static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_regular()
	t.default_font_size = 20
	t.set_color("font_color", "Label", C_TEXT)
	t.set_stylebox("panel", "PanelContainer", style(C_CREAM, 16, C_BROWN, 3))
	for k: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(k, "Button", _button_box(C_PRIMARY, k))
	t.set_font("font", "Button", font_bold())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.85))
	t.set_stylebox("panel", "PopupPanel", style(C_CREAM, 14, C_BROWN, 3))
	t.set_stylebox("panel", "AcceptDialog", style(C_CREAM, 14, C_BROWN, 3))
	t.set_color("font_color", "AcceptDialog", C_TEXT)
	return t


static func style(color: Color, radius: int = 14, border: Color = Color.TRANSPARENT, border_w: int = 0, margin: float = 12.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = true
	return sb


## Chunky storyboard button: darker bottom lip that "presses in".
static func _button_box(color: Color, state: String) -> StyleBox:
	if state == "focus":
		return StyleBoxEmpty.new()
	var c := color
	match state:
		"hover": c = color.lightened(0.1)
		"pressed": c = color.darkened(0.08)
		"disabled": c = C_LOCK
	var sb := style(c, 12, c.darkened(0.35), 2, 10)
	sb.border_width_bottom = 2 if state == "pressed" else 6
	sb.border_width_top = 4 if state == "pressed" else 2
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 0 if state == "pressed" else 3
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	return sb


static func button(text: String, color: Color = C_PRIMARY, min_size: Vector2 = Vector2(240, 56), font_size: int = 24) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_font_override("font", font_bold())
	recolor_button(b, color)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(key, Color.WHITE)
	b.add_theme_color_override("font_outline_color", color.darkened(0.45))
	b.add_theme_constant_override("outline_size", 4)
	b.pivot_offset = min_size / 2.0
	FX.hover_bounce(b)
	return b


static func recolor_button(b: Button, color: Color) -> void:
	for k: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(k, _button_box(color, k))


## Cream answer button with a letter badge, like storyboard frame 05.
static func choice_button(letter: String, text: String) -> Button:
	var b := Button.new()
	b.text = "%s.  %s" % [letter, text]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 62)
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_font_override("font", font_bold())
	set_choice_state(b, "normal")
	FX.hover_bounce(b, 1.02)
	return b


## state: "normal" | "correct" | "wrong" | "dim"
static func set_choice_state(b: Button, state: String) -> void:
	var bg := C_CREAM
	var border := C_BROWN
	var fc := C_TEXT
	match state:
		"correct":
			bg = C_GOOD
			border = C_GOOD.darkened(0.35)
			fc = Color.WHITE
		"wrong":
			bg = C_RED
			border = C_RED.darkened(0.35)
			fc = Color.WHITE
		"dim":
			bg = C_CREAM_DARK
			fc = C_MUTED
	for k: String in ["normal", "hover", "pressed", "disabled"]:
		var c := bg.lightened(0.06) if k == "hover" else bg
		var sb := style(c, 12, border, 2, 12)
		sb.border_width_bottom = 5
		sb.content_margin_left = 16
		b.add_theme_stylebox_override(k, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(key, fc)


static func label(text: String, font_size: int = 22, color: Color = C_TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrap_text: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	if wrap_text:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Big bold title with outline (logo / headers).
static func title(text: String, font_size: int = 40, color: Color = Color.WHITE, outline: Color = C_PRIMARY_DARK, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := label(text, font_size, color, align)
	l.add_theme_font_override("font", font_bold())
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", maxi(4, int(font_size / 6.0)))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l


static func panel(color: Color = C_CREAM, radius: int = 16, margin: float = 18.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := style(color, radius, color.darkened(0.35) if color != C_CREAM else C_BROWN, 3, margin)
	sb.shadow_color = Color(0, 0, 0, 0.22)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	p.add_theme_stylebox_override("panel", sb)
	return p


## Dark-green header strip with white bold text (storyboard frame headers).
static func ribbon(text: String, color: Color = C_PRIMARY_DARK, font_size: int = 22) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := style(color, 10, color.darkened(0.3), 2, 8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	p.add_theme_stylebox_override("panel", sb)
	var l := title(text, font_size, Color.WHITE, color.darkened(0.45), HORIZONTAL_ALIGNMENT_CENTER)
	l.name = "Text"
	p.add_child(l)
	return p


## Cream card with a colored ribbon header. Returns [card, body_vbox].
static func card(header: String, header_color: Color = C_PRIMARY_DARK, min_width: float = 0.0) -> Array:
	var c := panel(C_CREAM, 16, 0)
	c.custom_minimum_size = Vector2(min_width, 0)
	var v := vbox(0)
	c.add_child(v)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var r := ribbon(header, header_color)
	var rsb: StyleBoxFlat = r.get_theme_stylebox("panel").duplicate()
	rsb.corner_radius_bottom_left = 0
	rsb.corner_radius_bottom_right = 0
	rsb.corner_radius_top_left = 13
	rsb.corner_radius_top_right = 13
	r.add_theme_stylebox_override("panel", rsb)
	v.add_child(r)
	var m := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 18)
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(m)
	var body := vbox(12)
	m.add_child(body)
	return [c, body]


static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer(vertical: bool = true) -> Control:
	var s := Control.new()
	if vertical:
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## Painted placeholder environment + ambient particles.
static func background(parent: Control, kind: String = "park") -> Backdrop:
	var bg := Backdrop.new()
	bg.kind = kind
	parent.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return bg


## Standard screen: backdrop + top ribbon bar (back button, title) + body.
static func screen(parent: Control, title_text: String, back_cb: Callable = Callable(), kind: String = "clinic") -> VBoxContainer:
	background(parent, kind)
	var margin := MarginContainer.new()
	parent.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	var root := vbox(16)
	margin.add_child(root)
	var bar := hbox(16)
	root.add_child(bar)
	if back_cb.is_valid():
		var back := icon_button("arrow_left", C_PRIMARY_DARK, 54)
		back.pressed.connect(back_cb)
		bar.add_child(back)
	var rb := ribbon(title_text.to_upper(), C_PRIMARY_DARK, 26)
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(rb)
	var body := vbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	return body


## Round-cornered square button with a vector icon.
static func icon_button(icon_kind: String, color: Color = C_PRIMARY_DARK, px: int = 54) -> Button:
	var b := button("", color, Vector2(px, px), 18)
	var ic := Icon.new(icon_kind, Color.WHITE)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 10
	ic.offset_top = 8
	ic.offset_right = -10
	ic.offset_bottom = -12
	return b


static func center_in(parent: Control) -> CenterContainer:
	var c := CenterContainer.new()
	parent.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


## Draws a 5-point star (font-independent, so it renders on every device).
static func draw_star(ci: CanvasItem, center: Vector2, radius: float, filled: bool) -> void:
	var pts := PackedVector2Array()
	for i: int in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	if filled:
		ci.draw_colored_polygon(pts, C_STAR)
		var inner := PackedVector2Array()
		for pt: Vector2 in pts:
			inner.append(center + (pt - center) * 0.55 + Vector2(-radius * 0.08, -radius * 0.1))
		ci.draw_colored_polygon(inner, C_STAR.lightened(0.35))
	else:
		ci.draw_colored_polygon(pts, Color(0, 0, 0, 0.12))
	pts.append(pts[0])
	ci.draw_polyline(pts, C_STAR.darkened(0.4) if filled else C_LOCK, maxf(2.0, radius * 0.09), true)
