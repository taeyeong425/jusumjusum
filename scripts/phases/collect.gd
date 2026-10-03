extends Node3D
## 수집 (2:00) — 3인칭으로 놀이터를 돌아다니며, 조준해서 줍고, [E] 꾹으로 뜯는다.
## 놀이터 전체가 같은 덩어리 12종으로 지어져 있다. 뜯은 모양·색 그대로 핫바에 들어온다.
## 차는 도로를 돌고 기차는 레일을 달린다. 편성에 없는 몫의 부품은 녹슬어서 안 빠진다.

const SPEED := 5.0
const GRAVITY := 22.0
const JUMP_V := 7.5
const HOLD_MAX := 12
const REACH := 3.6
const AIM_DEG := 20.0
const PEEK_R := 7.0
const L_WORLD := 1
const L_ITEM := 2
const L_CHAR := 4

var time_left := 120.0
var finished := false
var world: Node3D
var cam_pivot: Node3D
var spring: SpringArm3D
var cam: Camera3D
var cam_yaw := 0.0
var cam_pitch := -0.32
var actors: Array = []
var ground: Array = []        # {node: Piece, item, alive}
var tears: Array = []         # {node: Piece, item, hold, name, alive, bolted, dig, uses}
var vehicles: Array = []      # {body, path, s, speed, stop_at, stop_t, wait}
var boundary: PackedVector2Array
var road_path: Array = []
var rail_path: Array = []
var wanted := {}

var aim: Dictionary = {}
var hold_target: Dictionary = {}
var hold_prog := 0.0
var tick_t := 0.0
var step_t := 0.0
var slot := 0
var jump_req := false
var was_floor := true

var hud_time: Label
var hud_prompt: Label
var hud_bar: ProgressBar
var hotbar: HBoxContainer
var hot_slots: Array = []
var minimap: Control
var toast: Label
var toast_t := 0.0
var capture_hint: Label
var crosshair: Control


func _ready() -> void:
	time_left = Game.t_collect()
	UI.make_env(self, Color("#CFE6F2"))
	world = Node3D.new()
	add_child(world)
	_build_boundary()
	_build_paths()
	_build_ground()
	_build_playground()
	_build_town()
	_commit_batch(batch_world, world)
	batch_world = {}
	_build_vehicles()
	_claim_formation()
	_spawn_ground_items()
	_spawn_actors()
	_build_camera()
	for t in BotBuilder.wanted_types(Game.target):
		wanted[t] = 1
	for part in Game.target["parts"]:
		wanted[Data.GROUPS[part[0]][0]] = 3
	_build_hud()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ── 덩어리로 짓기 ────────────────────────────────────
# 부위: [종류, 변형번호 또는 비율, 색, 위치, 회전(도), 크기, 뜯기이름("" = 장식), 뜯는 시간]

func _shape_of(t: String, spec) -> Vector3:
	if spec is Vector3:
		return spec
	return Data.variant(t, int(spec))[1]


var batch_world := {}   # 색 → SurfaceTool. 움직이지 않는 장식은 전부 여기로 합친다


## 장식(뜯을 수 없는 부분)은 색깔별로 하나의 메시로 합친다 — 웹에서 그리기 호출이 수백 번 → 수십 번.
## 뜯을 수 있는 부분만 개별 덩어리 노드로 둔다.
func _assemble(root: Node3D, parts: Array) -> void:
	var into_world := not (root is AnimatableBody3D) and root.get_parent() == world
	var batch: Dictionary = batch_world if into_world else {}
	var xf: Transform3D = root.transform if into_world else Transform3D.IDENTITY
	for p in parts:
		var t: String = p[0]
		var shp := _shape_of(t, p[1])
		var tear_name: String = p[6] if p.size() > 6 else ""
		var rot: Vector3 = p[4] if p[4] is Vector3 else Vector3.ZERO
		var s := shp * float(p[5])
		if tear_name == "":
			var ci: int = p[2]
			if not batch.has(ci):
				var nst := SurfaceTool.new()
				nst.begin(Mesh.PRIMITIVE_TRIANGLES)
				batch[ci] = nst
			var pxf := xf * Transform3D(Basis.from_euler(rot * PI / 180.0), p[3]) * Transform3D(Basis.from_scale(s), Vector3.ZERO) * Data.base_xform(t)
			(batch[ci] as SurfaceTool).append_from(Data.mesh(t), 0, pxf)
			continue
		var pc := Piece.new().setup(t, p[2], true, shp)
		pc.set_pscale(s, false)
		pc.position = p[3]
		pc.rotation_degrees = rot
		pc.mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(pc)
		if true:
			var item := Data.make_item(t, shp, p[2], "tear")
			var e := {"node": pc, "item": item, "hold": float(p[7]) if p.size() > 7 else 1.6,
				"name": tear_name, "alive": true, "bolted": false, "dig": false, "uses": 1}
			pc.set_meta("entry", e)
			tears.append(e)
	if not into_world:
		_commit_batch(batch, root)


func _commit_batch(batch: Dictionary, parent: Node3D) -> void:
	for ci in batch:
		var mi := MeshInstance3D.new()
		mi.mesh = (batch[ci] as SurfaceTool).commit()
		mi.material_override = Data.material(ci)
		parent.add_child(mi)


func _solid(parent: Node3D, pos: Vector3, size: Vector3, yaw := 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = L_WORLD
	b.collision_mask = 0
	b.position = pos
	b.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position.y = size.y * 0.5
	b.add_child(cs)
	parent.add_child(b)
	return b


func _place(builder: Callable, pos: Vector3, yaw := 0.0, arg = null) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	world.add_child(root)
	if arg == null:
		builder.call(root)
	else:
		builder.call(root, arg)
	return root


# ── 맵 ───────────────────────────────────────────────

func _boundary_r(a: float) -> float:
	return 35.0 + 4.0 * sin(3.0 * a + 1.0) + 2.0 * cos(5.0 * a)


func _build_boundary() -> void:
	var n := 48
	for i in n:
		var a := TAU * i / n
		var r := _boundary_r(a)
		boundary.append(Vector2(cos(a) * r, sin(a) * r))
	# 울타리: 기둥 + 가로대 (장식이라 외곽선 없음 · 충돌은 상자)
	var posts := SurfaceTool.new()
	posts.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rails := SurfaceTool.new()
	rails.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pm := CylinderMesh.new(); pm.top_radius = 0.13; pm.bottom_radius = 0.13; pm.height = 1.2; pm.radial_segments = 8
	var rm := BoxMesh.new(); rm.size = Vector3(1, 0.1, 0.08)
	for i in n:
		var a := boundary[i]
		var b := boundary[(i + 1) % n]
		var mid := (a + b) * 0.5
		var len := a.distance_to(b)
		var yaw := -atan2(b.y - a.y, b.x - a.x)
		_solid(world, Vector3(mid.x, 0, mid.y), Vector3(len, 1.4, 0.4), yaw)
		posts.append_from(pm, 0, Transform3D(Basis.IDENTITY, Vector3(a.x, 0.6, a.y)))
		for y in [0.45, 0.95]:
			rails.append_from(rm, 0, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(len, 1, 1)), Vector3(mid.x, y, mid.y)))
	for pair in [[posts, 13], [rails, 0]]:
		var mi := MeshInstance3D.new()
		mi.mesh = (pair[0] as SurfaceTool).commit()
		mi.material_override = Data.material(pair[1])
		world.add_child(mi)


func _rounded_rect(hx: float, hz: float, r: float, seg := 6) -> Array:
	var pts := []
	var corners := [Vector2(hx - r, hz - r), Vector2(-hx + r, hz - r), Vector2(-hx + r, -hz + r), Vector2(hx - r, -hz + r)]
	for c in 4:
		for k in seg + 1:
			var a := PI / 2 * c + PI / 2 * k / seg
			pts.append(Vector3(corners[c].x + cos(a) * r, 0, corners[c].y + sin(a) * r))
	return pts


func _ellipse(rx: float, rz: float, n := 64) -> Array:
	var pts := []
	for i in n:
		var a := TAU * i / n
		pts.append(Vector3(cos(a) * rx, 0, sin(a) * rz))
	return pts


func _build_paths() -> void:
	road_path = _rounded_rect(16.0, 13.0, 5.0)
	rail_path = _ellipse(26.0, 21.0)


