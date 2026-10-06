extends RefCounted
## 3라운드 공간: 해적선. 바다 위 배 한 척 — 화물칸(0층) · 갑판(1층) · 선장실 지붕 뒷갑판(2층) · 돛대 망루(3층, 밧줄 사다리).
## 화물칸에 있으면 갑판이 사라져 위에서 들여다본다. 술통 · 나무 상자 · 보물상자를 열어라.

const PLANK := Color("#A0703F")
const PLANK2 := Color("#8E6136")
const HULL := Color("#6E4526")
const HULL_DARK := Color("#4A2E1A")
const TRIM := Color("#C9A24A")
const SAIL := Color("#F3EBD8")
const DECK_Y := 3.0
const QD_Y := 5.8
const NEST_Y := 9.0


static func build(h) -> Dictionary:
	h.lv(0)
	h.set_world_scale(1.6)   # v0.6.2: 캐릭터 대비 1.6배 — 거대한 배
	# 보트 창고 안의 물 (충돌 없음 — 빠지면 부두로)
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(56, 30) * h.W
	pm.subdivide_width = 50
	pm.subdivide_depth = 30
	sea.mesh = pm
	sea.position = Vector3(2.0, -0.6, 0) * h.W
	var wm := ShaderMaterial.new()
	wm.shader = load("res://assets/shaders/water.gdshader")
	sea.material_override = wm
	h.add_child(sea)
	_boathouse(h)
	# 선체 바깥 (물 아래 · 옆구리)
	h.lay_box(Vector3(-1.0, -0.9, 0), Vector3(34.4, 1.4, 11.2), HULL_DARK, 0.0, false, 0.3)
	h.lay_box(Vector3(16.5, -0.9, 0), Vector3(5.0, 1.4, 7.0), HULL_DARK, 0.0, false, 0.3)
	# 화물칸 바닥 · 벽. 옆구리 = 아래(화물칸) + 위(갑판 난간, 건널판 자리만 열림)
	h.floor_rect(Rect2(-16, -5.4, 30, 10.8), 0.0, 0, Color("#6E4A2A"), Color("#5E3F24"), 0.7)
	h.wall(Vector2(-17.2, -5.6), Vector2(15.0, -5.6), -0.3, DECK_Y + 0.3, HULL, 0.35)
	h.wall(Vector2(-17.2, 5.6), Vector2(15.0, 5.6), -0.3, DECK_Y + 0.3, HULL, 0.35)
	h.wall(Vector2(-17.2, -5.6), Vector2(15.0, -5.6), DECK_Y, 1.3, HULL, 0.35, [[11.2, 1.8]])
	h.wall(Vector2(-17.2, 5.6), Vector2(15.0, 5.6), DECK_Y, 1.3, HULL, 0.35, [[24.7, 1.8]])
	h.wall(Vector2(-17.2, -5.6), Vector2(-17.2, 5.6), -0.3, QD_Y + 1.0, HULL, 0.35)
	h.wall(Vector2(15.0, -5.6), Vector2(20.5, 0.0), -0.3, DECK_Y + 1.3, HULL, 0.35)
	h.wall(Vector2(15.0, 5.6), Vector2(20.5, 0.0), -0.3, DECK_Y + 1.3, HULL, 0.35)
	h.wall(Vector2(14.0, -5.4), Vector2(14.0, 5.4), 0.0, DECK_Y, HULL)
	# 건널판 (부두 → 갑판)
	h.stairs(Vector3(-6.0, 0, -9.8), Vector3(-6.0, DECK_Y, -5.3), 1.5, Color("#8E6136"))
	h.stairs(Vector3(7.5, 0, 9.8), Vector3(7.5, DECK_Y, 5.3), 1.5, Color("#8E6136"))
	# 선체 장식 띠 · 대포 구멍
	for side in [-1, 1]:
		h.box_span(Vector3(-17.2, DECK_Y + 1.25, side * 5.62), Vector3(15.0, DECK_Y + 1.25, side * 5.62), 0.12, 0.42, TRIM)
		h.box_span(Vector3(-17.2, 1.6, side * 5.8), Vector3(15.0, 1.6, side * 5.8), 0.2, 0.1, TRIM)
		for k in 6:
			h.box(Vector3(-11.0 + k * 4.0, 2.2, side * 5.8), Vector3(0.6, 0.5, 0.06), HULL_DARK, 0.0, false, 0.04)
	_hold(h)
	_deck(h)
	_cabin(h)
	_quarterdeck(h)
	_masts(h)

	return {
		"levels": [0.0, DECK_Y, QD_Y, NEST_Y],
		"bounds": Rect2(-27, -16, 58, 32),
		"spawns": [Vector3(0, 0, 11.5), Vector3(2, 0, 12.5), Vector3(4, 0, 11.5), Vector3(6, 0, 12.5), Vector3(-2, 0, 12.5), Vector3(8, 0, 11.5)],
		"cam_yaw": 0.0,
		"rooms": [
			[Rect2(-26, -15, 56, 7), "남쪽 부두", 0, "#C9A27A"],
			[Rect2(-26, 8, 56, 7), "북쪽 부두", 0, "#C9A27A"],
			[Rect2(-26, -8, 7, 16), "뒤 부두", 0, "#C9A27A"],
			[Rect2(-16, -5.4, 30, 10.8), "화물칸", 0, "#B98A5E"],
			[Rect2(-17.2, -5.6, 32.2, 11.2), "갑판", 1, "#D0A475"],
			[Rect2(-17.2, -5.6, 7.2, 11.2), "선장실 · 뒷갑판", 2, "#C8925C"],
			[Rect2(-3.2, -1.2, 2.4, 2.4), "망루", 3, "#E2C27A"],
		],
	}


