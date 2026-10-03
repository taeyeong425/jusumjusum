class_name BotBuilder
extends RefCounted
## 봇의 작품. 사람과 같은 규칙 — 덩어리의 비율은 고정, 전체 크기와 회전만 바꾼다.
## 그래서 봇도 "바퀴 자리에 맞는 모양"을 가진 재료가 있어야 잘 만든다. 편성이 봇에게도 문제를 낸다.


static func wanted_types(tpl: Dictionary) -> Array:
	var out := []
	for part in tpl["parts"]:
		for t in Data.GROUPS[part[0]]:
			if not out.has(t):
				out.append(t)
	return out


## 부위의 로컬 크기 L에 아이템을 맞출 때의 (최적 크기 k, 어긋남)
static func fit(item: Dictionary, local: Vector3) -> Array:
	var b: Vector3 = Data.base_size(item["type"]) * (item.get("shape", Vector3.ONE) as Vector3)
	var r := Vector3(local.x / b.x, local.y / b.y, local.z / b.z)
	var k := clampf(pow(r.x * r.y * r.z, 1.0 / 3.0), Data.SIZE_MIN, Data.SIZE_MAX)
	var mis := absf(log(b.x * k / local.x)) + absf(log(b.y * k / local.y)) + absf(log(b.z * k / local.z))
	return [k, mis]


static func _take(avail: Array, group: String, local: Vector3) -> Array:
	var allowed: Array = Data.GROUPS[group]
	var best := -1
	var best_cost := INF
	var best_k := 1.0
	for i in avail.size():
		var t: String = avail[i]["type"]
		var pen := 0.0
		var gi := allowed.find(t)
		if gi >= 0:
			pen = gi * 0.15
		else:
			pen = 1.0
			for a in allowed:
				if Data.KIND[a] == Data.KIND[t]:
					pen = 0.6
		var f := fit(avail[i], local)
		var cost: float = pen + f[1] * 0.35
		if cost < best_cost:
			best_cost = cost
			best = i
			best_k = f[0]
	if best < 0:
		return []
	return [avail.pop_at(best), best_k]


static func build(tpl: Dictionary, inventory: Array, quality: float, rng: RandomNumberGenerator) -> Array:
	var avail := inventory.duplicate(true)
	var out := []
	var jitter := (1.0 - quality)
	for part in tpl["parts"]:
		if rng.randf() > 0.6 + quality * 0.45:
			continue
		var up: String = part[3]
		var tilt: Vector3 = part[4]
		var size: Vector3 = part[2] * (1.0 + rng.randfn(0.0, jitter * 0.3))
		var local := Data.world_to_local_size(up, size)
		var got := _take(avail, part[0], local)
		if got.is_empty():
			break
		var item: Dictionary = got[0]
		var k: float = got[1]
		var sh: Vector3 = item.get("shape", Vector3.ONE)
		var basis := Basis.from_euler(tilt * PI / 180.0) * Data.up_basis(up)
		basis = Basis(Vector3.UP, rng.randfn(0.0, jitter * 0.25)) * basis
		var pos: Vector3 = part[1] + Vector3(rng.randfn(0, 1), rng.randfn(0, 1), rng.randfn(0, 1)) * jitter * 0.12
		var ci: int = part[5] if rng.randf() < 0.55 + quality * 0.4 else item.get("color", rng.randi() % 16)
		out.append(_dict(item, pos, basis, sh, k, ci))
	while out.size() < 5 and not avail.is_empty():
		var item: Dictionary = avail.pop_at(0)
		out.append(_dict(item, Vector3(rng.randf_range(-0.4, 0.4), 0.2, rng.randf_range(-0.3, 0.3)),
			Basis.IDENTITY, item.get("shape", Vector3.ONE), 1.0, item.get("color", 0)))
	var yaw := Basis(Vector3.UP, rng.randf() * TAU)
	for d in out:
		d["p"] = yaw * d["p"]
		d["r"] = (yaw * Basis(d["r"] as Quaternion)).get_rotation_quaternion()
	return Judge.settle_work(out)


static func _dict(item: Dictionary, pos: Vector3, basis: Basis, sh: Vector3, k: float, ci: int) -> Dictionary:
	var s := sh * k
	s = Vector3(clampf(s.x, Data.SCALE_MIN, Data.SCALE_MAX), clampf(s.y, Data.SCALE_MIN, Data.SCALE_MAX), clampf(s.z, Data.SCALE_MIN, Data.SCALE_MAX))
	return {"t": item["type"], "p": pos, "r": basis.get_rotation_quaternion(), "s": s, "sh": sh, "k": k,
		"c": ci, "o": item.get("origin", "ground")}
