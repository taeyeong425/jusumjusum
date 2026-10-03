extends Node
## 정산 — 할당량 판정 · 카드 · 티켓 · 부문상 (§11.4: 기준선을 긋는 연출이 핵심)

var result: Dictionary
var verdict: Dictionary
var chart: Control
var reveal_t := 0.0
var verdict_l: Label
var detail_l: Label
var stand_l: Label
var buttons: HBoxContainer
var shown := false


func _ready() -> void:
	result = Judge.rate_round(Game.players, Game.target, Game.human_ratings, Game.rng)
	verdict = Judge.quota_pass(result["avg"], Game.quota)
	var avg: Array = result["avg"]
	# 카드 · 티켓
	var me: Dictionary = Game.human()
	var card: Dictionary = me["card"]
	var c_ok := Judge.card_constraint(card, me["work"], me["inventory"].size())
	var r_ok := Judge.card_rank_ok(card["rank"], 0, avg)
	me["card_done"] = c_ok and r_ok
	var gained := 0
	if me["card_done"]:
		gained += 1
	for i in range(1, Game.players.size()):
		var p: Dictionary = Game.players[i]
		p["card_done"] = Game.rng.randf() < 0.3 and Judge.card_rank_ok(p["card"]["rank"], i, avg)
		if p["card_done"]:
			gained += 1
	Game.tickets += gained
	result["gained"] = gained
	result["awards"] = Judge.awards(Game.players, result["ratings"])
	_build_ui(c_ok, r_ok)


func _build_ui(c_ok: bool, r_ok: bool) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = UI.CHALK
	layer.add_child(UI.full(bg))
	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 32)
	layer.add_child(UI.full(margin))
	var col := UI.vbox(12)
	margin.add_child(col)
	var chalk := Color("#F4F1E6")
	col.add_child(UI.label("%d라운드 정산 · 「%s」 · 할당량 ★%.1f 이상 %d명" % [Game.round_i, Game.target["name"], Game.quota[0], Game.quota[1]], 30, chalk, true))

	chart = Control.new()
	chart.custom_minimum_size = Vector2(0, 300)
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.draw.connect(_draw_chart)
	col.add_child(chart)

	verdict_l = UI.label("", 52, chalk, true)
	verdict_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(verdict_l)

	var row := UI.hbox(18)
	col.add_child(row)
	var cp := UI.panel()
	cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cp)
	var cv := UI.vbox(2)
	cp.add_child(cv)
	var card: Dictionary = Game.human()["card"]
	cv.add_child(UI.label("내 카드 「%s」" % card["name"], 24, UI.INK, true))
	cv.add_child(UI.label("제약 (%s): %s" % [card["desc"], "달성" if c_ok else "미달"], 20, UI.GOOD if c_ok else UI.BAD))
	cv.add_child(UI.label("성적 (%s): %s" % [Data.rank_text(card["rank"]), "달성" if r_ok else "미달"], 20, UI.GOOD if r_ok else UI.BAD))
	cv.add_child(UI.label("이번 라운드 티켓 +%d → 방 전체 %d장" % [result["gained"], Game.tickets], 20, UI.SOFT))

	var ap := UI.panel()
	ap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ap)
	var av := UI.vbox(0)
	ap.add_child(av)
	av.add_child(UI.label("부문상 (점수 없음)", 24, UI.INK, true))
	var letters: Dictionary = Game.get_meta("letters")
	for a in result["awards"]:
		var who: int = a["who"]
		var nm := "내 작품" if who == 0 else "작품 %s" % letters[who]
		av.add_child(UI.label("%s — %s" % [nm, a["name"]], 19, UI.ACCENT if who == 0 else UI.SOFT))

	detail_l = UI.label("", 20, Color(chalk, 0.75))
	col.add_child(detail_l)
	stand_l = UI.label("", 22, Color("#FFE08A"), true)
	stand_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(stand_l)
	buttons = UI.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.visible = false
	col.add_child(buttons)


func _process(delta: float) -> void:
	reveal_t += delta * (20.0 if Game.autotest else 1.0)
	chart.queue_redraw()
	if reveal_t > 2.6 and not shown:
		shown = true
		_show_verdict()
	if Game.autotest and shown and reveal_t > 4.0:
		set_process(false)
		if Game.round_i < Game.ROUNDS:
			_next_round()
		else:
			_to_gallery()


func _show_verdict() -> void:
	var v := verdict
	if v["pass"]:
		verdict_l.text = "통과!  %d명 / %d명 필요" % [v["got"], v["need"]]
		verdict_l.add_theme_color_override("font_color", Color("#BFE3A0"))
	else:
		verdict_l.text = "아깝다…  %d명 / %d명 필요" % [v["got"], v["need"]]
		verdict_l.add_theme_color_override("font_color", Color("#F2A7B5"))
	var me_avg: float = result["avg"][0]
	detail_l.text = "내 작품 평점 ★%.1f (봇이 본 닮음 %.0f%%) · 이번 판 기록 %d라운드" % [me_avg, result["scores"][0] * 100, Game.round_i]
	for c in buttons.get_children():
		c.queue_free()
	if not v["pass"] and Game.tickets >= 3 and not Game.lowered_this_round:
		buttons.add_child(UI.button("티켓 3장으로 할당량 한 단계 낮추기", _lower, 24))
	if Game.round_i < Game.ROUNDS:
		buttons.add_child(UI.button("다음 라운드 (%d / %d) →" % [Game.round_i + 1, Game.ROUNDS], _next_round, 30))
	else:
		buttons.add_child(UI.button("최종 결과 · 전시회 보러 가기 →", _to_gallery, 28))
	buttons.visible = true
	_store_history()
	_show_standings()


