class_name EmberForestStage
extends RefCounted
## Original 512 x 144 pixel stage. Fixed 32-color palette, no bitmap source.
## Only this local RNG is used; generation never advances a run's RNG.

const WIDTH := 512
const HEIGHT := 144
const GROUND_Y := 126
const PALETTE := [
	Color("101f23"), Color("15282b"), Color("1b3435"), Color("23403d"),
	Color("294b44"), Color("31554a"), Color("3a6052"), Color("486d59"),
	Color("597a65"), Color("718c70"), Color("8aa187"), Color("a6b596"),
	Color("0b1a20"), Color("11272a"), Color("193531"), Color("24463a"),
	Color("345442"), Color("4c6546"), Color("64754c"), Color("84905c"),
	Color("253d3b"), Color("344e46"), Color("496052"), Color("637564"),
	Color("262e2a"), Color("383b2d"), Color("4a4933"), Color("5a593d"),
	Color("776c43"), Color("ad8b4f"), Color("dbb56c"), Color("f2d49a")
]

static var _cached: Texture2D
static var _expanded: Texture2D
static var _expanded_width := 0


static func ground_y() -> int:
	return GROUND_Y


static func texture_for_width(minimum_width: int) -> Texture2D:
	var base: Texture2D = texture()
	if minimum_width <= WIDTH:
		return base
	var target_width: int = ceili(float(minimum_width) / 32.0) * 32
	if _expanded != null and _expanded_width == target_width:
		return _expanded
	var original: Image = base.get_image()
	var expanded := Image.create(target_width, HEIGHT, false, Image.FORMAT_RGBA8)
	# Continue quiet forest strips beyond the authored 512px stage. Pixel scale
	# and the complete ground line stay unchanged in intermediate window widths.
	for x in range(0, target_width, 64):
		expanded.blit_rect(original, Rect2i(160, 0, mini(64, target_width - x), HEIGHT), Vector2i(x, 0))
	var center_x: int = (target_width - WIDTH) / 2
	expanded.blit_rect(original, Rect2i(0, 0, WIDTH, HEIGHT), Vector2i(center_x, 0))
	_expanded_width = target_width
	_expanded = ImageTexture.create_from_image(expanded)
	return _expanded


static func texture() -> Texture2D:
	if _cached != null:
		return _cached
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 718204
	image.fill(PALETTE[1])
	_paint_distance(image, rng)
	_paint_ruins(image)
	_paint_middle(image, rng)
	_paint_ground(image, rng)
	_paint_foreground(image)
	_cached = ImageTexture.create_from_image(image)
	return _cached


static func _paint_distance(image: Image, rng: RandomNumberGenerator) -> void:
	# Wide horizontal bands give atmospheric depth without gradient filtering.
	_rect(image, 0, 20, WIDTH, 27, 2)
	_rect(image, 0, 47, WIDTH, 22, 3)
	_rect(image, 0, 69, WIDTH, 25, 4)
	_rect(image, 0, 94, WIDTH, 32, 5)
	for x in range(-16, WIDTH + 18, 19):
		var base := rng.randi_range(89, 113)
		var height := rng.randi_range(52, 97)
		var trunk := rng.randi_range(2, 4)
		_tree(image, x + rng.randi_range(-5, 5), base, height, trunk, 3, 4)
	for x in range(-10, WIDTH, 11):
		var y := rng.randi_range(99, 108)
		_rect(image, x, y, rng.randi_range(18, 35), 112 - y, 5)
	# Mist breaks distant trunks and leaves the central fight area calm.
	_rect(image, 73, 81, 348, 3, 5)
	_rect(image, 110, 84, 271, 2, 5)
	_rect(image, 29, 107, 437, 4, 6)
	_rect(image, 83, 105, 319, 2, 6)
	_rect(image, 146, 111, 221, 4, 6)
	_rect(image, 175, 116, 156, 2, 7)


static func _paint_ruins(image: Image) -> void:
	# A broken distant arch remains below the contrast of the combatants.
	_rect(image, 347, 76, 7, 34, 20)
	_rect(image, 376, 79, 8, 31, 20)
	_rect(image, 352, 70, 25, 7, 20)
	_rect(image, 358, 66, 15, 5, 20)
	_rect(image, 350, 78, 2, 27, 21)
	_rect(image, 377, 83, 2, 24, 21)
	_rect(image, 356, 72, 17, 2, 21)
	_rect(image, 346, 109, 40, 4, 21)
	_rect(image, 344, 113, 45, 3, 6)
	# Nearer mossy remnant frames the left edge of the playable clearing.
	_rect(image, 97, 91, 27, 31, 13)
	_rect(image, 94, 87, 31, 5, 20)
	_rect(image, 99, 94, 9, 10, 20)
	_rect(image, 111, 94, 10, 10, 21)
	_rect(image, 98, 106, 9, 8, 21)
	_rect(image, 110, 106, 11, 8, 20)
	_rect(image, 97, 116, 22, 7, 20)
	_rect(image, 98, 88, 13, 1, 7)
	_rect(image, 112, 89, 8, 2, 6)
	_rect(image, 100, 94, 1, 6, 22)
	_rect(image, 113, 106, 7, 1, 22)
	_rect(image, 90, 121, 38, 4, 15)
	_lantern(image, 111, 77)