func _strip_mesh(path: Array, width: float, y: float, col: Color, offset := 0.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := path.size()
	for i in n:
		var a: Vector3 = path[i]
		var b: Vector3 = path[(i + 1) % n]
		var c: Vector3 = path[(i + 2) % n]
		var d1 := (b - a).normalized()
		var d2 := (c - b).normalized()
		var na := Vector3(-d1.z, 0, d1.x)
		var nb := Vector3(-(d1 + d2).normalized().z, 0, (d1 + d2).normalized().x)
		var pa: Vector3 = path[(i - 1 + n) % n]
		var d0 := (a - pa).normalized()
		na = Vector3(-(d0 + d1).normalized().z, 0, (d0 + d1).normalized().x)
		var a0 := a + na * (offset - width * 0.5)
		var a1 := a + na * (offset + width * 0.5)
		var b0 := b + nb * (offset - width * 0.5)
		var b1 := b + nb * (offset + width * 0.5)
		for v in [a0, b0, b1, a0, b1, a1]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(v.x, y, v.z))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Data.flat_material(col)
	world.add_child(mi)
	return mi


func _build_ground() -> void:
	var outer := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(140, 140)
	outer.mesh = pm
	outer.position.y = -0.02
	outer.material_override = Data.flat_material(Color("#7FB069"))
	world.add_child(outer)
	# 울타리 안쪽 잔디 (불규칙한 다각형)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in boundary.size():
		var a := boundary[i]
		var b := boundary[(i + 1) % boundary.size()]
		for v in [Vector2.ZERO, b, a]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(v.x, 0.0, v.y))
	var lawn := MeshInstance3D.new()
	lawn.mesh = st.commit()
	lawn.material_override = Data.flat_material(Color("#A9CF8E"))
	world.add_child(lawn)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = L_WORLD
	var fcs := CollisionShape3D.new()
	var fsh := BoxShape3D.new()
	fsh.size = Vector3(140, 1, 140)
	fcs.shape = fsh
	fcs.position.y = -0.5
	floor_body.add_child(fcs)
	world.add_child(floor_body)
	# 도로 · 레일 · 침목
	_strip_mesh(road_path, 3.4, 0.015, Color("#8E8A86"))
	_strip_mesh(road_path, 0.12, 0.02, Color("#F3E9D2"))
	_strip_mesh(rail_path, 2.0, 0.012, Color("#C8B79A"))
	_strip_mesh(rail_path, 0.12, 0.05, Color("#5A5A5A"), -0.55)
	_strip_mesh(rail_path, 0.12, 0.05, Color("#5A5A5A"), 0.55)
	var sl := SurfaceTool.new()
	sl.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rail_path.size():
		var a: Vector3 = rail_path[i]
		var b: Vector3 = rail_path[(i + 1) % rail_path.size()]
		var d := (b - a).normalized()
		var nrm := Vector3(-d.z, 0, d.x)
		for f in [0.0, 0.5]:
			var c: Vector3 = a.lerp(b, f)
			var p0 := c + nrm * 0.85 - d * 0.18
			var p1 := c + nrm * 0.85 + d * 0.18
			var p2 := c - nrm * 0.85 + d * 0.18
			var p3 := c - nrm * 0.85 - d * 0.18
			for v in [p0, p1, p2, p0, p2, p3]:
				sl.set_normal(Vector3.UP)
				sl.add_vertex(Vector3(v.x, 0.03, v.z))
	var sleepers := MeshInstance3D.new()
	sleepers.mesh = sl.commit()
	sleepers.material_override = Data.flat_material(Color("#8A5A3B"))
	world.add_child(sleepers)
	# 모래밭
	var sand := Piece.new().setup("cylinder", 13, false, Vector3(1, 1, 1))
	sand.set_pscale(Vector3(26, 0.08, 26), false)
	sand.position = Vector3(0, 0.0, 0)
	world.add_child(sand)
	var rng := Game.rng
	for i in 6:
		var a := TAU * i / 6.0 + 0.4
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(2.2, 4.8)
		var mound := Piece.new().setup("hemi", 13, true, Data.variant("hemi", 1)[1])
		mound.set_pscale(Data.variant("hemi", 1)[1] * 2.2, false)
		mound.position = p + Vector3(0, 0.1, 0)
		world.add_child(mound)
		var e := {"node": mound, "item": {}, "hold": 1.4, "name": "모래 파기", "alive": true,
			"bolted": false, "dig": true, "uses": 3}
		mound.set_meta("entry", e)
		tears.append(e)
	var signs := [
		[Vector3(0, 2.6, 0), "모래밭 — 파면 나와요"],
		[Vector3(29.5, 4.2, 0), "기차역"],
	]
	for s in signs:
		var l := UI.label3d(s[1], 64)
		l.position = s[0]
		world.add_child(l)


# ── 놀이터 ───────────────────────────────────────────

func _swing(r: Node3D) -> void:
	var p := []
	for x in [-2.0, 2.0]:
		for z in [-0.8, 0.8]:
			p.append(["rod", 2, 2, Vector3(x, 1.5, z * 0.9), Vector3(z * 14, 0, 0), 2.1])
	p.append(["cylinder", 2, 2, Vector3(0, 3.0, 0), Vector3(0, 0, 90), 3.6])
	for x in [-0.9, 0.9]:
		for cx in [-0.28, 0.28]:
			p.append(["rod", 2, 14, Vector3(x + cx, 1.95, 0), Vector3.ZERO, 1.35, "그네 사슬", 1.2])
		p.append(["plate", 2, 4, Vector3(x, 0.85, 0), Vector3(0, 90, 0), 1.25, "그네 의자", 1.6])
	_assemble(r, p)
	_solid(r, Vector3(-2, 0, 0), Vector3(0.4, 3, 1.8))
	_solid(r, Vector3(2, 0, 0), Vector3(0.4, 3, 1.8))


func _seesaw(r: Node3D) -> void:
	_assemble(r, [
		["box", 0, 12, Vector3(0, 0.25, 0), Vector3.ZERO, 1.0],
		["plate", 3, 5, Vector3(0, 0.55, 0), Vector3(0, 0, 8), 1.6, "시소 판", 2.6],
		["capsule", 0, 2, Vector3(-1.4, 0.85, 0), Vector3.ZERO, 0.6, "시소 손잡이", 1.2],
		["capsule", 0, 2, Vector3(1.4, 1.2, 0), Vector3.ZERO, 0.6, "시소 손잡이", 1.2],
		["sphere", 0, 5, Vector3(-1.75, 0.35, 0), Vector3.ZERO, 0.55, "고무공", 0.8],
	])
	_solid(r, Vector3.ZERO, Vector3(0.6, 0.6, 0.6))


func _slide(r: Node3D) -> void:
	var p := [
		["box", Vector3(3.2, 0.4, 3.2), 10, Vector3(-1.2, 2.5, 0), Vector3.ZERO, 1.0],
		["plate", 3, 3, Vector3(1.0, 1.3, 0), Vector3(0, 0, -38), 1.6, "미끄럼판", 3.0],
		["capsule", 1, 4, Vector3(-1.2, 3.1, -0.75), Vector3(90, 0, 0), 0.0, "", 0],
		["sphere", 0, 2, Vector3(-1.2, 3.35, 0), Vector3.ZERO, 0.9, "꼭대기 공", 1.4],
	]
	p.pop_at(2)
	for z in [-0.75, 0.75]:
		p.append(["capsule", 1, 4, Vector3(-1.2, 3.05, z), Vector3.ZERO, 0.8, "난간", 1.3])
	for x in [-1.9, -0.5]:
		for z in [-0.7, 0.7]:
			p.append(["rod", 2, 11, Vector3(x, 1.25, z), Vector3.ZERO, 1.7])
	for y in [0.6, 1.2, 1.8]:
		p.append(["rod", 1, 13, Vector3(-2.15, y, 0), Vector3(90, 0, 0), 1.6, "사다리 칸", 1.0])
	_assemble(r, p)
	_solid(r, Vector3(-1.2, 0, 0), Vector3(1.6, 2.7, 1.6))


func _playhouse(r: Node3D) -> void:
	_assemble(r, [
		["box", Vector3(5.6, 4.4, 5.6), 1, Vector3(0, 1.1, 0), Vector3.ZERO, 1.0],
		["wedge", 0, 2, Vector3(-0.72, 2.95, 0), Vector3.ZERO, 2.9, "지붕 조각", 2.4],
		["wedge", 0, 2, Vector3(0.72, 2.95, 0), Vector3(0, 180, 0), 2.9, "지붕 조각", 2.4],
		["plate", 2, 12, Vector3(0, 0.75, 1.43), Vector3(90, 0, 0), 2.2, "놀이집 문", 2.2],
		["plate", 0, 7, Vector3(1.43, 1.3, 0), Vector3(90, 90, 0), 1.0, "놀이집 창문", 1.6],
		["cylinder", 2, 14, Vector3(0.8, 3.2, 0.6), Vector3.ZERO, 0.8, "굴뚝", 1.8],
	])
	_solid(r, Vector3.ZERO, Vector3(2.8, 2.4, 2.8))


