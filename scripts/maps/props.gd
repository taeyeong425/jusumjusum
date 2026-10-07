class_name Props
extends RefCounted
## 공간들이 같이 쓰는 가구 · 소품. h = 보물찾기 장면(hunt.gd)의 짓기 도구.
## yaw: 가구의 앞(+z 로컬)이 향하는 방향. 0 = +z, PI = -z, PI/2 = +x, -PI/2 = -x
## 색은 팔레트 번호(int) 또는 Color.


static func _fwd(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))


static func _rt(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))


## 학생 책상 + 서랍 + 의자. 서랍은 앞(학생 쪽)으로 빠진다
static func desk(h, p: Vector3, yaw: float, top_c, leg_c, drawer_c: int, spot_on_top := false, chair := true) -> void:
	h.obj(p)
	var f := _fwd(yaw)
	var r := _rt(yaw)
	h.box(p + Vector3(0, 0.74, 0), Vector3(1.1, 0.06, 0.62), top_c, yaw, false, 0.02)
	for sx in [-0.5, 0.5]:
		for sz in [-0.25, 0.25]:
			h.box(p + r * sx + f * sz + Vector3(0, 0.36, 0), Vector3(0.05, 0.72, 0.05), leg_c, yaw, false, 0.0)
	h.box(p + Vector3(0, 0.62, -0.0) - f * 0.08, Vector3(0.9, 0.16, 0.42), leg_c, yaw, false, 0.02)
	h.solid_box(p + Vector3(0, 0.4, 0), Vector3(1.1, 0.8, 0.62), yaw)
	h.container("drawer", p + Vector3(0, 0.62, 0) + f * 0.02, Vector3(0.6, 0.12, 0.42), yaw, drawer_c,
		p + Vector3(0, 0.69, 0) + f * 0.48, "책상 서랍")
	if spot_on_top:
		h.spot(p + Vector3(0, 0.78, 0) + r * 0.25, "open")
	else:
		clutter(h, p + Vector3(0, 0.77, 0), Game.rng)
	if chair:
		var cp := p + f * 0.75
		h.box(cp + Vector3(0, 0.44, 0), Vector3(0.45, 0.05, 0.42), top_c, yaw, false, 0.02)
		h.box(cp + Vector3(0, 0.7, 0) + f * 0.2, Vector3(0.45, 0.45, 0.04), top_c, yaw, false, 0.02)
		for sx in [-0.19, 0.19]:
			for sz in [-0.17, 0.17]:
				h.box(cp + r * sx + f * sz + Vector3(0, 0.22, 0), Vector3(0.04, 0.44, 0.04), leg_c, yaw, false, 0.0)
		h.solid_box(cp + Vector3(0, 0.235, 0), Vector3(0.45, 0.47, 0.45), yaw)   # 앉는 면 높이까지만 — 밟고 책상에 오른다


## 큰 책상 (선생님 · 사서 · 선장) — 서랍 둘
	h.end_obj()


static func big_desk(h, p: Vector3, yaw: float, top_c, body_c, drawer_c: int, name := "책상 서랍") -> void:
	h.obj(p)
	var f := _fwd(yaw)
	var r := _rt(yaw)
	h.box(p + Vector3(0, 0.78, 0), Vector3(1.9, 0.07, 0.9), top_c, yaw, false, 0.03)
	h.box(p + Vector3(0, 0.38, 0) - f * 0.05, Vector3(1.85, 0.74, 0.78), body_c, yaw, true, 0.03)
	for sx in [-0.5, 0.5]:
		h.container("drawer", p + r * sx + Vector3(0, 0.6, 0) + f * 0.12, Vector3(0.7, 0.2, 0.5), yaw, drawer_c,
			p + r * sx + Vector3(0, 0.71, 0) + f * 0.62, name)


## 사물함 (속이 빈 상자 + 문). 문은 앞으로 열린다
	h.end_obj()


