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
		var lab := UI.label3d("%d라운드  %s  ·  %s" % [rec["round"], rec["target"], "통과" if rec["pass"] else "실패"], 44)
		lab.position = Vector3(x + rec["works"].size() * 1.3 - 1.3, 3.95, -3.3)
		add_child(lab)
		var top_i := Game.round_top(rec)
		for i in rec["works"].size():
			var px: float = x + i * 2.6
			var top: bool = i == top_i
			# 좌대: 대리석 몸통 + 검은 펠트 윗판 + 바닥 굽
			var ped := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(1.4, 0.9, 1.4)
			ped.mesh = bm
			ped.position = Vector3(px, 0.45, 0)
			ped.material_override = _gold() if top else Data.plain_material(0, false, 1)
			add_child(ped)
			var felt := MeshInstance3D.new()
			var fm := BoxMesh.new(); fm.size = Vector3(1.46, 0.04, 1.46)
			felt.mesh = fm
			felt.position = Vector3(px, 0.92, 0)
			felt.material_override = Data.flat_material(Color("#1E1C1B"))
			add_child(felt)
			var foot := MeshInstance3D.new()
			var ftm := BoxMesh.new(); ftm.size = Vector3(1.5, 0.08, 1.5)
			foot.mesh = ftm
			foot.position = Vector3(px, 0.04, 0)
			foot.material_override = Data.flat_material(Color("#2B2826"))
			add_child(foot)
			var sl := SpotLight3D.new()
			sl.light_color = Color("#FFEFD6")
			sl.light_energy = 3.0 if top else 1.9
			sl.spot_range = 7.0
			sl.spot_angle = 17.0
			add_child(sl)
			sl.look_at_from_position(Vector3(px, 4.6, 1.6), Vector3(px, 1.2, 0))
			# 천장 조명 레일의 등기구
			var can := MeshInstance3D.new()
			var cm := CylinderMesh.new(); cm.top_radius = 0.09; cm.bottom_radius = 0.12; cm.height = 0.3
			can.mesh = cm
			can.position = Vector3(px, 4.7, 1.6)
			can.rotation_degrees.x = 35
			can.material_override = Data.flat_material(Color("#1A1A1A"))
			add_child(can)
			if top:
				_crown(Vector3(px, 2.75, 0))
			var holder := Node3D.new()
			holder.position = Vector3(px, 0.94, 0)
			holder.scale = Vector3.ONE * 0.7
			add_child(holder)
			for d in rec["works"][i]:
				holder.add_child(Piece.from_dict(d, false))
			var nm: String = "나" if i == 0 else Game.players[i]["name"]
			var tl: String = str(rec["titles"][i]) if rec.get("titles", []).size() > i else "무제"
			# 좌대 앞면 황동 명판
			var pl := MeshInstance3D.new()
			var plm := BoxMesh.new(); plm.size = Vector3(1.1, 0.36, 0.02)
			pl.mesh = plm
			pl.position = Vector3(px, 0.6, 0.71)
			pl.material_override = _gold() if top else Data.plain_material(12, false, 2)
			add_child(pl)
			var l := Label3D.new()
			l.font = Data.font_bold
			l.text = "「%s」\n%s · ★%.1f%s" % [tl, nm, rec["avg"][i], "  · 1등" if top else ""]
			l.font_size = 30
			l.pixel_size = 0.003
			l.width = 350
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.modulate = Color("#F7F1E3")
			l.outline_size = 4
			l.outline_modulate = Color(0, 0, 0, 0.6)
			l.position = Vector3(px, 0.6, 0.725)
			add_child(l)
		x += rec["works"].size() * 2.6 + 3.0
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


static var _gold_m: StandardMaterial3D
func _gold() -> StandardMaterial3D:
	if _gold_m == null:
		_gold_m = StandardMaterial3D.new()
		_gold_m.albedo_color = Color("#D9AE45")
		_gold_m.metallic = 0.45
		_gold_m.roughness = 0.35
	return _gold_m


## 금 왕관 (덩어리로)
func _crown(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	root.scale = Vector3.ONE * 0.7
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
	cam.position = Vector3(target_x, 2.3, 6.2)
	cam.look_at(Vector3(target_x, 1.3, 0))
	if Game.autotest and t > 0.5:
		print("[autotest] OK — reached %s, history %d" % [str(Game.get_meta("reached")), Game.history.size()])
		get_tree().quit(0)


func _again() -> void:
	Game.new_game()
	Game.goto("reveal")
