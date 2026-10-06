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
	var fl := MeshInstance3D.new()
	var fm := PlaneMesh.new(); fm.size = Vector2(30, 30)
	fl.mesh = fm
	fl.position.y = -0.9
	fl.material_override = Data.brick(Color("#DCE3E8"), false, 0.25, 0.7)
	add_child(fl)
	var top := Piece.new().setup("box", 13, false)
	top.set_pscale(Vector3(TABLE * 2 / 0.5, 0.4, TABLE * 2 / 0.5), false)
	top.position.y = -0.1
	add_child(top)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(TABLE * 2, 0.2, TABLE * 2)
	cs.shape = sh
	cs.position.y = -0.1
	body.add_child(cs)
	add_child(body)
	for x in [-1, 1]:
		for z in [-1, 1]:
			var leg := Piece.new().setup("box", 12, false, Data.variant("box", 2)[1])
			leg.set_pscale(Data.variant("box", 2)[1] * 1.4, false)
			leg.position = Vector3(x * (TABLE - 0.2), -0.75, z * (TABLE - 0.2))
			add_child(leg)
	var front := UI.label3d("정면", 40, UI.SOFT)
	front.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	front.rotation_degrees = Vector3(-90, 0, 0)
	front.position = Vector3(0, 0.005, TABLE - 0.25)
	add_child(front)


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
	grid.add_theme_constant_override("v_separation", 6)
	rv.add_child(grid)
	for i in 16:
		var b := Button.new()
		b.custom_minimum_size = Vector2(40, 40)
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
		var nl := UI.label(Data.palette()[i]["name"], 14, UI.SOFT)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(nl)
		grid.add_child(cell)
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
	magnet_btn = UI.button("", _toggle_magnet, 18)
	tools.add_child(magnet_btn)
	_toggle_magnet(false)
	hud_sel = UI.label("", 18, UI.SOFT)
	hud_sel.custom_minimum_size.x = 220
	hud_sel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(hud_sel)
	layer.add_child(right)
	UI.corner(right, Control.PRESET_CENTER_RIGHT)

	var bottom := UI.panel()
	var bv := UI.hbox(14)
	bottom.add_child(bv)
	bv.add_child(UI.label("덩어리 끌기 = 옮기기 (공중 · 겹치기 OK) · Shift+끌기 = 높이 · G = 바닥에 붙이기\n색 고리 = 그 축으로 회전 · 색 네모 = 그 방향으로 늘이기 · 크기 = 전체 · M = 자석 맞춤 · 빈 곳 끌기 = 시점", 17, UI.SOFT))
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


func _draw_overlay() -> void:
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
				dist_t = maxf(1.6, dist_t * 0.88)
			MOUSE_BUTTON_WHEEL_DOWN:
				dist_t = minf(10.0, dist_t * 1.12)
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
					anim[selected] = _snap_target(mm.position)
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
		KEY_M: _toggle_magnet()
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
	for i in range(1, Game.players.size()):
		var p: Dictionary = Game.players[i]
		p["work"] = BotBuilder.build(Game.target, p["inventory"], p["quality"], Game.rng)
		p["edits"] = Game.rng.randi_range(4, 40)
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
