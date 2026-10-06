extends RefCounted
## 1라운드 공간: 학교 (실내 · 천장 · 바깥 없음). 가운데 복도 + 북쪽 교실 둘 · 교무실, 남쪽 음악실 · 도서관(다락) · 미술실,
## 맨 남쪽 체육관(무대 · 관람석 · 매트). 캐릭터는 작은 사람 — 의자를 밟고 책상 위로, 관람석을 타고 무대로.

const WALL := Color("#F3EBDD")
const WALL2 := Color("#E4EEF3")
const TRIM := Color("#8A6B4E")
const H := 3.0
const HG := 5.0     # 체육관 높이


static func build(h) -> Dictionary:
	h.lv(0)
	h.set_world_scale(2.0)   # v0.6.2: 캐릭터 대비 세상 2배 — 작은 사람이 큰 학교를 누빈다
	var rng: RandomNumberGenerator = Game.rng
	# 바닥
	h.floor_rect(Rect2(-20, -2, 40, 4), 0.0, 1, Color("#ECE7DC"), Color("#D2CABA"))           # 복도
	h.floor_rect(Rect2(-20, -12, 14, 10), 0.0, 0, Color("#C9A27A"), Color("#B88E64"))         # 1반
	h.floor_rect(Rect2(-6, -12, 14, 10), 0.0, 0, Color("#D2AE84"), Color("#BF9670"))          # 2반
	h.floor_rect(Rect2(8, -12, 12, 10), 0.0, 3, Color("#8FA3B8"), Color("#8FA3B8"))           # 교무실
	h.floor_rect(Rect2(-20, 2, 12, 10), 0.0, 3, Color("#9C6A8A"), Color("#9C6A8A"))           # 음악실
	h.floor_rect(Rect2(-8, 2, 16, 10), 0.0, 3, Color("#6F9468"), Color("#6F9468"))            # 도서관
	h.floor_rect(Rect2(8, 2, 12, 10), 0.0, 1, Color("#F2EFE8"), Color("#DCE6EE"))             # 미술실
	h.floor_rect(Rect2(-20, 12, 40, 12), 0.0, 0, Color("#D9B27A"), Color("#CDA36B"), 0.35)    # 체육관
	# 천장
	h.ceiling(Rect2(-20, -12, 40, 14), H, Color("#F7F4EE"))
	h.ceiling(Rect2(-20, 2, 12, 10), H, Color("#F7F4EE"))
	h.ceiling(Rect2(8, 2, 12, 10), H, Color("#F7F4EE"))
	h.ceiling(Rect2(-8, 2, 16, 10), 4.2, Color("#F7F4EE"))
	h.ceiling(Rect2(-20, 12, 40, 12), HG, Color("#EDEBE6"))
	# 바깥벽 (사방이 막혀 있다) + 창문
	h.wall(Vector2(-20, -12), Vector2(20, -12), 0.0, H, WALL, 0.25, [], [[3.0, 2.0], [11.0, 2.0], [17.0, 2.0], [25.0, 2.0], [34.0, 2.0]])
	h.wall(Vector2(-20, -12), Vector2(-20, 12), 0.0, H, WALL, 0.25, [], [[4.0, 2.0], [18.0, 2.0]])
	h.wall(Vector2(20, -12), Vector2(20, 12), 0.0, H, WALL, 0.25, [], [[4.0, 2.0], [18.0, 2.0]])
	h.wall(Vector2(-20, 12), Vector2(-20, 24), 0.0, HG, WALL, 0.25, [], [[6.0, 2.4]])
	h.wall(Vector2(20, 12), Vector2(20, 24), 0.0, HG, WALL, 0.25, [], [[6.0, 2.4]])
	h.wall(Vector2(-20, 24), Vector2(20, 24), 0.0, HG, WALL, 0.25, [], [[8.0, 3.0], [32.0, 3.0]])
	# 체육관 북쪽 벽 (음악실 · 도서관 · 미술실 뒤) — 도서관 · 미술실 쪽 문
	h.wall(Vector2(-20, 12), Vector2(-8, 12), 0.0, HG, WALL)
	h.wall(Vector2(-8, 12), Vector2(8, 12), 0.0, HG, WALL2, 0.2, [[8.0, 3.2]])
	h.wall(Vector2(8, 12), Vector2(20, 12), 0.0, HG, WALL, 0.2, [[6.0, 2.6]])
	# 복도 벽 + 교실 문
	h.wall(Vector2(-20, -2), Vector2(20, -2), 0.0, H, WALL2, 0.2, [[7.0, 2.6], [21.0, 2.6], [34.0, 2.6]])
	h.wall(Vector2(-20, 2), Vector2(-8, 2), 0.0, H, WALL2, 0.2, [[6.0, 2.6]])
	h.wall(Vector2(-8, 2), Vector2(8, 2), 0.0, 4.2, WALL2, 0.2, [[8.0, 3.2]])
	h.wall(Vector2(8, 2), Vector2(20, 2), 0.0, H, WALL2, 0.2, [[6.0, 2.6]])
	# 교실 사이 벽
	h.wall(Vector2(-6, -12), Vector2(-6, -2), 0.0, H, WALL)
	h.wall(Vector2(8, -12), Vector2(8, -2), 0.0, H, WALL)
	h.wall(Vector2(-8, 2), Vector2(-8, 12), 0.0, 4.2, WALL)
	h.wall(Vector2(8, 2), Vector2(8, 12), 0.0, 4.2, WALL)

	_classroom(h, -20.0, rng)
	_classroom(h, -6.0, rng)
	_teachers(h)
	_hall(h)
	_music(h)
	_library(h, rng)
	_art(h)
	_gym(h)

	return {
		"levels": [0.0, 1.0, 2.6],
		"bounds": Rect2(-21, -13, 42, 38),
		"spawns": [Vector3(-3, 0, 0), Vector3(-1, 0, 0.5), Vector3(1, 0, -0.5), Vector3(3, 0, 0), Vector3(-2, 0, -0.8), Vector3(2, 0, 0.8)],
		"cam_yaw": 0.0,
		"rooms": [
			[Rect2(-20, -2, 40, 4), "복도", 0, "#ECE7DC"],
			[Rect2(-20, -12, 14, 10), "1반", 0, "#E2C9A8"],
			[Rect2(-6, -12, 14, 10), "2반", 0, "#E8D2B4"],
			[Rect2(8, -12, 12, 10), "교무실", 0, "#C3CFDB"],
			[Rect2(-20, 2, 12, 10), "음악실", 0, "#D7BCCD"],
			[Rect2(-8, 2, 16, 10), "도서관", 0, "#BBD0B6"],
			[Rect2(-8, 7, 7, 5), "다락", 2, "#9EBB98"],
			[Rect2(8, 2, 12, 10), "미술실", 0, "#F2EFE8"],
			[Rect2(-20, 12, 40, 12), "체육관", 0, "#E6CFA8"],
			[Rect2(-20, 12, 6, 12), "무대", 1, "#C99A6A"],
		],
	}


