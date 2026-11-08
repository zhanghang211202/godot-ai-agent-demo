extends Node
## Run before importing the fixture, like a fresh checkout launched directly.
const ClassImage = preload("res://class_image.gd")

func _ready() -> void:
	var path := "res://mage-idle.png"
	var image := ClassImage.load_image(path)
	if not FileAccess.file_exists(path) or image == null or image.get_size() != Vector2i(1122, 1402):
		printerr("COLD FIXTURE FAILED: image unavailable before import")
		get_tree().quit(1)
		return
	print("Cold image fixture: 1 check, 0 failures")
	get_tree().quit(0)
