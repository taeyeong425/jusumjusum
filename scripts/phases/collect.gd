extends Node3D
## 수집 (2:00) — 놀이터를 돌아다니며 덩어리를 줍고, 차·집·선풍기를 뜯는다.
## §7 + 해체 이식안: 맵 오브젝트를 [E]로 꾹 눌러 뜯으면 덩어리가 나온다.
## 편성에 없는 종류의 부품은 "녹슬어서" 안 빠진다 — 편성이 맵 위에서 실제로 보인다.

const SPEED := 4.6
const CARRY_MAX := 4
const HOLD_MAX := 12
const PICK_R := 1.4
const TEAR_R := 2.3
const BENCH_R := 3.4
const PEEK_R := 7.0
const HALF := 30.0

const TYPE_COLOR := {
	"sphere": 7, "hemi": 11, "cylinder": 8, "cone": 3, "capsule": 1, "ring": 4,
	"box": 13, "rod": 12, "plate": 5, "wedge": 10, "potato": 13, "pebble": 14,
}

var time_left := 120.0
var finished := false
var world: Node3D
var cam: Camera3D
var cam_yaw := 0.0
var actors: Array = []
var ground: Array = []
var tears: Array = []
var benches: Array = []
var pick_cd := 0.0
var hold_target: Dictionary = {}
var hold_prog := 0.0
var wanted := {}

var hud_time: Label
var hud_info: Label
var hud_prompt: Label
var hud_bar: ProgressBar
var hud_carry: HBoxContainer
var hud_inv: Label
var minimap: Control
var toast: Label
var toast_t := 0.0


func _ready() -> void:
	time_left = Game.t_collect()
	UI.make_env(self)
	world = Node3D.new()
	add_child(world)
	_build_ground()
	_build_benches()
	_build_objects()
	_claim_formation()
	_spawn_ground_pieces()
	_spawn_actors()
	cam = Camera3D.new()
	cam.fov = 55
	add_child(cam)
	for t in BotBuilder.wanted_types(Game.target):
		wanted[t] = 1
	for part in Game.target["parts"]:
		wanted[Data.GROUPS[part[0]][0]] = 3
	_build_hud()


# ── 맵 ───────────────────────────────────────────────

