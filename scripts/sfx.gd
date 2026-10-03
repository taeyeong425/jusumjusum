extends Node
## 효과음 (autoload "Sfx"). Kenney Impact / Interface Sounds — CC0

const SETS := {
	"tick": ["impactWood_light_000", "impactWood_light_002", "impactWood_light_004"],
	"tear": ["impactPlank_medium_000", "impactPlank_medium_002"],
	"place": ["impactWood_medium_001"],
	"thud": ["impactWood_heavy_000"],
	"pick": ["pluck_001", "pluck_002"],
	"land": ["impactSoft_medium_000"],
	"jump": ["impactSoft_heavy_001"],
	"step": ["footstep_grass_000", "footstep_grass_002", "footstep_grass_004"],
	"dig": ["footstep_snow_001"],
	"bell": ["impactBell_heavy_000"],
	"fail": ["impactPlate_heavy_002"],
	"click": ["click_002"],
	"select": ["select_002"],
	"error": ["error_004"],
	"ok": ["confirmation_002"],
	"star": ["toggle_001"],
	"drop": ["drop_002"],
	"whoosh": ["maximize_003"],
}

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var muted := false


func _ready() -> void:
	for k in SETS:
		var arr := []
		for n in SETS[k]:
			var s = load("res://assets/sfx/%s.ogg" % n)
			if s:
				arr.append(s)
		_streams[k] = arr
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


func play(name: String, vol_db := 0.0, pitch_jitter := 0.06) -> void:
	if muted or not _streams.has(name) or _streams[name].is_empty():
		return
	var arr: Array = _streams[name]
	for p in _pool:
		if not p.playing:
			p.stream = arr[randi() % arr.size()]
			p.volume_db = vol_db
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return