## 보트 창고: 높은 나무 벽 · 천장 · 지붕 트러스 · 부두(나무) · 부두 소품
static func _boathouse(h) -> void:
	var WOOD := Color("#7A5A3E")
	const TOP := 16.0
	h.floor_rect(Rect2(-26, -15, 56, 7), 0.0, 0, Color("#9C7A55"), Color("#8A6A47"), 0.7)
	h.floor_rect(Rect2(-26, 8, 56, 7), 0.0, 0, Color("#9C7A55"), Color("#8A6A47"), 0.7)
	h.floor_rect(Rect2(-26, -8, 7, 16), 0.0, 0, Color("#9C7A55"), Color("#8A6A47"), 0.7)
	h.floor_rect(Rect2(24, -8, 6, 16), 0.0, 0, Color("#9C7A55"), Color("#8A6A47"), 0.7)
	# 부두 가장자리 말뚝 · 테두리
	for z in [-8.0, 8.0]:
		h.box_span(Vector3(-19.0, 0.1, z), Vector3(24.0, 0.1, z), 0.2, 0.3, Color("#5E4128"))
		for k in 9:
			h.cyl(Vector3(-18.0 + k * 5.0, -0.2, z), 0.22, 1.2, Color("#5E4128"), true, 10)
	h.ceiling(Rect2(-26, -15, 56, 30), TOP, Color("#6E5A46"))
	h.wall(Vector2(-26, -15), Vector2(30, -15), 0.0, TOP, WOOD, 0.4, [], [[8.0, 3.0], [20.0, 3.0], [32.0, 3.0], [44.0, 3.0]])
	h.wall(Vector2(-26, 15), Vector2(30, 15), 0.0, TOP, WOOD, 0.4, [], [[8.0, 3.0], [20.0, 3.0], [32.0, 3.0], [44.0, 3.0]])
	h.wall(Vector2(-26, -15), Vector2(-26, 15), 0.0, TOP, WOOD, 0.4, [], [[8.0, 3.0], [22.0, 3.0]])
	h.wall(Vector2(30, -15), Vector2(30, 15), 0.0, TOP, WOOD, 0.4, [], [[15.0, 6.0]])
	# 지붕 트러스
	for k in 10:
		var x := -24.0 + k * 6.0
		h.box_span(Vector3(x, TOP - 0.6, -15), Vector3(x, TOP - 0.6, 15), 0.5, 0.4, Color("#5E4128"))
		h.beam(Vector3(x, TOP - 0.8, -15), Vector3(x, TOP - 4.0, 0), 0.3, Color("#5E4128"))
		h.beam(Vector3(x, TOP - 0.8, 15), Vector3(x, TOP - 4.0, 0), 0.3, Color("#5E4128"))
	for lp in [Vector3(-14, 6.0, -11.5), Vector3(4, 6.0, -11.5), Vector3(20, 6.0, -11.5), Vector3(-14, 6.0, 11.5), Vector3(4, 6.0, 11.5), Vector3(20, 6.0, 11.5)]:
		Props.lamp(h, lp, Color("#FFD9A0"), 1.2, 9.0)
	# 부두 소품: 상자 더미(밟고 오르기) · 술통 · 그물 · 밧줄 · 작업대 · 사무실
	for p in [Vector3(-22.0, 0, 12.0), Vector3(-20.6, 0, 12.6), Vector3(14.0, 0, 13.4), Vector3(22.0, 0, -12.0), Vector3(-10.0, 0, -13.4)]:
		Props.crate(h, p, Game.rng.randf_range(-0.2, 0.2), Vector3(1.2, 1.0, 1.0), 12, 13, "부두 상자")
	Props.crate(h, Vector3(-22.0, 1.0, 12.0), 0.2, Vector3(1.0, 0.8, 0.9), 13, 13, "위 상자")
	for p in [Vector3(-16.0, 0, 9.4), Vector3(-15.2, 0, 9.6), Vector3(18.0, 0, -9.5), Vector3(26.0, 0, 5.0), Vector3(26.5, 0, -5.0), Vector3(-23.5, 0, -3.0)]:
		Props.barrel(h, p, 12, "부두 술통")
	for p in [Vector3(-6.0, 0, 13.6), Vector3(2.0, 0, -13.6), Vector3(27.0, 0, 0.0), Vector3(-24.0, 0, 4.0), Vector3(10.0, 0, -12.6)]:
		h.pushable(p, Vector3(1.0, 0.8, 1.0), Color("#B98A5E"), Game.rng.randf_range(-0.4, 0.4), 2.5)
	for p in [Vector3(0.0, 0.03, 10.5), Vector3(-12.0, 0.03, -10.5)]:
		h.box_rot(p, Vector3(3.0, 0.04, 2.0), Color("#7C8C6A"), Vector3(0, 20, 0))
		h.spot(p + Vector3(0.5, 0.05, 0.2), "open")
	for p in [Vector3(6.0, 0.1, 13.8), Vector3(-2.0, 0.1, -13.8)]:
		h.part("ring", 2, Color("#C9B48A"), p, Vector3.ZERO, 2.2)
		h.spot(p, "open")
	Props.table(h, Vector3(20.0, 0, 13.6), 0.0, Vector2(2.4, 1.0), Color("#8A6A47"), Color("#5E4128"), 2)
	# 부두 사무실 (작은 방: 책상 · 서류함)
	h.wall(Vector2(-20, -15), Vector2(-20, -10), 0.0, 3.0, Color("#D9C7A8"), 0.15, [[3.6, 1.6]])
	h.wall(Vector2(-26, -10), Vector2(-20, -10), 0.0, 3.0, Color("#D9C7A8"), 0.15)
	h.ceiling(Rect2(-26, -15, 6, 5), 3.0, Color("#EDE6D8"))
	Props.big_desk(h, Vector3(-23.0, 0, -12.8), 0.0, Color("#8A6A47"), Color("#5E4128"), 13, "사무실 서랍")
	Props.cabinet(h, Vector3(-25.5, 0, -11.0), PI / 2, 14, 14, "서류장")
	Props.lamp(h, Vector3(-23.0, 2.6, -12.5), Color("#FFE7B8"), 1.0, 4.0)



