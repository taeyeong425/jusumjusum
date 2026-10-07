extends Node
## 타이틀 화면


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("#EAF2F7")
	layer.add_child(UI.full(bg))

	var center := CenterContainer.new()
	layer.add_child(UI.full(center))
	var col := UI.vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	var title := UI.label("주섬주섬", 112, UI.INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := UI.label("보물을 모아 작품을 만들고, 다 같이 전시회를 통과하세요", 28, UI.SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	col.add_child(Control.new())

	var start := UI.primary("시작하기", _start, 34)
	start.custom_minimum_size = Vector2(300, 64)
	col.add_child(_centered(start))

	var opts := UI.hbox(28)
	opts.alignment = BoxContainer.ALIGNMENT_CENTER
	var short := CheckButton.new()
	short.text = "짧은 판"
	short.tooltip_text = "보물찾기 1분 · 조립 2분"
	short.add_theme_font_size_override("font_size", 18)
	short.button_pressed = Game.short_mode
	short.toggled.connect(func(on): Game.short_mode = on)
	short.focus_mode = Control.FOCUS_NONE
	opts.add_child(short)
	# 설정: 마우스 감도 · 음량 (저장됨)
	for cfg in [["감도", 0.3, 2.5, Game.mouse_sens, "sens"], ["음량", 0.0, 1.0, Game.volume, "vol"]]:
		var it := UI.hbox(8)
		it.add_child(UI.label(cfg[0], 20, UI.SOFT))
		var sl := HSlider.new()
		sl.min_value = cfg[1]
		sl.max_value = cfg[2]
		sl.step = 0.05
		sl.value = cfg[3]
		sl.custom_minimum_size = Vector2(130, 24)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var key: String = cfg[4]
		sl.value_changed.connect(func(v: float):
			if key == "sens":
				Game.mouse_sens = v
			else:
				Game.volume = v
			Game.apply_settings())
		it.add_child(sl)
		opts.add_child(it)
	col.add_child(opts)
	if Game.best_record > 0:
		var rec := UI.label("최고 기록  %d라운드 통과" % Game.best_record, 20, UI.SOFT)
		rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(rec)
	col.add_child(Control.new())

	# 한 판의 흐름: 세 단계 카드
	var steps := UI.hbox(14)
	steps.alignment = BoxContainer.ALIGNMENT_CENTER
	for st in [
		["1", "보물찾기", "학교 · 미술관 · 해적선을 돌며\n서랍과 상자 속 봉투를 모아요"],
		["2", "조립", "봉투를 열어 나온 덩어리로\n제시된 물건을 만들어요"],
		["3", "전시 · 평가", "서로의 작품에 별점을 주고\n할당량을 넘기면 통과예요"],
	]:
		var card := UI.panel()
		card.custom_minimum_size = Vector2(250, 0)
		var cv := UI.vbox(6)
		card.add_child(cv)
		var head := UI.hbox(10)
		var num := UI.label(st[0], 22, UI.ACCENT, true)
		head.add_child(num)
		head.add_child(UI.label(st[1], 24, UI.INK, true))
		cv.add_child(head)
		cv.add_child(UI.label(st[2], 19, UI.SOFT))
		steps.add_child(card)
	col.add_child(steps)
	var foot := UI.label("3라운드 · 함께하는 5명은 봇이에요", 18, Color(UI.SOFT, 0.8))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(foot)

	var credit := UI.label("v0.6.4 · Godot · Pretendard (OFL) · Kenney 효과음 (CC0)", 18, Color(UI.SOFT, 0.55))
	layer.add_child(credit)
	UI.corner(credit, Control.PRESET_BOTTOM_RIGHT, Vector2(16, 10))


func _centered(c: Control) -> Control:
	var cc := CenterContainer.new()
	cc.add_child(c)
	return cc


func _start() -> void:
	Game.new_game()
	Game.goto("reveal")