func _sand_toys(r: Node3D) -> void:
	_assemble(r, [
		["cylinder", 0, 2, Vector3(0, 0.3, 0), Vector3.ZERO, 0.9, "모래 양동이", 1.0],
		["ring", 2, 4, Vector3(0, 0.6, 0), Vector3.ZERO, 0.75, "양동이 손잡이", 0.8],
		["plate", 2, 8, Vector3(0.8, 0.05, 0.3), Vector3(0, 30, 0), 0.8, "삽", 0.8],
		["rod", 1, 13, Vector3(0.8, 0.05, -0.25), Vector3(90, 30, 0), 0.9, "삽 자루", 0.8],
		["cone", 0, 10, Vector3(-0.8, 0.3, 0.2), Vector3.ZERO, 0.8, "모래성 탑", 1.0],
	])


func _build_playground() -> void:
	_place(_swing, Vector3(-10, 0, -5))
	_place(_seesaw, Vector3(-9, 0, 6.5))
	_place(_slide, Vector3(10.5, 0, -5))
	_place(_playhouse, Vector3(9.5, 0, 6.5))
	_place(_sand_toys, Vector3(2.5, 0, 1.5))
	_place(_sand_toys, Vector3(-2.8, 0, -1.8), 2.0)


# ── 동네 ─────────────────────────────────────────────

func _house(r: Node3D) -> void:
	_assemble(r, [
		["box", Vector3(8.4, 6.4, 8.4), 0, Vector3(0, 1.6, 0), Vector3.ZERO, 1.0],
		["wedge", Vector3(4.6, 3.4, 9.6), 12, Vector3(-1.15, 4.05, 0), Vector3.ZERO, 1.0],
		["wedge", Vector3(4.6, 3.4, 9.6), 12, Vector3(1.15, 4.05, 0), Vector3(0, 180, 0), 1.0],
		["plate", 2, 6, Vector3(0, 0.98, -2.14), Vector3(90, 0, 0), 3.0, "현관문", 3.0],
		["plate", 0, 7, Vector3(-1.3, 2.0, -2.14), Vector3(90, 0, 0), 1.2, "창문", 2.2],
		["plate", 0, 7, Vector3(1.3, 2.0, -2.14), Vector3(90, 0, 0), 1.2, "창문", 2.2],
		["cylinder", 3, 0, Vector3(0, 2.65, -2.17), Vector3(90, 0, 0), 1.0, "벽시계", 1.8],
		["cone", 1, 4, Vector3(0, 5.95, 0), Vector3.ZERO, 0.8, "지붕 장식", 2.0],
		["box", 2, 14, Vector3(1.4, 5.0, 1.2), Vector3.ZERO, 1.8, "굴뚝 벽돌", 2.4],
		["cylinder", 0, 3, Vector3(-1.6, 0.35, -2.6), Vector3.ZERO, 1.2, "화분", 1.4],
		["sphere", 2, 1, Vector3(-1.6, 0.85, -2.6), Vector3.ZERO, 0.9, "꽃", 0.6],
	])
	_solid(r, Vector3.ZERO, Vector3(4.2, 3.4, 4.2))


func _fan(r: Node3D) -> void:
	var p := [
		["hemi", 1, 7, Vector3(0, 0.1, 0), Vector3.ZERO, 1.2, "선풍기 받침", 1.8],
		["cylinder", 2, 0, Vector3(0, 0.82, 0), Vector3.ZERO, 1.0, "선풍기 기둥", 1.4],
		["sphere", 0, 7, Vector3(0, 1.55, 0), Vector3.ZERO, 0.8, "선풍기 모터", 1.8],
	]
	for i in 3:
		var a := i * 120.0
		var d := Vector3(cos(deg_to_rad(a)), sin(deg_to_rad(a)), 0) * 0.32
		p.append(["wedge", 1, 0, Vector3(d.x, 1.55 + d.y, 0.32), Vector3(90, 0, a), 0.7, "선풍기 날개", 1.3])
	_assemble(r, p)
	_solid(r, Vector3.ZERO, Vector3(0.8, 1.9, 0.8))


func _streetlight(r: Node3D) -> void:
	_assemble(r, [
		["cylinder", 2, 14, Vector3(0, 1.6, 0), Vector3.ZERO, 2.6, "가로등 기둥", 3.0],
		["sphere", 0, 4, Vector3(0, 3.25, 0), Vector3.ZERO, 0.75, "가로등 전구", 1.6],
		["hemi", 0, 15, Vector3(0, 3.5, 0), Vector3.ZERO, 0.9],
	])
	_solid(r, Vector3.ZERO, Vector3(0.4, 3.6, 0.4))


func _mailbox(r: Node3D) -> void:
	_assemble(r, [
		["rod", 0, 12, Vector3(0, 0.45, 0), Vector3.ZERO, 1.0],
		["box", 1, 2, Vector3(0, 1.05, 0), Vector3.ZERO, 0.9, "우체통", 1.8],
		["plate", 2, 4, Vector3(0.38, 1.25, 0.15), Vector3(90, 0, 0), 0.5, "우체통 깃발", 0.8],
	])
	_solid(r, Vector3.ZERO, Vector3(0.7, 1.3, 0.5))


func _trash(r: Node3D) -> void:
	_assemble(r, [
		["cylinder", 0, 6, Vector3(0, 0.48, 0), Vector3.ZERO, 1.6, "쓰레기통", 2.0],
		["hemi", 1, 6, Vector3(0, 1.0, 0), Vector3.ZERO, 1.25, "쓰레기통 뚜껑", 1.2],
	])
	_solid(r, Vector3.ZERO, Vector3(0.8, 1.1, 0.8))


func _fountain(r: Node3D) -> void:
	_assemble(r, [
		["cylinder", 3, 14, Vector3(0, 0.2, 0), Vector3.ZERO, 6.0],
		["ring", 2, 0, Vector3(0, 0.45, 0), Vector3.ZERO, 5.3],
		["cylinder", 2, 0, Vector3(0, 0.95, 0), Vector3.ZERO, 1.2, "분수 기둥", 2.6],
		["hemi", 1, 7, Vector3(0, 1.75, 0), Vector3(180, 0, 0), 1.4, "분수 그릇", 2.0],
		["sphere", 0, 7, Vector3(0, 2.1, 0), Vector3.ZERO, 0.5, "물방울", 1.0],
	])
	_solid(r, Vector3.ZERO, Vector3(3.4, 1.0, 3.4))


func _icecream(r: Node3D) -> void:
	var p := [
		["box", 1, 1, Vector3(0, 0.78, 0), Vector3.ZERO, 1.6],
		["rod", 2, 14, Vector3(0, 1.7, 0), Vector3.ZERO, 1.0],
		["cone", 2, 2, Vector3(0, 2.45, 0), Vector3.ZERO, 1.7, "파라솔", 2.0],
		["cone", 1, 13, Vector3(0.45, 1.4, 0), Vector3(180, 0, 0), 0.35, "아이스크림 콘", 1.0],
		["sphere", 0, 1, Vector3(0.45, 1.62, 0), Vector3.ZERO, 0.38, "아이스크림", 0.8],
		["sphere", 0, 11, Vector3(-0.35, 1.62, 0.1), Vector3.ZERO, 0.38, "아이스크림", 0.8],
	]
	for x in [-0.45, 0.45]:
		for z in [-0.42, 0.42]:
			p.append(["cylinder", 1, 15, Vector3(x, 0.25, z), Vector3(90, 0, 0), 0.65, "수레 바퀴", 1.6])
	_assemble(r, p)
	_solid(r, Vector3.ZERO, Vector3(1.4, 1.3, 1.0))


func _balloons(r: Node3D) -> void:
	var p := [["rod", 2, 14, Vector3(0, 0.8, 0), Vector3.ZERO, 0.9]]
	var cols := [2, 4, 8, 1, 10]
	for i in 5:
		var a := TAU * i / 5.0
		p.append(["sphere", 1, cols[i], Vector3(cos(a) * 0.45, 2.1 + 0.25 * sin(a * 2), sin(a) * 0.45), Vector3(0, 0, 90), 0.75, "풍선", 0.7])
	_assemble(r, p)
	_solid(r, Vector3.ZERO, Vector3(0.4, 1.6, 0.4))