## 체육관: 무대(높이 1, 계단) · 관람석 3단 · 농구대 · 매트(밀 수 있음) · 뜀틀(뚜껑) · 공 바구니
static func _gym(h) -> void:
	# 무대
	h.box(Vector3(-17.0, 0.5, 18.0), Vector3(6.0, 1.0, 11.6), Color("#8A5A3B"), 0.0, true, 0.02)
	h.lv(1)
	h.floor_rect(Rect2(-20, 12.2, 6, 11.6), 1.0, 0, Color("#B9895C"), Color("#A97B50"), 0.5, 0.05)
	for z in [12.6, 23.4]:
		h.box_rot(Vector3(-15.0, 2.9, z), Vector3(0.3, 3.8, 1.2), Color("#9E2B2B"), Vector3.ZERO)
	h.box_rot(Vector3(-14.2, 4.6, 18.0), Vector3(0.3, 0.6, 11.6), Color("#9E2B2B"), Vector3.ZERO)
	Props.crate(h, Vector3(-17.5, 1.0, 18.0), PI / 2, Vector3(0.9, 1.1, 0.7), 12, 12, "연설대")
	h.spot(Vector3(-19.0, 1.02, 13.5), "high")
	h.spot(Vector3(-19.0, 1.02, 22.5), "high")
	Props.cabinet(h, Vector3(-19.5, 1.0, 20.5), PI / 2, 12, 13, "무대 수납장")
	h.lv(0)
	h.stairs(Vector3(-12.2, 0, 15.0), Vector3(-13.95, 1.0, 15.0), 1.4, Color("#A97B50"))
	h.stairs(Vector3(-12.2, 0, 21.0), Vector3(-13.95, 1.0, 21.0), 1.4, Color("#A97B50"))
	# 관람석 (남쪽 벽, 3단 — 폴짝폴짝 오른다)
	for k in 3:
		var hgt := 0.4 * (k + 1)
		h.box(Vector3(4.0, hgt * 0.5, 23.6 - (2 - k) * 0.8 - 0.4), Vector3(18.0, hgt, 0.8), Color("#C9A27A").darkened(0.06 * k), 0.0, true, 0.03)
	h.spot(Vector3(-2.0, 0.82, 22.4), "open")
	h.spot(Vector3(9.0, 0.82, 22.4), "open")
	h.spot(Vector3(4.0, 1.22, 23.2), "high")
	# 농구대 (동쪽 벽)
	h.box(Vector3(19.4, 2.0, 18.0), Vector3(0.3, 4.0, 0.3), 14, 0.0, true, 0.03)
	h.box(Vector3(19.1, 3.4, 18.0), Vector3(0.08, 1.1, 1.8), 0, 0.0, false, 0.02)
	h.part("ring", 2, 3, Vector3(18.6, 3.1, 18.0), Vector3.ZERO, 0.9)
	# 매트 (밀 수 있음 — 밑에 쪽지가 있을지도)
	for p in [Vector3(-6.0, 0, 16.0), Vector3(-3.0, 0, 18.5), Vector3(8.0, 0, 15.5)]:
		h.pushable(p, Vector3(2.0, 0.22, 1.2), Color("#2F6FB5"), Game.rng.randf_range(-0.3, 0.3), 4.0)
	# 뜀틀 · 공 바구니 · 상자들 (밀 수 있음)
	Props.crate(h, Vector3(12.0, 0, 18.5), 0.0, Vector3(1.4, 1.0, 0.7), 3, 0, "뜀틀")
	h.cyl(Vector3(15.5, 0.4, 14.0), 0.5, 0.8, 14, true, 12, 0.6, 0.55)
	for k in 5:
		h.ball(Vector3(15.3 + (k % 3) * 0.25, 0.85 + (k / 3) * 0.2, 13.9 + (k % 2) * 0.2), 0.12, [3, 2, 0, 8, 6][k])
	for p in [Vector3(0.0, 0, 14.0), Vector3(2.0, 0, 13.6), Vector3(-10.0, 0, 22.0)]:
		h.pushable(p, Vector3(0.8, 0.7, 0.8), Color("#C9A27A"), Game.rng.randf_range(-0.4, 0.4), 2.0)
	for k in 6:
		h.part("cone", 0, 3, Vector3(-8.0 + k * 1.6, 0.18, 20.0), Vector3.ZERO, 0.6)
	h.spot(Vector3(19.0, 0.02, 13.0), "open")
	h.spot(Vector3(-11.0, 0.02, 12.6), "open")


