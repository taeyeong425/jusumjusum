extends RefCounted
## 1라운드 공간: 학교. 가운데 복도 + 북쪽 교실 둘 · 교무실, 남쪽 음악실 · 도서관(2층 다락) · 미술실, 남쪽 운동장.
## 지붕이 없는 인형의 집 — 위에서 들여다보며 돌아다닌다.

const WALL := Color("#F3EBDD")
const WALL2 := Color("#E4EEF3")
const TRIM := Color("#8A6B4E")
const H := 3.0


static func build(h) -> Dictionary:
	h.lv(0)
	var rng: RandomNumberGenerator = Game.rng
	# 땅 (운동장 잔디 + 흙길)
	h.floor_rect(Rect2(-25, -17, 50, 40), -0.03, 3, Color("#8CC26E"), Color("#8CC26E"), 0.9)
	h.floor_rect(Rect2(-6, 12, 12, 10), -0.02, 3, Color("#D8C19A"), Color("#D8C19A"), 0.95)
	# 바닥
	h.floor_rect(Rect2(-20, -2, 40, 4), 0.0, 1, Color("#ECE7DC"), Color("#D2CABA"))           # 복도
	h.floor_rect(Rect2(-20, -12, 14, 10), 0.0, 0, Color("#C9A27A"), Color("#B88E64"))         # 1반
	h.floor_rect(Rect2(-6, -12, 14, 10), 0.0, 0, Color("#D2AE84"), Color("#BF9670"))          # 2반
	h.floor_rect(Rect2(8, -12, 12, 10), 0.0, 3, Color("#8FA3B8"), Color("#8FA3B8"))           # 교무실
	h.floor_rect(Rect2(-20, 2, 12, 10), 0.0, 3, Color("#9C6A8A"), Color("#9C6A8A"))           # 음악실
	h.floor_rect(Rect2(-8, 2, 16, 10), 0.0, 3, Color("#6F9468"), Color("#6F9468"))            # 도서관
	h.floor_rect(Rect2(8, 2, 12, 10), 0.0, 1, Color("#F2EFE8"), Color("#DCE6EE"))             # 미술실
	# 바깥벽 (복도 양 끝이 출입구)
	h.wall(Vector2(-20, -12), Vector2(20, -12), 0.0, H, WALL)
	h.wall(Vector2(-20, 12), Vector2(-8, 12), 0.0, H, WALL)
	h.wall(Vector2(-8, 12), Vector2(8, 12), 0.0, 4.2, WALL2, 0.2, [[8.0, 2.4]])               # 도서관 → 운동장 문
	h.wall(Vector2(8, 12), Vector2(20, 12), 0.0, H, WALL)
	h.wall(Vector2(-20, -12), Vector2(-20, 12), 0.0, H, WALL, 0.2, [[12.0, 3.0]])
	h.wall(Vector2(20, -12), Vector2(20, 12), 0.0, H, WALL, 0.2, [[12.0, 3.0]])
	# 복도 벽 + 교실 문
	h.wall(Vector2(-20, -2), Vector2(20, -2), 0.0, H, WALL2, 0.2, [[7.0, 1.8], [21.0, 1.8], [34.0, 1.8]])
	h.wall(Vector2(-20, 2), Vector2(-8, 2), 0.0, H, WALL2, 0.2, [[6.0, 1.8]])
	h.wall(Vector2(-8, 2), Vector2(8, 2), 0.0, 4.2, WALL2, 0.2, [[8.0, 2.4]])
	h.wall(Vector2(8, 2), Vector2(20, 2), 0.0, H, WALL2, 0.2, [[6.0, 1.8]])
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
	_yard(h)

	return {
		"levels": [0.0, 2.6, 6.0],
		"bounds": Rect2(-25, -17, 50, 40),
		"spawns": [Vector3(-3, 0, 0), Vector3(-1, 0, 0.5), Vector3(1, 0, -0.5), Vector3(3, 0, 0), Vector3(-2, 0, -0.8), Vector3(2, 0, 0.8)],
		"cam_yaw": 0.0,
		"rooms": [
			[Rect2(-20, -2, 40, 4), "복도", 0, "#ECE7DC"],
			[Rect2(-20, -12, 14, 10), "1반", 0, "#E2C9A8"],
			[Rect2(-6, -12, 14, 10), "2반", 0, "#E8D2B4"],
			[Rect2(8, -12, 12, 10), "교무실", 0, "#C3CFDB"],
			[Rect2(-20, 2, 12, 10), "음악실", 0, "#D7BCCD"],
			[Rect2(-8, 2, 16, 10), "도서관", 0, "#BBD0B6"],
			[Rect2(-8, 7, 7, 5), "다락", 1, "#9EBB98"],
			[Rect2(8, 2, 12, 10), "미술실", 0, "#F2EFE8"],
			[Rect2(-25, 12, 50, 10), "운동장", 0, "#CFE3C1"],
		],
	}


