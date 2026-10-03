extends SceneTree
## 프로젝트 테마를 .tres로 굽는다. CanvasLayer 아래 컨트롤까지 전부 적용되게 하려면
## 창 테마가 아니라 프로젝트 테마(gui/theme/custom)여야 한다.
## godot --headless -s res://tests/make_theme.gd

func _init() -> void:
	var err := ResourceSaver.save(UI.theme(), "res://assets/theme.tres")
	print("theme saved: ", err)
	quit()