static func locker(h, p: Vector3, yaw: float, c: int, door_c: int) -> void:
	h.obj(p)
	var f := _fwd(yaw)
	var r := _rt(yaw)
	var w := 0.66
	var hh := 1.85
	var d := 0.5
	h.box(p - f * (d * 0.5 - 0.02) + Vector3(0, hh * 0.5, 0), Vector3(w, hh, 0.04), c, yaw, false, 0.0)
	for s in [-1, 1]:
		h.box(p + r * (w * 0.5 - 0.02) * s + Vector3(0, hh * 0.5, 0), Vector3(0.04, hh, d), c, yaw, false, 0.0)
	h.box(p + Vector3(0, hh - 0.02, 0), Vector3(w, 0.04, d), c, yaw, false, 0.0)
	h.box(p + Vector3(0, 0.05, 0), Vector3(w, 0.1, d), c, yaw, false, 0.0)
	h.box(p + Vector3(0, 1.1, 0), Vector3(w - 0.06, 0.03, d - 0.06), c, yaw, false, 0.0)
	h.solid_box(p + Vector3(0, hh * 0.5, 0) - f * 0.05, Vector3(w, hh, d - 0.1), yaw)
	var e: Dictionary = h.container("door", p + f * (d * 0.5) + Vector3(0, hh * 0.5, 0), Vector3(w - 0.04, hh - 0.08, 0.035), yaw, door_c,
		p + Vector3(0, 1.13, 0), "사물함")
	# 문 손잡이 · 환기구 (문과 같이 움직이게 판 자식으로)
	var pc: Piece = e["node"]
	# 손잡이 + 환기구 3줄을 한 메시로 (그리기 호출 절약)
	var W: float = h.W
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(h._plain_box(Vector3(0.03, 0.14, 0.03) * W), 0, Transform3D(Basis(), Vector3(w * 0.36, 0, 0.03) * W))
	for k in 3:
		st.append_from(h._plain_box(Vector3(0.36, 0.025, 0.01) * W), 0, Transform3D(Basis(), Vector3(0, 0.62 - k * 0.07, 0.02) * W))
	var deco := MeshInstance3D.new()
	deco.mesh = st.commit()
	deco.material_override = Data.brick(Color("#2B2F33"), false, 0.25, 0.5)
	pc.add_child(deco)


## 책장: 칸마다 책 줄 + 빈자리(보물 자리). top_high = 맨 위 칸은 "높은 곳"
	h.end_obj()


static func bookshelf(h, p: Vector3, yaw: float, w: float, c, levels := 4, top_high := true, rng: RandomNumberGenerator = null) -> void:
	h.obj(p)
	var f := _fwd(yaw)
	var r := _rt(yaw)
	var hh := 0.5 * levels + 0.1
	var d := 0.36
	h.box(p - f * (d * 0.5) + Vector3(0, hh * 0.5, 0), Vector3(w, hh, 0.03), c, yaw, false, 0.0)
	for s in [-1, 1]:
		h.box(p + r * (w * 0.5) * s + Vector3(0, hh * 0.5, 0), Vector3(0.05, hh, d), c, yaw, false, 0.0)
	h.solid_box(p + Vector3(0, hh * 0.5, 0), Vector3(w, hh, d), yaw)
	var book_cols := [2, 8, 6, 4, 10, 3, 9, 1, 12, 5]
	for lv in levels + 1:
		var y := 0.05 + lv * 0.5
		h.box(p + Vector3(0, y, 0), Vector3(w, 0.04, d), c, yaw, false, 0.0)
		if lv == levels:
			break
		# 책: 왼쪽부터 채우고 오른쪽에 빈자리를 남긴다
		var x := -w * 0.5 + 0.06
		var stop := w * 0.5 - (0.5 if lv % 2 == 0 else 0.25)
		var bi := lv * 3
		while x < stop:
			var bw: float = 0.06 + (bi % 3) * 0.02
			var bh: float = 0.3 + (bi % 4) * 0.03
			h.box(p + r * (x + bw * 0.5) + Vector3(0, y + 0.02 + bh * 0.5, 0), Vector3(bw, bh, d * 0.75), book_cols[bi % book_cols.size()], yaw, false, 0.008)
			x += bw + 0.01
			bi += 1
		var sp: Vector3 = p + r * (w * 0.5 - 0.22) + Vector3(0, y + 0.04, 0)
		h.spot(sp, "high" if top_high and lv == levels - 1 else "open")


## 열린 선반 (칸 = 보물 자리)
	h.end_obj()


