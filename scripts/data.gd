class_name Data
extends RefCounted
## 정적 데이터: 덩어리 12종, 팔레트, 타겟 템플릿, 편성, 할당량, 카드.

const TYPES: Array[String] = [
	"sphere", "hemi", "cylinder", "cone", "capsule", "ring",
	"box", "rod", "plate", "wedge", "potato", "pebble",
]

const NAMES := {
	"sphere": "구", "hemi": "반구", "cylinder": "원기둥", "cone": "원뿔",
	"capsule": "캡슐", "ring": "링", "box": "육면체", "rod": "막대",
	"plate": "판", "wedge": "쐐기", "potato": "감자형", "pebble": "자갈형",
}

## 곡면 6 · 각면 4 · 불규칙 2
const KIND := {
	"sphere": "curve", "hemi": "curve", "cylinder": "curve", "cone": "curve",
	"capsule": "curve", "ring": "curve", "box": "angle", "rod": "angle",
	"plate": "angle", "wedge": "angle", "potato": "irr", "pebble": "irr",
}

## 템플릿 부위가 받아들이는 덩어리. 앞쪽일수록 자연스러운 선택.
const GROUPS := {
	"disk": ["ring", "cylinder", "sphere", "hemi"],
	"bar": ["rod", "cylinder", "capsule", "box"],
	"ball": ["sphere", "potato", "pebble", "hemi"],
	"block": ["box", "plate", "potato", "wedge"],
	"flat": ["plate", "box", "wedge"],
	"point": ["cone", "wedge", "capsule"],
	"dome": ["hemi", "sphere", "cone"],
}

const SCALE_MIN := 0.2
const SCALE_MAX := 6.0
const SIZE_MIN := 0.35
const SIZE_MAX := 3.0

## 덩어리 변형 — 같은 종류도 비율이 다른 버전이 처음부터 있다.
## 조립에서는 전체 크기와 회전만 바꾼다. 납작한 원기둥이 필요하면 "바퀴"를 뜯어 와야 한다.
## [이름, 비율(로컬 X·Y·Z)]
const VARIANTS := {
	"sphere": [["공", Vector3(1, 1, 1)], ["럭비공", Vector3(1.5, 0.8, 0.8)], ["접시", Vector3(1.4, 0.35, 1.4)], ["보석", Vector3(1.0, 1.15, 1.0), "sphere:gem"], ["알", Vector3(0.85, 1.2, 0.85)]],
	"hemi": [["반구", Vector3(1, 1, 1)], ["납작 반구", Vector3(1.3, 0.5, 1.3)], ["높은 반구", Vector3(0.8, 1.6, 0.8)], ["버섯 갓", Vector3(1.6, 0.8, 1.6), "hemi:cap"]],
	"cylinder": [["원기둥", Vector3(1, 1, 1)], ["바퀴", Vector3(1.5, 0.35, 1.5)], ["기둥", Vector3(0.55, 2.0, 0.55)], ["동전", Vector3(1.2, 0.12, 1.2)], ["육각기둥", Vector3(1.05, 1.0, 1.05), "cylinder:6"], ["삼각기둥", Vector3(1.1, 0.9, 1.1), "cylinder:3"], ["화분", Vector3(1.1, 0.85, 1.1), "cylinder:pot"]],
	"cone": [["원뿔", Vector3(1, 1, 1)], ["뾰족 원뿔", Vector3(0.6, 1.6, 0.6)], ["납작 원뿔", Vector3(1.4, 0.5, 1.4)], ["피라미드", Vector3(1.2, 1.0, 1.2), "cone:4"], ["오각뿔", Vector3(1.0, 1.3, 1.0), "cone:5"]],
	"capsule": [["캡슐", Vector3(1, 1, 1)], ["긴 캡슐", Vector3(0.8, 1.6, 0.8)], ["통통 캡슐", Vector3(1.6, 0.9, 1.6)], ["콩", Vector3(1.0, 1.0, 1.3), "capsule:bean"]],
	"ring": [["링", Vector3(1, 1, 1)], ["타이어", Vector3(1, 2.6, 1)], ["가는 링", Vector3(1.2, 0.6, 1.2)], ["네모 링", Vector3(1.1, 1.0, 1.1), "ring:4"], ["반달 아치", Vector3(1.3, 1.0, 1.0), "ring:arch"]],
	"box": [["정육면체", Vector3(1, 1, 1)], ["벽돌", Vector3(1.6, 0.6, 0.9)], ["기둥 블록", Vector3(0.5, 2.0, 0.5)], ["ㄴ자 블록", Vector3(1.2, 1.0, 1.0), "box:L"], ["계단 블록", Vector3(1.3, 1.0, 1.0), "box:step"], ["십자 블록", Vector3(1.3, 0.45, 1.3), "box:cross"]],
	"rod": [["막대", Vector3(1, 1, 1)], ["짧은 막대", Vector3(1, 0.45, 1)], ["긴 막대", Vector3(0.8, 1.7, 0.8)], ["ㄱ자 막대", Vector3(1.1, 1.0, 1.1), "rod:bent"], ["T자 막대", Vector3(1.2, 1.0, 1.2), "rod:T"]],
	"plate": [["판", Vector3(1, 1, 1)], ["넓은 판", Vector3(1.7, 1, 1.6)], ["좁은 판", Vector3(0.45, 1, 1.3)], ["긴 판", Vector3(3.0, 1.2, 0.9)], ["둥근 판", Vector3(1.1, 1.0, 1.1), "plate:round"], ["별 판", Vector3(1.2, 1.0, 1.2), "plate:star"], ["하트 판", Vector3(1.15, 1.0, 1.15), "plate:heart"]],
	"wedge": [["쐐기", Vector3(1, 1, 1)], ["납작 쐐기", Vector3(1.4, 0.5, 1)], ["긴 쐐기", Vector3(0.7, 1, 2.0)], ["지붕", Vector3(1.3, 0.8, 1.0), "wedge:roof"]],
	"potato": [["감자", Vector3(1, 1, 1)], ["길쭉 감자", Vector3(1.4, 0.8, 0.8)], ["울퉁 감자", Vector3(1.1, 1.1, 1.0), "potato:lump"]],
	"pebble": [["자갈", Vector3(1, 1, 1)], ["납작 자갈", Vector3(1.3, 0.6, 1.3)]],
}

