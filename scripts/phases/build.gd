extends Node3D
## 조립 (3:30) — 작업대 위에 덩어리를 놓고, 늘리고, 눌러서 타겟을 만든다.
## 블렌더·유니티 씬뷰 표준 조작 (§8.1). 표면 스냅 + 바닥 그림자 유지 (§8.2).

const TABLE := 1.8
const UNDO_MAX := 20
const MIN_PIECES := 5

var time_left := 210.0
var finished := false
var cam: Camera3D
var orbit_target := Vector3(0, 0.55, 0)
var yaw := 0.5
var pitch := -0.5
var dist := 4.6
var work_root: Node3D
var gizmo: Gizmo
var selected: Piece
var inventory: Array
var undo: Array = []
var redo: Array = []

var drag_axis := -1
var drag_body := false
var drag_pushed := false
var rot_accum := 0.0
var rot_start := Basis.IDENTITY
var orbiting := false
var panning := false

var tray: VBoxContainer
var hud_time: Label
var hud_count: Label
var hud_card: Label
var hud_sel: Label
var mode_buttons: Array = []
var ticket_btn: Button
var warn: Label
var warn_t := 0.0


func _ready() -> void:
	time_left = Game.t_build()
	inventory = Game.human()["inventory"]
	UI.make_env(self, Color("#EAD9BE"))
	_build_room()
	work_root = Node3D.new()
	add_child(work_root)
	gizmo = Gizmo.new()
	add_child(gizmo)
	cam = Camera3D.new()
	cam.fov = 50
	add_child(cam)
	_build_hud()
	_refresh_tray()
	_update_cam()
	if Game.autotest:
		var w := BotBuilder.build(Game.target, inventory, 0.75, Game.rng)
		for d in w:
			work_root.add_child(Piece.from_dict(d))


func _build_room() -> void:
	var floor_m := PlaneMesh.new()
	floor_m.size = Vector2(30, 30)
	var fl := MeshInstance3D.new()
	fl.mesh = floor_m
	fl.position.y = -0.9
	fl.material_override = Data.flat_material(Color("#C8A97E"))
	add_child(fl)
	var top := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(TABLE * 2, 0.2, TABLE * 2)
	top.mesh = bm
	top.position.y = -0.1
	top.material_override = Data.flat_material(Color("#E9D2AE"))
	add_child(top)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = bm.size
	cs.shape = sh
	cs.position.y = -0.1
	body.add_child(cs)
	add_child(body)
	for x in [-1, 1]:
		for z in [-1, 1]:
			var leg := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.18, 0.7, 0.18)
			leg.mesh = lm
			leg.position = Vector3(x * (TABLE - 0.2), -0.55, z * (TABLE - 0.2))
			leg.material_override = Data.flat_material(Color("#8A5A3B"))
			add_child(leg)
	# 앞쪽 표시 (전시 때 정면)
	var front := UI.label3d("정면", 40, UI.SOFT)
	front.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	front.rotation_degrees = Vector3(-90, 0, 0)
	front.position = Vector3(0, 0.005, TABLE - 0.25)
	add_child(front)


