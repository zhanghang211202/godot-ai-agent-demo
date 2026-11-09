extends Node
## Executed from the packed fixture, with no loose PNG files beside the PCK.
const ClassImage = preload("res://class_image.gd")

func _ready() -> void:
	var paths := ["res://mage-idle.png", "res://moon-sentinel.png", "res://advanced-spells-v2.png", "res://wind-prism.png", "res://moon-familiar.png"]
	for path in paths:
		if FileAccess.file_exists(path):
			printerr("PACK FIXTURE FAILED: unexpectedly found loose source ", path)
			get_tree().quit(1)
			return
		var image := ClassImage.load_image(path)
		if image == null or image.is_empty() or image.get_width() < 500:
			printerr("PACK FIXTURE FAILED: ", path)
			get_tree().quit(1)
			return
		print("PACK FIXTURE LOADED: ", path, " ", image.get_size())
	if ClassImage.load_image("res://missing-texture.png") != null:
		printerr("PACK FIXTURE FAILED: missing texture")
		get_tree().quit(1)
		return
	print("Image pack fixture: 6 checks, 0 failures")
	get_tree().quit(0)