## 땅에 굴러다니는 덩어리 색 (팔레트 번호)
const TOY_COLORS := [1, 2, 3, 4, 5, 7, 8, 10, 11, 13]

## 할당량 (6인). 검수 반영: ★ 상한 4.0 — ★4.5는 ★5 제한 하에서 수학적으로 불가능했다.
## 값은 6인 평점 격자(0.2 단위) 위에만 둔다.
const QUOTA := [
	[3.0, 2], [3.0, 3], [3.4, 3], [3.4, 4],
	[3.6, 4], [3.8, 5], [4.0, 5], [4.0, 6],
]

const BOTS := [
	["곰돌이", 12], ["토끼", 1], ["펭귄", 9], ["여우", 3], ["고양이", 14],
]

static var _palette: Array = []
static var _meshes := {}
static var _mats := {}
static var _base := {}
static var _points := {}
static var font_regular: Font
static var font_bold: Font


static func palette() -> Array:
	if _palette.is_empty():
		var raw := [
			["크림", "#F2EBDC"], ["분홍", "#E8A4C4"], ["빨강", "#C91A09"], ["주황", "#FE8A18"],
			["노랑", "#F2CD37"], ["연두", "#A5CA18"], ["초록", "#237841"], ["하늘", "#5DC2D8"],
			["파랑", "#0055BF"], ["남색", "#0A3463"], ["보라", "#8E5AA8"], ["연보라", "#CDA4DE"],
			["갈색", "#6B3A1E"], ["베이지", "#E4CD9E"], ["회색", "#A0A5A9"], ["검정", "#1B2A34"],
		]
		for r in raw:
			_palette.append({"name": r[0], "color": Color(r[1])})
	return _palette


static func color(i: int) -> Color:
	var p := palette()
	return p[clampi(i, 0, p.size() - 1)]["color"]


static func load_fonts() -> void:
	if font_regular == null:
		# v0.5: 손글씨(Gaegu) → 나눔고딕. v0.6.4: → Pretendard ("글자가 조잡하다" 피드백 — 한국어 UI 표준에 가까운 글꼴)
		font_regular = load("res://assets/fonts/Pretendard-Regular.otf")
		font_bold = load("res://assets/fonts/Pretendard-Bold.otf")
		for f in [font_regular, font_bold]:   # 선명하게: 가벼운 힌팅 · 서브픽셀 위치
			if f is FontFile:
				(f as FontFile).hinting = TextServer.HINTING_LIGHT
				(f as FontFile).subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO


# ── 메시 ──────────────────────────────────────────────

