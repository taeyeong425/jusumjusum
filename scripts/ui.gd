class_name UI
extends RefCounted
## UI 헬퍼. 톤 (v0.5): 깔끔한 장난감 — 흰 카드 · 한 가지 강조색 버튼 · 나눔고딕
const FONT_SCALE := 0.84   # 나눔고딕은 손글씨보다 커 보여서 전체를 줄인다

const BG := Color("#F6EEDD")
const PAPER := Color("#FFF8EC")
const INK := Color("#1B2A34")
const SOFT := Color("#56636D")
const ACCENT := Color("#E2553D")
const GOOD := Color("#237841")
const BAD := Color("#C91A09")
const CHALK := Color("#24303B")


static func theme() -> Theme:
	Data.load_fonts()
	var t := Theme.new()
	t.default_font = Data.font_regular
	t.default_font_size = 20
	t.set_color("font_color", "Label", INK)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		# 깔끔한 버튼: 연한 회색 바탕 · 얇은 테두리. 강조 버튼은 primary()로 따로
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 7
		sb.content_margin_bottom = 7
		sb.border_color = Color("#D5DADF")
		sb.set_border_width_all(1)
		match state:
			"normal": sb.bg_color = Color("#F3F5F7")
			"hover": sb.bg_color = Color("#E6EBF0")
			"pressed": sb.bg_color = Color("#D9E0E7")
			"disabled":
				sb.bg_color = Color("#F3F5F7")
				sb.border_color = Color("#E3E6E9")
			"focus":
				sb.bg_color = Color(0, 0, 0, 0)
				sb.border_color = ACCENT
				sb.set_border_width_all(2)
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color("#9AA2A8"))
	# 흰 카드 (그림자 살짝)
	var pnl := StyleBoxFlat.new()
	pnl.bg_color = Color(1, 1, 1, 0.96)
	pnl.set_corner_radius_all(12)
	pnl.shadow_color = Color(0, 0, 0, 0.12)
	pnl.shadow_size = 6
	pnl.shadow_offset = Vector2(0, 2)
	pnl.content_margin_left = 16
	pnl.content_margin_right = 16
	pnl.content_margin_top = 12
	pnl.content_margin_bottom = 12
	t.set_stylebox("panel", "PanelContainer", pnl)
	return t


static func label(text: String, size := 24, col := INK, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(size * FONT_SCALE))
	l.add_theme_color_override("font_color", col)
	if bold:
		l.add_theme_font_override("font", Data.font_bold)
	return l


