class_name Themes
extends RefCounted
## 보물찾기 테마 (v0.6 브랜치 treasure-hunt) — 라운드마다 공간이 바뀐다.
## 학교 → 미술관 → 해적선. 공간마다 숨김 자리 · 파츠 세트 · 만들 것이 다르다.

const ORDER := ["school", "museum", "ship"]

const INFO := {
	"school": {"name": "학교", "sky": "#CFE6F2", "desc": "교실 · 사물함 복도 · 2층 과학실 · 컴퓨터실 · 도서관 다락 · 체육관 무대. 서랍과 사물함을 뒤져라"},
	"museum": {"name": "미술관", "sky": "#E9E4DA", "desc": "조각 홀 · 2층 발코니 · 전시실 셋 · 창고 선반(사다리). 액자 뒤와 받침대 서랍"},
	"ship": {"name": "해적선", "sky": "#BFE3F5", "desc": "보트 창고 부두 · 화물칸 · 포갑판 · 갑판 · 선장실 · 돛대 망루. 술통과 보물상자를 열어라"},
}

## 보물 등급: [이름, 비율, 파츠 수]
const TIERS := {
	"note": ["쪽지", 0.6, 1],
	"env": ["편지봉투", 0.3, 2],
	"gold": ["금봉투", 0.1, 3],
}

## 한 판 보물 수 = 인원 × 1.5 × 10
static func treasure_count(players: int) -> int:
	return int(players * 1.5 * 10)


## 파츠 세트: 판정 종류 → [[이름, 변형 번호, [색들]], ...]
## 판정은 12종 그대로 — 이름 · 색 · 변형만 테마에 맞춘다
const KITS := {
	"school": {
		"sphere": [["지구본 공", 0, [8, 7]], ["구슬", 0, [2, 8, 6, 4]], ["럭비공", 1, [12]]],
		"hemi": [["종 뚜껑", 0, [4]], ["반구 자석", 1, [2]]],
		"cylinder": [["풀", 0, [0, 7]], ["물통", 0, [8, 7]], ["동전", 3, [4]], ["육각 연필", 4, [4]], ["화분", 6, [3]]],
		"cone": [["고깔", 0, [3, 2]], ["연필 끝", 1, [13]], ["피라미드 모형", 3, [4]]],
		"capsule": [["필통", 0, [1, 7, 10]], ["리코더", 1, [0]]],
		"ring": [["테이프", 0, [0, 14]], ["훌라후프", 2, [2, 6]]],
		"box": [["지우개", 1, [0, 1]], ["주사위", 0, [0]], ["책", 1, [2, 8, 6]], ["사물함 블록", 2, [14]]],
		"rod": [["분필", 0, [0]], ["자", 2, [4]], ["ㄱ자 자", 3, [14]]],
		"plate": [["공책", 0, [8, 2, 6]], ["색종이", 0, [1, 4, 7, 5]], ["별 스티커", 5, [4]], ["하트 스티커", 6, [2]]],
		"wedge": [["책꽂이 받침", 0, [12]], ["지붕 모형", 3, [2]]],
		"potato": [["찰흙", 0, [13, 3]], ["감자 도장", 1, [13]]],
		"pebble": [["조약돌", 0, [14]], ["지우개 똥", 1, [0]]],
	},
	"museum": {
		"sphere": [["대리석 공", 0, [0, 14]], ["진주", 0, [0]], ["보석", 3, [2, 8, 6, 10]]],
		"hemi": [["돔 조각", 0, [13]], ["버섯 조각", 3, [2]]],
		"cylinder": [["기둥 조각", 2, [0]], ["물감통", 0, [2, 8, 4]], ["꽃병", 6, [8, 3]], ["금화", 3, [4]]],
		"cone": [["피라미드 조각", 3, [4]], ["오각뿔 조각", 4, [11]]],
		"capsule": [["붓 손잡이", 1, [12]], ["콩 조각", 3, [6]]],
		"ring": [["액자 고리", 0, [4]], ["네모 액자", 3, [12, 4]], ["아치 조형", 4, [0]]],
		"box": [["받침대", 0, [0]], ["대리석 블록", 1, [0, 14]], ["계단 조형", 4, [13]]],
		"rod": [["붓", 0, [12]], ["T자 조형", 4, [14]]],
		"plate": [["캔버스", 1, [0]], ["그림", 0, [8, 2, 6]], ["팔레트", 4, [13]]],
		"wedge": [["지붕 조형", 3, [2]], ["쐐기 조각", 0, [14]]],
		"potato": [["석고 덩어리", 0, [0]], ["울퉁 조각", 2, [13]]],
		"pebble": [["원석", 0, [10, 7]], ["납작 원석", 1, [14]]],
	},
	"ship": {
		"sphere": [["대포알", 0, [15]], ["진주", 0, [0]], ["보석", 3, [2, 6, 8]]],
		"hemi": [["투구", 0, [14]], ["버섯 갓", 3, [2]]],
		"cylinder": [["나무통", 0, [12]], ["돛대 조각", 2, [12]], ["금화", 3, [4]], ["망원경", 2, [4]]],
		"cone": [["깔때기", 0, [14]], ["해적 모자 끝", 1, [15]]],
		"capsule": [["앵무새 깃털", 1, [2, 6]], ["콩 통조림", 3, [6]]],
		"ring": [["닻 고리", 0, [14]], ["구명 튜브", 1, [2, 0]], ["밧줄 고리", 2, [13]]],
		"box": [["보물 상자", 0, [12]], ["나무 상자", 1, [12, 13]], ["돛대 블록", 2, [12]]],
		"rod": [["노", 2, [12]], ["갈고리", 3, [14]], ["키 손잡이", 4, [12]]],
		"plate": [["돛 천", 0, [0]], ["보물 지도", 1, [13]], ["해적 깃발", 0, [15]]],
		"wedge": [["뱃머리 조각", 0, [12]], ["지붕", 3, [2]]],
		"potato": [["감자", 0, [13]], ["울퉁 감자", 2, [13]]],
		"pebble": [["조약돌", 0, [14]], ["납작 돌", 1, [14]]],
	},
}