func _mi(parent: Node3D, m: Mesh, pos: Vector3, col: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = Data.flat_material(col)
	parent.add_child(mi)
	return mi


func _boxm(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new(); b.size = s; return b


func _cylm(r: float, h: float, top := -1.0) -> CylinderMesh:
	var c := CylinderMesh.new(); c.bottom_radius = r; c.top_radius = r if top < 0 else top; c.height = h; return c


func _sphm(r: float) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2; return s


func _solid(pos: Vector3, size: Vector3, yaw := 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.position = pos
	b.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position.y = size.y * 0.5
	b.add_child(cs)
	world.add_child(b)
	return b


func _tear(mi: MeshInstance3D, t: String, hold: float, nm: String) -> void:
	tears.append({"node": mi, "type": t, "hold": hold, "name": nm, "alive": true, "bolted": false, "dig": false, "uses": 1})


func _build_ground() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(HALF * 2 + 8, HALF * 2 + 8)
	_mi(world, pm, Vector3.ZERO, Color("#A9CF8E"))
	var sand := _mi(world, _cylm(7.0, 0.06), Vector3(0, 0.03, 0), Color("#EBD8A8"))
	sand.name = "Sand"
	# 울타리
	for i in 4:
		var horiz := i < 2
		var p := Vector3(0, 0, (HALF + 0.5) * (1 if i == 0 else -1)) if horiz else Vector3((HALF + 0.5) * (1 if i == 2 else -1), 0, 0)
		var s := Vector3(HALF * 2 + 2, 1.0, 0.4) if horiz else Vector3(0.4, 1.0, HALF * 2 + 2)
		_solid(p, s)
		_mi(world, _boxm(s), p + Vector3(0, 0.5, 0), Color("#E6D3B3"))
	var signs := [
		[Vector3(-15, 4.2, -18), "그네·시소 — 기본 선반"],
		[Vector3(15, 4.2, -18), "미끄럼틀 — 둥근 것들"],
		[Vector3(-16, 4.2, 6), "놀이집 — 구석 상자"],
		[Vector3(16, 4.2, 5), "주차장 · 우리 집"],
		[Vector3(0, 3.0, 0), "모래밭 — 파면 나와요"],
	]
	for s in signs:
		var l := UI.label3d(s[1], 72)
		l.position = s[0]
		world.add_child(l)
	# 모래밭 파는 곳
	var rng := Game.rng
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(2.5, 5.5)
		var mound := _mi(world, _sphm(0.55), p + Vector3(0, 0.05, 0), Color("#D9BE85"))
		mound.scale = Vector3(1.4, 0.45, 1.4)
		tears.append({"node": mound, "type": "", "hold": 1.6, "name": "모래 파기", "alive": true, "bolted": false, "dig": true, "uses": 3})


func _build_benches() -> void:
	var spots := [Vector3(0, 0, 24), Vector3(-24, 0, 14), Vector3(24, 0, 14), Vector3(-24, 0, -6), Vector3(24, 0, -6), Vector3(0, 0, -24)]
	for i in Game.PLAYERS:
		var p: Vector3 = spots[i]
		_solid(p, Vector3(2.4, 0.9, 1.4))
		_mi(world, _boxm(Vector3(2.4, 0.15, 1.4)), p + Vector3(0, 0.85, 0), Data.color(Game.players[i]["color"]))
		for lx in [-1.0, 1.0]:
			for lz in [-1.0, 1.0]:
				_mi(world, _boxm(Vector3(0.12, 0.8, 0.12)), p + Vector3(lx, 0.4, lz * 0.55), Color("#8A5A3B"))
		var l := UI.label3d("%s의 작업대" % Game.players[i]["name"], 56)
		l.position = p + Vector3(0, 2.0, 0)
		world.add_child(l)
		var pile := Node3D.new()
		pile.position = p + Vector3(0, 0.95, 0)
		world.add_child(pile)
		benches.append({"pos": p, "pile": pile})


func _car(pos: Vector3, yaw: float, col: Color) -> void:
	var root := _solid(pos, Vector3(2.4, 1.6, 1.3), yaw)
	_mi(root, _boxm(Vector3(2.4, 0.7, 1.2)), Vector3(0, 0.6, 0), col)
	_mi(root, _boxm(Vector3(1.3, 0.55, 1.1)), Vector3(-0.2, 1.22, 0), Color("#BFE3F2"))
	for wx in [-0.8, 0.8]:
		for wz in [-1, 1]:
			var w := _mi(root, _cylm(0.36, 0.22), Vector3(wx, 0.36, wz * 0.62), Color("#2B2B2B"), Vector3(90, 0, 0))
			_tear(w, "ring", 2.0, "바퀴")
	for dz in [-1, 1]:
		var d := _mi(root, _boxm(Vector3(0.8, 0.5, 0.06)), Vector3(-0.1, 0.7, dz * 0.62), col.darkened(0.15))
		_tear(d, "plate", 2.4, "문짝")
	for lz in [-0.35, 0.35]:
		var h := _mi(root, _sphm(0.13), Vector3(1.2, 0.68, lz), Color("#F4C84A"))
		h.scale = Vector3(0.6, 1, 1)
		_tear(h, "hemi", 1.4, "전조등")
	var ant := _mi(root, _boxm(Vector3(0.05, 0.7, 0.05)), Vector3(-0.6, 1.85, 0.3), Color("#555555"))
	_tear(ant, "rod", 1.0, "안테나")


func _fan(pos: Vector3) -> void:
	var root := _solid(pos, Vector3(0.9, 1.8, 0.9))
	var base := _mi(root, _sphm(0.4), Vector3(0, 0.08, 0), Color("#8ECAE6"))
	base.scale = Vector3(1, 0.4, 1)
	_tear(base, "hemi", 1.8, "선풍기 받침")
	var pole := _mi(root, _boxm(Vector3(0.1, 1.2, 0.1)), Vector3(0, 0.8, 0), Color("#DDDDDD"))
	_tear(pole, "rod", 1.4, "선풍기 기둥")
	var motor := _mi(root, _sphm(0.24), Vector3(0, 1.5, 0), Color("#8ECAE6"))
	_tear(motor, "sphere", 1.8, "선풍기 모터")
	for i in 3:
		var bl := _mi(root, PrismMesh.new(), Vector3(0, 1.5, 0.3), Color("#F2F2F2"), Vector3(0, 0, i * 120))
		(bl.mesh as PrismMesh).size = Vector3(0.35, 0.5, 0.05)
		bl.translate_object_local(Vector3(0, 0.3, 0))
		_tear(bl, "wedge", 1.3, "선풍기 날개")


func _build_objects() -> void:
	# 그네
	var sw := Vector3(-17, 0, -12)
	_solid(sw + Vector3(-2, 0, 0), Vector3(0.4, 3, 1.8))
	_solid(sw + Vector3(2, 0, 0), Vector3(0.4, 3, 1.8))
	var swr := Node3D.new(); swr.position = sw; world.add_child(swr)
	_mi(swr, _boxm(Vector3(4.4, 0.15, 0.15)), Vector3(0, 3, 0), Color("#E07A5F"))
	for x in [-2.0, 2.0]:
		for z in [-0.8, 0.8]:
			_mi(swr, _boxm(Vector3(0.12, 3.1, 0.12)), Vector3(x, 1.5, z), Color("#E07A5F"), Vector3(z * 12, 0, 0))
	for x in [-0.9, 0.9]:
		for cx in [-0.3, 0.3]:
			var ch := _mi(swr, _boxm(Vector3(0.05, 2.1, 0.05)), Vector3(x + cx, 1.9, 0), Color("#9A9A9A"))
			_tear(ch, "rod", 1.2, "그네 사슬")
		var seat := _mi(swr, _boxm(Vector3(0.8, 0.07, 0.4)), Vector3(x, 0.85, 0), Color("#F4C84A"))
		_tear(seat, "plate", 1.8, "그네 의자")
	# 시소
	var ss := Vector3(-12, 0, -18)
	_solid(ss, Vector3(0.6, 0.6, 0.6))
	var ssr := Node3D.new(); ssr.position = ss; world.add_child(ssr)
	_mi(ssr, _boxm(Vector3(0.5, 0.5, 0.5)), Vector3(0, 0.25, 0), Color("#8A5A3B"))
	var board := _mi(ssr, _boxm(Vector3(3.6, 0.1, 0.45)), Vector3(0, 0.55, 0), Color("#A8D46F"), Vector3(0, 0, 8))
	_tear(board, "plate", 2.6, "시소 판")
	for x in [-1.5, 1.5]:
		var hd := _mi(ssr, CapsuleMesh.new(), Vector3(x, 0.85 + x * 0.07, 0), Color("#D9483B"))
		(hd.mesh as CapsuleMesh).radius = 0.07
		(hd.mesh as CapsuleMesh).height = 0.45
		_tear(hd, "capsule", 1.2, "시소 손잡이")
	# 미끄럼틀
	var sl := Vector3(15, 0, -12)
	_solid(sl + Vector3(-1.2, 0, 0), Vector3(1.6, 2.6, 1.6))
	var slr := Node3D.new(); slr.position = sl; world.add_child(slr)
	_mi(slr, _boxm(Vector3(1.6, 0.2, 1.6)), Vector3(-1.2, 2.5, 0), Color("#8E6CC4"))
	for x in [-1.9, -0.5]:
		for z in [-0.7, 0.7]:
			_mi(slr, _boxm(Vector3(0.15, 2.5, 0.15)), Vector3(x, 1.25, z), Color("#CDB8E8"))
	var slide := _mi(slr, _boxm(Vector3(3.2, 0.08, 1.0)), Vector3(1.2, 1.25, 0), Color("#F08A3C"), Vector3(0, 0, -38))
	_tear(slide, "plate", 3.0, "미끄럼판")
	for z in [-0.75, 0.75]:
		var rail := _mi(slr, CapsuleMesh.new(), Vector3(-1.2, 3.1, z), Color("#F4C84A"))
		(rail.mesh as CapsuleMesh).radius = 0.06
		(rail.mesh as CapsuleMesh).height = 0.9
		_tear(rail, "capsule", 1.3, "난간 손잡이")
	var ball := _mi(slr, _sphm(0.3), Vector3(-1.2, 3.75, 0), Color("#D9483B"))
	_tear(ball, "sphere", 1.6, "꼭대기 공")
	for i in 2:
		var cone := _mi(slr, _cylm(0.35, 0.6, 0.0), Vector3(-2.6 + i * 0.4, 0.3, 1.4 - i * 2.8), Color("#F08A3C"))
		_tear(cone, "cone", 1.0, "고깔")
	# 놀이집
	var ph := Vector3(-17, 0, 9)
	_solid(ph, Vector3(2.8, 2.2, 2.8))
	var phr := Node3D.new(); phr.position = ph; world.add_child(phr)
	_mi(phr, _boxm(Vector3(2.8, 2.2, 2.8)), Vector3(0, 1.1, 0), Color("#F2A7B5"))
	for s in [-1, 1]:
		var roof := _mi(phr, PrismMesh.new(), Vector3(s * 0.75, 2.75, 0), Color("#D9483B"))
		(roof.mesh as PrismMesh).size = Vector3(1.6, 1.1, 3.0)
		(roof.mesh as PrismMesh).left_to_right = 1.0 if s < 0 else 0.0
		_tear(roof, "wedge", 2.4, "지붕 조각")
	var door := _mi(phr, _boxm(Vector3(0.9, 1.4, 0.06)), Vector3(0, 0.7, 1.43), Color("#8A5A3B"))
	_tear(door, "plate", 2.2, "놀이집 문")
	var chim := _mi(phr, _cylm(0.22, 0.8), Vector3(0.8, 3.3, 0.6), Color("#9A9A9A"))
	_tear(chim, "cylinder", 1.8, "굴뚝")
	# 집
	var hs := Vector3(19, 0, 12)
	_solid(hs, Vector3(4.2, 3.2, 4.2))
	var hsr := Node3D.new(); hsr.position = hs; world.add_child(hsr)
	_mi(hsr, _boxm(Vector3(4.2, 3.2, 4.2)), Vector3(0, 1.6, 0), Color("#F3E9D2"))
	var hr := _mi(hsr, PrismMesh.new(), Vector3(0, 4.0, 0), Color("#8A5A3B"))
	(hr.mesh as PrismMesh).size = Vector3(4.8, 1.6, 4.8)
	var hd2 := _mi(hsr, _boxm(Vector3(1.0, 1.9, 0.08)), Vector3(0, 0.95, -2.14), Color("#3E8E5B"))
	_tear(hd2, "plate", 3.0, "현관문")
	for x in [-1.3, 1.3]:
		var win := _mi(hsr, _boxm(Vector3(0.8, 0.8, 0.12)), Vector3(x, 2.0, -2.14), Color("#8ECAE6"))
		_tear(win, "box", 2.2, "창문")
	var clock := _mi(hsr, _cylm(0.3, 0.1), Vector3(0, 2.6, -2.16), Color("#FFFFFF"), Vector3(90, 0, 0))
	_tear(clock, "cylinder", 1.8, "벽시계")
	var orn := _mi(hsr, _cylm(0.25, 0.6, 0.0), Vector3(0, 5.05, 0), Color("#F4C84A"))
	_tear(orn, "cone", 2.0, "지붕 장식")
	var chm := _mi(hsr, _boxm(Vector3(0.5, 1.0, 0.5)), Vector3(1.3, 4.4, 0.8), Color("#9A9A9A"))
	_tear(chm, "box", 2.4, "굴뚝 벽돌")
	# 자동차 2대, 선풍기 2대
	_car(Vector3(12, 0, 4), 0.3, Color("#D9483B"))
	_car(Vector3(13, 0, 17), -0.2, Color("#2F6FB5"))
	_fan(Vector3(8.5, 0, 10))
	_fan(Vector3(22, 0, 3))


## 편성에 없는 몫의 부품은 녹슬어서 안 빠진다
func _claim_formation() -> void:
	var left: Dictionary = Game.counts.duplicate()
	var order := []
	for i in tears.size():
		if not tears[i]["dig"]:
			order.append(i)
	order.shuffle()
	for i in order:
		var tr: Dictionary = tears[i]
		if left.get(tr["type"], 0) > 0:
			left[tr["type"]] -= 1
		else:
			tr["bolted"] = true
			(tr["node"] as MeshInstance3D).material_override = Data.flat_material(Color("#6B5B4C"))
	Game.set_meta("ground_left", left)


func _spawn_ground_pieces() -> void:
	var left: Dictionary = Game.get_meta("ground_left")
	var zones := {
		"curve": Rect2(9, -18, 13, 9),
		"angle": Rect2(-23, -20, 14, 6),
		"irr": Rect2(-23, 1, 10, 4),
	}
	var rng := Game.rng
	for t in Data.TYPES:
		var n: int = left.get(t, 0)
		# 모래밭 파기가 불규칙 일부를 대신 낸다
		if Data.KIND[t] == "irr":
			n = maxi(0, n - 6)
		for k in n:
			var z: Rect2 = zones[Data.KIND[t]]
			var p := Vector3(rng.randf_range(z.position.x, z.end.x), 0, rng.randf_range(z.position.y, z.end.y))
			if t == "box" and k % 2 == 0:
				# 기본 선반 몫의 절반은 각 작업대 앞에 — 아무것도 못 만드는 사태 방지
				var bp: Vector3 = benches[k / 2 % benches.size()]["pos"]
				var inward := (-bp).normalized()
				var side := Vector3(-inward.z, 0, inward.x)
				p = bp + inward * rng.randf_range(3.5, 6.0) + side * rng.randf_range(-2.5, 2.5)
			_add_ground(t, p, "ground")


func _add_ground(t: String, p: Vector3, origin: String) -> void:
	var holder := Node3D.new()
	var pc := Piece.new().setup(t, TYPE_COLOR[t], false)
	pc.scale = Vector3.ONE * 1.5
	pc.rotation.y = Game.rng.randf() * TAU
	holder.add_child(pc)
	holder.position = Vector3(p.x, Data.base_size(t).y * 0.75 + 0.02, p.z)
	world.add_child(holder)
	ground.append({"node": holder, "type": t, "alive": true, "origin": origin})


# ── 캐릭터 ───────────────────────────────────────────

func _spawn_actors() -> void:
	for i in Game.PLAYERS:
		var p: Dictionary = Game.players[i]
		var body := CharacterBody3D.new()
		body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		body.collision_layer = 2
		body.collision_mask = 1
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.42
		cap.height = 1.5
		cs.shape = cap
		cs.position.y = 0.85
		body.add_child(cs)
		var vm := CapsuleMesh.new()
		vm.radius = 0.42
		vm.height = 1.5
		_mi(body, vm, Vector3(0, 0.85, 0), Data.color(p["color"]))
		for ex in [-0.16, 0.16]:
			_mi(body, _sphm(0.08), Vector3(ex, 1.25, -0.38), Color("#2B2B2B"))
		var name_l := UI.label3d(p["name"], 48)
		name_l.position = Vector3(0, 2.3, 0)
		body.add_child(name_l)
		var stack := Node3D.new()
		stack.position = Vector3(0, 1.95, 0)
		body.add_child(stack)
		var bpos: Vector3 = benches[i]["pos"]
		body.position = bpos + Vector3(0, 0, -2.6 if bpos.z > 0 else 2.6)
		world.add_child(body)
		actors.append({"i": i, "body": body, "carry": [], "stack": stack, "bot": p["is_bot"] or Game.autotest,
			"goal": {}, "prog": 0.0, "stuck_t": 0.0, "last_pos": body.position, "side_t": 0.0, "side": Vector3.ZERO})


func _cap_left(a: Dictionary) -> int:
	var inv: Array = Game.players[a["i"]]["inventory"]
	return mini(CARRY_MAX - a["carry"].size(), HOLD_MAX - inv.size() - a["carry"].size())


func _give(a: Dictionary, t: String, origin: String) -> void:
	a["carry"].append({"type": t, "origin": origin})
	_refresh_stack(a)
	if not a["bot"]:
		var src := "뜯었다" if origin == "tear" else ("팠다" if origin == "dig" else "주웠다")
		_toast("%s %s! (+%s)" % [Data.NAMES[t], src, Data.NAMES[t]])


func _refresh_stack(a: Dictionary) -> void:
	for c in a["stack"].get_children():
		c.queue_free()
	var y := 0.0
	for it in a["carry"]:
		var pc := Piece.new().setup(it["type"], TYPE_COLOR[it["type"]], false)
		pc.scale = Vector3.ONE * 0.7
		pc.position = Vector3(0, y, 0)
		a["stack"].add_child(pc)
		y += 0.38


func _deposit(a: Dictionary) -> void:
	if a["carry"].is_empty():
		return
	var inv: Array = Game.players[a["i"]]["inventory"]
	for it in a["carry"]:
		inv.append(it)
	a["carry"].clear()
	_refresh_stack(a)
	_refresh_pile(a["i"])
	if not a["bot"]:
		_toast("작업대에 보관! (%d/%d)" % [inv.size(), HOLD_MAX])


func _refresh_pile(i: int) -> void:
	var pile: Node3D = benches[i]["pile"]
	for c in pile.get_children():
		c.queue_free()
	var inv: Array = Game.players[i]["inventory"]
	for k in inv.size():
		var pc := Piece.new().setup(inv[k]["type"], TYPE_COLOR[inv[k]["type"]], false)
		pc.scale = Vector3.ONE * 0.55
		pc.position = Vector3(-0.9 + (k % 6) * 0.36, 0.15 + (k / 6) * 0.3, -0.2 + (k / 6) * 0.35)
		pile.add_child(pc)


func _yield_tear(tr: Dictionary) -> String:
	if tr["dig"]:
		var pool := ["potato", "pebble", "potato", "pebble", "sphere", "hemi"]
		return pool[Game.rng.randi() % pool.size()]
	return tr["type"]


func _finish_tear(a: Dictionary, tr: Dictionary) -> void:
	if not tr["alive"] or tr["bolted"]:
		return
	var t := _yield_tear(tr)
	tr["uses"] -= 1
	if tr["uses"] <= 0:
		tr["alive"] = false
		var n: Node3D = tr["node"]
		if tr["dig"]:
			n.scale = Vector3(1.4, 0.12, 1.4)
		else:
			n.visible = false
	_give(a, t, "dig" if tr["dig"] else "tear")


# ── 진행 ─────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if finished:
		return
	time_left -= delta
	pick_cd -= delta
	for a in actors:
		if a["bot"]:
			_bot_step(a, delta)
		else:
			_human_step(a, delta)
		_auto_pickup_and_deposit(a)
	_update_camera()
	_update_visibility()
	_update_hud(delta)
	if time_left <= 0:
		_end()


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
		body.rotation.y = atan2(-v.x, -v.z)
	body.velocity = v * SPEED
	body.move_and_slide()
	body.position.y = 0
	# 뜯기
	var near := _nearest_tear(body.position)
	hud_prompt.text = ""
	hud_bar.visible = false
	if near.is_empty():
		hold_prog = 0.0
		return
	if near["bolted"]:
		hud_prompt.text = "%s — 녹슬어서 안 빠진다 (이번 판엔 %s가 귀하다)" % [near["name"], Data.NAMES[near["type"]]]
		return
	if _cap_left(a) <= 0:
		hud_prompt.text = "손이 꽉 찼다 — 작업대에 갖다 두자"
		return
	var what: String = "랜덤 덩어리" if near["dig"] else Data.NAMES[near["type"]]
	hud_prompt.text = "[E] 꾹 — %s 뜯기 → %s" % [near["name"], what] if not near["dig"] else "[E] 꾹 — 모래 파기 → %s" % what
	if Input.is_physical_key_pressed(KEY_E):
		if hold_target != near:
			hold_target = near
			hold_prog = 0.0
		hold_prog += delta / near["hold"]
		hud_bar.visible = true
		hud_bar.value = hold_prog * 100
		if hold_prog >= 1.0:
			hold_prog = 0.0
			_finish_tear(a, near)
	else:
		hold_prog = 0.0


func _nearest_tear(p: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var bd := TEAR_R
	for tr in tears:
		if not tr["alive"]:
			continue
		var tp: Vector3 = (tr["node"] as Node3D).global_position
		var d := Vector2(tp.x - p.x, tp.z - p.z).length()
		if d < bd:
			bd = d
			best = tr
	return best


func _auto_pickup_and_deposit(a: Dictionary) -> void:
	var body: CharacterBody3D = a["body"]
	var bpos: Vector3 = benches[a["i"]]["pos"]
	if body.position.distance_to(bpos) < BENCH_R:
		_deposit(a)
	if not a["bot"] and pick_cd > 0:
		return
	if _cap_left(a) <= 0:
		return
	for g in ground:
		if not g["alive"]:
			continue
		var gp: Vector3 = g["node"].position
		if Vector2(gp.x - body.position.x, gp.z - body.position.z).length() < PICK_R:
			if a["bot"] and a["goal"].get("ref") != g:
				continue
			g["alive"] = false
			g["node"].queue_free()
			_give(a, g["type"], g["origin"])
			if not a["bot"]:
				pick_cd = 0.6
			return


func _drop_one() -> void:
	var a: Dictionary = actors[0]
	if a["carry"].is_empty():
		return
	var it: Dictionary = a["carry"].pop_back()
	_refresh_stack(a)
	var body: CharacterBody3D = a["body"]
	var fwd := -body.global_transform.basis.z
	_add_ground(it["type"], body.position - fwd * 1.8, it["origin"])
	pick_cd = 1.5
	_toast("%s 내려놓음 — 누군가 주워갈 수도" % Data.NAMES[it["type"]])


# ── 봇 ───────────────────────────────────────────────

func _bot_step(a: Dictionary, delta: float) -> void:
	var body: CharacterBody3D = a["body"]
	var goal: Dictionary = a["goal"]
	var inv: Array = Game.players[a["i"]]["inventory"]
	if goal.is_empty() or not _goal_valid(goal):
		a["prog"] = 0.0
		a["goal"] = _bot_choose(a)
		goal = a["goal"]
		if goal.is_empty():
			body.velocity = Vector3.ZERO
			return
	var gp := _goal_pos(goal, a)
	var to := Vector3(gp.x - body.position.x, 0, gp.z - body.position.z)
	var reach := 0.9 if goal["kind"] == "ground" else (TEAR_R * 0.8 if goal["kind"] == "tear" else BENCH_R * 0.7)
	if to.length() > reach:
		var v := to.normalized()
		if a["side_t"] > 0:
			a["side_t"] -= delta
			v = (v + a["side"]).normalized()
		body.velocity = v * SPEED
		body.rotation.y = atan2(-v.x, -v.z)
		body.move_and_slide()
		body.position.y = 0
		a["stuck_t"] += delta
		if a["stuck_t"] > 1.2:
			if body.position.distance_to(a["last_pos"]) < 0.5:
				a["side"] = Vector3(-v.z, 0, v.x) * (1 if Game.rng.randf() < 0.5 else -1) * 1.5
				a["side_t"] = 0.9
			a["stuck_t"] = 0.0
			a["last_pos"] = body.position
		return
	body.velocity = Vector3.ZERO
	match goal["kind"]:
		"tear":
			if _cap_left(a) <= 0:
				a["goal"] = {}
				return
			a["prog"] += delta / goal["ref"]["hold"]
			if a["prog"] >= 1.0:
				_finish_tear(a, goal["ref"])
				a["goal"] = {}
		"bench":
			_deposit(a)
			a["goal"] = {}
		"ground":
			pass  # _auto_pickup_and_deposit가 집는다
	if inv.size() >= HOLD_MAX:
		a["goal"] = {"kind": "idle"}


func _goal_valid(g: Dictionary) -> bool:
	match g["kind"]:
		"ground", "tear":
			return g["ref"]["alive"]
		"idle":
			return true
	return true


func _goal_pos(g: Dictionary, a: Dictionary) -> Vector3:
	match g["kind"]:
		"ground": return g["ref"]["node"].position
		"tear": return (g["ref"]["node"] as Node3D).global_position
		"bench", "idle": return benches[a["i"]]["pos"]
	return Vector3.ZERO


func _bot_choose(a: Dictionary) -> Dictionary:
	var inv: Array = Game.players[a["i"]]["inventory"]
	if inv.size() + a["carry"].size() >= HOLD_MAX:
		return {"kind": "bench"} if not a["carry"].is_empty() else {"kind": "idle"}
	if a["carry"].size() >= CARRY_MAX:
		return {"kind": "bench"}
	var body: CharacterBody3D = a["body"]
	var have := {}
	for it in inv + a["carry"]:
		have[it["type"]] = have.get(it["type"], 0) + 1
	var claimed := {}
	for o in actors:
		if o != a and not o["goal"].is_empty() and o["goal"].has("ref"):
			claimed[o["goal"]["ref"]] = true
	var best: Dictionary = {}
	var bs := INF
	for g in ground:
		if not g["alive"] or claimed.has(g):
			continue
		var d: float = body.position.distance_to(g["node"].position)
		var s := d - _desire(g["type"], have) * 4.0 + Game.rng.randf() * 2.0
		if s < bs:
			bs = s
			best = {"kind": "ground", "ref": g}
	for tr in tears:
		if not tr["alive"] or tr["bolted"] or claimed.has(tr):
			continue
		var d: float = body.position.distance_to((tr["node"] as Node3D).global_position)
		var t: String = "potato" if tr["dig"] else tr["type"]
		var s: float = d + tr["hold"] * SPEED * 0.8 - _desire(t, have) * 4.0 + Game.rng.randf() * 2.0
		if s < bs:
			bs = s
			best = {"kind": "tear", "ref": tr}
	if best.is_empty() and not a["carry"].is_empty():
		return {"kind": "bench"}
	return best


func _desire(t: String, have: Dictionary) -> float:
	var w: float = wanted.get(t, 0)
	return w / (1.0 + have.get(t, 0) * 0.8)


# ── 카메라 · 시야 ────────────────────────────────────

func _update_camera() -> void:
	var body: CharacterBody3D = actors[0]["body"]
	var off := Basis(Vector3.UP, cam_yaw) * Vector3(0, 10.5, 10.5)
	cam.position = body.position + off
	cam.look_at(body.position + Vector3(0, 1, 0))


## §7.5 정찰: 남이 뭘 들었는지는 가까이 가야 보인다
func _update_visibility() -> void:
	var me: Vector3 = actors[0]["body"].position
	for a in actors:
		if a["bot"] and a["i"] != 0:
			a["stack"].visible = a["body"].position.distance_to(me) < PEEK_R


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		cam_yaw -= event.relative.x * 0.008
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q:
		_drop_one()


# ── HUD ──────────────────────────────────────────────

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var tl := UI.panel()
	layer.add_child(UI.corner(tl, Control.PRESET_TOP_LEFT))
	var tv := UI.vbox(2)
	tl.add_child(tv)
	hud_time = UI.label("", 44, UI.INK, true)
	tv.add_child(hud_time)
	tv.add_child(UI.label("만들 것: 「%s」" % Game.target["name"], 26, UI.INK, true))
	tv.add_child(UI.label("할당량 ★%.1f 이상 %d명 · 재료 %s" % [Game.quota[0], Game.quota[1], Game.formation], 21, UI.SOFT))
	var card: Dictionary = Game.human()["card"]
	tv.add_child(UI.label("내 카드 「%s」 %s" % [card["name"], card["desc"]], 21, UI.ACCENT))

	minimap = Control.new()
	minimap.custom_minimum_size = Vector2(200, 200)
	minimap.size = Vector2(200, 200)
	minimap.draw.connect(_draw_minimap)
	var mp := UI.panel()
	mp.add_child(minimap)
	layer.add_child(mp)
	UI.corner(mp, Control.PRESET_TOP_RIGHT)

	var bottom := UI.panel()
	layer.add_child(bottom)
	UI.corner(bottom, Control.PRESET_CENTER_BOTTOM)
	var bv := UI.vbox(4)
	bottom.add_child(bv)
	var row := UI.hbox(10)
	bv.add_child(row)
	row.add_child(UI.label("손에 든 것", 22, UI.SOFT))
	hud_carry = UI.hbox(6)
	row.add_child(hud_carry)
	hud_inv = UI.label("", 21, UI.SOFT)
	bv.add_child(hud_inv)
	bv.add_child(UI.label("WASD 이동 · 우클릭 드래그 시점 · [E] 꾹 뜯기/파기 · [Q] 내려놓기 · 작업대에 가면 자동 보관", 18, UI.SOFT))
	var done := UI.button("수집 끝내기 →", _end, 20)
	bv.add_child(done)

	var cv := UI.vbox(6)
	cv.alignment = BoxContainer.ALIGNMENT_END
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_prompt = UI.label("", 26, UI.INK, true)
	hud_prompt.add_theme_color_override("font_outline_color", Color.WHITE)
	hud_prompt.add_theme_constant_override("outline_size", 8)
	hud_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(hud_prompt)
	hud_bar = ProgressBar.new()
	hud_bar.custom_minimum_size = Vector2(260, 22)
	hud_bar.show_percentage = false
	hud_bar.visible = false
	cv.add_child(hud_bar)
	toast = UI.label("", 24, UI.GOOD, true)
	toast.add_theme_color_override("font_outline_color", Color.WHITE)
	toast.add_theme_constant_override("outline_size", 8)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(toast)
	layer.add_child(cv)
	UI.corner(cv, Control.PRESET_CENTER_BOTTOM, Vector2(0, 168))


func _toast(s: String) -> void:
	toast.text = s
	toast_t = 1.8


func _update_hud(delta: float) -> void:
	hud_time.text = "수집 " + UI.clock(time_left)
	hud_time.add_theme_color_override("font_color", UI.BAD if time_left < 30 else UI.INK)
	toast_t -= delta
	if toast_t <= 0:
		toast.text = ""
	var a: Dictionary = actors[0]
	for c in hud_carry.get_children():
		c.queue_free()
	for k in CARRY_MAX:
		var l := UI.label(Data.NAMES[a["carry"][k]["type"]] if k < a["carry"].size() else "·", 22, UI.INK, true)
		l.custom_minimum_size.x = 70
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hud_carry.add_child(l)
	var inv: Array = Game.human()["inventory"]
	var names := []
	for it in inv:
		names.append(Data.NAMES[it["type"]])
	hud_inv.text = "작업대 %d/%d  %s" % [inv.size() + a["carry"].size(), HOLD_MAX, ", ".join(names)]
	minimap.queue_redraw()


func _draw_minimap() -> void:
	var sz := minimap.size
	var k := sz.x / (HALF * 2)
	var f := func(p: Vector3) -> Vector2: return Vector2((p.x + HALF) * k, (p.z + HALF) * k)
	minimap.draw_rect(Rect2(Vector2.ZERO, sz), Color("#A9CF8E"))
	minimap.draw_circle(f.call(Vector3.ZERO), 7 * k, Color("#EBD8A8"))
	for g in ground:
		if g["alive"]:
			minimap.draw_circle(f.call(g["node"].position), 1.6, Data.color(TYPE_COLOR[g["type"]]).darkened(0.2))
	for tr in tears:
		if tr["alive"] and not tr["bolted"]:
			minimap.draw_rect(Rect2(f.call((tr["node"] as Node3D).global_position) - Vector2(2, 2), Vector2(4, 4)), Color("#E07A5F"))
	for i in benches.size():
		minimap.draw_rect(Rect2(f.call(benches[i]["pos"]) - Vector2(5, 3), Vector2(10, 6)), Data.color(Game.players[i]["color"]))
	for a in actors:
		var c := Data.color(Game.players[a["i"]]["color"])
		var r := 6.0 if a["i"] == 0 else 4.0
		minimap.draw_circle(f.call(a["body"].position), r, c)
		if a["i"] == 0:
			minimap.draw_arc(f.call(a["body"].position), r + 2, 0, TAU, 16, UI.INK, 2.0)


func _end() -> void:
	if finished:
		return
	finished = true
	var rng := Game.rng
	var alive := []
	for g in ground:
		if g["alive"]:
			alive.append(g)
	alive.shuffle()
	for a in actors:
		var inv: Array = Game.players[a["i"]]["inventory"]
		for it in a["carry"]:
			inv.append(it)
		a["carry"].clear()
		# §7.5 미수집분 자동 채움: 맵 잔여분에서 랜덤
		while inv.size() < HOLD_MAX:
			if not alive.is_empty():
				var g: Dictionary = alive.pop_back()
				inv.append({"type": g["type"], "origin": "auto"})
			else:
				inv.append({"type": Data.TYPES[rng.randi() % Data.TYPES.size()], "origin": "auto"})
	Game.goto("build")
