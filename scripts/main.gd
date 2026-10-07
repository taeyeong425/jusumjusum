extends Node
## 페이즈 전환기. 각 페이즈는 코드로 장면을 짓는 Node 스크립트다.

const PHASES := {
	"menu": "res://scripts/phases/menu.gd",
	"reveal": "res://scripts/phases/reveal.gd",
	"collect": "res://scripts/phases/hunt.gd",   # v0.6: 놀이터 뜯기 → 테마 공간 보물찾기
	"build": "res://scripts/phases/build.gd",
	"exhibit": "res://scripts/phases/exhibit.gd",
	"settle": "res://scripts/phases/settle.gd",
	"gallery": "res://scripts/phases/gallery.gd",
}

var current: Node


func _ready() -> void:
	get_window().theme = UI.theme()
	Game.main = self
	if "--bench" in OS.get_cmdline_user_args():
		Game.new_game()
		goto("collect")
		var t := get_tree().create_timer(6.0)
		t.timeout.connect(func():
			var info := "fps=%d draw_calls=%d objects=%d primitives=%d" % [Engine.get_frames_per_second(),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)]
			print("[bench] ", info)
			var cnt := {}
			var stack: Array = [current]
			while not stack.is_empty():
				var n: Node = stack.pop_back()
				for c in n.get_children():
					stack.append(c)
				if n is MeshInstance3D or n is MultiMeshInstance3D:
					var key := "기타"
					var q: Node = n
					while q and q != current:
						if q is Piece and (q as Piece).has_meta("entry"):
							key = "보물·가구 " + str((q as Piece).get_meta("entry").get("kind", "?"))
							break
						if q is CharacterBody3D:
							key = "캐릭터"
							break
						if q is RigidBody3D:
							key = "밀기·공"
							break
						q = q.get_parent()
					var passes := 2 if ((n as GeometryInstance3D).material_override and (n as GeometryInstance3D).material_override.next_pass) else 1
					cnt[key] = int(cnt.get(key, 0)) + passes
			print("[bench] 그리기 후보(패스 포함): ", cnt)
			get_tree().quit())
	elif _arg("--scenario=") != "":
		var sc := _arg("--scenario=")
		Game.new_game()
		if sc == "practice":   # 조립만 해 보기 화면 확인
			Game.new_practice()
			print("[practice] %s · %s · 덩어리 %d개 · 시간 %.0f초" % [Game.theme, Game.target["name"], Game.human()["inventory"].size(), Game.t_build()])
			goto("build")
			return
		if sc == "ceremony":
			var tiers := ["note", "env", "gold", "note", "env", "note", "note"]
			for tr in tiers:
				var parts := []
				for k in Themes.TIERS[tr][2]:
					parts.append(Themes.make_part(Game.theme, Data.TYPES[Game.rng.randi() % 12], Game.rng))
				Game.human()["envelopes"].append({"tier": tr, "name": Themes.TIERS[tr][0], "parts": parts})
			goto("build")
			await get_tree().create_timer(0.6).timeout
			for k in 3:
				current.call("_open_next")
				await get_tree().create_timer(0.3).timeout
		elif sc == "build":
			for p in Game.players:
				for k in 12:
					p["inventory"].append(Data.make_item("box", Vector3.ONE, 2 + k % 6, "auto"))
			goto("build")
		else:
			goto("collect")
		if sc != "ceremony":
			current.call("run_scenario", sc)
	elif Game.autotest:
		Game.new_game()
		goto("reveal")
	else:
		goto("menu")


func goto(phase: String) -> void:
	if current:
		current.queue_free()
		current = null
	var scr: GDScript = load(PHASES[phase])
	current = scr.new()
	current.name = phase
	# 물리 보간은 보물찾기에서만 (캐릭터가 화면 주사율로 부드럽게). 다른 단계는 _process · 트윈으로 움직인다
	if phase != "collect":
		current.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(current)
	if Game.autotest:
		print("[autotest] phase → %s (round %d) f%d" % [phase, Game.round_i, Engine.get_frames_drawn()])


func _arg(prefix: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with(prefix):
			return s.substr(prefix.length())
	return ""
