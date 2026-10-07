extends Node
## 공개: 타겟 · 편성 · 할당량 · 내 카드 (0:20)

var left := 20.0
var timer_label: Label


var model: Node3D


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
	var th: Dictionary = Themes.INFO[Game.theme]
	top.add_child(UI.label("%d / 3 라운드" % Game.round_i, 26, Color(chalk, 0.75), true))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	timer_label = UI.label("", 30, Color(chalk, 0.8))
	top.add_child(timer_label)

	var pre := UI.label("이번에 만들 물건", 26, Color(chalk, 0.7))
	pre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(pre)
	var tgt := UI.label(str(Game.target["name"]), 92, chalk, true)
	tgt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tgt)
	var how := UI.label("%s에서 봉투를 모아 오세요. 봉투 속 덩어리가 재료가 돼요" % th["name"], 24, Color(chalk, 0.8))
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size.x = 900
	col.add_child(how)

	var row := UI.hbox(24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)

	# 만들 것 견본 (3D, 천천히 돈다)
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(280, 280)
	svc.stretch = true
	row.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	svc.add_child(sv)
	var w3 := Node3D.new()
	sv.add_child(w3)
	UI.make_env(w3, Color(0, 0, 0, 0))
	var inv := []
	for t in Data.TYPES:
		for v in Data.VARIANTS[t]:
			inv.append(Data.make_item(t, v[1], 0, "auto"))
	model = Node3D.new()
	w3.add_child(model)
	var mrng := RandomNumberGenerator.new()
	mrng.seed = 7
	for d in BotBuilder.build(Game.target, inv, 1.0, mrng):
		model.add_child(Piece.from_dict(d, false))
	var mcam := Camera3D.new()
	mcam.fov = 40
	w3.add_child(mcam)
	mcam.look_at_from_position(Vector3(0, 1.3, 3.0), Vector3(0, 0.6, 0))
	mcam.current = true
	var ml := DirectionalLight3D.new()
	ml.rotation_degrees = Vector3(-40, 30, 0)
	w3.add_child(ml)

	# 편성
	var fp := UI.panel()
	fp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fp)
	var fv := UI.vbox(6)
	fp.add_child(fv)
	fp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	fv.add_child(UI.label("재료 · %s" % Game.formation, 26, UI.INK, true))
	fv.add_child(UI.label(Data.FORMATIONS[Game.formation], 19, UI.SOFT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	fv.add_child(grid)
	var mx := 1
	for t in Data.TYPES:
		mx = maxi(mx, Game.counts[t])
	for t in Data.TYPES:
		var h := UI.hbox(8)
		var n := UI.label(Data.NAMES[t], 19)
		n.custom_minimum_size.x = 70
		h.add_child(n)
		var bar := ColorRect.new()
		var c: int = Game.counts[t]
		bar.custom_minimum_size = Vector2(maxf(4.0, 160.0 * c / mx), 18)
		bar.color = UI.BAD if c <= 3 else (UI.ACCENT if c >= 40 else Color("#9AA5AF"))
		h.add_child(bar)
		h.add_child(UI.label(str(c), 18, UI.SOFT))
		grid.add_child(h)

	# 할당량 + 카드
	var rp := UI.vbox(16)
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rp)
	var qp := UI.panel()
	rp.add_child(qp)
	var qv := UI.vbox(4)
	qp.add_child(qv)
	qv.add_child(UI.label("통과 조건", 20, UI.SOFT))
	qv.add_child(UI.label("★%.1f 이상 %d명" % [Game.quota[0], Game.quota[1]], 40, UI.INK, true))
	qv.add_child(UI.label("6명 중 %d명이 별점 %.1f을 넘기면 통과" % [Game.quota[1], Game.quota[0]], 19, UI.SOFT))

	var card: Dictionary = Game.human()["card"]
	var cp := UI.panel()
	rp.add_child(cp)
	var cv := UI.vbox(4)
	cp.add_child(cv)
	cv.add_child(UI.label("내 비밀 카드", 20, UI.SOFT))
	cv.add_child(UI.label(str(card["name"]), 34, UI.ACCENT, true))
	cv.add_child(UI.label(str(card["desc"]), 21))
	cv.add_child(UI.label("성공하면 +0.5점 · 티켓 %d / 3" % Game.tickets, 19, UI.SOFT))

	var go := UI.primary("보물찾기 시작", _go, 30)
	go.custom_minimum_size = Vector2(280, 0)
	var gr := UI.hbox(12)
	gr.alignment = BoxContainer.ALIGNMENT_CENTER
	gr.add_child(go)
	gr.add_child(UI.keycap("Enter", 18))
	col.add_child(gr)


func _process(delta: float) -> void:
	if model:
		model.rotation.y += delta * 0.7
	left -= delta * (40.0 if Game.autotest else 1.0)
	timer_label.text = UI.clock(left)
	if left <= 0:
		_go()


func _go() -> void:
	set_process(false)
	Game.goto("collect")


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_go()
