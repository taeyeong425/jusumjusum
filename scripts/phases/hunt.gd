extends Node3D
## 보물찾기 (2:30) — v0.6 브랜치 treasure-hunt.
## 라운드마다 다른 공간(학교 · 미술관 · 해적선)을 돌아다니며 쪽지 · 편지봉투 · 금봉투를 찾는다.
## 서랍 · 사물함 · 술통 · 액자 같은 가구를 열어야 보이는 봉투도 있다. 봉투는 조립 시작 때 한꺼번에 연다.
## 보물 수 = 인원 × 1.5 × 10 (6명 = 90개). 먼저 줍는 사람이 임자.

const SPEED := 5.6
const GRAVITY := 22.0
const JUMP_V := 8.6
const BAG_MAX := 15            # 봉투 칸 (3분에 12칸이 다 차서 늘림)
const REACH := 3.6
const PEEK_R := 7.0
const OPEN_TIME := 0.55        # 가구 여는 시간 배율
const L_WORLD := 1
const L_ITEM := 2
const L_CHAR := 4
const LVL_LAYERS := [1, 8, 16, 64, 512]  # 층별 충돌 레이어
const L_WALL := 32             # 벽 — 캐릭터는 막고 카메라는 통과 (위에서 들여다보는 인형의 집)
const ALL_WORLD := 1 | 8 | 16 | 32 | 64 | 256 | 512   # 바닥 · 층 · 벽 · 가구 (밀 수 있는 것 128은 빼고 — 길찾기가 그걸 지나가며 민다)
var wall_mode := false

var time_left := 150.0
var finished := false
var world: Node3D
var cam_pivot: Node3D
var spring: SpringArm3D
var cam: Camera3D
var cam_yaw := 0.0
var cam_pitch := -0.32
var actors: Array = []
var obstacles: Array = []      # (_solid · _ramp 호환용)
var info: Dictionary = {}      # 지도 정보: levels · bounds · spawns · rooms

# 지도 짓기 상태
var lvl := 0
var lvl_roots: Array = []      # 층별 루트 노드 (위층 숨기기)
var batches: Array = []        # 층별 {색 키: SurfaceTool}
var _mesh_cache := {}
var containers: Array = []     # 열 수 있는 가구
var treasures: Array = []      # 보물
var spots: Array = []          # 숨김 자리 {pos, kind, lvl}
var ladders: Array = []        # {pos: Vector2, y0, y1, yaw}
var links: Array = []          # 길찾기 층 연결 [아래 점, 위 점]
var hidden_from := 99          # 이 층부터 위는 숨김 (머리 위에 천장이 있을 때)
var pushables: Array = []
var push_t := 0.0
var furn := true             # 가구 충돌 표시 (조준 레이가 가구 충돌은 통과 — 서랍 속 봉투를 겨눌 수 있게)

var aim: Dictionary = {}
var act: Dictionary = {}
var zoom := 4.0           # 시점 거리 고정 (배그식)
var hold_prog := 0.0
var tick_t := 0.0
var step_t := 0.0
var slot := 0
var jump_req := false
var jump_buf := 0.0
var warned := {}
var was_floor := true
var sim_move := Vector2.ZERO
var detect_t := 0.0

var hud_time: Label
var hud_prompt: Label
var hud_left: Label
var prompt_key: Control
var hud_bar: ProgressBar
var fx: Control
var bag_panel: PanelContainer
var bag_list: VBoxContainer
var bag_open := false
var bag_t := 0.0
var hotbar: HBoxContainer
var hot_slots: Array = []
var minimap: Control
var toast: Label
var toast_t := 0.0
var _sb_cache := {}


func _ready() -> void:
	time_left = Game.t_collect()
	var th: Dictionary = Themes.INFO[Game.theme]
	# 지도 · 길 계산 동안 가림막 (카메라가 자리 잡기 전 엉뚱한 화면이 깜빡였다)
	var cover_l := CanvasLayer.new()
	cover_l.layer = 50
	add_child(cover_l)
	var cover := ColorRect.new()
	cover.color = Color("#24303B")
	cover_l.add_child(UI.full(cover))
	var cl := UI.label("%s로 가는 중" % th["name"], 30, Color("#F4F1E6", 0.8), true)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cover.add_child(UI.full(cl))
	UI.make_env(self, Color(th["sky"]))
	_indoor_env()
	world = Node3D.new()
	add_child(world)
	for k in LVL_LAYERS.size():
		var r := Node3D.new()
		r.name = "L%d" % k
		world.add_child(r)
		lvl_roots.append(r)
		batches.append({})
	var builder: GDScript = load("res://scripts/maps/%s.gd" % Game.theme)
	info = builder.call("build", self)
	_scale_info()
	for k in batches.size():
		_commit(batches[k], lvl_roots[k])
	_commit_glow()
	_spawn_actors()
	_build_camera()
	await _build_nav()
	_place_treasures()
	_build_hud()
	if not OS.has_feature("web") and not Game.autotest and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # 웹은 첫 클릭에서 (브라우저 규칙)
	ready_done = true
	_update_camera(1.0)
	cam_pivot.global_position = (actors[0]["body"] as Node3D).global_position + Vector3(0, 2.05, 0)
	var ctw := create_tween()
	ctw.tween_interval(0.15)
	ctw.tween_property(cover, "modulate:a", 0.0, 0.35)
	ctw.tween_callback(cover_l.queue_free)


var ready_done := false


## 지도 정보(경계 · 방 · 시작 자리)도 배율만큼
func _scale_info() -> void:
	var b: Rect2 = info["bounds"]
	info["bounds"] = Rect2(b.position * W, b.size * W)
	var rs := []
	for r in info.get("rooms", []):
		var rr: Rect2 = r[0]
		var nr: Array = r.duplicate()
		nr[0] = Rect2(rr.position * W, rr.size * W)
		rs.append(nr)
	info["rooms"] = rs
	var sp := []
	for s in info["spawns"]:
		sp.append(s * W)
	info["spawns"] = sp
	var lv_s := []
	for y in info["levels"]:
		lv_s.append(float(y) * W)
	info["levels"] = lv_s


## 실내 분위기: 은은한 거리 안개(깊이감) · 따뜻한 주변광 · 필름 톤
func _indoor_env() -> void:
	for c in get_children():
		if c is WorldEnvironment:
			var env: Environment = (c as WorldEnvironment).environment
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.tonemap_exposure = 0.95
			env.ambient_light_color = Color("#FFF0DC")
			env.ambient_light_energy = 0.5
			env.fog_enabled = true
			env.fog_light_color = Color("#E9E2D6")
			env.fog_density = 0.0035
			env.fog_sky_affect = 0.0
		if c is DirectionalLight3D:
			# 실내는 햇빛 그림자 끔: 그림자 거리(30m) 경계가 카메라 따라 움직이며 먼 바닥이 천장 그늘 ↔ 햇빛으로 깜빡였다.
			# 대신 캐릭터마다 발밑 원형 그림자 (_blob_shadow)
			(c as DirectionalLight3D).light_energy = 0.4
			(c as DirectionalLight3D).shadow_enabled = false


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RenderingServer.global_shader_parameter_set("seethru_on", 0.0)


# ── 지도 짓기 도구 (maps/*.gd가 부른다) ───────────────
# 배율 W: 지도 전체(위치 · 크기 · 높이)를 W배로 키운다. 캐릭터는 그대로 → 캐릭터가 작은 사람처럼 된다 (메챠 카멜레온 · Tinykin).
# 책상 위 · 책장 칸 · 배 난간처럼 가구가 곧 지형이 된다 — 의자 → 책상 → 선반으로 오르는 3D 탐색.

var W := 1.0
var glow_batches: Array = []   # 층별 [형광등 SurfaceTool, 유리 SurfaceTool]
var walls: Array = []
var _wall_mats := {}
const L_FURN := 256            # 가구 충돌: 캐릭터는 막고 카메라는 통과 (가구에 카메라가 끌려 들어오지 않게)
const L_PUSH := 128            # 밀 수 있는 가구 (상자 · 의자 · 통)


func set_world_scale(s: float) -> void:
	W = s


## (호환) 가구 묶음 — 같은 배율이라 따로 할 일이 없다
func obj(_p: Vector3) -> void:
	pass


func end_obj() -> void:
	pass


## 지도 좌표 → 실제 좌표
func P(p: Vector3) -> Vector3:
	return p * W


func lv(k: int) -> void:
	lvl = k


func level_y(k: int) -> float:
	return float(info.get("levels", [0.0, 3.2, 6.4])[k]) if not info.is_empty() else [0.0, 3.2, 6.4][k]


func _col(c) -> Color:
	return Data.color(c) if c is int else c


var audit_on := OS.get_cmdline_user_args().has("--scenario=solids")
var audit: Array = []   # [로컬 크기, 변환, 지도 코드 위치, 층]

func _batch_add(mesh: Mesh, xf: Transform3D, c, gloss := 0.55) -> void:
	if audit_on:
		var where := "?"
		for fr in get_stack():
			if str(fr["source"]).contains("/maps/"):
				where = "%s:%d %s" % [str(fr["source"]).get_file(), fr["line"], fr["function"]]
				break
		var ab := mesh.get_aabb()
		audit.append([ab.size * xf.basis.get_scale(), xf * Transform3D(Basis(), ab.get_center()), where, lvl])
	var col := _col(c)
	var key := "%s_%.2f" % [col.to_html(), gloss]
	var b: Dictionary = batches[lvl]
	if not b.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		b[key] = [st, col, gloss]
	(b[key][0] as SurfaceTool).append_from(mesh, 0, xf)


func _commit(b: Dictionary, parent: Node3D) -> void:
	for key in b:
		var mi := MeshInstance3D.new()
		mi.mesh = (b[key][0] as SurfaceTool).commit()
		var m := Data.brick(b[key][1], false, 0.25, b[key][2])
		mi.material_override = m
		parent.add_child(mi)


## 충돌 상자 (지도 좌표 · 지도 크기)
func solid_box(center: Vector3, size: Vector3, yaw := 0.0) -> StaticBody3D:
	return _solid(P(center), size * W, yaw)