## 화물칸: 술통 · 상자 · 해먹 · 자루 · 대포알 · 등불
static func _hold(h) -> void:
	var rng: RandomNumberGenerator = Game.rng
	for p in [Vector3(-14.5, 0, -4.4), Vector3(-13.5, 0, -4.5), Vector3(-14.0, 0, -3.5), Vector3(10.5, 0, 4.4), Vector3(11.5, 0, 4.5), Vector3(12.6, 0, 4.4),
			Vector3(-6.0, 0, 4.5), Vector3(-5.0, 0, 4.4), Vector3(4.0, 0, -4.5), Vector3(12.8, 0, -4.4)]:
		Props.barrel(h, p, 12)
	for p in [Vector3(-10.0, 0, -4.4), Vector3(-8.6, 0, -4.4), Vector3(7.5, 0, -4.4), Vector3(-10.5, 0, 4.4), Vector3(8.5, 0, 4.4)]:
		Props.crate(h, p, rng.randf_range(-0.2, 0.2), Vector3(1.1, 0.9, 0.9), 12, 13, "나무 상자")
	Props.crate(h, Vector3(-9.3, 0.9, -4.4), 0.3, Vector3(0.8, 0.6, 0.7), 13, 13, "작은 상자")
	Props.chest(h, Vector3(-15.2, 0, 0.0), PI / 2, "숨겨진 보물상자")
	for p in [Vector3(-1.6, 0, -4.5), Vector3(0.4, 0, -4.5), Vector3(-12.5, 0, 4.5), Vector3(-7.5, 0, -4.5)]:
		Props.barrel(h, p, 13)
	# 해먹 (기둥 사이 천) — 위에 쪽지
	for k in 3:
		var hp := Vector3(-3.5 + k * 3.0, 0, -3.0)
		h.obj(hp)
		for dz in [-1.0, 1.0]:
			h.box(hp + Vector3(0, 0.9, dz * 0.0) + Vector3(dz * 1.1, 0, 0), Vector3(0.12, 1.8, 0.12), PLANK2, 0.0, true, 0.03)
		h.part("capsule", Vector3(1.0, 1.0, 1.0), Color("#E8DCC0"), hp + Vector3(0, 1.0, 0), Vector3(0, 0, 90), 2.3)
		h.spot(hp + Vector3(0.2, 1.17, 0), "open")
		h.end_obj()
	# 자루 · 대포알 더미
	h.obj(Vector3(2.5, 0, 4.5))
	for k in 4:
		h.part("potato", 0, Color("#C9B48A"), Vector3(1.5 + k * 0.7, 0.35, 4.5), Vector3(0, k * 40, 0), 1.5)
	h.spot(Vector3(2.6, 0.02, 3.6), "open")
	h.end_obj()
	h.obj(Vector3(-0.7, 0, 4.6))
	for k in 6:
		h.ball(Vector3(-1.0 + (k % 3) * 0.32, 0.16 + (k / 3) * 0.26, 4.6 - (k / 3) * 0.0), 0.16, Color("#2B2B2B"))
	h.end_obj()
	for lp in [Vector3(-12, 2.6, 0), Vector3(-4, 2.6, 2.5), Vector3(5, 2.6, -2.5), Vector3(11, 2.6, 1.5)]:
		Props.lamp(h, lp, Color("#FFC27A"), 1.4, 8.0)
	h.spot(Vector3(-15.6, 0.02, 4.6), "open")
	h.spot(Vector3(13.4, 0.02, 0.0), "open")
	# 계단 (화물칸 → 갑판, 해치 구멍으로)
	h.stairs(Vector3(5.6, 0, 0.0), Vector3(0.45, DECK_Y, 0.0), 1.3, PLANK2)


