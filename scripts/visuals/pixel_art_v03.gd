class_name EmberArtV03
extends RefCounted
## Original v0.3 native pixel art. All image pixels are authored here, without
## imported game art, filtering or square-to-footprint deformation.

const Legacy = preload("res://scripts/visuals/pixel_art.gd")
const CLIPS := {
	"idle": {"frames": 4, "seconds": 0.15, "loop": true},
	"attack": {"frames": 4, "seconds": 0.075, "loop": false},
	"hurt": {"frames": 2, "seconds": 0.08, "loop": false},
	"defeat": {"frames": 4, "seconds": 0.11, "loop": false},
}
const FOOTPRINTS := {
	"sword": Vector2i(1, 2), "longsword": Vector2i(1, 3),
	"flame_sword": Vector2i(1, 3), "shield": Vector2i(2, 2),
	"thorn_shield": Vector2i(2, 2), "bow": Vector2i(2, 1),
	"windbow": Vector2i(3, 1), "herb": Vector2i.ONE,
	"potion": Vector2i.ONE, "greater_potion": Vector2i(1, 2),
	"whetstone": Vector2i.ONE, "ember": Vector2i.ONE,
}
const INK := Color("283131")
const CLOTH_DARK := Color("888e79")
const CLOTH := Color("d3d0ac")
const CLOTH_LIGHT := Color("fff0c7")
const LEATHER_DARK := Color("503b35")
const LEATHER := Color("916044")
const LEATHER_LIGHT := Color("c18a55")
const COPPER := Color("bd8e4b")
const GOLD_LIGHT := Color("f2d38d")
const SCARF_DARK := Color("9d493b")
const SCARF := Color("df7c43")
const SCARF_LIGHT := Color("ffc56c")
const SKIN_DARK := Color("b97759")
const SKIN := Color("e4ab78")
const SKIN_LIGHT := Color("ffe0a3")
const GREEN_DARK := Color("244d48")
const GREEN := Color("387b65")
const GREEN_LIGHT := Color("75b18a")
const STEEL_DARK := Color("596b77")
const STEEL := Color("98b4b6")
const STEEL_LIGHT := Color("e0eeee")

static var _characters: Dictionary = {}
static var _inventory: Dictionary = {}
static var _icons: Dictionary = {}


static func character(kind: String, clip: String = "idle", time: float = 0.0) -> Texture2D:
	if kind not in ["hero", "slime"]:
		return Legacy.character("boss" if kind == "tree" else kind)
	var actual_clip := clip if CLIPS.has(clip) else "idle"
	var frame := frame_index(actual_clip, time)
	var key := "%s/%s/%d" % [kind, actual_clip, frame]
	if not _characters.has(key):
		_characters[key] = ImageTexture.create_from_image(character_frame(kind, actual_clip, frame))
	return _characters[key]


static func character_pivot(kind: String) -> Vector2:
	return Vector2(32, 58) if kind in ["hero", "slime"] else Vector2(48, 88)


static func frame_index(clip: String, time: float) -> int:
	var definition: Dictionary = CLIPS.get(clip, CLIPS["idle"])
	var count := int(definition["frames"])
	var frame := int(floor(maxf(0.0, time) / float(definition["seconds"])))
	return frame % count if bool(definition["loop"]) else mini(frame, count - 1)


static func inventory(kind: String) -> Texture2D:
	if not _inventory.has(kind):
		_inventory[kind] = ImageTexture.create_from_image(inventory_image(kind))
	return _inventory[kind]


static func icon(kind: String) -> Texture2D:
	if kind not in ["sword", "shield", "whetstone"]:
		return Legacy.icon(kind)
	if not _icons.has(kind):
		var image := _blank(32, 32)
		match kind:
			"sword":
				_sword_icon(image)
			"shield":
				image = inventory_image(kind)
				image.resize(32, 32, Image.INTERPOLATE_NEAREST)
			"whetstone":
				_stone(image)
		_icons[kind] = ImageTexture.create_from_image(image)
	return _icons[kind]


static func character_frame(kind: String, clip: String, frame: int) -> Image:
	var image := _blank(64, 64)
	var actual_clip := clip if CLIPS.has(clip) else "idle"
	var index := clampi(frame, 0, int(CLIPS[actual_clip]["frames"]) - 1)
	if kind == "hero":
		_hero(image, actual_clip, index)
	elif kind == "slime":
		_slime(image, actual_clip, index)
	return image