## 테마 파츠 하나 (종류는 편성에서 정해져 온다)
static func make_part(theme: String, t: String, rng: RandomNumberGenerator) -> Dictionary:
	var opts: Array = KITS[theme][t]
	var o: Array = opts[rng.randi() % opts.size()]
	var cols: Array = o[2]
	var it := Data.make_item(t, Data.variant(t, int(o[1]))[1], int(cols[rng.randi() % cols.size()]), "treasure", theme)
	it["name"] = o[0]
	return it


## 테마별 만들 것. 형식은 Data.targets()와 같다
static func targets() -> Array:
	var Z := Vector3.ZERO
	return [
		{"name": "지구본", "theme": "school", "parts": [
			["ball", Vector3(0, 1.0, 0), Vector3(0.7, 0.7, 0.7), "y", Z, 8],
			["disk", Vector3(0, 1.0, 0), Vector3(0.9, 0.9, 0.08), "z", Vector3(0, 0, -20), 14],
			["bar", Vector3(0, 0.45, 0), Vector3(0.08, 0.5, 0.08), "y", Z, 12],
			["disk", Vector3(0, 0.12, 0), Vector3(0.6, 0.08, 0.6), "y", Z, 12],
		]},
		{"name": "책가방", "theme": "school", "parts": [
			["block", Vector3(0, 0.5, 0), Vector3(0.7, 0.8, 0.35), "y", Z, 2],
			["flat", Vector3(0, 0.35, 0.21), Vector3(0.5, 0.35, 0.06), "z", Z, 4],
			["bar", Vector3(-0.2, 0.55, -0.21), Vector3(0.06, 0.6, 0.06), "y", Z, 15],
			["bar", Vector3(0.2, 0.55, -0.21), Vector3(0.06, 0.6, 0.06), "y", Z, 15],
			["disk", Vector3(0, 0.98, 0), Vector3(0.28, 0.22, 0.06), "z", Z, 15],
		]},
		{"name": "탁상시계", "theme": "school", "parts": [
			["disk", Vector3(0, 0.7, 0), Vector3(0.8, 0.8, 0.15), "z", Z, 0],
			["dome", Vector3(-0.3, 1.12, 0), Vector3(0.3, 0.2, 0.3), "y", Vector3(0, 0, 25), 4],
			["dome", Vector3(0.3, 1.12, 0), Vector3(0.3, 0.2, 0.3), "y", Vector3(0, 0, -25), 4],
			["bar", Vector3(-0.25, 0.2, 0), Vector3(0.06, 0.28, 0.06), "y", Vector3(0, 0, 20), 15],
			["bar", Vector3(0.25, 0.2, 0), Vector3(0.06, 0.28, 0.06), "y", Vector3(0, 0, -20), 15],
			["bar", Vector3(0, 0.8, 0.09), Vector3(0.04, 0.25, 0.03), "y", Z, 15],
		]},
		{"name": "조각상", "theme": "museum", "parts": [
			["block", Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6), "y", Z, 0],
			["block", Vector3(0, 0.95, 0), Vector3(0.45, 0.6, 0.3), "y", Z, 0],
			["ball", Vector3(0, 1.45, 0), Vector3(0.3, 0.36, 0.3), "y", Z, 0],
			["bar", Vector3(-0.3, 1.0, 0), Vector3(0.1, 0.5, 0.1), "y", Vector3(0, 0, 15), 0],
			["bar", Vector3(0.3, 1.0, 0), Vector3(0.1, 0.5, 0.1), "y", Vector3(0, 0, -15), 0],
		]},
		{"name": "이젤", "theme": "museum", "parts": [
			["bar", Vector3(-0.3, 0.7, 0.05), Vector3(0.06, 1.4, 0.06), "y", Vector3(0, 0, -8), 12],
			["bar", Vector3(0.3, 0.7, 0.05), Vector3(0.06, 1.4, 0.06), "y", Vector3(0, 0, 8), 12],
			["bar", Vector3(0, 0.65, -0.3), Vector3(0.06, 1.3, 0.06), "y", Vector3(-20, 0, 0), 12],
			["flat", Vector3(0, 1.0, 0.12), Vector3(0.7, 0.55, 0.05), "z", Z, 0],
			["bar", Vector3(0, 0.7, 0.12), Vector3(0.7, 0.06, 0.08), "x", Z, 12],
		]},
		{"name": "꽃병", "theme": "museum", "parts": [
			["ball", Vector3(0, 0.38, 0), Vector3(0.55, 0.7, 0.55), "y", Z, 8],
			["bar", Vector3(0, 0.82, 0), Vector3(0.22, 0.25, 0.22), "y", Z, 8],
			["bar", Vector3(-0.12, 1.1, 0), Vector3(0.04, 0.4, 0.04), "y", Vector3(0, 0, 15), 6],
			["bar", Vector3(0.12, 1.1, 0), Vector3(0.04, 0.4, 0.04), "y", Vector3(0, 0, -15), 6],
			["ball", Vector3(-0.2, 1.32, 0), Vector3(0.2, 0.2, 0.2), "y", Z, 2],
			["ball", Vector3(0.2, 1.32, 0), Vector3(0.2, 0.2, 0.2), "y", Z, 4],
		]},
		{"name": "닻", "theme": "ship", "parts": [
			["bar", Vector3(0, 0.7, 0), Vector3(0.1, 1.1, 0.1), "y", Z, 14],
			["disk", Vector3(0, 1.35, 0), Vector3(0.3, 0.3, 0.06), "z", Z, 14],
			["bar", Vector3(0, 1.12, 0), Vector3(0.6, 0.07, 0.07), "x", Z, 14],
			["bar", Vector3(-0.25, 0.25, 0), Vector3(0.5, 0.08, 0.08), "x", Vector3(0, 0, -25), 14],
			["bar", Vector3(0.25, 0.25, 0), Vector3(0.5, 0.08, 0.08), "x", Vector3(0, 0, 25), 14],
			["point", Vector3(-0.5, 0.42, 0), Vector3(0.12, 0.18, 0.08), "y", Vector3(0, 0, 30), 14],
			["point", Vector3(0.5, 0.42, 0), Vector3(0.12, 0.18, 0.08), "y", Vector3(0, 0, -30), 14],
		]},
		{"name": "앵무새", "theme": "ship", "parts": [
			["ball", Vector3(0, 0.6, 0), Vector3(0.4, 0.6, 0.35), "y", Z, 6],
			["ball", Vector3(0, 1.0, 0.05), Vector3(0.3, 0.3, 0.3), "y", Z, 2],
			["point", Vector3(0, 0.97, 0.22), Vector3(0.1, 0.12, 0.15), "z", Z, 4],
			["flat", Vector3(0, 0.22, -0.12), Vector3(0.2, 0.4, 0.05), "z", Vector3(30, 0, 0), 8],
			["flat", Vector3(-0.21, 0.65, 0), Vector3(0.05, 0.4, 0.25), "x", Z, 6],
			["flat", Vector3(0.21, 0.65, 0), Vector3(0.05, 0.4, 0.25), "x", Z, 6],
		]},
		{"name": "보물상자", "theme": "ship", "parts": [
			["block", Vector3(0, 0.28, 0), Vector3(0.9, 0.5, 0.55), "y", Z, 12],
			["dome", Vector3(0, 0.6, 0), Vector3(0.9, 0.25, 0.55), "y", Z, 12],
			["bar", Vector3(-0.3, 0.4, 0), Vector3(0.07, 0.75, 0.6), "y", Z, 4],
			["bar", Vector3(0.3, 0.4, 0), Vector3(0.07, 0.75, 0.6), "y", Z, 4],
			["ball", Vector3(0, 0.82, 0), Vector3(0.15, 0.15, 0.15), "y", Z, 4],
		]},
	]


static func targets_for(theme: String) -> Array:
	var out := []
	for t in targets():
		if t["theme"] == theme:
			out.append(t)
	return out


## 자동 작품 제목 (출품 이름표)
static func auto_title(target: String, rng: RandomNumberGenerator) -> String:
	var pats := ["무제 — %s", "%s의 오후", "작은 %s", "꿈꾸는 %s", "기억 속의 %s", "%s, 두 번째", "어느 날의 %s", "%s 습작 #%d", "빛나는 %s", "조용한 %s"]
	var p: String = pats[rng.randi() % pats.size()]
	return p % [target, rng.randi_range(2, 9)] if p.contains("%d") else p % target