## 갑판: 해치 구멍 · 대포 · 술통 · 밧줄 · 상자
static func _deck(h) -> void:
	h.lv(1)
	for r in [Rect2(-17.0, -5.4, 17.45, 10.8), Rect2(5.65, -5.4, 9.35, 10.8), Rect2(0.45, -5.4, 5.2, 4.6), Rect2(0.45, 0.8, 5.2, 4.6)]:
		h.floor_rect(r, DECK_Y, 0, PLANK, PLANK2, 0.6, 0.3)
	# 뱃머리 갑판 + 기움돛대
	h.floor_rect(Rect2(15.0, -3.2, 2.8, 6.4), DECK_Y, 0, PLANK, PLANK2, 0.6, 0.3)
	h.cyl_rot(Vector3(20.5, DECK_Y + 1.6, 0), 0.16, 6.0, PLANK2, Vector3(0, 0, -70))
	# 해치 난간 (계단 입구 쪽 x=0.45 은 비움)
	for e in [[Vector3(0.6, DECK_Y + 1.05, -0.85), Vector3(5.65, DECK_Y + 1.05, -0.85)], [Vector3(0.6, DECK_Y + 1.05, 0.85), Vector3(5.65, DECK_Y + 1.05, 0.85)], [Vector3(5.65, DECK_Y + 1.05, -0.85), Vector3(5.65, DECK_Y + 1.05, 0.85)]]:
		h.box_span(e[0], e[1], 0.08, 0.08, TRIM, true, 1.1)
	for x in [0.6, 3.0, 5.6]:
		for z in [-0.85, 0.85]:
			h.box(Vector3(x, DECK_Y + 0.52, z), Vector3(0.08, 1.04, 0.08), TRIM, 0.0, false, 0.0)
	# 대포 (양옆)
	for side in [-1, 1]:
		for k in 4:
			var cp := Vector3(-3.5 + k * 4.5, DECK_Y, side * 4.6)
			h.obj(cp)
			h.box(cp + Vector3(0, 0.25, 0), Vector3(1.0, 0.5, 0.8), HULL, 0.0, true, 0.05)
			h.cyl_rot(cp + Vector3(0, 0.6, side * 0.25), 0.2, 1.4, Color("#2B2B2B"), Vector3(90, 0, 0))
			for wz in [-0.3, 0.3]:
				h.cyl_rot(cp + Vector3(-0.45, 0.15, wz), 0.15, 0.08, HULL_DARK, Vector3(0, 0, 90))
			if k % 2 == 0:
				h.spot(cp + Vector3(0.9, 0.02, -side * 0.3), "open")
			h.end_obj()
	# 술통 · 상자 · 밧줄 고리
	for p in [Vector3(12.5, DECK_Y, -4.3), Vector3(13.3, DECK_Y, -3.6), Vector3(-8.5, DECK_Y, 3.2), Vector3(7.0, DECK_Y, 4.0)]:
		Props.barrel(h, p, 12)
	Props.crate(h, Vector3(11.0, DECK_Y, 4.2), 0.2, Vector3(1.1, 0.9, 0.9), 12, 13, "갑판 상자")
	Props.crate(h, Vector3(-4.5, DECK_Y, -4.0), -0.2, Vector3(1.0, 0.8, 0.9), 12, 13, "갑판 상자")
	Props.crate(h, Vector3(13.8, DECK_Y, -2.3), 0.1, Vector3(1.0, 0.8, 0.9), 13, 13, "뱃머리 상자")
	Props.barrel(h, Vector3(13.9, DECK_Y, 2.3), 12, "뱃머리 술통")
	for p in [Vector3(9.0, DECK_Y + 0.1, -1.6), Vector3(-6.0, DECK_Y + 0.1, -1.0)]:
		h.part("ring", 2, Color("#C9B48A"), p, Vector3.ZERO, 2.2)
		h.part("ring", 2, Color("#C9B48A"), p + Vector3(0, 0.12, 0), Vector3.ZERO, 1.8)
		h.spot(p + Vector3(0, 0.0, 0), "open")
	# 갑판 → 뒷갑판 계단 (오른쪽 가장자리)
	h.stairs(Vector3(-5.6, DECK_Y, 4.55), Vector3(-9.95, QD_Y, 4.55), 1.0, PLANK2)
	h.lv(0)