## 교실 하나: x0 ~ x0+14, z -12 ~ -2. 칠판은 북쪽 벽, 책상 3×3은 칠판을 본다
static func _classroom(h, x0: float, rng: RandomNumberGenerator) -> void:
	var cx := x0 + 7.0
	# 칠판 + 분필받침 (높은 곳)
	h.obj(Vector3(cx, 0, -11.86))
	h.box(Vector3(cx, 1.6, -11.86), Vector3(5.5, 1.3, 0.06), Color("#2F5240"), 0.0, false, 0.02)
	h.box(Vector3(cx, 1.6, -11.89), Vector3(5.8, 1.5, 0.04), TRIM, 0.0, false, 0.01)
	h.box(Vector3(cx, 0.93, -11.78), Vector3(5.6, 0.05, 0.14), TRIM, 0.0, false, 0.0)
	h.spot(Vector3(cx + 1.8, 0.97, -11.78), "high")
	for k in 4:
		h.box(Vector3(cx - 2.0 + k * 0.5, 0.97, -11.78), Vector3(0.18, 0.04, 0.04), [0, 4, 1, 7][k], 0.0, false, 0.01)
	h.end_obj()
	# 교탁
	h.obj(Vector3(cx, 0, -10.0))
	Props.big_desk(h, Vector3(cx, 0, -10.0), PI, Color("#B88E64"), Color("#9C7552"), 13, "교탁 서랍")
	h.part("sphere", 0, 8, Vector3(cx + 0.6, 1.15, -10.0), Vector3.ZERO, 0.55)
	h.part("ring", 2, 14, Vector3(cx + 0.6, 1.15, -10.0), Vector3(90, 0, -20), 0.6)
	h.part("cylinder", 0, 12, Vector3(cx + 0.6, 0.92, -10.0), Vector3.ZERO, 0.4)
	h.end_obj()
	# 학생 책상 3×3
	for row in 3:
		for col in 3:
			var p := Vector3(cx - 3.6 + col * 3.6, 0, -8.6 + row * 2.0)   # 마지막 줄 의자가 문을 막지 않게
			Props.desk(h, p, 0.0, Color("#E6C9A0"), Color("#5E6B78"), [8, 6, 2][col], (row + col) % 2 == 0)
	# 사물 칸 (뒤쪽 벽) · 게시판 액자 · 시계 · 창문 · 화분
	Props.cubbies(h, Vector3(x0 + 3.2, 0, -2.45), PI, 6, 2, Color("#D9B98F"))   # 문(x0+7)을 막지 않게
	Props.frame(h, Vector3(x0 + 0.15, 1.7, -7.0), PI / 2, Vector2(1.6, 1.0), 12, [7, 5, 1][int(x0) % 3])
	h.cyl_rot(Vector3(cx + 4.5, 2.4, -11.88), 0.3, 0.06, Color("#FFFFFF"), Vector3(90, 0, 0))
	h.box(Vector3(cx + 4.5, 2.45, -11.84), Vector3(0.03, 0.22, 0.02), Color("#333333"), 0.0, false, 0.0)
	for wx in [-5.0, 5.2]:
		h.box(Vector3(cx + wx, 1.9, -11.88), Vector3(1.6, 1.2, 0.05), Color("#BFE0F0"), 0.0, false, 0.02)
	Props.plant(h, Vector3(x0 + 13.3, 0, -11.2))
	h.spot(Vector3(x0 + 0.6, 0.02, -2.6), "open")
	h.spot(Vector3(x0 + 13.4, 0.02, -4.0), "open")


