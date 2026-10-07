extends Node3D
## 전시 · 평가 — 익명 · 랜덤 순서 · 작품당 10초 회전 (§9.1)
## 별 위를 끌어서 0.0~5.0 (0.1 단위). 4.6 이상은 평가자당 한 작품만 (§9.2)

const LETTERS := ["A", "B", "C", "D", "E", "F"]


## 별 다섯 개 위를 끌어서 점수를 매기는 막대
class RatingBar extends Control:
	signal changed(v: float)
	var value := 3.0
	var max_v := 5.0
	var dragging := false

	func _init() -> void:
		custom_minimum_size = Vector2(360, 64)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			dragging = ev.pressed
			if ev.pressed:
				_set_from(ev.position.x)
		elif ev is InputEventMouseMotion and dragging:
			_set_from(ev.position.x)

	func _set_from(x: float) -> void:
		var v := snappedf(clampf(x / size.x * 5.0, 0.0, max_v), 0.1)
		if absf(v - value) > 0.001:
			if floori(v * 2) != floori(value * 2):
				UI.sfx("star", -14.0)
			value = v
			changed.emit(v)
			queue_redraw()

	func set_value(v: float) -> void:
		value = clampf(v, 0.0, max_v)
		queue_redraw()

	func _star(c: Vector2, r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI / 2 + PI * i / 5.0
			var rr := r if i % 2 == 0 else r * 0.45
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		return pts

	func _draw() -> void:
		var w := size.x / 5.0
		var r := minf(w, size.y) * 0.44
		for i in 5:
			var c := Vector2(w * (i + 0.5), size.y * 0.5)
			var st := _star(c, r)
			draw_colored_polygon(st, Color("#E8E1D6"))
			var f := clampf(value - i, 0.0, 1.0)
			if f > 0.0:
				var x1 := c.x - r + 2 * r * f
				var clip := PackedVector2Array([Vector2(c.x - r - 1, c.y - r - 1), Vector2(x1, c.y - r - 1), Vector2(x1, c.y + r + 1), Vector2(c.x - r - 1, c.y + r + 1)])
				for poly in Geometry2D.intersect_polygons(st, clip):
					draw_colored_polygon(poly, Color("#F4B942"))
			var closed := st.duplicate()
			closed.append(st[0])
			draw_polyline(closed, Color(UI.INK, 0.8), 2.0)
		if max_v < 5.0:
			var xm := size.x * max_v / 5.0
			draw_rect(Rect2(xm, 0, size.x - xm, size.y), Color(1, 1, 1, 0.55))
			draw_line(Vector2(xm, 4), Vector2(xm, size.y - 4), UI.BAD, 2.0)


var order: Array = []
var idx := 0
var t := 0.0
var per := 10.0
var pivot: Node3D
var cam: Camera3D
var title: Label
var count_l: Label
var sub: Label
var timer_l: Label
var rate_box: VBoxContainer
var bar: RatingBar
var value_l: Label
var top_l: Label
var done := false


func _ready() -> void:
	per = Game.t_exhibit()
	for i in Game.players.size():
		order.append(i)
	order.shuffle()
	var letters := {}
	for k in order.size():
		letters[order[k]] = LETTERS[k]
	Game.set_meta("letters", letters)
	UI.make_env(self, Color("#2A2725"))
	_gallery_set()
	pivot = Node3D.new()
	add_child(pivot)
	cam = Camera3D.new()
	cam.fov = 45
	add_child(cam)
	cam.position = Vector3(0, 1.45, 3.9)
	cam.look_at(Vector3(0, 0.25, 0))
	_build_hud()
	_show(0)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := UI.panel()
	var tv := UI.vbox(2)
	top.add_child(tv)
	count_l = UI.label("", 18, UI.SOFT)
	count_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(count_l)
	title = UI.label("", 36, UI.INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(title)
	sub = UI.label("", 22, UI.SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(sub)
	layer.add_child(top)
	UI.corner(top, Control.PRESET_TOP_LEFT, Vector2(16, 16))   # 가운데 위는 작품을 가렸다

	var bottom := UI.panel()
	var bv := UI.vbox(6)
	bottom.add_child(bv)
	rate_box = UI.vbox(4)
	bv.add_child(rate_box)
	var row := UI.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	rate_box.add_child(row)
	bar = RatingBar.new()
	bar.changed.connect(_rate)
	row.add_child(bar)
	value_l = UI.label("", 48, UI.INK, true)
	value_l.custom_minimum_size.x = 90
	row.add_child(value_l)
	top_l = UI.label("", 19, UI.SOFT)
	top_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rate_box.add_child(top_l)
	var h := UI.hbox(12)
	bv.add_child(h)
	timer_l = UI.label("", 24, UI.SOFT)
	h.add_child(timer_l)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(UI.primary("다음 작품", _next, 22))
	h.add_child(UI.keycap("Enter", 16))
	layer.add_child(bottom)
	UI.corner(bottom, Control.PRESET_BOTTOM_RIGHT, Vector2(16, 16))


func _show(k: int) -> void:
	idx = k
	t = per
	for c in pivot.get_children():
		c.queue_free()
	var who: int = order[k]
	for d in Game.players[who]["work"]:
		pivot.add_child(Piece.from_dict(d, false))
	pivot.rotation.y = 0
	var letter: String = Game.get_meta("letters")[who]
	var ttl: String = Game.players[who].get("title", "무제")
	title.text = ttl
	count_l.text = "작품 %s   ·   %d / %d" % [letter, k + 1, order.size()]
	if plaque:
		plaque.text = "「%s」\n작품 %s · %s\n%s" % [ttl, letter, Themes.INFO[Game.theme]["name"], "재질: " + _finish_text(Game.players[who]["work"])]
	var mine := who == 0
	sub.text = ("내 작품이에요. 이번엔 구경만 해요" if mine else "%s처럼 보이나요? 별을 끌어서 점수를 주세요" % Game.target["name"])
	rate_box.visible = not mine
	_refresh()


## 4.6 이상은 한 작품만 — 다른 작품에 이미 줬으면 이 작품은 4.5까지
func _refresh() -> void:
	var who: int = order[idx]
	var top_used := false
	for w in Game.human_ratings:
		if w != who and Game.human_ratings[w] >= Judge.TOP - 0.001:
			top_used = true
	bar.max_v = Judge.TOP_CAP if top_used else 5.0
	bar.set_value(Game.human_ratings.get(who, 3.0))
	value_l.text = "%.1f" % bar.value
	top_l.text = ("4.6점 이상은 이미 다른 작품에 줬어요" if top_used else "4.6점 이상은 한 작품에만 줄 수 있어요")


func _rate(v: float) -> void:
	Game.human_ratings[order[idx]] = v
	value_l.text = "%.1f" % v


func _process(delta: float) -> void:
	if done:
		return
	pivot.rotation.y += delta * TAU / maxf(per, 0.1)
	t -= delta
	timer_l.text = "%d초" % ceili(maxf(t, 0))
	if Game.autotest:
		var who: int = order[idx]
		if who != 0 and not Game.human_ratings.has(who):
			bar.set_value(snappedf(Game.rng.randf_range(2.0, 4.4), 0.1))
			_rate(bar.value)
	if t <= 0:
		_next()


func _next() -> void:
	if done:
		return
	if idx + 1 < order.size():
		_show(idx + 1)
	else:
		done = true
		for w in Game.players.size():
			if w != 0 and not Game.human_ratings.has(w):
				Game.human_ratings[w] = 3.0
		Game.goto("settle")


## ←/→ 로 0.1씩 미세 조정, Enter = 다음 작품
func _unhandled_input(ev: InputEvent) -> void:
	if done or not (ev is InputEventKey) or not ev.pressed:
		return
	if not rate_box.visible:
		if ev.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_next()
		return
	var d := 0.0
	match ev.physical_keycode:
		KEY_LEFT, KEY_A: d = -0.1
		KEY_RIGHT, KEY_D: d = 0.1
		KEY_ENTER, KEY_KP_ENTER: _next()
	if d != 0.0:
		bar.set_value(snappedf(bar.value + d, 0.1))
		_rate(bar.value)
		UI.sfx("click", -14.0)


# ── 전시실 (갤러리) ──────────────────────────────────
var plaque: Label3D


func _gallery_set() -> void:
	# 어두운 전시실 · 흰 좌대(윗면 = 작품 자리) · 스포트라이트 · 이름표 · 차단봉
	for c in get_children():
		if c is WorldEnvironment:
			var env: Environment = (c as WorldEnvironment).environment
			env.ambient_light_energy = 0.22
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		if c is DirectionalLight3D:
			(c as DirectionalLight3D).light_energy = 0.15
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(40, 40)
	fl.mesh = pm
	fl.position.y = -1.0
	var flm := ShaderMaterial.new()
	flm.shader = load("res://assets/shaders/floor.gdshader")
	flm.set_shader_parameter("style", 0)
	flm.set_shader_parameter("col_a", Color("#5A4636"))
	flm.set_shader_parameter("col_b", Color("#4C3B2D"))
	flm.set_shader_parameter("gloss", 0.25)
	flm.set_shader_parameter("scale", 0.6)
	fl.material_override = flm
	add_child(fl)
	_gbox(Vector3(0, -0.5, 0), Vector3(1.9, 1.0, 1.9), Color("#F3F0EA"), 0.02)
	_gbox(Vector3(0, -0.02, 0), Vector3(2.0, 0.04, 2.0), Color("#FFFFFF"), 0.0)
	_gbox(Vector3(0, 1.5, -6.0), Vector3(16, 5.0, 0.2), Color("#3B3633"), 0.0)
	_gbox(Vector3(-7.0, 1.5, 0), Vector3(0.2, 5.0, 14), Color("#34302D"), 0.0)
	_gbox(Vector3(7.0, 1.5, 0), Vector3(0.2, 5.0, 14), Color("#34302D"), 0.0)
	# 뒤 벽 액자 (다른 작품들 분위기)
	for k in 3:
		_gbox(Vector3(-4.0 + k * 4.0, 1.4, -5.88), Vector3(1.4, 1.0, 0.04), Color("#C9A24A"), 0.0)
		_gbox(Vector3(-4.0 + k * 4.0, 1.4, -5.85), Vector3(1.2, 0.8, 0.02), [Color("#3E6B9A"), Color("#C94A4A"), Color("#5E9A5E")][k], 0.0)
	# 차단봉 + 줄
	for x in [-1.6, 1.6]:
		_gcyl(Vector3(x, -0.55, 1.7), 0.04, 0.9, Color("#C9A24A"))
	_gbox(Vector3(0, -0.2, 1.7), Vector3(3.2, 0.04, 0.04), Color("#8E2B2B"), 0.0)
	# 이름표 (좌대 앞에 기울어진 판)
	_gbox(Vector3(0.0, -0.2, 0.965), Vector3(0.9, 0.28, 0.02), Color("#E9E2D3"), 0.0)
	plaque = Label3D.new()
	plaque.font = Data.font_bold
	plaque.font_size = 22
	plaque.pixel_size = 0.0028
	plaque.modulate = Color("#2B2B2B")
	plaque.outline_size = 0
	plaque.position = Vector3(0.0, -0.2, 0.98)
	plaque.width = 300
	plaque.font_size = 20
	plaque.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plaque.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(plaque)
	# 스포트라이트 (위에서 좌대로)
	var l := SpotLight3D.new()
	l.light_color = Color("#FFEFD6")
	l.light_energy = 4.0
	l.spot_range = 9.0
	l.spot_angle = 22.0
	l.shadow_enabled = true
	add_child(l)
	l.look_at_from_position(Vector3(0.8, 4.2, 2.2), Vector3(0, 0.4, 0))
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.0, 1.6, 3.0)
	fill.light_energy = 0.35
	fill.omni_range = 8.0
	add_child(fill)


func _gbox(p: Vector3, s: Vector3, c: Color, r := 0.02, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	if r >= 0.012:
		mi.mesh = Data.rounded_box(s, r)
	else:
		var bm := BoxMesh.new()
		bm.size = s
		mi.mesh = bm
	mi.material_override = Data.brick(c, false, 0.25, 0.5)
	mi.position = p
	mi.rotation_degrees = rot
	add_child(mi)


func _gcyl(p: Vector3, r: float, h: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r; cm.bottom_radius = r; cm.height = h; cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = Data.brick(c, false, 0.25, 0.3)
	mi.position = p
	add_child(mi)


func _finish_text(work: Array) -> String:
	var seen := {}
	for d in work:
		seen[Data.FINISHES[int(d.get("f", 0))]] = true
	return " · ".join(seen.keys())