## 선장실 (갑판 위 x -17 ~ -10): 큰 책상 · 보물상자 · 지도 탁자 · 책장 · 침대
static func _cabin(h) -> void:
	h.lv(1)
	var wc := Color("#7A4E2C")
	h.wall(Vector2(-10.0, -5.4), Vector2(-10.0, 5.4), DECK_Y, QD_Y - DECK_Y, wc, 0.25, [[5.4, 1.6]])
	h.floor_rect(Rect2(-17.0, -5.4, 7.0, 10.8), DECK_Y + 0.01, 3, Color("#7A2E3A"), Color("#7A2E3A"), 0.95, 0.05)
	Props.big_desk(h, Vector3(-15.6, DECK_Y, 0.0), PI / 2, Color("#5E3A1E"), Color("#4A2E1A"), 12, "선장 책상 서랍")
	h.box(Vector3(-15.6, DECK_Y + 0.83, 0.3), Vector3(0.6, 0.02, 0.45), Color("#E8D2A0"), 0.3, false, 0.0)
	Props.chest(h, Vector3(-11.2, DECK_Y, -4.6), 0.0, "선장의 보물상자")
	Props.table(h, Vector3(-12.8, DECK_Y, 2.8), 0.0, Vector2(1.4, 1.0), Color("#5E3A1E"), Color("#4A2E1A"), 1)
	h.box(Vector3(-12.8, DECK_Y + 0.81, 2.8), Vector3(1.1, 0.01, 0.75), Color("#E8D2A0"), 0.1, false, 0.0)
	Props.bookshelf(h, Vector3(-16.75, DECK_Y, -3.6), PI / 2, 1.8, Color("#4A2E1A"), 3, true)
	h.box(Vector3(-16.0, DECK_Y + 0.3, 4.4), Vector3(1.6, 0.6, 1.4), Color("#5E3A1E"), 0.0, true, 0.05)
	h.box(Vector3(-16.0, DECK_Y + 0.65, 4.4), Vector3(1.5, 0.12, 1.3), Color("#C94A4A"), 0.0, false, 0.06)
	h.spot(Vector3(-15.6, DECK_Y + 0.73, 4.0), "open")
	Props.cabinet(h, Vector3(-13.0, DECK_Y, -5.0), 0.0, 12, 13, "옷장")
	Props.lamp(h, Vector3(-13.5, QD_Y - 0.4, 0.0), Color("#FFC27A"), 1.6, 7.0)
	h.lv(0)


