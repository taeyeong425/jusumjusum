extends Node3D
## 조립 (3:30) — 축 없는 직접 조작.
##  · 덩어리 끌기 = 표면을 따라 이동 (부드럽게 따라온다)
##  · 손잡이 「크기」 = 전체 크기 (비율은 덩어리마다 고정 — 납작한 건 처음부터 납작하다)
##  · 손잡이 「회전」 = 끄는 방향으로 자유 회전 (트랙볼)
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


func _ready() -> void:
	time_left = Game.t_build()
	inventory = Game.human()["inventory"]
	UI.make_env(self, Color("#EAD9BE"))
	_build_room()
	work_root = Node3D.new()
	add_child(work_root)
	cam = Camera3D.new()
	cam.fov = 50
	add_child(cam)
	_build_hud()
	_refresh_tray()
	_update_cam(1.0)
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
	fl.material_override = Data.flat_material(Color("#C8A97E"))
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
			sb.border_color = UI.INK if st == "hover" else Color("#C9A27A")
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
	tools.add_child(UI.button("↺ 45° (Q)", func(): _turn(-PI / 4), 18))
	tools.add_child(UI.button("↻ 45° (E)", func(): _turn(PI / 4), 18))
	tools.add_child(UI.button("똑바로 (T)", _straighten, 18))
	tools.add_child(UI.button("내리기 (Del)", _delete, 18))
	tools.add_child(UI.button("되돌리기", _undo, 18))
	spin_btn = UI.button("돌려보기", func(): spin = not spin, 18)
	tools.add_child(spin_btn)
	hud_sel = UI.label("", 18, UI.SOFT)
	hud_sel.custom_minimum_size.x = 220
	hud_sel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(hud_sel)
	layer.add_child(right)
	UI.corner(right, Control.PRESET_CENTER_RIGHT)

	var bottom := UI.panel()
	var bv := UI.hbox(14)
	bottom.add_child(bv)
	bv.add_child(UI.label("끌기: 덩어리 = 옮겨서 위에 얹기 · Shift+끌기 = 높이 · 손잡이 = 크기/회전\n빈 곳·우클릭 끌기 = 시점 · 휠 = 줌 · Ctrl+Z 되돌리기 · F 덩어리로 시점 이동", 17, UI.SOFT))
	bv.add_child(UI.button("다 했다 →", _finish, 26))
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


func _select(p: Piece) -> void:
	if selected and is_instance_valid(selected):
		selected.set_highlight(false)
	selected = p
	if p:
		p.set_highlight(true)



# ── 입력 ─────────────────────────────────────────────

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
	var rot_k := Vector2((mn.x + mx.x) * 0.5, mn.y - 26).clamp(Vector2(24, 24), vs - Vector2(24, 24))
	return {"rect": Rect2(mn, mx - mn), "size": size_k, "rot": rot_k, "center": cam.unproject_position(c)}


func _draw_overlay() -> void:
	var k := _knobs()
	if k.is_empty():
		return
	var r: Rect2 = k["rect"]
	overlay.draw_rect(r.grow(6), Color(UI.ACCENT, 0.55), false, 2.0)
	for nm in ["size", "rot"]:
		var p: Vector2 = k[nm]
		var active: bool = (mode == "size" and nm == "size") or (mode == "rot" and nm == "rot")
		overlay.draw_circle(p, KNOB_R, Color("#FFF8EC") if not active else Color("#FFE3A8"))
		overlay.draw_arc(p, KNOB_R, 0, TAU, 28, UI.ACCENT, 2.5)
		var txt: String = "크기" if nm == "size" else "회전"
		overlay.draw_string(Data.font_bold, p + Vector2(-KNOB_R, 6), txt, HORIZONTAL_ALIGNMENT_CENTER, KNOB_R * 2, 16, UI.INK)


func _ray_piece(mouse: Vector2) -> Dictionary:
	var from := cam.project_ray_origin(mouse)
	var to := from + cam.project_ray_normal(mouse) * 50
	var q := PhysicsRayQueryParameters3D.create(from, to, Piece.LAYER_PIECE)
	return get_world_3d().direct_space_state.intersect_ray(q)