## 충돌 상자 (실제 좌표)
func _solid(center: Vector3, size: Vector3, yaw := 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = L_WALL if wall_mode else (L_FURN if furn else LVL_LAYERS[lvl])
	b.collision_mask = 0
	if furn:
		b.set_meta("furn", true)
	b.set_meta("lvl", lvl)
	b.position = center
	b.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	lvl_roots[lvl].add_child(b)
	return b


func _rbox_mesh(size: Vector3, r: float) -> Mesh:
	var key := "rb%s_%.3f" % [str(size.snapped(Vector3.ONE * 0.01)), r]
	if not _mesh_cache.has(key):
		_mesh_cache[key] = Data.rounded_box(size, r) if r >= 0.012 else _plain_box(size)
	return _mesh_cache[key]


func _plain_box(size: Vector3) -> Mesh:
	var bm := BoxMesh.new()
	bm.size = size
	return bm


## 상자 하나 (중심 · 크기, 지도 단위). round = 모서리 반지름
## 보이지 않는 충돌만 (지도 좌표)
func block(center: Vector3, size: Vector3, yaw := 0.0) -> void:
	_solid(P(center), size * W, yaw)


func box(center: Vector3, size: Vector3, c, yaw := 0.0, collide := true, round := 0.04, gloss := 0.55) -> void:
	_box_raw(P(center), size * W, c, yaw, collide, round * W, gloss)


func _box_raw(center: Vector3, size: Vector3, c, yaw := 0.0, collide := true, round := 0.04, gloss := 0.55) -> void:
	_batch_add(_rbox_mesh(size, round), Transform3D(Basis(Vector3.UP, yaw), center), c, gloss)
	if collide:
		_solid(center, size, yaw)


func lay_box(center: Vector3, size: Vector3, c, yaw := 0.0, collide := true, round := 0.04, gloss := 0.55) -> void:
	box(center, size, c, yaw, collide, round, gloss)


## a → b 를 잇는 수평 막대 (난간 · 띠 · 테두리)
func box_span(a: Vector3, b: Vector3, hgt: float, w: float, c, collide := false, solid_h := 1.0) -> void:
	var pa := P(a)
	var pb := P(b)
	var d := Vector2(pb.x - pa.x, pb.z - pa.z)
	var yaw := -atan2(d.y, d.x)
	var mid := (pa + pb) * 0.5
	_box_raw(mid, Vector3(d.length(), hgt * W, w * W), c, yaw, false, 0.02 * W)
	if collide:
		_solid(Vector3(mid.x, pa.y + hgt * W * 0.5 - solid_h * W * 0.5, mid.z), Vector3(d.length(), solid_h * W, maxf(w * W, 0.15)), yaw)


func box_rot(center: Vector3, size: Vector3, c, rot_deg: Vector3, round := 0.03, gloss := 0.55) -> void:
	_batch_add(_rbox_mesh(size * W, round * W), Transform3D(Basis.from_euler(rot_deg * PI / 180.0), P(center)), c, gloss)


func _cyl_mesh(radius: float, height: float, top_r: float, sides: int) -> Mesh:
	var key := "cy%.3f_%.3f_%.3f_%d" % [radius, height, top_r, sides]
	if not _mesh_cache.has(key):
		var cm := CylinderMesh.new()
		cm.bottom_radius = radius
		cm.top_radius = radius if top_r < 0.0 else top_r
		cm.height = height
		cm.radial_segments = sides
		cm.rings = 0
		_mesh_cache[key] = cm
	return _mesh_cache[key]


func cyl(center: Vector3, radius: float, height: float, c, collide := true, sides := 16, gloss := 0.55, top_r := -1.0) -> void:
	var pc := P(center)
	_batch_add(_cyl_mesh(radius * W, height * W, top_r * W if top_r >= 0.0 else -1.0, sides), Transform3D(Basis(), pc), c, gloss)
	if collide:
		_solid(pc, Vector3(radius * 1.6, height, radius * 1.6) * W)


func cyl_rot(center: Vector3, radius: float, height: float, c, rot_deg: Vector3, sides := 14) -> void:
	_batch_add(_cyl_mesh(radius * W, height * W, -1.0, sides), Transform3D(Basis.from_euler(rot_deg * PI / 180.0), P(center)), c)


func ball(center: Vector3, radius: float, c, squash := Vector3.ONE, collide := false) -> void:
	if collide:
		_solid(P(center), Vector3.ONE * radius * 1.6 * W * squash)
	var key := "sp%.3f" % (radius * W)
	if not _mesh_cache.has(key):
		var sm := SphereMesh.new()
		sm.radius = radius * W
		sm.height = radius * W * 2
		sm.radial_segments = 14
		sm.rings = 7
		_mesh_cache[key] = sm
	_batch_add(_mesh_cache[key], Transform3D(Basis.from_scale(squash), P(center)), c)


func beam(a: Vector3, b: Vector3, t: float, c) -> void:
	var pa := P(a)
	var pb := P(b)
	var d := pb - pa
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_batch_add(_rbox_mesh(Vector3(t * W, d.length(), t * W), 0.0), Transform3D(Basis(x, y, z), (pa + pb) * 0.5), c)


func part(t: String, spec, c, pos: Vector3, rot_deg := Vector3.ZERO, k := 1.0, solid := false) -> void:
	var shp: Vector3 = spec if spec is Vector3 else Data.variant(t, int(spec))[1]
	var mk := Data.mesh_key(t, shp)
	if solid:   # 장식 조각도 부딪히게 (몸통 상자로 대충)
		_solid(P(pos), Data.base_size(mk) * shp * k * W * 0.85, deg_to_rad(rot_deg.y))
	var xf := Transform3D(Basis.from_euler(rot_deg * PI / 180.0), P(pos)) * Transform3D(Basis.from_scale(shp * k * W), Vector3.ZERO) * Data.base_xform(mk)
	_batch_add(Data.mesh(mk), xf, c)


## 바닥판 (셰이더 무늬) + 충돌. rect = xz 사각형, y = 윗면 (지도 단위)
func floor_rect(rect: Rect2, y: float, style: int, ca: Color, cb: Color, gloss := 0.55, thick := 0.25) -> void:
	furn = false
	rect = Rect2(rect.position * W, rect.size * W)
	y *= W
	thick *= W
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = rect.size
	mi.mesh = pm
	mi.position = Vector3(rect.get_center().x, y + 0.004, rect.get_center().y)
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/floor.gdshader")
	m.set_shader_parameter("style", style)
	m.set_shader_parameter("col_a", ca)
	m.set_shader_parameter("col_b", cb)
	m.set_shader_parameter("gloss", gloss)
	m.set_shader_parameter("scale", W * 0.8)
	mi.material_override = m
	lvl_roots[lvl].add_child(mi)
	var fc := Vector3(rect.get_center().x, y - thick * 0.5, rect.get_center().y)
	if lvl > 0:
		_box_raw(fc - Vector3(0, 0.006, 0), Vector3(rect.size.x, thick, rect.size.y), ca.darkened(0.35), 0.0, false, 0.0)
	var sb := _solid(fc, Vector3(rect.size.x, thick, rect.size.y))
	if lvl > 0:
		sb.set_meta("roof", true)
	furn = true


## 천장 (그림자 없음 — 햇빛이 실내를 비추게) + 형광등 판
func ceiling(rect: Rect2, y: float, c: Color, lights := true) -> void:
	rect = Rect2(rect.position * W, rect.size * W)
	y *= W
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = rect.size
	pm.flip_faces = true
	mi.mesh = pm
	mi.position = Vector3(rect.get_center().x, y, rect.get_center().y)
	mi.material_override = Data.brick(c, false, 0.25, 0.9)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lvl_roots[lvl].add_child(mi)
	if lights:
		var lm := StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.albedo_color = Color("#FFFBEF")
		var nx := maxi(1, int(rect.size.x / (4.5 * W)))
		var nz := maxi(1, int(rect.size.y / (4.5 * W)))
		for ix in nx:
			for iz in nz:
				var lp := Vector3(rect.position.x + rect.size.x * (ix + 0.5) / nx, y - 0.03, rect.position.y + rect.size.y * (iz + 0.5) / nz)
				_glow(0).append_from(_rbox_mesh(Vector3(1.2 * W, 0.04 * W, 0.3 * W), 0.0), 0, Transform3D(Basis(), lp))


## 벽: a→b (xz, 지도 단위), y 바닥, 높이 h. gaps = [[a에서 거리, 폭], ...] (문 — 문 위에 상인방, 문틀)
## windows = [[a에서 거리, 폭], ...] (창문 — 밝은 유리 + 창틀)
func wall(a: Vector2, b: Vector2, y: float, h: float, c, thick := 0.2, gaps := [], windows := []) -> void:
	furn = false
	wall_mode = true
	a *= W
	b *= W
	y *= W
	h *= W
	thick *= W
	var door_h := minf(h - 0.2 * W, 2.3 * W)
	var L := a.distance_to(b)
	var d := (b - a) / L
	var n := Vector2(-d.y, d.x)
	var yaw := -atan2(d.y, d.x)
	var sorted_gaps := gaps.duplicate()
	sorted_gaps.sort_custom(func(p, q): return p[0] < q[0])
	var t := 0.0
	var segs := []
	var col := _col(c)
	var dark := col.darkened(0.3)
	for g in sorted_gaps:
		var gc: float = float(g[0]) * W
		var gw: float = float(g[1]) * W
		var g0: float = gc - gw * 0.5
		if g0 > t:
			segs.append([t, g0])
		t = gc + gw * 0.5
		# 문 위 벽 (상인방) + 문틀
		var gm := a + d * gc
		if h - door_h > 0.05:
			_box_raw(Vector3(gm.x, y + (door_h + h) * 0.5, gm.y), Vector3(gw, h - door_h, thick), col, yaw, true, 0.0)
		for s in [-1.0, 1.0]:
			var jp: Vector2 = a + d * (gc + float(s) * gw * 0.5)
			_box_raw(Vector3(jp.x, y + door_h * 0.5, jp.y), Vector3(0.12 * W, door_h, thick + 0.08 * W), Color("#E9E2D3"), yaw, false, 0.0)
		_box_raw(Vector3(gm.x, y + door_h + 0.05 * W, gm.y), Vector3(gw + 0.24 * W, 0.1 * W, thick + 0.08 * W), Color("#E9E2D3"), yaw, false, 0.0)
	if t < L:
		segs.append([t, L])
	for s in segs:
		var s0: float = s[0]
		var s1: float = s[1]
		var mid := a + d * (s0 + s1) * 0.5
		_box_raw(Vector3(mid.x, y + h * 0.5, mid.y), Vector3(s1 - s0, h, thick), col, yaw, true, 0.0)
		# 아랫단 판벽(어두운 색) · 걸레받이 · 윗몰딩 — 양쪽 면
		for side in [-1.0, 1.0]:
			var off: Vector2 = n * float(side) * (thick * 0.5 + 0.01 * W)
			_box_raw(Vector3(mid.x + off.x, y + 0.45 * W, mid.y + off.y), Vector3(s1 - s0, 0.9 * W, 0.02 * W), col.darkened(0.12), yaw, false, 0.0)
			_box_raw(Vector3(mid.x + off.x, y + 0.92 * W, mid.y + off.y), Vector3(s1 - s0, 0.05 * W, 0.04 * W), Color("#E9E2D3"), yaw, false, 0.0)
			_box_raw(Vector3(mid.x + off.x, y + 0.06 * W, mid.y + off.y), Vector3(s1 - s0, 0.12 * W, 0.04 * W), dark, yaw, false, 0.0)
			_box_raw(Vector3(mid.x + off.x, y + h - 0.06 * W, mid.y + off.y), Vector3(s1 - s0, 0.1 * W, 0.05 * W), Color("#F4EFE6"), yaw, false, 0.0)
	# 창문 (벽에 붙은 밝은 유리 — 바깥이 대낮처럼)
	var gm2 := StandardMaterial3D.new()
	gm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm2.albedo_color = Color("#CFEAF7")
	for wdw in windows:
		var wc: float = float(wdw[0]) * W
		var ww: float = float(wdw[1]) * W
		var wp := a + d * wc
		for side in [-1.0, 1.0]:
			var off: Vector2 = n * float(side) * (thick * 0.5 + 0.015 * W)
			_glow(1).append_from(_plain_box(Vector3(ww, 1.3 * W, 0.01 * W)), 0, Transform3D(Basis(Vector3.UP, yaw), Vector3(wp.x + off.x, y + 1.75 * W, wp.y + off.y)))
			for fy in [1.1, 1.75, 2.4]:
				_box_raw(Vector3(wp.x + off.x * 1.5, y + fy * W, wp.y + off.y * 1.5), Vector3(ww + 0.1 * W, 0.06 * W, 0.04 * W), Color("#FFFFFF"), yaw, false, 0.0)
			for fx_ in [-0.5, 0.0, 0.5]:
				var fp: Vector2 = wp + d * ww * float(fx_)
				_box_raw(Vector3(fp.x + off.x * 1.5, y + 1.75 * W, fp.y + off.y * 1.5), Vector3(0.06 * W, 1.36 * W, 0.04 * W), Color("#FFFFFF"), yaw, false, 0.0)
	furn = true
	wall_mode = false


## 빛나는 것 묶음 (0 = 형광등 · 1 = 창문 유리)
func _glow(k: int) -> SurfaceTool:
	while glow_batches.size() <= lvl:
		glow_batches.append([null, null])
	if glow_batches[lvl][k] == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		glow_batches[lvl][k] = st
	return glow_batches[lvl][k]


func _commit_glow() -> void:
	for k in glow_batches.size():
		for j in 2:
			if glow_batches[k][j] == null:
				continue
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color("#FFFBEF") if j == 0 else Color("#CFEAF7")
			var mi := MeshInstance3D.new()
			mi.mesh = (glow_batches[k][j] as SurfaceTool).commit()
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lvl_roots[k].add_child(mi)


## (v0.6.2: 벽 접기 대신 카메라가 벽에 부딪혀 앞으로 온다 — 실내 3인칭)
func _update_walls(_delta: float) -> void:
	pass


## 계단: bottom → top (지도 단위)
func stairs(bottom: Vector3, top: Vector3, width: float, c) -> void:
	bottom = P(bottom)
	top = P(top)
	width *= W
	var d := Vector3(top.x - bottom.x, 0, top.z - bottom.z)
	var run := d.length()
	var dir := d / run
	var rise := top.y - bottom.y
	var n := maxi(4, int(rise / 0.28))
	var yaw := atan2(-dir.z, dir.x)
	for i in n:
		var f := (i + 0.5) / n
		var p := bottom + dir * run * f
		var hgt := rise * (i + 1) / n
		_box_raw(Vector3(p.x, bottom.y + hgt * 0.5, p.z), Vector3(run / n + 0.02, hgt, width), _col(c).darkened(0.05 * (i % 2)), yaw, false, 0.02)
		# 계단 몸통은 단단하게 — 옆 · 밑으로 통과하지 않게. 윗면은 경사판보다 낮아서 오를 때 덜컹거리지 않는다
		var sh := rise * i / n - 0.3   # 단 앞 모서리에서도 경사판보다 낮게 (턱이 생겨 걸리지 않게)
		if sh > 0.05:
			_solid(Vector3(p.x, bottom.y + sh * 0.5, p.z), Vector3(run / n + 0.02, sh, width), yaw)
	furn = false
	# 경사판 끝은 위층 바닥보다 살짝 높게 · 조금 앞까지 — 딱 맞춰 끝나면 둥근 몸이 바닥판 모서리에 걸려 옆으로 떨어졌다
	_ramp(lvl_roots[lvl], bottom + Vector3(0, -0.12, 0) - dir * 0.3, top + Vector3(0, 0.06, 0) + dir * 0.1, width)
	furn = true
	links.append([bottom - dir * 0.6, top + dir * 0.7])


## 사다리: base(지도 단위) → 높이 y1(지도 단위)
func ladder(base: Vector3, y1: float, yaw: float, c) -> void:
	base = P(base)
	y1 *= W
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var side := Vector3(-fwd.z, 0, fwd.x)
	var h := y1 - base.y
	for s in [-0.3, 0.3]:
		_box_raw(base + side * s + Vector3(0, h * 0.5, 0), Vector3(0.08, h, 0.08), c, yaw, false, 0.02)
	var rungs := int(h / 0.35)
	for i in rungs:
		_box_raw(base + Vector3(0, 0.3 + i * 0.35, 0), Vector3(0.6, 0.06, 0.06), c, yaw, false, 0.0)
	ladders.append({"pos": Vector2(base.x, base.z), "y0": base.y, "y1": y1, "fwd": fwd})
	links.append([base - fwd * 0.5, Vector3(base.x, y1, base.z) + fwd * 0.8])


## 숨김 자리 (지도 좌표). 캐릭터 손이 안 닿는 높이(바닥에서 2.4 이상)는 버린다 — 올라설 데가 있으면 그 위에 등록
func spot(pos: Vector3, kind := "open") -> void:
	var p := P(pos)
	spots.append({"pos": p, "kind": kind, "lvl": lvl})


## 열 수 있는 가구 (지도 좌표 · 지도 크기)
func container(kind: String, pos: Vector3, size: Vector3, yaw: float, c: int, inside: Vector3, name: String) -> Dictionary:
	pos = P(pos)
	inside = P(inside)
	size *= W
	var pivot := Node3D.new()
	var basis := Basis(Vector3.UP, yaw)
	var hinge := Vector3.ZERO
	match kind:
		"door": hinge = basis * Vector3(-size.x * 0.5, 0, 0)
		"lid": hinge = basis * Vector3(0, 0, -size.z * 0.5)
		"frame": hinge = basis * Vector3(0, size.y * 0.5, 0)
	pivot.position = pos + hinge
	pivot.rotation.y = yaw
	lvl_roots[lvl].add_child(pivot)
	var pc := Piece.new().setup("box", int(c), true, Vector3.ONE)
	pc.set_pscale(size / 0.5, false)
	pc.position = basis.inverse() * (-hinge)
	pivot.add_child(pc)
	var e := {"kind": "box", "node": pc, "pivot": pivot, "mode": kind, "hold": 0.0, "name": name,
		"alive": true, "inside": [], "slot": inside, "lvl": lvl, "yaw": yaw}
	pc.set_meta("entry", e)
	containers.append(e)
	return e


## 밀 수 있는 가구 (상자 · 통 · 의자). 밑에 쪽지가 깔려 있을 수 있다 — 밀어서 치우면 보인다
func pushable(pos: Vector3, size: Vector3, c, yaw := 0.0, mass := 3.0) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.collision_layer = L_PUSH
	rb.collision_mask = ALL_WORLD | L_PUSH | L_CHAR
	rb.mass = mass
	rb.linear_damp = 3.0
	rb.angular_damp = 4.0
	rb.position = P(pos) + Vector3(0, size.y * W * 0.5 + 0.02, 0)
	rb.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size * W
	cs.shape = sh
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = _rbox_mesh(size * W, 0.04 * W)
	mi.material_override = Data.brick(_col(c), false, 0.25, 0.55)
	rb.add_child(mi)
	rb.set_meta("furn", true)
	lvl_roots[lvl].add_child(rb)
	pushables.append({"body": rb, "start": rb.position, "inside": [], "lvl": lvl})
	return rb

## 찰 수 있는 공 (부딪히면 튀어 날아간다)
func toy_ball(pos: Vector3, radius: float, c, bounce := 0.6) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.collision_layer = L_PUSH
	rb.collision_mask = ALL_WORLD | L_PUSH | L_CHAR
	rb.mass = 0.5
	rb.linear_damp = 0.25
	rb.angular_damp = 0.4
	var pm := PhysicsMaterial.new()
	pm.bounce = bounce
	pm.friction = 0.6
	rb.physics_material_override = pm
	rb.position = P(pos) + Vector3(0, radius * W + 0.05, 0)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = radius * W
	cs.shape = sh
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius * W
	sm.height = radius * W * 2
	sm.radial_segments = 18
	sm.rings = 9
	mi.mesh = sm
	mi.material_override = Data.material(c) if c is int else Data.brick(c, false, 0.25, 0.3)
	rb.add_child(mi)
	rb.set_meta("ball", true)
	rb.set_meta("furn", true)
	lvl_roots[lvl].add_child(rb)
	return rb


## 가구가 열린다
func _open_anim(e: Dictionary) -> void:
	var pv: Node3D = e["pivot"]
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	match e["mode"]:
		"drawer":
			var fwd := Basis(Vector3.UP, float(e["yaw"])) * Vector3(0, 0, 1)
			tw.tween_property(pv, "position", pv.position + fwd * 0.38, 0.35)
		"door":
			tw.tween_property(pv, "rotation:y", pv.rotation.y - 1.9, 0.4)
		"lid":
			tw.tween_property(pv, "rotation:x", -1.6, 0.4)
		"frame":
			tw.tween_property(pv, "rotation:x", -0.9, 0.4)
	var n: Piece = e["node"]
	if n.body:
		n.body.collision_layer = 0
	n.set_highlight(false)


# ── 보물 ─────────────────────────────────────────────

const ENV_COLORS := [1, 7, 5, 3, 11]


func _treasure_node(tier: String) -> Piece:
	var col: int = 0 if tier == "note" else (4 if tier == "gold" else ENV_COLORS[Game.rng.randi() % ENV_COLORS.size()])
	var pc := Piece.new().setup("plate", col, true, Vector3.ONE)
	var s := Vector3(0.45, 0.6, 0.44) if tier == "note" else (Vector3(0.62, 0.75, 0.62) if tier == "env" else Vector3(0.7, 0.8, 0.7))
	pc.set_pscale(s, false)
	var w := 0.7 * s.x * 0.5
	var d := 0.5 * s.z * 0.5
	var top := 0.06 * s.y * 0.5 + 0.004
	if tier == "note":
		# 반쯤 펼쳐진 쪽지 — 접힌 반쪽이 살짝 들려 있다
		var fold := MeshInstance3D.new()
		fold.mesh = _rbox_mesh(Vector3(w * 2, 0.012, d), 0.004)
		fold.material_override = Data.material(0)
		fold.position = Vector3(0, top + 0.03, -d * 0.5)
		fold.rotation.x = 0.35
		pc.add_child(fold)
	else:
		# 봉투 덮개(삼각) + 밀랍 도장
		var flap := MeshInstance3D.new()
		flap.mesh = Data._extrude(PackedVector2Array([Vector2(-w, -d), Vector2(w, -d), Vector2(0, d * 0.35)]), 0.012)
		flap.material_override = Data.material(col).duplicate()
		(flap.material_override as ShaderMaterial).set_shader_parameter("albedo", Data.color(col).darkened(0.18))
		flap.position = Vector3(0, top + 0.004, 0)
		pc.add_child(flap)
	if tier == "gold":
		pc.mesh_inst.material_override = Data.brick(Color("#F2C94C"), false, 0.25, 0.15)
		_glint(pc, 1.0)
	return pc


## 반짝 — 멀리서도 "뭔가 있다"는 느낌 (금봉투는 늘, 나머지는 가끔)
func _glint(n: Node3D, strength: float) -> void:
	var star := MeshInstance3D.new()
	star.mesh = Data.mesh("plate:star")
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 0.85, 0.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	star.material_override = m
	star.rotation.x = PI / 2
	star.position = Vector3(0, 0.25, 0)
	star.scale = Vector3.ONE * 0.7
	n.add_child(star)
	var tw := create_tween().set_loops()
	tw.tween_interval(Game.rng.randf_range(0.5, 4.0) / strength)
	tw.tween_property(m, "albedo_color:a", 0.95 * strength, 0.18)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)


