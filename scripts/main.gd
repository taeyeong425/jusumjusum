extends Node
## 페이즈 전환기. 각 페이즈는 코드로 장면을 짓는 Node 스크립트다.

const PHASES := {
	"menu": "res://scripts/phases/menu.gd",
	"reveal": "res://scripts/phases/reveal.gd",
	"collect": "res://scripts/phases/collect.gd",
	"build": "res://scripts/phases/build.gd",
	"exhibit": "res://scripts/phases/exhibit.gd",
	"settle": "res://scripts/phases/settle.gd",
	"gallery": "res://scripts/phases/gallery.gd",
}

var current: Node


func _ready() -> void:
	get_window().theme = UI.theme()
	Game.main = self
	if Game.autotest:
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
	add_child(current)
	if Game.autotest:
		print("[autotest] phase → %s (round %d)" % [phase, Game.round_i])
