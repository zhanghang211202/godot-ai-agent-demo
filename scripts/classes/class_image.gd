extends RefCounted
## Load imported textures through Godot's resource system, including in PCKs.

static func load_image(path: String) -> Image:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path, "Texture2D"):
		var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
		if texture != null:
			return texture.get_image()
	# A fresh checkout may run before Godot has imported its assets. The PNG is
	# present in that case; exported PCKs use the imported resource above.
	if FileAccess.file_exists(path):
		return Image.load_from_file(path)
	return null
