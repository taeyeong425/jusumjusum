extends Node3D
## 조립 (3:30) — 축 없는 직접 조작.
##  · 덩어리 끌기 = 표면을 따라 이동 (부드럽게 따라온다)
##  · 손잡이 「크기」 = 전체 크기 (비율은 덩어리마다 고정 — 납작한 건 처음부터 납작하다)
##  · 색 고리 = 월드 X·Y·Z 축 회전 (v0.5, 트랙볼 폐기) · 색 네모 = 축별 늘이기
##  · 빈 곳 끌기 / 우클릭 끌기 = 시점 회전 · 휠 = 줌 · 가운데 버튼 = 시점 이동

const TABLE := 1.8
const UNDO_MAX := 30
const MIN_PIECES := 5
const KNOB_R := 20.0

var time_left := 210.0
var finished := false
var cam: Camera3D
var center := Vector3(0, 0.5, 0)
var center_t := Vector3(0, 0.5, 0)
var yaw := 0.55
var yaw_t := 0.55
var pitch := -0.5
var pitch_t := -0.5
var dist := 4.6
var dist_t := 4.6
var spin := false
var work_root: Node3D
var selected: Piece
var inventory: Array
var undo: Array = []
var redo: Array = []
var anim := {}               # Piece → 목표 위치 (부드럽게 다가간다)

var mode := ""               # "", "move", "size", "rot", "orbit?", "orbit", "pan"
var press_pos := Vector2.ZERO
var size0 := 1.0
var dist0 := 1.0
var pushed := false
var grab_off := Vector3.ZERO     # 잡은 지점 → 덩어리 중심 (수평)

var overlay: Control
var tray: VBoxContainer
var hud_time: Label
var hud_count: Label
var hud_card: Label
var hud_sel: Label
var spin_btn: Button
var warn: Label
var warn_t := 0.0
var title_edit: LineEdit
var placing := false          # 목록에서 꺼낸 덩어리를 들고 있는 중
var guides: Array = []        # 맞춤 안내선 [월드 a, 월드 b]
var snap_note := ""
var snap_t := 0.0
var magnet := false            # 자석 맞춤 (M) — 기본 끔
var magnet_btn: Button
var ring_axis := Vector3.ZERO   # 돌리는 중인 고리 축 (월드)
var ring_a0 := 0.0
var basis0 := Basis()
var st_axis := -1               # 늘이는 중인 로컬 축
var st0 := 1.0
var st_d0 := 1.0
var hover := ""                 # 손잡이 위 커서 (그리기 강조)


func _ready() -> void:
	time_left = Game.t_build()
	inventory = Game.human()["inventory"]
	UI.make_env(self, Color("#CFE6F2"))
	_build_room()
	work_root = Node3D.new()
	add_child(work_root)
	cam = Camera3D.new()
	cam.fov = 50
	add_child(cam)
	_build_hud()
	_refresh_tray()
	_update_cam(1.0)
	_open_ceremony()
	if Game.autotest:
		var w := BotBuilder.build(Game.target, inventory, 0.75, Game.rng)
		for d in w:
			work_root.add_child(Piece.from_dict(d))
		if work_root.get_child_count() > 0:
			_select(work_root.get_child(0))


func _build_room() -> void:
	# 조각가의 작업실: 나무 바닥 · ㄱ자 벽(판벽 · 창문) · 선반 · 이젤 · 점토 통 · 받침대(위가 작업대) · 스포트라이트
	var fl := MeshInstance3D.new()
	var fm := PlaneMesh.new(); fm.size = Vector2(30, 30)
	fl.mesh = fm
	fl.position.y = -0.9
	var flm := ShaderMaterial.new()
	flm.shader = load("res://assets/shaders/floor.gdshader")
	flm.set_shader_parameter("style", 0)
	flm.set_shader_parameter("col_a", Color("#B98A5E"))
	flm.set_shader_parameter("col_b", Color("#A47750"))
	flm.set_shader_parameter("scale", 0.5)
	fl.material_override = flm
	add_child(fl)
	# 받침대 (흰 좌대) + 검은 펠트 윗면 = 작업대
	_rb(Vector3(0, -0.5, 0), Vector3(TABLE * 2 + 0.1, 0.8, TABLE * 2 + 0.1), Color("#F1EEE8"), 0.03)
	_rb(Vector3(0, -0.06, 0), Vector3(TABLE * 2 + 0.16, 0.12, TABLE * 2 + 0.16), Color("#2E2B29"), 0.02)
	_rb(Vector3(0, -0.88, 0), Vector3(TABLE * 2 + 0.3, 0.06, TABLE * 2 + 0.3), Color("#D9D4CB"), 0.02)
	# 펠트 위 옅은 격자 (30cm 칸 · 가운데 십자는 진하게) — 줄 맞추기 · 가운데 찾기
	var gl := ArrayMesh.new()
	var gv := PackedVector3Array()
	var gc := PackedColorArray()
	var gk := -TABLE
	while gk <= TABLE + 0.001:
		var a := 0.32 if absf(gk) < 0.01 else 0.12
		for seg in [[Vector3(gk, 0.003, -TABLE), Vector3(gk, 0.003, TABLE)], [Vector3(-TABLE, 0.003, gk), Vector3(TABLE, 0.003, gk)]]:
			gv.append(seg[0]); gv.append(seg[1])
			gc.append(Color(1, 1, 1, a)); gc.append(Color(1, 1, 1, a))
		gk += 0.3
	var ga := []
	ga.resize(Mesh.ARRAY_MAX)
	ga[Mesh.ARRAY_VERTEX] = gv
	ga[Mesh.ARRAY_COLOR] = gc
	gl.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, ga)
	var gmi := MeshInstance3D.new()
	gmi.mesh = gl
	var gm := StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmi.material_override = gm
	gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gmi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(TABLE * 2, 0.2, TABLE * 2)
	cs.shape = sh
	cs.position.y = -0.1
	body.add_child(cs)
	add_child(body)
	var front := UI.label3d("정면", 28, Color("#E9E2D6"))
	front.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	front.rotation_degrees = Vector3(-90, 0, 0)
	front.position = Vector3(0, 0.005, TABLE - 0.18)
	add_child(front)
	# 벽 둘 (뒤 · 왼쪽) — 판벽 · 몰딩 · 창문
	var wc := Color("#EDE6DA")
	for w in [[Vector3(0, 1.6, -6.0), Vector3(14, 5.0, 0.2)], [Vector3(-6.0, 1.6, 0), Vector3(0.2, 5.0, 14)]]:
		_rb(w[0], w[1], wc, 0.0)
		var low: Vector3 = w[0] - Vector3(0, 1.8, 0)
		var lsz: Vector3 = w[1]
		var off := Vector3(0, 0, 0.11) if lsz.x > 1 else Vector3(0.11, 0, 0)
		_rb(low + off, Vector3(lsz.x if lsz.x > 1 else 0.03, 1.4, lsz.z if lsz.z > 1 else 0.03), wc.darkened(0.15), 0.0)
	var glass := StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_color = Color("#DDEFF8")
	for wx in [-2.5, 2.5]:
		var g := MeshInstance3D.new()
		g.mesh = _box_mesh(Vector3(2.0, 2.0, 0.02))
		g.material_override = glass
		g.position = Vector3(wx, 2.0, -5.88)
		add_child(g)
		_rb(Vector3(wx, 2.0, -5.86), Vector3(0.08, 2.1, 0.04), Color("#FFFFFF"), 0.0)
		_rb(Vector3(wx, 2.0, -5.86), Vector3(2.1, 0.08, 0.04), Color("#FFFFFF"), 0.0)
	# 선반 + 도구 (물감 통 · 붓 통 · 점토 덩어리)
	for sy in [0.8, 1.6]:
		_rb(Vector3(-5.7, sy, -2.5), Vector3(0.5, 0.05, 3.0), Color("#8A6A47"), 0.01)
		for k in 5:
			var cols := [Color("#C94A4A"), Color("#3E6B9A"), Color("#E9C46A"), Color("#5E9A5E"), Color("#F4F1EA")]
			_cy(Vector3(-5.65, sy + 0.12, -3.6 + k * 0.55), 0.1, 0.2, cols[(k + int(sy * 10)) % 5])
	# 이젤 + 스케치 (타겟 이름)
	_rb(Vector3(4.2, 0.2, -3.6), Vector3(0.06, 2.4, 0.06), Color("#8A6A47"), 0.0, Vector3(0, 0, -6))
	_rb(Vector3(5.2, 0.2, -3.6), Vector3(0.06, 2.4, 0.06), Color("#8A6A47"), 0.0, Vector3(0, 0, 6))
	_rb(Vector3(4.7, 0.95, -3.55), Vector3(1.3, 1.0, 0.03), Color("#FAF7F0"), 0.0)
	var sk := UI.label3d("「%s」\n스케치" % Game.target["name"], 30, Color("#5A4636"))
	sk.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sk.position = Vector3(4.7, 0.95, -3.52)
	add_child(sk)
	# 점토 통 · 의자 · 바닥 천
	_cy(Vector3(-3.8, -0.6, 3.6), 0.35, 0.6, Color("#9AA5AF"))
	_cy(Vector3(-3.8, -0.28, 3.6), 0.3, 0.1, Color("#B5763C"))
	_cy(Vector3(3.6, -0.55, 3.2), 0.25, 0.7, Color("#6E5743"))
	_rb(Vector3(3.6, -0.18, 3.2), Vector3(0.6, 0.06, 0.6), Color("#8A6A47"), 0.02)
	_rb(Vector3(0, -0.895, 0), Vector3(7.0, 0.01, 7.0), Color("#D8D1C4"), 0.0)
	# 참고 모형: 만들 물건의 작은 견본 (뒤쪽 작은 좌대 위, 천천히 돈다)
	_rb(Vector3(-2.9, -0.45, -2.9), Vector3(0.9, 0.9, 0.9), Color("#F3F0EA"), 0.02)
	var inv := []
	for t in Data.TYPES:
		for v in Data.VARIANTS[t]:
			inv.append(Data.make_item(t, v[1], 0, "auto"))
	var model := Node3D.new()
	model.position = Vector3(-2.9, 0.05, -2.9)
	model.scale = Vector3.ONE * 0.65
	add_child(model)
	var mrng := RandomNumberGenerator.new()
	mrng.seed = 7
	for d in BotBuilder.build(Game.target, inv, 1.0, mrng):
		model.add_child(Piece.from_dict(d, false))
	var mtw := create_tween().set_loops()
	mtw.tween_property(model, "rotation:y", TAU, 9.0).from(0.0)
	var ml := UI.label3d("참고 모형", 22, Color("#5A4636"))
	ml.position = Vector3(-2.9, 1.15, -2.9)
	add_child(ml)
	# 스포트라이트 둘 (따뜻한 빛, 받침대에 그림자)
	for sp in [[Vector3(3.5, 5.0, 3.0), Color("#FFE9C8")], [Vector3(-3.0, 5.0, 2.0), Color("#FFF4E6")]]:
		var l := SpotLight3D.new()
		l.position = sp[0]
		l.light_color = sp[1]
		l.light_energy = 2.2
		l.spot_range = 12.0
		l.spot_angle = 30.0
		l.shadow_enabled = true
		add_child(l)
		l.look_at_from_position(sp[0], Vector3(0, 0.3, 0))