static func inventory_image(kind: String) -> Image:
	var footprint: Vector2i = FOOTPRINTS.get(kind, Vector2i.ONE)
	var image := _blank(footprint.x * 32, footprint.y * 32)
	match kind:
		"sword":
			_sword(image)
		"shield":
			_shield(image)
		"whetstone":
			_stone(image)
		_:
			# Honest, temporary legacy artwork. A 32 px square remains a square
			# inside the correct footprint, never stretched into a long object.
			var legacy_image := Legacy.icon(kind).get_image()
			image.blit_rect(legacy_image, Rect2i(Vector2i.ZERO, legacy_image.get_size()),
				(image.get_size() - legacy_image.get_size()) / 2)
	return image


static func _hero(image: Image, clip: String, frame: int) -> void:
	var down := 0
	var sway := 0
	var wind := [0, 1, 2, 1][frame % 4] as int
	if clip == "idle":
		down = [0, 0, -1, 0][frame] as int
	elif clip == "attack":
		sway = [1, 2, 1, 0][frame] as int
		down = [0, 1, 0, 0][frame] as int
		wind = 3 - frame
	elif clip == "hurt":
		sway = -1 - frame
		down = frame
		wind = 2
	elif clip == "defeat":
		down = [1, 4, 7, 8][frame] as int
		sway = [0, 0, 1, 2][frame] as int
		wind = 0
	var offset := Vector2i(sway, down)
	# The boots stay anchored while the upper body breathes, recoils or kneels.
	_poly(image, [29,43, 35,43, 36,53, 33,57, 26,57, 27,53], INK)
	_poly(image, [37,43, 42,43, 44,53, 48,55, 48,58, 38,58, 36,53], INK)
	_rect(image, Rect2i(29, 44, 5, 9), GREEN_DARK)
	_rect(image, Rect2i(38, 45, 4, 9), GREEN)
	_rect(image, Rect2i(29, 45, 2, 6), GREEN_LIGHT)
	_poly(image, [28,52, 33,52, 34,55, 32,57, 27,57, 27,55], LEATHER)
	_poly(image, [39,53, 43,53, 43,54, 47,55, 47,57, 38,57], LEATHER)
	_line(image, Vector2i(28, 53), Vector2i(31, 53), LEATHER_LIGHT)
	_line(image, Vector2i(40, 54), Vector2i(43, 55), LEATHER_LIGHT)
	_line(image, Vector2i(27, 57), Vector2i(33, 57), LEATHER_DARK)
	_line(image, Vector2i(38, 57), Vector2i(47, 57), LEATHER_DARK)
	# Broad cloak silhouette. A stepped hem, cool shadow and warm shoulder
	# light establish cloth without noisy gradients or oversized black edges.
	_poly(image, [25,26, 35,24, 42,28, 43,37, 47,46, 42,49, 36,48, 30,50, 23,47, 23,37], INK, offset)
	_poly(image, [26,27, 34,26, 39,28, 40,37, 44,45, 41,47, 36,46, 30,48, 25,46, 25,37], CLOTH, offset)
	_poly(image, [26,28, 32,27, 31,36, 27,43, 25,45, 25,35], CLOTH_LIGHT, offset)
	_poly(image, [36,28, 40,30, 40,37, 44,45, 41,47, 36,46, 34,40], CLOTH_DARK, offset)
	_line(image, Vector2i(31, 33) + offset, Vector2i(29, 43) + offset, CLOTH_DARK)
	_line(image, Vector2i(28, 47) + offset, Vector2i(30, 48) + offset, GOLD_LIGHT)
	_line(image, Vector2i(37, 46) + offset, Vector2i(40, 47) + offset, GOLD_LIGHT)
	# Leather pack: rolled top, two clasp straps and a rounded outer pocket.
	_poly(image, [17,28, 23,27, 27,31, 27,44, 25,47, 16,47, 13,43, 13,33], INK, offset)
	_poly(image, [17,29, 23,29, 25,32, 25,43, 23,45, 16,45, 15,42, 15,33], LEATHER, offset)
	_rect(image, Rect2i(Vector2i(17, 28) + offset, Vector2i(7, 5)), LEATHER_LIGHT)
	_line(image, Vector2i(18, 29) + offset, Vector2i(23, 29) + offset, GOLD_LIGHT)
	_line(image, Vector2i(16, 33) + offset, Vector2i(24, 33) + offset, LEATHER_DARK)
	_rect(image, Rect2i(Vector2i(18, 31) + offset, Vector2i(2, 12)), LEATHER_DARK)
	_rect(image, Rect2i(Vector2i(23, 32) + offset, Vector2i(2, 10)), LEATHER_DARK)
	_rect(image, Rect2i(Vector2i(17, 35) + offset, Vector2i(4, 4)), COPPER)
	_rect(image, Rect2i(Vector2i(18, 36) + offset, Vector2i(2, 2)), LEATHER_DARK)
	_pixel(image, 17 + sway, 35 + down, GOLD_LIGHT)
	_poly(image, [15,39, 21,39, 23,41, 23,44, 21,45, 16,45], LEATHER_DARK, offset)
	_rect(image, Rect2i(Vector2i(16, 40) + offset, Vector2i(5, 3)), LEATHER_LIGHT)
	_pixel(image, 19 + sway, 41 + down, GOLD_LIGHT)
	# Chest sash and belt give the front of the body structure.
	_poly(image, [34,30, 37,29, 42,41, 40,44, 37,37], LEATHER_DARK, offset)
	_line(image, Vector2i(35, 31) + offset, Vector2i(40, 41) + offset, LEATHER_LIGHT)
	_rect(image, Rect2i(Vector2i(33, 43) + offset, Vector2i(9, 3)), LEATHER_DARK)
	_rect(image, Rect2i(Vector2i(38, 43) + offset, Vector2i(3, 3)), COPPER)
	_pixel(image, 39 + sway, 44 + down, GOLD_LIGHT)
	# Face, pointed hair locks and a lighter hood folded behind the head.
	_poly(image, [29,11, 34,9, 42,9, 46,13, 46,18, 44,25, 39,28, 31,26, 27,21, 27,15], INK, offset)
	_poly(image, [29,14, 33,12, 34,22, 37,26, 32,25, 29,21], CLOTH, offset)
	_line(image, Vector2i(29, 15) + offset, Vector2i(29, 20) + offset, CLOTH_LIGHT)
	_poly(image, [35,13, 42,13, 44,16, 44,20, 47,21, 46,23, 43,23, 43,26, 36,26, 32,22, 32,17], SKIN, offset)
	_poly(image, [35,14, 40,14, 41,17, 41,23, 37,24, 34,21, 34,17], SKIN_LIGHT, offset)
	_poly(image, [42,18, 44,19, 44,21, 46,22, 43,23, 43,25, 40,26, 38,24, 42,23], SKIN_DARK, offset)
	_poly(image, [30,13, 33,11, 41,10, 44,12, 45,16, 42,17, 40,15, 38,18, 37,15, 34,16, 33,21, 30,22, 29,19], LEATHER_DARK, offset)
	_poly(image, [31,13, 35,12, 40,11, 43,13, 39,13, 37,15, 35,14, 32,17, 30,18], LEATHER, offset)
	_line(image, Vector2i(33, 12) + offset, Vector2i(37, 12) + offset, LEATHER_LIGHT)
	if clip == "hurt" or (clip == "defeat" and frame > 0) or (clip == "idle" and frame == 3):
		_line(image, Vector2i(41, 20) + offset, Vector2i(43, 20) + offset, INK)
	else:
		_rect(image, Rect2i(Vector2i(42, 18) + offset, Vector2i(2, 3)), INK)
		_pixel(image, 42 + sway, 18 + down, CLOTH_LIGHT)
	_line(image, Vector2i(40, 24) + offset, Vector2i(42, 24) + offset, LEATHER_DARK)
	# Distinct orange scarf: its tail reacts to movement rather than moving
	# the complete character, and the boots remain at the same baseline.
	_poly(image, [28,25, 35,25, 40,26, 43,26, 43,29, 36,31, 29,30, 26,28], INK, offset)
	_poly(image, [29,26, 35,26, 39,27, 42,27, 41,28, 35,29, 29,29, 27,28], SCARF, offset)
	_line(image, Vector2i(29, 26) + offset, Vector2i(34, 26) + offset, SCARF_LIGHT)
	_poly(image, [29,29, 28,33, 22,35, 17,34-wind, 12,35-wind, 14,30-wind, 22,32, 26,29], INK, offset)
	_poly(image, [28,30, 27,32, 22,34, 17,33-wind, 14,34-wind, 15,31-wind, 22,33, 26,30], SCARF, offset)
	_line(image, Vector2i(16, 31 - wind) + offset, Vector2i(21, 33) + offset, SCARF_LIGHT)
	_line(image, Vector2i(22, 34) + offset, Vector2i(27, 32) + offset, SCARF_DARK)
	# The front arm has a neutral hand; weapon-specific attacks are effects
	# owned by the UI, so an archer does not visibly swing a fixed sword.
	var hand := Vector2i(43, 40)
	if clip == "attack":
		hand = [Vector2i(49, 33), Vector2i(51, 31), Vector2i(48, 35), Vector2i(44, 39)][frame]
	elif clip == "defeat":
		hand += Vector2i(0, -mini(down, 5))
	_poly(image, [40,30, 43,31, hand.x+2,hand.y-2, hand.x,hand.y+2, 40,37, 38,34], INK, offset)
	_poly(image, [40,31, 42,32, hand.x,hand.y-2, hand.x-1,hand.y, 40,36, 39,34], CLOTH, offset)
	_line(image, Vector2i(40, 31) + offset, Vector2i(41, 34) + offset, CLOTH_LIGHT)
	_rect(image, Rect2i(hand + offset, Vector2i(4, 4)), INK)
	_rect(image, Rect2i(hand + offset + Vector2i(0, 1), Vector2i(3, 2)), SKIN)
	_pixel(image, hand.x + sway, hand.y + down + 1, SKIN_LIGHT)


