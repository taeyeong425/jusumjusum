class_name Gizmo
extends Node3D
## 런타임 변환 기즈모 (§8.1 W/E/R). Godot은 게임 빌드용 기즈모를 제공하지 않아 직접 구현.
## 핸들 집기는 물리 대신 화면 좌표 거리로 한다 — 기즈모에 배율을 걸어도 안전하다.

enum Mode { MOVE, ROTATE, SCALE }

const AXIS_COLORS := [Color("#E5484D"), Color("#46A758"), Color("#3E7BFA")]
const PICK_PX := 16.0

var mode := Mode.MOVE
var target: Piece
var hover := -1
var handles: Array = []   # [axis] → Node3D


func _ready() -> void:
	_rebuild()


func set_mode(m: int) -> void:
	mode = m
	_rebuild()


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	m.render_priority = 10
	return m


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	handles.clear()
	for i in 3:
		var h := Node3D.new()
		add_child(h)
		handles.append(h)
		var col: Color = AXIS_COLORS[i]
		# 핸들은 로컬 +Y를 기준으로 만들고 축 방향으로 돌린다
		var to_axis := Basis.IDENTITY
		if i == 0:
			to_axis = Basis(Vector3.BACK, -PI / 2)
		elif i == 2:
			to_axis = Basis(Vector3.RIGHT, PI / 2)
		h.basis = to_axis
		match mode:
			Mode.MOVE, Mode.SCALE:
				var shaft := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.025; cm.bottom_radius = 0.025; cm.height = 0.85
				shaft.mesh = cm
				shaft.position.y = 0.425
				shaft.material_override = _mat(col)
				h.add_child(shaft)
				var tip := MeshInstance3D.new()
				if mode == Mode.MOVE:
					var cone := CylinderMesh.new()
					cone.top_radius = 0.0; cone.bottom_radius = 0.08; cone.height = 0.22
					tip.mesh = cone
				else:
					var bm := BoxMesh.new()
					bm.size = Vector3.ONE * 0.14
					tip.mesh = bm
				tip.position.y = 0.95
				tip.material_override = _mat(col)
				h.add_child(tip)
			Mode.ROTATE:
				var ring := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.82; tm.outer_radius = 0.88
				tm.rings = 48
				ring.mesh = tm
				ring.material_override = _mat(col)
				h.add_child(ring)
	set_hover(-1)


func set_hover(i: int) -> void:
	hover = i
	for k in handles.size():
		for c in handles[k].get_children():
			var mi := c as MeshInstance3D
			if mi:
				var col: Color = AXIS_COLORS[k]
				(mi.material_override as StandardMaterial3D).albedo_color = col.lightened(0.45) if k == i else col


## 축 방향 (월드). 배율 모드는 덩어리의 로컬 축, 나머지는 월드 축.
func axis_dir(i: int) -> Vector3:
	if mode == Mode.SCALE and target:
		var b := target.global_transform.basis.orthonormalized()
		return [b.x, b.y, b.z][i]
	return [Vector3.RIGHT, Vector3.UP, Vector3.BACK][i]


func follow(cam: Camera3D) -> void:
	visible = target != null
	if not target:
		return
	global_position = target.global_position
	var d := cam.global_position.distance_to(global_position)
	var s := d * 0.13
	if mode == Mode.SCALE:
		basis = target.global_transform.basis.orthonormalized().scaled(Vector3.ONE * s)
	else:
		basis = Basis.IDENTITY.scaled(Vector3.ONE * s)


func size_world() -> float:
	return basis.get_scale().x


## 마우스 위치에서 가장 가까운 핸들 축. 없으면 -1
func pick(cam: Camera3D, mouse: Vector2) -> int:
	if not target or not visible:
		return -1
	var best := -1
	var bd := PICK_PX
	var o := global_position
	var L := size_world()
	for i in 3:
		var a := axis_dir(i)
		var d := INF
		if mode == Mode.ROTATE:
			var u := a.cross(Vector3.UP if absf(a.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
			var v := a.cross(u).normalized()
			var prev := Vector2.ZERO
			for k in 33:
				var t := TAU * k / 32.0
				var p := o + (u * cos(t) + v * sin(t)) * L * 0.85
				if cam.is_position_behind(p):
					continue
				var sp := cam.unproject_position(p)
				if k > 0:
					d = minf(d, _seg_dist(mouse, prev, sp))
				prev = sp
		else:
			if cam.is_position_behind(o + a * L):
				continue
			d = _seg_dist(mouse, cam.unproject_position(o + a * L * 0.15), cam.unproject_position(o + a * L * 1.05))
		if d < bd:
			bd = d
			best = i
	return best


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## 마우스 이동(px)을 축 방향 월드 거리로 변환
func screen_to_axis(cam: Camera3D, axis: int, mouse_delta: Vector2) -> float:
	var o := global_position
	var a := axis_dir(axis)
	var s0 := cam.unproject_position(o)
	var s1 := cam.unproject_position(o + a)
	var sd := s1 - s0
	var px := sd.length()
	if px < 2.0:
		return -mouse_delta.y * 0.01
	return mouse_delta.dot(sd / px) / px


## 회전: 축의 화면 방향에 수직인 마우스 성분을 각도로
func screen_to_angle(cam: Camera3D, axis: int, mouse_delta: Vector2) -> float:
	var o := global_position
	var a := axis_dir(axis)
	var sd := cam.unproject_position(o + a) - cam.unproject_position(o)
	if sd.length() < 6.0:
		return mouse_delta.x * 0.012
	var perp := Vector2(-sd.y, sd.x).normalized()
	return mouse_delta.dot(perp) * 0.012