static func _teachers(h) -> void:
	Props.big_desk(h, Vector3(11.0, 0, -9.0), 0.0, Color("#A88462"), Color("#8B6A4C"), 13, "교무실 서랍")
	Props.big_desk(h, Vector3(16.5, 0, -9.0), 0.0, Color("#A88462"), Color("#8B6A4C"), 13, "교무실 서랍")
	# 서류함 (서랍 셋)
	h.obj(Vector3(19.4, 0, -6.5))
	h.box(Vector3(19.4, 0.75, -6.5), Vector3(0.6, 1.5, 0.8), 14, -PI / 2, true, 0.03)
	for k in 3:
		h.container("drawer", Vector3(19.0, 0.3 + k * 0.45, -6.5), Vector3(0.7, 0.36, 0.5), -PI / 2, 14, Vector3(18.55, 0.52 + k * 0.45, -6.5), "서류함")
	h.end_obj()
	h.obj(Vector3(10.6, 0, -3.1))
	# 소파 · 탁자 · 정수기 · 책장
	h.box(Vector3(10.6, 0.25, -3.3), Vector3(2.6, 0.5, 0.9), 9, 0.0, true, 0.12)
	h.box(Vector3(10.6, 0.7, -2.85), Vector3(2.6, 0.6, 0.25), 9, 0.0, false, 0.1)
	h.spot(Vector3(10.0, 0.52, -3.3), "open")
	h.end_obj()
	Props.table(h, Vector3(11.0, 0, -5.2), 0.0, Vector2(1.6, 0.8), Color("#C9A27A"), Color("#6E5743"), 1)
	h.cyl(Vector3(9.2, 0.6, -11.2), 0.25, 1.2, 0, true, 12)
	h.cyl(Vector3(9.2, 1.45, -11.2), 0.18, 0.5, Color("#9FD3EA"), false, 12)
	Props.bookshelf(h, Vector3(15.5, 0, -11.65), 0.0, 2.4, Color("#8B6A4C"), 3)


