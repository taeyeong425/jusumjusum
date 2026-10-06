extends RefCounted
## 2라운드 공간: 미술관. 남쪽 입구 → 가운데 조각 홀(대리석, 북쪽 2층 발코니) · 서쪽 전시실 둘 · 동쪽 전시실 · 창고.
## 액자는 아래가 들리고(뒤에 쪽지), 조각 받침대엔 서랍, 진열장은 뚜껑이 열린다.

const WHITE := Color("#F4F1EA")
const RED := Color("#8C3A45")
const NAVY := Color("#2F4A62")
const GREEN := Color("#3E6B57")
const H := 3.6


static func build(h) -> Dictionary:
	h.lv(0)
	h.set_world_scale(2.0)   # v0.6.2: 캐릭터 대비 2배 — 작은 관람객
	const HH := 7.0          # 조각 홀 높이 (2층 발코니 위로 트인 천장)
	h.floor_rect(Rect2(-7, -13, 14, 26), 0.0, 2, Color("#EFEBE4"), Color("#D6CFC4"), 0.4)          # 조각 홀 (대리석)
	h.floor_rect(Rect2(-20, -13, 13, 13), 0.0, 0, Color("#8B5E3C"), Color("#7A5134"), 0.5)         # 전시실 A
	h.floor_rect(Rect2(-20, 0, 13, 13), 0.0, 0, Color("#9A6A44"), Color("#86593A"), 0.5)           # 전시실 B
	h.floor_rect(Rect2(7, -13, 13, 15), 0.0, 0, Color("#8B5E3C"), Color("#7A5134"), 0.5)           # 전시실 C
	h.floor_rect(Rect2(7, 2, 13, 11), 0.0, 1, Color("#B4B8BC"), Color("#A5A9AD"), 0.8)             # 창고
	h.ceiling(Rect2(-7, -13, 14, 26), HH, Color("#F4F1EA"))
	h.ceiling(Rect2(-20, -13, 13, 26), H, Color("#F4F1EA"))
	h.ceiling(Rect2(7, -13, 13, 26), H, Color("#F4F1EA"))
	# 바깥벽 — 사방이 막혔다 (입구 없음, 창문만)
	h.wall(Vector2(-20, -13), Vector2(-7, -13), 0.0, H, WHITE, 0.25)
	h.wall(Vector2(-7, -13), Vector2(7, -13), 0.0, HH, WHITE, 0.25, [], [[3.5, 2.4], [10.5, 2.4]])
	h.wall(Vector2(7, -13), Vector2(20, -13), 0.0, H, WHITE, 0.25)
	h.wall(Vector2(-20, 13), Vector2(-7, 13), 0.0, H, WHITE, 0.25, [], [[6.5, 2.4]])
	h.wall(Vector2(-7, 13), Vector2(7, 13), 0.0, HH, WHITE, 0.25, [], [[3.0, 2.0], [7.0, 2.0], [11.0, 2.0]])
	h.wall(Vector2(7, 13), Vector2(20, 13), 0.0, H, WHITE, 0.25)
	h.wall(Vector2(-20, -13), Vector2(-20, 13), 0.0, H, WHITE, 0.25)
	h.wall(Vector2(20, -13), Vector2(20, 13), 0.0, H, WHITE, 0.25, [], [[20.0, 2.0]])
	# 홀 ↔ 전시실 (넓은 문) — 홀 쪽 벽은 홀 높이까지
	h.wall(Vector2(-7, -13), Vector2(-7, 13), 0.0, HH, RED, 0.25, [[6.5, 3.2], [19.5, 3.2]])
	h.wall(Vector2(7, -13), Vector2(7, 13), 0.0, HH, NAVY, 0.25, [[6.5, 3.2], [21.0, 2.8]])
	h.wall(Vector2(-20, 0), Vector2(-7, 0), 0.0, H, WHITE, 0.25, [[3.0, 2.8]])
	h.wall(Vector2(7, 2), Vector2(20, 2), 0.0, H, GREEN, 0.25, [[10.0, 2.8]])
	# 밀 수 있는 포장 상자 (밑에 쪽지가 깔렸을지도)
	for p in [Vector3(-18.0, 0, -2.0), Vector3(-9.0, 0, 11.5), Vector3(18.5, 0, -1.0), Vector3(15.0, 0, 9.5), Vector3(11.0, 0, 7.5), Vector3(-3.5, 0, 11.6)]:
		h.pushable(p, Vector3(0.9, 0.7, 0.9), Color("#C9A27A"), Game.rng.randf_range(-0.5, 0.5), 2.0)

	_hall(h)
	_gallery_a(h)
	_gallery_b(h)
	_gallery_c(h)
	_storage(h)

	return {
		"levels": [0.0, 2.62, 3.4],
		"bounds": Rect2(-21, -14, 42, 28),
		"spawns": [Vector3(-2, 0, 11.0), Vector3(-1, 0, 11.8), Vector3(0, 0, 11.0), Vector3(1, 0, 11.8), Vector3(2, 0, 11.0), Vector3(0, 0, 9.5)],
		"cam_yaw": 0.0,
		"rooms": [
			[Rect2(-7, -13, 14, 26), "조각 홀", 0, "#EFEBE4"],
			[Rect2(-7, -13, 14, 4.5), "발코니", 2, "#D8D2C8"],
			[Rect2(-20, -13, 13, 13), "전시실 A", 0, "#D8B49A"],
			[Rect2(-20, 0, 13, 13), "전시실 B", 0, "#DCBDA2"],
			[Rect2(7, -13, 13, 15), "전시실 C", 0, "#C3CEDA"],
			[Rect2(7, 2, 13, 11), "창고", 0, "#C9CCCF"],
		],
	}


