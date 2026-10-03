class_name Judge
extends RefCounted
## 판정: 작품 인식 점수, 봇 평가, ★5 제한, 할당량, 카드, 부문상.
## 프로토타입의 봇 평가는 "타겟 템플릿과 얼마나 닮았나"를 근사한 것이다.


static func half_extents(basis: Basis, s: Vector3, base: Vector3) -> Vector3:
	var h := base * s * 0.5
	var bx := basis.x * h.x
	var by := basis.y * h.y
	var bz := basis.z * h.z
	return Vector3(
		absf(bx.x) + absf(by.x) + absf(bz.x),
		absf(bx.y) + absf(by.y) + absf(bz.y),
		absf(bx.z) + absf(by.z) + absf(bz.z))


static func work_boxes(work: Array) -> Array:
	var out := []
	for d in work:
		var b := Basis(d["r"] as Quaternion)
		out.append({"c": d["p"], "h": half_extents(b, d["s"], Data.base_size(d["t"])), "t": d["t"]})
	return out


static func template_boxes(tpl: Dictionary) -> Array:
	var out := []
	for part in tpl["parts"]:
		var sz: Vector3 = part[2]
		var tilt: Vector3 = part[4]
		var h := sz * 0.5
		if tilt != Vector3.ZERO:
			var b := Basis.from_euler(tilt * PI / 180.0)
			h = half_extents(b, sz, Vector3.ONE)
		out.append({"c": part[1], "h": h, "g": part[0]})
	return out


static func bounds(boxes: Array) -> AABB:
	if boxes.is_empty():
		return AABB()
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	for b in boxes:
		mn = mn.min(b["c"] - b["h"])
		mx = mx.max(b["c"] + b["h"])
	return AABB(mn, mx - mn)


static func normalized(boxes: Array) -> Array:
	var bb := bounds(boxes)
	var k := 1.0 / maxf(0.001, maxf(bb.size.x, maxf(bb.size.y, bb.size.z)))
	var center := Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
	var out := []
	for b in boxes:
		var nb: Dictionary = b.duplicate()
		nb["c"] = (b["c"] - center) * k
		nb["h"] = b["h"] * k
		out.append(nb)
	return out


static func _sorted3(v: Vector3) -> Array:
	var a := [v.x, v.y, v.z]
	a.sort()
	return a


static func _yawed(boxes: Array, quarter: int, mirror: bool) -> Array:
	var out := []
	var rot := Basis(Vector3.UP, quarter * PI / 2)
	for b in boxes:
		var c: Vector3 = rot * b["c"]
		var h: Vector3 = b["h"]
		if quarter % 2 == 1:
			h = Vector3(h.z, h.y, h.x)
		if mirror:
			c.x = -c.x
		var nb: Dictionary = b.duplicate()
		nb["c"] = c
		nb["h"] = h
		out.append(nb)
	return out


static func _type_penalty(t: String, g: String) -> float:
	var allowed: Array = Data.GROUPS[g]
	if allowed.has(t):
		return 0.0
	for a in allowed:
		if Data.KIND[a] == Data.KIND[t]:
			return 0.22
	return 0.45


static func _match(w: Array, tpl: Array) -> float:
	var order := tpl.duplicate()
	order.sort_custom(func(a, b): return (a["h"].x * a["h"].y * a["h"].z) > (b["h"].x * b["h"].y * b["h"].z))
	var used := {}
	var total := 0.0
	for tp in order:
		var best := 0.0
		var best_i := -1
		var st := _sorted3(tp["h"])
		for i in w.size():
			if used.has(i):
				continue
			var wb: Dictionary = w[i]
			var dist: float = (wb["c"] - tp["c"]).length()
			var sw := _sorted3(wb["h"])
			var sz := 0.0
			for k in 3:
				sz += absf(log(maxf(sw[k], 0.004) / maxf(st[k], 0.004)))
			sz /= 3.0
			var cost: float = dist * 1.8 + minf(sz, 1.5) * 0.3 + _type_penalty(wb["t"], tp["g"])
			var m := clampf(1.0 - cost, 0.0, 1.0)
			if m > best:
				best = m
				best_i = i
		if best_i >= 0:
			used[best_i] = true
			total += best
	return total / maxf(1.0, float(order.size()))


static func _aspect_sim(a: AABB, b: AABB) -> float:
	var ma := maxf(0.001, maxf(a.size.x, maxf(a.size.y, a.size.z)))
	var mb := maxf(0.001, maxf(b.size.x, maxf(b.size.y, b.size.z)))
	var ra := a.size / ma
	var rb := b.size / mb
	var d := absf(ra.x - rb.x) + absf(ra.y - rb.y) + absf(ra.z - rb.z)
	return 1.0 - clampf(d / 1.5, 0.0, 1.0)