static func _paint_middle(image: Image, rng: RandomNumberGenerator) -> void:
	_tree(image, 67, 123, 113, 8, 14, 15)
	_tree(image, 430, 123, 107, 8, 14, 15)
	_tree(image, 18, 125, 121, 11, 13, 14)
	_tree(image, 489, 125, 119, 10, 13, 14)
	# Understory appears at the sides, avoiding busy detail behind the hero.
	for x in [2, 24, 43, 61, 81, 422, 441, 461, 482, 503]:
		var base := rng.randi_range(115, 123)
		_crown(image, x, base, rng.randi_range(11, 22), rng.randi_range(4, 8), 15)
		_rect(image, x - 4, base - 3, 6, 1, 16)
	# Small, quiet hanging vines sit above the characters.
	_line(image, Vector2i(180, 0), Vector2i(180, 16), 1, 3)
	_line(image, Vector2i(180, 16), Vector2i(175, 23), 1, 3)
	_line(image, Vector2i(313, 0), Vector2i(313, 11), 1, 3)
	_rect(image, 176, 10, 4, 2, 4)
	_rect(image, 314, 7, 3, 2, 4)


static func _paint_ground(image: Image, rng: RandomNumberGenerator) -> void:
	# Every x has the same support line: characters' feet anchor at y=126.
	_rect(image, 0, 124, WIDTH, 2, 15)
	_rect(image, 0, GROUND_Y, WIDTH, 1, 17)
	_rect(image, 0, 127, WIDTH, 2, 14)
	_rect(image, 0, 129, WIDTH, 15, 24)
	_rect(image, 0, 131, WIDTH, 1, 25)
	_rect(image, 0, 140, WIDTH, 4, 12)
	for x in range(5, WIDTH - 6, 9):
		var width := rng.randi_range(2, 6)
		_rect(image, x, rng.randi_range(133, 138), width, 1, 25)
		if x < 130 or x > 391:
			_rect(image, x, 125, rng.randi_range(2, 4), 1, 18)
	for stone in [Vector2i(62, 132), Vector2i(151, 134), Vector2i(354, 132), Vector2i(452, 135)]:
		_rect(image, stone.x, stone.y, 7, 2, 26)
		_rect(image, stone.x + 1, stone.y - 1, 5, 1, 27)
	# A handful of fallen leaves, not a field of random high-frequency noise.
	_rect(image, 137, 128, 3, 1, 28)
	_rect(image, 379, 128, 2, 1, 28)
	_rect(image, 88, 130, 2, 1, 27)


static func _paint_foreground(image: Image) -> void:
	# Two original stepped silhouettes form a canopy and frame the clearing.
	_line(image, Vector2i(27, 130), Vector2i(37, 55), 17, 12)
	_line(image, Vector2i(37, 55), Vector2i(24, -5), 13, 12)
	_line(image, Vector2i(35, 57), Vector2i(87, 17), 9, 12)
	_line(image, Vector2i(87, 17), Vector2i(129, 3), 5, 12)
	_line(image, Vector2i(35, 72), Vector2i(0, 39), 8, 12)
	_line(image, Vector2i(25, 119), Vector2i(31, 61), 3, 14)
	_line(image, Vector2i(31, 61), Vector2i(24, 17), 2, 14)
	_line(image, Vector2i(41, 61), Vector2i(77, 28), 2, 14)
	_line(image, Vector2i(482, 131), Vector2i(472, 52), 18, 12)
	_line(image, Vector2i(472, 52), Vector2i(491, -5), 13, 12)
	_line(image, Vector2i(475, 60), Vector2i(433, 22), 8, 12)
	_line(image, Vector2i(433, 22), Vector2i(395, 6), 4, 12)
	_line(image, Vector2i(476, 86), Vector2i(510, 61), 7, 12)
	_line(image, Vector2i(476, 118), Vector2i(466, 56), 3, 14)
	_line(image, Vector2i(466, 56), Vector2i(485, 6), 2, 14)
	for patch in [Vector2i(10, 6), Vector2i(46, 1), Vector2i(84, 3), Vector2i(118, -1), Vector2i(394, 0), Vector2i(425, 6), Vector2i(465, 1), Vector2i(500, 7)]:
		_crown(image, patch.x, patch.y, 40, 12, 12)
		_crown(image, patch.x - 4, patch.y - 3, 28, 8, 13)
	# Bark facets and roots avoid repeated uniform vertical stripes.
	_rect(image, 34, 89, 2, 15, 15)
	_rect(image, 471, 79, 2, 16, 15)
	_line(image, Vector2i(29, 122), Vector2i(9, 130), 4, 12)
	_line(image, Vector2i(37, 122), Vector2i(54, 129), 3, 12)
	_line(image, Vector2i(480, 124), Vector2i(501, 132), 4, 12)
	_line(image, Vector2i(472, 124), Vector2i(456, 130), 3, 12)
	_fern(image, 13, 128, -1)
	_fern(image, 55, 130, 1)
	_fern(image, 450, 130, -1)
	_fern(image, 503, 130, 1)
	# Fern stems stay above the dark soil, leaving the support line readable.
	_rect(image, 0, 140, WIDTH, 4, 12)


