class_name EmberPixelArt
extends RefCounted
## Original, hand-drawn pixel sprites. No external art or runtime file access.
## Icons are 32 px; characters are 96 px with crisp 2 px source pixels.

static var _icons: Dictionary = {}
static var _characters: Dictionary = {}

const INK := Color("282731")
const PALETTE := {
	"X": Color("282731"), "d": Color("42414b"),
	"n": Color("553a35"), "b": Color("805342"), "l": Color("b67b50"),
	"s": Color("b9785b"), "t": Color("e6ad78"), "f": Color("ffe1a2"),
	"h": Color("b8aa86"), "w": Color("e6ddba"), "W": Color("fff2ce"),
	"g": Color("244d48"), "v": Color("387b65"), "u": Color("75b18a"),
	"r": Color("9f493c"), "o": Color("df7c43"), "y": Color("ffc56c"),
	"S": Color("596b77"), "m": Color("98b4b6"), "L": Color("e0eeee"),
	"G": Color("ad7d39"), "Y": Color("ebba62"), "F": Color("ffe5a3"),
	"a": Color("446c37"), "c": Color("76a44c"), "e": Color("b6d470"),
	"q": Color("695272"), "p": Color("ac7b9c"), "P": Color("edbecb"),
	"B": Color("36536e"), "C": Color("86c8d1"), "D": Color("bde8df")
}


static func icon(kind: String) -> Texture2D:
	if _icons.has(kind):
		return _icons[kind]
	var pixels := _icon_pixels(kind)
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var palette := PALETTE
	if kind == "fury":
		palette = PALETTE.duplicate()
		palette["L"] = Color("ffcf88")
		palette["W"] = Color("fff0bc")
		palette["m"] = Color("e27c55")
		palette["S"] = Color("a74645")
	_stamp_centered(img, pixels, palette)
	var texture := ImageTexture.create_from_image(img)
	_icons[kind] = texture
	return texture


static func character(kind: String) -> Texture2D:
	if _characters.has(kind):
		return _characters[kind]
	var pixels: Array = _character_pixels(kind)
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	# A quiet, stepped contact shadow grounds each transparent sprite.
	var shadow_width := 26 if kind == "boss" else 20
	if kind == "slime":
		shadow_width = 23
	elif kind == "wolf":
		shadow_width = 30
	for dy in range(-2, 3):
		var half_width: int = shadow_width / 2 - absi(dy) * 2
		for dx in range(-half_width, half_width + 1):
			img.set_pixel(24 + dx, 43 + dy, Color(0.12, 0.13, 0.16, 0.17))
	var width := _width(pixels)
	_stamp(img, pixels, Vector2i((48 - width) / 2, 44 - pixels.size()), PALETTE)
	img.resize(96, 96, Image.INTERPOLATE_NEAREST)
	var texture := ImageTexture.create_from_image(img)
	_characters[kind] = texture
	return texture


static func draw_icon(canvas: CanvasItem, kind: String, rect: Rect2, tint := Color.WHITE) -> void:
	canvas.draw_texture_rect(icon(kind), rect, false, tint)


static func _width(pixels: Array) -> int:
	var result := 0
	for row in pixels:
		result = maxi(result, str(row).length())
	return result


static func _stamp_centered(img: Image, pixels: Array, palette: Dictionary) -> void:
	_stamp(img, pixels, Vector2i((img.get_width() - _width(pixels)) / 2, (img.get_height() - pixels.size()) / 2), palette)


static func _stamp(img: Image, pixels: Array, offset: Vector2i, palette: Dictionary) -> void:
	for row in range(pixels.size()):
		var line: String = pixels[row]
		for col in range(line.length()):
			var key := line.substr(col, 1)
			var point := offset + Vector2i(col, row)
			if palette.has(key) and point.x >= 0 and point.y >= 0 and point.x < img.get_width() and point.y < img.get_height():
				img.set_pixelv(point, palette[key])


