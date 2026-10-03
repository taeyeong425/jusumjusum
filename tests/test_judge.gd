extends SceneTree
## 인식기 보정 테스트: godot --headless -s res://tests/test_judge.gd

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var tpls := Data.targets()
	print("\n== 같은 타겟, 품질별 (평균 점수 → 별) ==")
	for tpl in tpls:
		var line := "%-4s" % tpl["name"]
		for q in [1.0, 0.85, 0.7, 0.55]:
			var acc := 0.0
			for k in 12:
				var inv := _full_inventory(tpl)
				var w := BotBuilder.build(tpl, inv, q, rng)
				acc += Judge.recognize(w, tpl)
			acc /= 12.0
			line += "  q%.2f=%.2f(★%.1f)" % [q, acc, 1 + 4 * acc]
		print(line)
	print("\n== 다른 타겟으로 만든 작품 (오인식이 낮아야 함) ==")
	for tpl in tpls:
		var worst := 0.0
		var worst_name := ""
		for other in tpls:
			if other == tpl:
				continue
			var w := BotBuilder.build(other, _full_inventory(other), 1.0, rng)
			var s := Judge.recognize(w, tpl)
			if s > worst:
				worst = s
				worst_name = other["name"]
		print("%-4s 최고 오인식 %.2f (%s)" % [tpl["name"], worst, worst_name])
	print("\n== 무작위 더미 8개 ==")
	for tpl in tpls:
		var acc := 0.0
		for k in 12:
			var w := []
			for i in 8:
				var t: String = Data.TYPES[rng.randi() % 12]
				w.append({"t": t, "p": Vector3(rng.randf_range(-.6, .6), rng.randf_range(0, 1), rng.randf_range(-.4, .4)), "r": Quaternion.IDENTITY, "s": Vector3.ONE, "c": rng.randi() % 16})
			acc += Judge.recognize(w, tpl)
		print("%-4s 무작위 %.2f" % [tpl["name"], acc / 12.0])
	print("\n== 편성별 덩어리 수 ==")
	for f in Data.FORMATIONS:
		var c := Data.formation_counts(f, 6, rng)
		var s := 0
		var line := ""
		for t in Data.TYPES:
			s += c[t]
			line += "%s%d " % [Data.NAMES[t], c[t]]
		print("%s 합%d: %s" % [f, s, line])
	quit()


func _full_inventory(tpl: Dictionary) -> Array:
	var inv := []
	for part in tpl["parts"]:
		inv.append({"type": Data.GROUPS[part[0]][0], "origin": "ground"})
	while inv.size() < 12:
		inv.append({"type": "box", "origin": "ground"})
	return inv