func _bicycle(r: Node3D, col: int) -> void:
	_assemble(r, [
		["ring", 2, 15, Vector3(-0.55, 0.42, 0), Vector3(90, 0, 0), 1.15, "자전거 바퀴", 1.6],
		["ring", 2, 15, Vector3(0.55, 0.42, 0), Vector3(90, 0, 0), 1.15, "자전거 바퀴", 1.6],
		["rod", 2, col, Vector3(0, 0.6, 0), Vector3(0, 0, 90), 0.75, "자전거 프레임", 1.4],
		["rod", 1, col, Vector3(-0.2, 0.8, 0), Vector3(0, 0, 20), 0.9],
		["box", 1, 15, Vector3(-0.3, 1.02, 0), Vector3.ZERO, 0.42, "안장", 1.0],
		["rod", 2, 14, Vector3(0.5, 1.05, 0), Vector3(90, 0, 0), 0.5, "핸들", 1.0],
	])
	_solid(r, Vector3.ZERO, Vector3(1.6, 1.1, 0.4))


func _bench(r: Node3D) -> void:
	_assemble(r, [
		["plate", 3, 12, Vector3(0, 0.5, 0), Vector3.ZERO, 1.0, "벤치 판", 2.0],
		["plate", 3, 12, Vector3(0, 0.9, -0.26), Vector3(75, 0, 0), 1.0, "등받이", 2.0],
		["box", 2, 15, Vector3(-0.9, 0.24, 0), Vector3.ZERO, 0.5],
		["box", 2, 15, Vector3(0.9, 0.24, 0), Vector3.ZERO, 0.5],
	])
	_solid(r, Vector3.ZERO, Vector3(2.0, 1.0, 0.7))


func _tcone(r: Node3D) -> void:
	_assemble(r, [
		["cone", 1, 3, Vector3(0, 0.42, 0), Vector3.ZERO, 0.9, "고깔", 0.8],
		["plate", 1, 3, Vector3(0, 0.03, 0), Vector3.ZERO, 0.6],
	])


func _tree(r: Node3D) -> void:
	var rng := Game.rng
	_assemble(r, [
		["cylinder", 2, 12, Vector3(0, 1.2, 0), Vector3.ZERO, 2.0],
		["sphere", 0, 6, Vector3(0, 2.8, 0), Vector3.ZERO, 3.2],
		["sphere", 0, 5, Vector3(0.7, 2.35, 0.4), Vector3.ZERO, 2.1],
		["sphere", 0, 2, Vector3(rng.randf_range(-0.5, 0.5), 2.0, 0.95), Vector3.ZERO, 0.34, "사과", 0.7],
		["sphere", 0, 2, Vector3(-0.9, 2.5, rng.randf_range(-0.4, 0.4)), Vector3.ZERO, 0.34, "사과", 0.7],
	])
	_solid(r, Vector3.ZERO, Vector3(0.7, 3, 0.7))


func _station(r: Node3D) -> void:
	_assemble(r, [
		["box", Vector3(4.4, 0.7, 18), 14, Vector3(0, 0.17, 0), Vector3.ZERO, 1.0],
		["plate", 3, 10, Vector3(0.3, 3.0, 0), Vector3(0, 90, 0), 3.0],
		["cylinder", 2, 15, Vector3(0.5, 1.5, -3.5), Vector3.ZERO, 2.3],
		["cylinder", 2, 15, Vector3(0.5, 1.5, 3.5), Vector3.ZERO, 2.3],
		["cylinder", 3, 0, Vector3(0.5, 2.4, 0), Vector3(90, 90, 0), 0.9, "역 시계", 1.8],
		["box", 0, 13, Vector3(0.6, 0.6, -6), Vector3.ZERO, 1.1, "짐 상자", 1.6],
		["box", 1, 3, Vector3(0.6, 0.6, 6), Vector3.ZERO, 1.0, "여행 가방", 1.6],
	])
	_solid(r, Vector3.ZERO, Vector3(2.2, 0.35, 9))


func _build_town() -> void:
	_place(_house, Vector3(-20.8, 0, 1), PI / 2)
	_place(_house, Vector3(20.8, 0, -5), -PI / 2)
	_place(_fan, Vector3(-20.5, 0, -6.5))
	_place(_fan, Vector3(20.5, 0, 3.8))
	_place(_mailbox, Vector3(-18.0, 0, 5.8))
	_place(_trash, Vector3(12.5, 0, -15.6))
	_place(_trash, Vector3(-12.5, 0, 15.6))
	_place(_fountain, Vector3(-6, 0, -17.2))
	_place(_icecream, Vector3(-2.5, 0, 17.0))
	_place(_balloons, Vector3(3.5, 0, 17.4))
	_place(_bicycle, Vector3(-9.0, 0, 17.2), 0.0, 2)
	_place(_bicycle, Vector3(-7.3, 0, 17.4), 0.15, 8)
	_place(_bicycle, Vector3(8.0, 0, -16.8), PI, 4)
	_place(_bench, Vector3(-6, 0, -14.6), PI)
	_place(_bench, Vector3(6, 0, 15.2))
	_place(_bench, Vector3(0, 0, -10.5), PI)
	for c in [Vector2(17.6, 14.6), Vector2(-17.6, 14.6), Vector2(17.6, -14.6), Vector2(-17.6, -14.6)]:
		_place(_streetlight, Vector3(c.x, 0, c.y))
	for p in [Vector3(14.4, 0, 2), Vector3(14.4, 0, 3.2), Vector3(-14.4, 0, -2), Vector3(4, 0, 11.4)]:
		_place(_tcone, p)
	_place(_station, Vector3(29.2, 0, 0))
	for i in 12:
		var a := TAU * i / 12.0 + 0.2
		var rr := _boundary_r(a) - 3.0
		var p := Vector3(cos(a) * rr, 0, sin(a) * rr)
		if p.x > 24 and absf(p.z) < 11:
			continue
		_place(_tree, p, Game.rng.randf() * TAU)


# ── 움직이는 것: 차 · 기차 ───────────────────────────

func _path_len(path: Array) -> Array:
	var cum := [0.0]
	for i in path.size():
		cum.append(cum[-1] + (path[i] as Vector3).distance_to(path[(i + 1) % path.size()]))
	return cum


func _path_at(path: Array, cum: Array, s: float) -> Array:
	var total: float = cum[-1]
	s = fposmod(s, total)
	var i := 0
	while i < path.size() - 1 and cum[i + 1] < s:
		i += 1
	var a: Vector3 = path[i]
	var b: Vector3 = path[(i + 1) % path.size()]
	var f: float = (s - cum[i]) / maxf(0.0001, cum[i + 1] - cum[i])
	return [a.lerp(b, f), (b - a).normalized()]


func _car(r: Node3D, col: int) -> void:
	var p := [
		["box", Vector3(4.4, 1.5, 2.3), col, Vector3(0, 0.62, 0), Vector3.ZERO, 1.0],
		["box", Vector3(2.4, 1.0, 2.0), 7, Vector3(-0.25, 1.25, 0), Vector3.ZERO, 1.0],
		["rod", 2, 14, Vector3(-0.6, 1.95, 0.35), Vector3.ZERO, 0.5, "안테나", 0.9],
	]
	for x in [-0.75, 0.75]:
		for z in [-0.6, 0.6]:
			p.append(["cylinder", 1, 15, Vector3(x, 0.37, z), Vector3(90, 0, 0), 1.0, "자동차 바퀴", 2.0])
	for z in [-0.6, 0.6]:
		p.append(["plate", 0, col, Vector3(-0.1, 0.72, z), Vector3(90, 0, 0), 1.1, "자동차 문", 2.4])
	for z in [-0.35, 0.35]:
		p.append(["hemi", 1, 4, Vector3(1.12, 0.66, z), Vector3(0, 0, -90), 0.45, "전조등", 1.3])
	_assemble(r, p)


