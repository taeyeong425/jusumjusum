extends Node
## 타이틀 화면


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	# 하늘색 바닥판 (스터드 무늬)
	var bg := Control.new()
	bg.draw.connect(func():
		bg.draw_rect(Rect2(Vector2.ZERO, bg.size), Color("#9FD3EA"))
		var p := 34.0
		for y in int(bg.size.y / p) + 1:
			for x in int(bg.size.x / p) + 1:
				var c := Vector2(x * p + p * 0.5, y * p + p * 0.5)
				bg.draw_circle(c + Vector2(2, 3), 10, Color("#86BCD6"))
				bg.draw_circle(c, 10, Color("#AEDDF1")))
	layer.add_child(UI.full(bg))

	var center := CenterContainer.new()
	layer.add_child(UI.full(center))
	var col := UI.vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	# 제목: 글자마다 색 브릭
	var title := UI.hbox(10)
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	var cols := ["#C91A09", "#F2CD37", "#0055BF", "#237841"]
	var word := "주섬주섬"
	for k in word.length():
		var tile := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(cols[k])
		sb.set_corner_radius_all(14)
		sb.border_color = Color(cols[k]).darkened(0.3)
		sb.border_width_bottom = 10
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 2
		sb.content_margin_bottom = 4
		tile.add_theme_stylebox_override("panel", sb)
		tile.rotation_degrees = [-4.0, 3.0, -2.0, 4.0][k]
		tile.pivot_offset = Vector2(60, 70)
		var l := UI.label(word[k], 104, Color.WHITE if k != 1 else UI.INK, true)
		tile.add_child(l)
		title.add_child(tile)
	col.add_child(title)
	var sub := UI.label("놀이터를 뜯어서, 정해진 물건을 만들고, 다 같이 할당량을 넘겨라", 28, UI.SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	col.add_child(Control.new())

	var start := UI.button("놀이 시작", _start, 36)
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

	var help := UI.panel()
	var hv := UI.vbox(4)
	help.add_child(hv)
	hv.add_child(UI.label("이렇게 놀아요", 26, UI.INK, true))
	for line in [
		"1. 라운드마다 만들 물건(타겟)과 이번 판 재료 편성이 공개됩니다",
		"2. 마우스로 둘러보다 조준점에 맞춰 [F]/클릭 — 알아서 걸어가 줍고 뜯어요. [Tab] = 근처 목록에서 고르기\n   (미끄럼틀은 계단으로 올라가 타고, 객차·화물칸은 걸어가면 폴짝 올라타요)",
		"3. 작업대에서 덩어리를 쌓고, 크기·회전 손잡이로 다듬어 타겟을 만듭니다\n   (옆면에 대면 딱 붙고, 줄·크기·각도는 자석처럼 맞춰져요 — Alt 누르면 보정 끄기)",
		"4. 전원의 작품을 돌려보며 별을 끌어 0~5점을 매깁니다 (←/→ 0.1씩, 4.6 이상은 한 작품만)",
		"5. 무조건 3라운드! 라운드마다 할당량 통과를 노리고, 끝나면 평점 합계로 전체 등수가 나와요",
		"   ※ 지금은 프로토타입이라 나머지 5명은 봇입니다",
	]:
		hv.add_child(UI.label(line, 21, UI.SOFT))
	col.add_child(help)

	var credit := UI.label("프로토타입 v0.4 · Godot 4.7 · 폰트 Gaegu · 나눔고딕 (OFL) · 효과음 Kenney (CC0)", 18, Color(UI.SOFT, 0.7))
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(credit)


func _centered(c: Control) -> Control:
	var cc := CenterContainer.new()
	cc.add_child(c)
	return cc


func _start() -> void:
	Game.new_game()
	Game.goto("reveal")
