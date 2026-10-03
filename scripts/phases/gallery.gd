extends Node3D
## 판 종료 — 시상대가 아니라 전시회 (§9.5). 우승자를 발표하지 않는다.

var cam: Camera3D
var t := 0.0
var span := 1.0


func _ready() -> void:
	UI.make_env(self, Color("#F2E6D0"))
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(80, 40)
	fl.mesh = pm
	fl.material_override = Data.flat_material(Color("#D8C3A0"))
	add_child(fl)
	var letters: Dictionary = Game.get_meta("letters") if Game.has_meta("letters") else {}
	var x := 0.0
	for rec in Game.history:
		var lab := UI.label3d("%d라운드 「%s」 %s" % [rec["round"], rec["target"], "통과" if rec["pass"] else "여기까지"], 44)
		lab.position = Vector3(x + 5.0, 3.4, -1.2)
		add_child(lab)
		for i in rec["works"].size():
			var px: float = x + i * 2.0
			var ped := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(1.6, 0.5, 1.6)
			ped.mesh = bm
			ped.position = Vector3(px, 0.25, 0)
			ped.material_override = Data.flat_material(Color("#FFFFFF") if i != 0 else Color("#FFF0C2"))
			add_child(ped)
			var holder := Node3D.new()
			holder.position = Vector3(px, 0.5, 0)
			holder.scale = Vector3.ONE * 0.75
			add_child(holder)
			for d in rec["works"][i]:
				holder.add_child(Piece.from_dict(d, false))
			var nm: String = "나" if i == 0 else Game.players[i]["name"]
			var l := UI.label3d("%s ★%.1f" % [nm, rec["avg"][i]], 26)
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
	v.add_child(UI.label("기록: %d라운드까지 · 최고 기록 %d라운드" % [mini(reached, Data.QUOTA.size()), Game.best_record], 26, UI.INK))
	v.add_child(UI.label("오늘 만든 작품 %d개" % (Game.history.size() * Game.players.size()), 22, UI.SOFT))
	var h := UI.hbox(12)
	v.add_child(h)
	h.add_child(UI.button("한 판 더", _again, 26))
	h.add_child(UI.button("처음으로", func(): Game.goto("menu"), 22))
	layer.add_child(p)
	UI.corner(p, Control.PRESET_TOP_LEFT)


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