## 뒷갑판 (선장실 지붕): 키 · 작은 상자 · 깃발
static func _quarterdeck(h) -> void:
	h.lv(2)
	h.floor_rect(Rect2(-17.2, -5.6, 7.2, 11.2), QD_Y, 0, PLANK, PLANK2, 0.6, 0.3)
	# 난간 (계단 입구 z 4.05~5.05 비움)
	h.box_span(Vector3(-10.05, QD_Y + 1.0, -5.6), Vector3(-10.05, QD_Y + 1.0, 4.0), 0.08, 0.1, TRIM, true, 1.0)
	for side in [-1, 1]:
		h.box_span(Vector3(-17.2, QD_Y + 1.0, side * 5.55), Vector3(-10.0, QD_Y + 1.0, side * 5.55), 0.08, 0.1, TRIM, true, 1.0)
	# 키 (바퀴)
	h.obj(Vector3(-12.0, 0, 0))
	h.box(Vector3(-12.0, QD_Y + 0.55, 0), Vector3(0.3, 1.1, 0.3), PLANK2, 0.0, true, 0.03)
	h.part("ring", 0, PLANK2, Vector3(-11.8, QD_Y + 1.2, 0), Vector3(0, 0, 90), 2.0)
	for k in 4:
		h.box_rot(Vector3(-11.75, QD_Y + 1.2, 0), Vector3(0.05, 1.4, 0.06), TRIM, Vector3(k * 45.0, 0, 0))
	h.spot(Vector3(-12.6, QD_Y + 0.02, 0.8), "high")
	h.end_obj()
	Props.chest(h, Vector3(-16.2, QD_Y, -4.3), PI / 2, "뒷갑판 상자")
	Props.barrel(h, Vector3(-16.3, QD_Y, 4.5), 12, "물통")
	# 깃대 + 해적 깃발
	h.obj(Vector3(-16.6, 0, 0))
	h.cyl(Vector3(-16.6, QD_Y + 2.2, 0), 0.08, 4.4, PLANK2, false, 8)
	h.box_rot(Vector3(-15.8, QD_Y + 3.9, 0), Vector3(1.5, 1.0, 0.03), Color("#1B1B1B"), Vector3.ZERO)
	h.part("sphere", 0, Color("#F3EBD8"), Vector3(-15.8, QD_Y + 4.0, 0.03), Vector3.ZERO, 0.4)
	h.end_obj()
	h.lv(0)