static func cubbies(h, p: Vector3, yaw: float, cols: int, rows: int, c) -> void:
	h.obj(p)
	var f := _fwd(yaw)
	var r := _rt(yaw)
	var cw := 0.45
	var w := cw * cols
	var hh := 0.42 * rows
	h.box(p - f * 0.18 + Vector3(0, hh * 0.5, 0), Vector3(w, hh, 0.03), c, yaw, false, 0.0)
	for i in cols + 1:
		h.box(p + r * (-w * 0.5 + i * cw) + Vector3(0, hh * 0.5, 0), Vector3(0.03, hh, 0.38), c, yaw, false, 0.0)
	for j in rows + 1:
		h.box(p + Vector3(0, j * 0.42, 0), Vector3(w, 0.03, 0.38), c, yaw, false, 0.0)
	h.solid_box(p + Vector3(0, hh * 0.5, 0), Vector3(w, hh, 0.38), yaw)
	for i in cols:
		for j in rows:
			if (i + j) % 2 == 0:
				h.spot(p + r * (-w * 0.5 + (i + 0.5) * cw) + Vector3(0, j * 0.42 + 0.03, 0), "open")


## 나무 상자 (뚜껑이 뒤로 열린다)
	h.end_obj()


static func crate(h, p: Vector3, yaw: float, size: Vector3, c: int, lid_c: int, name := "나무 상자") -> void:
	h.obj(p)
	var f := _fwd(yaw)
	h.box(p + Vector3(0, size.y * 0.5 - 0.03, 0), size - Vector3(0, 0.06, 0), c, yaw, true, 0.03)
	# 판자 무늬 띠
	h.box(p + Vector3(0, size.y * 0.5, 0) + f * (size.z * 0.5 + 0.005), Vector3(size.x * 0.96, 0.05, 0.02), Data.color(c).darkened(0.25), yaw, false, 0.0)
	h.container("lid", p + Vector3(0, size.y - 0.02, 0), Vector3(size.x, 0.05, size.z), yaw, lid_c, p + Vector3(0, size.y + 0.03, 0), name)


## 술통 (뚜껑이 들린다)
	h.end_obj()


static func barrel(h, p: Vector3, c: int, name := "술통") -> void:
	h.obj(p)
	h.cyl(p + Vector3(0, 0.5, 0), 0.38, 1.0, c, true, 14, 0.6)
	h.cyl(p + Vector3(0, 0.5, 0), 0.42, 0.12, 14, false, 14)
	h.cyl(p + Vector3(0, 0.2, 0), 0.4, 0.08, 14, false, 14)
	h.cyl(p + Vector3(0, 0.8, 0), 0.4, 0.08, 14, false, 14)
	h.container("lid", p + Vector3(0, 1.02, 0), Vector3(0.62, 0.04, 0.62), Game.rng.randf() * TAU, c, p + Vector3(0, 1.06, 0), name)


## 보물상자 (반구 뚜껑 대신 상자 뚜껑 + 금속 띠)
	h.end_obj()


static func chest(h, p: Vector3, yaw: float, name := "보물상자") -> void:
	h.obj(p)
	var f := _fwd(yaw)
	var r := _rt(yaw)
	h.box(p + Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.55), 12, yaw, true, 0.04)
	for sx in [-0.3, 0.3]:
		h.box(p + r * sx + Vector3(0, 0.25, 0), Vector3(0.07, 0.52, 0.57), 4, yaw, false, 0.01)
	h.box(p + Vector3(0, 0.38, 0) + f * 0.28, Vector3(0.12, 0.14, 0.03), 4, yaw, false, 0.01)
	h.block(p + Vector3(0, 0.56, 0), Vector3(0.9, 0.12, 0.55), yaw)   # 뚜껑 자리 (뚜껑은 보물층이라 캐릭터가 통과했다)
	h.container("lid", p + Vector3(0, 0.56, 0), Vector3(0.92, 0.12, 0.57), yaw, 12, p + Vector3(0, 0.56, 0), name)