## 복도: 양쪽 사물함 줄
static func _hall(h) -> void:
	var doors := [-13.0, 1.0, 14.0]
	var doors_s := [-14.0, 0.0, 14.0]
	var cols := [8, 7, 6, 2]
	var i := 0
	var x := -19.3
	while x < 19.4:
		var clear := true
		for d in doors:
			if absf(x - d) < 1.4:
				clear = false
		if clear:
			Props.locker(h, Vector3(x, 0, -1.72), 0.0, 14, cols[(i / 4) % cols.size()])
			i += 1
		x += 0.7
	# 남쪽 벽엔 게시판 · 소화기 · 의자
	Props.bench(h, Vector3(-4.0, 0, 1.55), PI, Color("#C9A27A"), Color("#5E6B78"))
	Props.bench(h, Vector3(5.0, 0, 1.55), PI, Color("#C9A27A"), Color("#5E6B78"))
	h.cyl(Vector3(-19.5, 0.35, 1.6), 0.13, 0.7, 2, true, 10)
	Props.frame(h, Vector3(9.0, 1.8, 1.86), PI, Vector2(1.4, 0.9), 12, 4, "게시판")
	h.spot(Vector3(-10.5, 0.02, 1.4), "open")
	h.spot(Vector3(17.5, 0.02, 1.4), "open")
	for d in doors_s:
		pass