func _add_treasure(tier: String, pos: Vector3, level: int, parts: Array, box_e: Dictionary = {}) -> Dictionary:
	var pc := _treasure_node(tier)
	pc.position = pos + Vector3(0, 0.02, 0)
	pc.scale = Vector3.ONE * W * 0.8
	pc.rotation.y = Game.rng.randf() * TAU
	if tier == "note":
		pc.rotation.z = Game.rng.randf_range(-0.08, 0.08)
	lvl_roots[level].add_child(pc)
	# 최적화: 작은 보물은 30m 밖에선 안 그린다 (어차피 점 하나, 벽 너머 다른 방 것도 그리고 있었다)
	var gs: Array = [pc]
	while not gs.is_empty():
		var g: Node = gs.pop_back()
		gs.append_array(g.get_children())
		if g is GeometryInstance3D:
			(g as GeometryInstance3D).visibility_range_end = 30.0
			(g as GeometryInstance3D).visibility_range_end_margin = 2.0
	var e := {"kind": "treasure", "tier": tier, "node": pc, "parts": parts, "alive": true,
		"hidden": not box_e.is_empty(), "lvl": level, "name": Themes.TIERS[tier][0], "from_box": not box_e.is_empty()}
	pc.set_meta("entry", e)
	if not box_e.is_empty():
		pc.visible = false
		pc.body.collision_layer = 0
		(box_e["inside"] as Array).append(e)
	elif tier != "gold" and Game.rng.randf() < 0.3:
		_glint(pc, 0.35)
	treasures.append(e)
	return e


## 보물 배치: 금 → 높은 곳 · 가구 / 봉투 → 가구 / 쪽지 → 열린 자리 · 바닥 아무 데나
func _place_treasures() -> void:
	var rng := Game.rng
	var total := Themes.treasure_count(Game.PLAYERS)
	var n_gold := int(round(total * 0.1))
	var n_env := int(round(total * 0.3))
	var n_note := total - n_gold - n_env
	# 파츠 종류: 이번 판 편성 비율 그대로
	var pool := []
	for t in Data.TYPES:
		for k in int(Game.counts.get(t, 0)):
			pool.append(t)
	pool.shuffle()
	var pick_i := [0]   # 람다는 값으로 잡으므로 배열에 담는다
	var take := func(n: int) -> Array:
		var out := []
		for k in n:
			var t: String = pool[pick_i[0] % pool.size()] if not pool.is_empty() else Data.TYPES[rng.randi() % Data.TYPES.size()]
			pick_i[0] += 1
			out.append(Themes.make_part(Game.theme, t, rng))
		return out
	var boxes := containers.duplicate()
	boxes.shuffle()
	var opens := []
	var highs := []
	for s in spots:
		# 손이 안 닿는 높이(그 층 바닥에서 2.4 넘게)는 쓰지 않는다
		if (s["pos"] as Vector3).y - level_y(int(s["lvl"])) > 2.4:
			continue
		if s["kind"] == "high":
			highs.append(s)
		else:
			opens.append(s)
	opens.shuffle()
	highs.shuffle()
	# 바닥 아무 데나 (길찾기 칸에서)
	var floor_pts := []
	if nav:
		# 바닥 쪽지는 주로 실내에 (바깥 광장 · 운동장은 가끔)
		var indoor := []
		for r in info.get("rooms", []):
			if not (str(r[1]) in ["광장", "운동장"]):
				indoor.append(r[0])
		for id in nav.get_point_ids():
			if rng.randf() < 0.08:
				var fp := nav.get_point_position(id)
				var inside := false
				for rr in indoor:
					if (rr as Rect2).has_point(Vector2(fp.x, fp.z)):
						inside = true
				if inside or rng.randf() < 0.12:
					floor_pts.append(fp)
		floor_pts.shuffle()
	var used: Array = []
	var far_enough := func(p: Vector3) -> bool:
		for q in used:
			if (q as Vector3).distance_to(p) < 1.3:
				return false
		return true
	var put_open := func(tier: String, parts: Array) -> void:
		while not opens.is_empty():
			var s: Dictionary = opens.pop_back()
			if far_enough.call(s["pos"]):
				used.append(s["pos"])
				_add_treasure(tier, s["pos"], s["lvl"], parts)
				return
		while not floor_pts.is_empty():
			var p: Vector3 = floor_pts.pop_back()
			if far_enough.call(p):
				used.append(p)
				_add_treasure(tier, p, _level_of(p.y), parts)
				return
	var put_box := func(tier: String, parts: Array) -> bool:
		if boxes.is_empty():
			return false
		var b: Dictionary = boxes.pop_back()
		var sp: Vector3 = b["slot"]
		_add_treasure(tier, sp, b["lvl"], parts, b)
		return true
	for k in n_gold:
		var parts: Array = take.call(3)
		if not highs.is_empty() and k % 2 == 0:
			var s: Dictionary = highs.pop_back()
			_add_treasure("gold", s["pos"], s["lvl"], parts)
		elif not put_box.call("gold", parts):
			put_open.call("gold", parts)
	for k in n_env:
		var parts: Array = take.call(2)
		if not put_box.call("env", parts):
			put_open.call("env", parts)
	# 남은 높은 자리도 쪽지로
	for s in highs:
		opens.append(s)
	opens.shuffle()
	# 밀 수 있는 가구 밑에도 쪽지 (밀어서 치우면 보인다)
	var pz := pushables.duplicate()
	pz.shuffle()
	for k in mini(pz.size(), int(n_note * 0.25)):
		var pe: Dictionary = pz[k]
		var sp0: Vector3 = pe["start"]
		_add_treasure("note", Vector3(sp0.x, level_y(int(pe["lvl"])), sp0.z), int(pe["lvl"]), take.call(1), pe)
		n_note -= 1
	for k in n_note:
		put_open.call("note", take.call(1))


func _level_of(y: float) -> int:
	var best := 0
	for k in (info["levels"] as Array).size():
		if level_y(k) <= y + 0.6:
			best = k
	return best


# ── 길찾기 (층 · 계단 · 사다리) ──────────────────────

const NAV_CELL := 0.6
var nav: AStar3D
var nav_dim := Vector2i.ZERO
var nav_org := Vector2.ZERO


func _nav_id(k: int, ix: int, iz: int) -> int:
	return k * nav_dim.x * nav_dim.y + iz * nav_dim.x + ix


func _build_nav() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	nav = AStar3D.new()
	var b: Rect2 = info["bounds"]
	nav_org = b.position
	nav_dim = Vector2i(int(b.size.x / NAV_CELL), int(b.size.y / NAV_CELL))
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(NAV_CELL + 0.28, 0.9, NAV_CELL + 0.28)   # 캐릭터 지름(0.76) 정도
	q.shape = sh
	q.collision_mask = ALL_WORLD
	var levels: Array = info["levels"]
	for k in levels.size():
		var y: float = levels[k]
		for iz in nav_dim.y:
			for ix in nav_dim.x:
				var x := nav_org.x + (ix + 0.5) * NAV_CELL
				var z := nav_org.y + (iz + 0.5) * NAV_CELL
				var rq := PhysicsRayQueryParameters3D.create(Vector3(x, y + 1.0, z), Vector3(x, y - 0.5, z), ALL_WORLD & ~L_WALL)   # 벽 윗면은 바닥이 아니다
				var hit := space.intersect_ray(rq)
				if hit.is_empty():
					continue
				var hy: float = hit["position"].y
				if absf(hy - y) > 0.4:
					continue
				q.transform = Transform3D(Basis(), Vector3(x, hy + 0.95, z))
				if not space.intersect_shape(q, 1).is_empty():
					continue
				nav.add_point(_nav_id(k, ix, iz), Vector3(x, hy, z))
	for id in nav.get_point_ids():
		var k := id / (nav_dim.x * nav_dim.y)
		var r := id % (nav_dim.x * nav_dim.y)
		var iz := r / nav_dim.x
		var ix := r % nav_dim.x
		for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
			var jx: int = ix + d.x
			var jz: int = iz + d.y
			if jx < 0 or jz < 0 or jx >= nav_dim.x or jz >= nav_dim.y:
				continue
			var j := _nav_id(k, jx, jz)
			if not nav.has_point(j):
				continue
			if d.x != 0 and d.y != 0:
				if not nav.has_point(_nav_id(k, ix + d.x, iz)) or not nav.has_point(_nav_id(k, ix, iz + d.y)):
					continue
			if absf(nav.get_point_position(id).y - nav.get_point_position(j).y) < 0.45:
				nav.connect_points(id, j)
	for l in links:
		var a := nav.get_closest_point(l[0])
		var c := nav.get_closest_point(l[1])
		if a >= 0 and c >= 0 and a != c:
			if nav.get_point_position(a).distance_to(l[0]) < 1.6 and nav.get_point_position(c).distance_to(l[1]) < 1.6:
				nav.connect_points(a, c)


## 목표까지 길 (가장 가까운 곳까지라도)
func _repath(a: Dictionary, to: Vector3) -> void:
	var body: CharacterBody3D = a["body"]
	a["path"] = PackedVector3Array()
	a["pi"] = 0
	a["pgoal"] = to
	a["pt"] = 0.6
	if nav == null or nav.get_point_count() == 0:
		return
	var s := nav.get_closest_point(body.global_position)
	var g := nav.get_closest_point(to)
	if s < 0 or g < 0:
		return
	a["path"] = nav.get_point_path(s, g, true)
	a["pi"] = 1
	_skip_visible(a)


func _skip_visible(a: Dictionary) -> void:
	var body: CharacterBody3D = a["body"]
	var path: PackedVector3Array = a["path"]
	var space := get_world_3d().direct_space_state
	var from := body.global_position
	while int(a["pi"]) + 1 < path.size():
		var nx: Vector3 = path[int(a["pi"]) + 1]
		if absf(nx.y - from.y) > 0.3:
			break
		var ok := true
		for hgt in [0.4, 1.2]:
			for side in [-0.35, 0.35]:
				var dd := Vector3(nx.x - from.x, 0, nx.z - from.z)
				var perp: Vector3 = Vector3(-dd.z, 0, dd.x).normalized() * float(side)
				var rq := PhysicsRayQueryParameters3D.create(from + Vector3(0, float(hgt), 0) + perp, Vector3(nx.x, from.y + float(hgt), nx.z) + perp, ALL_WORLD)
				if not space.intersect_ray(rq).is_empty():
					ok = false
		if not ok or int(a["pi"]) > 40:
			break
		a["pi"] = int(a["pi"]) + 1


