extends RefCounted
## Dedicated mage-slice atlases. Source PNGs are never resampled or rewritten.

const ROOT := "res://assets/art/mage-trial-v1/"
const ICONS := ["spark", "fire_mote", "water_mote", "wind_mote", "flame_glyph", "tide_lances", "arcane_focus", "mage_ward"]
static var _icons: Dictionary = {}
static var _enemy: Dictionary = {}

static func icon(kind: String) -> Dictionary:
	if kind not in ICONS:
		return {}
	if _icons.is_empty():
		var path := ROOT + "items/mage-items.png"
		var image := Image.load_from_file(path)
		if image == null:
			return {}
		image.convert(Image.FORMAT_RGBA8)
		var cell := Vector2i(image.get_width() / 4, image.get_height() / 2)
		var texture := ImageTexture.create_from_image(image)
		for index in range(ICONS.size()):
			var region := Rect2i(Vector2i(index % 4, index / 4) * cell, cell)
			var bounds := _bounds(image, region)
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(bounds)
			_icons[ICONS[index]] = {"path": path, "texture": texture, "atlas": atlas, "source_rect": Rect2(bounds), "region": Rect2(region), "source_size": image.get_size()}
	return _icons.get(kind, {})

static func enemy() -> Dictionary:
	if not _enemy.is_empty():
		return _enemy
	var path := ROOT + "enemies/moon-sentinel.png"
	var image := Image.load_from_file(path)
	if image == null:
		return {}
	image.convert(Image.FORMAT_RGBA8)
	var half := image.get_size() / 2
	var regions: Array[Rect2i] = [Rect2i(Vector2i.ZERO, half), Rect2i(Vector2i(half.x, 0), half),
		Rect2i(Vector2i(0, half.y), Vector2i(624, half.y)), Rect2i(Vector2i(624, half.y), Vector2i(image.get_width() - 624, half.y))]
	# Dedicated attack frame reaches into the otherwise empty central gutter.
	var feet := [330, 870, 392, 873]
	var frames: Array[Dictionary] = []
	var height := 0.0
	var left := 0.0
	var right := 0.0
	for index in range(4):
		var bounds := _bounds(image, regions[index])
		var pivot := Vector2(feet[index], bounds.end.y)
		frames.append({"source_rect": Rect2(bounds), "region": Rect2(regions[index]), "pivot": pivot})
		height = maxf(height, bounds.size.y)
		left = maxf(left, pivot.x - bounds.position.x)
		right = maxf(right, bounds.end.x - pivot.x)
	_enemy = {"path": path, "texture": ImageTexture.create_from_image(image), "size": image.get_size(), "frames": frames, "height": height, "left": left, "right": right}
	return _enemy

static func _bounds(image: Image, region: Rect2i) -> Rect2i:
	var bytes := image.get_data()
	var minimum := region.end
	var maximum := Vector2i(-1, -1)
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if bytes[(y * image.get_width() + x) * 4 + 3] < 128:
				continue
			minimum = Vector2i(mini(minimum.x, x), mini(minimum.y, y))
			maximum = Vector2i(maxi(maximum.x, x), maxi(maximum.y, y))
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE) if maximum.x >= 0 else Rect2i()
