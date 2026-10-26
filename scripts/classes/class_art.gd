extends RefCounted
## Cache for newly drawn static battle-pose candidates. No source PNG is edited.

const ROOT := "res://assets/art/c1-static-v1/"
const FILES := {
	"mage-idle": "characters/mage-idle.png",
	"knight-sword-idle": "characters/knight-sword-idle.png",
	"knight-greatblade-idle": "characters/knight-greatblade-idle.png",
	"moon-court": "environments/moon-court.png",
	"reliquary-hall": "environments/reliquary-hall.png",
}
static var _cache: Dictionary = {}

static func asset_path(id: String) -> String:
	return ROOT + str(FILES[id]) if FILES.has(id) else ""

static func get_asset(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var path := asset_path(id)
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var picture := Image.load_from_file(path)
	if picture == null or picture.is_empty():
		return {}
	var source_rect := Rect2(Vector2.ZERO, Vector2(picture.get_size()))
	if id in ["mage-idle", "knight-sword-idle", "knight-greatblade-idle"]:
		source_rect = _visible_bounds(picture)
	var result := {"id": id, "path": path, "size": picture.get_size(), "source_rect": source_rect,
		"texture": ImageTexture.create_from_image(picture), "alpha_threshold": 128}
	_cache[id] = result
	return result

static func _visible_bounds(picture: Image) -> Rect2:
	# Faint alpha residues must not decide the actor's displayed height.
	var rgba := picture.duplicate() as Image
	rgba.convert(Image.FORMAT_RGBA8)
	var data := rgba.get_data()
	var width := rgba.get_width()
	var minimum := Vector2i(width, rgba.get_height())
	var maximum := Vector2i(-1, -1)
	for offset in range(3, data.size(), 4):
		if data[offset] < 128:
			continue
		var pixel: int = offset >> 2
		var point := Vector2i(pixel % width, pixel / width)
		minimum.x = mini(minimum.x, point.x)
		minimum.y = mini(minimum.y, point.y)
		maximum.x = maxi(maximum.x, point.x)
		maximum.y = maxi(maximum.y, point.y)
	if maximum.x < 0:
		return Rect2()
	return Rect2(Vector2(minimum), Vector2(maximum - minimum + Vector2i.ONE))
