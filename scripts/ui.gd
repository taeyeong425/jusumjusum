class_name UI
extends RefCounted
## UI 헬퍼. 톤: 크림 바탕 · 갈색 잉크 · 손글씨 (§13.1 방과후 교실)

const BG := Color("#F6EEDD")
const PAPER := Color("#FFF8EC")
const INK := Color("#3B3024")
const SOFT := Color("#7A6A55")
const ACCENT := Color("#E07A5F")
const GOOD := Color("#3E8E5B")
const BAD := Color("#C0392B")
const CHALK := Color("#2F4A3A")


static func theme() -> Theme:
	Data.load_fonts()
	var t := Theme.new()
	t.default_font = Data.font_regular
	t.default_font_size = 24
	t.set_color("font_color", "Label", INK)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		match state:
			"normal": sb.bg_color = Color("#FBE3C9")
			"hover": sb.bg_color = Color("#F7CFA6")
			"pressed": sb.bg_color = Color("#EDB27F")
			"disabled": sb.bg_color = Color("#E8E1D6")
			"focus":
				sb.bg_color = Color(0, 0, 0, 0)
				sb.border_color = ACCENT
				sb.set_border_width_all(2)
		if state != "focus":
			sb.border_color = Color("#C9A27A")
			sb.set_border_width_all(2)
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color("#A89C8C"))
	var pnl := StyleBoxFlat.new()
	pnl.bg_color = Color(PAPER, 0.94)
	pnl.set_corner_radius_all(16)
	pnl.border_color = Color("#D9C3A5")
	pnl.set_border_width_all(2)
	pnl.content_margin_left = 16
	pnl.content_margin_right = 16
	pnl.content_margin_top = 12
	pnl.content_margin_bottom = 12
	t.set_stylebox("panel", "PanelContainer", pnl)
	return t


static func label(text: String, size := 24, col := INK, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if bold:
		l.add_theme_font_override("font", Data.font_bold)
	return l


static func button(text: String, cb: Callable, size := 24) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): UI.sfx("click", -6.0))
	b.pressed.connect(cb)
	return b