func _box_mesh(s: Vector3) -> Mesh:
	var bm := BoxMesh.new()
	bm.size = s
	return bm


func _rb(p: Vector3, s: Vector3, c: Color, r := 0.02, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Data.rounded_box(s, r) if r >= 0.012 else _box_mesh(s)
	mi.material_override = Data.brick(c, false, 0.25, 0.6)
	mi.position = p
	mi.rotation_degrees = rot
	add_child(mi)


func _cy(p: Vector3, r: float, h: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r; cm.bottom_radius = r; cm.height = h; cm.radial_segments = 14
	mi.mesh = cm
	mi.material_override = Data.brick(c, false, 0.25, 0.5)
	mi.position = p
	add_child(mi)


# ── HUD ──────────────────────────────────────────────

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	layer.add_child(UI.full(overlay))

	var top := UI.panel()
	var tv := UI.hbox(24)
	top.add_child(tv)
	hud_time = UI.label("", 40, UI.INK, true)
	tv.add_child(hud_time)
	var tcol := UI.vbox(0)
	tv.add_child(tcol)
	tcol.add_child(UI.label("「%s」를 만들어라" % Game.target["name"], 30, UI.INK, true))
	tcol.add_child(UI.label("할당량 ★%.1f 이상 %d명 · 재료 %s" % [Game.quota[0], Game.quota[1], Game.formation], 20, UI.SOFT))
	var card: Dictionary = Game.human()["card"]
	var ccol := UI.vbox(0)
	tv.add_child(ccol)
	ccol.add_child(UI.label("카드 「%s」 %s" % [card["name"], card["desc"]], 21, UI.ACCENT))
	hud_card = UI.label("", 20, UI.SOFT)
	ccol.add_child(hud_card)
	# 출품 제목 — 전시회 이름표에 나온다
	title_edit = LineEdit.new()
	title_edit.placeholder_text = "작품 제목 (비우면 자동)"
	title_edit.custom_minimum_size = Vector2(260, 0)
	title_edit.max_length = 18
	title_edit.add_theme_font_size_override("font_size", 16)
	tv.add_child(title_edit)
	layer.add_child(top)
	UI.corner(top, Control.PRESET_CENTER_TOP, Vector2(0, 12))

	var left := UI.panel()
	var lv := UI.vbox(6)
	left.add_child(lv)
	lv.add_child(UI.label("모은 덩어리", 24, UI.INK, true))
	lv.add_child(UI.label("눌러서 작업대에 올리기", 18, UI.SOFT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(210, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(scroll)
	tray = UI.vbox(4)
	scroll.add_child(tray)
	hud_count = UI.label("", 20, UI.SOFT)
	lv.add_child(hud_count)
	layer.add_child(left)
	UI.corner(left, Control.PRESET_CENTER_LEFT)

	var right := UI.panel()
	var rv := UI.vbox(6)
	right.add_child(rv)
	rv.add_child(UI.label("색 (1~0 키)", 22, UI.INK, true))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 2)
	rv.add_child(grid)
	for i in 16:
		var b := Button.new()
		b.custom_minimum_size = Vector2(40, 30)
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Data.color(i) if st != "hover" else Data.color(i).lightened(0.15)
			sb.set_corner_radius_all(8)
			sb.border_color = UI.INK if st == "hover" else Color("#D5DADF")
			sb.set_border_width_all(2)
			b.add_theme_stylebox_override(st, sb)
		var ci := i
		b.pressed.connect(func(): _apply_color(ci))
		var cell := UI.vbox(0)
		cell.add_child(b)
		var nl := UI.label(Data.palette()[i]["name"], 12, UI.SOFT)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(nl)
		grid.add_child(cell)
	rv.add_child(UI.label("마감 (고른 것 / Shift = 전체)", 18, UI.INK, true))
	var fin := HFlowContainer.new()
	fin.add_theme_constant_override("h_separation", 4)
	fin.add_theme_constant_override("v_separation", 4)
	rv.add_child(fin)
	for fi in Data.FINISHES.size():
		var f_i := fi
		var fb := UI.button(Data.FINISHES[fi], func():
			if Input.is_key_pressed(KEY_SHIFT):
				_finish_all(f_i)
			else:
				_apply_finish(f_i), 15)
		fin.add_child(fb)
	var tools := GridContainer.new()
	tools.columns = 2
	tools.add_theme_constant_override("h_separation", 6)
	tools.add_theme_constant_override("v_separation", 6)
	rv.add_child(tools)
	tools.add_child(UI.button("왼쪽 45° (Q)", func(): _turn(-PI / 4), 18))
	tools.add_child(UI.button("오른쪽 45° (E)", func(): _turn(PI / 4), 18))
	tools.add_child(UI.button("똑바로 (T)", _straighten, 18))
	tools.add_child(UI.button("내리기 (Del)", _delete, 18))
	tools.add_child(UI.button("되돌리기", _undo, 18))
	spin_btn = UI.button("돌려보기", func(): spin = not spin, 18)
	tools.add_child(spin_btn)
	tools.add_child(UI.button("바닥에 붙이기 (G)", _drop_down, 18))
	tools.add_child(UI.button("옆에 딱 붙이기 (J)", _attach_nearest, 18))
	magnet_btn = UI.button("", _toggle_magnet, 18)
	tools.add_child(magnet_btn)
	_toggle_magnet(false)
	rv.add_child(UI.label("시점 (Tab)", 18, UI.INK, true))
	var vrow := UI.hbox(4)
	rv.add_child(vrow)
	for vi in VIEWS.size():
		var v_i := vi
		vrow.add_child(UI.button(str(VIEWS[vi][0]).replace("에서", "").replace("히", ""), func(): _set_view(v_i), 15))
	hud_sel = UI.label("", 18, UI.SOFT)
	hud_sel.custom_minimum_size.x = 220
	hud_sel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(hud_sel)
	layer.add_child(right)
	UI.corner(right, Control.PRESET_CENTER_RIGHT)

	var bottom := UI.panel()
	var bv := UI.hbox(14)
	bottom.add_child(bv)
	bv.add_child(UI.label("끌기 = 옮기기 (가까우면 딱 붙음, Alt = 안 붙게) · J = 옆에 딱 붙이기 · G = 아래에 붙이기 · 방향키 = 조금씩\n휠 · PageUp/Down = 높이 · 색 고리 = 회전 · 색 네모 = 늘이기 · Tab = 앞/옆/위 시점 · 빈 곳 끌기 = 시점", 17, UI.SOFT))
	bv.add_child(UI.primary("다 했다 →", _finish, 26))
	layer.add_child(bottom)
	UI.corner(bottom, Control.PRESET_CENTER_BOTTOM, Vector2(0, 12))

	warn = UI.label("", 26, UI.BAD, true)
	warn.add_theme_color_override("font_outline_color", Color.WHITE)
	warn.add_theme_constant_override("outline_size", 8)
	layer.add_child(warn)
	UI.corner(warn, Control.PRESET_CENTER_BOTTOM, Vector2(0, 120))


func _refresh_tray() -> void:
	for c in tray.get_children():
		c.queue_free()
	var used := {}
	for p in work_root.get_children():
		used[(p as Piece).inv_index] = true
	for i in inventory.size():
		if used.has(i):
			continue
		var it: Dictionary = inventory[i]
		var src: String = {"tear": "뜯음", "dig": "팜", "auto": "자동"}.get(it["origin"], "")
		var idx := i
		var row := Button.new()
		row.custom_minimum_size = Vector2(196, 48)
		row.focus_mode = Control.FOCUS_NONE
		row.pressed.connect(func(): _spawn(idx))
		UI.tile_button(row)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.position = Vector2(6, 4)
		icon.size = Vector2(40, 40)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.draw.connect(func(): UI.draw_chunk_icon(icon, it, Rect2(Vector2.ZERO, Vector2(40, 40))))
		row.add_child(icon)
		var l := UI.label("%s%s" % [it["name"], ("  · " + src) if src != "" else ""], 19)
		l.position = Vector2(52, 10)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l)
		tray.add_child(row)
	hud_count.text = "올린 것 %d / 모은 것 %d" % [work_root.get_child_count(), inventory.size()]


func _warn(s: String) -> void:
	warn.text = s
	warn_t = 2.2
	UI.sfx("error", -8.0)


# ── 작업 ─────────────────────────────────────────────

func _dicts() -> Array:
	var out := []
	for p in work_root.get_children():
		var pc := p as Piece
		var d := pc.to_dict()
		if anim.has(pc):
			d["p"] = anim[pc]
		out.append(d)
	return out


func _push_undo() -> void:
	undo.append(_dicts())
	if undo.size() > UNDO_MAX:
		undo.pop_front()
	redo.clear()
	Game.human()["edits"] += 1


func _restore(state: Array) -> void:
	var keep := selected.inv_index if selected else -1
	_select(null)
	anim.clear()
	for c in work_root.get_children():
		work_root.remove_child(c)
		c.queue_free()
	for d in state:
		var p := Piece.from_dict(d)
		work_root.add_child(p)
		if p.inv_index == keep:
			_select(p)
	_refresh_tray()
	UI.sfx("click", -8.0)


func _undo() -> void:
	if undo.is_empty():
		return
	redo.append(_dicts())
	_restore(undo.pop_back())


func _redo() -> void:
	if redo.is_empty():
		return
	undo.append(_dicts())
	_restore(redo.pop_back())


func _spawn(inv_i: int, from: Dictionary = {}) -> Piece:
	_push_undo()
	var it: Dictionary = inventory[inv_i]
	var p: Piece = Piece.from_item(it) if from.is_empty() else Piece.from_dict(from)
	p.inv_index = inv_i
	p.origin = it["origin"]
	work_root.add_child(p)
	var target: Vector3
	if from.is_empty():
		var off := Vector3(Game.rng.randf_range(-0.5, 0.5), 0, Game.rng.randf_range(-0.4, 0.4))
		target = _surface_point_above(p, off)
	else:
		target = from["p"]
	p.position = target + Vector3(0, 0.9, 0)
	anim[p] = target
	_select(p)
	_refresh_tray()
	UI.sfx("place", -4.0)
	# 들고 오기: 커서를 따라오다가 클릭한 곳에 놓인다 (빌드 게임식)
	if from.is_empty() and not Game.autotest:
		placing = true
		mode = "move"
		pushed = true
		grab_off = Vector3.ZERO
		_note("클릭해서 놓기 · 휠 = 높이")
	return p


func _surface_point_above(p: Piece, xz: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(xz.x, 6, xz.z), Vector3(xz.x, -1, xz.z), 0b11)
	if p.body:
		q.exclude = [p.body.get_rid()]
	var hit := space.intersect_ray(q)
	var y := 0.0
	if hit:
		y = hit["position"].y
	return Vector3(xz.x, y + p.world_half_extents().y, xz.z)


func _delete() -> void:
	if not selected:
		return
	_push_undo()
	var p := selected
	_select(null)
	anim.erase(p)
	work_root.remove_child(p)
	p.queue_free()
	_refresh_tray()
	UI.sfx("drop", -6.0)


func _apply_color(ci: int) -> void:
	if not selected:
		_warn("먼저 덩어리를 고르세요")
		return
	_push_undo()
	selected.set_color(ci)
	selected.set_highlight(true)
	UI.sfx("select", -10.0)


## 마감 재질 (플라스틱 · 대리석 · 청동 · 나무 · 금) — 전시회 조각상 느낌
func _apply_finish(f: int) -> void:
	if not selected:
		_warn("먼저 덩어리를 고르세요")
		return
	_push_undo()
	selected.set_finish(f)
	selected.set_highlight(true)
	UI.sfx("select", -10.0)
	_note("마감: " + Data.FINISHES[f])


## 모두에 같은 마감
func _finish_all(f: int) -> void:
	_push_undo()
	for p in work_root.get_children():
		(p as Piece).set_finish(f)
	if selected:
		selected.set_highlight(true)
	_note("전체 마감: " + Data.FINISHES[f])


func _turn(a: float) -> void:
	if not selected:
		return
	_push_undo()
	selected.basis = Basis(Vector3.UP, a) * selected.basis
	UI.sfx("select", -12.0)


func _straighten() -> void:
	if not selected:
		return
	_push_undo()
	selected.basis = Basis.IDENTITY
	UI.sfx("select", -12.0)


func _toggle_magnet(flip := true) -> void:
	if flip:
		magnet = not magnet
		_note("자석 맞춤 켬" if magnet else "자석 맞춤 끔")
	if magnet_btn:
		magnet_btn.text = "자석: %s (M)" % ("켬" if magnet else "끔")


func _select(p: Piece) -> void:
	if selected and is_instance_valid(selected):
		selected.set_highlight(false)
	selected = p
	if p:
		p.set_highlight(true)



# ── 입력 ─────────────────────────────────────────────

const AXIS_COL := [Color("#D9483B"), Color("#3E9E4F"), Color("#2F6FB5")]


func _knobs() -> Dictionary:
	if not selected:
		return {}
	var c := selected.global_position
	var h := selected.world_half_extents()
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				var p := c + Vector3(h.x * sx, h.y * sy, h.z * sz)
				if cam.is_position_behind(p):
					continue
				var s := cam.unproject_position(p)
				mn = mn.min(s)
				mx = mx.max(s)
	if mn.x == INF:
		return {}
	var vs := overlay.size
	var size_k := Vector2(mx.x + 16, mx.y + 16).clamp(Vector2(24, 24), vs - Vector2(24, 24))
	# 늘이기 손잡이: 덩어리 로컬 축(+) 방향 면 바깥
	var st := []
	var loc := Data.base_size(selected.type) * selected.pscale * 0.5
	for i in 3:
		var ax: Vector3 = selected.global_transform.basis[i].normalized()
		var wp := c + ax * (loc[i] + 0.14)
		st.append(cam.unproject_position(wp) if not cam.is_position_behind(wp) else Vector2(-999, -999))
	return {"rect": Rect2(mn, mx - mn), "size": size_k, "center": cam.unproject_position(c), "stretch": st}


## 회전 고리 (월드 X·Y·Z) — 화면 위 점들
func _ring_pts(axis: int) -> PackedVector2Array:
	var c := selected.global_position
	var h := selected.world_half_extents()
	var R := maxf(h.x, maxf(h.y, h.z)) * 1.25 + 0.18
	var a := Vector3.ZERO
	a[axis] = 1.0
	var u := Vector3.ZERO
	u[(axis + 1) % 3] = 1.0
	var v := a.cross(u)
	var pts := PackedVector2Array()
	for k in 49:
		var t := TAU * k / 48.0
		var wp := c + (u * cos(t) + v * sin(t)) * R
		pts.append(cam.unproject_position(wp))
	return pts


func _near_ring(pos: Vector2) -> int:
	if not selected:
		return -1
	var best := -1
	var bd := 9.0
	for axis in 3:
		var pts := _ring_pts(axis)
		for k in pts.size() - 1:
			var d := Geometry2D.get_closest_point_to_segment(pos, pts[k], pts[k + 1]).distance_to(pos)
			if d < bd:
				bd = d
				best = axis
	return best


## 잡고 끄는 중(또는 R · V 키) 휠 = 높이만 위아래 (폴아웃 4식). 그 밖엔 줌
func _wheel_height(dy: float) -> bool:
	if mode != "move" or not selected:
		return false
	if not pushed:
		_push_undo()
		pushed = true
	var cur: Vector3 = anim.get(selected, selected.position)
	cur.y = clampf(cur.y + dy, -0.2, 3.5)
	anim[selected] = cur
	_note("높이 %.2f" % cur.y)
	return true


## 고른 덩어리 아래로 바닥까지 안내선 + 그림자 점 + 높이 숫자 — 공중에 뜬 높이를 읽게
func _draw_height_guide() -> void:
	if not selected:
		return
	var c := selected.global_position
	var hh := selected.world_half_extents()
	var bottom := c - Vector3(0, hh.y, 0)
	var q := PhysicsRayQueryParameters3D.create(bottom + Vector3(0, -0.01, 0), bottom + Vector3(0, -6, 0), 0b11)
	if selected.body:
		q.exclude = [selected.body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var ground := Vector3(c.x, -0.1, c.z)
	if hit:
		ground = hit["position"]
	if cam.is_position_behind(bottom) or cam.is_position_behind(ground):
		return
	var a := cam.unproject_position(bottom)
	var b := cam.unproject_position(ground)
	var gap := bottom.y - ground.y
	if gap > 0.02:
		overlay.draw_dashed_line(a, b, Color("#E2553D"), 2.0, 6.0)
	# 바닥의 그림자 점 (눌린 타원)
	var pts := PackedVector2Array()
	for i in 20:
		var t := TAU * i / 20.0
		pts.append(cam.unproject_position(ground + Vector3(cos(t) * hh.x, 0.005, sin(t) * hh.z)))
	overlay.draw_colored_polygon(pts, Color(0.1, 0.1, 0.1, 0.18))
	if gap > 0.02:
		overlay.draw_string(Data.font_bold, b + Vector2(8, -4), "높이 %.2f" % gap, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#E2553D"))


func _draw_overlay() -> void:
	_draw_height_guide()
	for g in guides:
		if cam.is_position_behind(g[0]) or cam.is_position_behind(g[1]):
			continue
		overlay.draw_dashed_line(cam.unproject_position(g[0]), cam.unproject_position(g[1]), Color("#3FA7D6"), 2.5, 8.0)
	var k := _knobs()
	if k.is_empty():
		return
	var r: Rect2 = k["rect"]
	overlay.draw_rect(r.grow(6), Color(UI.ACCENT, 0.35), false, 1.5)
	# 회전 고리
	for axis in 3:
		var on := hover == "ring%d" % axis or (mode == "ring" and ring_axis[axis] > 0.5)
		overlay.draw_polyline(_ring_pts(axis), Color(AXIS_COL[axis], 0.95 if on else 0.6), 4.0 if on else 2.2, true)
	# 늘이기 손잡이 (색 네모)
	var st: Array = k["stretch"]
	for i in 3:
		var p: Vector2 = st[i]
		if p.x < -900:
			continue
		var on := hover == "st%d" % i or (mode == "stretch" and st_axis == i)
		var s := 9.0 if on else 7.0
		overlay.draw_line(k["center"], p, Color(AXIS_COL[i], 0.4), 1.5)
		overlay.draw_rect(Rect2(p - Vector2(s, s), Vector2(s, s) * 2), AXIS_COL[i])
		overlay.draw_rect(Rect2(p - Vector2(s, s), Vector2(s, s) * 2), Color.WHITE, false, 1.5)
	# 크기 손잡이
	var sp: Vector2 = k["size"]
	var act := mode == "size" or hover == "size"
	overlay.draw_circle(sp, KNOB_R, Color("#FFF8EC") if not act else Color("#FFE3A8"))
	overlay.draw_arc(sp, KNOB_R, 0, TAU, 28, UI.ACCENT, 2.5)
	overlay.draw_string(Data.font_bold, sp + Vector2(-KNOB_R, 6), "크기", HORIZONTAL_ALIGNMENT_CENTER, KNOB_R * 2, 15, UI.INK)
	if snap_t > 0.0 and snap_note != "":
		var tp := r.position + Vector2(r.size.x * 0.5 - 90, r.size.y + 34)
		overlay.draw_rect(Rect2(tp - Vector2(0, 18), Vector2(180, 26)), Color(1, 1, 1, 0.85 * minf(1.0, snap_t * 3)))
		overlay.draw_string(Data.font_bold, tp, snap_note, HORIZONTAL_ALIGNMENT_CENTER, 180, 17, Color("#2F7FA8", minf(1.0, snap_t * 3)))


## 커서 아래 손잡이 이름 ("size" · "st0~2" · "ring0~2" · "")
func _handle_at(pos: Vector2) -> String:
	var k := _knobs()
	if k.is_empty():
		return ""
	if pos.distance_to(k["size"]) < KNOB_R + 4:
		return "size"
	var st: Array = k["stretch"]
	for i in 3:
		if pos.distance_to(st[i]) < 13.0:
			return "st%d" % i
	var ra := _near_ring(pos)
	if ra >= 0:
		return "ring%d" % ra
	return ""


func _ray_piece(mouse: Vector2) -> Dictionary:
	var from := cam.project_ray_origin(mouse)
	var to := from + cam.project_ray_normal(mouse) * 50
	var q := PhysicsRayQueryParameters3D.create(from, to, Piece.LAYER_PIECE)
	return get_world_3d().direct_space_state.intersect_ray(q)


## 끌기: 커서가 가리키는 곳에 놓는다.
##  · 다른 덩어리 윗면/책상 → 그 위에 얹는다 (잡은 지점 유지)
##  · 다른 덩어리 옆면 → 그 면에 딱 붙인다 (면과 면이 만난다)
##  · 근처 덩어리와 가운데·모서리가 거의 맞으면 자석처럼 맞춘다 (Alt = 보정 끄기)
## 끌기 (v0.5): 기본은 자유 — 지금 높이의 수평면 위에서 옮긴다. 공중에 띄우기 · 겹치기 OK.
## 자석(M)을 켜면 예전처럼 표면에 얹기 · 옆면 붙이기 · 줄 맞춤.
func _snap_target(mouse: Vector2) -> Vector3:
	if magnet:
		return _magnet_target(mouse)
	var cur: Vector3 = anim.get(selected, selected.position)
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	if absf(dir.y) < 0.02:
		return cur
	var t := (cur.y - from.y) / dir.y
	if t < 0:
		return cur
	var p := from + dir * t + grab_off
	return Vector3(clampf(p.x, -TABLE - 0.6, TABLE + 0.6), cur.y, clampf(p.z, -TABLE - 0.6, TABLE + 0.6))


## 그 자리 바로 아래 가장 높은 면 위로 내려 붙인다 (G)
func _drop_down() -> void:
	if not selected:
		return
	_push_undo()
	var cur: Vector3 = anim.get(selected, selected.position)
	var h := selected.world_half_extents()
	var space := get_world_3d().direct_space_state
	var top := 0.0
	for off in [Vector3.ZERO, Vector3(h.x * 0.6, 0, 0), Vector3(-h.x * 0.6, 0, 0), Vector3(0, 0, h.z * 0.6), Vector3(0, 0, -h.z * 0.6)]:
		var from: Vector3 = Vector3(cur.x, cur.y - h.y + 0.01, cur.z) + off
		var dq := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -9, 0), 0b11)
		dq.exclude = [selected.body.get_rid()]
		var dh := space.intersect_ray(dq)
		if dh:
			top = maxf(top, dh["position"].y)
	anim[selected] = Vector3(cur.x, top + h.y, cur.z)
	UI.sfx("place", -8.0)


func _magnet_target(mouse: Vector2) -> Vector3:
	var cur: Vector3 = anim.get(selected, selected.position)
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 50, 0b11)
	q.exclude = [selected.body.get_rid()]
	var hit := space.intersect_ray(q)
	var free := false
	var h := selected.world_half_extents()
	guides = []
	var p: Vector3
	if hit:
		p = hit["position"]
		var n: Vector3 = hit["normal"]
		if absf(n.y) < 0.5 and hit["collider"].has_meta("piece"):
			return _side_attach(hit["collider"].get_meta("piece"), p, n, h, free)
	else:
		if absf(dir.y) < 0.001:
			return cur
		var t := -from.y / dir.y
		if t < 0:
			return cur
		p = from + dir * t
	var xz := Vector3(p.x, 0, p.z) + grab_off
	if not free:
		xz = _align_xz(xz, h)
	xz.x = clampf(xz.x, -TABLE, TABLE)
	xz.z = clampf(xz.z, -TABLE, TABLE)
	# 그 자리 바로 아래 가장 높은 면 위에 얹는다
	var top := 0.0
	for off in [Vector3.ZERO, Vector3(h.x * 0.6, 0, 0), Vector3(-h.x * 0.6, 0, 0), Vector3(0, 0, h.z * 0.6), Vector3(0, 0, -h.z * 0.6)]:
		var dq := PhysicsRayQueryParameters3D.create(xz + off + Vector3(0, 8, 0), xz + off + Vector3(0, -1, 0), 0b11)
		dq.exclude = [selected.body.get_rid()]
		var dh := space.intersect_ray(dq)
		if dh:
			top = maxf(top, dh["position"].y)
	return Vector3(xz.x, top + h.y, xz.z)


## 옆면에 붙이기: 맞닿는 축은 딱 붙이고, 나머지 축은 가운데·밑면·윗면 맞춤
func _side_attach(other: Piece, p: Vector3, n: Vector3, h: Vector3, free: bool) -> Vector3:
	var oc := other.global_position
	var oh := other.world_half_extents()
	var ax := 0 if absf(n.x) >= absf(n.z) else 2
	var sx := signf(n.x) if ax == 0 else signf(n.z)
	var out := p
	out[ax] = oc[ax] + sx * (oh[ax] + h[ax] - 0.004)
	var bx := 2 - ax
	var y := maxf(p.y, h.y)
	if not free:
		var tol := 0.12
		if absf(out[bx] - oc[bx]) < tol + oh[bx] * 0.25:
			out[bx] = oc[bx]
			_guide(oc, out)
		for cand in [oc.y - oh.y + h.y, oc.y, oc.y + oh.y - h.y]:   # 밑면 맞춤 우선
			if absf(y - cand) < tol:
				y = cand
				break
		y = maxf(y, h.y)
		_note("면 붙이기")
	out.y = y
	out.x = clampf(out.x, -TABLE, TABLE)
	out.z = clampf(out.z, -TABLE, TABLE)
	return out


## 위에 얹을 때: 근처 덩어리와 가운데·모서리 줄 맞춤
func _align_xz(xz: Vector3, h: Vector3) -> Vector3:
	var tol := 0.07
	for axis in [0, 2]:
		var best := INF
		var val: float = xz[axis]
		var hit: Piece = null
		for o in work_root.get_children():
			if o == selected or not (o is Piece):
				continue
			var oc: Vector3 = anim.get(o, (o as Piece).position)
			var oh := (o as Piece).world_half_extents()
			for pair in [[oc[axis], xz[axis]], [oc[axis] - oh[axis], xz[axis] - h[axis]], [oc[axis] + oh[axis], xz[axis] + h[axis]]]:
				var d: float = pair[0] - pair[1]
				if absf(d) < tol and absf(d) < absf(best):
					best = d
					hit = o
		if hit != null:
			val += best
			var g := Vector3(xz.x, 0, xz.z)
			g[axis] = val
			_guide(hit.global_position, g + Vector3(0, selected.position.y, 0))
		xz[axis] = val
	return xz


## 맞닿기: 다른 덩어리 면에서 tol 안쪽(살짝 겹친 것도)이면 면과 면이 딱 맞게. 나머지 축 가운데도 거의 맞으면 맞춘다
func _contact_snap(p: Vector3, tol: float) -> Vector3:
	if not selected:
		return p
	var h := selected.world_half_extents()
	var best_d := INF
	var best_ax := -1
	var best_o: Piece = null
	for o in work_root.get_children():
		if o == selected or not (o is Piece):
			continue
		var oc: Vector3 = anim.get(o, (o as Piece).position)
		var oh := (o as Piece).world_half_extents()
		for ax in 3:
			var ok := true
			for b in 3:
				if b != ax and absf(p[b] - oc[b]) > h[b] + oh[b] - 0.02:
					ok = false   # 그 축에서 서로 안 겹치면 맞닿을 면이 없다
			if not ok:
				continue
			var sgn := signf(p[ax] - oc[ax]) if absf(p[ax] - oc[ax]) > 0.001 else 1.0
			var touch: float = oc[ax] + sgn * (oh[ax] + h[ax])
			var diff: float = touch - p[ax]
			# 밖에서 다가오는 중(diff<0) 또는 살짝 파묻힌(diff>0) 것만 — 깊이 겹친 건 일부러 그런 것
			if absf(diff) < tol and absf(diff) < absf(best_d):
				best_d = diff
				best_ax = ax
				best_o = o
	if best_o == null:
		return p
	var out := p
	out[best_ax] += best_d
	var oc2: Vector3 = anim.get(best_o, best_o.position)
	for b in 3:   # 옆 축 가운데 맞춤 (거의 맞을 때만)
		if b != best_ax and b != 1 and absf(out[b] - oc2[b]) < 0.06:
			out[b] = oc2[b]
	out.y = maxf(out.y, h.y - 0.2)
	_guide(oc2, out)
	if snap_note != "딱 붙음" or snap_t <= 0.0:
		UI.sfx("tick", -16.0)
	_note("딱 붙음")
	return out


## J: 가장 가까운 덩어리 쪽으로 미끄러져 면에 붙는다 (대충 옆에 두고 누르기)
func _attach_nearest() -> void:
	if not selected:
		_warn("붙일 덩어리를 먼저 고르세요")
		return
	var p: Vector3 = anim.get(selected, selected.position)
	var h := selected.world_half_extents()
	var best := INF
	var target := p
	for o in work_root.get_children():
		if o == selected or not (o is Piece):
			continue
		var oc: Vector3 = anim.get(o, (o as Piece).position)
		var oh := (o as Piece).world_half_extents()
		# 가장 가까운 축 하나로 다가간다 (나머지 축은 겹치게 끌어온다)
		var gap := Vector3.ZERO
		for ax in 3:
			gap[ax] = absf(p[ax] - oc[ax]) - (h[ax] + oh[ax])
		var ax_m := 0
		for ax in 3:
			if gap[ax] > gap[ax_m]:
				ax_m = ax
		var cand := p
		var sgn := signf(p[ax_m] - oc[ax_m]) if absf(p[ax_m] - oc[ax_m]) > 0.001 else 1.0
		cand[ax_m] = oc[ax_m] + sgn * (oh[ax_m] + h[ax_m])
		for b in 3:
			if b != ax_m and absf(cand[b] - oc[b]) > h[b] + oh[b] - 0.05:
				cand[b] = oc[b] + signf(cand[b] - oc[b]) * (h[b] + oh[b] - 0.05)
			if b != ax_m and b != 1 and absf(cand[b] - oc[b]) < 0.12:
				cand[b] = oc[b]
		var d := cand.distance_to(p)
		if d < best:
			best = d
			target = cand
	if best == INF:
		_warn("붙일 다른 덩어리가 없어요")
		return
	_push_undo()
	target.y = maxf(target.y, h.y)
	anim[selected] = target
	UI.sfx("place", -8.0)
	_note("딱 붙이기")


func _guide(a: Vector3, b: Vector3) -> void:
	guides.append([a, b])


func _note(s: String) -> void:
	snap_note = s
	snap_t = 0.8


## 크기: 옆·아래 덩어리와 너비/높이가 거의 같으면 딱 맞추고, 0.5배 단위 근처면 거기 맞춘다
func _snap_size(k: float) -> float:
	if not magnet:
		return k
	var h1 := selected.world_half_extents() / maxf(selected.size, 0.001)   # 크기 1배일 때 반폭
	var best_k := k
	var best_err := 0.06
	var msg := ""
	var me := selected.global_position
	for o in work_root.get_children():
		if o == selected or not (o is Piece):
			continue
		var op := o as Piece
		if op.global_position.distance_to(me) > 1.6:
			continue
		var oh := op.world_half_extents()
		for a in 3:
			if h1[a] < 0.01:
				continue
			var kk: float = oh[a] / h1[a]
			var err := absf(kk - k) / k
			if err < best_err:
				best_err = err
				best_k = kk
				msg = "%s에 %s 맞춤" % [Data.variant_name(op.type, op.shape), ["너비", "높이", "깊이"][a]]
	if msg == "":
		var r := snappedf(k, 0.5)
		if absf(r - k) < 0.04:
			best_k = r
			msg = "%.1f배" % r
	if msg != "":
		_note(msg)
	return best_k


## 회전을 놓을 때: 반듯한 방향(90° 단위)에 가까우면 딱 맞춘다
func _snap_rotation() -> void:
	if not selected or not magnet:
		return
	var b := selected.basis.orthonormalized()
	var cols := []
	var used := {}
	for i in 3:
		var v: Vector3 = b[i]
		var ax := v.abs().max_axis_index()
		if used.has(ax):
			return
		used[ax] = true
		var c := Vector3.ZERO
		c[ax] = signf(v[ax])
		cols.append(c)
	var nb := Basis(cols[0], cols[1], cols[2])
	if nb.determinant() < 0:
		return
	var diff := (nb.inverse() * b).get_rotation_quaternion().get_angle()
	if diff > 0.001 and diff < deg_to_rad(12):
		var tw := create_tween()
		tw.tween_method(func(t: float): selected.basis = b.slerp(nb, t), 0.0, 1.0, 0.12)
		_note("반듯하게")


func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_press(mb.position)
			MOUSE_BUTTON_RIGHT:
				if mb.pressed:
					mode = "orbit"
			MOUSE_BUTTON_MIDDLE:
				if mb.pressed:
					mode = "pan"
			MOUSE_BUTTON_WHEEL_UP:
				if not _wheel_height(0.04):
					dist_t = maxf(1.6, dist_t * 0.88)
			MOUSE_BUTTON_WHEEL_DOWN:
				if not _wheel_height(-0.04):
					dist_t = minf(10.0, dist_t * 1.12)
	elif event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_PAGEUP, KEY_PAGEDOWN]:
		_nudge(event as InputEventKey)   # 꾹 누르면 계속
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event as InputEventKey)