static func _slime(image: Image, clip: String, frame: int) -> void:
	var radius_x := [22, 23, 22, 21][frame % 4] as int
	var radius_y := [14, 13, 15, 15][frame % 4] as int
	var center_x := 32
	var leaf_bend := [0, 1, 0, -1][frame % 4] as int
	if clip == "attack":
		radius_x = [22, 26, 24, 22][frame] as int
		radius_y = [14, 11, 12, 14][frame] as int
		center_x = [31, 28, 29, 32][frame] as int
		leaf_bend = 3
	elif clip == "hurt":
		radius_x = [24, 21][frame] as int
		radius_y = [12, 16][frame] as int
		center_x = 33 + frame
		leaf_bend = 2
	elif clip == "defeat":
		radius_x = [23, 25, 27, 28][frame] as int
		radius_y = [12, 9, 6, 4][frame] as int
		leaf_bend = 2 + frame
	var top := 58 - radius_y * 2
	var center := Vector2i(center_x, 58 - radius_y)
	var moss_dark := Color("315647")
	var moss := Color("689b62")
	var moss_light := Color("acd17f")
	var dew := Color("e3ebae")
	# A one-pixel stepped silhouette and broad, hand-shaped light clusters.
	_ellipse(image, center, Vector2i(radius_x, radius_y), INK)
	_ellipse(image, center, Vector2i(radius_x-1, radius_y-1), moss_dark)
	_ellipse(image, center + Vector2i(-2,-1), Vector2i(radius_x-3, maxi(1,radius_y-2)), moss)
	_ellipse(image, center + Vector2i(-6,-3), Vector2i(maxi(3,radius_x-9), maxi(1,radius_y-5)), moss_light)
	# Stable contact edge, plus two small lobes which keep the mass organic.
	_ellipse(image, Vector2i(center_x-12, 55), Vector2i(7, 2), moss_dark)
	_ellipse(image, Vector2i(center_x+12, 55), Vector2i(7, 2), moss_dark)
	_line(image, Vector2i(center_x-radius_x+5, 57), Vector2i(center_x+radius_x-5, 57), INK)
	if radius_y > 6:
		_poly(image, [center_x-13,top+7, center_x-10,top+4, center_x-4,top+3, center_x-4,top+5, center_x-10,top+6, center_x-12,top+9], dew)
		_pixel(image, center_x - 14, top + 10, dew)
		_poly(image, [center_x+7,top+11, center_x+11,top+10, center_x+14,top+13, center_x+12,top+16, center_x+8,top+15], moss_dark)
		_pixel(image, center_x + 10, top + 11, moss_light)
		_line(image, Vector2i(center_x+3, 53), Vector2i(center_x+8, 54), moss_dark)
	# A sprout crown and asymmetric moss tufts establish the creature's own
	# identity. The crown drops with squash; it is not scaled as a texture.
	var stem := Vector2i(center_x+5, top+3)
	_line(image, stem, stem + Vector2i(leaf_bend, -10), INK)
	_line(image, stem + Vector2i(1,0), stem + Vector2i(leaf_bend+1,-9), GREEN)
	_poly(image, [-1,-5, -7,-6, -10,-11, -10,-15, -5,-14, -1,-10, 0,-7], INK, stem)
	_poly(image, [-2,-7, -6,-8, -8,-12, -8,-13, -5,-12, -2,-9], GREEN_LIGHT, stem)
	_line(image, stem+Vector2i(-7,-12), stem+Vector2i(-2,-7), moss_light)
	_poly(image, [leaf_bend,-8, leaf_bend+1,-13, leaf_bend+7,-16, leaf_bend+10,-15, leaf_bend+8,-10, leaf_bend+3,-7], INK, stem)
	_poly(image, [leaf_bend+1,-9, leaf_bend+3,-12, leaf_bend+7,-14, leaf_bend+8,-14, leaf_bend+6,-11], GREEN_LIGHT, stem)
	_pixel(image, stem.x+leaf_bend+5, stem.y-12, dew)
	# Facial features sit toward the left: default enemy-facing direction.
	var eye_y := top + maxi(5, radius_y - 1)
	var left_eye := center_x - 12
	var right_eye := center_x - 2
	if clip == "defeat" or (clip == "idle" and frame == 3):
		_line(image, Vector2i(left_eye, eye_y), Vector2i(left_eye+3,eye_y+1), INK)
		_line(image, Vector2i(right_eye,eye_y+1), Vector2i(right_eye+3,eye_y), INK)
	elif clip == "hurt":
		_line(image, Vector2i(left_eye,eye_y), Vector2i(left_eye+3,eye_y+3), INK)
		_line(image, Vector2i(left_eye+3,eye_y), Vector2i(left_eye,eye_y+3), INK)
		_line(image, Vector2i(right_eye,eye_y), Vector2i(right_eye+3,eye_y+3), INK)
		_line(image, Vector2i(right_eye+3,eye_y), Vector2i(right_eye,eye_y+3), INK)
	else:
		_rect(image, Rect2i(left_eye,eye_y,4,5), INK)
		_rect(image, Rect2i(right_eye,eye_y,4,5), INK)
		_pixel(image, left_eye, eye_y+1, dew)
		_pixel(image, right_eye, eye_y+1, dew)
	var mouth_y := mini(55, eye_y + 7)
	if clip == "attack":
		_ellipse(image, Vector2i(center_x-6,mouth_y), Vector2i(3,2), INK)
		_pixel(image, center_x-6, mouth_y+1, Color("b77b6b"))
	else:
		_line(image, Vector2i(center_x-8,mouth_y), Vector2i(center_x-6,mouth_y+1), INK)
		_line(image, Vector2i(center_x-6,mouth_y+1), Vector2i(center_x-4,mouth_y), INK)
	if radius_y > 9:
		_rect(image, Rect2i(left_eye-2,eye_y+5,3,1), Color("bc9b74"))
		_rect(image, Rect2i(right_eye+2,eye_y+5,3,1), Color("bc9b74"))


