extends Node3D
## 전시 · 평가 — 익명 · 랜덤 순서 · 작품당 10초 회전 (§9.1)
## 자기 작품 제외 ★1~5. 평가자당 ★5는 1개만 (§9.2)

const LETTERS := ["A", "B", "C", "D", "E", "F"]

var order: Array = []
var idx := 0
var t := 0.0
var per := 10.0
var pivot: Node3D
var cam: Camera3D
var title: Label
var sub: Label
var timer_l: Label
var star_row: HBoxContainer
var star_btns: Array = []
var five_l: Label
var done := false


func _ready() -> void:
	per = Game.t_exhibit()
	for i in Game.players.size():
		order.append(i)
	order.shuffle()
	Game.set_meta("letters", {})
	var letters := {}
	for k in order.size():
		letters[order[k]] = LETTERS[k]
	Game.set_meta("letters", letters)
	UI.make_env(self, Color("#F2E6D0"))
	var ped := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.5; cm.bottom_radius = 1.6; cm.height = 0.4
	ped.mesh = cm
	ped.position.y = -0.2
	ped.material_override = Data.flat_material(Color("#FFFFFF"))
	add_child(ped)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(40, 40)
	fl.mesh = pm
	fl.position.y = -0.4
	fl.material_override = Data.flat_material(Color("#D8C3A0"))
	add_child(fl)
	pivot = Node3D.new()
	add_child(pivot)
	cam = Camera3D.new()
	cam.fov = 45
	add_child(cam)
	cam.position = Vector3(0, 1.9, 4.6)
	cam.look_at(Vector3(0, 0.6, 0))
	_build_hud()
	_show(0)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := UI.panel()
	var tv := UI.vbox(2)
	top.add_child(tv)
	title = UI.label("", 40, UI.INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(title)
	sub = UI.label("", 22, UI.SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(sub)
	layer.add_child(top)
	UI.corner(top, Control.PRESET_CENTER_TOP, Vector2(0, 14))

	var bottom := UI.panel()
	var bv := UI.vbox(6)
	bottom.add_child(bv)
	star_row = UI.hbox(8)
	bv.add_child(star_row)
	for s in range(1, 6):
		var stars := s
		var b := UI.button(UI.stars(s), func(): _rate(stars), 26)
		b.toggle_mode = true
		star_row.add_child(b)
		star_btns.append(b)
	five_l = UI.label("", 20, UI.SOFT)
	five_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(five_l)
	var h := UI.hbox(12)
	bv.add_child(h)
	timer_l = UI.label("", 24, UI.SOFT)
	h.add_child(timer_l)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(UI.button("다음 작품 →", _next, 22))
	layer.add_child(bottom)
	UI.corner(bottom, Control.PRESET_CENTER_BOTTOM, Vector2(0, 16))


func _show(k: int) -> void:
	idx = k
	t = per
	for c in pivot.get_children():
		c.queue_free()
	var who: int = order[k]
	for d in Game.players[who]["work"]:
		pivot.add_child(Piece.from_dict(d, false))
	pivot.rotation.y = 0
	var letter: String = Game.get_meta("letters")[who]
	title.text = "작품 %s  (%d / %d)" % [letter, k + 1, order.size()]
	var mine := who == 0
	sub.text = ("내 작품이에요 — 평가는 안 해요" if mine else "「%s」처럼 보이나요?" % Game.target["name"])
	star_row.visible = not mine
	_refresh_stars()


func _refresh_stars() -> void:
	var who: int = order[idx]
	var cur: int = Game.human_ratings.get(who, 0)
	var five_used := false
	for w in Game.human_ratings:
		if Game.human_ratings[w] == 5 and w != who:
			five_used = true
	for s in range(1, 6):
		var b: Button = star_btns[s - 1]
		b.set_pressed_no_signal(cur == s)
		b.disabled = s == 5 and five_used
	five_l.text = "★5는 한 번만 줄 수 있어요 — 이미 썼어요" if five_used else "★5는 한 번만 줄 수 있어요"


func _rate(s: int) -> void:
	Game.human_ratings[order[idx]] = s
	_refresh_stars()


func _process(delta: float) -> void:
	if done:
		return
	pivot.rotation.y += delta * TAU / maxf(per, 0.1)
	t -= delta
	timer_l.text = "%d초" % ceili(maxf(t, 0))
	if Game.autotest:
		var who: int = order[idx]
		if who != 0 and not Game.human_ratings.has(who):
			_rate(Game.rng.randi_range(2, 4))
	if t <= 0:
		_next()


func _next() -> void:
	if done:
		return
	if idx + 1 < order.size():
		_show(idx + 1)
	else:
		done = true
		for w in Game.players.size():
			if w != 0 and not Game.human_ratings.has(w):
				Game.human_ratings[w] = 3
		Game.goto("settle")