func _input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseButton and not event.pressed:
		if mode == "orbit?" and event.button_index == MOUSE_BUTTON_LEFT:
			_select(null)   # 빈 곳을 그냥 클릭 = 선택 해제
		if mode == "move":
			UI.sfx("place", -10.0)
		if mode == "ring":
			_snap_rotation()
		guides = []
		mode = ""
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		match mode:
			"move":
				if not pushed:
					_push_undo()
					pushed = true
				if Input.is_key_pressed(KEY_SHIFT):
					# 높이만: 띄우거나 파묻기
					var cur: Vector3 = anim.get(selected, selected.position)
					cur.y = clampf(cur.y - mm.relative.y * dist * 0.0022, -0.2, 3.5)
					anim[selected] = cur
				else:
					var tp := _snap_target(mm.position)
					if not magnet and not Input.is_key_pressed(KEY_ALT):
						tp = _contact_snap(tp, 0.1)
					anim[selected] = tp
			"size":
				var k := _knobs()
				if not k.is_empty():
					var c: Vector2 = k["center"]
					var d := maxf(4.0, mm.position.distance_to(c))
					selected.set_size(size0 * d / dist0)
					selected.set_size(_snap_size(selected.size))
			"ring":
				# 고리를 따라 돌린 각도만큼 그 축으로. 축이 나를 향하면 화면 반시계 = +
				var k := _knobs()
				if not k.is_empty():
					var a := (mm.position - (k["center"] as Vector2)).angle()
					var da := wrapf(a - ring_a0, -PI, PI)
					var toward := ring_axis.dot(cam.global_position - selected.global_position) > 0.0
					var ang := -da if toward else da
					if magnet:
						ang = snappedf(ang, PI / 12)
					selected.basis = (Basis(ring_axis, ang) * basis0).orthonormalized()
					_note("%d°" % roundi(rad_to_deg(ang)))
			"stretch":
				var k2 := _knobs()
				if not k2.is_empty():
					var dir: Vector2 = ((k2["stretch"][st_axis] as Vector2) - (k2["center"] as Vector2)).normalized()
					var d := (mm.position - (k2["center"] as Vector2)).dot(dir)
					var f := st0 * maxf(0.05, d) / st_d0
					if magnet:
						f = snappedf(f, 0.25)
					selected.set_stretch(st_axis, f)
					_note("%s %.2f배" % [["가로", "세로", "깊이"][st_axis], selected.stretch[st_axis]])
			"":
				var hv := _handle_at(mm.position)
				if hv != hover:
					hover = hv
			"orbit?":
				if mm.position.distance_to(press_pos) > 5.0:
					mode = "orbit"
			"orbit":
				yaw_t -= mm.relative.x * 0.008
				pitch_t = clampf(pitch_t - mm.relative.y * 0.006, -1.45, 0.25)
			"pan":
				var r := cam.global_transform.basis.x
				var u := cam.global_transform.basis.y
				center_t += (-r * mm.relative.x + u * mm.relative.y) * dist * 0.0016