static func _sword(image: Image) -> void:
	# Dedicated 1x2 silhouette: a long, narrow blade, leather grip and copper
	# quillons. This is not an enlarged 32 px thumbnail.
	_poly(image, [16,3, 21,12, 20,40, 19,45, 12,45, 11,40, 11,12], INK)
	_poly(image, [16,5, 19,13, 18,42, 16,44, 13,42, 13,13], STEEL)
	_poly(image, [16,6, 16,41, 14,42, 13,39, 13,14], STEEL_LIGHT)
	_poly(image, [18,13, 19,14, 18,40, 17,42, 17,14], STEEL_DARK)
	_line(image, Vector2i(16,14), Vector2i(16,38), CLOTH_LIGHT)
	_line(image, Vector2i(14,26), Vector2i(15,27), STEEL_DARK)
	_line(image, Vector2i(15,27), Vector2i(14,29), STEEL_DARK)
	_poly(image, [7,42, 11,43, 16,44, 22,42, 25,43, 25,46, 20,48, 17,48, 17,58, 20,60, 18,63, 13,63, 11,60, 14,58, 13,48, 9,47, 7,46], INK)
	_poly(image, [8,43, 12,45, 17,45, 22,43, 24,44, 23,46, 18,47, 13,47, 9,46], COPPER)
	_line(image, Vector2i(9,44), Vector2i(12,45), GOLD_LIGHT)
	_line(image, Vector2i(17,45), Vector2i(22,44), GOLD_LIGHT)
	_rect(image, Rect2i(14,48,3,10), LEATHER_DARK)
	_rect(image, Rect2i(14,48,2,9), LEATHER)
	for y in [49,52,55]:
		_line(image, Vector2i(14,y), Vector2i(16,y+1), LEATHER_LIGHT)
	_poly(image, [15,58, 18,60, 17,62, 14,62, 12,60], COPPER)
	_pixel(image, 14,59, GOLD_LIGHT)