## 조각상 (덩어리로 지은 사람 · 추상 조형)
static func _statue(h, p: Vector3, kind: int) -> void:
	match kind:
		0:
			h.box(p + Vector3(0, 0.45, 0), Vector3(0.42, 0.55, 0.26), Color("#F2EEE6"), 0.0, false, 0.08)
			h.ball(p + Vector3(0, 0.92, 0), 0.17, Color("#F2EEE6"), Vector3(1, 1.15, 1))
			h.box(p + Vector3(0, 0.1, 0), Vector3(0.36, 0.2, 0.22), Color("#F2EEE6"), 0.0, false, 0.04)
		1:
			h.part("ring", 4, Color("#C9A24A"), p + Vector3(0, 0.45, 0), Vector3(0, 0, 0), 1.6)
			h.part("sphere", 0, Color("#C9A24A"), p + Vector3(0, 0.15, 0), Vector3.ZERO, 0.5)
		2:
			h.part("cone", 3, Color("#B85C4A"), p + Vector3(0, 0.3, 0), Vector3(0, 30, 0), 1.1)
			h.part("sphere", 3, Color("#3E6B9A"), p + Vector3(0, 0.75, 0), Vector3.ZERO, 0.6)
		3:
			for k in 4:
				h.part("box", 0, [Color("#E9C46A"), Color("#2A9D8F"), Color("#E76F51"), Color("#264653")][k], p + Vector3(0, 0.12 + k * 0.24, 0), Vector3(0, k * 22, 0), 0.9 - k * 0.14)