static func button(text: String, cb: Callable, size := 24) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", int(size * FONT_SCALE))
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
	var mk := Data.mesh_key(t, sh)
	var poly := PackedVector2Array()
	match mk:
		"plate:star":
			for i in 10:
				var ang := -PI / 2 + PI * i / 5.0
				var rr := 0.5 if i % 2 == 0 else 0.22
				poly.append(cen + Vector2(cos(ang), sin(ang)) * rr * minf(r.size.x, r.size.y) * 0.95)
		"plate:heart":
			for i in 24:
				var s := TAU * i / 24.0
				poly.append(cen + Vector2(16.0 * pow(sin(s), 3), -(13.0 * cos(s) - 5.0 * cos(2 * s) - 2.0 * cos(3 * s) - cos(4 * s))) * minf(r.size.x, r.size.y) * 0.028)
		"plate:round":
			poly = _ellipse_pts(cen, minf(W, H) * 0.5, minf(W, H) * 0.5, 20)
		"box:L":
			var p0 := rect.position
			poly = PackedVector2Array([p0, p0 + Vector2(W * 0.45, 0), p0 + Vector2(W * 0.45, H * 0.55), rect.end - Vector2(0, H * 0.45), rect.end, p0 + Vector2(0, H)])
		"box:step":
			var p0 := rect.position
			poly = PackedVector2Array([p0, p0 + Vector2(W / 3, 0), p0 + Vector2(W / 3, H / 3), p0 + Vector2(W * 2 / 3, H / 3), p0 + Vector2(W * 2 / 3, H * 2 / 3), p0 + Vector2(W, H * 2 / 3), rect.end, p0 + Vector2(0, H)])
		"box:cross", "rod:T", "rod:bent":
			var th := minf(W, H) * (0.34 if mk == "box:cross" else 0.22)
			var bars := []
			if mk == "box:cross":
				bars = [Rect2(cen.x - W / 2, cen.y - th / 2, W, th), Rect2(cen.x - th / 2, cen.y - H / 2, th, H)]
			elif mk == "rod:T":
				bars = [Rect2(rect.position.x, rect.position.y, W, th), Rect2(cen.x - th / 2, rect.position.y, th, H)]
			else:
				bars = [Rect2(rect.position.x, rect.position.y, W, th), Rect2(rect.position.x, rect.position.y, th, H)]
			for br in bars:
				c.draw_rect(br, col)
			for br in bars:
				c.draw_rect(br, ink, false, 1.5)
			return
		"cone:4", "cone:5", "wedge:roof":
			poly = PackedVector2Array([Vector2(cen.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
		"cylinder:6", "sphere:gem":
			for i in 6:
				var ang := PI / 6 + TAU * i / 6.0
				poly.append(cen + Vector2(cos(ang) * W * 0.5, sin(ang) * H * 0.5))
		"cylinder:3":
			poly = PackedVector2Array([Vector2(cen.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
		"cylinder:pot":
			poly = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end - Vector2(W * 0.18, 0), Vector2(rect.position.x + W * 0.18, rect.end.y)])
		"ring:4":
			var q := minf(W, H)
			var o := Rect2(cen - Vector2(q, q) * 0.5, Vector2(q, q))
			c.draw_rect(o.grow(-q * 0.12), col, false, q * 0.24)
			c.draw_rect(o, ink, false, 1.5)
			c.draw_rect(o.grow(-q * 0.25), ink, false, 1.5)
			return
		"ring:arch":
			var rad := minf(W * 0.5, H)
			var base := Vector2(cen.x, cen.y + rad * 0.5)
			c.draw_arc(base, rad * 0.75, PI, TAU, 16, col, rad * 0.45)
			c.draw_arc(base, rad, PI, TAU, 16, ink, 1.5)
			c.draw_arc(base, rad * 0.52, PI, TAU, 16, ink, 1.5)
			return
	if poly.size() > 2:
		c.draw_colored_polygon(poly, col)
		c.draw_polyline(_closed(poly), ink, 1.5)
		return
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


## 흰 플라스틱 타일 버튼 (목록용 — 노란 브릭 버튼이 줄줄이면 시끄럽다)
static func tile_button(b: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(8)
		sb.border_color = Color("#C3C9CE")
		sb.set_border_width_all(1)
		sb.border_color = Color("#E1E5E9")
		sb.bg_color = {"normal": Color("#FFFFFF"), "hover": Color("#F1F5F9"), "pressed": Color("#E4EAF0")}[state]
		b.add_theme_stylebox_override(state, sb)


## 강조 버튼 (진행 · 시작 등 화면에 하나) — 강조색 바탕 · 흰 글씨
static func primary(text: String, cb: Callable, size := 26) -> Button:
	var b := button(text, cb, size)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 9
		sb.content_margin_bottom = 9
		sb.bg_color = {"normal": ACCENT, "hover": ACCENT.lightened(0.1), "pressed": ACCENT.darkened(0.12)}[state]
		b.add_theme_stylebox_override(state, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_font_override("font", Data.font_bold)
	return b


## 봉투 아이콘 (쪽지 · 편지봉투 · 금봉투)
static func draw_envelope(c: CanvasItem, r: Rect2, tier: String) -> void:
	var col := Color("#FFFDF7") if tier == "note" else (Color("#F2C94C") if tier == "gold" else Color("#F4B6C2"))
	var ink := Color(INK, 0.8)
	var rr := Rect2(r.position + Vector2(0, r.size.y * 0.15), Vector2(r.size.x, r.size.y * 0.7))
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(3)
	sb.border_color = ink
	sb.set_border_width_all(1)
	c.draw_style_box(sb, rr)
	if tier == "note":
		for k in 3:
			var y := rr.position.y + rr.size.y * (0.3 + k * 0.2)
			c.draw_line(Vector2(rr.position.x + 5, y), Vector2(rr.end.x - 5 - k * 4, y), Color("#9AA5AF"), 1.5)
	else:
		c.draw_polyline(PackedVector2Array([rr.position, Vector2(rr.get_center().x, rr.position.y + rr.size.y * 0.55), Vector2(rr.end.x, rr.position.y)]), ink, 1.5)
		c.draw_circle(Vector2(rr.get_center().x, rr.position.y + rr.size.y * 0.55), 3.5, Color("#C0392B") if tier == "env" else Color("#0A3463"))
	if tier == "gold":
		c.draw_string(Data.font_bold, rr.position + Vector2(rr.size.x - 12, 2), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#B07800"))
