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
const SCALE_MAX := 3.0
const SIZE_MIN := 0.35
const SIZE_MAX := 3.0

## 덩어리 변형 — 같은 종류도 비율이 다른 버전이 처음부터 있다.
## 조립에서는 전체 크기와 회전만 바꾼다. 납작한 원기둥이 필요하면 "바퀴"를 뜯어 와야 한다.
## [이름, 비율(로컬 X·Y·Z)]
const VARIANTS := {
	"sphere": [["공", Vector3(1, 1, 1)], ["럭비공", Vector3(1.5, 0.8, 0.8)], ["접시", Vector3(1.4, 0.35, 1.4)]],
	"hemi": [["반구", Vector3(1, 1, 1)], ["납작 반구", Vector3(1.3, 0.5, 1.3)], ["높은 반구", Vector3(0.8, 1.6, 0.8)]],
	"cylinder": [["원기둥", Vector3(1, 1, 1)], ["바퀴", Vector3(1.5, 0.35, 1.5)], ["기둥", Vector3(0.55, 2.0, 0.55)], ["동전", Vector3(1.2, 0.12, 1.2)]],
	"cone": [["원뿔", Vector3(1, 1, 1)], ["뾰족 원뿔", Vector3(0.6, 1.6, 0.6)], ["납작 원뿔", Vector3(1.4, 0.5, 1.4)]],
	"capsule": [["캡슐", Vector3(1, 1, 1)], ["긴 캡슐", Vector3(0.8, 1.6, 0.8)], ["통통 캡슐", Vector3(1.6, 0.9, 1.6)]],
	"ring": [["링", Vector3(1, 1, 1)], ["타이어", Vector3(1, 2.6, 1)], ["가는 링", Vector3(1.2, 0.6, 1.2)]],
	"box": [["정육면체", Vector3(1, 1, 1)], ["벽돌", Vector3(1.6, 0.6, 0.9)], ["기둥 블록", Vector3(0.5, 2.0, 0.5)]],
	"rod": [["막대", Vector3(1, 1, 1)], ["짧은 막대", Vector3(1, 0.45, 1)], ["긴 막대", Vector3(0.8, 1.7, 0.8)]],
	"plate": [["판", Vector3(1, 1, 1)], ["넓은 판", Vector3(1.7, 1, 1.6)], ["좁은 판", Vector3(0.45, 1, 1.3)], ["긴 판", Vector3(3.0, 1.2, 0.9)]],
	"wedge": [["쐐기", Vector3(1, 1, 1)], ["납작 쐐기", Vector3(1.4, 0.5, 1)], ["긴 쐐기", Vector3(0.7, 1, 2.0)]],
	"potato": [["감자", Vector3(1, 1, 1)], ["길쭉 감자", Vector3(1.4, 0.8, 0.8)]],
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
			["크림", "#F3E9D2"], ["분홍", "#F2A7B5"], ["빨강", "#D9483B"], ["주황", "#F08A3C"],
			["노랑", "#F4C84A"], ["연두", "#A8D46F"], ["초록", "#3E8E5B"], ["하늘", "#8ECAE6"],
			["파랑", "#2F6FB5"], ["남색", "#263D6B"], ["보라", "#8E6CC4"], ["연보라", "#CDB8E8"],
			["갈색", "#8A5A3B"], ["베이지", "#D8B98C"], ["회색", "#9A9A9A"], ["검정", "#2B2B2B"],
		]
		for r in raw:
			_palette.append({"name": r[0], "color": Color(r[1])})
	return _palette


static func color(i: int) -> Color:
	var p := palette()
	return p[clampi(i, 0, p.size() - 1)]["color"]


static func load_fonts() -> void:
	if font_regular == null:
		font_regular = load("res://assets/fonts/Gaegu-Regular.ttf")
		font_bold = load("res://assets/fonts/Gaegu-Bold.ttf")
		# Gaegu에는 기호(「」★☆·→—…)가 없다. 웹에는 시스템 폰트 대체가 없으므로 나눔고딕으로 채운다.
		font_regular.fallbacks = [load("res://assets/fonts/NanumGothic-Regular.ttf")]
		font_bold.fallbacks = [load("res://assets/fonts/NanumGothic-Bold.ttf")]


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
			var b := BoxMesh.new(); b.size = Vector3(0.5, 0.5, 0.5); m = b
		"rod":
			var b := BoxMesh.new(); b.size = Vector3(0.12, 0.9, 0.12); m = b
		"plate":
			var b := BoxMesh.new(); b.size = Vector3(0.7, 0.06, 0.5); m = b
		"wedge":
			var p := PrismMesh.new(); p.size = Vector3(0.5, 0.5, 0.5); p.left_to_right = 0.0; m = p
		"potato":
			var s := SphereMesh.new(); s.radius = 0.3; s.height = 0.6; s.radial_segments = 7; s.rings = 4; m = s
		"pebble":
			var s := SphereMesh.new(); s.radius = 0.3; s.height = 0.6; s.radial_segments = 6; s.rings = 3; m = s
		_:
			push_error("unknown type " + t)
			m = BoxMesh.new()
	_meshes[t] = m
	return m


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


static func material(ci: int, alpha := 1.0) -> StandardMaterial3D:
	var key := "%d_%.2f" % [ci, alpha]
	if _mats.has(key):
		return _mats[key]
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


static func flat_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	m.metallic_specular = 0.15
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
	return [
		{"id": "minimal", "name": "미니멀", "desc": "덩어리 6개 이하로", "rank": "half"},
		{"id": "glutton", "name": "과식", "desc": "모은 덩어리를 전부 써서", "rank": "notlast"},
		{"id": "mono", "name": "단색", "desc": "한 가지 색만 써서", "rank": "half"},
		{"id": "stubborn", "name": "외골수", "desc": "한 종류를 절반 이상 써서", "rank": "half"},
		{"id": "honest", "name": "정직", "desc": "크기를 하나도 안 바꾸고", "rank": "notlast"},
		{"id": "curvy", "name": "곡선만", "desc": "곡면 덩어리만 써서", "rank": "notlast"},
		{"id": "wrecker", "name": "뜯기 장인", "desc": "뜯어서 얻은 덩어리 4개 이상 써서", "rank": "notlast"},
	]


static func rank_text(r: String) -> String:
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


static func make_item(t: String, shape: Vector3, ci: int, origin: String) -> Dictionary:
	return {"type": t, "shape": shape, "color": ci, "origin": origin, "name": variant_name(t, shape)}


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
		_outline.grow_amount = 0.012
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
static func plain_material(ci: int) -> StandardMaterial3D:
	if not _plain.has(ci):
		var m: StandardMaterial3D = material(ci).duplicate()
		m.next_pass = null
		_plain[ci] = m
	return _plain[ci]