## 돛대 둘 + 돛 + 망루 (밧줄 사다리)
static func _masts(h) -> void:
	h.lv(1)
	for mx in [-2.0, 9.0]:
		h.cyl(Vector3(mx, DECK_Y + 5.5, 0), 0.3, 11.0, PLANK2, true, 12)
		h.cyl_rot(Vector3(mx, DECK_Y + 3.0, 0), 0.12, 9.0, PLANK2, Vector3(90, 0, 0))
		h.cyl_rot(Vector3(mx, DECK_Y + 8.4, 0), 0.1, 7.0, PLANK2, Vector3(90, 0, 0))
		h.box_rot(Vector3(mx + 0.25, DECK_Y + 5.2, 0), Vector3(0.05, 4.4, 8.2), SAIL, Vector3(0, 0, 3))
		h.box_rot(Vector3(mx + 0.3, DECK_Y + 5.2, 0), Vector3(0.02, 0.5, 8.0), Color("#C94A4A"), Vector3(0, 0, 3))
		if mx > 0.0:
			h.box_rot(Vector3(mx + 0.2, DECK_Y + 9.3, 0), Vector3(0.05, 1.6, 6.2), SAIL, Vector3(0, 0, 3))
		# 밧줄 (돛대 꼭대기 → 뱃전)
		for side in [-1, 1]:
			var top := Vector3(mx, DECK_Y + 10.5, 0)
			var bot := Vector3(mx - 1.5, DECK_Y + 1.2, side * 5.5)
			h.beam(top, bot, 0.04, Color("#C9B48A"))
	# 망루 (큰 돛대, 높이 10)
	h.lv(3)
	h.floor_rect(Rect2(-3.2, -1.2, 2.4, 2.4), NEST_Y, 0, PLANK, PLANK2, 0.6, 0.2)
	for e in [[Vector3(-3.2, NEST_Y + 1.0, -1.2), Vector3(-0.8, NEST_Y + 1.0, -1.2)], [Vector3(-3.2, NEST_Y + 1.0, -1.2), Vector3(-3.2, NEST_Y + 1.0, 1.2)], [Vector3(-0.8, NEST_Y + 1.0, -1.2), Vector3(-0.8, NEST_Y + 1.0, 1.2)]]:
		h.box_span(e[0], e[1], 0.1, 0.1, PLANK2, true, 1.0)
	h.spot(Vector3(-2.8, NEST_Y + 0.02, -0.8), "high")
	h.spot(Vector3(-1.2, NEST_Y + 0.02, -0.7), "high")
	h.part("cylinder", 2, TRIM, Vector3(-1.3, NEST_Y + 0.4, 0.6), Vector3(0, 0, 70), 0.5)
	h.lv(1)
	# 밧줄 사다리: 갑판(z 1.6) → 망루 앞 가장자리, 앞 = -z
	h.ladder(Vector3(-2.0, DECK_Y, 1.65), NEST_Y, PI / 2 + PI / 2, Color("#C9B48A"))
	h.lv(0)
