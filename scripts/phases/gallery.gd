extends Node3D
## 판 종료 — 3라운드 작품 전시회 + 전체 등수. 라운드마다 1등 작품엔 금 받침대와 왕관.

var cam: Camera3D
var t := 0.0
var span := 1.0


func _ready() -> void:
	UI.make_env(self, Color("#2A2725"))
	# 전시회장: 어두운 벽 · 나무 바닥 · 작품마다 스포트라이트
	for c in get_children():
		if c is WorldEnvironment:
			(c as WorldEnvironment).environment.ambient_light_energy = 0.3
			(c as WorldEnvironment).environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		if c is DirectionalLight3D:
			(c as DirectionalLight3D).light_energy = 0.25
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(120, 40)
	fl.mesh = pm
	fl.position.x = 30
	var flm := ShaderMaterial.new()
	flm.shader = load("res://assets/shaders/floor.gdshader")
	flm.set_shader_parameter("style", 0)
	flm.set_shader_parameter("col_a", Color("#5A4636"))
	flm.set_shader_parameter("col_b", Color("#4C3B2D"))
	flm.set_shader_parameter("scale", 0.6)
	fl.material_override = flm
	add_child(fl)
	var back := MeshInstance3D.new()
	var bbm := BoxMesh.new(); bbm.size = Vector3(120, 8, 0.2)
	back.mesh = bbm
	back.position = Vector3(30, 4, -3.5)
	back.material_override = Data.brick(Color("#3B3633"), false, 0.25, 0.7)
	add_child(back)
	var letters: Dictionary = Game.get_meta("letters") if Game.has_meta("letters") else {}
	var x := 0.0
	for rec in Game.history:
		var lab := UI.label3d("%d라운드 「%s」 %s" % [rec["round"], rec["target"], "통과" if rec["pass"] else "여기까지"], 44)
		lab.position = Vector3(x + 5.0, 3.4, -1.2)
		add_child(lab)
		var top_i := Game.round_top(rec)
		for i in rec["works"].size():
			var px: float = x + i * 2.0
			var ped := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(1.6, 0.5, 1.6)
			ped.mesh = bm
			ped.position = Vector3(px, 0.25, 0)
			ped.material_override = Data.flat_material(Color("#F4C84A") if i == top_i else (Color("#FFFFFF") if i != 0 else Color("#FFF0C2")))
			add_child(ped)
			var sl := SpotLight3D.new()
			sl.light_color = Color("#FFEFD6")
			sl.light_energy = 2.6 if i == top_i else 1.6
			sl.spot_range = 7.0
			sl.spot_angle = 18.0
			add_child(sl)
			sl.look_at_from_position(Vector3(px, 4.5, 2.0), Vector3(px, 0.8, 0))
			if i == top_i:
				_crown(Vector3(px, 2.95, 0))
				var badge := UI.label3d("1등", 40)
				badge.modulate = Color("#C98A00")
				badge.position = Vector3(px, 0.25, 0.83)
				add_child(badge)
			var holder := Node3D.new()
			holder.position = Vector3(px, 0.5, 0)
			holder.scale = Vector3.ONE * 0.75
			add_child(holder)
			for d in rec["works"][i]:
				holder.add_child(Piece.from_dict(d, false))
			var nm: String = "나" if i == 0 else Game.players[i]["name"]
			var tl: String = str(rec["titles"][i]) if rec.get("titles", []).size() > i else "무제"
			var l := UI.label3d("「%s」\n%s ★%.1f" % [tl, nm, rec["avg"][i]], 24)
			l.position = Vector3(px, 2.35, 0.4)
			add_child(l)
		x += rec["works"].size() * 2.0 + 3.0
	span = maxf(1.0, x - 3.0)
	cam = Camera3D.new()
	cam.fov = 50
	add_child(cam)
	_build_hud()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var p := UI.panel()
	var v := UI.vbox(6)
	p.add_child(v)
	var reached: int = Game.get_meta("reached") if Game.has_meta("reached") else Game.round_i
	v.add_child(UI.label("오늘의 전시회", 40, UI.INK, true))
	v.add_child(UI.label("할당량 통과 %d / %d라운드 · 최고 기록 %d" % [reached, Game.history.size(), Game.best_record], 24, UI.INK))
	v.add_child(UI.label("최종 등수 (3라운드 평점 합계)", 26, UI.INK, true))
	var rank := 0
	for row in Game.standings():
		rank += 1
		var i: int = row["i"]
		var nm: String = "나" if i == 0 else Game.players[i]["name"]
		var per := []
		for s in row["per"]:
			per.append("%.1f" % s)
		var wins := 0
		for rec in Game.history:
			if Game.round_top(rec) == i:
				wins += 1
		var line := "%d등  %s  ★%.1f   (%s)%s" % [rank, nm, row["total"], " + ".join(per), ("   라운드 1등 ×%d" % wins) if wins > 0 else ""]
		var col := UI.ACCENT if i == 0 else (Color("#B07800") if rank == 1 else UI.INK)
		v.add_child(UI.label(line, 24 if rank == 1 else 20, col, rank == 1 or i == 0))
	var h := UI.hbox(12)
	v.add_child(h)
	h.add_child(UI.primary("한 판 더", _again, 26))
	h.add_child(UI.button("처음으로", func(): Game.goto("menu"), 22))
	layer.add_child(p)
	UI.corner(p, Control.PRESET_TOP_LEFT)


## 금 왕관 (덩어리로)
func _crown(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var ring := Piece.new().setup("cylinder", 4, false, Vector3(1.5, 0.35, 1.5))
	ring.set_pscale(Vector3(1.5, 0.35, 1.5), false)
	root.add_child(ring)
	for k in 5:
		var a := TAU * k / 5.0
		var c := Piece.new().setup("cone", 4, false, Vector3(0.6, 1.6, 0.6))
		c.set_pscale(Vector3(0.45, 0.9, 0.45), false)
		c.position = Vector3(cos(a) * 0.3, 0.3, sin(a) * 0.3)
		root.add_child(c)
	var tw := create_tween().set_loops()
	tw.tween_property(root, "rotation:y", TAU, 4.0).from(0.0)


func _process(delta: float) -> void:
	t += delta
	var k := (sin(t * 0.18 - PI / 2) + 1.0) * 0.5
	var target_x := k * span
	cam.position = Vector3(target_x, 3.2, 8.5)
	cam.look_at(Vector3(target_x, 0.9, 0))
	if Game.autotest and t > 0.5:
		print("[autotest] OK — reached %s, history %d" % [str(Game.get_meta("reached")), Game.history.size()])
		get_tree().quit(0)


func _again() -> void:
	Game.new_game()
	Game.goto("reveal")