static func _icon_pixels(kind: String) -> Array:
	match kind:
		"flame_sword":
			return [
				"......................X....",
				".....................XyX...",
				"...................XXyFX...",
				"..................XoyFFX...",
				"..................XyFWWX...",
				"...............X.XoyFWyoX..",
				"..............XoXXyFWyrX...",
				"..............XyoyFWyrX....",
				".............XoyyFWyrX.....",
				".............XyyFWyrX......",
				"..........X.XoyFWyrX.......",
				".........XoXXyFWyrX........",
				".........XyyyFWyrX.........",
				"........XoyyFWyrX..........",
				".....XX.XyyFWyrX...........",
				"....XYFXyyFWyrX............",
				"....XGYYXFWyrX.............",
				".....XGYXXyrX..............",
				"......XYoYYX...............",
				".....XqXrrYYX..............",
				"....XpqX.XYYGX.............",
				"...XpqX...XYFX.............",
				"..XpqX.....XX..............",
				".XpqX......................",
				"XYFYX......................",
				"XFoGX......................",
				".XGX.......................",
				"..X........................"
			]
		"thorn_shield":
			return [
				"...........XX.............",
				"......X...XeX....X........",
				".....XcX.XecX...XcX.......",
				"....XecXXXXcXXXXecX.......",
				".....XclllbclllbcX........",
				"..XX.XlYllllllbbX.XX......",
				".XWlXXllXXXXXXbbXXlWX.....",
				"..XWlXlXeecccaXbXlWX......",
				"...XlXlXeWecccaXbXlX......",
				"..XXlXlXeeecccaXbXlXX.....",
				".XWllXlXeecccaaXbXllWX....",
				"..XXlXlXeecXcaaXbXlXX.....",
				"...XlXlXeccWcaaXbXlX......",
				"...XlXlXccWWWaaXbXlX......",
				"..XXlXlXcWWWWWaXbXlXX.....",
				".XWllXlXccWWWaaXbXllWX....",
				"..XWlXlXcccWaaaXbXlWX.....",
				"...XlXlXcccWaaaXbXlX......",
				"...XlXlXccaaaaaXbXlX......",
				"....XlXlXcaaaaXbXlX.......",
				"...XcXlXlXaaaXbXlXcX......",
				"..XecXXlXlXXXbXlXXceX.....",
				"...XX..XllbbbllX..XX......",
				"........XllbllX...........",
				".........XlbbX............",
				"..........XbX.............",
				"...........X.............."
			]
		"windbow":
			return [
				"...............XXXX.......",
				"..............XDDuX.......",
				".............XDeuX........",
				"............XLvvgX........",
				"...........XL.XDuvX.......",
				"..........XL..XLDuvX......",
				"...DDD...XL....XLDuvX.....",
				"..D...D.XL.....XLDuvX.....",
				".......XL.......XLDvgX....",
				"......XL........XLDvgX....",
				"..DD.XL.........XWvgX.....",
				".D..XL..........XYYgX.....",
				"...XL...........XYFgX.....",
				"..XXXXXXXXXXXXXXXXXXXXXX..",
				".XDDDuuuuuuuuuuuuuCYLLLX..",
				"..XXXXXXXXXXXXXXXXXXXXXX..",
				"...XL...........XYFgX.....",
				".D..XL..........XYYgX.....",
				"..DD.XL.........XWvgX.....",
				"......XL........XLDvgX....",
				".......XL.......XLDvgX....",
				"..D....XL......XLDuvX.....",
				"...DD...XL.....XLDuvX.....",
				".........XL...XLDuvX......",
				"..........XL..XDuvX.......",
				"...........XL.XuvX........",
				"............XDeuX.........",
				".............XDuX.........",
				"..............XX.........."
			]
		"greater_potion":
			return [
				"..........XXXXXX..........",
				".........XLWWWmmX.........",
				".........XWDDCmmX.........",
				".........XXmmmSXX.........",
				".........XlYYYGbX.........",
				"........XXYYYYGGXX........",
				"........XLDCCCCmSX........",
				".........XLDCCmSX.........",
				".........XLDCCmSX.........",
				"........XLDCCCmmSX........",
				".......XLDCCCCmmmSX.......",
				"......XLDCCCCCCmmmSX......",
				".....XLDCCCCCCCCmmmSX.....",
				"....XLDDCCCCCCCCCmmmSX....",
				"...XLDDCBBBBBBBBBCmmSSX...",
				"...XLDCCBBWWBBBqBqmmSSX...",
				"..XLDDCCBWWWBBqqqqBmmSSX..",
				"..XLDDCCWWWBqqqqqqBmmSSX..",
				"..XLDDCCWWWqqqqqqqBmmSSX..",
				"..XLDCCCWWWqqqqqqqBmmSSX..",
				"..XLDCCCBWWWqqqqWqBmmSSX..",
				"..XLDCCCBWWWWqqWWqBmmSSX..",
				"...XLDCCBBWWWWWWqqBmmSX...",
				"...XLDCCBBBWWWWqqBBmmSX...",
				"....XLDCCBBBBBBBBBmmSX....",
				".....XLDCCCCCCCCCmmSX.....",
				"......XXmmmmmmmmSSXX......",
				"........XXXXXXXXXX........"
			]
		"precision":
			return [
				"........XXXXXXXX.........",
				"......XXWWWWWWWWXX.......",
				"....XXWWrrrrrrrrWWXX.....",
				"...XWWrrWWWWWWWWrrWWX....",
				"..XWWrWWWWWWWWWWWWrWWX...",
				"..XWrWWrrXXXXrrWWWWrWX...",
				".XWWrWrrWWWWWWrrWWWrrWX..",
				".XWrWWrWWrrrrWWrWWWWrWX..",
				"XWWrWWrWrrrrrrWrWWWWrWWX.",
				"XWWrWWrWrYYYYrWrWWWWrWWX.",
				"XWWrWWrWrYFYYrWrWWWWrWWX.",
				"XWWrWWrWrYYYYrWrWWWWrWWX.",
				"XWWrWWrWrrrrrrWrWWWWrWWX.",
				".XWrWWrWWrrrrWWrWWWWrWX..",
				".XWWrWrrWWWWWWrrWWWrrWX..",
				"..XWrWWrrWWWWrrWWWWrWX...",
				"..XWWrWWWWWWWWWWWWrWWX...",
				"...XWWrrWWWWWWWWrrWWX....",
				"....XXWWrrrrrrrrWWXX.....",
				"......XXWWWWWWWWXX.......",
				"........XXXXXXXX........."
			]
		"sword", "fury":
			return [
				".....................XXX",
				"....................XWLX",
				"...................XWLMX",
				"..................XWLMSX",
				".................XWLMSX.",
				"................XWLMSX..",
				"...............XWLMSX...",
				"..............XWLMSX....",
				".............XWLMSX.....",
				"............XWLMSX......",
				".....XX....XWLMSX.......",
				"....XYYX..XWLMSX........",
				".....XYYXXWLMSX.........",
				"......XYYXLMSX..........",
				".......XYyYSX...........",
				".......XGYyYX...........",
				"......XlbXYYGX..........",
				".....XlbX.XYGX..........",
				"....XlbX...XX...........",
				"...XlbX.................",
				"..XYYX..................",
				"..XFGX..................",
				"...XX..................."
			]
		"longsword":
			return [
				"......................XX",
				".....................XWX",
				"....................XLWX",
				"...................XLWMX",
				"..................XLWMSX",
				".................XLWMSX.",
				"................XLWMSX..",
				"...............XLWMSX...",
				"..............XLWMSX....",
				".............XLWMSX.....",
				"............XLWMSX......",
				"...........XLWMSX.......",
				"......XX..XLWMSX........",
				".....XYFXXLWMSX.........",
				".....XGYYXWMSX..........",
				"......XGYYMSX...........",
				".......XYuuYX...........",
				"......XlXugYYX..........",
				".....XlnX.XYYGX.........",
				"....XlnX...XYFX.........",
				"...XlnX.....XX..........",
				"..XlnX..................",
				".XYFX...................",
				".XFYGX..................",
				"..XGX...................",
				"...X...................."
			]
		"shield", "bastion":
			return [
				".........XXXXX.........",
				".....XXXXYYYFGXXXX.....",
				"..XXXWYYYYYYYYYGGGXXX..",
				".XWYFGGGGGGGGGGGGGGGGX.",
				".XYYGvvuuuvvvvvgvvvGGX.",
				".XYYGvuuWuvvvvvvgvvGGX.",
				".XYYGvuWWWvvvvvvvvgGGX.",
				".XYYGvuuWuvvvvvvvvgGGX.",
				".XYYGvvvWvvvvvvvvvgGGX.",
				".XYYGvvvWvvvvvvvvvgGGX.",
				".XYYGvvWWWvvvvvvvvgGGX.",
				".XYYGvWWWWWvvvvvvvgGGX.",
				".XYYGvvWWWvvvvvvvvggGX.",
				"..XYGvvvWvvvvvvvgggGX..",
				"..XYGvvvWvvvvvvggggGX..",
				"...XYGvvWvvvvvggggGX...",
				"...XYGvvvvvvvgggggGX...",
				"....XYGvvvvvgggggGX....",
				".....XYGvvvgggggGX.....",
				"......XYGvgggggGX......",
				".......XYGGGGGGX.......",
				"........XYYGGGX........",
				".........XYGGX.........",
				"..........XXX.........."
			]
		"bow":
			return [
				"..............XXX.........",
				".............XlYbX........",
				"............XW.lbX........",
				"...........XW.XlYbX.......",
				"..........XW...XlYbX......",
				".........XW....XlYbX......",
				"........XW......XlYbX.....",
				".......XW.......XlYbX.....",
				"......XW........XlYbX.....",
				".....XW.........XlnbX.....",
				"....XW..........XlnbX.....",
				"...XW...........XlnbX.....",
				"..XW............XlnbX.....",
				".XXXXXXXXXXXXXXXXXXXXXXXX.",
				"..YlllllllllllllllllYLLLX.",
				"...XXXXXXXXXXXXXXnlXXXXX..",
				"....XW..........XlnbX.....",
				".....XW.........XlnbX.....",
				"......XW........XlYbX.....",
				".......XW.......XlYbX.....",
				"........XW......XlYbX.....",
				".........XW....XlYbX......",
				"..........XW...XlYbX......",
				"...........XW.XlYbX.......",
				"............XW.lbX........",
				".............XlYbX........",
				"..............XXX........."
			]
		"herb", "renewal":
			return [
				"............XX.........",
				"...........XeeX........",
				"...........XecX........",
				".....XXX..XeccaX.......",
				"....XeecX.XeccaX.......",
				"...XeeeccXXecccaX......",
				"...XeecccaXecccaX......",
				"....XecccaXeccaX.......",
				".....XcccaXccaX........",
				"......XaaaXaaX.........",
				".......XavavX..XXXX....",
				".XXXX...XvavX.XecccX...",
				"XecccX..XvavXXeecccX...",
				"XeccccX.XvavXeecccX....",
				".XccccaXXvavXcccaX.....",
				"..XccaaaXvavXaaaX......",
				"...XXXXXXvavXXXX.......",
				".......XlYYYYX.........",
				".......XYYllYX.........",
				"........XvavX..........",
				".......XavavaX.........",
				".......XXvavXX.........",
				".........XXX..........."
			]
		"potion":
			return [
				".......XXXXXXXX.......",
				".......XlllllbX.......",
				".......XlYllbbX.......",
				".......XllbbbbX.......",
				"......XXYYYYGGXX......",
				"......XLWWmmmmSX......",
				".......XLWmmmSX.......",
				".......XLWmmmSX.......",
				"......XLWWmmmmSX......",
				".....XLWWmmmmmSSX.....",
				"....XLWWmmmmmmmSSX....",
				"...XLWWmmmmmmmmmSSX...",
				"..XLWWmPPPPppppmmSSX..",
				"..XLWmPPPPppppqqmSSX..",
				".XLWmPPPPpppppqqqmSSX.",
				".XLWmPPPPppppqqqqmSSX.",
				".XLWmPPPWWppqqqqqmSSX.",
				".XLWmPPWWWWpqqqqqmSSX.",
				".XLWmPPPWWppqqqqqmSSX.",
				"..XLmPppppppqqqqmSSX..",
				"..XLmppppppqqqqqmSSX..",
				"...XLmppppqqqqqmSSX...",
				"....XLLmmmmmmmSSSX....",
				".....XXSSSSSSSSXX.....",
				".......XXXXXXXX......."
			]
		"whetstone":
			return [
				".............XXXXX.......",
				"..........XXXLWWWmXX.....",
				".......XXXLWWWmmmmmmXX...",
				"....XXXLWWWmmmmmmmmmmSX..",
				"..XXLWWWmmmmmmmmmmSSSSX..",
				".XLWWWmmmmmmmmmmSSSSSSX..",
				".XLWmmmmmmmmmmSSSSSSSSX..",
				".XLmmmmmmmmmSSSSSSSSSSX..",
				".XSmmmmmLmSSSSSSSSSSSSX..",
				".XSmmmmLmSSSSSSSSSSSdX...",
				".XSSmmLmSSSSSSSSSSddX....",
				"..XSSLmSSSSSSSSSdddX.....",
				"...XSSSSSSSSSSdddXX......",
				"....XSSSSSSSdddXX........",
				".....XXSSSdddXX..........",
				".......XXddXX............",
				".........XX.............."
			]
		"ember":
			return [
				".............X...........",
				"............XoX..........",
				"............XyX..........",
				"...........XyoX..........",
				"...........XyroX.........",
				"..........XyoroX.........",
				".....X....XyorrX.........",
				"....XoX..XyyorrX.........",
				"....XyoXXyyoorroX........",
				"...XoyyyFFyoorroX........",
				"...XoyyFFFyooorroX..X....",
				"..XoyyFFFFyyooorrXXoX....",
				"..XoyyFFWFyyooorroyX.....",
				"..XoyFFWWFFyyooorryX.....",
				".XoyyFFWWWFFyooorroyX....",
				".XoyyFWWWWFFyyooorryX....",
				".XoyyFWWWWFFyyooorryX....",
				"..XoyFFWWFFyyooorryX.....",
				"..XooyFFFFyyooorrrX......",
				"...XooyyyyooorrrrX.......",
				"....XoooooorrrrrX........",
				".....XXrrrrrrrXX.........",
				".......XXXXXXX..........."
			]
		"coin", "fortune":
			return [
				".......XXXXXXXX.......",
				".....XXWYYYYYGGXX.....",
				"....XWFYYYYYYYYGGX....",
				"...XWFYGGGGGGYYGGGX...",
				"..XWFYGYYYYYYGYYGGGX..",
				"..XFYGYFYYYFYYGYYGGX..",
				".XWFYGYFYFYFYYGYYGGGX.",
				".XWYYGYYFFFYYYGYYGGGX.",
				".XWYYGYYYFYYYYGYYGGGX.",
				".XWYYGYYYFYYYYGYYGGGX.",
				".XYYYGYFFFFFYYGYYGGGX.",
				".XYYYGYYYYYYYYGYYGGGX.",
				"..XYYYGGYYYYGGYYGGGX..",
				"..XYYYYYGGGGYYYGGGGX..",
				"...XYYYYYYYYYYGGGGX...",
				"....XYYYYYYGGGGGGX....",
				".....XXGGGGGGGGXX.....",
				".......XXXXXXXX......."
			]
		"heart", "vitality":
			return [
				"...XXXXX....XXXXX...",
				"..XPooooX..XoooooX..",
				".XPPPooooXXooooorrX.",
				"XPPWPPooooooooorrrrX",
				"XPWWPooooooooorrrrrX",
				"XPPPooooooooorrrrrrX",
				"XPoooooooooorrrrrrrX",
				"XoooooooooorrrrrrrrX",
				".XoooooooorrrrrrrrX.",
				"..XoooooorrrrrrrrX..",
				"...XoooorrrrrrrrX...",
				"....XoorrrrrrrrX....",
				".....XrrrrrrrrX.....",
				"......XrrrrrrX......",
				".......XrrrrX.......",
				"........XrrX........",
				".........XX........."
			]
		"spark":
			return [
				"...........X...........",
				"..........XYX..........",
				"..........XFX..........",
				".........XYFYX.........",
				".........XFYFX.........",
				"........XYFWFYX........",
				"........XFWFWFX........",
				".......XYFWWWFYX.......",
				"......XYFWWWWWFYX......",
				"...XXXYFWWWWWWWFYXXX...",
				".XXYYFFWWWWWWWWWFFYYXX.",
				"XYYFFWWWWWWWWWWWWWFFYYX",
				".XXYYFFWWWWWWWWWFFYYXX.",
				"...XXXYFWWWWWWWFYXXX...",
				"......XYFWWWWWFYX......",
				".......XYFWWWFYX.......",
				"........XFWFWFX........",
				"........XYFWFYX........",
				".........XFYFX.........",
				".........XYFYX.........",
				"..........XFX..........",
				"..........XYX..........",
				"...........X..........."
			]
		"backpack":
			return [
				"........XXXXXX.........",
				".......XlYYYYbX........",
				".......XYXXXXbX........",
				"....XXXXYXXXXbXXXX.....",
				"...XllYYYYYYYYYYbbX....",
				"..XlYYllYYYYllYYbbbX...",
				"..XlYYllYYYYllYYbbbX...",
				"..XllYllYYYYllYYbbbX...",
				".XXlllbbllllbbllbbbXX..",
				"XlbXllGGllllGGllbbXblX.",
				"XlbXllYFllllYFllbbXblX.",
				"XlbXllGGllllGGllbbXblX.",
				"XlbXlllbbbbbbbbbbbXblX.",
				"XlbXlllXXXXXXXXbbbXblX.",
				"XlbXllXlllllllbbXbXblX.",
				"XlbXllXlYYYYllbbXbXblX.",
				"XlbXllXlllGGllbbXbXblX.",
				"XlbXllXlllYFllbbXbXblX.",
				".XXXllXlllGGllbbXbXXX..",
				"..XlllXlllllllbbXbbX...",
				"..XlllXXXXXXXXXXbbbX...",
				"...XllllllbbbbbbbbX....",
				"....XXXXXXXXXXXXXX....."
			]
		_:
			return _icon_pixels("spark")


