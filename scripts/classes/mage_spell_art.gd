extends RefCounted
## Original tiny pixel masks, expanded with nearest sampling in the arena.
## These are effect sprites, not character/source-art cleanup.

const PALETTES := {
	"flame": {"o": "7b2545", "r": "d54438", "a": "fa7134", "y": "ffc45a", "w": "fff0b2"},
	"comet": {"o": "503782", "r": "8056c2", "a": "b78aff", "y": "dfc4ff", "w": "fff4ff"},
	"lance": {"o": "245a99", "r": "258bc4", "a": "63d4eb", "y": "b5f8fa", "w": "f3ffff"},
	"shard": {"o": "245a99", "r": "258bc4", "a": "63d4eb", "y": "b5f8fa", "w": "f3ffff"}
}
const MASKS := {
	"flame": [
		"...........a............", "..........ara...........", "..........aya...........",
		".........ayya...........", "....a....aywa...........", "....ra...aywya..........",
		"....ara.aaywwya.........", "....ayraaywwwya.........", "...aayyaaaywwyra........",
		"...aywya..aywwyra.......", "..aaywwya.aywwwya..a....", "..aywwwyaaywwwwyaaara...",
		".raywwwyyaywwwwyyaayra..", ".raywwwwyyywwwwwyyywya..", "oraywwwwwwwwwwwwyywwya..",
		"oraywwwwwwwwwwwwwwwwyra.", "oraywwwwwwwwwwwwwwwwwya.", "oraywwwwwwwwwwwwwwwwwya.",
		".raywwwwwwwwwwwwwwwwyra.", ".raaywwwwwwwwwwwwwwyaro.", "..raaywwwwwwwwwwwwyaaro.",
		"..orraaywwwwwwwwyyaaro..", "...orraayyyyyyyyaarro...", "....orrraaaaaaaarrro....",
		"......orrrrrrrrroo......", "........oooooo.........."
	],
	"comet": [
		"....................a...........", ".................aaaya..........", "...........rraaaayyywya.........",
		".....orrraaayyyyywwwwwya........", "orrraaayyyyywwwwwwwwwwwya.......", "..orrraayyyyywwwwwwwwwwwya......",
		"......orrraaaayyyywwwwwya.......", "............orraayyywya........", ".................aaaya..........",
		"....................a..........."
	],
	"lance": [
		"............................a.......", ".........................aaywa......", "......oooooo..........aayywwwya.....",
		"ooorrraaaaaaaaarraaaayyyywwwwwwya....", ".rrraayyyyyyyyyyyyyywwwwwwwwwwwwya...",
		"wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwya.", ".rrraayyyyyyyyyyyyyywwwwwwwwwwwwya...",
		"ooorrraaaaaaaaarraaaayyyywwwwwwya....", "......oooooo..........aayywwwya.....",
		".........................aaywa......", "............................a......."
	],
	"shard": ["....o...", "...ora..", "..orya..", "..rayya.", ".oraywa.", ".oraywa.", ".orayya.", "..raya..", "..ora...", "...o...."]
}
static var _textures: Dictionary = {}

static func texture(kind: String, frame: int = 0) -> Texture2D:
	var variant := posmod(frame, 3) if kind == "flame" else 0
	var key := "%s:%d" % [kind, variant]
	if _textures.has(key):
		return _textures[key]
	if not MASKS.has(kind):
		return null
	var width := 0
	for row: String in MASKS[kind]:
		width = maxi(width, row.length())
	var image := Image.create(width, MASKS[kind].size(), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(MASKS[kind].size()):
		var row: String = MASKS[kind][y]
		for x in range(row.length()):
			var pixel := row.substr(x, 1)
			if PALETTES[kind].has(pixel):
				# Three tongue variations; integer shifts preserve crisp pixels.
				var shift := (posmod(variant + y / 4, 3) - 1) if kind == "flame" and y < 11 else 0
				var tone := "y" if kind == "flame" and pixel == "w" and y < 10 else pixel
				image.set_pixel(clampi(x + shift, 0, width - 1), y, Color(PALETTES[kind][tone]))
	var result := ImageTexture.create_from_image(image)
	_textures[key] = result
	return result