static func _sword_icon(image: Image) -> void:
	_poly(image, [28,2, 28,8, 15,21, 11,18, 24,4], INK)
	_poly(image, [27,4, 26,8, 15,19, 13,18, 25,5], STEEL)
	_line(image, Vector2i(25,5), Vector2i(14,17), STEEL_LIGHT)
	_line(image, Vector2i(25,8), Vector2i(15,18), STEEL_DARK)
	_poly(image, [7,16, 11,17, 16,22, 16,25, 13,25, 11,22, 6,27, 7,29, 4,31, 1,28, 3,25, 5,26, 10,21, 7,20], INK)
	_poly(image, [8,17, 11,18, 15,22, 15,24, 13,23, 9,19, 8,19], COPPER)
	_pixel(image, 9,18, GOLD_LIGHT)
	_line(image, Vector2i(10,22), Vector2i(5,27), LEATHER)
	_line(image, Vector2i(9,22), Vector2i(4,27), LEATHER_LIGHT)
	_poly(image, [3,26, 6,29, 4,30, 2,28], COPPER)
	_pixel(image, 3,27, GOLD_LIGHT)


static func _shield(image: Image) -> void:
	var center := Vector2i(32,32)
	_ellipse(image, center, Vector2i(27,27), INK)
	_ellipse(image, center, Vector2i(26,26), STEEL_DARK)
	_ellipse(image, center+Vector2i(-1,-1), Vector2i(24,24), COPPER)
	_ellipse(image, center, Vector2i(22,22), INK)
	_ellipse(image, center, Vector2i(21,21), LEATHER)
	# Wood planks are clipped to the disk, with sparse grain instead of noise.
	for y in range(12,53):
		for x in range(12,53):
			if Vector2(float(x-32)/20.5,float(y-32)/20.5).length_squared() <= 1.0:
				var color := LEATHER_LIGHT if x < 26 else LEATHER
				if x > 42:
					color = LEATHER_DARK
				if x in [19,28,37,46]:
					color = LEATHER_DARK
				_pixel(image,x,y,color)
	_line(image,Vector2i(16,25),Vector2i(16,35),LEATHER)
	_line(image,Vector2i(23,15),Vector2i(23,24),COPPER)
	_line(image,Vector2i(41,38),Vector2i(41,46),LEATHER_LIGHT)
	_line(image,Vector2i(24,41),Vector2i(24,48),LEATHER)
	# A deep green painted band and an ivory oak-leaf crest.
	_poly(image,[29,12, 35,12, 37,17, 36,47, 33,52, 29,49, 27,43, 28,18],GREEN_DARK)
	_poly(image,[30,14, 33,14, 34,21, 33,47, 31,48, 29,43, 30,25],GREEN)
	_poly(image,[32,19, 35,23, 34,27, 39,26, 38,31, 35,34, 36,37, 33,39, 32,44, 30,40, 26,38, 28,35, 24,31, 25,27, 30,29, 29,24],CLOTH)
	_line(image,Vector2i(32,24),Vector2i(31,42),CLOTH_LIGHT)
	_line(image,Vector2i(27,29),Vector2i(31,33),CLOTH_LIGHT)
	_line(image,Vector2i(35,29),Vector2i(32,34),CLOTH_LIGHT)
	# Eight small inset rivets and a broken upper-left rim highlight.
	for point in [Vector2i(32,8),Vector2i(49,15),Vector2i(56,32),Vector2i(49,49),Vector2i(32,56),Vector2i(15,49),Vector2i(8,32),Vector2i(15,15)]:
		_rect(image,Rect2i(point-Vector2i.ONE,Vector2i(3,3)),INK)
		_pixel(image,point.x,point.y,COPPER)
		_pixel(image,point.x-1,point.y-1,GOLD_LIGHT)
	_line(image,Vector2i(20,10),Vector2i(26,8),GOLD_LIGHT)
	_line(image,Vector2i(10,21),Vector2i(12,17),GOLD_LIGHT)