## 지금까지 전체 등수 (라운드 평점 합계)
func _show_standings() -> void:
	var letters: Dictionary = Game.get_meta("letters")
	var parts := []
	var rank := 0
	for row in Game.standings():
		rank += 1
		var i: int = row["i"]
		var nm: String = "나" if i == 0 else Game.players[i]["name"]
		parts.append(("%d등 %s %.1f" % [rank, nm, row["total"]]) if i != 0 else ("[%d등 나 %.1f]" % [rank, row["total"]]))
	stand_l.text = "전체 등수 (%d라운드 합계)  " % Game.history.size() + "  ·  ".join(parts)


func _store_history() -> void:
	var works := []
	for p in Game.players:
		works.append(p["work"])
	var rec := {"round": Game.round_i, "target": Game.target["name"], "works": works,
		"avg": result["avg"], "pass": verdict["pass"]}
	if Game.history.size() >= Game.round_i:
		Game.history[Game.round_i - 1] = rec
	else:
		Game.history.append(rec)


func _lower() -> void:
	if Game.lower_quota():
		verdict = Judge.quota_pass(result["avg"], Game.quota)
		reveal_t = 0.0
		shown = false
		buttons.visible = false


func _next_round() -> void:
	Game.save_record(Game.round_i + 1)
	Game.next_round()
	Game.goto("reveal")


func _to_gallery() -> void:
	var passed := 0
	for rec in Game.history:
		if rec["pass"]:
			passed += 1
	Game.set_meta("reached", passed)
	Game.save_record(passed)
	Game.goto("gallery")


## 막대 = 브릭을 쌓은 탑 (0.5점 = 브릭 한 칸, 맨 위에 스터드)
func _brick_tower(r: Rect2, col: Color, step: float) -> void:
	if r.size.y <= 0.5:
		return
	var y := r.end.y
	var k := 0
	while y > r.position.y + 0.5:
		var h := minf(step, y - r.position.y)
		var br := Rect2(r.position.x, y - h, r.size.x, h)
		chart.draw_rect(br, col.darkened(0.04 * (k % 2)))
		chart.draw_rect(Rect2(br.position.x, br.end.y - 3, br.size.x, 3), col.darkened(0.25))
		y -= h
		k += 1
	var n := maxi(2, int(r.size.x / 26))
	for s in n:
		var cx := r.position.x + r.size.x * (s + 0.5) / n
		chart.draw_rect(Rect2(cx - 8, r.position.y - 6, 16, 6), col.lightened(0.12))
		chart.draw_rect(Rect2(cx - 8, r.position.y - 6, 16, 6), col.darkened(0.25), false, 1.0)


func _draw_chart() -> void:
	var avg: Array = result["avg"]
	var sz := chart.size
	var n := avg.size()
	var letters: Dictionary = Game.get_meta("letters")
	# 높은 순으로 줄 세운다
	var idx := range(n)
	idx.sort_custom(func(a, b): return avg[a] > avg[b])
	var slot := sz.x / n
	var bw := slot * 0.62
	var base_y := sz.y - 40
	var scale_y := (sz.y - 70) / 5.0
	var grow := clampf(reveal_t / 1.2, 0.0, 1.0)
	var font := Data.font_bold
	for k in n:
		var i: int = idx[k]
		var x := k * slot + slot * 0.19
		var hgt: float = avg[i] * scale_y * grow
		var passed: bool = avg[i] >= verdict["th"] - 0.0001
		var col := Color("#4B9F4A") if passed else Color("#A0A5A9")
		if i == 0:
			col = Color("#F2CD37") if passed else Color("#E4CD9E")
		_brick_tower(Rect2(x, base_y - hgt, bw, hgt), col, scale_y * 0.5)
		var nm: String = "내 것" if i == 0 else letters.get(i, "?")
		chart.draw_string(font, Vector2(x, base_y + 30), nm, HORIZONTAL_ALIGNMENT_CENTER, bw, 26, Color("#F4F1E6"))
		chart.draw_string(font, Vector2(x, base_y - hgt - 8), "★%.1f" % avg[i], HORIZONTAL_ALIGNMENT_CENTER, bw, 24, Color("#F4F1E6"))
		if k == 0 and grow >= 1.0:
			chart.draw_string(font, Vector2(x, base_y - hgt - 38), "1등", HORIZONTAL_ALIGNMENT_CENTER, bw, 26, Color("#FFD34D"))
	# 기준선 — 1.2초 뒤에 그어진다
	if reveal_t > 1.2:
		var ly: float = base_y - verdict["th"] * scale_y
		var w := sz.x * clampf((reveal_t - 1.2) / 0.8, 0.0, 1.0)
		chart.draw_line(Vector2(0, ly), Vector2(w, ly), Color("#E07A5F"), 4.0)
		chart.draw_string(font, Vector2(4, ly - 8), "★%.1f" % verdict["th"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#E07A5F"))
