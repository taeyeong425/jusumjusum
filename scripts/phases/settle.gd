extends Node
## 정산 — 할당량 판정 · 카드 · 티켓 · 부문상 (§11.4: 기준선을 긋는 연출이 핵심)

var result: Dictionary
var verdict: Dictionary
var chart: Control
var reveal_t := 0.0
var verdict_l: Label
var detail_l: Label
var stand_l: Label
var stand_grid: GridContainer
var button_bar: PanelContainer
var primary: Button
var buttons: HBoxContainer
var shown := false


func _ready() -> void:
	result = Judge.rate_round(Game.players, Game.target, Game.human_ratings, Game.rng)
	verdict = Judge.quota_pass(result["avg"], Game.quota)
	var avg: Array = result["avg"]
	# 카드 · 티켓
	var me: Dictionary = Game.human()
	var card: Dictionary = me["card"]
	var c_ok := Judge.card_constraint(card, me["work"], me["inventory"].size(), me.get("hunt", {}))
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
	for s in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + s, 28)
	margin.add_theme_constant_override("margin_bottom", 96)   # 아래 버튼 줄 자리
	layer.add_child(UI.full(margin))
	var col := UI.vbox(10)
	margin.add_child(col)
	var chalk := Color("#F4F6F8")
	var hd := UI.hbox(16)
	col.add_child(hd)
	hd.add_child(UI.label("%d / %d 라운드 결과" % [Game.round_i, Game.ROUNDS], 32, chalk, true))
	var hs := UI.label("%s  ·  ★%.1f 이상 %d명이면 통과" % [Game.target["name"], Game.quota[0], Game.quota[1]], 20, Color(chalk, 0.65))
	hs.size_flags_vertical = Control.SIZE_SHRINK_END
	hd.add_child(hs)

	var main := UI.hbox(20)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(main)
	var left := UI.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(left)
	chart = Control.new()
	chart.custom_minimum_size = Vector2(0, 200)
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.draw.connect(_draw_chart)
	left.add_child(chart)
	verdict_l = UI.label("", 40, chalk, true)
	verdict_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(verdict_l)
	stand_l = UI.label("", 18, Color(chalk, 0.6))
	left.add_child(stand_l)
	stand_grid = GridContainer.new()
	stand_grid.columns = 3
	stand_grid.add_theme_constant_override("h_separation", 36)
	stand_grid.add_theme_constant_override("v_separation", 2)
	left.add_child(stand_grid)

	var right := UI.vbox(10)
	right.custom_minimum_size = Vector2(390, 0)
	main.add_child(right)
	# 내 작품 — 평점 · 닮음 · 봇 한마디
	var mp := UI.panel()
	right.add_child(mp)
	var mv := UI.vbox(2)
	mp.add_child(mv)
	detail_l = UI.label("", 22, UI.INK, true)
	mv.add_child(detail_l)
	var names := []
	for i in range(1, Game.players.size()):
		names.append(Game.players[i]["name"])
	names.shuffle()
	var says: Array = Judge.comments(Game.human()["work"], result["scores"][0], Game.target["name"], Game.rng)
	for k in says.size():
		mv.add_child(UI.label("%s  “%s”" % [names[k % names.size()], says[k]], 18, UI.SOFT))
	# 카드 결과 (같은 패널 아래)
	var card: Dictionary = Game.human()["card"]
	var sep := HSeparator.new()
	mv.add_child(sep)
	var ok_c := c_ok and r_ok
	mv.add_child(UI.label("카드 %s  %s" % [card["name"], "성공 +0.5점" if ok_c else "실패"], 19, UI.GOOD if ok_c else UI.SOFT, true))
	mv.add_child(UI.label("티켓 %d / 3 — 3장이면 통과 조건을 낮출 수 있어요" % Game.tickets, 18, UI.SOFT))
	# 부문상 — 내 것 먼저, 나머지는 한 줄씩
	var ap := UI.panel()
	right.add_child(ap)
	var av := UI.vbox(2)
	ap.add_child(av)
	av.add_child(UI.label("부문상", 22, UI.INK, true))
	var letters: Dictionary = Game.get_meta("letters")
	var aw: Array = result["awards"].duplicate()
	aw.sort_custom(func(a, b): return a["who"] == 0 and b["who"] != 0)
	for a in aw:
		var who: int = a["who"]
		var nm := "내 작품" if who == 0 else "작품 %s" % letters[who]
		av.add_child(UI.label("%s   %s" % [a["name"], nm], 18, UI.ACCENT if who == 0 else UI.SOFT, who == 0))

	# 아래 버튼 줄 (화면 밖으로 밀려나지 않게 따로 고정)
	var bp := UI.panel()
	buttons = UI.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	bp.add_child(buttons)
	bp.visible = false
	layer.add_child(bp)
	UI.corner(bp, Control.PRESET_CENTER_BOTTOM, Vector2(0, 14))
	button_bar = bp


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
		verdict_l.text = "통과   %d / %d명" % [v["got"], v["need"]]
		verdict_l.add_theme_color_override("font_color", Color("#BFE3A0"))
	else:
		verdict_l.text = "아깝게 실패   %d / %d명" % [v["got"], v["need"]]
		verdict_l.add_theme_color_override("font_color", Color("#F2A7B5"))
	var me_avg: float = result["avg"][0]
	detail_l.text = "내 작품  ★%.1f   닮음 %.0f%%" % [me_avg, result["scores"][0] * 100]
	for c in buttons.get_children():
		c.queue_free()
	if not v["pass"] and Game.tickets >= 3 and not Game.lowered_this_round:
		buttons.add_child(UI.button("티켓 3장 써서 통과 조건 낮추기", _lower, 22))
	if Game.practice:
		buttons.add_child(UI.button("처음으로", func(): Game.goto("menu"), 22))
		primary = UI.primary("조립 다시 하기", func():
			Game.new_practice()
			Game.goto("build"), 26)
	elif Game.round_i < Game.ROUNDS:
		primary = UI.primary("다음 라운드", _next_round, 26)
	else:
		primary = UI.primary("최종 결과 보기", _to_gallery, 26)
	primary.custom_minimum_size.x = 240
	buttons.add_child(primary)
	buttons.add_child(UI.keycap("Enter", 18))
	button_bar.visible = true
	_store_history()
	_show_standings()