static func _stone(image: Image) -> void:
	_poly(image,[7,7, 21,4, 28,12, 25,25, 11,29, 4,20],INK)
	_poly(image,[8,8, 21,6, 26,12, 13,16, 6,19],STEEL)
	_poly(image,[6,20, 13,17, 25,14, 23,24, 12,27],STEEL_DARK)
	_poly(image,[8,9, 20,7, 23,10, 12,13, 7,16],Color("bdc9c1"))
	_poly(image,[13,17, 17,16, 16,25, 12,26],Color("74858e"))
	_line(image,Vector2i(7,19),Vector2i(12,16),STEEL_LIGHT)
	_line(image,Vector2i(14,15),Vector2i(24,12),STEEL_LIGHT)
	_line(image,Vector2i(10,11),Vector2i(18,9),STEEL_DARK)
	_line(image,Vector2i(12,12),Vector2i(20,10),STEEL_DARK)
	_line(image,Vector2i(20,18),Vector2i(18,23),STEEL_LIGHT)
	_pixel(image,20,19,STEEL_LIGHT)
	_pixel(image,18,22,STEEL_LIGHT)
	_pixel(image,10,23,STEEL_DARK)


static func _blank(width: int, height: int) -> Image:
	var image := Image.create(width,height,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	return image


static func _pixel(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x,y,color)


static func _rect(image: Image, rect: Rect2i, color: Color) -> void:
	var clipped := rect.intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	if clipped.size.x > 0 and clipped.size.y > 0:
		image.fill_rect(clipped,color)


static func _line(image: Image, start: Vector2i, finish: Vector2i, color: Color) -> void:
	var point := start
	var dx := absi(finish.x-start.x)
	var dy := -absi(finish.y-start.y)
	var sx := 1 if start.x < finish.x else -1
	var sy := 1 if start.y < finish.y else -1
	var error := dx+dy
	while true:
		_pixel(image,point.x,point.y,color)
		if point == finish:
			break
		var twice := error*2
		if twice >= dy:
			error += dy
			point.x += sx
		if twice <= dx:
			error += dx
			point.y += sy


static func _poly(image: Image, coordinates: Array, color: Color, offset: Vector2i = Vector2i.ZERO) -> void:
	var points := PackedVector2Array()
	for index in range(0,coordinates.size(),2):
		points.append(Vector2(coordinates[index]+offset.x,coordinates[index+1]+offset.y))
	var bounds := Rect2(points[0],Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	for y in range(maxi(0,int(bounds.position.y)),mini(image.get_height(),int(bounds.end.y)+1)):
		for x in range(maxi(0,int(bounds.position.x)),mini(image.get_width(),int(bounds.end.x)+1)):
			if Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),points):
				image.set_pixel(x,y,color)


static func _ellipse(image: Image, center: Vector2i, radius: Vector2i, color: Color) -> void:
	for y in range(center.y-radius.y,center.y+radius.y+1):
		for x in range(center.x-radius.x,center.x+radius.x+1):
			var delta := Vector2(float(x-center.x)/maxi(1,radius.x),float(y-center.y)/maxi(1,radius.y))
			if delta.length_squared() <= 1.0:
				_pixel(image,x,y,color)