## 0~1. 작품이 타겟처럼 보이는 정도.
static func recognize(work: Array, tpl: Dictionary) -> float:
	if work.is_empty():
		return 0.0
	var tb := template_boxes(tpl)
	var tn := normalized(tb)
	var tbb := bounds(tb)
	var wb := work_boxes(work)
	var best := 0.0
	for q in 4:
		for mirror in [false, true]:
			var y := _yawed(wb, q, mirror)
			var cov := _match(normalized(y), tn)
			var asp := _aspect_sim(bounds(y), tbb)
			best = maxf(best, cov * 0.8 + asp * 0.2)
	var colors := {}
	for d in work:
		colors[d["c"]] = true
	var color_term := clampf((colors.size() - 1) / 2.0, 0.0, 1.0)
	var s := best * 0.9 + color_term * 0.1
	var n := work.size()
	if n < 5:
		s *= 0.45
	elif n < tb.size() * 0.5:
		s *= 0.8
	return clampf(s, 0.0, 1.0)


## 인식 점수 → 봇의 별점
## 대비 곡선: 무작위 더미(≈0.33)는 ★1~2, 잘 만든 것(≈0.85)은 ★4~5가 되도록 펼친다.
static func perceived(score: float) -> float:
	return clampf((score - 0.25) / 0.57, 0.0, 1.0)


## 평가는 0.0 ~ 5.0, 0.1 단위
const TOP := 4.6        # 이 점수 이상은 평가자 1명당 한 작품만
const TOP_CAP := 4.5


static func bot_star(score: float, bias: float, rng: RandomNumberGenerator) -> float:
	var v := 1.0 + 4.0 * clampf(perceived(score) + bias + rng.randfn(0.0, 0.08), 0.0, 1.0)
	return snappedf(clampf(v + rng.randfn(0.0, 0.15), 0.0, 5.0), 0.1)