static func _hall(h) -> void:
	# 가운데 큰 조각 + 원형 받침
	h.cyl(Vector3(0, 0.25, 1.0), 1.4, 0.5, Color("#D6CFC4"), true, 24)
	h.part("sphere", 0, Color("#E8E2D8"), Vector3(0, 1.4, 1.0), Vector3.ZERO, 2.2)
	h.part("ring", 0, Color("#C9A24A"), Vector3(0, 1.4, 1.0), Vector3(90, 0, 30), 3.4)
	h.spot(Vector3(1.1, 0.52, 1.6), "open")
	# 받침대 + 조각 (홀 양쪽 줄)
	for k in 4:
		for side in [-1, 1]:
			var p := Vector3(side * 4.4, 0, -6.0 + k * 3.6)
			Props.pedestal(h, p, -side * PI / 2, 0, 1.0)
			_statue(h, p + Vector3(0, 1.06, 0), (k + (1 if side > 0 else 0)) % 4)
	# 관람 의자 · 화분 · 안내 데스크
	Props.bench(h, Vector3(0, 0, 6.5), 0.0, Color("#3F3A36"), Color("#3F3A36"))
	Props.bench(h, Vector3(0, 0, -4.2), PI, Color("#3F3A36"), Color("#3F3A36"))
	for pp in [Vector3(-6.3, 0, 12.2), Vector3(6.3, 0, 12.2)]:
		Props.plant(h, pp)
	Props.big_desk(h, Vector3(-4.2, 0, 10.5), PI / 2, Color("#E8E2D8"), Color("#8C3A45"), 0, "안내 데스크")
	# 계단 → 북쪽 발코니 (2층 3.4)
	h.stairs(Vector3(6.15, 0, -1.2), Vector3(6.15, 3.4, -8.4), 1.2, Color("#D6CFC4"))
	h.stairs(Vector3(-6.15, 0, -1.2), Vector3(-6.15, 3.4, -8.4), 1.2, Color("#D6CFC4"))
	h.lv(2)
	h.floor_rect(Rect2(-7, -13, 14, 4.5), 3.4, 2, Color("#E2DCD2"), Color("#CFC8BE"), 0.4, 0.3)
	for x in [-4.6, 0.0, 4.6]:
		h.lv(0)
		h.cyl(Vector3(x, 1.7, -8.55), 0.22, 3.4, Color("#E8E2D8"), true, 14)
		h.lv(2)
	# 발코니 난간 (계단 입구 두 곳은 비움)
	h.box_span(Vector3(-4.8, 4.5, -8.55), Vector3(4.8, 4.5, -8.55), 0.08, 0.1, Color("#C9A24A"), true, 1.2)
	for k in 17:
		h.box(Vector3(-4.6 + k * 0.575, 3.88, -8.55), Vector3(0.05, 0.9, 0.05), Color("#C9A24A"), 0.0, false, 0.0)
	# 발코니: 진열장(뚜껑) · 액자 · 작은 조각
	for x in [-4.0, 0.0, 4.0]:
		h.box(Vector3(x, 3.85, -11.5), Vector3(1.2, 0.9, 0.7), Color("#5A4636"), 0.0, true, 0.03)
		h.container("lid", Vector3(x, 4.33, -11.5), Vector3(1.2, 0.06, 0.7), 0.0, 11, Vector3(x, 4.36, -11.5), "진열장")
	Props.frame(h, Vector3(-2.0, 5.0, -12.82), 0.0, Vector2(1.6, 1.1), 4, 8, "큰 액자")
	Props.frame(h, Vector3(2.0, 5.0, -12.82), 0.0, Vector2(1.6, 1.1), 4, 2, "큰 액자")
	h.spot(Vector3(-6.4, 3.42, -12.4), "high")
	h.spot(Vector3(6.4, 3.42, -12.4), "high")
	h.spot(Vector3(0.0, 3.42, -10.0), "high")
	h.lv(0)


## 벽에 액자를 줄줄이 (frame 컨테이너)
static func _frames_on(h, a: Vector2, b: Vector2, yaw: float, n: int, cols: Array) -> void:
	for k in n:
		var t := (k + 0.5) / n
		var p := a.lerp(b, t)
		var w := 1.0 + (k % 3) * 0.3
		Props.frame(h, Vector3(p.x, 1.65 + (k % 2) * 0.15, p.y), yaw, Vector2(w, w * 0.75), [4, 12, 15][k % 3], cols[k % cols.size()])
		# 작품 이름표
		var fwd := Vector3(sin(yaw), 0, cos(yaw))
		var rt := Vector3(cos(yaw), 0, -sin(yaw))
		h.box(Vector3(p.x, 0.62, p.y) + rt * (w * 0.5 + 0.25) + fwd * 0.02, Vector3(0.22, 0.14, 0.015), Color("#F4F1EA"), yaw, false, 0.0)


static func _gallery_a(h) -> void:
	_frames_on(h, Vector2(-19.0, -12.86), Vector2(-8.0, -12.86), 0.0, 5, [8, 2, 6, 3, 10])
	_frames_on(h, Vector2(-19.86, -12.0), Vector2(-19.86, -1.5), PI / 2, 4, [7, 1, 5, 11])
	Props.bench(h, Vector3(-13.5, 0, -6.5), 0.0, Color("#3F3A36"), Color("#3F3A36"))
	Props.pedestal(h, Vector3(-10.5, 0, -3.0), PI, 0, 0.9)
	_statue(h, Vector3(-10.5, 0.96, -3.0), 2)
	# 줄 서기 기둥 + 끈
	h.obj(Vector3(-15.25, 0, -10.8))
	for k in 4:
		h.cyl(Vector3(-17.5 + k * 1.5, 0.45, -10.8), 0.06, 0.9, Color("#C9A24A"), true, 8)
	h.box(Vector3(-15.25, 0.82, -10.8), Vector3(4.5, 0.05, 0.05), 2, 0.0, false, 0.02)
	h.end_obj()
	h.spot(Vector3(-16.0, 0.02, -11.6), "open")