static func _music(h) -> void:
	# 그랜드 피아노: 뚜껑이 열린다 (금봉투가 잘 숨는 곳)
	var pp := Vector3(-16.0, 0, 6.5)
	h.obj(pp)
	h.box(pp + Vector3(0, 0.85, 0), Vector3(1.6, 0.35, 2.0), 15, 0.0, true, 0.1, 0.25)
	for lp in [Vector3(-0.65, 0, -0.8), Vector3(0.65, 0, -0.8), Vector3(0, 0, 0.85)]:
		h.box(pp + lp + Vector3(0, 0.34, 0), Vector3(0.12, 0.68, 0.12), 15, 0.0, false, 0.03)
	h.box(pp + Vector3(0, 0.98, 1.05), Vector3(1.5, 0.08, 0.25), 0, 0.0, false, 0.01)
	for k in 6:
		h.box(pp + Vector3(-0.55 + k * 0.22, 1.03, 1.08), Vector3(0.08, 0.03, 0.12), 15, 0.0, false, 0.0)
	h.container("lid", pp + Vector3(0, 1.05, 0), Vector3(1.62, 0.05, 2.02), PI, 15, pp + Vector3(0, 1.04, -0.2), "피아노 뚜껑")
	# 의자 (뚜껑 의자)
	Props.crate(h, pp + Vector3(0, 0, 1.75), 0.0, Vector3(0.9, 0.45, 0.4), 15, 15, "피아노 의자")
	h.end_obj()
	# 드럼 · 실로폰 · 보면대 · 수납장
	for d in [[Vector3(-11.5, 0, 4.0), 0.4], [Vector3(-10.6, 0, 4.4), 0.3], [Vector3(-11.0, 0, 5.2), 0.5]]:
		var dp: Vector3 = d[0]
		var r: float = d[1]
		h.cyl(dp + Vector3(0, 0.3, 0), r, 0.4, 2, true, 16)
		h.cyl(dp + Vector3(0, 0.52, 0), r * 0.95, 0.03, 0, false, 16)
	h.obj(Vector3(-12.0, 0, 9.5))
	h.box(Vector3(-12.0, 0.55, 9.5), Vector3(1.6, 0.12, 0.6), 12, 0.2, true, 0.03)
	for k in 7:
		h.box(Vector3(-12.6 + k * 0.2, 0.64, 9.5 - k * 0.04), Vector3(0.14, 0.04, 0.5 - k * 0.03), [2, 3, 4, 5, 7, 8, 10][k], 0.2, false, 0.01)
	h.end_obj()
	for k in 3:
		var sp := Vector3(-15.5 + k * 1.5, 0, 9.8)
		h.box(sp + Vector3(0, 0.6, 0), Vector3(0.04, 1.2, 0.04), 15, 0.0, false, 0.0)
		h.box(sp + Vector3(0, 1.2, 0), Vector3(0.5, 0.35, 0.03), 15, -0.3, false, 0.01)
	Props.cabinet(h, Vector3(-19.4, 0, 9.0), PI / 2, 12, 13, "악기장")
	Props.cabinet(h, Vector3(-9.0, 0, 11.6), PI, 12, 13, "악기장")
	h.spot(Vector3(-13.5, 0.02, 3.0), "open")


## 도서관: 높은 벽 · 책장 · 열람 책상 · 2층 다락 (계단)
static func _library(h, rng: RandomNumberGenerator) -> void:
	for k in 3:
		Props.bookshelf(h, Vector3(-6.4 + k * 2.6, 0, 11.65), PI, 2.4, Color("#8B6A4C"), 4, true)
	Props.bookshelf(h, Vector3(7.65, 0, 6.0), -PI / 2, 2.6, Color("#8B6A4C"), 4, true)
	Props.bookshelf(h, Vector3(-7.65, 0, 4.2), PI / 2, 2.2, Color("#8B6A4C"), 3, false)
	Props.table(h, Vector3(3.0, 0, 5.0), 0.0, Vector2(2.2, 1.0), Color("#C9A27A"), Color("#6E5743"), 2)
	Props.table(h, Vector3(3.0, 0, 8.2), 0.0, Vector2(2.2, 1.0), Color("#C9A27A"), Color("#6E5743"), 2)
	Props.big_desk(h, Vector3(-4.5, 0, 3.2), 0.0, Color("#B88E64"), Color("#9C7552"), 13, "사서 서랍")
	Props.plant(h, Vector3(6.9, 0, 2.7))
	# 다락 (2층, 높이 2.6) — x -8 ~ -1, z 7 ~ 12
	h.lv(2)
	h.floor_rect(Rect2(-8, 7, 7, 5), 2.6, 0, Color("#B9895C"), Color("#A97B50"), 0.55, 0.22)
	h.lv(0)
	for px in [-1.2, -4.5]:
		h.box(Vector3(px, 1.3, 7.15), Vector3(0.18, 2.6, 0.18), Color("#8B6A4C"), 0.0, true, 0.03)
	h.stairs(Vector3(3.2, 0, 9.6), Vector3(-0.95, 2.6, 9.6), 1.2, Color("#B9895C"))
	h.lv(2)
	# 난간 (계단 입구만 비움)
	h.box_span(Vector3(-8.0, 3.65, 7.05), Vector3(-1.0, 3.65, 7.05), 0.08, 0.08, Color("#8B6A4C"), true, 1.1)
	for k in 13:
		h.box(Vector3(-7.8 + k * 0.55, 3.12, 7.05), Vector3(0.05, 1.05, 0.05), Color("#8B6A4C"), 0.0, false, 0.0)
	h.box_span(Vector3(-1.05, 3.65, 7.05), Vector3(-1.05, 3.65, 8.5), 0.08, 0.08, Color("#8B6A4C"), true, 1.1)
	h.box_span(Vector3(-1.05, 3.65, 10.4), Vector3(-1.05, 3.65, 12.0), 0.08, 0.08, Color("#8B6A4C"), true, 1.1)
	# 다락 위: 빈백 · 작은 책장 · 망원경 · 보물 자리
	h.part("potato", 0, 2, Vector3(-6.5, 2.95, 8.5), Vector3.ZERO, 1.6)
	h.part("potato", 0, 8, Vector3(-5.0, 2.95, 10.6), Vector3.ZERO, 1.5)
	Props.bookshelf(h, Vector3(-3.5, 2.6, 11.65), PI, 2.0, Color("#8B6A4C"), 2, true)
	h.obj(Vector3(-7.3, 0, 11.0))
	h.cyl_rot(Vector3(-7.2, 3.6, 11.0), 0.08, 1.0, 4, Vector3(0, 0, 50))
	h.box(Vector3(-7.4, 3.0, 11.0), Vector3(0.05, 0.8, 0.05), 15, 0.0, false, 0.0)
	h.end_obj()
	Props.chest(h, Vector3(-2.2, 2.6, 8.4), PI / 2, "다락 상자")
	h.spot(Vector3(-7.4, 2.62, 7.6), "high")
	h.spot(Vector3(-2.0, 2.62, 11.4), "high")
	h.lv(0)


