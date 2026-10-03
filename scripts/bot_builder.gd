class_name BotBuilder
extends RefCounted
## 봇의 작품: 타겟 템플릿을 봇이 가진 덩어리로 대체해서 만든다.
## 재료가 없으면 같은 계열로, 그것도 없으면 아무거나로 — 편성이 봇에게도 문제를 낸다.


static func wanted_types(tpl: Dictionary) -> Array:
	var out := []
	for part in tpl["parts"]:
		for t in Data.GROUPS[part[0]]:
			if not out.has(t):
				out.append(t)
	return out


static func _take(avail: Array, group: String) -> Dictionary:
	var allowed: Array = Data.GROUPS[group]
	for t in allowed:
		for i in avail.size():
			if avail[i]["type"] == t:
				return avail.pop_at(i)
	for i in avail.size():
		for t in allowed:
			if Data.KIND[avail[i]["type"]] == Data.KIND[t]:
				return avail.pop_at(i)
	if not avail.is_empty():
		return avail.pop_at(0)
	return {}


static func build(tpl: Dictionary, inventory: Array, quality: float, rng: RandomNumberGenerator) -> Array:
	var avail := inventory.duplicate(true)
	var out := []
	var jitter := (1.0 - quality)
	for part in tpl["parts"]:
		if rng.randf() > 0.6 + quality * 0.45:
			continue
		var item := _take(avail, part[0])
		if item.is_empty():
			break
		var t: String = item["type"]
		var up: String = part[3]
		var tilt: Vector3 = part[4]
		var size: Vector3 = part[2] * (1.0 + rng.randfn(0.0, jitter * 0.3))
		var local := Data.world_to_local_size(up, size)
		var bs := Data.base_size(t)
		var s := Vector3(local.x / bs.x, local.y / bs.y, local.z / bs.z)
		var basis := Basis.from_euler(tilt * PI / 180.0) * Data.up_basis(up)
		basis = Basis(Vector3.UP, rng.randfn(0.0, jitter * 0.25)) * basis
		var pos: Vector3 = part[1] + Vector3(rng.randfn(0, 1), rng.randfn(0, 1), rng.randfn(0, 1)) * jitter * 0.12
		var ci: int = part[5] if rng.randf() < 0.55 + quality * 0.4 else rng.randi() % 16
		out.append({"t": t, "p": pos, "r": basis.get_rotation_quaternion(), "s": s, "c": ci, "o": item.get("origin", "ground")})
	# 최소 5개는 채운다
	while out.size() < 5 and not avail.is_empty():
		var item: Dictionary = avail.pop_at(0)
		out.append({"t": item["type"], "p": Vector3(rng.randf_range(-0.4, 0.4), 0.2, rng.randf_range(-0.3, 0.3)),
			"r": Quaternion.IDENTITY, "s": Vector3.ONE, "c": rng.randi() % 16, "o": item.get("origin", "ground")})
	# 클램프된 배율 반영 후 정렬
	for d in out:
		var s: Vector3 = d["s"]
		d["s"] = Vector3(clampf(s.x, Data.SCALE_MIN, Data.SCALE_MAX), clampf(s.y, Data.SCALE_MIN, Data.SCALE_MAX), clampf(s.z, Data.SCALE_MIN, Data.SCALE_MAX))
	# 전체를 무작위 방향으로 돌려서 전시 각도가 다양하게
	var yaw := Basis(Vector3.UP, rng.randf() * TAU)
	for d in out:
		d["p"] = yaw * d["p"]
		d["r"] = (yaw * Basis(d["r"] as Quaternion)).get_rotation_quaternion()
	return Judge.settle_work(out)