static func _gallery_b(h) -> void:
	_frames_on(h, Vector2(-19.86, 1.2), Vector2(-19.86, 12.0), PI / 2, 4, [8, 4, 6, 2])
	_frames_on(h, Vector2(-19.0, 12.86), Vector2(-8.0, 12.86), PI, 4, [3, 10, 7, 5])
	# 유리 진열장 둘 (뚜껑)
	for p in [Vector3(-15.0, 0, 6.5), Vector3(-11.0, 0, 6.5)]:
		h.box(p + Vector3(0, 0.45, 0), Vector3(1.4, 0.9, 0.8), Color("#5A4636"), 0.0, true, 0.03)
		h.container("lid", p + Vector3(0, 0.93, 0), Vector3(1.4, 0.06, 0.8), PI, 7, p + Vector3(0, 0.96, 0), "진열장")
	Props.bench(h, Vector3(-13.0, 0, 3.0), PI, Color("#3F3A36"), Color("#3F3A36"))
	Props.plant(h, Vector3(-19.2, 0, 0.8))


static func _gallery_c(h) -> void:
	_frames_on(h, Vector2(8.0, -12.86), Vector2(19.0, -12.86), 0.0, 5, [2, 6, 8, 4, 1])
	_frames_on(h, Vector2(19.86, -12.0), Vector2(19.86, 1.0), -PI / 2, 4, [10, 3, 7, 5])
	for k in 3:
		var p := Vector3(10.5 + k * 3.0, 0, -5.0)
		Props.pedestal(h, p, 0.0, 15, 0.8)
		_statue(h, p + Vector3(0, 0.86, 0), (k + 1) % 4)
	# 큰 조형: 아치
	h.part("ring", 4, Color("#E9C46A"), Vector3(13.5, 1.2, -1.0), Vector3.ZERO, 3.0)
	Props.bench(h, Vector3(13.5, 0, -8.5), PI, Color("#3F3A36"), Color("#3F3A36"))
	h.spot(Vector3(19.2, 0.02, -12.2), "open")


## 창고: 상자 · 선반 · 사다리 (선반 꼭대기에 금봉투)
static func _storage(h) -> void:
	for p in [Vector3(9.5, 0, 4.0), Vector3(11.0, 0, 4.2), Vector3(16.5, 0, 11.6), Vector3(9.2, 0, 11.4), Vector3(18.6, 0, 7.5)]:
		Props.crate(h, p, Game.rng.randf_range(-0.3, 0.3), Vector3(1.0, 0.75, 0.8), 12, 13, "포장 상자")
	Props.crate(h, Vector3(9.5, 0.75, 4.0), 0.4, Vector3(0.7, 0.55, 0.6), 13, 13, "작은 상자")
	Props.bookshelf(h, Vector3(13.5, 0, 12.6), PI, 3.0, Color("#7A7F85"), 4, true)
	# 높은 선반 + 사다리 (꼭대기 2.6)
	h.lay_box(Vector3(13.0, 1.3, 7.0), Vector3(3.0, 2.6, 0.9), Color("#7A7F85"), 0.0, true, 0.03)
	h.lv(1)
	h.floor_rect(Rect2(11.5, 6.55, 3.0, 0.9), 2.62, 1, Color("#8F949A"), Color("#8F949A"), 0.7, 0.05)
	h.lv(0)
	h.ladder(Vector3(13.0, 0, 7.75), 2.6, PI, Color("#C9A24A"))
	h.lv(1)
	h.spot(Vector3(12.0, 2.64, 7.0), "high")
	h.spot(Vector3(14.0, 2.64, 7.0), "high")
	h.lv(0)
	# 액자 더미 (기대 놓인 그림)
	for k in 3:
		h.box_rot(Vector3(18.8, 0.7, 4.0 + k * 0.25), Vector3(1.4, 1.2, 0.05), [4, 12, 15][k], Vector3(0, 90, 12))
	h.spot(Vector3(17.8, 0.02, 3.4), "open")
	h.toy_ball(Vector3(15.5, 0, 5.0), 0.14, 0, 0.3)
	h.toy_ball(Vector3(-13.0, 0, 9.0), 0.1, 4)