## 지금까지 전체 등수 (라운드 평점 합계)
func _show_standings() -> void:
	var rank := 0
	for row in Game.standings():
		rank += 1
		var i: int = row["i"]
		var nm: String = "나" if i == 0 else Game.players[i]["name"]
		var l := UI.label("%d   %s   ★%.1f" % [rank, nm, row["total"]], 20, Color("#FFD27A") if i == 0 else Color("#F4F6F8", 0.85), i == 0)
		stand_grid.add_child(l)
	stand_l.text = "전체 순위 · %d라운드 합계" % Game.history.size()


## Enter / Space = 다음으로
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		if shown and primary and is_instance_valid(primary):
			primary.pressed.emit()
		elif not shown:
			reveal_t = 2.6   # 연출 건너뛰기


func _store_history() -> void:
	var works := []
	for p in Game.players:
		works.append(p["work"])
	var cards := []
	for p in Game.players:
		cards.append(p.get("card_done", false))
	var titles := []
	for p in Game.players:
		titles.append(p.get("title", "무제"))
	var rec := {"round": Game.round_i, "target": Game.target["name"], "works": works,
		"avg": result["avg"], "pass": verdict["pass"], "cards": cards, "titles": titles, "theme": Game.theme}
	if Game.history.size() >= Game.round_i:
		Game.history[Game.round_i - 1] = rec
	else:
		Game.history.append(rec)


func _lower() -> void:
	if Game.lower_quota():
		verdict = Judge.quota_pass(result["avg"], Game.quota)
		reveal_t = 0.0
		shown = false
		button_bar.visible = false


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


## 막대: 위만 둥근 깔끔한 막대
func _bar_box(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	return sb


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
		chart.draw_style_box(_bar_box(col), Rect2(x, base_y - hgt, bw, maxf(hgt, 1.0)))
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