func _path_dir(a: Dictionary, delta: float) -> Vector3:
	var body: CharacterBody3D = a["body"]
	var path: PackedVector3Array = a.get("path", PackedVector3Array())
	a["pt"] = float(a.get("pt", 0.0)) - delta
	while int(a.get("pi", 0)) < path.size():
		var w: Vector3 = path[int(a["pi"])]
		a["climb_ok"] = w.y > body.global_position.y + 0.1   # 사다리는 길이 위로 갈 때만 오른다 (0.5였더니 꼭대기 바로 밑에서 멈췄다)
		# 다음 지점이 훨씬 위(사다리 꼭대기)면, 그 사다리 밑으로 먼저 간다 — 지나쳐서 밑에 끼지 않게
		if w.y > body.global_position.y + 1.4:
			for l in ladders:
				if absf(float(l["y1"]) - w.y) < 1.2 and absf(float(l["y0"]) - body.global_position.y) < 1.2:
					var lp: Vector2 = l["pos"]
					var to_l := Vector3(lp.x - body.global_position.x, 0, lp.y - body.global_position.z)
					if to_l.length() > 0.3:
						# 사다리 앞쪽(오르는 방향 반대편)으로 붙는다
						var lf: Vector3 = l["fwd"]
						var stand := Vector3(lp.x, 0, lp.y) - lf * 0.35
						var to_s := Vector3(stand.x - body.global_position.x, 0, stand.z - body.global_position.z)
						if to_s.length() > 0.25:
							return to_s.normalized()
						return lf
		var d := Vector3(w.x - body.global_position.x, 0, w.z - body.global_position.z)
		if d.length() > 0.35 or absf(w.y - body.global_position.y) > 1.4:
			if float(a["pt"]) <= 0.0:
				a["pt"] = 0.25
				_skip_visible(a)
				w = path[int(a["pi"])]
				d = Vector3(w.x - body.global_position.x, 0, w.z - body.global_position.z)
			if d.length() < 0.05:
				d = (a["ladder_fwd"] if a.has("ladder_fwd") else Vector3.FORWARD)
			return d.normalized()
		a["pi"] = int(a["pi"]) + 1
	return Vector3.ZERO


## 사다리 앞이면 그 사다리
func _ladder_near(body: CharacterBody3D) -> Dictionary:
	var p := body.global_position
	for l in ladders:
		var lp: Vector2 = l["pos"]
		if Vector2(p.x, p.z).distance_to(lp) < 0.75 and p.y > float(l["y0"]) - 0.3 and p.y < float(l["y1"]) + 0.4:
			return l
	return {}


# ── 사람 · 봇 ────────────────────────────────────────

func _spawn_actors() -> void:
	var spots_s: Array = info["spawns"]
	for i in Game.PLAYERS:
		var p: Dictionary = Game.players[i]
		var body := CharacterBody3D.new()
		body.collision_layer = L_CHAR
		body.collision_mask = ALL_WORLD | L_PUSH
		body.floor_snap_length = 0.45
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.38
		cap.height = 1.7
		cs.shape = cap
		cs.position.y = 0.85
		body.add_child(cs)
		var vis := _character(i)
		body.add_child(vis)
		var name_l := UI.label3d(p["name"], 40)
		name_l.position = Vector3(0, 2.2, 0)
		name_l.visible = i != 0
		name_l.fixed_size = true   # 가까이 와도 화면을 가리지 않게 작은 고정 크기
		name_l.pixel_size = 0.0011
		name_l.font_size = 30
		body.add_child(name_l)
		var sp: Vector3 = spots_s[i % spots_s.size()]
		body.position = sp + Vector3(Game.rng.randf_range(-0.6, 0.6), 0.2, Game.rng.randf_range(-0.6, 0.6))
		world.add_child(body)
		body.set_meta("label", name_l)
		var blob := _blob_shadow()
		world.add_child(blob)
		actors.append({"i": i, "body": body, "vis": vis, "blob": blob, "bot": p["is_bot"] or Game.autotest,
			"goal": {}, "prog": 0.0, "wait": Game.rng.randf_range(0.0, 1.0), "walk_t": 0.0,
			"spawn": sp})
	cam_yaw = float(info.get("cam_yaw", 0.0))


func _envs(a: Dictionary) -> Array:
	return Game.players[a["i"]]["envelopes"]


## 보물을 줍는다
func _take(a: Dictionary, e: Dictionary) -> void:
	if not e["alive"] or e["hidden"] or _envs(a).size() >= BAG_MAX:
		return
	e["alive"] = false
	var n: Piece = e["node"]
	_fly(n, a)
	n.queue_free()
	_envs(a).append({"tier": e["tier"], "name": e["name"], "parts": e["parts"]})
	var st: Dictionary = Game.players[a["i"]]["hunt"]
	st["found"] = int(st["found"]) + 1
	if e["tier"] == "gold":
		st["gold"] = int(st["gold"]) + 1
	if e["from_box"]:
		st["hidden"] = int(st["hidden"]) + 1
	if int(e["lvl"]) > 0:
		st["up"] = int(st["up"]) + 1
	if not a["bot"]:
		Sfx.play("pick" if e["tier"] != "gold" else "star", -2.0)
		slot = _envs(a).size() - 1
		_refresh_hotbar()
		if e["tier"] == "gold":   # 머리 위 "+쪽지" · 가방 칸으로 충분 — 금봉투만 따로 알린다
			_toast("금봉투! 덩어리 3개")
		_pop("+ " + e["name"], a["body"].global_position + Vector3(0, 2.5, 0))
		_squash(a["vis"], 0.9)


## 가구를 연다 — 안에 봉투가 있으면 보이게
func _open(a: Dictionary, e: Dictionary) -> void:
	if not e["alive"]:
		return
	e["alive"] = false
	_open_anim(e)
	var inside: Array = e["inside"]
	for t in inside:
		t["hidden"] = false
		var n: Piece = t["node"]
		n.visible = true
		n.body.collision_layer = L_ITEM
		var tw := create_tween()
		n.scale = Vector3.ONE * 0.2
		tw.tween_property(n, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not a["bot"]:
		if inside.is_empty():
			Sfx.play("drop", -10.0)
			_toast("%s 안은 비어 있어요" % e["name"])
		else:
			Sfx.play("tear", -4.0)
			_toast("%s 안에서 %s 발견" % [e["name"], (inside[0] as Dictionary)["name"]])
	elif not inside.is_empty():
		# 봇은 열자마자 집어 간다
		a["goal"] = {"ref": inside[0]}


func _physics_process(delta: float) -> void:
	if finished or not ready_done:
		return
	time_left -= delta
	for a in actors:
		if a["bot"]:
			_bot_step(a, delta)
		else:
			_human_step(a, delta)
		var body: CharacterBody3D = a["body"]
		if body.global_position.y < -0.6:   # 물(바닥 아래)에 빠지면 바로 처음 자리로
			body.global_position = a["spawn"] + Vector3(0, 0.5, 0)
			body.velocity = Vector3.ZERO
			body.reset_physics_interpolation()
			if not a["bot"]:
				_toast("풍덩! 출발 지점으로 돌아왔어요")
				Sfx.play("land", 0.0)
	_update_levels(delta)
	_update_walls(delta)
	_update_pushables(delta)
	_update_hud(delta)
	if time_left <= 0:
		_end()


## 밀어서 치운 가구 밑 쪽지가 드러난다
func _update_pushables(delta: float) -> void:
	push_t -= delta
	if push_t > 0.0:
		return
	push_t = 0.2
	for pe in pushables:
		var inside: Array = pe["inside"]
		if inside.is_empty():
			continue
		var rb: RigidBody3D = pe["body"]
		var s0: Vector3 = pe["start"]
		if Vector2(rb.global_position.x - s0.x, rb.global_position.z - s0.z).length() > 0.9 * W:
			for t in inside:
				t["hidden"] = false
				(t["node"] as Piece).visible = true
				(t["node"] as Piece).body.collision_layer = L_ITEM
			inside.clear()
			Sfx.play("pick", -12.0)


## 머리 위에 천장(위층 바닥)이 있으면 그 층부터 숨긴다 — 인형의 집처럼 들여다본다
func _update_levels(delta: float) -> void:
	return   # v0.6.2: 천장 있는 실내 — 층을 숨기지 않는다
	detect_t -= delta
	if detect_t > 0.0:
		return
	detect_t = 0.12
	var body: CharacterBody3D = actors[0]["body"]
	var from := body.global_position + Vector3(0, 1.9, 0)
	var rq := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 14, 0), ALL_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(rq)
	var hf := 99
	if hit and hit["collider"].has_meta("roof"):
		hf = int(hit["collider"].get_meta("lvl"))
	if hf != hidden_from:
		hidden_from = hf
		var mask := 0
		for k in lvl_roots.size():
			(lvl_roots[k] as Node3D).visible = k < hidden_from
			if k < hidden_from:
				mask |= LVL_LAYERS[k]
		pass


func _human_step(a: Dictionary, delta: float) -> void:
	var body: CharacterBody3D = a["body"]
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): dir.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): dir.x += 1
	if sim_move != Vector2.ZERO:
		dir = sim_move
	var v := Vector3.ZERO
	var manual := dir != Vector2.ZERO
	if manual:
		a["climb_ok"] = true
		dir = dir.normalized()
		v = Basis(Vector3.UP, cam_yaw) * Vector3(dir.x, 0, dir.y)
	var doing := false
	if not act.is_empty():
		if not act["alive"] or not is_instance_valid(act["node"]):
			_cancel_act()
		else:
			var tp: Vector3 = (act["node"] as Node3D).global_position
			var to := Vector3(tp.x - body.position.x, 0, tp.z - body.position.z)
			var dy := absf(tp.y - body.position.y)
			var reach := 1.6 if act["kind"] == "treasure" else 2.0
			if to.length() <= reach and dy < 2.2:
				doing = true
			elif manual:
				if to.length() > 14.0:
					_cancel_act()
			else:
				if (a.get("pgoal", Vector3.INF) as Vector3).distance_to(tp) > 0.8 or (int(a.get("pi", 0)) >= (a.get("path", PackedVector3Array()) as PackedVector3Array).size() and float(a.get("pt", 0.0)) <= 0.0):
					_repath(a, tp)
				var pd := _path_dir(a, delta)
				if body.global_position.distance_to(a.get("prog_pos", Vector3.INF)) > 0.25:
					a["prog_pos"] = body.global_position
					a["prog_t"] = 0.0
				else:
					a["prog_t"] = float(a.get("prog_t", 0.0)) + delta
				if float(a["prog_t"]) > 0.8:
					a["prog_t"] = 0.0
					if to.length() <= 3.0 and dy < 2.6:
						pd = Vector3.ZERO
					else:
						_repath(a, tp)
						jump_req = true
				if pd != Vector3.ZERO:
					v = pd
				elif to.length() <= 3.0 and dy < 2.6:
					doing = true
				else:
					v = to.normalized()
	if jump_req:
		jump_buf = 0.15
	jump_req = false
	jump_buf -= delta
	_move_body(a, v, delta, jump_buf > 0.0)
	if a.get("jumped", false):
		jump_buf = 0.0
		a["jumped"] = false
	if body.is_on_floor() and not was_floor:
		Sfx.play("land", -10.0)
		_squash(a["vis"], 0.82)
	was_floor = body.is_on_floor()
	if v != Vector3.ZERO and body.is_on_floor():
		step_t -= delta
		if step_t <= 0:
			step_t = 0.36
			Sfx.play("step", -16.0, 0.12)
	if not doing:
		hold_prog = maxf(0.0, hold_prog - delta * 1.5)
		_wobble(false)
		return
	if act["kind"] == "treasure":
		if _envs(a).size() >= BAG_MAX:
			_toast("가방이 가득 찼어요 · Q로 하나 내려놓기")
			Sfx.play("error", -6.0)
			_cancel_act()
			return
		_take(a, act)
		_cancel_act()
		return
	# 가구: 게이지 없이 바로 열린다 (v0.6.2)
	if true:
		hold_prog = 0.0
		_wobble(false)
		var e := act
		_cancel_act()
		_open(a, e)
		# 안에 있던 봉투를 바로 노린다
		if not (e["inside"] as Array).is_empty():
			act = e["inside"][0]


func _cancel_act() -> void:
	_wobble(false)
	if not act.is_empty() and is_instance_valid(act["node"]) and act != aim:
		(act["node"] as Piece).set_highlight(false)
	act = {}
	hold_prog = 0.0


## 여는 동안 판이 덜컹거린다
func _wobble(on: bool) -> void:
	if act.is_empty() or act["kind"] != "box" or not is_instance_valid(act["node"]):
		return
	var pc: Piece = act["node"]
	if not on:
		pc.vis.position = Vector3.ZERO
		return
	pc.vis.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.03 * (0.4 + hold_prog)