func _press(pos: Vector2) -> void:
	press_pos = pos
	if placing:
		placing = false
		mode = ""
		UI.sfx("place", -6.0)
		return
	var hd := _handle_at(pos)
	if hd != "":
		_push_undo()
		var k := _knobs()
		if hd == "size":
			mode = "size"
			size0 = selected.size
			dist0 = maxf(4.0, pos.distance_to(k["center"]))
		elif hd.begins_with("st"):
			mode = "stretch"
			st_axis = int(hd.substr(2))
			st0 = selected.stretch[st_axis]
			var dir: Vector2 = (k["stretch"][st_axis] as Vector2) - (k["center"] as Vector2)
			st_d0 = maxf(8.0, (pos - (k["center"] as Vector2)).dot(dir.normalized()))
		else:
			mode = "ring"
			var ax := int(hd.substr(4))
			ring_axis = Vector3.ZERO
			ring_axis[ax] = 1.0
			basis0 = selected.basis
			ring_a0 = (pos - (k["center"] as Vector2)).angle()
		return
	var hit := _ray_piece(pos)
	if hit and hit["collider"].has_meta("piece"):
		var p: Piece = hit["collider"].get_meta("piece")
		if p != selected:
			UI.sfx("select", -12.0)
		_select(p)
		mode = "move"
		pushed = false
		# 잡은 지점 → 중심 (덩어리 중심 높이의 수평면 기준) — 잡는 순간 안 튄다
		var from := cam.project_ray_origin(pos)
		var dir := cam.project_ray_normal(pos)
		var cy := p.global_position.y
		if absf(dir.y) > 0.02:
			var ph := from + dir * ((cy - from.y) / dir.y)
			grab_off = Vector3(p.global_position.x - ph.x, 0, p.global_position.z - ph.z)
		else:
			grab_off = Vector3.ZERO
		if magnet:
			var hp: Vector3 = hit["position"]
			grab_off = Vector3(p.global_position.x - hp.x, 0, p.global_position.z - hp.z)
	else:
		mode = "orbit?"