static func _tree(image: Image, x: int, base: int, height: int, width: int, trunk: int, leaves: int) -> void:
	var top := base - height
	_rect(image, x - width / 2, top, width, height, trunk)
	_line(image, Vector2i(x, top + height / 3), Vector2i(x - 14, top + 6), maxi(1, width / 2), trunk)
	_line(image, Vector2i(x, top + height / 2), Vector2i(x + 17, top + 20), maxi(1, width / 2), trunk)
	_crown(image, x - 9, top + 4, width * 3 + 10, 8 + width, leaves)
	_crown(image, x + 14, top + 14, width * 3 + 9, 7 + width, leaves)


static func _crown(image: Image, x: int, y: int, width: int, height: int, color: int) -> void:
	_rect(image, x - width / 2, y - height / 3, width, height * 2 / 3, color)
	_rect(image, x - width / 2 + 4, y - height / 2, width - 7, height, color)
	_rect(image, x - width / 2 - 3, y - 1, width + 5, maxi(2, height / 3), color)


static func _lantern(image: Image, x: int, y: int) -> void:
	# Opaque palette steps create a restrained warm halo without blur.
	_rect(image, x - 9, y - 2, 19, 12, 5)
	_rect(image, x - 6, y, 13, 9, 17)
	_line(image, Vector2i(x, y - 8), Vector2i(x, y - 3), 1, 25)
	_rect(image, x - 4, y - 3, 9, 2, 26)
	_rect(image, x - 5, y - 1, 11, 2, 28)
	_rect(image, x - 3, y + 1, 7, 8, 25)
	_rect(image, x - 2, y + 1, 5, 6, 29)
	_rect(image, x - 1, y + 2, 3, 4, 30)
	_rect(image, x, y + 2, 1, 3, 31)
	_rect(image, x - 4, y + 8, 9, 2, 26)
	_rect(image, x - 2, y + 10, 5, 1, 28)


static func _fern(image: Image, x: int, base: int, direction: int) -> void:
	var tip := Vector2i(x + direction * 13, base - 16)
	_line(image, Vector2i(x, base), tip, 1, 16)
	for step in range(2, 13, 3):
		var point := Vector2i(x + direction * step, base - step - 2)
		_line(image, point, point + Vector2i(-direction * 5, -1), 1, 17)
		_line(image, point, point + Vector2i(direction * 3, -5), 1, 16)
	_line(image, Vector2i(x, base), Vector2i(x - direction * 8, base - 10), 1, 16)
	_rect(image, x - direction * 6, base - 9, 3, 1, 17)


static func _line(image: Image, start: Vector2i, end: Vector2i, width: int, color: int) -> void:
	var span := end - start
	var steps := maxi(absi(span.x), absi(span.y))
	for step in range(steps + 1):
		var weight := float(step) / maxi(1, steps)
		var point := Vector2(start).lerp(Vector2(end), weight).round()
		_rect(image, int(point.x) - width / 2, int(point.y) - width / 2, width, width, color)


static func _rect(image: Image, x: int, y: int, width: int, height: int, color: int) -> void:
	var clipped := Rect2i(x, y, width, height).intersection(Rect2i(0, 0, WIDTH, HEIGHT))
	if clipped.has_area():
		image.fill_rect(clipped, PALETTE[color])