# ── HUD ──────────────────────────────────────────────

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

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

	# 왼쪽: 재료 트레이
	var left := UI.panel()
	var lv := UI.vbox(6)
	left.add_child(lv)
	lv.add_child(UI.label("모은 덩어리", 24, UI.INK, true))
	lv.add_child(UI.label("눌러서 작업대에 올리기", 18, UI.SOFT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(190, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(scroll)
	tray = UI.vbox(4)
	scroll.add_child(tray)
	hud_count = UI.label("", 20, UI.SOFT)
	lv.add_child(hud_count)
	layer.add_child(left)
	UI.corner(left, Control.PRESET_CENTER_LEFT)

	# 오른쪽: 팔레트 + 모드
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
		b.tooltip_text = Data.palette()[i]["name"]
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
	rv.add_child(UI.label("모드", 22, UI.INK, true))
	var mh := UI.hbox(4)
	rv.add_child(mh)
	for m in [["이동 W", Gizmo.Mode.MOVE], ["회전 E", Gizmo.Mode.ROTATE], ["크기 R", Gizmo.Mode.SCALE]]:
		var mm: int = m[1]
		var mb := UI.button(m[0], func(): _set_mode(mm), 18)
		mb.toggle_mode = true
		mh.add_child(mb)
		mode_buttons.append(mb)
	hud_sel = UI.label("", 18, UI.SOFT)
	hud_sel.custom_minimum_size.x = 210
	hud_sel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(hud_sel)
	layer.add_child(right)
	UI.corner(right, Control.PRESET_CENTER_RIGHT)

	# 아래: 도움말 + 버튼
	var bottom := UI.panel()
	var bv := UI.hbox(14)
	bottom.add_child(bv)
	var help := UI.label("좌클릭 선택·끌기(표면에 붙음) · 축 핸들 끌기 · 우클릭 회전 · 휠 줌 · 가운데 버튼 이동\nX 거울 복제 · Ctrl+D 복제 · Del 내리기 · Ctrl+Z 되돌리기 · F 초점 · Space 꾹 = 전시처럼 돌려보기", 17, UI.SOFT)
	bv.add_child(help)
	ticket_btn = UI.button("", _use_ticket, 20)
	bv.add_child(ticket_btn)
	bv.add_child(UI.button("다 했다 →", _finish, 26))
	layer.add_child(bottom)
	UI.corner(bottom, Control.PRESET_CENTER_BOTTOM, Vector2(0, 12))

	warn = UI.label("", 26, UI.BAD, true)
	warn.add_theme_color_override("font_outline_color", Color.WHITE)
	warn.add_theme_constant_override("outline_size", 8)
	layer.add_child(warn)
	UI.corner(warn, Control.PRESET_CENTER_BOTTOM, Vector2(0, 120))
	_set_mode(Gizmo.Mode.MOVE)


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
		var src: String = {"tear": " (뜯음)", "dig": " (팜)", "auto": " (자동)"}.get(it["origin"], "")
		var idx := i
		var b := UI.button("%s%s" % [Data.NAMES[it["type"]], src], func(): _spawn(idx), 20)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tray.add_child(b)
	hud_count.text = "올린 것 %d / 모은 것 %d" % [work_root.get_child_count(), inventory.size()]


func _set_mode(m: int) -> void:
	gizmo.set_mode(m)
	for i in mode_buttons.size():
		mode_buttons[i].set_pressed_no_signal(i == m)


func _warn(s: String) -> void:
	warn.text = s
	warn_t = 2.2


# ── 작업 ─────────────────────────────────────────────

func _dicts() -> Array:
	var out := []
	for p in work_root.get_children():
		out.append((p as Piece).to_dict())
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
	for c in work_root.get_children():
		work_root.remove_child(c)
		c.queue_free()
	for d in state:
		var p := Piece.from_dict(d)
		work_root.add_child(p)
		if p.inv_index == keep:
			_select(p)
	_refresh_tray()


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
	var p: Piece
	if from.is_empty():
		p = Piece.new().setup(it["type"], 0)
		p.color_idx = 0
	else:
		p = Piece.from_dict(from)
	p.inv_index = inv_i
	p.origin = it["origin"]
	work_root.add_child(p)
	if from.is_empty():
		var off := Vector3(Game.rng.randf_range(-0.5, 0.5), 0, Game.rng.randf_range(-0.4, 0.4))
		_drop_at(p, off)
	_select(p)
	_refresh_tray()
	return p


## 위에서 아래로 쏴서 닿는 표면 위에 올린다
func _drop_at(p: Piece, xz: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(xz.x, 6, xz.z), Vector3(xz.x, -1, xz.z), 0b11)
	if p.body:
		q.exclude = [p.body.get_rid()]
	var hit := space.intersect_ray(q)
	var y := 0.0
	if hit:
		y = hit["position"].y
	p.position = Vector3(xz.x, y + p.world_half_extents().y, xz.z)


func _free_index_of_type(t: String) -> int:
	var used := {}
	for c in work_root.get_children():
		used[(c as Piece).inv_index] = true
	for i in inventory.size():
		if not used.has(i) and inventory[i]["type"] == t:
			return i
	return -1


func _duplicate(mirror: bool) -> void:
	if not selected:
		return
	var idx := _free_index_of_type(selected.type)
	if idx < 0:
		_warn("같은 덩어리(%s)가 더 없어요" % Data.NAMES[selected.type])
		return
	var d := selected.to_dict()
	if mirror:
		var b := Basis(d["r"] as Quaternion)
		var m := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
		d["r"] = (m * b * m).get_rotation_quaternion()
		var pos: Vector3 = d["p"]
		d["p"] = Vector3(-pos.x if absf(pos.x) > 0.05 else pos.x + 0.35, pos.y, pos.z)
	else:
		d["p"] = d["p"] + Vector3(0.3, 0, 0.3)
	_spawn(idx, d)


func _delete() -> void:
	if not selected:
		return
	_push_undo()
	var p := selected
	_select(null)
	work_root.remove_child(p)
	p.queue_free()
	_refresh_tray()


func _apply_color(ci: int) -> void:
	if not selected:
		_warn("먼저 덩어리를 고르세요")
		return
	_push_undo()
	selected.set_color(ci)


func _select(p: Piece) -> void:
	if selected and is_instance_valid(selected):
		selected.set_highlight(false)
	selected = p
	gizmo.target = p
	if p:
		p.set_highlight(true)


func _use_ticket() -> void:
	if Game.tickets < 1:
		_warn("티켓이 없어요 — 카드를 달성하면 생겨요")
		return
	Game.tickets -= 1
	time_left += 30
	_warn("+30초!")


# ── 입력 ─────────────────────────────────────────────

func _ray_piece(mouse: Vector2) -> Dictionary:
	var from := cam.project_ray_origin(mouse)
	var to := from + cam.project_ray_normal(mouse) * 50
	var q := PhysicsRayQueryParameters3D.create(from, to, Piece.LAYER_PIECE)
	return get_world_3d().direct_space_state.intersect_ray(q)


func _snap_drag(mouse: Vector2) -> void:
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 50, 0b11)
	q.exclude = [selected.body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var h := selected.world_half_extents()
	var pos: Vector3
	if hit:
		var n: Vector3 = hit["normal"]
		var ext := absf(n.x) * h.x + absf(n.y) * h.y + absf(n.z) * h.z
		pos = hit["position"] + n * ext
	else:
		if absf(dir.y) < 0.001:
			return
		var t := -from.y / dir.y
		if t < 0:
			return
		pos = from + dir * t + Vector3(0, h.y, 0)
	pos.x = clampf(pos.x, -TABLE, TABLE)
	pos.z = clampf(pos.z, -TABLE, TABLE)
	pos.y = maxf(pos.y, h.y * 0.3)
	selected.global_position = pos


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
				orbiting = mb.pressed
			MOUSE_BUTTON_MIDDLE:
				panning = mb.pressed
			MOUSE_BUTTON_WHEEL_UP:
				dist = maxf(1.8, dist * 0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				dist = minf(10.0, dist * 1.1)
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event as InputEventKey)


func _input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseButton and not event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			drag_axis = -1
			drag_body = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			orbiting = false
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			panning = false
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if drag_axis >= 0 and selected:
			_drag_axis(mm.relative)
		elif drag_body and selected:
			if not drag_pushed:
				_push_undo()
				drag_pushed = true
			_snap_drag(mm.position)
		elif orbiting:
			yaw -= mm.relative.x * 0.008
			pitch = clampf(pitch - mm.relative.y * 0.006, -1.45, 0.25)
		elif panning:
			var right := cam.global_transform.basis.x
			var up := cam.global_transform.basis.y
			orbit_target += (-right * mm.relative.x + up * mm.relative.y) * dist * 0.0016
		else:
			gizmo.set_hover(gizmo.pick(cam, mm.position))


func _press(pos: Vector2) -> void:
	var ax := gizmo.pick(cam, pos)
	if ax >= 0:
		_push_undo()
		drag_axis = ax
		rot_accum = 0.0
		rot_start = selected.basis
		return
	var hit := _ray_piece(pos)
	if hit and hit["collider"].has_meta("piece"):
		_select(hit["collider"].get_meta("piece"))
		drag_body = true
		drag_pushed = false
	else:
		_select(null)


func _drag_axis(rel: Vector2) -> void:
	var a := gizmo.axis_dir(drag_axis)
	match gizmo.mode:
		Gizmo.Mode.MOVE:
			selected.global_position += a * gizmo.screen_to_axis(cam, drag_axis, rel)
			selected.position.x = clampf(selected.position.x, -TABLE, TABLE)
			selected.position.z = clampf(selected.position.z, -TABLE, TABLE)
			selected.position.y = clampf(selected.position.y, 0.0, 3.5)
		Gizmo.Mode.SCALE:
			var d := gizmo.screen_to_axis(cam, drag_axis, rel)
			var bs := Data.base_size(selected.type)
			var s := selected.pscale
			if Input.is_key_pressed(KEY_SHIFT):
				var f := 1.0 + d / maxf(0.05, bs[drag_axis] * s[drag_axis])
				s *= f
			else:
				s[drag_axis] += d / maxf(0.05, bs[drag_axis])
			selected.set_pscale(s)
		Gizmo.Mode.ROTATE:
			rot_accum += gizmo.screen_to_angle(cam, drag_axis, rel)
			var ang := rot_accum
			if not Input.is_key_pressed(KEY_ALT):
				ang = snappedf(ang, deg_to_rad(15))
			selected.basis = Basis(a, ang) * rot_start


func _key(k: InputEventKey) -> void:
	var ctrl := k.ctrl_pressed or k.meta_pressed
	match k.physical_keycode:
		KEY_W: _set_mode(Gizmo.Mode.MOVE)
		KEY_E: _set_mode(Gizmo.Mode.ROTATE)
		KEY_R: _set_mode(Gizmo.Mode.SCALE)
		KEY_X: _duplicate(true)
		KEY_D:
			if ctrl: _duplicate(false)
		KEY_Z:
			if ctrl:
				if k.shift_pressed: _redo()
				else: _undo()
		KEY_Y:
			if ctrl: _redo()
		KEY_DELETE, KEY_BACKSPACE: _delete()
		KEY_F:
			if selected:
				orbit_target = selected.global_position
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			_apply_color(k.physical_keycode - KEY_1)
		KEY_0: _apply_color(9)


# ── 진행 ─────────────────────────────────────────────

func _update_cam() -> void:
	var b := Basis.from_euler(Vector3(pitch, yaw, 0))
	cam.position = orbit_target + b * Vector3(0, 0, dist)
	cam.look_at(orbit_target)


func _process(delta: float) -> void:
	if finished:
		return
	time_left -= delta
	if Input.is_physical_key_pressed(KEY_SPACE):
		yaw += delta * 1.3
	_update_cam()
	gizmo.follow(cam)
	hud_time.text = UI.clock(time_left)
	hud_time.add_theme_color_override("font_color", UI.BAD if time_left < 30 else UI.INK)
	var dicts := _dicts()
	var card: Dictionary = Game.human()["card"]
	var ok := Judge.card_constraint(card, dicts, inventory.size())
	hud_card.text = ("제약 충족 — 이제 %s만 남았어요" % Data.rank_text(card["rank"])) if ok else "제약 아직 (최소 %d개 + 카드 조건)" % MIN_PIECES
	hud_card.add_theme_color_override("font_color", UI.GOOD if ok else UI.SOFT)
	ticket_btn.text = "+30초 (티켓 %d장)" % Game.tickets
	ticket_btn.disabled = Game.tickets < 1
	if selected:
		var s := selected.pscale
		hud_sel.text = "%s · 배율 %.1f × %.1f × %.1f\n색 %s" % [Data.NAMES[selected.type], s.x, s.y, s.z, Data.palette()[selected.color_idx]["name"]]
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
	Game.goto("exhibit")