func _key(k: InputEventKey) -> void:
	if ceremony:
		match k.physical_keycode:
			KEY_SPACE: _open_next()
			KEY_A:
				for i in 30:
					_open_next()
			KEY_ENTER, KEY_KP_ENTER:
				if cer_envs.is_empty():
					_close_ceremony()
		return
	var ctrl := k.ctrl_pressed or k.meta_pressed
	match k.physical_keycode:
		KEY_Q: _turn(-PI / 4)
		KEY_E: _turn(PI / 4)
		KEY_T: _straighten()
		KEY_G: _drop_down()
		KEY_R:
			if selected:
				_push_undo()
				var c: Vector3 = anim.get(selected, selected.position)
				anim[selected] = c + Vector3(0, 0.05, 0)
		KEY_V:
			if selected:
				_push_undo()
				var c2: Vector3 = anim.get(selected, selected.position)
				anim[selected] = c2 - Vector3(0, 0.05, 0)
		KEY_M: _toggle_magnet()
		KEY_J: _attach_nearest()
		KEY_TAB: _next_view()
		KEY_Z:
			if ctrl:
				if k.shift_pressed: _redo()
				else: _undo()
		KEY_Y:
			if ctrl: _redo()
		KEY_DELETE, KEY_BACKSPACE: _delete()
		KEY_F:
			if selected:
				center_t = selected.global_position
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			_apply_color(k.physical_keycode - KEY_1)
		KEY_0: _apply_color(9)