static func mesh(t: String) -> Mesh:
	if _meshes.has(t):
		return _meshes[t]
	var m: Mesh
	match t:
		"sphere":
			var s := SphereMesh.new(); s.radius = 0.3; s.height = 0.6; s.radial_segments = 18; s.rings = 9; m = s
		"hemi":
			var s := SphereMesh.new(); s.radius = 0.3; s.height = 0.3; s.is_hemisphere = true; s.radial_segments = 18; s.rings = 5; m = s
		"cylinder":
			var c := CylinderMesh.new(); c.top_radius = 0.25; c.bottom_radius = 0.25; c.height = 0.6; c.radial_segments = 18; c.rings = 0; m = c
		"cone":
			var c := CylinderMesh.new(); c.top_radius = 0.0; c.bottom_radius = 0.3; c.height = 0.6; c.radial_segments = 18; c.rings = 0; m = c
		"capsule":
			var c := CapsuleMesh.new(); c.radius = 0.15; c.height = 0.6; c.radial_segments = 14; c.rings = 3; m = c
		"ring":
			var r := TorusMesh.new(); r.inner_radius = 0.17; r.outer_radius = 0.3; r.rings = 22; r.ring_segments = 9; m = r
		"box":
			m = rounded_box(Vector3(0.5, 0.5, 0.5), 0.07)   # v0.6: 둥근 모서리
		"rod":
			m = rounded_box(Vector3(0.12, 0.9, 0.12), 0.04)
		"plate":
			m = rounded_box(Vector3(0.7, 0.06, 0.5), 0.025)
		"wedge":
			var p := PrismMesh.new(); p.size = Vector3(0.5, 0.5, 0.5); p.left_to_right = 0.0; m = p
		"potato":
			var s := SphereMesh.new(); s.radius = 0.3; s.height = 0.6; s.radial_segments = 7; s.rings = 4; m = s
		"pebble":
			var s := SphereMesh.new(); s.radius = 0.3; s.height = 0.6; s.radial_segments = 6; s.rings = 3; m = s
		_:
			m = _variant_mesh(t)
	_meshes[t] = m
	return m


## 변형 고유의 모양 (같은 종류지만 생김새가 다르다). 크기는 원래 종류의 틀 안에 맞춘다.
static func _variant_mesh(key: String) -> Mesh:
	match key:
		"sphere:gem":
			var s := SphereMesh.new(); s.radius = 0.3; s.height = 0.6; s.radial_segments = 6; s.rings = 2; return s
		"hemi:cap":
			var h := SphereMesh.new(); h.radius = 0.3; h.height = 0.3; h.is_hemisphere = true; h.radial_segments = 18; h.rings = 5
			var st := CylinderMesh.new(); st.top_radius = 0.1; st.bottom_radius = 0.12; st.height = 0.14; st.radial_segments = 10; st.rings = 0
			return _merge([[h, Transform3D(Basis(), Vector3(0, 0.07, 0))], [st, Transform3D()]])
		"cylinder:6", "cylinder:3":
			var c := CylinderMesh.new(); c.top_radius = 0.25; c.bottom_radius = 0.25; c.height = 0.6
			c.radial_segments = 6 if key == "cylinder:6" else 3; c.rings = 0; return c
		"cylinder:pot":
			var c := CylinderMesh.new(); c.top_radius = 0.28; c.bottom_radius = 0.18; c.height = 0.6; c.radial_segments = 16; c.rings = 0
			var rim := CylinderMesh.new(); rim.top_radius = 0.31; rim.bottom_radius = 0.31; rim.height = 0.1; rim.radial_segments = 16; rim.rings = 0
			return _merge([[c, Transform3D()], [rim, Transform3D(Basis(), Vector3(0, 0.27, 0))]])
		"cone:4", "cone:5":
			var c := CylinderMesh.new(); c.top_radius = 0.0; c.bottom_radius = 0.3; c.height = 0.6
			c.radial_segments = 4 if key == "cone:4" else 5; c.rings = 0; return c
		"capsule:bean":
			var a := CapsuleMesh.new(); a.radius = 0.15; a.height = 0.42; a.radial_segments = 12; a.rings = 2
			return _merge([[a, Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, 0.1, -0.08))],
				[a, Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, -0.1, -0.08))]])
		"ring:4":
			var parts := []
			for i in 4:
				var b := BoxMesh.new(); b.size = Vector3(0.6, 0.13, 0.13)
				var ang := PI / 2 * i
				parts.append([b, Transform3D(Basis(Vector3.UP, ang), Basis(Vector3.UP, ang) * Vector3(0, 0, 0.235))])
			return _merge(parts)
		"ring:arch":
			var parts := []
			for i in 7:
				var ang := PI * (i + 0.5) / 7.0
				var b := BoxMesh.new(); b.size = Vector3(0.15, 0.15, 0.2)
				parts.append([b, Transform3D(Basis(Vector3.BACK, ang), Vector3(cos(ang) * 0.24, sin(ang) * 0.24, 0))])
			return _merge(parts)
		"box:L":
			var a := BoxMesh.new(); a.size = Vector3(0.5, 0.22, 0.5)
			var b := BoxMesh.new(); b.size = Vector3(0.22, 0.28, 0.5)
			return _merge([[a, Transform3D(Basis(), Vector3(0, -0.14, 0))], [b, Transform3D(Basis(), Vector3(-0.14, 0.11, 0))]])
		"box:step":
			var parts := []
			for i in 3:
				var b := BoxMesh.new(); b.size = Vector3(0.5 - i * 0.1667, 0.1667, 0.5)
				parts.append([b, Transform3D(Basis(), Vector3(-i * 0.0833, -0.1667 + i * 0.1667, 0))])
			return _merge(parts)
		"box:cross":
			var a := BoxMesh.new(); a.size = Vector3(0.5, 0.25, 0.17)
			var b := BoxMesh.new(); b.size = Vector3(0.17, 0.25, 0.5)
			return _merge([[a, Transform3D()], [b, Transform3D()]])
		"rod:bent":
			var a := BoxMesh.new(); a.size = Vector3(0.12, 0.9, 0.12)
			var b := BoxMesh.new(); b.size = Vector3(0.36, 0.12, 0.12)
			return _merge([[a, Transform3D(Basis(), Vector3(-0.12, 0, 0))], [b, Transform3D(Basis(), Vector3(0.12, 0.39, 0))]])
		"rod:T":
			var a := BoxMesh.new(); a.size = Vector3(0.12, 0.9, 0.12)
			var b := BoxMesh.new(); b.size = Vector3(0.5, 0.12, 0.12)
			return _merge([[a, Transform3D()], [b, Transform3D(Basis(), Vector3(0, 0.39, 0))]])
		"plate:round":
			var c := CylinderMesh.new(); c.top_radius = 0.3; c.bottom_radius = 0.3; c.height = 0.06; c.radial_segments = 22; c.rings = 0; return c
		"plate:star":
			var pts := PackedVector2Array()
			for i in 10:
				var ang := -PI / 2 + PI * i / 5.0
				var rr := 0.33 if i % 2 == 0 else 0.14
				pts.append(Vector2(cos(ang), sin(ang)) * rr)
			return _extrude(pts, 0.06)
		"plate:heart":
			var pts := PackedVector2Array()
			for i in 28:
				var s := TAU * i / 28.0
				var x := 16.0 * pow(sin(s), 3)
				var y := 13.0 * cos(s) - 5.0 * cos(2 * s) - 2.0 * cos(3 * s) - cos(4 * s)
				pts.append(Vector2(x, -y) * 0.019)
			return _extrude(pts, 0.06)
		"wedge:roof":
			var p := PrismMesh.new(); p.size = Vector3(0.5, 0.5, 0.5); p.left_to_right = 0.5; return p
		"potato:lump":
			var parts := []
			var spots := [[Vector3(-0.1, 0, 0), 0.24], [Vector3(0.12, 0.04, 0.05), 0.2], [Vector3(0.02, 0.1, -0.08), 0.17]]
			for sp in spots:
				var s := SphereMesh.new(); s.radius = sp[1]; s.height = sp[1] * 2; s.radial_segments = 7; s.rings = 4
				parts.append([s, Transform3D(Basis(), sp[0])])
			return _merge(parts)
	push_error("unknown mesh " + key)
	return BoxMesh.new()