func _loco(r: Node3D) -> void:
	var p := [
		["box", Vector3(5.6, 0.8, 2.6), 15, Vector3(0, 0.55, 0), Vector3.ZERO, 1.0],
		["cylinder", Vector3(2.0, 3.6, 2.0), 2, Vector3(0.55, 1.35, 0), Vector3(0, 0, 90), 1.0],
		["box", Vector3(2.6, 2.6, 2.6), 2, Vector3(-0.85, 1.55, 0), Vector3.ZERO, 1.0],
		["cylinder", 2, 15, Vector3(1.25, 2.25, 0), Vector3.ZERO, 0.75, "기차 굴뚝", 2.2],
		["cone", 2, 15, Vector3(1.25, 2.85, 0), Vector3(180, 0, 0), 0.75, "굴뚝 깔때기", 1.5],
		["sphere", 0, 4, Vector3(1.7, 1.35, 0), Vector3.ZERO, 0.55, "기차 전조등", 1.2],
		["hemi", 2, 4, Vector3(0.1, 2.0, 0), Vector3.ZERO, 0.5, "기차 종", 1.4],
		["plate", 2, 7, Vector3(-0.85, 1.85, -1.32), Vector3(90, 0, 0), 1.1, "기차 창문", 2.0],
		["plate", 2, 7, Vector3(-0.85, 1.85, 1.32), Vector3(90, 0, 0), 1.1, "기차 창문", 2.0],
	]
	for x in [-1.0, 0.0, 1.0]:
		for z in [-0.7, 0.7]:
			p.append(["cylinder", 1, 15, Vector3(x, 0.42, z), Vector3(90, 0, 0), 1.05, "기차 바퀴", 2.4])
	_assemble(r, p)


func _wagon(r: Node3D, kind: int) -> void:
	var p := [["box", Vector3(5.2, 0.4, 2.4), 12, Vector3(0, 0.78, 0), Vector3.ZERO, 1.0]]
	for x in [-0.8, 0.8]:
		for z in [-0.62, 0.62]:
			p.append(["cylinder", 1, 15, Vector3(x, 0.4, z), Vector3(90, 0, 0), 1.0, "화물칸 바퀴", 2.2])
	if kind == 0:
		p.append(["cylinder", 0, 3, Vector3(-0.6, 1.25, 0.3), Vector3.ZERO, 1.3, "나무통", 1.8])
		p.append(["cylinder", 0, 12, Vector3(-0.6, 1.25, -0.32), Vector3.ZERO, 1.3, "나무통", 1.8])
		p.append(["box", 0, 13, Vector3(0.6, 1.2, 0), Vector3.ZERO, 1.5, "화물 상자", 1.8])
		p.append(["box", 1, 5, Vector3(0.6, 1.72, 0), Vector3.ZERO, 0.9, "작은 상자", 1.2])
	else:
		p.append(["ring", 1, 15, Vector3(-0.6, 1.2, 0), Vector3.ZERO, 1.25, "타이어", 2.0])
		p.append(["sphere", 0, 8, Vector3(0.55, 1.35, 0.3), Vector3.ZERO, 1.2, "큰 공", 1.4])
		p.append(["cone", 0, 3, Vector3(0.55, 1.25, -0.4), Vector3.ZERO, 0.9, "고깔", 1.0])
		p.append(["capsule", 2, 10, Vector3(-0.6, 1.55, 0), Vector3(90, 0, 0), 0.9, "베개", 1.2])
	_assemble(r, p)


func _vehicle(builder: Callable, arg, path: Array, s0: float, speed: float, stops: Array, box: Vector3) -> Dictionary:
	var body := AnimatableBody3D.new()
	body.collision_layer = L_WORLD
	body.sync_to_physics = true
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box
	cs.shape = sh
	cs.position.y = box.y * 0.5
	body.add_child(cs)
	world.add_child(body)
	if arg == null:
		builder.call(body)
	else:
		builder.call(body, arg)
	var v := {"body": body, "path": path, "cum": _path_len(path), "s": s0, "speed": speed,
		"stops": stops, "wait": 0.0, "follow": null, "gap": 0.0}
	vehicles.append(v)
	_move_vehicle(v, 0.0)
	return v


func _build_vehicles() -> void:
	var road_len: float = _path_len(road_path)[-1]
	var cols := [2, 8, 4]
	for i in 3:
		_vehicle(_car, cols[i], road_path, road_len * i / 3.0, 2.8, [road_len * (i * 0.33 + 0.12)], Vector3(2.3, 1.6, 1.3))
	# 기차: 역(각도 0)에서 선다
	var loco := _vehicle(_loco, null, rail_path, 6.0, 3.4, [0.0], Vector3(2.9, 2.8, 1.4))
	var prev := loco
	for k in 2:
		var w := _vehicle(_wagon, k, rail_path, 6.0 - 3.2 * (k + 1), 3.4, [], Vector3(2.7, 1.6, 1.3))
		w["follow"] = loco
		w["gap"] = 3.2 * (k + 1)
		prev = w


func _move_vehicle(v: Dictionary, delta: float) -> void:
	if v["follow"] != null:
		v["s"] = v["follow"]["s"] - v["gap"]
	else:
		if v["wait"] > 0.0:
			v["wait"] -= delta
		else:
			var total: float = v["cum"][-1]
			var before := fposmod(v["s"], total)
			v["s"] += v["speed"] * delta
			var after := fposmod(v["s"], total)
			for st in v["stops"]:
				var stp: float = st
				var crossed := (before < stp and after >= stp) or (before > after and (stp >= before or stp < after))
				if crossed and delta > 0.0:
					v["wait"] = 7.0 if v["path"] == rail_path else 3.5
	var at := _path_at(v["path"], v["cum"], v["s"])
	var pos: Vector3 = at[0]
	var dir: Vector3 = at[1]
	var body: AnimatableBody3D = v["body"]
	body.global_transform = Transform3D(Basis(Vector3.UP, atan2(-dir.z, dir.x)), pos)


# ── 편성 ─────────────────────────────────────────────

## 편성에 비례해 녹슨다. 그 종류가 평균(1인당 2개)보다 귀한 만큼 그 종류 부품이 녹슬어서 안 빠진다.
## 풍족 판이면 거의 다 빠지고, 곡면 기근이면 둥근 부품 대부분이 녹슨다 — 편성이 맵에서 보인다.
func _claim_formation() -> void:
	var avg := float(Game.PLAYERS * 24) / Data.TYPES.size()
	var by_type := {}
	for tr in tears:
		if not tr["dig"]:
			var t: String = tr["item"]["type"]
			if not by_type.has(t):
				by_type[t] = []
			by_type[t].append(tr)
	for t in by_type:
		var list: Array = by_type[t]
		list.shuffle()
		var frac := clampf(float(Game.counts.get(t, 0)) / avg, 0.08, 1.0)
		var keep := ceili(list.size() * frac)
		for k in range(keep, list.size()):
			list[k]["bolted"] = true
			(list[k]["node"] as Piece).set_rusty()
	Game.set_meta("ground_left", Game.counts.duplicate())


func _inside(p: Vector2, margin := 2.0) -> bool:
	var a := atan2(p.y, p.x)
	return p.length() < _boundary_r(a) - margin


func _spawn_ground_items() -> void:
	var left: Dictionary = Game.get_meta("ground_left")
	var rng := Game.rng
	var zones := {
		"curve": [Vector2(11, 0), Vector2(0, -20), Vector2(24, -14)],
		"angle": [Vector2(-11, 0), Vector2(-22, 12), Vector2(0, 20)],
		"irr": [Vector2(0, 0), Vector2(-24, -12), Vector2(14, 18)],
	}
	for t in Data.TYPES:
		var n: int = left.get(t, 0)
		if Data.KIND[t] == "irr":
			n = maxi(0, n - 6)
		n = int(n * 0.6)
		for k in n:
			var cs: Array = zones[Data.KIND[t]]
			var c: Vector2 = cs[rng.randi() % cs.size()]
			var p := c + Vector2(rng.randfn(0, 4.5), rng.randfn(0, 4.5))
			if not _inside(p):
				p = c
			_add_ground(Data.random_item(t, "ground", rng), Vector3(p.x, 0, p.y))


func _add_ground(item: Dictionary, p: Vector3) -> void:
	var pc := Piece.from_item(item, true)
	var k := 1.6
	pc.set_pscale(item["shape"] * k, false)
	pc.rotation.y = Game.rng.randf() * TAU
	pc.mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pc.position = Vector3(p.x, Data.base_size(item["type"]).y * item["shape"].y * k * 0.5 + 0.02, p.z)
	world.add_child(pc)
	var e := {"node": pc, "item": item, "alive": true}
	pc.set_meta("entry", e)
	ground.append(e)


# ── 캐릭터 (덩어리로 지은 아이 · 동물) ─────────────────