## 방향키 = 고른 덩어리를 화면 기준으로 조금씩 (Shift = 크게) · PageUp/Down = 높이
func _nudge(k: InputEventKey) -> void:
	if not selected or ceremony:
		return
	var step := 0.2 if k.shift_pressed else 0.05
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var rt := Vector3(-fwd.z, 0, fwd.x)
	var d := Vector3.ZERO
	match k.physical_keycode:
		KEY_UP: d = fwd
		KEY_DOWN: d = -fwd
		KEY_LEFT: d = -rt
		KEY_RIGHT: d = rt
		KEY_PAGEUP: d = Vector3.UP
		KEY_PAGEDOWN: d = Vector3.DOWN
	if not k.echo:
		_push_undo()
	var c: Vector3 = anim.get(selected, selected.position)
	var n := c + d * step
	n.x = clampf(n.x, -TABLE, TABLE)
	n.z = clampf(n.z, -TABLE, TABLE)
	n.y = maxf(n.y, -0.2)
	anim[selected] = n


## 시점 바로가기: 앞 · 옆 · 위 · 비스듬 (Tab = 다음)
const VIEWS := [["앞에서", 0.0, -0.12], ["옆에서", PI / 2, -0.12], ["위에서", 0.0, -1.45], ["비스듬히", 0.55, -0.5]]
var view_i := 3
func _set_view(i: int) -> void:
	view_i = i
	spin = false
	yaw_t = float(VIEWS[i][1])
	pitch_t = float(VIEWS[i][2])
	center_t = Vector3(0, 0.5, 0) if not selected else Vector3(0, selected.global_position.y, 0)
	_note("시점: " + str(VIEWS[i][0]))