## 손에 들어오는 순간: 그 모양 그대로 캐릭터 쪽으로 날아와 쏙
func _fly(src: Piece, a: Dictionary) -> void:
	var pc := Piece.new().setup(src.type, src.color_idx, false, src.shape)
	world.add_child(pc)
	pc.global_transform = src.global_transform
	pc.set_pscale(src.pscale, false)
	var target: Vector3 = a["body"].global_position + Vector3(0, 1.6, 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(pc, "global_position", target, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(pc, "scale", Vector3.ONE * 0.25, 0.3).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(pc.queue_free)


# ── 봇: 보이는 봉투를 줍고, 가구를 하나씩 열어 본다 ──────

func _bot_step(a: Dictionary, delta: float) -> void:
	var body: CharacterBody3D = a["body"]
	if float(a["wait"]) > 0.0:
		a["wait"] = float(a["wait"]) - delta
		_move_body(a, Vector3.ZERO, delta)
		return
	if _envs(a).size() >= BAG_MAX:
		_move_body(a, Vector3.ZERO, delta)
		return
	var goal: Dictionary = a["goal"]
	if goal.is_empty() or not goal["ref"]["alive"] or goal["ref"].get("hidden", false):
		a["prog"] = 0.0
		a["goal"] = _bot_choose(a)
		goal = a["goal"]
		if goal.is_empty():
			_move_body(a, Vector3.ZERO, delta)
			return
		_repath(a, (goal["ref"]["node"] as Node3D).global_position)
	var ref: Dictionary = goal["ref"]
	var gp: Vector3 = (ref["node"] as Node3D).global_position
	var to := Vector3(gp.x - body.position.x, 0, gp.z - body.position.z)
	var dy := absf(gp.y - body.position.y)
	var reach := 1.5 if ref["kind"] == "treasure" else 1.9
	if to.length() > reach or dy > 2.2:
		var v := _path_dir(a, delta)
		if v == Vector3.ZERO:
			if to.length() < 3.0 and dy < 2.6:
				v = Vector3.ZERO
			else:
				_repath(a, gp)
				v = to.normalized()
		# 막힘 → 다시 길 찾기 · 폴짝
		if body.global_position.distance_to(a.get("prog_pos", Vector3.INF)) > 0.25:
			a["prog_pos"] = body.global_position
			a["prog_t"] = 0.0
		else:
			a["prog_t"] = float(a.get("prog_t", 0.0)) + delta
			if float(a["prog_t"]) > 1.5:
				a["prog_t"] = 0.0
				a["goal"] = {}
				a["wait"] = 0.3
		if v != Vector3.ZERO or to.length() >= 3.0:
			_move_body(a, v, delta, float(a.get("prog_t", 0.0)) > 0.7)
			return
	_move_body(a, Vector3.ZERO, delta)
	if ref["kind"] == "treasure":
		_take(a, ref)
		a["goal"] = {}
		a["wait"] = randf_range(0.2, 0.6) + (1.0 - float(Game.players[a["i"]]["quality"])) * 1.2
	else:
		if true:
			a["goal"] = {}
			_open(a, ref)
			a["wait"] = randf_range(0.1, 0.4)


func _bot_choose(a: Dictionary) -> Dictionary:
	var body: CharacterBody3D = a["body"]
	var claimed := {}
	for o in actors:
		if o != a and not (o["goal"] as Dictionary).is_empty():
			claimed[o["goal"]["ref"]["node"]] = true
	if not act.is_empty():
		claimed[act["node"]] = true
	var best: Dictionary = {}
	var bs := INF
	var p := body.global_position
	for e in treasures:
		if not e["alive"] or e["hidden"] or claimed.has(e["node"]):
			continue
		var q: Vector3 = (e["node"] as Node3D).global_position
		var s := Vector2(p.x - q.x, p.z - q.z).length() + absf(p.y - q.y) * 4.0 + randf() * 5.0
		if e["tier"] == "gold":
			s -= 4.0
		if s < bs:
			bs = s
			best = {"ref": e}
	for e in containers:
		if not e["alive"] or claimed.has(e["node"]):
			continue
		var q: Vector3 = (e["node"] as Node3D).global_position
		var s := Vector2(p.x - q.x, p.z - q.z).length() + absf(p.y - q.y) * 4.0 + 3.0 + randf() * 6.0
		if s < bs:
			bs = s
			best = {"ref": e}
	return best


# ── 조준 · 입력 ──────────────────────────────────────

func _pickable(e: Dictionary) -> bool:
	if not e["alive"] or not is_instance_valid(e["node"]):
		return false
	if e["kind"] == "treasure" and e["hidden"]:
		return false
	return int(e["lvl"]) < hidden_from


func _update_aim() -> void:
	var best: Dictionary = {}
	var mouse := _aim_pos()
	var from := cam.project_ray_origin(mouse)
	var q := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(mouse) * 60.0, L_ITEM | ALL_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var ex: Array[RID] = []
	for k in 5:
		if hit.is_empty() or not hit["collider"].has_meta("furn"):
			break
		ex.append(hit["rid"])
		q.exclude = ex
		hit = get_world_3d().direct_space_state.intersect_ray(q)
	if hit and hit["collider"].has_meta("piece"):
		var pc: Piece = hit["collider"].get_meta("piece")
		if pc.has_meta("entry"):
			var e: Dictionary = pc.get_meta("entry")
			if _pickable(e):
				best = e
	if best.is_empty():
		best = _near_cursor(mouse)
	if not aim.is_empty() and not is_instance_valid(aim["node"]):
		aim = {}
	if best != aim:
		if not aim.is_empty() and is_instance_valid(aim["node"]) and aim != act:
			(aim["node"] as Piece).set_highlight(false)
		aim = best
		if not aim.is_empty():
			(aim["node"] as Piece).set_highlight(true)
	var target: Dictionary = aim if not aim.is_empty() else act
	if target.is_empty() or not is_instance_valid(target["node"]):   # 방금 주워서 지워진 것
		hud_prompt.text = ""
		prompt_key.visible = false
		return
	var me: Vector3 = actors[0]["body"].global_position
	var far: bool = (target["node"] as Node3D).global_position.distance_to(me) > REACH
	var what: String = "줍기" if target["kind"] == "treasure" else "열기"
	# 키 칩 [F] + "사물함 열기" / "사물함까지 가서 열기" / "사물함으로 가는 중"
	prompt_key.visible = true
	if target == act and aim.is_empty():
		# 자동으로 가는 중엔 글자 없이 (캐릭터가 걸어가는 게 보이고 대상은 빛난다)
		prompt_key.visible = false
		hud_prompt.text = ""
	elif far:
		hud_prompt.text = "%s까지 가서 %s" % [target["name"], what]
	else:
		hud_prompt.text = "%s %s" % [target["name"], what]


## 레이가 빗나갔을 때: 조준점에서 화면상 48px 안, 가장 가까운 것
func _near_cursor(mouse: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var bd := 48.0
	var me: Vector3 = actors[0]["body"].global_position
	for list in [treasures, containers]:
		for e in list:
			if not _pickable(e):
				continue
			var wp: Vector3 = (e["node"] as Node3D).global_position
			if wp.distance_to(me) > 20.0 or cam.is_position_behind(wp):
				continue
			var d := cam.unproject_position(wp).distance_to(mouse)
			if d < bd:
				bd = d
				best = e
	return best


func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	var looking := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and not bag_open:   # v0.6.3: 마우스를 움직이면 그냥 시점이 돈다 (우클릭 필요 없음)
		if event.relative.length() > 1.5:
			look_t = 0.0
		cam_yaw -= event.relative.x * 0.0042 * Game.mouse_sens
		cam_pitch = clampf(cam_pitch - event.relative.y * 0.0036 * Game.mouse_sens, -1.2, 0.25)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if not looking and not bag_open:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # 커서 숨김 (웹은 클릭해야 잠긴다)
				_try_pick()
			MOUSE_BUTTON_WHEEL_UP:
				_select_slot(posmod(slot - 1, maxi(1, _envs(actors[0]).size())))
			MOUSE_BUTTON_WHEEL_DOWN:
				_select_slot(posmod(slot + 1, maxi(1, _envs(actors[0]).size())))
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE: jump_req = true
			KEY_ESCAPE:
				if bag_open:
					_toggle_bag()
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_F, KEY_E: _try_pick()
			KEY_Q: _drop_selected()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				_select_slot(event.physical_keycode - KEY_1)
			KEY_0: _select_slot(9)


func _try_pick() -> void:
	_try_pick_entry(aim)


func _try_pick_entry(e: Dictionary) -> void:
	if e.is_empty() or not _pickable(e):
		return
	if e["kind"] == "treasure" and _envs(actors[0]).size() >= BAG_MAX:
		Sfx.play("error", -6.0)
		_toast("가방이 가득 찼어요 · Q로 하나 내려놓기")
		return
	if act != e:
		_cancel_act()
	act = e
	(act["node"] as Piece).set_highlight(true)
	Sfx.play("select", -12.0)


func _select_slot(i: int) -> void:
	if i < _envs(actors[0]).size():
		slot = i
		_refresh_hotbar()
		Sfx.play("select", -14.0)


## 고른 봉투 내려놓기 — 누군가 주워 갈 수도
func _drop_selected() -> void:
	var a: Dictionary = actors[0]
	var envs := _envs(a)
	if envs.is_empty():
		return
	slot = clampi(slot, 0, envs.size() - 1)
	var it: Dictionary = envs.pop_at(slot)
	slot = clampi(slot, 0, maxi(0, envs.size() - 1))
	var body: CharacterBody3D = a["body"]
	var fwd := Basis(Vector3.UP, cam_yaw) * Vector3(0, 0, -1)
	_add_treasure(it["tier"], body.global_position + fwd * 1.2, _level_of(body.global_position.y), it["parts"])
	Sfx.play("drop", -4.0)
	_refresh_hotbar()
	_toast("%s 내려놓았어요" % it["name"])


# ── 카메라 ───────────────────────────────────────────

## 카메라 · 투시 · 조준은 화면 프레임마다 (물리 틱마다 하면 고주사율 화면에서 떨리고 깜빡인다)
func _process(delta: float) -> void:
	if finished or not ready_done:
		return
	_auto_follow(delta)
	_update_camera(delta)
	_update_blobs()
	# 큰 가구 · 조형물이 캐릭터를 가리면 그 부분만 작게 비친다 (벽은 카메라가 부딪혀서 해당 없음)
	RenderingServer.global_shader_parameter_set("seethru_on", 1.0)
	RenderingServer.global_shader_parameter_set("seethru_pos", vis_pos + Vector3(0, 0.9, 0))
	_update_aim()


var vis_pos := Vector3.ZERO
var look_t := 99.0   # 마지막으로 마우스로 시점을 돌린 뒤 지난 시간

## 시점 자동 따라가기: 걸으면 카메라가 캐릭터 등 뒤로 천천히 돈다 (마우스로 돌리면 잠깐 멈춤).
## 뒤로 걸을 땐 돌지 않는다 — 카메라가 빙글 돌며 어지럽지 않게
func _auto_follow(delta: float) -> void:
	look_t += delta
	var body: CharacterBody3D = actors[0]["body"]
	var hv := Vector2(body.velocity.x, body.velocity.z)
	if look_t < 0.6 or hv.length() < 1.0 or bag_open:
		return
	var cam_fwd := Vector2(-sin(cam_yaw), -cos(cam_yaw))
	var fwd := hv.normalized().dot(cam_fwd)
	if fwd < -0.3:
		return
	var k := clampf(fwd + 0.35, 0.0, 1.0) * clampf(hv.length() / SPEED, 0.0, 1.0)
	cam_yaw = lerp_angle(cam_yaw, body.rotation.y, 1.0 - exp(-1.9 * k * delta))

static var _blob_mat: StandardMaterial3D
## 발밑 그림자: 부드러운 검은 원 (바닥 · 가구 윗면에 붙는다)
func _blob_shadow() -> MeshInstance3D:
	if _blob_mat == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.55))
		g.set_color(1, Color(0, 0, 0, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_blob_mat = StandardMaterial3D.new()
		_blob_mat.albedo_texture = tex
		_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blob_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var m := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(0.9, 0.9)
	m.mesh = q
	m.material_override = _blob_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return m


func _update_blobs() -> void:
	var space := get_world_3d().direct_space_state
	for a in actors:
		var body: CharacterBody3D = a["body"]
		var blob: MeshInstance3D = a["blob"]
		var p := body.get_global_transform_interpolated().origin
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.3, 0), p + Vector3(0, -6, 0), ALL_WORLD & ~L_WALL | L_PUSH)
		q.exclude = [body.get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			blob.visible = false
			continue
		var drop: float = p.y - (hit["position"] as Vector3).y
		blob.visible = true
		blob.global_position = (hit["position"] as Vector3) + Vector3(0, 0.02, 0)
		var k := clampf(1.0 - drop / 4.0, 0.3, 1.0)   # 높이 뛸수록 작고 옅게
		blob.scale = Vector3(k, 1, k)

func _update_camera(delta := 1.0 / 60.0) -> void:
	var body: CharacterBody3D = actors[0]["body"]
	vis_pos = body.get_global_transform_interpolated().origin
	var target := vis_pos + Vector3(0, 2.05, 0)
	var k := 1.0 - pow(0.65, delta * 60.0)   # 60fps 기준 0.35 — 프레임레이트와 무관하게 같은 느낌
	cam_pivot.global_position = cam_pivot.global_position.lerp(target, k) if cam_pivot.global_position.distance_to(target) < 6 else target
	cam_pivot.rotation = Vector3(cam_pitch, cam_yaw, 0)
	spring.spring_length = lerpf(spring.spring_length, zoom, 0.2)


# ── HUD ──────────────────────────────────────────────

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var tl := UI.panel()
	var tv := UI.vbox(2)
	tl.add_child(tv)
	hud_time = UI.label("", 38, UI.INK, true)
	tv.add_child(hud_time)
	var th: Dictionary = Themes.INFO[Game.theme]
	tv.add_child(UI.label("%s 만들기" % Game.target["name"], 26, UI.INK, true))
	hud_left = UI.label("", 19, UI.SOFT)
	tv.add_child(hud_left)
	var card: Dictionary = Game.human()["card"]
	var cl := UI.label("카드 · %s" % card["desc"], 18, UI.SOFT)
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cl.custom_minimum_size.x = 230
	tv.add_child(cl)
	var endb := UI.button("일찍 끝내기", _end, 18)
	endb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tv.add_child(endb)
	layer.add_child(tl)
	UI.corner(tl, Control.PRESET_TOP_LEFT)

	fx = Control.new()
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.draw.connect(_draw_fx)
	layer.add_child(UI.full(fx))

	minimap = Control.new()
	minimap.custom_minimum_size = Vector2(220, 150)
	minimap.draw.connect(_draw_minimap)
	var mp := UI.panel()
	mp.add_child(minimap)
	layer.add_child(mp)
	UI.corner(mp, Control.PRESET_TOP_RIGHT)

	var bar := UI.panel()
	var bv := UI.vbox(2)
	bar.add_child(bv)
	hotbar = UI.hbox(5)
	bv.add_child(hotbar)
	for k in BAG_MAX:
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(56, 56)
		var idx := k
		cell.draw.connect(func(): _draw_slot(cell, idx))
		cell.gui_input.connect(func(ev): _slot_input(ev, idx))
		hotbar.add_child(cell)
		hot_slots.append(cell)
	bv.add_child(UI.key_hints([["WASD", "이동"], ["F", "줍기 · 열기"], ["Space", "점프"], ["Tab", "근처 목록"], ["Q", "내려놓기"]], 18))
	layer.add_child(bar)
	UI.corner(bar, Control.PRESET_CENTER_BOTTOM, Vector2(0, 10))

	var cv := UI.vbox(6)
	cv.alignment = BoxContainer.ALIGNMENT_END
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var prow := UI.hbox(10)
	prow.alignment = BoxContainer.ALIGNMENT_CENTER
	prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_key = UI.keycap("F", 24)
	prompt_key.visible = false
	prow.add_child(prompt_key)
	hud_prompt = UI.label("", 26, UI.INK, true)
	hud_prompt.add_theme_color_override("font_outline_color", Color.WHITE)
	hud_prompt.add_theme_constant_override("outline_size", 8)
	hud_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prow.add_child(hud_prompt)
	cv.add_child(prow)
	hud_bar = ProgressBar.new()
	hud_bar.visible = false
	cv.add_child(hud_bar)
	toast = UI.label("", 24, UI.GOOD, true)
	toast.add_theme_color_override("font_outline_color", Color.WHITE)
	toast.add_theme_constant_override("outline_size", 8)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(toast)
	layer.add_child(cv)
	UI.corner(cv, Control.PRESET_CENTER_BOTTOM, Vector2(0, 112))

	bag_panel = UI.panel()
	var bpv := UI.vbox(4)
	bag_panel.add_child(bpv)
	bpv.add_child(UI.label("근처에 있는 것", 24, UI.INK, true))

	bag_list = UI.vbox(3)
	bpv.add_child(bag_list)
	bag_panel.custom_minimum_size = Vector2(320, 0)
	bag_panel.visible = false
	layer.add_child(bag_panel)
	UI.corner(bag_panel, Control.PRESET_CENTER_LEFT, Vector2(16, 0))
	# 시작 안내 (몇 초 뒤 사라진다)
	var tip := UI.panel()
	var tipv := UI.vbox(4)
	tip.add_child(tipv)
	var tt := UI.label(Themes.INFO[Game.theme]["name"], 30, UI.INK, true)
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tipv.add_child(tt)
	if Game.round_i == 1:   # 설명은 첫 라운드에만 (이후엔 장소 이름만)
		var tdl := UI.label("서랍 · 사물함 · 상자를 열어 봉투를 찾으세요\n가구를 밟고 높은 곳에 올라가 보고, 상자를 밀면 밑에 쪽지가 있을지도 몰라요", 19, UI.SOFT)
		tdl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tipv.add_child(tdl)
	layer.add_child(tip)
	UI.corner(tip, Control.PRESET_CENTER_TOP, Vector2(0, 16))
	tip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var ttw := create_tween()
	ttw.tween_interval(6.0)
	ttw.tween_property(tip, "modulate:a", 0.0, 0.8)
	ttw.tween_callback(tip.queue_free)
	_refresh_hotbar()


func _refresh_bag(delta: float) -> void:
	if not bag_open:
		return
	bag_t -= delta
	if bag_t > 0.0:
		return
	bag_t = 0.3
	for c in bag_list.get_children():
		c.queue_free()
	var me: Vector3 = actors[0]["body"].global_position
	var near := []
	for list in [treasures, containers]:
		for e in list:
			if _pickable(e):
				var d: float = (e["node"] as Node3D).global_position.distance_to(me)
				if d < 5.0:
					near.append([d, e])
	near.sort_custom(func(x, y): return x[0] < y[0])
	if near.is_empty():
		bag_list.add_child(UI.label("근처에 보이는 게 없어요", 18, UI.SOFT))
	for k in mini(near.size(), 9):
		var e: Dictionary = near[k][1]
		var b := UI.button("%s   %.0fm" % [e["name"], near[k][0]], func(): _try_pick_entry(e), 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UI.tile_button(b)
		bag_list.add_child(b)


func _draw_slot(cell: Control, idx: int) -> void:
	var envs := _envs(actors[0])
	cell.draw_style_box(_slot_box(idx == slot and idx < envs.size()), Rect2(Vector2.ZERO, cell.size))
	if idx < envs.size():
		UI.draw_envelope(cell, Rect2(Vector2(9, 12), cell.size - Vector2(18, 22)), envs[idx]["tier"])


func _update_hud(delta: float) -> void:
	# 봇 이름표에 찾은 봉투 수 (경쟁감)
	if Engine.get_physics_frames() % 20 == 0:
		for a in actors:
			if a["i"] != 0:
				var lb: Label3D = (a["body"] as Node).get_meta("label")
				lb.text = str(Game.players[a["i"]]["name"])
	for w in [30, 10, 5, 4, 3, 2, 1]:
		if time_left <= w and not warned.has(w):
			warned[w] = true
			Sfx.play("tick" if w <= 5 else "error", -2.0)
			if w == 30 or w == 10:
				_toast("%d초 남았어요" % w)
	hud_time.text = UI.clock(time_left)
	hud_time.add_theme_color_override("font_color", UI.BAD if time_left < 30 else UI.INK)
	var left := 0
	for e in treasures:
		if e["alive"]:
			left += 1
	var mine := 0
	for env in _envs(actors[0]):
		mine += (env["parts"] as Array).size()
	hud_left.text = "내 봉투 %d / %d   ·   남은 보물 %d" % [_envs(actors[0]).size(), BAG_MAX, left]
	toast_t -= delta
	if toast_t <= 0:
		toast.text = ""
	_refresh_bag(delta)
	minimap.queue_redraw()
	fx.queue_redraw()


## 보물 감지기: 가장 가까운 (숨은 것 포함) 보물까지 — 가까울수록 칸이 차고 빨라진다
func _detect_level() -> int:
	var me: Vector3 = actors[0]["body"].global_position
	var d := INF
	for e in treasures:
		if e["alive"]:
			d = minf(d, (e["node"] as Node3D).global_position.distance_to(me))
	if d < 1.8: return 4
	if d < 3.2: return 3
	if d < 5.0: return 2
	if d < 8.0: return 1
	return 0


func _draw_minimap() -> void:
	var sz := minimap.size
	var b: Rect2 = info["bounds"]
	var k := minf(sz.x / b.size.x, sz.y / b.size.y)
	var off := (sz - b.size * k) * 0.5
	var me: Vector3 = actors[0]["body"].global_position
	var my_l := _level_of(me.y)
	minimap.draw_rect(Rect2(Vector2.ZERO, sz), Color("#E9EEF2"))
	for r in info.get("rooms", []):
		var rr: Rect2 = r[0]
		var rl: int = r[2]
		var rect := Rect2(off + (rr.position - b.position) * k, rr.size * k)
		var col: Color = Color(r[3]) if r.size() > 3 else Color("#FFFFFF")
		if rl != my_l:
			col = col.lerp(Color("#E9EEF2"), 0.6)
		minimap.draw_rect(rect, col)
		minimap.draw_rect(rect, Color(UI.INK, 0.3 if rl == my_l else 0.12), false, 1.0)
	for a in actors:
		var p: Vector3 = a["body"].global_position
		var mp := off + (Vector2(p.x, p.z) - b.position) * k
		if a["i"] == 0:
			var fwd := Vector2(-sin(cam_yaw), -cos(cam_yaw))
			minimap.draw_colored_polygon(PackedVector2Array([mp + fwd * 8, mp + fwd.rotated(2.5) * 5, mp + fwd.rotated(-2.5) * 5]), UI.ACCENT)
		else:
			minimap.draw_circle(mp, 3.0, Color(Data.color(Game.players[a["i"]]["color"]), 0.9))
	# 감지기
	var lv_d := _detect_level()
	var dots := ""
	for i in 4:
		dots += "●" if i < lv_d else "○"
	var dc: Color = [UI.SOFT, Color("#6AA84F"), Color("#E0A030"), Color("#E2553D"), Color("#D0021B")][lv_d]
	minimap.draw_string(Data.font_bold, Vector2(6, sz.y - 6), "보물 감지 " + dots, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, dc)
	if lv_d >= 2:
		var period: float = [9.0, 9.0, 1.0, 0.6, 0.3][lv_d]
		if fmod(Time.get_ticks_msec() / 1000.0, period) < 0.02:
			Sfx.play("tick", -18.0 + lv_d * 2.0)


func _end() -> void:
	if finished:
		return
	finished = true
	var rng := Game.rng
	var spare := []
	for e in treasures:
		if e["alive"]:
			spare.append(e)
	spare.shuffle()
	for i in Game.players.size():
		var p: Dictionary = Game.players[i]
		var envs: Array = p["envelopes"]
		var parts := 0
		for env in envs:
			parts += (env["parts"] as Array).size()
		# 너무 적게 찾았으면 남은 보물로 채운다 (최소 파츠 8개)
		while parts < 8:
			if not spare.is_empty():
				var e: Dictionary = spare.pop_back()
				e["alive"] = false
				envs.append({"tier": e["tier"], "name": "남은 " + str(e["name"]), "parts": e["parts"], "auto": true})
				parts += (e["parts"] as Array).size()
			else:
				envs.append({"tier": "note", "name": "남은 쪽지", "parts": [Themes.make_part(Game.theme, Data.TYPES[rng.randi() % Data.TYPES.size()], rng)], "auto": true})
				parts += 1
		# 봇(과 자동 테스트)은 바로 연다. 사람은 조립 시작 때 개봉식
		if i != 0 or Game.autotest:
			for env in envs:
				for it in env["parts"]:
					(p["inventory"] as Array).append(it)
			p["envelopes"] = []
	Sfx.play("whoosh", -6.0)
	Game.goto("build")


# ── 시나리오 테스트 ──────────────────────────────────

func run_scenario(sc: String) -> void:
	while not ready_done:
		await get_tree().process_frame
	time_left = 999.0
	match sc:
		"solids":
			_scenario_solids()
		"reach":
			await _scenario_reach()
		"navdbg":
			for r in info["rooms"]:
				var rr: Rect2 = r[0]
				var n := 0
				for id in nav.get_point_ids():
					var p := nav.get_point_position(id)
					if rr.has_point(Vector2(p.x, p.z)):
						n += 1
				print("[nav] ", r[1], " ", n, " / ", int(rr.get_area() * 4))
			var s0 := nav.get_closest_point(info["spawns"][0])
			for r in info["rooms"]:
				var rr: Rect2 = r[0]
				var c := Vector3(rr.get_center().x, level_y(int(r[2])), rr.get_center().y)
				var g := nav.get_closest_point(c)
				var pth := nav.get_point_path(s0, g, true)
				var endp: Vector3 = pth[pth.size() - 1] if pth.size() > 0 else Vector3.INF
				print("[conn] ", r[1], " 도착 ", "OK" if endp.distance_to(nav.get_point_position(g)) < 0.1 else "끊김 → " + str(endp))
			var space := get_world_3d().direct_space_state
			var q := PhysicsShapeQueryParameters3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(0.95, 0.9, 0.95)
			q.shape = sh
			q.collision_mask = ALL_WORLD
			q.transform = Transform3D(Basis(), Vector3(-15.25, 0.95, -5.25))
			for hres in space.intersect_shape(q, 8):
				var col: Object = hres["collider"]
				print("[hit] ", col, " ", (col as Node3D).global_position, " meta=", col.get_meta_list())
		"open":
			var me: Dictionary = actors[0]
			var body: CharacterBody3D = me["body"]
			var best: Dictionary = {}
			var bd := INF
			for e in containers:
				if (e["inside"] as Array).size() > 0:
					var d: float = (e["node"] as Node3D).global_position.distance_to(body.global_position)
					if d < bd:
						bd = d
						best = e
			best["hold"] = 3.0
			var np: Vector3 = (best["node"] as Node3D).global_position
			body.global_position = np + Basis(Vector3.UP, float(best["yaw"])) * Vector3(0, 0, 1.4)
			body.reset_physics_interpolation()
			body.global_position.y = level_y(int(best["lvl"])) + 0.1
			cam_yaw = float(best["yaw"]) + 0.5
			zoom = 4.5
			cam_pitch = -0.6
			act = best
			return
		"ball":
			var me: Dictionary = actors[0]
			var body: CharacterBody3D = me["body"]
			var balls := []
			for r in lvl_roots:
				for c in (r as Node3D).get_children():
					if c is RigidBody3D and c.has_meta("ball"):
						balls.append(c)
			balls.sort_custom(func(p, q): return p.global_position.z > q.global_position.z)
			var bl: RigidBody3D = balls[balls.size() / 2]   # 체육관 가운데 공 (복도 공은 벽에 막힌다)
			var b0 := bl.global_position
			body.global_position = b0 + Vector3(0, 0, 3.0)
			body.reset_physics_interpolation()
			cam_yaw = 0.0
			for i in 40:
				await get_tree().physics_frame
			sim_move = Vector2(0, -1)
			for i in 50:
				await get_tree().physics_frame
			sim_move = Vector2.ZERO
			for i in 60:
				await get_tree().physics_frame
			print("[ball] 공 %d개 · 찬 공 이동 %.1fm · 최고 높이 변화 %.1f" % [balls.size(), b0.distance_to(bl.global_position), bl.global_position.y - b0.y])
		"play":
			# 사람도 봇처럼 3분 (빠르게 감기) — 몇 개씩 줍나 · 막히는 데 없나
			Engine.time_scale = 3.0
			time_left = Game.t_collect()
			var me: Dictionary = actors[0]
			var stuck := 0
			var last := Vector3.ZERO
			while time_left > 0.5:
				if act.is_empty():
					var g := _bot_choose(me)
					if not g.is_empty():
						act = g["ref"]
				await get_tree().create_timer(0.5).timeout
				var p: Vector3 = me["body"].global_position
				if p.distance_to(last) < 0.3:
					stuck += 1
					if stuck > 6:
						print("[play] 오래 멈춤 @", p.snapped(Vector3.ONE * 0.1), " 목표 ", act.get("name", "-"))
						_cancel_act()
						stuck = 0
				else:
					stuck = 0
				last = p
			Engine.time_scale = 1.0
			var line := ""
			for a in actors:
				var n := 0
				for e in _envs(a):
					n += (e["parts"] as Array).size()
				line += "%s 봉투 %d(파츠 %d)  " % [Game.players[a["i"]]["name"], _envs(a).size(), n]
			var left := 0
			for e in treasures:
				if e["alive"]:
					left += 1
			print("[play] %s 3분: %s · 남은 보물 %d" % [Game.theme, line, left])
			for a in actors:
				if a["bot"] and _envs(a).size() < 10:
					var g: Dictionary = a["goal"]
					print("[play] 느린 봇 %s @%s 목표 %s @%s wait=%.1f" % [Game.players[a["i"]]["name"], (a["body"] as Node3D).global_position.snapped(Vector3.ONE * 0.1), g["ref"]["name"] if not g.is_empty() else "-", ((g["ref"]["node"] as Node3D).global_position.snapped(Vector3.ONE * 0.1)) if not g.is_empty() and is_instance_valid(g["ref"]["node"]) else Vector3.ZERO, float(a["wait"])])
		"follow":
			for i in 30:
				await get_tree().physics_frame
			for mv in [Vector2(0.7, -1.0), Vector2(0, 1.0)]:
				var y0 := cam_yaw
				sim_move = mv
				for i in 240:
					await get_tree().physics_frame
				sim_move = Vector2.ZERO
				print("[follow] 입력 %s: 카메라 %.2f → %.2f · 캐릭터 %.2f" % [str(mv), y0, cam_yaw, (actors[0]["body"] as Node3D).rotation.y])
		"chars":
			# 캐릭터 6명 근접 확인용
			for i in 20:
				await get_tree().physics_frame
			ready_done = false
			var c0: Vector3 = (actors[0]["body"] as Node3D).global_position
			for k in actors.size():
				var b: CharacterBody3D = actors[k]["body"]
				b.global_position = c0 + Vector3((k - 2.5) * 0.9, 0, 0)
				b.rotation.y = 0.0
				(actors[k]["vis"] as Node3D).rotation.y = 0.0 + (0.5 if OS.get_cmdline_user_args().has("--side") else 0.0)
			cam_pivot.global_position = c0 + Vector3(0, 1.1, -4.0)
			cam_pivot.rotation = Vector3(-0.15, PI, 0)
			spring.spring_length = 0.0
			cam.position = Vector3.ZERO
			return
		"look":
			for i in 25:
				await get_tree().physics_frame
			for s in OS.get_cmdline_user_args():
				if s.begins_with("--room="):
					for r in info["rooms"]:
						if r[1] == s.substr(7):
							var rr: Rect2 = r[0]
							var b: CharacterBody3D = actors[0]["body"]
							var g := nav.get_closest_point(Vector3(rr.get_center().x, level_y(int(r[2])), rr.get_center().y))
							b.global_position = nav.get_point_position(g) + Vector3(0, 0.2, 0)
							for i in 10:
								await get_tree().physics_frame
			cam_yaw = 0.6
			if OS.get_cmdline_user_args().has("--bag"):
				for i in 20:
					await get_tree().physics_frame
				_toggle_bag()
			return
	print("[scenario] done")
	get_tree().quit()


## 보이는 덩어리 중 충돌이 없는 것 (캐릭터가 통과하는 가구 찾기)
func _scenario_solids() -> void:
	var space := get_world_3d().direct_space_state
	var seen := {}
	var miss := 0
	for r in audit:
		var sz: Vector3 = r[0]
		var xf: Transform3D = r[1]
		var lvl_y := level_y(int(r[3]))
		var wb := AABB(xf.origin, Vector3.ZERO)
		# 걸어서 부딪힐 만한 것만: 두께 0.15 이상 · 높이 0.3 이상 · 발밑~머리 높이에 걸침
		if minf(sz.x, minf(sz.y, sz.z)) < 0.15 or sz.y * absf(xf.basis.orthonormalized().y.y) < 0.3 and sz.y < 0.3:
			continue
		if xf.origin.y - sz.y * 0.5 > lvl_y + 2.0 or xf.origin.y + sz.y * 0.5 < lvl_y + 0.25:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		var bs := BoxShape3D.new()
		bs.size = sz * 0.5
		q.shape = bs
		q.transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
		q.collision_mask = ALL_WORLD | L_PUSH | L_ITEM
		if space.intersect_shape(q, 1).is_empty():
			miss += 1
			var key: String = r[2]
			seen[key] = int(seen.get(key, 0)) + 1
			if int(seen[key]) <= 2:
				print("[solids] 통과: %s · 크기 %s @%s" % [key, str(sz.snapped(Vector3.ONE * 0.01)), str(xf.origin.snapped(Vector3.ONE * 0.1))])
	print("[solids] %s: 덩어리 %d 중 통과 %d (코드 위치 %d곳)" % [Game.theme, audit.size(), miss, seen.size()])
	# 여는 가구(서랍 · 문 · 뚜껑)는 보물층이라 캐릭터가 무시한다 — 바깥 몸체 충돌 안에 있는지
	var cmiss := {}
	for e in containers:
		var pc: Piece = e["node"]
		var gx := pc.mesh_inst.global_transform
		var sz := pc.pscale * 0.5
		if minf(sz.x, minf(sz.y, sz.z)) < 0.15 or gx.origin.y - sz.y * 0.5 > level_y(int(e["lvl"])) + 2.0:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		var bs := BoxShape3D.new()
		bs.size = sz * 0.5
		q.shape = bs
		q.transform = Transform3D(gx.basis.orthonormalized(), gx.origin)
		q.collision_mask = ALL_WORLD | L_PUSH
		if space.intersect_shape(q, 1).is_empty():
			cmiss[e["name"]] = int(cmiss.get(e["name"], 0)) + 1
	print("[solids] %s: 여는 가구 %d 중 몸체 없음 %s" % [Game.theme, containers.size(), str(cmiss)])
	get_tree().quit()


## 아무 보물 · 가구를 골랐을 때 실제로 가서 손에 넣는지 (층 · 계단 · 사다리 포함)
func _scenario_reach() -> void:
	var me: Dictionary = actors[0]
	var pool := []
	for e in treasures:
		if not e["hidden"]:
			pool.append(e)
	for e in containers:
		pool.append(e)
	pool.shuffle()
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--lvl="):   # 특정 층 목표만 (막힘 재현용)
			var want := int(s.substr(6))
			pool = pool.filter(func(e): return int(e["lvl"]) == want)
		if s.begins_with("--name="):
			var nm := s.substr(7)
			pool = pool.filter(func(e): return str(e["name"]) == nm)
	var ok := 0
	var stuck := []
	var times := []
	for n in mini(30, pool.size()):
		var e: Dictionary = pool[n]
		if not e["alive"]:
			continue
		if _envs(me).size() >= BAG_MAX - 1:
			_envs(me).clear()
		act = e
		var t := 0.0
		var trail := []
		while e["alive"] and t < 25.0 and not act.is_empty():
			await get_tree().physics_frame
			t += 1.0 / 60.0
			if int(t * 60) % 30 == 0:
				var bb: CharacterBody3D = me["body"]
				var cn := []
				for ci in bb.get_slide_collision_count():
					var kc := bb.get_slide_collision(ci)
					var co := kc.get_collider() as CollisionObject3D
					var shp := ""
					if co.get_child_count() > 0 and co.get_child(0) is CollisionShape3D and (co.get_child(0) as CollisionShape3D).shape is BoxShape3D:
						shp = str(((co.get_child(0) as CollisionShape3D).shape as BoxShape3D).size.snapped(Vector3.ONE * 0.01))
					cn.append("%s:L%d@%s%s" % [str(kc.get_normal().snapped(Vector3.ONE * 0.1)), co.collision_layer, str(co.global_position.snapped(Vector3.ONE * 0.01)), shp])
				trail.append("%s v%s %s" % [str(bb.global_position.snapped(Vector3.ONE * 0.1)), str(bb.velocity.snapped(Vector3.ONE * 0.1)), ",".join(cn)])
		if not e["alive"]:
			ok += 1
			times.append(t)
			if OS.get_cmdline_user_args().has("--each"):
				print("[each] %s @%s %.1f초" % [e["name"], str((e["node"] as Node3D).global_position.snapped(Vector3.ONE * 0.1)), t])
		else:
			var b: CharacterBody3D = me["body"]
			var pth: PackedVector3Array = me.get("path", PackedVector3Array())
			var ps := []
			for q in pth:
				ps.append(str(q.snapped(Vector3.ONE * 0.5)))
			print("[path] ", e["name"], " pi=", me.get("pi", -1), " ", ", ".join(ps.slice(0, 40)))
			print("[trail] ", " ".join(trail.slice(-50)))
			stuck.append("%s L%d @%s (나 %s)" % [e["name"], e["lvl"], str((e["node"] as Node3D).global_position.snapped(Vector3.ONE * 0.1)), str(b.global_position.snapped(Vector3.ONE * 0.1))])
			_cancel_act()
	times.sort()
	print("[reach] %s: 성공 %d / %d · 중앙값 %.1f초 · 최대 %.1f초" % [Game.theme, ok, ok + stuck.size(), times[times.size() / 2] if times.size() > 0 else 0.0, times[-1] if times.size() > 0 else 0.0])
	for s in stuck:
		print("[reach] 막힘: ", s)
	var nt := 0
	for e in treasures:
		nt += 1
	print("[map] %s: 보물 %d · 가구 %d · 자리 %d · 길 점 %d · 사다리 %d · 계단 %d" % [Game.theme, nt, containers.size(), spots.size(), nav.get_point_count(), ladders.size(), links.size() - ladders.size()])


# ── 수집 단계에서 그대로 가져온 것 (이동 · 손 연출 · 카메라 · 가방) ──

func _shape_of(t: String, spec) -> Vector3:
	if spec is Vector3:
		return spec
	return Data.variant(t, int(spec))[1]


## a→b 비스듬한 발판 (윗면이 a-b 선을 지난다). 계단·미끄럼틀용
func _ramp(parent: Node3D, a: Vector3, b: Vector3, width: float, slide := false) -> StaticBody3D:
	var thick := 0.3
	var d := b - a
	var xa := d.normalized()
	var za := xa.cross(Vector3.UP).normalized()
	var ya := za.cross(xa)
	var body := StaticBody3D.new()
	body.collision_layer = LVL_LAYERS[lvl]
	body.set_meta("lvl", lvl)
	body.collision_mask = 0
	body.transform = Transform3D(Basis(xa, ya, za), (a + b) * 0.5 - ya * thick * 0.5)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(d.length(), thick, width)
	cs.shape = sh
	body.add_child(cs)
	if slide:
		body.set_meta("slide", true)
	parent.add_child(body)
	var g: Transform3D = parent.global_transform * body.transform if parent.is_inside_tree() else parent.transform * body.transform
	obstacles.append([Vector2(g.origin.x, g.origin.z), Vector2(absf(d.x) + width, absf(d.z) + width) * 0.5, -parent.rotation.y])
	return body


## 모자 · 머리털 반구: 머리(반지름 ≈0.285)보다 넉넉히 크고 높게 — 작으면 정수리가 뚫고 나와 겹쳐 보였다
const HAT := Vector3(1.08, 1.0, 1.08)
const HAT_Y := 0.21

func _character(i: int) -> Node3D:
	# 작은 탐험가: 다리 · 팔은 따로 움직이는 관절(걸으면 흔든다) · 몸통 · 배낭 · 머리. 동물 친구는 귀 · 부리
	var p: Dictionary = Game.players[i]
	var c: int = p["color"]
	var root := Node3D.new()
	var skin := Color("#F2D3B3")
	var pants := Color("#3A4A63")
	var add := func(parent: Node3D, t: String, shp: Vector3, col, pos: Vector3, rot := Vector3.ZERO) -> Piece:
		var pc := Piece.new().setup(t, col if col is int else 0, false, shp)
		pc.set_pscale(shp, false)
		if not (col is int):
			pc.mesh_inst.material_override = Data.brick(col, false, 0.25, 0.5)
		pc.position = pos
		pc.rotation_degrees = rot
		parent.add_child(pc)
		return pc
	# 다리 (엉덩이 관절)
	for s in [-1, 1]:
		var hip := Node3D.new()
		hip.name = "leg_l" if s < 0 else "leg_r"
		hip.position = Vector3(s * 0.12, 0.55, 0)
		root.add_child(hip)
		add.call(hip, "capsule", Vector3(0.75, 0.85, 0.75), pants, Vector3(0, -0.27, 0))
		add.call(hip, "box", Vector3(0.38, 0.18, 0.6), Color("#3B2B22"), Vector3(0, -0.5, -0.05))
	# 몸통 · 허리띠 · 배낭
	add.call(root, "box", Vector3(0.95, 0.95, 0.62), c, Vector3(0, 0.8, 0))
	add.call(root, "box", Vector3(0.97, 0.12, 0.64), Color("#5A3E2B"), Vector3(0, 0.6, 0))
	add.call(root, "box", Vector3(0.7, 0.85, 0.36), Color("#B5763C"), Vector3(0, 0.84, 0.23))
	add.call(root, "box", Vector3(0.5, 0.3, 0.1), Color("#8E5A2C"), Vector3(0, 0.74, 0.32))
	# 팔 (어깨 관절)
	for s in [-1, 1]:
		var sh := Node3D.new()
		sh.name = "arm_l" if s < 0 else "arm_r"
		sh.position = Vector3(s * 0.27, 1.0, 0)
		sh.rotation_degrees = Vector3(0, 0, s * 8)
		root.add_child(sh)
		add.call(sh, "capsule", Vector3(0.6, 0.72, 0.6), c, Vector3(0, -0.2, 0))
		add.call(sh, "sphere", Vector3(0.22, 0.22, 0.22), skin, Vector3(0, -0.42, 0))
	# 머리 · 얼굴
	var head := Node3D.new()
	head.name = "head"
	head.position = Vector3(0, 1.32, 0)
	root.add_child(head)
	add.call(head, "sphere", Vector3(0.95, 0.9, 0.9), skin, Vector3.ZERO)
	for s in [-1, 1]:
		add.call(head, "sphere", Vector3(0.11, 0.14, 0.08), 15, Vector3(s * 0.09, 0.03, -0.25))
		add.call(head, "sphere", Vector3(0.1, 0.06, 0.05), Color("#F0A0A0"), Vector3(s * 0.16, -0.06, -0.22))
	add.call(head, "box", Vector3(0.14, 0.03, 0.03), Color("#7A4A3A"), Vector3(0, -0.1, -0.265))
	match p["name"]:
		"나":
			add.call(head, "hemi", HAT, 8, Vector3(0, HAT_Y, 0.01))
			add.call(head, "plate", Vector3(0.5, 0.7, 0.5), 8, Vector3(0, 0.085, -0.31), Vector3(10, 0, 0))   # 챙
		"곰돌이":
			for s in [-1, 1]:
				add.call(head, "sphere", Vector3(0.3, 0.3, 0.2), 12, Vector3(s * 0.21, 0.31, 0.02))
			add.call(head, "hemi", HAT, 12, Vector3(0, HAT_Y, 0.02))
		"토끼":
			for s in [-1, 1]:
				add.call(head, "capsule", Vector3(0.6, 0.85, 0.5), 0, Vector3(s * 0.1, 0.5, 0.02), Vector3(0, 0, s * -8))
		"펭귄":
			add.call(head, "hemi", HAT, 15, Vector3(0, HAT_Y, 0.02))
			add.call(head, "cone", Vector3(0.28, 0.3, 0.28), 3, Vector3(0, -0.04, -0.3), Vector3(-90, 0, 0))
		"여우":
			for s in [-1, 1]:
				add.call(head, "cone", Vector3(0.45, 0.55, 0.4), 3, Vector3(s * 0.15, 0.4, 0.02), Vector3(0, 0, s * -14))
			add.call(head, "hemi", HAT, 3, Vector3(0, HAT_Y, 0.02))
		"고양이":
			for s in [-1, 1]:
				add.call(head, "cone", Vector3(0.38, 0.42, 0.36), 14, Vector3(s * 0.15, 0.38, 0.02), Vector3(0, 0, s * -14))
			add.call(head, "hemi", HAT, 14, Vector3(0, HAT_Y, 0.02))
	_bake_parts(root)
	for pv in root.get_children():
		if not (pv is Piece):
			_bake_parts(pv)
	return root


static var _char_mat: StandardMaterial3D
## 최적화: 관절 하나에 붙은 덩어리들을 메시 하나로 합친다 (색은 꼭짓점 색).
## 캐릭터 1명 ≈ 22덩어리 × (본체 + 외곽선) 44번 그리기 → 관절 5개 × 2 = 10번
func _bake_parts(pivot: Node3D) -> void:
	if _char_mat == null:
		_char_mat = StandardMaterial3D.new()
		_char_mat.vertex_color_use_as_albedo = true
		_char_mat.roughness = 0.55
		_char_mat.next_pass = Data.outline_material()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for ch in pivot.get_children():
		if not (ch is Piece):
			continue
		var pc: Piece = ch
		var mi: MeshInstance3D = pc.mesh_inst
		var xf: Transform3D = pc.transform * pc.vis.transform * mi.transform
		var nb := xf.basis.inverse().transposed()
		var col := Color.WHITE
		var mat := mi.material_override if mi.material_override else mi.get_active_material(0)
		if mat is ShaderMaterial:
			col = (mat as ShaderMaterial).get_shader_parameter("albedo")
		elif mat is StandardMaterial3D:
			col = (mat as StandardMaterial3D).albedo_color
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var ii = arr[Mesh.ARRAY_INDEX]
			var base := verts.size()
			for k in v.size():
				verts.append(xf * v[k])
				norms.append((nb * n[k]).normalized() if n.size() > k else Vector3.UP)
				cols.append(col)
			if ii == null or (ii as PackedInt32Array).is_empty():
				for k in v.size():
					idx.append(base + k)
			else:
				for k in (ii as PackedInt32Array):
					idx.append(base + k)
		pivot.remove_child(pc)
		pc.queue_free()
	if verts.is_empty():
		return
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_NORMAL] = norms
	a[Mesh.ARRAY_COLOR] = cols
	a[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	var out := MeshInstance3D.new()
	out.mesh = am
	out.material_override = _char_mat
	pivot.add_child(out)


## 걷기 · 숨쉬기 애니메이션 (관절 흔들기)
func _animate_limbs(a: Dictionary, moving: bool, on_floor: bool, delta: float) -> void:
	var vis: Node3D = a["vis"]
	var t: float = a["walk_t"]
	var k: float = a.get("swing", 0.0)
	k = lerpf(k, 1.0 if moving and on_floor else 0.0, 1.0 - exp(-10.0 * delta))
	a["swing"] = k
	var sw := sin(t * 11.0) * 0.75 * k
	var air := 0.0 if on_floor else 0.6
	var ll := vis.get_node_or_null("leg_l") as Node3D
	var lr := vis.get_node_or_null("leg_r") as Node3D
	var al := vis.get_node_or_null("arm_l") as Node3D
	var ar := vis.get_node_or_null("arm_r") as Node3D
	var hd := vis.get_node_or_null("head") as Node3D
	if ll:
		ll.rotation.x = sw - air * 0.5
		lr.rotation.x = -sw + air * 0.3
		al.rotation.x = -sw * 0.8 - air
		ar.rotation.x = sw * 0.8 - air
		var breathe := sin(Time.get_ticks_msec() * 0.003 + float(a["i"])) * 0.02 * (1.0 - k)
		hd.position.y = 1.32 + breathe


## 찌그러졌다 돌아오기 (착지 · 줍기)
func _squash(n: Node3D, k: float) -> void:
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3(1.0 + (1.0 - k) * 0.6, k, 1.0 + (1.0 - k) * 0.6), 0.06)
	tw.tween_property(n, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 머리 위로 떠오르는 글자
func _pop(s: String, at: Vector3) -> void:
	var l := UI.label3d(s, 40)
	l.modulate = Color("#E07A5F")
	l.position = at
	world.add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", at.y + 1.2, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _move_body(a: Dictionary, v: Vector3, delta: float, jump := false) -> void:
	var body: CharacterBody3D = a["body"]
	var vel := body.velocity
	if a["bot"]:
		vel.x = v.x * SPEED
		vel.z = v.z * SPEED
	else:
		# 사람: 가속 · 감속이 있다 (출발 0.12초 · 정지 0.08초 정도). 공중에선 덜 꺾인다
		var want := Vector2(v.x, v.z) * SPEED
		var cur := Vector2(vel.x, vel.z)
		var rate := (42.0 if want.length() > cur.length() else 62.0) * (1.0 if body.is_on_floor() else 0.45)
		cur = cur.move_toward(want, rate * delta)
		vel.x = cur.x
		vel.z = cur.y
	# 미끄럼판 위: 아래로 주르륵
	if a.get("on_slide", false) and body.is_on_floor():
		var n := body.get_floor_normal()
		var down := Vector3(n.x, 0, n.z).normalized()
		vel.x = v.x * SPEED * 0.35 + down.x * 7.5
		vel.z = v.z * SPEED * 0.35 + down.z * 7.5
	if body.is_on_floor():
		a["air_t"] = 0.0
	else:
		a["air_t"] = a.get("air_t", 0.0) + delta
	# 가장자리에서 막 떨어진 뒤 0.12초는 아직 뛸 수 있다 (코요테 타임)
	var leapt := false
	var grounded: bool = body.is_on_floor() or (a["air_t"] < 0.12 and vel.y <= 0.0)
	if grounded:
		# 무릎 높이 턱(차·화물칸·계단 끝)은 걸어가면 알아서 폴짝
		var flat := Vector3(v.x, 0, v.z)
		if not jump and flat.length() > 0.5 and body.is_on_wall() and _low_ledge(body, flat.normalized()):
			vel.y = JUMP_V * 0.8
			a["air_t"] = 1.0
			leapt = true
		elif jump:
			vel.y = JUMP_V
			a["air_t"] = 1.0
			leapt = true
			a["jumped"] = true
			if not a["bot"]:
				Sfx.play("jump", -8.0)
	var lad := _ladder_near(body)
	var climbing := false
	if not lad.is_empty():
		var lf: Vector3 = lad["fwd"]
		if Vector3(v.x, 0, v.z).dot(lf) > 0.25 and a.get("climb_ok", true):
			climbing = true
			a["ladder_fwd"] = lf
			if body.global_position.y < float(lad["y1"]) + 0.12:
				# 사다리 줄에 붙어서 오른다 (밧줄 사다리는 뒤에 벽이 없어서, 앞으로 밀면 떨어져 나갔다)
				var lp: Vector2 = lad["pos"]
				var hold := Vector3(lp.x, 0, lp.y) - lf * 0.3 - Vector3(body.global_position.x, 0, body.global_position.z)
				vel.y = 3.8
				vel.x = hold.x * 4.0 + lf.x * 0.15
				vel.z = hold.z * 4.0 + lf.z * 0.15
			else:
				# 꼭대기: 발이 판 윗면을 넘은 뒤 앞으로 올라선다 (아래서 뛰면 판 모서리에 머리를 박았다)
				vel.y = 1.2
				vel.x = lf.x * 3.5
				vel.z = lf.z * 3.5
	if not body.is_on_floor() and not leapt and not climbing:
		vel.y -= GRAVITY * delta
	body.velocity = vel
	body.move_and_slide()
	# 밀 수 있는 가구는 부딪히면 밀린다
	for ci in body.get_slide_collision_count():
		var kc := body.get_slide_collision(ci)
		var rb := kc.get_collider() as RigidBody3D
		if rb and (kc.get_normal().y < 0.5 or rb.has_meta("ball")):
			var push := -kc.get_normal()
			push.y = 0.0
			if push.length() < 0.2:
				push = Vector3(vel.x, 0, vel.z)
			if rb.has_meta("ball"):
				# 공: 뻥 — 달리는 속도만큼 세게, 살짝 위로
				if rb.linear_velocity.length() < 2.5 and push.length() > 0.01:
					var sp := Vector2(vel.x, vel.z).length()   # 부딪히기 전 속도
					rb.apply_central_impulse((push.normalized() * (2.0 + sp * 0.9) + Vector3.UP * (1.5 + sp * 0.3)) * rb.mass)
					if not a["bot"]:
						Sfx.play("tick", -4.0, 0.3)
			else:
				rb.apply_central_impulse(push.normalized() * 0.9 * rb.mass * delta * 8.0)
	# 지금 밟고 있는 것
	var floor_obj: Object = null
	if body.is_on_floor():
		var fp := body.global_position
		var fq := PhysicsRayQueryParameters3D.create(fp + Vector3(0, 0.3, 0), fp + Vector3(0, -0.35, 0), ALL_WORLD)
		var fh := get_world_3d().direct_space_state.intersect_ray(fq)
		if fh:
			floor_obj = fh["collider"]
		for i in body.get_slide_collision_count():
			var sc := body.get_slide_collision(i)
			if sc.get_normal().y > 0.5 and (floor_obj == null or sc.get_collider() is AnimatableBody3D):
				floor_obj = sc.get_collider()
	a["on_slide"] = floor_obj != null and floor_obj.has_meta("slide")
	var ride: Object = floor_obj if floor_obj is AnimatableBody3D else null
	if ride != a.get("ride") and body.is_on_floor():
		a["ride"] = ride
	var moving := Vector2(v.x, v.z).length() > 0.1
	if moving:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-v.x, -v.z), 1.0 - exp(-14.0 * delta))
		a["walk_t"] += delta
	var vis: Node3D = a["vis"]
	vis.position.y = absf(sin(a["walk_t"] * 11.0)) * 0.05 if moving and body.is_on_floor() else lerpf(vis.position.y, 0.0, 0.3)
	_animate_limbs(a, moving, body.is_on_floor(), delta)


## 앞이 발목~허리 높이에서만 막혀 있으면 올라설 수 있는 턱
func _low_ledge(body: CharacterBody3D, dir: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var base := body.global_position
	var lo := PhysicsRayQueryParameters3D.create(base + Vector3(0, 0.3, 0), base + Vector3(0, 0.3, 0) + dir * 0.8, ALL_WORLD)
	var hi := PhysicsRayQueryParameters3D.create(base + Vector3(0, 0.95, 0), base + Vector3(0, 0.95, 0) + dir * 0.9, ALL_WORLD)   # 난간(1m)은 못 넘게
	return not space.intersect_ray(lo).is_empty() and space.intersect_ray(hi).is_empty()


## 손 + 원형 게이지. 뜯는 동안: 손이 대상을 움켜쥐고 캐릭터 쪽으로 당기며, 게이지가 한 바퀴 돌면 쏙.
## 커서가 집을 수 있는 것 위에 있으면 커서 옆에 편 손.
func _draw_fx() -> void:
	var mouse := _aim_pos()
	var tearing := not act.is_empty() and hold_prog > 0.0 and is_instance_valid(act["node"])
	var looking := not bag_open
	if looking:
		var on: bool = not aim.is_empty() and not aim.get("bolted", false)
		fx.draw_circle(mouse, 3.5, Color(1, 1, 1, 0.95))
		fx.draw_arc(mouse, 11.0, 0, TAU, 24, Color(UI.ACCENT if on else Color.WHITE, 0.9), 2.5)
		fx.draw_arc(mouse, 12.5, 0, TAU, 24, Color(UI.INK, 0.35), 1.0)
	if not tearing:
		if not aim.is_empty() and not aim.get("bolted", false):
			pass   # 조준점 색 + F 안내로 충분 (손 아이콘은 뺐다)
		return
	var wp: Vector3 = (act["node"] as Node3D).global_position
	if cam.is_position_behind(wp):
		return
	var c := cam.unproject_position(wp)
	var me := cam.unproject_position(actors[0]["body"].global_position + Vector3(0, 1.15, 0))
	var g := clampf(hold_prog, 0, 1)
	var R := 46.0
	fx.draw_circle(c, R + 6, Color(1, 1, 1, 0.5))
	fx.draw_arc(c, R, 0, TAU, 48, Color(UI.INK, 0.22), 9.0)
	fx.draw_arc(c, R, -PI / 2, -PI / 2 + TAU * g, 48, UI.ACCENT, 9.0)
	fx.draw_circle(c + Vector2(cos(-PI / 2 + TAU * g), sin(-PI / 2 + TAU * g)) * R, 7.0, Color.WHITE)
	# 팔: 캐릭터 → 손. 진행할수록 손이 캐릭터 쪽으로 당겨진다
	var hc := c.lerp(me, g * 0.28)
	var skin := Color("#F6D2B0")
	var ink := Color(UI.INK, 0.9)
	var wob := Vector2(sin(Time.get_ticks_msec() * 0.04), cos(Time.get_ticks_msec() * 0.05)) * 2.5 * g
	var ang := (hc - me).angle() + PI / 2
	_draw_hand(hc + wob, 2.1, clampf(g * 1.4, 0.0, 1.0), ang)


## 만화 손. s 크기, grip 0(편 손)~1(쥔 주먹), rot 손목→손끝 방향 회전
func _draw_hand(at: Vector2, s: float, grip: float, rot: float) -> void:
	var skin := Color("#F6D2B0")
	var ink := Color(UI.INK, 0.9)
	var xf := Transform2D(rot, at)
	var caps := []   # [a, b, width]
	# 손가락 4개: 마디 두 개, 쥘수록 접힌다
	for i in 4:
		var bx := (-7.5 + i * 5.0) * s
		var base := Vector2(bx, -6 * s)
		var l1 := (8.0 - (1.5 if i == 0 or i == 3 else 0.0)) * s
		var a1 := lerpf(0.0, 1.1, grip) + (i - 1.5) * 0.08 * (1.0 - grip)
		var k := base + Vector2(sin(a1 * 0.3 + (i - 1.5) * 0.06), -cos(a1 * 0.3)) * l1
		var a2 := lerpf(0.0, 2.3, grip)
		var tip := k + Vector2(0, -1).rotated(a2) * l1 * 0.8
		caps.append([base, k, 5.2 * s])
		caps.append([k, tip, 5.0 * s])
	# 엄지
	var tb := Vector2(-10 * s, 3 * s)
	var tt := tb + Vector2(-7, -6).lerp(Vector2(3, -7), grip) * s
	caps.append([tb, tt, 5.6 * s])
	# 외곽선 먼저, 살색 위에
	for layer in 2:
		var col := ink if layer == 0 else skin
		var grow := 2.4 if layer == 0 else 0.0
		for cp in caps:
			var p0: Vector2 = xf * (cp[0] as Vector2)
			var p1: Vector2 = xf * (cp[1] as Vector2)
			var w: float = cp[2] + grow
			fx.draw_line(p0, p1, col, w)
			fx.draw_circle(p0, w * 0.5, col)
			fx.draw_circle(p1, w * 0.5, col)
		# 손바닥
		var palm := PackedVector2Array()
		for j in 12:
			var t := TAU * j / 12.0
			palm.append(xf * Vector2(cos(t) * (11.5 * s + grow * 0.5), 2 * s + sin(t) * (9.5 * s + grow * 0.5)))
		fx.draw_colored_polygon(palm, col)
	# 손목 소매
	fx.draw_line(xf * Vector2(-8 * s, 12 * s), xf * Vector2(8 * s, 12 * s), UI.ACCENT, 4.0 * s)


## 조준점: 시점 조작 중이면 화면 가운데, 커서를 풀었으면 커서
func _aim_pos() -> Vector2:
	if not bag_open:   # 마우스는 시점만 돌린다 — 줍기는 늘 화면 가운데 조준점 (정면에 보이는 것)
		return get_viewport().get_visible_rect().size * 0.5
	return get_viewport().get_mouse_position()


func _build_camera() -> void:
	cam_pivot = Node3D.new()
	cam_pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # _process에서 직접 움직인다
	add_child(cam_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = zoom
	spring.collision_mask = L_WALL | 1 | 8 | 16 | 64 | 512   # 벽 · 바닥 · 층에 부딪히면 앞으로 (가구는 통과)
	spring.margin = 0.3
	var sph := SphereShape3D.new()
	sph.radius = 0.25
	spring.shape = sph
	cam_pivot.add_child(spring)
	cam = Camera3D.new()
	cam.fov = 62
	cam.position = Vector3(1.15, 0, 0)   # 어깨 너머 — 조준점이 머리에 안 겹치게
	spring.add_child(cam)
	spring.add_excluded_object(actors[0]["body"].get_rid())


func _input(ev: InputEvent) -> void:
	if finished:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_TAB:
		_toggle_bag()
		get_viewport().set_input_as_handled()


func _toggle_bag() -> void:
	bag_open = not bag_open
	bag_panel.visible = bag_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if bag_open else Input.MOUSE_MODE_CAPTURED
	bag_t = 0.0
	Sfx.play("select", -12.0)


func _slot_input(ev: InputEvent, idx: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_select_slot(idx)


func _refresh_hotbar() -> void:
	for c in hot_slots:
		c.queue_redraw()


func _slot_box(sel: bool) -> StyleBoxFlat:
	if _sb_cache.has(sel):
		return _sb_cache[sel]
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#F3F5F7") if not sel else Color("#FFF1EC")
	sb.set_corner_radius_all(8)
	sb.border_color = UI.ACCENT if sel else Color("#D5DADF")
	sb.set_border_width_all(3 if sel else 2)
	_sb_cache[sel] = sb
	return sb


func _toast(s: String) -> void:
	toast.text = s
	toast_t = 1.8


