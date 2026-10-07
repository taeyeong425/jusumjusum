extends Node
## 전역 상태 (autoload "Game"). 한 판의 진행과 기록을 들고 있다.

signal phase_changed(name: String)

const PLAYERS := 6
const ROUNDS := 3                # 한 판은 무조건 3라운드. 할당량은 라운드마다 통과/실패만 기록
const CARD_BONUS := 0.5         # 카드 성공 = 그 라운드 점수 +0.5 (전체 등수)

var rng := RandomNumberGenerator.new()
var short_mode := false
var practice := false            # 조립만 해 보기 (보물찾기 없이 덩어리를 받고 바로 조립 — 조립 피드백용)
var autotest := false

var round_i := 1
var target: Dictionary
var theme := "school"           # 이번 라운드 공간 (Themes.ORDER)
var formation := "풍족"
var counts: Dictionary
var quota: Array
var players: Array = []          # [0] = 사람
var tickets := 0
var lowered_this_round := false
var history: Array = []          # 라운드별 결과
var last_result: Dictionary
var best_record := 0
var human_ratings: Dictionary = {}
var mouse_sens := 1.0           # 설정: 마우스 감도
var volume := 0.8               # 설정: 음량 (0~1)

var main: Node


func _ready() -> void:
	rng.randomize()
	_load_settings()
	Data.load_fonts()
	_load_record()
	autotest = "--autotest" in OS.get_cmdline_user_args()


func t_collect() -> float:
	return 4.0 if autotest else (100.0 if short_mode else 180.0)


func t_build() -> float:
	if practice and not autotest:
		return 600.0
	return 2.0 if autotest else (150.0 if short_mode else 270.0)


func t_exhibit() -> float:
	return 0.6 if autotest else (6.0 if short_mode else 10.0)


## 조립만 해 보기: 무작위 장소 · 물건, 모두에게 덩어리 꾸러미를 주고 조립부터
func new_practice() -> void:
	new_game()
	practice = true
	theme = Themes.ORDER[rng.randi() % Themes.ORDER.size()]
	var tpls := Themes.targets_for(theme)
	target = tpls[rng.randi() % tpls.size()]
	for p in players:
		var inv: Array = p["inventory"]
		for t in Data.TYPES:
			for k in 2:
				inv.append(Themes.make_part(theme, t, rng))
		for k in 4:
			inv.append(Themes.make_part(theme, Data.TYPES[rng.randi() % Data.TYPES.size()], rng))


func new_game() -> void:
	practice = false
	round_i = 1
	tickets = 0
	history = []
	players = []
	var me := {"name": "나", "is_bot": false, "color": 6, "quality": 0.0, "bias": 0.0}
	players.append(me)
	var bot_order := Data.BOTS.duplicate()
	for b in bot_order:
		players.append({"name": b[0], "is_bot": true, "color": b[1],
			"quality": rng.randf_range(0.5, 0.95), "bias": rng.randf_range(-0.07, 0.07)})
	_setup_round()


func _setup_round() -> void:
	theme = Themes.ORDER[(round_i - 1) % Themes.ORDER.size()]
	var ft := ""
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--theme="):
			ft = s.substr(8)
	if ft != "":
		theme = ft   # 테스트: 특정 공간으로 바로
	var tpls := Themes.targets_for(theme)
	var prev: String = target.get("name", "") if target else ""
	var pick: Dictionary = tpls[rng.randi() % tpls.size()]
	while pick["name"] == prev:
		pick = tpls[rng.randi() % tpls.size()]
	target = pick
	formation = Data.pick_formation(round_i, rng)
	counts = Data.formation_counts(formation, PLAYERS, rng)
	quota = Data.QUOTA[mini(round_i, Data.QUOTA.size()) - 1].duplicate()
	lowered_this_round = false
	human_ratings = {}
	var cards := Data.cards()
	for p in players:
		p["inventory"] = []
		p["envelopes"] = []
		p["hunt"] = {"gold": 0, "hidden": 0, "up": 0, "found": 0}
		p["work"] = []
		p["edits"] = 0
		p["card"] = cards[rng.randi() % cards.size()]


func next_round() -> void:
	round_i += 1
	_setup_round()


## 전체 등수: 라운드 평점 합계 (높은 순). [{"i", "total", "per": [라운드별]}]
func standings() -> Array:
	var rows := []
	for i in players.size():
		var per := []
		var tot := 0.0
		for rec in history:
			var v: float = rec["avg"][i]
			if rec.get("cards", []).size() > i and rec["cards"][i]:
				v += CARD_BONUS   # 카드 성공 보너스
			per.append(v)
			tot += v
		rows.append({"i": i, "total": tot, "per": per})
	rows.sort_custom(func(a, b): return a["total"] > b["total"])
	return rows


## 라운드 1등 작품 (평점 최고)
static func round_top(rec: Dictionary) -> int:
	var avg: Array = rec["avg"]
	var best := 0
	for i in avg.size():
		if avg[i] > avg[best]:
			best = i
	return best


func human() -> Dictionary:
	return players[0]


## 티켓 3장으로 이번 라운드 할당량을 한 단계 낮춘다 (방 전체 공유, 라운드당 1회)
func lower_quota() -> bool:
	if tickets < 3 or lowered_this_round:
		return false
	tickets -= 3
	lowered_this_round = true
	var idx := mini(round_i, Data.QUOTA.size()) - 2
	quota = Data.QUOTA[idx].duplicate() if idx >= 0 else [quota[0] - 0.4, quota[1]]
	return true


func goto(phase: String) -> void:
	phase_changed.emit(phase)
	if main:
		main.goto(phase)


func save_record(reached: int) -> void:
	if reached > best_record:
		best_record = reached
		var f := FileAccess.open("user://record.json", FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify({"best": best_record}))


func _load_record() -> void:
	if FileAccess.file_exists("user://record.json"):
		var f := FileAccess.open("user://record.json", FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			best_record = int(d.get("best", 0))


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
	var f := FileAccess.open("user://settings.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"sens": mouse_sens, "vol": volume}))


func _load_settings() -> void:
	if FileAccess.file_exists("user://settings.json"):
		var f := FileAccess.open("user://settings.json", FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			mouse_sens = float(d.get("sens", 1.0))
			volume = float(d.get("vol", 0.8))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