## 액자 (벽에 붙음, 아래가 앞으로 들린다 — 뒤에 쪽지). 그림 = 흰 여백 + 하늘 · 땅 · 산 · 해
static func frame(h, p: Vector3, yaw: float, size: Vector2, frame_c: int, art_c: int, name := "액자") -> void:
	p.y = minf(p.y, 1.05)   # 작은 캐릭터 손이 닿게
	var f := _fwd(yaw)
	var e: Dictionary = h.container("frame", p + f * 0.04, Vector3(size.x, size.y, 0.05), yaw, frame_c, p + f * 0.06 - Vector3(0, size.y * 0.3, 0), name)
	var pc: Piece = e["node"]
	var W: float = h.W
	var lay := func(pos: Vector2, sz: Vector2, col: Color, z: float) -> void:
		var mi := MeshInstance3D.new()
		mi.mesh = h._rbox_mesh(Vector3(sz.x * W, sz.y * W, 0.006 * W), 0.0)
		mi.material_override = Data.brick(col, false, 0.25, 0.8)
		mi.position = Vector3(pos.x * W, pos.y * W, z * W)
		pc.add_child(mi)
	var sky := Data.color(art_c).lerp(Color("#DDEFF8"), 0.5)
	var ground := Data.color(art_c).darkened(0.3)
	lay.call(Vector2.ZERO, size * 0.86, Color("#F4F1EA"), 0.028)
	lay.call(Vector2(0, size.y * 0.1), Vector2(size.x * 0.74, size.y * 0.5), sky, 0.032)
	lay.call(Vector2(0, -size.y * 0.22), Vector2(size.x * 0.74, size.y * 0.2), ground, 0.034)
	lay.call(Vector2(-size.x * 0.12, -size.y * 0.04), Vector2(size.x * 0.32, size.y * 0.22), Data.color(art_c).darkened(0.1), 0.036)
	lay.call(Vector2(size.x * 0.22, size.y * 0.22), Vector2(size.x * 0.1, size.x * 0.1), Color("#F2C94C"), 0.038)



## 받침대 + 서랍 (미술관 조각 받침)
	h.end_obj()


static func pedestal(h, p: Vector3, yaw: float, c: int, hgt := 1.0) -> void:
	h.obj(p)
	var f := _fwd(yaw)
	h.box(p + Vector3(0, hgt * 0.5, 0), Vector3(0.75, hgt, 0.75), c, yaw, true, 0.03)
	h.box(p + Vector3(0, hgt + 0.03, 0), Vector3(0.85, 0.06, 0.85), c, yaw, false, 0.02)
	h.container("drawer", p + Vector3(0, hgt * 0.35, 0) + f * 0.2, Vector3(0.5, 0.18, 0.4), yaw, c,
		p + Vector3(0, hgt * 0.35 + 0.1, 0) + f * 0.68, "받침대 서랍")


## 문 두 짝 수납장
	h.end_obj()


static func cabinet(h, p: Vector3, yaw: float, c: int, door_c: int, name := "수납장") -> void:
	h.obj(p)
	var f := _fwd(yaw)
	var r := _rt(yaw)
	h.box(p + Vector3(0, 0.55, 0) - f * 0.05, Vector3(1.2, 1.1, 0.45), c, yaw, true, 0.03)
	for sx in [-0.3, 0.3]:
		h.container("door", p + r * sx + Vector3(0, 0.55, 0) + f * 0.2, Vector3(0.56, 1.0, 0.035), yaw, door_c,
			p + r * sx + Vector3(0, 0.15, 0) + f * 0.55, name)
	h.spot(p + Vector3(0, 1.13, 0), "high")
	h.end_obj()


static func bench(h, p: Vector3, yaw: float, c, leg_c) -> void:
	h.obj(p)
	var r := _rt(yaw)
	h.box(p + Vector3(0, 0.45, 0), Vector3(1.6, 0.07, 0.45), c, yaw, false, 0.02)
	for sx in [-0.65, 0.65]:
		h.box(p + r * sx + Vector3(0, 0.22, 0), Vector3(0.07, 0.44, 0.4), leg_c, yaw, false, 0.0)
	h.solid_box(p + Vector3(0, 0.25, 0), Vector3(1.6, 0.5, 0.45), yaw)
	h.spot(p + Vector3(0, 0.02, 0) + r * 0.3, "open")
	h.end_obj()


static func table(h, p: Vector3, yaw: float, size: Vector2, top_c, leg_c, spots_n := 1) -> void:
	h.obj(p)
	var r := _rt(yaw)
	var f := _fwd(yaw)
	h.box(p + Vector3(0, 0.76, 0), Vector3(size.x, 0.07, size.y), top_c, yaw, false, 0.03)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			h.box(p + r * (size.x * 0.5 - 0.1) * sx + f * (size.y * 0.5 - 0.1) * sz + Vector3(0, 0.37, 0), Vector3(0.07, 0.74, 0.07), leg_c, yaw, false, 0.0)
	h.solid_box(p + Vector3(0, 0.4, 0), Vector3(size.x, 0.8, size.y), yaw)
	for k in spots_n:
		h.spot(p + Vector3(0, 0.8, 0) + r * (size.x * (k + 0.5) / spots_n - size.x * 0.5) * 0.8, "open")
	h.end_obj()


