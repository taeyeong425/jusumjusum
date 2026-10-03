extends SceneTree
## 모든 변형을 한 줄로 늘어놓고 스크린샷 (시각 확인용)

func _initialize() -> void:
	Data.load_fonts()
	var root := Node3D.new()
	get_root().add_child(root)
	UI.make_env(root)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	var x := 0
	var z := 0
	for t in Data.TYPES:
		x = 0
		for v in Data.VARIANTS[t]:
			var pc := Piece.new().setup(t, 2 + (x % 8), false, v[1])
			pc.position = Vector3(x * 1.0, 0, z * 1.0)
			pc.rotation_degrees = Vector3(0, 25, 0)
			pc.set_pscale(v[1], false)
			root.add_child(pc)
			x += 1
		z += 1
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.look_at_from_position(Vector3(3.5, 9, 15), Vector3(3.5, 0, 5.5))
	cam.fov = 50
	for i in 8:
		await process_frame
	get_root().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