static func _merge(parts: Array) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		st.append_from(p[0], 0, p[1])
	return st.commit()


## XZ 평면 다각형을 두께 h로 세운 판 (Godot 앞면 = 시계 방향)
static func _extrude(poly: PackedVector2Array, h: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := Geometry2D.triangulate_polygon(poly)
	if Geometry2D.is_polygon_clockwise(poly):
		poly.reverse()
		tri = Geometry2D.triangulate_polygon(poly)
	var y0 := -h * 0.5
	var y1 := h * 0.5
	for i in range(0, tri.size(), 3):
		var a := poly[tri[i]]; var b := poly[tri[i + 1]]; var c := poly[tri[i + 2]]
		st.set_normal(Vector3.UP)
		for v in [a, b, c]:
			st.add_vertex(Vector3(v.x, y1, v.y))
		st.set_normal(Vector3.DOWN)
		for v in [a, c, b]:
			st.add_vertex(Vector3(v.x, y0, v.y))
	var n := poly.size()
	for i in n:
		var p := poly[i]; var q := poly[(i + 1) % n]
		var e := q - p
		var nrm := Vector3(-e.y, 0, e.x).normalized()
		st.set_normal(nrm)
		for v in [Vector3(p.x, y0, p.y), Vector3(q.x, y0, q.y), Vector3(q.x, y1, q.y),
				Vector3(p.x, y0, p.y), Vector3(q.x, y1, q.y), Vector3(p.x, y1, p.y)]:
			st.add_vertex(v)
	return st.commit()


## 이 비율이 고유 메시를 가진 변형이면 그 메시 키
static func mesh_key(t: String, shape: Vector3) -> String:
	for v in VARIANTS.get(t, []):
		if v.size() > 2 and (v[1] as Vector3).is_equal_approx(shape):
			return v[2]
	return t


static func _base_scale(t: String) -> Vector3:
	match t:
		"potato": return Vector3(1.2, 0.8, 0.9)
		"pebble": return Vector3(1.0, 0.55, 0.8)
	return Vector3.ONE


## 메시를 원점 중심으로 맞추는 기본 변환. 반구처럼 원점이 치우친 메시도 중심을 맞춘다.
static func base_xform(t: String) -> Transform3D:
	if _base.has(t):
		return _base[t]["xf"]
	var bs := _base_scale(t)
	var aabb := mesh(t).get_aabb()
	var center := aabb.get_center() * bs
	var xf := Transform3D(Basis.from_scale(bs), -center)
	_base[t] = {"xf": xf, "size": aabb.size * bs}
	return xf


## 기본 변환 후 로컬 크기 (scale 1 기준)
static func base_size(t: String) -> Vector3:
	base_xform(t)
	return _base[t]["size"]


static func collision_points(t: String) -> PackedVector3Array:
	if _points.has(t):
		return _points[t]
	var xf := base_xform(t)
	var faces := mesh(t).get_faces()
	var seen := {}
	var out := PackedVector3Array()
	for v in faces:
		var key := Vector3i(roundi(v.x * 200), roundi(v.y * 200), roundi(v.z * 200))
		if seen.has(key):
			continue
		seen[key] = true
		out.append(xf * v)
	_points[t] = out
	return out


## 덩어리 재질 — 레고 같은 반짝이는 플라스틱. studs = 윗면 스터드 (각진 것 · 원기둥)
static func material(ci: int, alpha := 1.0, studs := true, finish := 0) -> Material:
	var key := "%d_%.2f_%s_%d" % [ci, alpha, studs, finish]
	if _mats.has(key):
		return _mats[key]
	if alpha >= 1.0:
		var bm := brick(color(ci), studs)
		bm.set_shader_parameter("finish", finish)
		bm.next_pass = outline_material()
		_mats[key] = bm
		return bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color(ci)
	m.roughness = 0.85
	m.metallic_specular = 0.2
	m.next_pass = outline_material()
	if alpha < 1.0:
		m.albedo_color.a = alpha
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


static var _brick_shader: Shader
## 브릭 셰이더 재질 (바닥판 · 덩어리 공용)
static func brick(c: Color, studs := true, pitch := 0.25, gloss := 0.3) -> ShaderMaterial:
	if _brick_shader == null:
		_brick_shader = load("res://assets/shaders/brick.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _brick_shader
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("studs", 1.0 if studs and STUDS else 0.0)
	m.set_shader_parameter("pitch", pitch)
	m.set_shader_parameter("gloss", gloss)
	return m


## 윗면에 스터드가 있는 종류 (레고 브릭 · 플레이트 · 둥근 브릭)
## v0.5: 스터드(레고 돌기) 끔 — "조립이 레고 방식이 아닌데 그래픽만 레고일 필요가 없다". 셰이더는 남겨 둠
const STUDS := false

## 마감 재질 이름 (조립 · 전시)
const FINISHES := ["플라스틱", "대리석", "청동", "나무", "금"]

static func has_studs(t: String) -> bool:
	return STUDS and t in ["box", "plate", "rod", "cylinder"]


static func flat_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.45
	m.metallic_specular = 0.5
	return m


# ── 타겟 템플릿 ───────────────────────────────────────
# 부위: [그룹, 중심, 월드 크기, 로컬 Y가 향할 월드축, 기울기(도), 색]

static func targets() -> Array:
	var Z := Vector3.ZERO
	return [
		{"name": "자전거", "parts": [
			["disk", Vector3(-0.65, 0.38, 0), Vector3(0.75, 0.75, 0.12), "z", Z, 15],
			["disk", Vector3(0.65, 0.38, 0), Vector3(0.75, 0.75, 0.12), "z", Z, 15],
			["bar", Vector3(0, 0.45, 0), Vector3(1.1, 0.08, 0.08), "x", Z, 2],
			["bar", Vector3(-0.12, 0.7, 0), Vector3(0.08, 0.55, 0.08), "y", Vector3(0, 0, 25), 2],
			["flat", Vector3(-0.25, 0.98, 0), Vector3(0.32, 0.06, 0.18), "y", Z, 12],
			["bar", Vector3(0.5, 0.75, 0), Vector3(0.07, 0.6, 0.07), "y", Vector3(0, 0, -15), 2],
			["bar", Vector3(0.56, 1.06, 0), Vector3(0.07, 0.07, 0.45), "z", Z, 15],
		]},
		{"name": "물고기", "parts": [
			["ball", Vector3(0, 0.5, 0), Vector3(1.2, 0.6, 0.4), "y", Z, 3],
			["flat", Vector3(-0.8, 0.5, 0), Vector3(0.35, 0.5, 0.06), "z", Z, 4],
			["ball", Vector3(0.4, 0.6, 0.19), Vector3(0.1, 0.1, 0.1), "y", Z, 15],
			["ball", Vector3(0.4, 0.6, -0.19), Vector3(0.1, 0.1, 0.1), "y", Z, 15],
			["point", Vector3(0, 0.88, 0), Vector3(0.35, 0.25, 0.06), "y", Z, 4],
			["point", Vector3(0.05, 0.2, 0), Vector3(0.25, 0.18, 0.06), "y", Vector3(180, 0, 0), 4],
		]},
		{"name": "나무", "parts": [
			["bar", Vector3(0, 0.45, 0), Vector3(0.22, 0.9, 0.22), "y", Z, 12],
			["ball", Vector3(0, 1.15, 0), Vector3(0.9, 0.7, 0.9), "y", Z, 6],
			["ball", Vector3(-0.32, 0.98, 0.1), Vector3(0.55, 0.5, 0.55), "y", Z, 5],
			["ball", Vector3(0.32, 1.02, -0.1), Vector3(0.55, 0.5, 0.55), "y", Z, 5],
			["ball", Vector3(0.22, 1.12, 0.4), Vector3(0.13, 0.13, 0.13), "y", Z, 2],
		]},
		{"name": "눈사람", "parts": [
			["ball", Vector3(0, 0.35, 0), Vector3(0.7, 0.7, 0.7), "y", Z, 0],
			["ball", Vector3(0, 0.9, 0), Vector3(0.5, 0.5, 0.5), "y", Z, 0],
			["ball", Vector3(0, 1.3, 0), Vector3(0.36, 0.36, 0.36), "y", Z, 0],
			["point", Vector3(0, 1.3, 0.22), Vector3(0.08, 0.08, 0.22), "z", Z, 3],
			["block", Vector3(0, 1.56, 0), Vector3(0.3, 0.25, 0.3), "y", Z, 15],
			["bar", Vector3(-0.45, 0.98, 0), Vector3(0.5, 0.05, 0.05), "x", Vector3(0, 0, 20), 12],
			["bar", Vector3(0.45, 0.98, 0), Vector3(0.5, 0.05, 0.05), "x", Vector3(0, 0, -20), 12],
		]},
		{"name": "로켓", "parts": [
			["bar", Vector3(0, 0.8, 0), Vector3(0.42, 1.1, 0.42), "y", Z, 14],
			["point", Vector3(0, 1.55, 0), Vector3(0.42, 0.42, 0.42), "y", Z, 2],
			["flat", Vector3(-0.3, 0.32, 0), Vector3(0.2, 0.36, 0.05), "z", Z, 2],
			["flat", Vector3(0.3, 0.32, 0), Vector3(0.2, 0.36, 0.05), "z", Z, 2],
			["flat", Vector3(0, 0.32, 0.3), Vector3(0.05, 0.36, 0.2), "x", Z, 2],
			["disk", Vector3(0, 0.95, 0.22), Vector3(0.18, 0.18, 0.05), "z", Z, 7],
			["point", Vector3(0, 0.1, 0), Vector3(0.26, 0.2, 0.26), "y", Vector3(180, 0, 0), 4],
		]},
		{"name": "강아지", "parts": [
			["block", Vector3(0, 0.55, 0), Vector3(0.9, 0.4, 0.4), "y", Z, 13],
			["ball", Vector3(0.55, 0.85, 0), Vector3(0.4, 0.4, 0.4), "y", Z, 13],
			["flat", Vector3(0.5, 1.06, 0.16), Vector3(0.12, 0.2, 0.05), "z", Z, 12],
			["flat", Vector3(0.5, 1.06, -0.16), Vector3(0.12, 0.2, 0.05), "z", Z, 12],
			["ball", Vector3(0.78, 0.8, 0), Vector3(0.2, 0.15, 0.18), "y", Z, 12],
			["bar", Vector3(0.3, 0.18, 0.13), Vector3(0.1, 0.36, 0.1), "y", Z, 13],
			["bar", Vector3(0.3, 0.18, -0.13), Vector3(0.1, 0.36, 0.1), "y", Z, 13],
			["bar", Vector3(-0.3, 0.18, 0.13), Vector3(0.1, 0.36, 0.1), "y", Z, 13],
			["bar", Vector3(-0.3, 0.18, -0.13), Vector3(0.1, 0.36, 0.1), "y", Z, 13],
			["bar", Vector3(-0.52, 0.78, 0), Vector3(0.05, 0.3, 0.05), "y", Vector3(0, 0, 30), 12],
		]},
		{"name": "우산", "parts": [
			["dome", Vector3(0, 1.2, 0), Vector3(1.2, 0.45, 1.2), "y", Z, 8],
			["dome", Vector3(0, 1.4, 0), Vector3(0.6, 0.2, 0.6), "y", Z, 7],
			["bar", Vector3(0, 0.65, 0), Vector3(0.06, 1.1, 0.06), "y", Z, 14],
			["disk", Vector3(0.08, 0.1, 0), Vector3(0.25, 0.25, 0.05), "z", Z, 12],
			["point", Vector3(0, 1.56, 0), Vector3(0.08, 0.15, 0.08), "y", Z, 14],
		]},
		{"name": "자동차", "parts": [
			["block", Vector3(0, 0.45, 0), Vector3(1.3, 0.35, 0.6), "y", Z, 2],
			["block", Vector3(-0.05, 0.8, 0), Vector3(0.7, 0.35, 0.55), "y", Z, 7],
			["disk", Vector3(0.45, 0.2, 0.32), Vector3(0.38, 0.38, 0.1), "z", Z, 15],
			["disk", Vector3(-0.45, 0.2, 0.32), Vector3(0.38, 0.38, 0.1), "z", Z, 15],
			["disk", Vector3(0.45, 0.2, -0.32), Vector3(0.38, 0.38, 0.1), "z", Z, 15],
			["disk", Vector3(-0.45, 0.2, -0.32), Vector3(0.38, 0.38, 0.1), "z", Z, 15],
			["ball", Vector3(0.66, 0.48, 0.2), Vector3(0.1, 0.1, 0.1), "y", Z, 4],
			["ball", Vector3(0.66, 0.48, -0.2), Vector3(0.1, 0.1, 0.1), "y", Z, 4],
		]},
	]


## 로컬 Y를 월드 축으로 보내는 회전과, 월드 크기 → 로컬 크기 변환
static func up_basis(up: String) -> Basis:
	match up:
		"z": return Basis(Vector3.RIGHT, PI / 2)
		"x": return Basis(Vector3.BACK, -PI / 2)
	return Basis.IDENTITY


static func world_to_local_size(up: String, w: Vector3) -> Vector3:
	match up:
		"z": return Vector3(w.x, w.z, w.y)
		"x": return Vector3(w.y, w.x, w.z)
	return w


# ── 편성 ─────────────────────────────────────────────

const FORMATIONS := {
	"풍족": "전 종류가 넉넉하다. 순수 표현력 대결.",
	"곡면 기근": "구·반구·원기둥·원뿔·캡슐·링이 귀하다. 둥근 걸 각진 걸로 풀어라.",
	"직선 기근": "막대·판이 귀하다. 골격 없이 덩어리로 뭉쳐라.",
	"극단 편중": "한 종류가 40%를 차지한다. 그걸로 어떻게든.",
}


## 총량 = 인원 × 12 × 2.0. 육면체는 1인당 5개 항상 보장 (기본 선반 — 검수 반영).
static func formation_counts(kind: String, players: int, rng: RandomNumberGenerator) -> Dictionary:
	var total := players * 24
	var box_min := players * 5
	var c := {}
	for t in TYPES:
		c[t] = 0
	match kind:
		"곡면 기근":
			for t in TYPES:
				if KIND[t] == "curve":
					c[t] = maxi(2, players / 2)
		"직선 기근":
			c["rod"] = maxi(2, players / 2)
			c["plate"] = maxi(2, players / 2)
		"극단 편중":
			var pool := TYPES.duplicate()
			pool.erase("box")
			var hot: String = pool[rng.randi() % pool.size()]
			c[hot] = int(total * 0.4)
			c["_hot"] = hot
	c["box"] = maxi(c["box"], box_min)
	# 남은 몫을 비어있는 종류에 고르게
	var fixed := 0
	var free_types: Array = []
	for t in TYPES:
		if c[t] > 0:
			fixed += c[t]
		else:
			free_types.append(t)
	var left := maxi(0, total - fixed)
	if not free_types.is_empty():
		var each := left / free_types.size()
		for t in free_types:
			c[t] = each
		for i in range(left - each * free_types.size()):
			c[free_types[rng.randi() % free_types.size()]] += 1
	return c


static func pick_formation(round_i: int, rng: RandomNumberGenerator) -> String:
	if round_i <= 1:
		return "풍족"
	var lean := ["풍족", "곡면 기근", "직선 기근", "극단 편중"]
	var hard := ["곡면 기근", "직선 기근", "극단 편중"]
	if round_i == 2:
		return lean[rng.randi() % lean.size()]
	return hard[rng.randi() % hard.size()]


# ── 개인 목표 카드 ──────────────────────────────────
# 성적 조건: "half" = 상위 절반, "notlast" = 꼴찌만 아니면 (동점 규칙은 Judge 참고)

static func cards() -> Array:
	# v0.5: 모으기 · 만들기와 이어지는 조건. 성공하면 전체 등수 +0.5점 · 방 티켓 +1. 등수 조건은 없앴다
	return [
		# v0.6 보물찾기 카드 (찾는 동안의 기록으로 판정)
		{"id": "gold", "name": "황금 손", "desc": "금봉투를 1개 이상 찾고", "rank": ""},
		{"id": "hidden", "name": "뒤지기 장인", "desc": "가구 속 봉투를 3개 이상 찾고", "rank": ""},
		{"id": "up", "name": "높은 곳 탐험가", "desc": "위층에서 봉투를 2개 이상 찾고", "rank": ""},
		{"id": "many", "name": "싹쓸이", "desc": "봉투를 8개 이상 찾고", "rank": ""},
		{"id": "rainbow", "name": "알록달록", "desc": "4가지 색 이상 써서", "rank": ""},
		{"id": "duo", "name": "깔맞춤", "desc": "2가지 색 이하로", "rank": ""},
		{"id": "tall", "name": "고층 건물", "desc": "높이 1.5 이상으로", "rank": ""},
		{"id": "minimal", "name": "미니멀", "desc": "덩어리 6개 이하로", "rank": ""},
		{"id": "epic", "name": "대작", "desc": "덩어리 10개 이상으로", "rank": ""},
		{"id": "nostretch", "name": "원래 모양", "desc": "늘이기 없이", "rank": ""},
	]


static func rank_text(r: String) -> String:
	if r == "":
		return ""
	return "★ 상위 절반" if r == "half" else "★ 꼴찌만 아니면"


# ── 아이템 (모은 덩어리 하나) ────────────────────────
# {"type", "shape": Vector3 비율, "color": 팔레트 번호, "origin": ground|tear|dig|auto, "name"}

static func variant(t: String, i: int) -> Array:
	var vs: Array = VARIANTS[t]
	return vs[clampi(i, 0, vs.size() - 1)]


static func variant_name(t: String, shape: Vector3) -> String:
	for v in VARIANTS[t]:
		if (v[1] as Vector3).is_equal_approx(shape):
			return v[0]
	return NAMES[t]


static func make_item(t: String, shape: Vector3, ci: int, origin: String, src := "") -> Dictionary:
	return {"type": t, "shape": shape, "color": ci, "origin": origin, "src": src, "name": variant_name(t, shape)}


## 무작위 변형 (기본형이 절반)
static func random_item(t: String, origin: String, rng: RandomNumberGenerator) -> Dictionary:
	var vs: Array = VARIANTS[t]
	var v: Array = vs[0] if rng.randf() < 0.5 else vs[rng.randi() % vs.size()]
	return make_item(t, v[1], TOY_COLORS[rng.randi() % TOY_COLORS.size()], origin)


## 장난감 느낌의 외곽선 — 필드 · 손 · 작업대 · 전시 어디서나 같은 재질
static var _outline: StandardMaterial3D
static func outline_material() -> StandardMaterial3D:
	if _outline == null:
		_outline = StandardMaterial3D.new()
		_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline.grow = true
		_outline.grow_amount = 0.008
		_outline.albedo_color = Color("#3B3024")
	return _outline


static var _rust: StandardMaterial3D
static func rust_material() -> StandardMaterial3D:
	if _rust == null:
		_rust = StandardMaterial3D.new()
		_rust.albedo_color = Color("#6B5B4C")
		_rust.roughness = 1.0
		_rust.metallic_specular = 0.1
		_rust.next_pass = outline_material()
	return _rust


static var _plain := {}
## 외곽선 없는 같은 색 재질 (아주 크게 키운 덩어리용)
static func plain_material(ci: int, studs := true, finish := 0) -> Material:
	var key := "%d_%s_%d" % [ci, studs, finish]
	if not _plain.has(key):
		var m: Material = material(ci, 1.0, studs, finish).duplicate()
		m.next_pass = null
		_plain[key] = m
	return _plain[key]


## 모서리를 둥글게 깎은 상자 (조잡한 느낌 줄이기). 반지름 r은 가장 짧은 변 기준
static func rounded_box(size: Vector3, rr: float) -> Mesh:
	var e := size * 0.5
	var r := minf(rr, minf(e.x, minf(e.y, e.z)) * 0.95)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var core := e - Vector3.ONE * r
	var coords := func(h: float) -> Array:
		return [-h, -h + r, h - r, h]   # 모서리 한 번 깎기 (가볍게 — 웹 성능)
	for ax in 3:
		for sgn in [-1.0, 1.0]:
			var u := (ax + 1) % 3
			var v := (ax + 2) % 3
			var cu: Array = coords.call(e[u])
			var cv: Array = coords.call(e[v])
			var grid := []
			for i in cu.size():
				var row := []
				for j in cv.size():
					var p := Vector3.ZERO
					p[ax] = e[ax] * sgn
					p[u] = cu[i]
					p[v] = cv[j]
					var c := p.clamp(-core, core)
					var d := p - c
					var n := d.normalized() if d.length() > 0.00001 else Vector3.ZERO
					if n == Vector3.ZERO:
						n[ax] = sgn
					row.append([c + n * r, n])
				grid.append(row)
			for i in cu.size() - 1:
				for j in cv.size() - 1:
					var q := [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
					var order := [0, 2, 1, 0, 3, 2] if sgn > 0 else [0, 1, 2, 0, 2, 3]
					for k in order:
						st.set_normal(q[k][1])
						st.add_vertex(q[k][0])
	return st.commit()