func _character(i: int) -> Node3D:
	var p: Dictionary = Game.players[i]
	var c: int = p["color"]
	var root := Node3D.new()
	var parts := [
		["capsule", 2, c, Vector3(0, 0.62, 0), Vector3.ZERO, 1.25],
		["sphere", 0, c if i != 0 else 0, Vector3(0, 1.42, 0), Vector3.ZERO, 1.05],
		["sphere", 0, 15, Vector3(-0.13, 1.48, -0.29), Vector3.ZERO, 0.13],
		["sphere", 0, 15, Vector3(0.13, 1.48, -0.29), Vector3.ZERO, 0.13],
	]
	match p["name"]:
		"나":
			parts.append(["hemi", 0, 8, Vector3(0, 1.62, 0.02), Vector3.ZERO, 1.08])
			parts.append(["plate", 0, 8, Vector3(0, 1.66, -0.28), Vector3.ZERO, 0.55])
		"곰돌이":
			parts.append(["hemi", 0, 12, Vector3(-0.24, 1.72, 0), Vector3.ZERO, 0.42])
			parts.append(["hemi", 0, 12, Vector3(0.24, 1.72, 0), Vector3.ZERO, 0.42])
			parts.append(["sphere", 0, 13, Vector3(0, 1.34, -0.3), Vector3.ZERO, 0.38])
		"토끼":
			parts.append(["capsule", 1, c, Vector3(-0.14, 1.95, 0), Vector3(0, 0, 8), 0.75])
			parts.append(["capsule", 1, c, Vector3(0.14, 1.95, 0), Vector3(0, 0, -8), 0.75])
		"펭귄":
			parts.append(["hemi", 2, 0, Vector3(0, 0.72, -0.2), Vector3(-90, 0, 0), 0.8])
			parts.append(["cone", 1, 3, Vector3(0, 1.36, -0.36), Vector3(-90, 0, 0), 0.3])
		"여우":
			parts.append(["cone", 1, c, Vector3(-0.2, 1.82, 0), Vector3(0, 0, 12), 0.45])
			parts.append(["cone", 1, c, Vector3(0.2, 1.82, 0), Vector3(0, 0, -12), 0.45])
			parts.append(["cone", 1, 0, Vector3(0, 1.36, -0.36), Vector3(-90, 0, 0), 0.35])
		"고양이":
			parts.append(["cone", 0, c, Vector3(-0.2, 1.78, 0), Vector3(0, 0, 14), 0.35])
			parts.append(["cone", 0, c, Vector3(0.2, 1.78, 0), Vector3(0, 0, -14), 0.35])
	for q in parts:
		var shp := _shape_of(q[0], q[1])
		var pc := Piece.new().setup(q[0], q[2], false, shp)
		pc.set_pscale(shp * float(q[5]), false)
		pc.position = q[3]
		pc.rotation_degrees = q[4]
		root.add_child(pc)
	return root


func _spawn_actors() -> void:
	var spots := [Vector3(0, 0, 18.5), Vector3(-12, 0, 14.5), Vector3(12, 0, 14.5),
		Vector3(-12, 0, -14.5), Vector3(12, 0, -14.5), Vector3(4, 0, -18.5)]
	for i in Game.PLAYERS:
		var p: Dictionary = Game.players[i]
		var body := CharacterBody3D.new()
		body.collision_layer = L_CHAR
		body.collision_mask = L_WORLD
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.7
		cs.shape = cap
		cs.position.y = 0.85
		body.add_child(cs)
		var vis := _character(i)
		body.add_child(vis)
		var name_l := UI.label3d(p["name"], 44)
		name_l.position = Vector3(0, 2.45, 0)
		body.add_child(name_l)
		var stack := Node3D.new()
		stack.position = Vector3(0, 2.15, 0)
		body.add_child(stack)
		body.position = spots[i] + Vector3(0, 0.2, 0)
		body.rotation.y = atan2(spots[i].x, spots[i].z)
		world.add_child(body)
		actors.append({"i": i, "body": body, "vis": vis, "stack": stack, "bot": p["is_bot"] or Game.autotest,
			"goal": {}, "prog": 0.0, "stuck_t": 0.0, "last_pos": body.position, "side_t": 0.0,
			"side": Vector3.ZERO, "walk_t": 0.0})
	cam_yaw = actors[0]["body"].rotation.y


func _inv(a: Dictionary) -> Array:
	return Game.players[a["i"]]["inventory"]


func _give(a: Dictionary, item: Dictionary) -> void:
	_inv(a).append(item)
	if not a["bot"]:
		slot = _inv(a).size() - 1
		_refresh_hotbar()
		var how: String = {"tear": "뜯었다", "dig": "팠다"}.get(item["origin"], "주웠다")
		_toast("%s %s!  (%d/%d)" % [item["name"], how, _inv(a).size(), HOLD_MAX])
	else:
		_refresh_stack(a)


func _refresh_stack(a: Dictionary) -> void:
	for c in a["stack"].get_children():
		c.queue_free()
	var inv := _inv(a)
	var y := 0.0
	for k in range(maxi(0, inv.size() - 3), inv.size()):
		var pc := Piece.from_item(inv[k], false)
		pc.set_pscale(inv[k]["shape"] * 0.55, false)
		pc.position = Vector3(0, y, 0)
		a["stack"].add_child(pc)
		y += 0.32


func _finish_tear(a: Dictionary, tr: Dictionary) -> void:
	if not tr["alive"] or tr["bolted"] or _inv(a).size() >= HOLD_MAX:
		return
	var item: Dictionary
	if tr["dig"]:
		var pool := ["potato", "pebble", "potato", "pebble", "sphere", "hemi", "cone"]
		item = Data.random_item(pool[Game.rng.randi() % pool.size()], "dig", Game.rng)
		if not a["bot"]:
			Sfx.play("dig")
	else:
		item = tr["item"].duplicate()
		if not a["bot"]:
			Sfx.play("tear")
	tr["uses"] -= 1
	if tr["uses"] <= 0:
		tr["alive"] = false
		var n: Piece = tr["node"]
		if tr["dig"]:
			n.set_pscale(n.pscale * Vector3(1, 0.25, 1), false)
		else:
			n.visible = false
			if n.body:
				n.body.collision_layer = 0
	_give(a, item)


func _take_ground(a: Dictionary, g: Dictionary) -> void:
	if not g["alive"] or _inv(a).size() >= HOLD_MAX:
		return
	g["alive"] = false
	(g["node"] as Node3D).queue_free()
	if not a["bot"]:
		Sfx.play("pick")
	_give(a, g["item"])


# ── 진행 ─────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if finished:
		return
	time_left -= delta
	for v in vehicles:
		_move_vehicle(v, delta)
	for a in actors:
		if a["bot"]:
			_bot_step(a, delta)
		else:
			_human_step(a, delta)
	_update_camera()
	_update_aim()
	_update_visibility()
	_update_hud(delta)
	if time_left <= 0:
		_end()


func _move_body(a: Dictionary, v: Vector3, delta: float, jump := false) -> void:
	var body: CharacterBody3D = a["body"]
	var vel := body.velocity
	vel.x = v.x * SPEED
	vel.z = v.z * SPEED
	if body.is_on_floor():
		if jump:
			vel.y = JUMP_V
			if not a["bot"]:
				Sfx.play("jump", -8.0)
	else:
		vel.y -= GRAVITY * delta
	body.velocity = vel
	body.move_and_slide()
	var moving := Vector2(v.x, v.z).length() > 0.1
	if moving:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-v.x, -v.z), 1.0 - exp(-14.0 * delta))
		a["walk_t"] += delta
	var vis: Node3D = a["vis"]
	vis.position.y = absf(sin(a["walk_t"] * 9.0)) * 0.09 if moving and body.is_on_floor() else lerpf(vis.position.y, 0.0, 0.3)


func _human_step(a: Dictionary, delta: float) -> void:
	var body: CharacterBody3D = a["body"]
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): dir.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): dir.x += 1
	var v := Vector3.ZERO
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		v = Basis(Vector3.UP, cam_yaw) * Vector3(dir.x, 0, dir.y)
	_move_body(a, v, delta, jump_req)
	jump_req = false
	if body.is_on_floor() and not was_floor:
		Sfx.play("land", -10.0)
	was_floor = body.is_on_floor()
	if v != Vector3.ZERO and body.is_on_floor():
		step_t -= delta
		if step_t <= 0:
			step_t = 0.36
			Sfx.play("step", -16.0, 0.12)
	# 뜯기: [E] 또는 좌클릭을 누르고 있는 동안
	hud_bar.visible = false
	var holding := Input.is_physical_key_pressed(KEY_E) or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	if aim.is_empty() or not aim.has("hold") or aim["bolted"] or not holding or _inv(a).size() >= HOLD_MAX:
		hold_prog = 0.0
		hold_target = {}
		return
	if hold_target != aim:
		hold_target = aim
		hold_prog = 0.0
	hold_prog += delta / aim["hold"]
	tick_t -= delta
	if tick_t <= 0:
		tick_t = 0.3
		Sfx.play("tick", -6.0, 0.15)
	hud_bar.visible = true
	hud_bar.value = hold_prog * 100
	if hold_prog >= 1.0:
		hold_prog = 0.0
		_finish_tear(a, aim)


