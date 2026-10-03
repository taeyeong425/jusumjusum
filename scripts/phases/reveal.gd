extends Node
## 공개: 타겟 · 편성 · 할당량 · 내 카드 (0:20)

var left := 20.0
var timer_label: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = UI.CHALK
	layer.add_child(UI.full(bg))

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	layer.add_child(UI.full(margin))
	var col := UI.vbox(16)
	margin.add_child(col)

	var chalk := Color("#F4F1E6")
	var top := UI.hbox(20)
	col.add_child(top)
	top.add_child(UI.label("%d라운드 · 오늘의 과제" % Game.round_i, 34, Color(chalk, 0.8)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	timer_label = UI.label("", 30, Color(chalk, 0.8))
	top.add_child(timer_label)

	var tgt := UI.label("「%s」를 만들어라" % Game.target["name"], 88, chalk, true)
	tgt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tgt)

	var row := UI.hbox(24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)

	# 편성
	var fp := UI.panel()
	fp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fp)
	var fv := UI.vbox(6)
	fp.add_child(fv)
	fv.add_child(UI.label("이번 판 재료: %s" % Game.formation, 30, UI.INK, true))
	fv.add_child(UI.label(Data.FORMATIONS[Game.formation], 22, UI.SOFT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	fv.add_child(grid)
	var mx := 1
	for t in Data.TYPES:
		mx = maxi(mx, Game.counts[t])
	for t in Data.TYPES:
		var h := UI.hbox(8)
		var n := UI.label(Data.NAMES[t], 22)
		n.custom_minimum_size.x = 70
		h.add_child(n)
		var bar := ColorRect.new()
		var c: int = Game.counts[t]
		bar.custom_minimum_size = Vector2(maxf(4.0, 160.0 * c / mx), 18)
		bar.color = UI.BAD if c <= 3 else (UI.ACCENT if c >= 40 else Color("#C9A27A"))
		h.add_child(bar)
		h.add_child(UI.label(str(c), 20, UI.SOFT))
		grid.add_child(h)

	# 할당량 + 카드
	var rp := UI.vbox(16)
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rp)
	var qp := UI.panel()
	rp.add_child(qp)
	var qv := UI.vbox(4)
	qp.add_child(qv)
	qv.add_child(UI.label("할당량", 26, UI.SOFT))
	qv.add_child(UI.label("★%.1f 이상이 %d명" % [Game.quota[0], Game.quota[1]], 44, UI.INK, true))
	qv.add_child(UI.label("6명 중 %d명이 넘으면 다 같이 다음 라운드로" % Game.quota[1], 22, UI.SOFT))

	var card: Dictionary = Game.human()["card"]
	var cp := UI.panel()
	rp.add_child(cp)
	var cv := UI.vbox(4)
	cp.add_child(cv)
	cv.add_child(UI.label("내 비밀 카드", 26, UI.SOFT))
	cv.add_child(UI.label("「%s」" % card["name"], 38, UI.ACCENT, true))
	cv.add_child(UI.label("%s + %s" % [card["desc"], Data.rank_text(card["rank"])], 24))
	cv.add_child(UI.label("달성하면 티켓 1장. 티켓 3장 = 할당량 한 단계 낮추기", 20, UI.SOFT))
	cv.add_child(UI.label("방 전체 티켓: %d장" % Game.tickets, 22, UI.SOFT))

	var go := UI.button("놀이터로 →", _go, 32)
	var cc := CenterContainer.new()
	cc.add_child(go)
	col.add_child(cc)


func _process(delta: float) -> void:
	left -= delta * (40.0 if Game.autotest else 1.0)
	timer_label.text = UI.clock(left)
	if left <= 0:
		_go()


func _go() -> void:
	set_process(false)
	Game.goto("collect")