## 평가 매트릭스: ratings[rater][work] (자기 작품은 -1).
## human_ratings: 플레이어가 준 별점 {work_index: stars}
## 반환: {"ratings", "avg": Array[float], "scores": Array[float]}
static func rate_round(players: Array, tpl: Dictionary, human_ratings: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n := players.size()
	var scores := []
	for p in players:
		scores.append(recognize(p["work"], tpl))
	var ratings := []
	for r in n:
		var row := []
		for w in n:
			row.append(-1)
		if players[r]["is_bot"]:
			var raw := {}
			for w in n:
				if w == r:
					continue
				raw[w] = scores[w] + players[r]["bias"] + rng.randfn(0.0, 0.07)
				row[w] = bot_star(scores[w], players[r]["bias"], rng)
			_enforce_one_top(row, raw)
		else:
			for w in n:
				if w != r:
					row[w] = float(human_ratings.get(w, 3.0))
		ratings.append(row)
	var avg := []
	for w in n:
		var s := 0.0
		var c := 0
		for r in n:
			if ratings[r][w] >= 0:
				s += ratings[r][w]
				c += 1
		avg.append(s / maxf(1.0, float(c)))
	return {"ratings": ratings, "avg": avg, "scores": scores}


## 4.6 이상은 평가자당 한 작품만. 여러 개면 가장 높게 본 작품만 남기고 나머지는 4.5로.
static func _enforce_one_top(row: Array, raw: Dictionary) -> void:
	var tops := []
	for w in row.size():
		if row[w] >= TOP - 0.001:
			tops.append(w)
	if tops.size() <= 1:
		return
	tops.sort_custom(func(a, b): return raw.get(a, 0.0) > raw.get(b, 0.0))
	for i in range(1, tops.size()):
		row[tops[i]] = TOP_CAP


## 동점 규칙: 기준값 이상이면 통과 (격자 위의 값이라 경계가 명확하다)
static func quota_pass(avg: Array, quota: Array) -> Dictionary:
	var th: float = quota[0]
	var need: int = quota[1]
	var got := 0
	for a in avg:
		if a >= th - 0.0001:
			got += 1
	return {"pass": got >= need, "got": got, "need": need, "th": th}


# ── 카드 ─────────────────────────────────────────────

## 제약 부분만 (조립 중 실시간 표시에 쓴다)
static func card_constraint(card: Dictionary, work: Array, inventory_size: int) -> bool:
	var n := work.size()
	if n < 5:
		return false
	match card["id"]:
		"minimal":
			return n <= 6
		"glutton":
			return n >= inventory_size and n >= 8
		"mono":
			var cs := {}
			for d in work:
				cs[d["c"]] = true
			return cs.size() == 1
		"stubborn":
			var tc := {}
			for d in work:
				tc[d["t"]] = tc.get(d["t"], 0) + 1
			for t in tc:
				if tc[t] * 2 >= n:
					return true
			return false
		"honest":
			for d in work:
				if absf(float(d.get("k", 1.0)) - 1.0) > 0.05:
					return false
			return true
		"curvy":
			for d in work:
				if Data.KIND[d["t"]] != "curve":
					return false
			return true
		"wrecker":
			var k := 0
			for d in work:
				if d.get("o", "") == "tear":
					k += 1
			return k >= 4
	return false


## 순위 조건. 동점 규칙:
##  상위 절반 = 나보다 평점이 '엄격히 높은' 작품 수 < 절반
##  꼴찌만 아니면 = 나보다 '엄격히 낮은' 작품이 하나라도 있다 (최저 동점은 전원 꼴찌)
static func card_rank_ok(rank: String, idx: int, avg: Array) -> bool:
	var higher := 0
	var lower := 0
	for i in avg.size():
		if i == idx:
			continue
		if avg[i] > avg[idx] + 0.0001:
			higher += 1
		elif avg[i] < avg[idx] - 0.0001:
			lower += 1
	if rank == "half":
		return higher < avg.size() / 2
	return lower > 0


# ── 부문상 ───────────────────────────────────────────

static func awards(players: Array, ratings: Array) -> Array:
	var n := players.size()
	var cats := [
		["가장 적은 덩어리로", func(i): return -players[i]["work"].size() if players[i]["work"].size() >= 5 else -999],
		["가장 과감한", func(i): return _max_scale_dev(players[i]["work"])],
		["색감 장인", func(i): return _color_count(players[i]["work"])],
		["제일 많이 고친", func(i): return players[i].get("edits", 0)],
		["아무도 안 쓴 덩어리를 쓴", func(i): return _unique_types(players, i)],
		["이게 뭐죠?", func(i): return _spread(ratings, i)],
		["키다리", func(i): return bounds(work_boxes(players[i]["work"])).size.y],
		["꼼꼼이", func(i): return players[i]["work"].size()],
	]
	# 각 범주에서 1위를 정하되, 한 사람은 상 하나만. 남은 사람은 참가상.
	var cand := []
	for ci in cats.size():
		var vals := []
		for i in n:
			vals.append(float(cats[ci][1].call(i)))
		var mx: float = vals.max()
		var mn: float = vals.min()
		for i in n:
			var norm: float = 0.5 if mx - mn < 0.0001 else (vals[i] - mn) / (mx - mn)
			cand.append([norm, ci, i])
	cand.sort_custom(func(a, b): return a[0] > b[0])
	var got := {}
	var used_cat := {}
	var out := []
	for c in cand:
		if got.has(c[2]) or used_cat.has(c[1]) or c[0] < 0.5:
			continue
		got[c[2]] = true
		used_cat[c[1]] = true
		out.append({"who": c[2], "name": cats[c[1]][0]})
	for i in n:
		if not got.has(i):
			out.append({"who": i, "name": "오늘도 만들었다"})
	return out


static func _max_scale_dev(work: Array) -> float:
	var m := 0.0
	for d in work:
		var s: Vector3 = d["s"]
		m = maxf(m, maxf(absf(log(s.x)), maxf(absf(log(s.y)), absf(log(s.z)))))
	return m


static func _color_count(work: Array) -> int:
	var cs := {}
	for d in work:
		cs[d["c"]] = true
	return cs.size()


static func _unique_types(players: Array, idx: int) -> int:
	var mine := {}
	for d in players[idx]["work"]:
		mine[d["t"]] = true
	var others := {}
	for i in players.size():
		if i == idx:
			continue
		for d in players[i]["work"]:
			others[d["t"]] = true
	var k := 0
	for t in mine:
		if not others.has(t):
			k += 1
	return k


static func _spread(ratings: Array, idx: int) -> float:
	var vals := []
	for r in ratings.size():
		if ratings[r][idx] >= 0:
			vals.append(float(ratings[r][idx]))
	if vals.size() < 2:
		return 0.0
	var mean := 0.0
	for v in vals:
		mean += v
	mean /= vals.size()
	var s := 0.0
	for v in vals:
		s += (v - mean) * (v - mean)
	return sqrt(s / vals.size())


## 작품을 받침대 기준으로 정렬: x·z 중심 0, 최저점 y 0
static func settle_work(work: Array) -> Array:
	if work.is_empty():
		return work
	var bb := bounds(work_boxes(work))
	var off := Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
	var out := []
	for d in work:
		var nd: Dictionary = d.duplicate()
		nd["p"] = d["p"] - off
		out.append(nd)
	return out