## 교실 하나: x0 ~ x0+14, z -12 ~ -2. 칠판은 북쪽 벽, 책상 3×3은 칠판을 본다
static func _classroom(h, x0: float, rng: RandomNumberGenerator) -> void:
	var cx := x0 + 7.0
	# 칠판 + 분필받침 (높은 곳)
	h.box(Vector3(cx, 1.6, -11.86), Vector3(5.5, 1.3, 0.06), Color("#2F5240"), 0.0, false, 0.02)
	h.box(Vector3(cx, 1.6, -11.89), Vector3(5.8, 1.5, 0.04), TRIM, 0.0, false, 0.01)
	h.box(Vector3(cx, 0.93, -11.78), Vector3(5.6, 0.05, 0.14), TRIM, 0.0, false, 0.0)
	h.spot(Vector3(cx + 1.8, 0.97, -11.78), "high")
	for k in 4:
		h.box(Vector3(cx - 2.0 + k * 0.5, 0.97, -11.78), Vector3(0.18, 0.04, 0.04), [0, 4, 1, 7][k], 0.0, false, 0.01)
	# 교탁
	Props.big_desk(h, Vector3(cx, 0, -10.0), PI, Color("#B88E64"), Color("#9C7552"), 13, "교탁 서랍")
	h.part("sphere", 0, 8, Vector3(cx + 0.6, 1.15, -10.0), Vector3.ZERO, 0.55)
	h.part("ring", 2, 14, Vector3(cx + 0.6, 1.15, -10.0), Vector3(90, 0, -20), 0.6)
	h.part("cylinder", 0, 12, Vector3(cx + 0.6, 0.92, -10.0), Vector3.ZERO, 0.4)
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
	h.box(Vector3(19.4, 0.75, -6.5), Vector3(0.6, 1.5, 0.8), 14, -PI / 2, true, 0.03)
	for k in 3:
		h.container("drawer", Vector3(19.0, 0.3 + k * 0.45, -6.5), Vector3(0.7, 0.36, 0.5), -PI / 2, 14, Vector3(18.55, 0.52 + k * 0.45, -6.5), "서류함")
	# 소파 · 탁자 · 정수기 · 책장
	h.box(Vector3(10.6, 0.25, -3.3), Vector3(2.6, 0.5, 0.9), 9, 0.0, true, 0.12)
	h.box(Vector3(10.6, 0.7, -2.85), Vector3(2.6, 0.6, 0.25), 9, 0.0, false, 0.1)
	h.spot(Vector3(10.0, 0.52, -3.3), "open")
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
	h.box(pp + Vector3(0, 0.85, 0), Vector3(1.6, 0.35, 2.0), 15, 0.0, true, 0.1, 0.25)
	for lp in [Vector3(-0.65, 0, -0.8), Vector3(0.65, 0, -0.8), Vector3(0, 0, 0.85)]:
		h.box(pp + lp + Vector3(0, 0.34, 0), Vector3(0.12, 0.68, 0.12), 15, 0.0, false, 0.03)
	h.box(pp + Vector3(0, 0.98, 1.05), Vector3(1.5, 0.08, 0.25), 0, 0.0, false, 0.01)
	for k in 6:
		h.box(pp + Vector3(-0.55 + k * 0.22, 1.03, 1.08), Vector3(0.08, 0.03, 0.12), 15, 0.0, false, 0.0)
	h.container("lid", pp + Vector3(0, 1.05, 0), Vector3(1.62, 0.05, 2.02), PI, 15, pp + Vector3(0, 1.04, -0.2), "피아노 뚜껑")
	# 의자 (뚜껑 의자)
	Props.crate(h, pp + Vector3(0, 0, 1.75), 0.0, Vector3(0.9, 0.45, 0.4), 15, 15, "피아노 의자")
	# 드럼 · 실로폰 · 보면대 · 수납장
	for d in [[Vector3(-11.5, 0, 4.0), 0.4], [Vector3(-10.6, 0, 4.4), 0.3], [Vector3(-11.0, 0, 5.2), 0.5]]:
		var dp: Vector3 = d[0]
		var r: float = d[1]
		h.cyl(dp + Vector3(0, 0.3, 0), r, 0.4, 2, true, 16)
		h.cyl(dp + Vector3(0, 0.52, 0), r * 0.95, 0.03, 0, false, 16)
	h.box(Vector3(-12.0, 0.55, 9.5), Vector3(1.6, 0.12, 0.6), 12, 0.2, true, 0.03)
	for k in 7:
		h.box(Vector3(-12.6 + k * 0.2, 0.64, 9.5 - k * 0.04), Vector3(0.14, 0.04, 0.5 - k * 0.03), [2, 3, 4, 5, 7, 8, 10][k], 0.2, false, 0.01)
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
	h.lv(1)
	h.floor_rect(Rect2(-8, 7, 7, 5), 2.6, 0, Color("#B9895C"), Color("#A97B50"), 0.55, 0.22)
	h.lv(0)
	for px in [-1.2, -4.5]:
		h.box(Vector3(px, 1.3, 7.15), Vector3(0.18, 2.6, 0.18), Color("#8B6A4C"), 0.0, true, 0.03)
	h.stairs(Vector3(3.2, 0, 9.6), Vector3(-0.95, 2.6, 9.6), 1.2, Color("#B9895C"))
	h.lv(1)
	# 난간 (계단 입구만 비움)
	h.box(Vector3(-4.5, 3.05, 7.05), Vector3(7.0, 0.08, 0.08), Color("#8B6A4C"), 0.0, false, 0.02)
	for k in 13:
		h.box(Vector3(-7.8 + k * 0.55, 2.82, 7.05), Vector3(0.05, 0.45, 0.05), Color("#8B6A4C"), 0.0, false, 0.0)
	h.solid_box(Vector3(-4.5, 3.1, 7.05), Vector3(7.0, 1.0, 0.1))
	h.box(Vector3(-1.05, 3.05, 7.8), Vector3(0.08, 0.08, 1.4), Color("#8B6A4C"), 0.0, false, 0.02)
	h.box(Vector3(-1.05, 3.05, 11.2), Vector3(0.08, 0.08, 1.6), Color("#8B6A4C"), 0.0, false, 0.02)
	h.solid_box(Vector3(-1.05, 3.1, 7.8), Vector3(0.1, 1.0, 1.4))
	h.solid_box(Vector3(-1.05, 3.1, 11.2), Vector3(0.1, 1.0, 1.6))
	# 다락 위: 빈백 · 작은 책장 · 망원경 · 보물 자리
	h.part("potato", 0, 2, Vector3(-6.5, 2.95, 8.5), Vector3.ZERO, 1.6)
	h.part("potato", 0, 8, Vector3(-5.0, 2.95, 10.6), Vector3.ZERO, 1.5)
	Props.bookshelf(h, Vector3(-3.5, 2.6, 11.65), PI, 2.0, Color("#8B6A4C"), 2, true)
	h.cyl_rot(Vector3(-7.2, 3.6, 11.0), 0.08, 1.0, 4, Vector3(0, 0, 50))
	h.box(Vector3(-7.4, 3.0, 11.0), Vector3(0.05, 0.8, 0.05), 15, 0.0, false, 0.0)
	Props.chest(h, Vector3(-2.2, 2.6, 8.4), PI / 2, "다락 상자")
	h.spot(Vector3(-7.4, 2.62, 7.6), "high")
	h.spot(Vector3(-2.0, 2.62, 11.4), "high")
	h.lv(0)


