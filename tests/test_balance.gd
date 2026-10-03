extends SceneTree
## R7 검증 — 할당량 곡선. 사람 실력별 평균 도달 라운드 (목표 4~6).
## 수집은 근사: 원하는 종류를 70% 확률로 확보 (편성 재고 한도 내).

const GAMES := 300

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	print("\n사람 실력 → 평균 도달 라운드 (분포)")
	for hq in [0.4, 0.6, 0.75, 0.9]:
		var hist := {}
		var total := 0
		for g in GAMES:
			var r := _play(hq, rng)
			total += r
			hist[r] = hist.get(r, 0) + 1
		var dist := ""
		for k in range(1, 10):
			if hist.has(k):
				dist += " %d:%d%%" % [k, roundi(100.0 * hist[k] / GAMES)]
		print("  사람 q%.2f → 평균 %.2f |%s" % [hq, float(total) / GAMES, dist])
	quit()


func _play(hq: float, rng: RandomNumberGenerator) -> int:
	var players := [{"is_bot": false, "quality": hq, "bias": 0.0}]
	for i in 5:
		players.append({"is_bot": true, "quality": rng.randf_range(0.5, 0.95), "bias": rng.randf_range(-0.07, 0.07)})
	var tpls := Data.targets()
	var tickets := 0
	for round_i in range(1, Data.QUOTA.size() + 1):
		var tpl: Dictionary = tpls[rng.randi() % tpls.size()]
		var counts := Data.formation_counts(Data.pick_formation(round_i, rng), 6, rng)
		var want := BotBuilder.wanted_types(tpl)
		for p in players:
			var inv := []
			for k in 12:
				var t: String = want[rng.randi() % want.size()] if rng.randf() < 0.7 else Data.TYPES[rng.randi() % 12]
				if counts.get(t, 0) <= 0:
					t = "box"
				counts[t] = counts.get(t, 1) - 1
				inv.append({"type": t, "origin": "ground"})
			p["work"] = BotBuilder.build(tpl, inv, p["quality"], rng)
		# 사람의 평가는 봇처럼 근사
		var tmp := Judge.rate_round(players, tpl, {}, rng)
		var human := {}
		for w in range(1, 6):
			human[w] = Judge.bot_star(tmp["scores"][w], 0.0, rng)
		var res := Judge.rate_round(players, tpl, human, rng)
		var quota: Array = Data.QUOTA[round_i - 1]
		var v := Judge.quota_pass(res["avg"], quota)
		tickets += 1 if rng.randf() < 0.35 else 0
		if not v["pass"] and tickets >= 3 and round_i > 1:
			tickets -= 3
			v = Judge.quota_pass(res["avg"], Data.QUOTA[round_i - 2])
		if not v["pass"]:
			return round_i
	return Data.QUOTA.size() + 1