## 화면 가운데 조준점에 가장 가까이 걸린, 손이 닿는 것
func _update_aim() -> void:
	var body: CharacterBody3D = actors[0]["body"]
	var origin := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var best: Dictionary = {}
	var best_a := deg_to_rad(AIM_DEG)
	var me := body.global_position + Vector3(0, 0.9, 0)
	for list in [ground, tears]:
		for e in list:
			if not e["alive"]:
				continue
			var n: Piece = e["node"]
			if not n.visible:
				continue
			var p := n.global_position
			if p.distance_to(me) > REACH:
				continue
			var ang := fwd.angle_to(p - origin)
			if ang < best_a:
				best_a = ang
				best = e
	if best != aim:
		if not aim.is_empty() and is_instance_valid(aim["node"]) and not aim.get("bolted", false):
			(aim["node"] as Piece).set_highlight(false)
		aim = best
		if not aim.is_empty() and not aim.get("bolted", false):
			(aim["node"] as Piece).set_highlight(true)
	if aim.is_empty():
		hud_prompt.text = ""
	elif aim.has("hold"):
		if aim["bolted"]:
			var t: String = aim["item"]["type"]
			var scarce: bool = Game.counts.get(t, 0) < float(Game.PLAYERS * 24) / Data.TYPES.size() * 0.6
			hud_prompt.text = "%s — 녹슬어서 안 빠진다%s" % [aim["name"], ("  (이번 판엔 %s가 귀하다)" % Data.NAMES[t]) if scarce else ""]
		elif _inv(actors[0]).size() >= HOLD_MAX:
			hud_prompt.text = "가방이 꽉 찼다 — [Q]로 하나 버리기"
		elif aim["dig"]:
			hud_prompt.text = "[E] 꾹 — 모래 파기 → 뭐가 나올지 몰라요"
		else:
			hud_prompt.text = "[E] 꾹 — %s 뜯기 → %s" % [aim["name"], aim["item"]["name"]]
	else:
		hud_prompt.text = "[E] 줍기 — %s (%s)" % [aim["item"]["name"], Data.palette()[aim["item"]["color"]]["name"]]


func _drop_selected() -> void:
	var a: Dictionary = actors[0]
	var inv := _inv(a)
	if inv.is_empty():
		return
	slot = clampi(slot, 0, inv.size() - 1)
	var it: Dictionary = inv.pop_at(slot)
	slot = clampi(slot, 0, maxi(0, inv.size() - 1))
	var body: CharacterBody3D = a["body"]
	var fwd := Basis(Vector3.UP, cam_yaw) * Vector3(0, 0, -1)
	_add_ground(it, body.position + fwd * 1.6)
	Sfx.play("drop", -4.0)
	_refresh_hotbar()
	_toast("%s 버림 — 누군가 주워갈 수도" % it["name"])


# ── 봇 ───────────────────────────────────────────────

func _bot_step(a: Dictionary, delta: float) -> void:
	var body: CharacterBody3D = a["body"]
	var goal: Dictionary = a["goal"]
	if _inv(a).size() >= HOLD_MAX:
		_move_body(a, Vector3.ZERO, delta)
		return
	if goal.is_empty() or not goal["ref"]["alive"] or (goal["kind"] == "tear" and goal["ref"]["bolted"]):
		a["prog"] = 0.0
		a["goal"] = _bot_choose(a)
		goal = a["goal"]
		if goal.is_empty():
			_move_body(a, Vector3.ZERO, delta)
			return
	var gp: Vector3 = (goal["ref"]["node"] as Node3D).global_position
	var to := Vector3(gp.x - body.position.x, 0, gp.z - body.position.z)
	var reach := 1.3 if goal["kind"] == "ground" else 2.4
	if to.length() > reach:
		var v := to.normalized()
		if a["side_t"] > 0:
			a["side_t"] -= delta
			v = (v + a["side"]).normalized()
		_move_body(a, v, delta)
		a["stuck_t"] += delta
		if a["stuck_t"] > 1.2:
			if body.position.distance_to(a["last_pos"]) < 0.6:
				a["side"] = Vector3(-v.z, 0, v.x) * (1 if Game.rng.randf() < 0.5 else -1) * 1.5
				a["side_t"] = 0.9
			a["stuck_t"] = 0.0
			a["last_pos"] = body.position
		return
	_move_body(a, Vector3.ZERO, delta)
	if goal["kind"] == "ground":
		_take_ground(a, goal["ref"])
		a["goal"] = {}
	else:
		a["prog"] += delta / goal["ref"]["hold"]
		if a["prog"] >= 1.0:
			_finish_tear(a, goal["ref"])
			a["goal"] = {}


func _bot_choose(a: Dictionary) -> Dictionary:
	var body: CharacterBody3D = a["body"]
	var have := {}
	for it in _inv(a):
		have[it["type"]] = have.get(it["type"], 0) + 1
	var claimed := {}
	for o in actors:
		if o != a and not o["goal"].is_empty():
			claimed[o["goal"]["ref"]["node"]] = true
	var best: Dictionary = {}
	var bs := INF
	for g in ground:
		if not g["alive"] or claimed.has(g["node"]):
			continue
		var d: float = body.position.distance_to((g["node"] as Node3D).global_position)
		var s: float = d - _desire(g["item"]["type"], have) * 4.0 + Game.rng.randf() * 2.0
		if s < bs:
			bs = s
			best = {"kind": "ground", "ref": g}
	for tr in tears:
		if not tr["alive"] or tr["bolted"] or claimed.has(tr["node"]):
			continue
		var d: float = body.position.distance_to((tr["node"] as Node3D).global_position)
		var t: String = "potato" if tr["dig"] else tr["item"]["type"]
		var s: float = d + tr["hold"] * SPEED * 0.8 - _desire(t, have) * 4.0 + Game.rng.randf() * 2.0
		if s < bs:
			bs = s
			best = {"kind": "tear", "ref": tr}
	return best


func _desire(t: String, have: Dictionary) -> float:
	var w: float = wanted.get(t, 0)
	return w / (1.0 + have.get(t, 0) * 0.8)


# ── 카메라: 3인칭 어깨 시점 ──────────────────────────

