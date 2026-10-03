class_name Piece
extends Node3D
## 조립 작품의 덩어리 하나.
## 구조: Piece(위치·회전) → Vis(로컬 비균등 배율) → Mesh(기본 변환)
##       Piece → Body(배율 없음. 충돌 점을 직접 배율에 맞춰 굽는다)
## 물리 바디에 비균등 배율을 걸지 않기 위해서다.

const LAYER_PIECE := 2

var type := "box"
var pscale := Vector3.ONE
var color_idx := 0
var origin := "ground"
var inv_index := -1

var vis: Node3D
var mesh_inst: MeshInstance3D
var body: StaticBody3D
var shape: CollisionShape3D


func setup(t: String, ci: int, collide := true) -> Piece:
	type = t
	color_idx = ci
	vis = Node3D.new()
	add_child(vis)
	mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = Data.mesh(t)
	mesh_inst.transform = Data.base_xform(t)
	mesh_inst.material_override = Data.material(ci)
	vis.add_child(mesh_inst)
	if collide:
		body = StaticBody3D.new()
		body.collision_layer = LAYER_PIECE
		body.collision_mask = 0
		body.set_meta("piece", self)
		add_child(body)
		shape = CollisionShape3D.new()
		body.add_child(shape)
	set_pscale(Vector3.ONE)
	return self


func set_pscale(s: Vector3) -> void:
	pscale = Vector3(
		clampf(s.x, Data.SCALE_MIN, Data.SCALE_MAX),
		clampf(s.y, Data.SCALE_MIN, Data.SCALE_MAX),
		clampf(s.z, Data.SCALE_MIN, Data.SCALE_MAX))
	vis.scale = pscale
	if shape:
		var pts := PackedVector3Array()
		for p in Data.collision_points(type):
			pts.append(p * pscale)
		var cs := ConvexPolygonShape3D.new()
		cs.points = pts
		shape.shape = cs


func set_color(ci: int) -> void:
	color_idx = ci
	mesh_inst.material_override = Data.material(ci)


func set_highlight(on: bool) -> void:
	if on:
		var m: StandardMaterial3D = Data.material(color_idx).duplicate()
		m.emission_enabled = true
		m.emission = Color(1, 0.85, 0.4)
		m.emission_energy_multiplier = 0.35
		mesh_inst.material_override = m
	else:
		mesh_inst.material_override = Data.material(color_idx)


## 월드 AABB의 반지름(축별 절반 크기). 현재 회전 반영.
func world_half_extents() -> Vector3:
	return Judge.half_extents(global_transform.basis, pscale, Data.base_size(type))


func to_dict() -> Dictionary:
	return {"t": type, "p": position, "r": quaternion, "s": pscale, "c": color_idx, "o": origin, "i": inv_index}


static func from_dict(d: Dictionary, collide := true) -> Piece:
	var p := Piece.new()
	p.setup(d["t"], d["c"], collide)
	p.position = d["p"]
	p.quaternion = d["r"]
	p.set_pscale(d["s"])
	p.origin = d.get("o", "ground")
	p.inv_index = d.get("i", -1)
	return p