static func _character_pixels(kind: String) -> Array:
	match kind:
		"hero":
			return [
				".............XXXXXXX...............",
				"...........XXbbbbbbbXX.............",
				"..........XblYYYYYllbbX............",
				".........XblYlllYYllbbbX...........",
				".........XlYlllbbbbbbbbbX..........",
				"........XbYllbbbbbbbbbnnX..........",
				"........XbYlbbbntttttbbnX..........",
				"........XlYlbbntfftfftXnnX.........",
				"........XlYbbnttfftffttXnX.........",
				"........XlYbbntffXtXftXnX.........",
				".........XbbbntffXtXftXnX.........",
				".......XXXXbnntttttttssX...........",
				"......XWWWWXnnttfffttsX............",
				".....XWWhWWwXnssstttssX............",
				"....XWWhWWWWwXXssssXX..............",
				"...XWWhWWWWWwXooooorX..............",
				"..XhWWhWWWWWwXyoooorX..............",
				"..XhWWhWWWWWXXYYYYooX..............",
				"..XhWWXXXXWWwXoorrrXX..............",
				"..XhWXlllbXWwwXvgggX...............",
				"..XhXlYYlbXWwwXvggvgX..............",
				"..XhXlYYlbXWwwXvgvvgXX.............",
				"..XhXlYYlbXWwhXvvvggXftX...........",
				"..XhXlbbnbXWwhXvvgggXfttX..........",
				"..XhXlbbnbXWwhXvvgggXsttX...XX.....",
				"..XhXlGGlbXWwhXlYYYblXXsX..XWLX....",
				"..XhXlYFlbXWwhXlYFbbnX.XX.XWLMX....",
				"..XhXlGGlbXWwhXlGGbbnX...XWLMSX....",
				"..XhXXbbbXWWhXvvvgvvgX..XWLMSX.....",
				"..XhWWXXXWWhhXvvgggggX.XWLMSX......",
				"...XhWWWWWhhhXvggggggXXWLMSX.......",
				"...XhWWWWWhhXvvvvgggXXWLMSX........",
				"....XhWWWhhXgvvgvggXXYMSX..........",
				".....XhhhXXgvvgvggXbXYYYX..........",
				"......XXX.XggXXgggXblXYYGX.........",
				".........XgggX.XgggXbX.XXX.........",
				".........XgggX.XgggXXX.............",
				"........XbbbnX.XnbbbX..............",
				"........XbYbnX.XnbYbX..............",
				".......XblbbnX.XnbblbX.............",
				".......XbbbnnX.XnnbbbbX............",
				".......XXXXXX...XXXXXX............."
			]
		"slime":
			return [
				".............XXXXXX.............",
				"...........XXeeeeeeXX...........",
				".........XXeeWWWeeeeXX.........",
				"........XeeWWWWWeeeeccX........",
				".......XeeWWWWeeeeeccccX.......",
				"......XeeWWWeeeeeccccccX.......",
				".....XeeWWeeeeeecccccccaX......",
				"....XeeWeeeeeeeccccccccaX......",
				"...XeeeeeeeeeeccccccccccaX.....",
				"...XeeeeeeeeecccccccccccaX.....",
				"..XeeeeeeeeeccccccccccccaX.....",
				"..XeeeXXXeeccccccXXXccccaX.....",
				"..XeeeXWXeeccccccXWXccccaX.....",
				".XeeeeXXXeeccccccXXXccccaX.....",
				".XeeeeeeeeeccccccccccccccaX....",
				".XeeeeeooeeccXccXccoooccaX....",
				".XeeeeeooeecccXXcccoooccaX....",
				".XeeeeeeeeccccccccccccccaX....",
				"..XeeeeeecccccccccccccaaaX....",
				"..XeeeeccccccccccccccaaaaaX...",
				".XeeccccccccccccccccaaaaaaaX..",
				"XeeccccccaaaaaccccaaaaaaaaaaX.",
				"XccccccaaXXXXaaacccaaaXXXaaaX.",
				".XXXXXXX.....XXXXXXXX...XXXX.."
			]
		"goblin":
			return [
				"............XXXXXX................",
				"...........XacccccXX..............",
				"..........XceeeccccX..............",
				"...XXX...XceeeeccccaX....XXX......",
				"...XeaX.XceeeeeccccaX..XceX......",
				"...XecaXXceeeeccccccaXXccaX......",
				"....XecacccXXXcccXXXcccccaX......",
				".....XcccccXyXcccXyXccccaX.......",
				"......XccccXXXcccXXXcccaX........",
				".......XcccccccaccccccaX.........",
				"........XcccaccaccccccaX.........",
				"........XcccaaaccWWWcaX..........",
				".........XccXWWWWXXcaX...........",
				"..........XccXXXXccaX............",
				"...........XXaaaXXX..............",
				".........XXllbbbbbXX.............",
				"........XllbllllllbbX............",
				".......XecXlllllllbbccX...........",
				"......XeceXllbllllbbXccX..........",
				"......XeccXllblllbbbXccaX.........",
				".....XeccaXllbbbbbbbXccaX........",
				".....XecaXXYYYGGYYYYXXcaX........",
				".....XcaX.XllYFGlllX.XcaX........",
				".....XXX..XllGGGlllX.XXX..XXX....",
				"...........XllbbblX.....XXbYbX...",
				"...........XlbXblX....XbbYbbX....",
				"..........XcaX.XacX..XbbYbbX.....",
				"..........XcaX.XacX.XbbYbbX......",
				".........XccaX.XaccXXbbYbbX......",
				".........XccaX.XaccXbbYbbX.......",
				"........XaaaaX.XaaaaXbbX.........",
				"........XXXXXX.XXXXXX.X.........."
			]
		"wolf":
			return [
				".............XX......XX................",
				"............XSmX....XSmX...............",
				"............XSLmX..XSmmX...............",
				"...........XSSLLmXXSmmmX...............",
				"...........XSSLLmmmmmmmSX..............",
				"..........XSSLLmmmmmmmmSSX.............",
				"..........XSLLmmmmXymXmSSX............",
				".........XSSLLmmmmXXmXmSSX.............",
				"........XSSLLmmmmmmmmmmSSXXXX..........",
				".......XSSLLmmmmmmmmmmmSXXSSSX.........",
				"......XSSLLmmmmmmmmmSSSmWWWX..........",
				".....XSSLLmmmmmmmmmSSSSWWXX...........",
				"....XSSLLmmmmmmmmSSSSSWXX.............",
				"...XSSLLmmmmmmmmSSSSSSX...............",
				"..XSSLLmmmmmmmmSSSSSSSSX..............",
				".XSSLLmmmmmmmmmSSSSSSSSSX.............",
				"XSSLLmmmmmmmmmmSSSSSSSSSSX............",
				"XSSmmmmmmmmmmmmSSSSSSSSSSSX...........",
				"XSSmmmmmSSmmmmmSSSSSSSSSSSSX..........",
				".XSSmmmSSSSmmmmSSSSSSSSSSSSSX.........",
				"..XSSSSSXSmmmmSSSSSSSSSSSSSSX.........",
				"...XSSSX.SmmmSSSSSSXXXXSSSSSSX........",
				"....XXX..XSmSSSSSSX....XSSSSSX........",
				".........XSmSSSSSX.....XSSSSX.........",
				".........XSmSSSSX......XSSSSX.........",
				"........XSmSSSSX.......XSSSSX.........",
				".......XSmmSSSX.......XSmmSSX.........",
				"......XSmmmSSX.......XSmmmSSX.........",
				"......XWWmSSSX.......XWWmSSSX.........",
				"......XXXXXXXX.......XXXXXXXX........."
			]
		"boss":
			return [
				".....XXX...................XX..........",
				"....XlbbX.................XlbX.........",
				"....XllbX.......XX.......XllbX.........",
				".....XllbX.....XabX.....XllbX..........",
				"......XllbX....XllX....XllbX...........",
				".......XllbXX..XllX..XXllbX............",
				"....XXXXlllbbXXlllXXXlllbXX............",
				"...XeecXllllbbllllllbbllbceX...........",
				"..XeeeecXlllbbllllllbbllceecX..........",
				"..XeWWeeccccXllllllXccceeWeecX.........",
				".XeWWWeeeccccXllllXccceeWWWeecX........",
				".XeeeeeecccccXllllXcccceeeeeccX........",
				"..XeeeccccccllllllllllcccccXX..........",
				"...XXXXclllllllllllllllcccX............",
				"......XlllllllbbbllllllbbX.............",
				".....XllllllbbbbblllllbbbX.............",
				".....XllllllbbbbblllllbbbbbX...........",
				"....XllllXXXbbbbblllXXXbbbbX...........",
				"....XllllXyFXbbbblllXyFXbbbX...........",
				"....XllllXooXbbbblllXooXbbbX...........",
				".....XlllXXXbbbbblllXXXbbbX............",
				".....XlllllbbbbbbllllbbbbbbX...........",
				"...XXXllllbbbbbbbllllbbbbbXXX..........",
				"..XcccllllbbbXXXXXXllbbbbbcccX.........",
				".XccccllllbbXWllWllXlbbbbccccX........",
				"XeccccllllbbXXXXXXXXlbbbbcccccX........",
				"XeeccXlllllbbbbbbbbllbbbbbXccccX.......",
				"XeecXllllllbbbbbbbblllbbbbXccccaX......",
				"XecXlllllllbbbbbbbblllbbbbXcccaX.......",
				"XccXllllllbbbbbXXXXXXXXbbbXccaX........",
				"XcaXllllllbbbbXeeeeccccXbbXcaX.........",
				"XaaXllllllbbbbXeeeccccaXbbXaaX.........",
				"XXXXllllllbbbbXeeccccaaXbbXXXX.........",
				"...XllllllbbbbXccccaaaXbbbX............",
				"...XllllllbbbbbXXXXXXXbbbbX............",
				"...XllllllbbbbbbbbbbbbbbbX.............",
				"....XlllllbbbbXbbbXbbbbbbX.............",
				"....XlllllbbbX...XbbbbbbX..............",
				"...XllllllbbbX...XbbbbbbbX.............",
				"..XlllllllbbbX...XbbbbbbbbX............",
				".XlllbbllbbbbX...XbbbllbbbX............",
				".XXXXXXXXXXXXX...XXXXXXXXXX............"
			]
		_:
			return _character_pixels("slime")