static func plant(h, p: Vector3) -> void:
	h.obj(p)
	h.cyl(p + Vector3(0, 0.22, 0), 0.22, 0.44, 3, true, 12, 0.5, 0.26)
	h.ball(p + Vector3(0, 0.75, 0), 0.38, 6, Vector3.ONE, true)
	h.ball(p + Vector3(0.18, 0.95, 0.1), 0.24, 5)
	h.spot(p + Vector3(0.35, 0.02, 0.3), "open")
	h.end_obj()


static func tree(h, p: Vector3) -> void:
	h.obj(p)
	h.cyl(p + Vector3(0, 1.0, 0), 0.22, 2.0, 12, true, 10)
	h.ball(p + Vector3(0, 2.6, 0), 1.2, 6)
	h.ball(p + Vector3(0.7, 2.2, 0.3), 0.8, 5)
	h.ball(p + Vector3(-0.6, 2.3, -0.4), 0.75, 6)
	h.spot(p + Vector3(0.5, 0.02, -0.4), "open")


## 매달린 등불 (실내 · 배 아래칸)
	h.end_obj()


static func lamp(h, p: Vector3, col := Color("#FFD9A0"), energy := 1.6, rng_ := 7.0) -> void:
	h.obj(p)
	h.cyl(p, 0.14, 0.22, 4, false, 8)
	var l := OmniLight3D.new()
	l.position = h.P(p) - Vector3(0, 0.4, 0)
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_ * h.W
	h.lvl_roots[h.lvl].add_child(l)
	h.end_obj()


## 책상 위 잔짐 (공책 · 연필 · 책 더미 · 컵) — 무작위로 조금씩
static func clutter(h, top: Vector3, rng: RandomNumberGenerator) -> void:
	var r := rng.randf()
	if r < 0.35:
		h.box_rot(top + Vector3(rng.randf_range(-0.3, 0.1), 0.012, rng.randf_range(-0.12, 0.12)), Vector3(0.24, 0.02, 0.32), [Color("#3E6B9A"), Color("#C94A4A"), Color("#5E9A5E")][rng.randi() % 3], Vector3(0, rng.randf_range(-30, 30), 0))
		h.box_rot(top + Vector3(rng.randf_range(0.1, 0.35), 0.012, rng.randf_range(-0.1, 0.1)), Vector3(0.18, 0.012, 0.012), Color("#E9C46A"), Vector3(0, rng.randf_range(0, 180), 0))
	elif r < 0.55:
		for k in rng.randi_range(2, 3):
			h.box_rot(top + Vector3(0.25, 0.03 + k * 0.045, 0.0), Vector3(0.26, 0.04, 0.34), [Color("#8E3B3B"), Color("#2F4A62"), Color("#6A7F3A"), Color("#B5763C")][k % 4], Vector3(0, rng.randf_range(-15, 15), 0))
	elif r < 0.7:
		h.cyl(top + Vector3(rng.randf_range(-0.3, 0.3), 0.06, 0.1), 0.045, 0.12, [Color("#F4F1EA"), Color("#E2553D"), Color("#3E6B9A")][rng.randi() % 3], false, 10, 0.3)


## 벽 포스터 (그림 · 시간표 · 지도) — 장식
static func poster(h, p: Vector3, yaw: float, size: Vector2, base, rng: RandomNumberGenerator) -> void:
	var f := _fwd(yaw)
	h.box(p + f * 0.012, Vector3(size.x, size.y, 0.01), base, yaw, false, 0.0)
	for k in 3:
		var off := Vector3(rng.randf_range(-0.3, 0.3) * size.x, rng.randf_range(-0.3, 0.3) * size.y, 0)
		h.box(p + f * 0.02 + Basis(Vector3.UP, yaw) * off, Vector3(size.x * rng.randf_range(0.15, 0.4), size.y * rng.randf_range(0.08, 0.25), 0.01), [Color("#E2553D"), Color("#3E6B9A"), Color("#E9C46A"), Color("#5E9A5E")][rng.randi() % 4], yaw, false, 0.0)
