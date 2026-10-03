class_name Piece
extends Node3D
## 덩어리 하나. 필드 · 손 · 작업대 · 전시 어디서나 같은 노드, 같은 재질.
## 구조: Piece(위치·회전) → Vis(로컬 배율) → Mesh(기본 변환)
##       Piece → Body(배율 없음. 충돌 점을 배율에 맞춰 굽는다 — 물리 바디에 배율을 걸지 않는다)
## 배율 = 비율(shape, 덩어리마다 고정) × 크기(size, 조립에서 조절)

const LAYER_PIECE := 2

var type := "box"
var shape := Vector3.ONE
var size := 1.0
var pscale := Vector3.ONE
var color_idx := 0
var origin := "ground"
var inv_index := -1
var big := false      # 크게 키운 덩어리(받침대·모래밭 등)는 외곽선이 같이 두꺼워지므로 외곽선 없이
var mkey := ""        # 변형 고유 메시 (육각기둥·별 판 등)

var vis: Node3D
var mesh_inst: MeshInstance3D
var body: StaticBody3D
var shape_node: CollisionShape3D


func setup(t: String, ci: int, collide := true, shp := Vector3.ONE) -> Piece:
	type = t
	color_idx = ci
	shape = shp
	vis = Node3D.new()
	add_child(vis)
	mesh_inst = MeshInstance3D.new()
	mkey = Data.mesh_key(t, shp)
	mesh_inst.mesh = Data.mesh(mkey)
	mesh_inst.transform = Data.base_xform(mkey)
	mesh_inst.material_override = Data.material(ci)
	vis.add_child(mesh_inst)
	if collide:
		body = StaticBody3D.new()
		body.collision_layer = LAYER_PIECE
		body.collision_mask = 0
		body.set_meta("piece", self)
		add_child(body)
		shape_node = CollisionShape3D.new()
		body.add_child(shape_node)
	set_size(1.0)
	return self


## 조립용: 비율은 그대로, 전체 크기만
func set_size(k: float) -> void:
	size = clampf(k, Data.SIZE_MIN, Data.SIZE_MAX)
	set_pscale(shape * size)


## 필드 오브젝트는 clamp 없이 크게 쓸 수 있다
func set_pscale(s: Vector3, clamp := true) -> void:
	if clamp:
		s = Vector3(clampf(s.x, Data.SCALE_MIN, Data.SCALE_MAX), clampf(s.y, Data.SCALE_MIN, Data.SCALE_MAX), clampf(s.z, Data.SCALE_MIN, Data.SCALE_MAX))
	pscale = s
	vis.scale = s
	var was_big := big
	big = maxf(s.x, maxf(s.y, s.z)) > 3.2
	if big != was_big:
		mesh_inst.material_override = _mat()
	if shape_node:
		var pts := PackedVector3Array()
		for p in Data.collision_points(mkey):
			pts.append(p * s)
		var cs := ConvexPolygonShape3D.new()
		cs.points = pts
		shape_node.shape = cs


func _mat() -> StandardMaterial3D:
	return Data.plain_material(color_idx) if big else Data.material(color_idx)


func set_color(ci: int) -> void:
	color_idx = ci
	mesh_inst.material_override = _mat()


func set_rusty() -> void:
	mesh_inst.material_override = Data.rust_material()


func set_highlight(on: bool) -> void:
	if on:
		var m: StandardMaterial3D = _mat().duplicate()
		m.emission_enabled = true
		m.emission = Color(1, 0.85, 0.4)
		m.emission_energy_multiplier = 0.45
		mesh_inst.material_override = m
	else:
		mesh_inst.material_override = _mat()


func world_half_extents() -> Vector3:
	return Judge.half_extents(global_transform.basis, pscale, Data.base_size(type))


func to_dict() -> Dictionary:
	return {"t": type, "p": position, "r": quaternion, "s": pscale, "sh": shape, "k": size,
		"c": color_idx, "o": origin, "i": inv_index}


static func from_dict(d: Dictionary, collide := true) -> Piece:
	var p := Piece.new()
	p.setup(d["t"], d["c"], collide, d.get("sh", d["s"]))
	p.position = d["p"]
	p.quaternion = d["r"]
	p.size = d.get("k", 1.0)
	p.set_pscale(d["s"])
	p.origin = d.get("o", "ground")
	p.inv_index = d.get("i", -1)
	return p


static func from_item(it: Dictionary, collide := true) -> Piece:
	var p := Piece.new()
	p.setup(it["type"], it.get("color", 0), collide, it.get("shape", Vector3.ONE))
	p.origin = it.get("origin", "ground")
	return p