## 끌기: 커서가 가리키는 곳(책상이나 다른 덩어리 윗면) 위에 얹는다. 옆면에 붙지 않는다.
## 잡은 지점을 유지해서, 잡는 순간 덩어리가 커서로 튀지 않는다.
func _snap_target(mouse: Vector2) -> Vector3:
	var cur: Vector3 = anim.get(selected, selected.position)
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 50, 0b11)
	q.exclude = [selected.body.get_rid()]
	var hit := space.intersect_ray(q)
	var p: Vector3
	if hit:
		p = hit["position"]
	else:
		if absf(dir.y) < 0.001:
			return cur
		var t := -from.y / dir.y
		if t < 0:
			return cur
		p = from + dir * t
	var xz := Vector3(p.x, 0, p.z) + grab_off
	xz.x = clampf(xz.x, -TABLE, TABLE)
	xz.z = clampf(xz.z, -TABLE, TABLE)
	# 그 자리 바로 아래 가장 높은 면 위에 얹는다
	var h := selected.world_half_extents()
	var top := 0.0
	for off in [Vector3.ZERO, Vector3(h.x * 0.6, 0, 0), Vector3(-h.x * 0.6, 0, 0), Vector3(0, 0, h.z * 0.6), Vector3(0, 0, -h.z * 0.6)]:
		var dq := PhysicsRayQueryParameters3D.create(xz + off + Vector3(0, 8, 0), xz + off + Vector3(0, -1, 0), 0b11)
		dq.exclude = [selected.body.get_rid()]
		var dh := space.intersect_ray(dq)
		if dh:
			top = maxf(top, dh["position"].y)
	return Vector3(xz.x, top + h.y, xz.z)


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
			"rot":
				var right := cam.global_transform.basis.x
				selected.basis = (Basis(Vector3.UP, mm.relative.x * 0.012) * Basis(right, mm.relative.y * 0.012) * selected.basis).orthonormalized()
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
	var k := _knobs()
	if not k.is_empty():
		if pos.distance_to(k["size"]) < KNOB_R + 4:
			_push_undo()
			mode = "size"
			size0 = selected.size
			dist0 = maxf(4.0, pos.distance_to(k["center"]))
			return
		if pos.distance_to(k["rot"]) < KNOB_R + 4:
			_push_undo()
			mode = "rot"
			return
	var hit := _ray_piece(pos)
	if hit and hit["collider"].has_meta("piece"):
		var p: Piece = hit["collider"].get_meta("piece")
		if p != selected:
			UI.sfx("select", -12.0)
		_select(p)
		mode = "move"
		pushed = false
		var hp: Vector3 = hit["position"]
		grab_off = Vector3(p.global_position.x - hp.x, 0, p.global_position.z - hp.z)
	else:
		mode = "orbit?"


func _key(k: InputEventKey) -> void:
	var ctrl := k.ctrl_pressed or k.meta_pressed
	match k.physical_keycode:
		KEY_Q: _turn(-PI / 4)
		KEY_E: _turn(PI / 4)
		KEY_T: _straighten()
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
	time_left -= delta
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
	overlay.queue_redraw()
	hud_time.text = UI.clock(time_left)
	hud_time.add_theme_color_override("font_color", UI.BAD if time_left < 30 else UI.INK)
	var dicts := _dicts()
	var card: Dictionary = Game.human()["card"]
	var ok := Judge.card_constraint(card, dicts, inventory.size())
	hud_card.text = ("제약 충족 — 이제 %s만 남았어요" % Data.rank_text(card["rank"])) if ok else "제약 아직 (최소 %d개 + 카드 조건)" % MIN_PIECES
	hud_card.add_theme_color_override("font_color", UI.GOOD if ok else UI.SOFT)
	spin_btn.text = "멈추기" if spin else "돌려보기"
	if selected:
		hud_sel.text = "%s · 크기 %.1f배\n색 %s" % [Data.variant_name(selected.type, selected.shape), selected.size, Data.palette()[selected.color_idx]["name"]]
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