func _next_view() -> void:
	_set_view((view_i + 1) % VIEWS.size())


## 고른 덩어리 바로 아래 표면에 그림자 — 공중 높이 · 앞뒤 위치가 한눈에
var sel_shadow: MeshInstance3D
func _update_sel_shadow() -> void:
	if sel_shadow == null:
		sel_shadow = MeshInstance3D.new()
		var q := PlaneMesh.new()
		q.size = Vector2(1, 1)
		sel_shadow.mesh = q
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.5))
		g.set_color(1, Color(0, 0, 0, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		sel_shadow.material_override = m
		sel_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sel_shadow)
	if not selected or not is_instance_valid(selected):
		sel_shadow.visible = false
		return
	var p := selected.global_position
	var q := PhysicsRayQueryParameters3D.create(p, p + Vector3(0, -4, 0), 1 | Piece.LAYER_PIECE)
	if selected.body:
		q.exclude = [selected.body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		sel_shadow.visible = false
		return
	var hp: Vector3 = hit["position"]
	var gap := p.y - hp.y
	sel_shadow.visible = gap > 0.05
	sel_shadow.global_position = hp + Vector3(0, 0.004, 0)
	var r := maxf(selected.pscale.x, selected.pscale.z) * 0.5 * clampf(1.2 - gap * 0.3, 0.5, 1.2)
	sel_shadow.scale = Vector3(r, 1, r)


# ── 진행 ─────────────────────────────────────────────

func _update_cam(f: float) -> void:
	yaw = lerp_angle(yaw, yaw_t, f)
	pitch = lerpf(pitch, pitch_t, f)
	dist = lerpf(dist, dist_t, f)
	center = center.lerp(center_t, f)
	var b := Basis.from_euler(Vector3(pitch, yaw, 0))
	cam.position = center + b * Vector3(0, 0, dist)
	cam.look_at(center)


func _process(delta: float) -> void:
	if finished:
		return
	if ceremony == null:
		time_left -= delta   # 개봉식 동안엔 시간이 안 간다
	if spin:
		yaw_t += delta * 0.9
	_update_cam(1.0 - exp(-10.0 * delta))
	var f := 1.0 - exp(-20.0 * delta)
	for p in anim.keys():
		if not is_instance_valid(p):
			anim.erase(p)
			continue
		var t: Vector3 = anim[p]
		(p as Piece).position = (p as Piece).position.lerp(t, f)
		if mode != "move" and (p as Piece).position.distance_to(t) < 0.002:
			(p as Piece).position = t
			anim.erase(p)
	snap_t -= delta
	_update_sel_shadow()
	overlay.queue_redraw()
	hud_time.text = UI.clock(time_left)
	hud_time.add_theme_color_override("font_color", UI.BAD if time_left < 30 else UI.INK)
	var dicts := _dicts()
	var card: Dictionary = Game.human()["card"]
	var ok := Judge.card_constraint(card, dicts, inventory.size(), Game.human().get("hunt", {}))
	hud_card.text = "카드 조건 충족! (+0.5점)" if ok else "카드 조건 아직 (덩어리 3개 이상 + 조건)"
	hud_card.add_theme_color_override("font_color", UI.GOOD if ok else UI.SOFT)
	spin_btn.text = "멈추기" if spin else "돌려보기"
	if selected:
		hud_sel.text = "%s · 크기 %.1f배%s\n색 %s" % [Data.variant_name(selected.type, selected.shape), selected.size, ("" if selected.stretch.is_equal_approx(Vector3.ONE) else " · 늘임 %.1f×%.1f×%.1f" % [selected.stretch.x, selected.stretch.y, selected.stretch.z]), Data.palette()[selected.color_idx]["name"]]
	else:
		hud_sel.text = "덩어리를 클릭해서 고르세요"
	warn_t -= delta
	if warn_t <= 0:
		warn.text = ""
	if time_left <= 0:
		_finish(true)


func _finish(forced := false) -> void:
	if finished:
		return
	if not forced and work_root.get_child_count() < MIN_PIECES:
		_warn("최소 %d개는 올려야 낼 수 있어요" % MIN_PIECES)
		return
	finished = true
	_select(null)
	Game.human()["work"] = Judge.settle_work(_dicts())
	var tt := title_edit.text.strip_edges() if title_edit else ""
	Game.human()["title"] = tt if tt != "" else Themes.auto_title(Game.target["name"], Game.rng)
	for i in range(1, Game.players.size()):
		var p: Dictionary = Game.players[i]
		p["work"] = BotBuilder.build(Game.target, p["inventory"], p["quality"], Game.rng)
		p["edits"] = Game.rng.randi_range(4, 40)
		p["title"] = Themes.auto_title(Game.target["name"], Game.rng)
		# 봇도 가끔 마감 재질을 고른다 (전시회 느낌)
		if Game.rng.randf() < 0.45:
			var fz := Game.rng.randi_range(1, Data.FINISHES.size() - 1)
			for d in p["work"]:
				if Game.rng.randf() < 0.7:
					d["f"] = fz
	UI.sfx("whoosh", -6.0)
	Game.goto("exhibit")


# ── 시나리오 테스트 (--scenario=build): 면 붙이기 · 크기 맞춤 수치 확인 ──
func run_scenario(_sc: String) -> void:
	await get_tree().process_frame
	time_left = 999.0
	var a := _spawn(0)
	var b := _spawn(1)
	a.set_size(1.4)
	a.position = Vector3(0, a.world_half_extents().y, 0)
	anim.erase(a)
	b.set_size(0.8)
	await get_tree().physics_frame
	await get_tree().physics_frame
	selected = b
	var ah := a.world_half_extents()
	var bh := b.world_half_extents()
	var hitp := Vector3(ah.x, ah.y * 0.9, 0.05)
	var t := _side_attach(a, hitp, Vector3.RIGHT, bh, false)
	print("[build] side gap=%.3f (0 = 면이 딱 붙음)  z=%.3f (가운데 맞춤 0)  bottom=%.3f" % [(t.x - bh.x) - ah.x, t.z, t.y - bh.y])
	b.position = t
	b.set_size(1.33)
	var k := _snap_size(b.size)
	print("[build] 자석 끔: size 1.33 → %.3f (그대로여야 함)" % k)
	magnet = true
	print("[build] 자석 켬: size 1.33 → %.3f (1.4에 맞춤)" % _snap_size(b.size))
	magnet = false
	# 자유 이동: 높이 유지 · 겹침 허용
	b.position = Vector3(0, 1.2, 0)
	anim.erase(b)
	var mp := cam.unproject_position(Vector3(0.3, 1.2, 0.2))
	grab_off = Vector3.ZERO
	var ft := _snap_target(mp)
	print("[build] 자유 이동 → %s (y 1.2 유지, a와 겹침 OK)" % str(ft.snapped(Vector3.ONE * 0.01)))
	# 늘이기
	var ps0 := b.pscale
	b.set_stretch(0, 2.0)
	print("[build] 가로 2배 늘이기: pscale.x %.2f → %.2f, y %.2f → %.2f" % [ps0.x, b.pscale.x, ps0.y, b.pscale.y])
	var d := b.to_dict()
	var b2 := Piece.from_dict(d)
	print("[build] 저장/복원 stretch=%s" % str(b2.stretch))
	b2.free()
	# 방향키 미세 이동
	b.set_stretch(0, 1.0)
	b.position = Vector3(0, 1.0, 0)
	anim.erase(b)
	_select(b)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_RIGHT
	ev.pressed = true
	for i in 4:
		_nudge(ev)
	ev.physical_keycode = KEY_PAGEUP
	_nudge(ev)
	print("[build] 방향키 → ×4 · PageUp: 목표 %s" % str((anim[b] as Vector3).snapped(Vector3.ONE * 0.01)))
	# 맞닿기: a 오른쪽 면에서 6cm 떨어진 곳 → 딱 붙어야
	anim.erase(b)
	b.position = Vector3(0, 1.0, 0)
	ah = a.world_half_extents()
	bh = b.world_half_extents()
	var near := Vector3(ah.x + bh.x + 0.06, a.position.y, 0.03)
	var sn := _contact_snap(near, 0.1)
	print("[build] 맞닿기: 틈 0.06 → %.3f (0이면 딱), z %.2f (가운데 0)" % [(sn.x - bh.x) - (a.position.x + ah.x), sn.z])
	# J: 멀리(0.5) 떨어진 것 → 붙는다
	b.position = Vector3(ah.x + bh.x + 0.5, a.position.y + 0.1, 0.4)
	anim.erase(b)
	_attach_nearest()
	var jt: Vector3 = anim[b]
	print("[build] J 붙이기: 틈 %.3f, z %.2f" % [(jt.x - bh.x) - (a.position.x + ah.x), jt.z])
	if OS.get_cmdline_user_args().has("--keep"):   # 화면 확인용: 떠 있는 덩어리 + 그림자 + 격자
		_set_view(3)
		return
	print("[scenario] done")
	get_tree().quit()


# ── 봉투 개봉식 (v0.6 보물찾기) ──────────────────────
# 찾아온 봉투를 조립 시작 때 한꺼번에 연다. 열린 파츠는 바로 「모은 덩어리」에 들어간다. 이 동안 시간은 안 간다.

var ceremony: CanvasLayer
var cer_envs: Array = []
var cer_row: HFlowContainer
var cer_parts: HFlowContainer
var cer_note: Label
var cer_btn: Button


func _open_ceremony() -> void:
	cer_envs = Game.human()["envelopes"]
	if cer_envs.is_empty():
		return
	ceremony = CanvasLayer.new()
	ceremony.layer = 5
	add_child(ceremony)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.13, 0.16, 0.72)
	ceremony.add_child(UI.full(dim))
	var p := UI.panel()
	p.custom_minimum_size = Vector2(860, 0)
	var v := UI.vbox(10)
	p.add_child(v)
	var t := UI.label("봉투 개봉식!", 40, UI.INK, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	cer_note = UI.label("봉투를 눌러서 열어요 · Space = 하나씩 · A = 모두 열기", 20, UI.SOFT)
	cer_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cer_note)
	cer_row = HFlowContainer.new()
	cer_row.alignment = FlowContainer.ALIGNMENT_CENTER
	cer_row.add_theme_constant_override("h_separation", 10)
	cer_row.add_theme_constant_override("v_separation", 10)
	v.add_child(cer_row)
	for i in cer_envs.size():
		var env: Dictionary = cer_envs[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(78, 70)
		b.focus_mode = Control.FOCUS_NONE
		UI.tile_button(b)
		var icon := Control.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(8, 8)
		icon.size = Vector2(62, 54)
		var tier: String = env["tier"]
		icon.draw.connect(func(): UI.draw_envelope(icon, Rect2(Vector2.ZERO, icon.size), tier))
		b.add_child(icon)
		b.tooltip_text = env["name"]
		b.pressed.connect(func(): _open_env(b, env))
		cer_row.add_child(b)
	var sep := HSeparator.new()
	v.add_child(sep)
	v.add_child(UI.label("나온 파츠", 20, UI.INK, true))
	cer_parts = HFlowContainer.new()
	cer_parts.add_theme_constant_override("h_separation", 8)
	cer_parts.add_theme_constant_override("v_separation", 8)
	cer_parts.custom_minimum_size = Vector2(0, 90)
	v.add_child(cer_parts)
	cer_btn = UI.primary("조립 시작 →", _close_ceremony, 24)
	cer_btn.visible = false
	var hb := UI.hbox(10)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(cer_btn)
	v.add_child(hb)
	ceremony.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH


func _open_env(b: Button, env: Dictionary) -> void:
	if not is_instance_valid(b) or b.disabled:
		return
	b.disabled = true
	var tw := create_tween()
	b.pivot_offset = b.size * 0.5
	tw.tween_property(b, "scale", Vector2(1.25, 1.25), 0.08)
	tw.tween_property(b, "scale", Vector2(0.0, 0.0), 0.16)
	tw.tween_callback(b.queue_free)
	UI.sfx("star" if env["tier"] == "gold" else "pick", -6.0)
	for it in env["parts"]:
		inventory.append(it)
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(96, 86)
		var item: Dictionary = it
		cell.draw.connect(func():
			cell.draw_style_box(_cer_box(), Rect2(Vector2.ZERO, cell.size))
			UI.draw_chunk_icon(cell, item, Rect2(Vector2(22, 6), Vector2(52, 50)))
			cell.draw_string(Data.font_regular, Vector2(0, 76), item["name"], HORIZONTAL_ALIGNMENT_CENTER, cell.size.x, 15, UI.INK))
		cell.scale = Vector2(0.2, 0.2)
		cer_parts.add_child(cell)
		var ct := create_tween()
		ct.tween_property(cell, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	cer_envs.erase(env)
	_refresh_tray()
	if cer_envs.is_empty():
		cer_note.text = "다 열었다! 파츠 %d개" % inventory.size()
		cer_btn.visible = true


var _cer_sb: StyleBoxFlat
func _cer_box() -> StyleBoxFlat:
	if _cer_sb == null:
		_cer_sb = StyleBoxFlat.new()
		_cer_sb.bg_color = Color("#F3F5F7")
		_cer_sb.set_corner_radius_all(8)
	return _cer_sb


func _open_next() -> void:
	for b in cer_row.get_children():
		if b is Button and not (b as Button).disabled:
			(b as Button).pressed.emit()
			return


func _close_ceremony() -> void:
	if ceremony:
		ceremony.queue_free()
		ceremony = null
	Game.human()["envelopes"] = []