static func panel() -> PanelContainer:
	return PanelContainer.new()


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func full(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


static func corner(c: Control, preset: int, margin := Vector2(16, 16)) -> Control:
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	var gl := Control.GROW_DIRECTION_BEGIN
	var ge := Control.GROW_DIRECTION_END
	var gb := Control.GROW_DIRECTION_BOTH
	match preset:
		Control.PRESET_TOP_LEFT:
			c.grow_horizontal = ge; c.grow_vertical = ge
			c.offset_left = margin.x; c.offset_top = margin.y
		Control.PRESET_TOP_RIGHT:
			c.grow_horizontal = gl; c.grow_vertical = ge
			c.offset_right = -margin.x; c.offset_left = -margin.x; c.offset_top = margin.y
		Control.PRESET_BOTTOM_LEFT:
			c.grow_horizontal = ge; c.grow_vertical = gl
			c.offset_left = margin.x; c.offset_bottom = -margin.y; c.offset_top = -margin.y
		Control.PRESET_BOTTOM_RIGHT:
			c.grow_horizontal = gl; c.grow_vertical = gl
			c.offset_right = -margin.x; c.offset_left = -margin.x; c.offset_bottom = -margin.y; c.offset_top = -margin.y
		Control.PRESET_CENTER_BOTTOM:
			c.grow_horizontal = gb; c.grow_vertical = gl
			c.offset_bottom = -margin.y; c.offset_top = -margin.y
		Control.PRESET_CENTER_TOP:
			c.grow_horizontal = gb; c.grow_vertical = ge
			c.offset_top = margin.y
		Control.PRESET_CENTER_LEFT:
			c.grow_horizontal = ge; c.grow_vertical = gb
			c.offset_left = margin.x
		Control.PRESET_CENTER_RIGHT:
			c.grow_horizontal = gl; c.grow_vertical = gb
			c.offset_right = -margin.x; c.offset_left = -margin.x
	return c


static func clock(sec: float) -> String:
	var s := maxi(0, ceili(sec))
	return "%d:%02d" % [s / 60, s % 60]


static func stars(n: int) -> String:
	return "★".repeat(n) + "☆".repeat(5 - n)


static func swatch(ci: int, size := Vector2(28, 28)) -> ColorRect:
	var r := ColorRect.new()
	r.color = Data.color(ci)
	r.custom_minimum_size = size
	return r


## 3D 공통: 조명 + 환경
static func make_env(parent: Node, sky := Color("#CFE6F2")) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#FFF4E0")
	env.ambient_light_energy = 0.36
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 0.82
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 0.7
	sun.light_color = Color("#FFF1DC")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	parent.add_child(sun)


static func label3d(text: String, size := 64, col := INK) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = Data.font_bold
	l.font_size = size
	l.modulate = col
	l.outline_size = 12
	l.outline_modulate = Color(1, 1, 1, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.01
	return l


## 덩어리 아이콘 — 실제 비율(기본 크기 × 변형)과 색 그대로 정면 실루엣을 그린다.
## 판은 얇아서 위에서 본 모양으로.
static func draw_chunk_icon(c: CanvasItem, item: Dictionary, r: Rect2) -> void:
	var t: String = item["type"]
	var sh: Vector3 = item.get("shape", Vector3.ONE)
	var b := Data.base_size(t) * sh
	var w := b.x
	var h := b.z if t == "plate" else b.y
	if t == "ring":
		h = b.x if b.y < b.x else b.y
	var k := minf(r.size.x / maxf(w, 0.01), r.size.y / maxf(h, 0.01)) * 0.92
	var W := maxf(w * k, 3.0)
	var H := maxf(h * k, 3.0)
	var cen := r.get_center()
	var col := Data.color(item.get("color", 0))
	var ink := Color(INK, 0.85)
	var rect := Rect2(cen - Vector2(W, H) * 0.5, Vector2(W, H))
	match t:
		"sphere", "potato", "pebble":
			var pts := _ellipse_pts(cen, W * 0.5, H * 0.5, 20 if t == "sphere" else (8 if t == "potato" else 6))
			c.draw_colored_polygon(pts, col)
			c.draw_polyline(_closed(pts), ink, 1.5)
		"hemi":
			var pts := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				pts.append(Vector2(cen.x + cos(a) * W * 0.5, cen.y + H * 0.5 + sin(a) * H))
			c.draw_colored_polygon(pts, col)
			c.draw_polyline(_closed(pts), ink, 1.5)
		"cone":
			var pts := PackedVector2Array([Vector2(cen.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
			c.draw_colored_polygon(pts, col)
			c.draw_polyline(_closed(pts), ink, 1.5)
		"wedge":
			var pts := PackedVector2Array([rect.position, rect.end, Vector2(rect.position.x, rect.end.y)])
			c.draw_colored_polygon(pts, col)
			c.draw_polyline(_closed(pts), ink, 1.5)
		"ring":
			var rad := minf(W, H) * 0.5
			c.draw_arc(cen, rad * 0.72, 0, TAU, 28, col, rad * 0.5)
			c.draw_arc(cen, rad, 0, TAU, 28, ink, 1.5)
			c.draw_arc(cen, rad * 0.45, 0, TAU, 28, ink, 1.5)
		"capsule":
			var sb := StyleBoxFlat.new()
			sb.bg_color = col
			sb.set_corner_radius_all(int(minf(W, H) * 0.5))
			sb.border_color = ink
			sb.set_border_width_all(1)
			c.draw_style_box(sb, rect)
		"cylinder":
			c.draw_rect(rect, col)
			var eh := clampf(W * 0.18, 2.0, H * 0.4)
			c.draw_colored_polygon(_ellipse_pts(Vector2(cen.x, rect.position.y), W * 0.5, eh, 16), col.lightened(0.18))
			c.draw_rect(rect, ink, false, 1.5)
		_:
			c.draw_rect(rect, col)
			c.draw_rect(rect, ink, false, 1.5)


static func _ellipse_pts(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var q := p.duplicate()
	q.append(p[0])
	return q


## autoload를 직접 참조하지 않는다 (헤드리스 테스트 스크립트에서도 컴파일되게)
static func sfx(name: String, db := 0.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		var s := tree.root.get_node_or_null("Sfx")
		if s:
			s.play(name, db)
