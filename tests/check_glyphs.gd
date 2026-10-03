extends SceneTree
## 스크립트에 쓰인 비한글·비ASCII 글자 중 Gaegu에 없는 것을 찾는다

func _init() -> void:
	Data.load_fonts()
	var font: FontFile = load("res://assets/fonts/NanumGothic-Regular.ttf")
	var seen := {}
	for dir in ["res://scripts/", "res://scripts/phases/"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var txt := FileAccess.get_file_as_string(dir + f)
			for i in txt.length():
				var c := txt.unicode_at(i)
				if c < 128 or (c >= 0xAC00 and c <= 0xD7A3) or (c >= 0x3131 and c <= 0x318E):
					continue
				seen[c] = true
	var missing := []
	var ok := []
	for c in seen:
		if font.has_char(c):
			ok.append(String.chr(c))
		else:
			missing.append("%s(U+%04X)" % [String.chr(c), c])
	print("있음: ", " ".join(ok))
	print("없음: ", " ".join(missing))
	quit()