func _build_camera() -> void:
	cam_pivot = Node3D.new()
	add_child(cam_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 5.2
	spring.collision_mask = L_WORLD
	spring.margin = 0.3
	var sph := SphereShape3D.new()
	sph.radius = 0.25
	spring.shape = sph
	cam_pivot.add_child(spring)
	cam = Camera3D.new()
	cam.fov = 62
	cam.position = Vector3(0.7, 0, 0)
	spring.add_child(cam)
	spring.add_excluded_object(actors[0]["body"].get_rid())


func _update_camera() -> void:
	var body: CharacterBody3D = actors[0]["body"]
	var target := body.global_position + Vector3(0, 1.75, 0)
	cam_pivot.global_position = cam_pivot.global_position.lerp(target, 0.35) if cam_pivot.global_position.distance_to(target) < 6 else target
	cam_pivot.rotation = Vector3(cam_pitch, cam_yaw, 0)


func _update_visibility() -> void:
	var me: Vector3 = actors[0]["body"].position
	for a in actors:
		if a["bot"] and a["i"] != 0:
			a["stack"].visible = a["body"].position.distance_to(me) < PEEK_R


func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and (captured or (event.button_mask & MOUSE_BUTTON_MASK_RIGHT)):
		cam_yaw -= event.relative.x * 0.0045
		cam_pitch = clampf(cam_pitch - event.relative.y * 0.0035, -1.25, 0.45)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if not captured:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
					capture_hint.visible = false
				else:
					_try_pick()
			MOUSE_BUTTON_WHEEL_UP:
				_select_slot(slot - 1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_select_slot(slot + 1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE: jump_req = true
			KEY_E: _try_pick()
			KEY_Q: _drop_selected()
			KEY_ESCAPE, KEY_TAB:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				capture_hint.visible = true
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				_select_slot(event.physical_keycode - KEY_1)
			KEY_0: _select_slot(9)


func _try_pick() -> void:
	if aim.is_empty() or aim.has("hold"):
		return
	if _inv(actors[0]).size() >= HOLD_MAX:
		Sfx.play("error", -6.0)
		_toast("가방이 꽉 찼다 — [Q]로 버리고 줍자")
		return
	_take_ground(actors[0], aim)
	aim = {}


func _select_slot(i: int) -> void:
	var n := maxi(1, _inv(actors[0]).size())
	slot = posmod(i, n)
	Sfx.play("select", -14.0)
	_refresh_hotbar()


# ── HUD ──────────────────────────────────────────────

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var tl := UI.panel()
	var tv := UI.vbox(2)
	tl.add_child(tv)
	hud_time = UI.label("", 40, UI.INK, true)
	tv.add_child(hud_time)
	tv.add_child(UI.label("만들 것: 「%s」" % Game.target["name"], 26, UI.INK, true))
	tv.add_child(UI.label("할당량 ★%.1f 이상 %d명 · 재료 %s" % [Game.quota[0], Game.quota[1], Game.formation], 20, UI.SOFT))
	var card: Dictionary = Game.human()["card"]
	tv.add_child(UI.label("카드 「%s」 %s" % [card["name"], card["desc"]], 20, UI.ACCENT))
	var done := UI.button("수집 끝내기 →", _end, 18)
	tv.add_child(done)
	layer.add_child(tl)
	UI.corner(tl, Control.PRESET_TOP_LEFT)

	minimap = Control.new()
	minimap.custom_minimum_size = Vector2(190, 190)
	minimap.draw.connect(_draw_minimap)
	var mp := UI.panel()
	mp.add_child(minimap)
	layer.add_child(mp)
	UI.corner(mp, Control.PRESET_TOP_RIGHT)

	# 핫바
	var bar := UI.panel()
	var bv := UI.vbox(2)
	bar.add_child(bv)
	hotbar = UI.hbox(5)
	bv.add_child(hotbar)
	for k in HOLD_MAX:
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(58, 58)
		var idx := k
		cell.draw.connect(func(): _draw_slot(cell, idx))
		cell.gui_input.connect(func(ev): _slot_input(ev, idx))
		hotbar.add_child(cell)
		hot_slots.append(cell)
	var help := UI.label("WASD 이동 · 마우스 시점 · Space 점프 · [E]/좌클릭 줍기 · [E] 꾹 뜯기 · 휠/숫자 칸 고르기 · [Q] 버리기 · Esc 마우스 풀기", 16, UI.SOFT)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(help)
	layer.add_child(bar)
	UI.corner(bar, Control.PRESET_CENTER_BOTTOM, Vector2(0, 10))

	var cv := UI.vbox(6)
	cv.alignment = BoxContainer.ALIGNMENT_END
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_prompt = UI.label("", 26, UI.INK, true)
	hud_prompt.add_theme_color_override("font_outline_color", Color.WHITE)
	hud_prompt.add_theme_constant_override("outline_size", 8)
	hud_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(hud_prompt)
	hud_bar = ProgressBar.new()
	hud_bar.custom_minimum_size = Vector2(260, 18)
	hud_bar.show_percentage = false
	hud_bar.visible = false
	cv.add_child(hud_bar)
	toast = UI.label("", 24, UI.GOOD, true)
	toast.add_theme_color_override("font_outline_color", Color.WHITE)
	toast.add_theme_constant_override("outline_size", 8)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(toast)
	layer.add_child(cv)
	UI.corner(cv, Control.PRESET_CENTER_BOTTOM, Vector2(0, 118))

	crosshair = Control.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(func():
		var c := crosshair.size * 0.5
		crosshair.draw_circle(c, 4.5, Color(1, 1, 1, 0.9))
		crosshair.draw_arc(c, 6.0, 0, TAU, 20, Color(UI.INK, 0.8), 1.5))
	layer.add_child(UI.full(crosshair))

	capture_hint = UI.label("화면을 클릭하면 마우스로 둘러볼 수 있어요  (Esc로 풀기)", 24, UI.INK, true)
	capture_hint.add_theme_color_override("font_outline_color", Color.WHITE)
	capture_hint.add_theme_constant_override("outline_size", 10)
	layer.add_child(capture_hint)
	UI.corner(capture_hint, Control.PRESET_CENTER_TOP, Vector2(0, 30))
	_refresh_hotbar()


func _slot_input(ev: InputEvent, idx: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_select_slot(idx)


func _refresh_hotbar() -> void:
	for c in hot_slots:
		c.queue_redraw()


func _draw_slot(cell: Control, idx: int) -> void:
	var inv := _inv(actors[0])
	var r := Rect2(Vector2.ZERO, cell.size)
	var sel := idx == slot and idx < inv.size()
	cell.draw_style_box(_slot_box(sel), r)
	cell.draw_string(Data.font_bold, Vector2(4, 14), str((idx + 1) % 10) if idx < 10 else "", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UI.SOFT, 0.7))
	if idx < inv.size():
		UI.draw_chunk_icon(cell, inv[idx], Rect2(Vector2(8, 6), cell.size - Vector2(16, 18)))
		var nm: String = inv[idx]["name"]
		cell.draw_string(Data.font_regular, Vector2(0, cell.size.y - 3), nm, HORIZONTAL_ALIGNMENT_CENTER, cell.size.x, 13, UI.INK)


var _sb_cache := {}
func _slot_box(sel: bool) -> StyleBoxFlat:
	if _sb_cache.has(sel):
		return _sb_cache[sel]
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FBEFD9") if not sel else Color("#FFE3A8")
	sb.set_corner_radius_all(8)
	sb.border_color = UI.ACCENT if sel else Color("#D9C3A5")
	sb.set_border_width_all(3 if sel else 2)
	_sb_cache[sel] = sb
	return sb


func _toast(s: String) -> void:
	toast.text = s
	toast_t = 1.8


func _update_hud(delta: float) -> void:
	hud_time.text = "수집 " + UI.clock(time_left)
	hud_time.add_theme_color_override("font_color", UI.BAD if time_left < 30 else UI.INK)
	toast_t -= delta
	if toast_t <= 0:
		toast.text = ""
	crosshair.visible = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	minimap.queue_redraw()


func _draw_minimap() -> void:
	var sz := minimap.size
	var R := 42.0
	var k := sz.x / (R * 2)
	var f := func(p: Vector3) -> Vector2: return Vector2((p.x + R) * k, (p.z + R) * k)
	minimap.draw_rect(Rect2(Vector2.ZERO, sz), Color("#7FB069"))
	var poly := PackedVector2Array()
	for b in boundary:
		poly.append(Vector2((b.x + R) * k, (b.y + R) * k))
	minimap.draw_colored_polygon(poly, Color("#A9CF8E"))
	var road := PackedVector2Array()
	for p in road_path:
		road.append(f.call(p))
	road.append(road[0])
	minimap.draw_polyline(road, Color("#8E8A86"), 3.0)
	var rail := PackedVector2Array()
	for p in rail_path:
		rail.append(f.call(p))
	rail.append(rail[0])
	minimap.draw_polyline(rail, Color("#8A5A3B"), 2.0)
	minimap.draw_circle(f.call(Vector3.ZERO), 6 * k, Color("#EBD8A8"))
	for g in ground:
		if g["alive"]:
			minimap.draw_circle(f.call((g["node"] as Node3D).global_position), 1.3, Data.color(g["item"]["color"]).darkened(0.25))
	for v in vehicles:
		minimap.draw_rect(Rect2(f.call((v["body"] as Node3D).global_position) - Vector2(3, 3), Vector2(6, 6)), Color("#D9483B"))
	for a in actors:
		var c := Data.color(Game.players[a["i"]]["color"])
		var r := 5.5 if a["i"] == 0 else 3.5
		minimap.draw_circle(f.call(a["body"].position), r, c)
		if a["i"] == 0:
			minimap.draw_arc(f.call(a["body"].position), r + 2, 0, TAU, 16, UI.INK, 2.0)
			var d := Vector2(-sin(cam_yaw), -cos(cam_yaw)) * 12
			minimap.draw_line(f.call(a["body"].position), f.call(a["body"].position) + d, UI.INK, 2.0)


func _end() -> void:
	if finished:
		return
	finished = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var rng := Game.rng
	var alive := []
	for g in ground:
		if g["alive"]:
			alive.append(g)
	alive.shuffle()
	for a in actors:
		var inv := _inv(a)
		# 미수집분 자동 채움: 맵에 남은 것에서 랜덤
		while inv.size() < HOLD_MAX:
			if not alive.is_empty():
				var g: Dictionary = alive.pop_back()
				var it: Dictionary = g["item"].duplicate()
				it["origin"] = "auto"
				inv.append(it)
			else:
				inv.append(Data.random_item(Data.TYPES[rng.randi() % Data.TYPES.size()], "auto", rng))
	Sfx.play("whoosh", -6.0)
	Game.goto("build")
