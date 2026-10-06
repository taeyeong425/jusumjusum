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
	var sub := UI.label("보물을 찾아서, 봉투 속 파츠로 정해진 물건을 만들고, 다 같이 할당량을 넘겨라", 28, UI.SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	col.add_child(Control.new())

	var start := UI.primary("놀이 시작", _start, 36)
	start.custom_minimum_size = Vector2(320, 64)
	col.add_child(_centered(start))

	var short := CheckButton.new()
	short.text = "짧은 모드 (수집 1분 · 조립 2분)"
	short.add_theme_font_size_override("font_size", 22)
	short.button_pressed = Game.short_mode
	short.toggled.connect(func(on): Game.short_mode = on)
	short.focus_mode = Control.FOCUS_NONE
	col.add_child(_centered(short))

	var rec := UI.label("최고 기록: 할당량 통과 %d라운드" % Game.best_record if Game.best_record > 0 else "아직 기록이 없어요", 24, UI.SOFT)
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(rec)
	# 설정: 마우스 감도 · 음량 (저장됨)
	var sets := UI.hbox(16)
	sets.alignment = BoxContainer.ALIGNMENT_CENTER
	for cfg in [["마우스 감도", 0.3, 2.5, Game.mouse_sens, "sens"], ["음량", 0.0, 1.0, Game.volume, "vol"]]:
		sets.add_child(UI.label(cfg[0], 20, UI.SOFT))
		var sl := HSlider.new()
		sl.min_value = cfg[1]
		sl.max_value = cfg[2]
		sl.step = 0.05
		sl.value = cfg[3]
		sl.custom_minimum_size = Vector2(160, 24)
		var key: String = cfg[4]
		sl.value_changed.connect(func(v: float):
			if key == "sens":
				Game.mouse_sens = v
			else:
				Game.volume = v
			Game.apply_settings())
		sets.add_child(sl)
	col.add_child(sets)

	var help := UI.panel()
	var hv := UI.vbox(4)
	help.add_child(hv)
	hv.add_child(UI.label("이렇게 놀아요", 26, UI.INK, true))
	for line in [
		"1. 라운드마다 공간이 바뀝니다 — 학교 → 미술관 → 해적선. 만들 물건(타겟)이 먼저 공개돼요",
		"2. 보물찾기 2:30 — 쪽지 · 편지봉투 · 금봉투를 찾아요 (6명이면 90개). 서랍 · 사물함 · 술통 · 액자를 열면 숨은 봉투!\n   마우스로 둘러보고 조준점 + [F] · [Tab] 근처 목록 · 계단과 사다리로 위층까지. 먼저 줍는 사람이 임자",
		"3. 조립 시작 때 봉투 개봉식 — 봉투 속 파츠로 타겟을 만들어요 (색 고리 = 회전 · 색 네모 = 늘이기)",
		"4. 전원의 작품을 돌려보며 별을 끌어 0~5점을 매깁니다 (←/→ 0.1씩, 4.6 이상은 한 작품만)",
		"5. 무조건 3라운드! 라운드마다 할당량 통과를 노리고, 끝나면 평점 합계로 전체 등수가 나와요",
		"   ※ 지금은 프로토타입이라 나머지 5명은 봇입니다",
	]:
		hv.add_child(UI.label(line, 21, UI.SOFT))
	col.add_child(help)

	var credit := UI.label("프로토타입 v0.6 (보물찾기) · Godot 4.7 · 폰트 나눔고딕 (OFL) · 효과음 Kenney (CC0)", 18, Color(UI.SOFT, 0.7))
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(credit)


func _centered(c: Control) -> Control:
	var cc := CenterContainer.new()
	cc.add_child(c)
	return cc


func _start() -> void:
	Game.new_game()
	Game.goto("reveal")