static func _art(h) -> void:
	# 이젤 3개 (캔버스 = 액자처럼 들린다)
	for k in 3:
		var ep := Vector3(10.5 + k * 2.8, 0, 9.5)
		h.obj(ep)
		h.box(ep + Vector3(-0.35, 0.8, 0), Vector3(0.05, 1.6, 0.05), 12, 0.0, false, 0.0)
		h.box(ep + Vector3(0.35, 0.8, 0), Vector3(0.05, 1.6, 0.05), 12, 0.0, false, 0.0)
		h.box(ep + Vector3(0, 0.75, -0.3), Vector3(0.05, 1.5, 0.05), 12, -0.3, false, 0.0)
		h.solid_box(ep + Vector3(0, 0.8, 0), Vector3(0.8, 1.6, 0.4))
		Props.frame(h, ep + Vector3(0, 1.25, 0.05), 0.0, Vector2(0.8, 0.6), 0, [7, 1, 5][k], "캔버스")
		h.end_obj()
	h.obj(Vector3(14.0, 0, 5.2))
	Props.table(h, Vector3(14.0, 0, 5.2), 0.0, Vector2(3.0, 1.4), Color("#E8E2D6"), Color("#6E5743"), 3)
	for k in 4:
		h.cyl(Vector3(13.0 + k * 0.6, 0.9, 5.0), 0.1, 0.18, [2, 8, 4, 6][k], false, 10)
	h.end_obj()
	h.box(Vector3(19.5, 0.45, 4.5), Vector3(0.8, 0.9, 1.6), 0, -PI / 2, true, 0.05)
	h.box(Vector3(19.5, 0.92, 4.5), Vector3(0.6, 0.06, 1.2), Color("#9FB6C4"), -PI / 2, false, 0.03)
	Props.cabinet(h, Vector3(19.4, 0, 8.5), -PI / 2, 0, 7, "물감장")
	Props.cubbies(h, Vector3(9.0, 0, 2.45), 0.0, 4, 2, Color("#D9B98F"))
	Props.crate(h, Vector3(9.2, 0, 11.2), 0.0, Vector3(1.0, 0.9, 0.7), 13, 13, "가마")