static func _art(h) -> void:
	# 이젤 3개 (캔버스 = 액자처럼 들린다)
	for k in 3:
		var ep := Vector3(10.5 + k * 2.8, 0, 9.5)
		h.box(ep + Vector3(-0.35, 0.8, 0), Vector3(0.05, 1.6, 0.05), 12, 0.0, false, 0.0)
		h.box(ep + Vector3(0.35, 0.8, 0), Vector3(0.05, 1.6, 0.05), 12, 0.0, false, 0.0)
		h.box(ep + Vector3(0, 0.75, -0.3), Vector3(0.05, 1.5, 0.05), 12, -0.3, false, 0.0)
		h.solid_box(ep + Vector3(0, 0.8, 0), Vector3(0.8, 1.6, 0.4))
		Props.frame(h, ep + Vector3(0, 1.25, 0.05), 0.0, Vector2(0.8, 0.6), 0, [7, 1, 5][k], "캔버스")
	Props.table(h, Vector3(14.0, 0, 5.2), 0.0, Vector2(3.0, 1.4), Color("#E8E2D6"), Color("#6E5743"), 3)
	for k in 4:
		h.cyl(Vector3(13.0 + k * 0.6, 0.9, 5.0), 0.1, 0.18, [2, 8, 4, 6][k], false, 10)
	h.box(Vector3(19.5, 0.45, 4.5), Vector3(0.8, 0.9, 1.6), 0, -PI / 2, true, 0.05)
	h.box(Vector3(19.5, 0.92, 4.5), Vector3(0.6, 0.06, 1.2), Color("#9FB6C4"), -PI / 2, false, 0.03)
	Props.cabinet(h, Vector3(19.4, 0, 8.5), -PI / 2, 0, 7, "물감장")
	Props.cubbies(h, Vector3(9.0, 0, 2.45), 0.0, 4, 2, Color("#D9B98F"))
	Props.crate(h, Vector3(9.2, 0, 11.2), 0.0, Vector3(1.0, 0.9, 0.7), 13, 13, "가마")


## 운동장: 나무 · 벤치 · 국기봉 · 모래놀이 · 창고 · 축구 골대
static func _yard(h) -> void:
	for tp in [Vector3(-20, 0, 16), Vector3(-14, 0, 19.5), Vector3(14, 0, 19), Vector3(21, 0, 15.5), Vector3(-22, 0, -14.5), Vector3(22, 0, -14.5)]:
		Props.tree(h, tp)
	Props.bench(h, Vector3(-10, 0, 14.5), 0.0, Color("#C97B4A"), Color("#5E6B78"))
	Props.bench(h, Vector3(10, 0, 14.5), 0.0, Color("#C97B4A"), Color("#5E6B78"))
	h.cyl(Vector3(0, 3.0, 20.5), 0.07, 6.0, 14, true, 8)
	h.box_rot(Vector3(0.6, 5.4, 20.5), Vector3(1.1, 0.7, 0.02), 2, Vector3.ZERO)
	h.spot(Vector3(0.4, 0.02, 20.9), "open")
	# 모래놀이터 (낮은 테) — 모래 위에 쪽지
	h.floor_rect(Rect2(-19, 17, 6, 4), 0.05, 3, Color("#E6CF9A"), Color("#E6CF9A"), 0.95)
	for e in [[Vector3(-16, 0.15, 17), Vector3(6, 0.3, 0.2)], [Vector3(-16, 0.15, 21), Vector3(6, 0.3, 0.2)], [Vector3(-19, 0.15, 19), Vector3(0.2, 0.3, 4)], [Vector3(-13, 0.15, 19), Vector3(0.2, 0.3, 4)]]:
		h.box(e[0], e[1], 3, 0.0, false, 0.03)
	h.spot(Vector3(-17.5, 0.07, 18.6), "open")
	h.spot(Vector3(-14.4, 0.07, 20.0), "open")
	h.part("cone", 0, 2, Vector3(-15.5, 0.25, 19.2), Vector3.ZERO, 0.6)
	h.part("cylinder", 0, 8, Vector3(-17.0, 0.2, 20.2), Vector3.ZERO, 0.6)
	# 창고 (문이 열린다)
	h.box(Vector3(19.0, 1.2, 20.0), Vector3(3.0, 2.4, 2.4), Color("#C97B4A"), 0.0, true, 0.04)
	h.box_rot(Vector3(19.0, 2.55, 20.0), Vector3(3.3, 0.12, 2.7), Color("#8A4B2E"), Vector3.ZERO)
	h.container("door", Vector3(19.0, 1.0, 18.78), Vector3(1.0, 1.9, 0.05), PI, 12, Vector3(19.0, 0.05, 18.4), "창고 문")
	# 축구 골대
	for gx in [-3.0, 3.0]:
		h.box(Vector3(gx, 1.0, -15.5), Vector3(0.1, 2.0, 0.1), 0, 0.0, true, 0.03)
	h.box(Vector3(0, 2.0, -15.5), Vector3(6.1, 0.1, 0.1), 0, 0.0, false, 0.03)
	h.spot(Vector3(1.0, 0.02, -15.8), "open")
	h.part("sphere", 0, 0, Vector3(-1.5, 0.25, -14.0), Vector3.ZERO, 0.8)
