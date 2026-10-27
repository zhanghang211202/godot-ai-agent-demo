extends RefCounted
## Presentation only. Event timestamps, damage, cooldowns and saves stay in ClassBattle.

const ROOT := "res://assets/art/c1-motion-v1/characters/"
const FILES := {"mage-cast": "mage-cast.png", "knight-sword": "knight-sword.png", "knight-greatblade": "knight-greatblade.png"}
# Measured boot-midpoint x anchors in original PNG coordinates. Y is the last
# alpha>=128 row of each frame. A common scale is used throughout each clip.
const FOOT_X := {"mage-cast": [307, 879, 340, 880], "knight-sword": [260, 923, 246, 903], "knight-greatblade": [249, 924, 250, 842]}
const MAGE_CAST_POINTS := [Vector2(452, 135), Vector2(1026, 155), Vector2(508, 810), Vector2(1028, 812)]
static var _assets: Dictionary = {}
var clip := ""
var state := "idle"
var elapsed := 0.0
var source_uid := -1
var last_activation := ""

static func clip_for_kind(kind: String) -> String:
	if kind in ["spark", "flame_glyph", "tide_lances", "frost_bolt", "gale_blades", "steam_burst", "ember_tornado"]:
		return "mage-cast"
	if kind == "iron_blade":
		return "knight-sword"
	if kind == "greatblade":
		return "knight-greatblade"
	return ""

func reset() -> void:
	clip = ""
	state = "idle"
	elapsed = 0.0
	source_uid = -1
	last_activation = ""

func prepare_mage_cast(uid: int) -> void:
	# Visual cue from the read-only upcoming activation, not a combat charge.
	# Never interrupt an actual impact/recovery to play another source's cue.
	if state != "idle":
		return
	clip = "mage-cast"
	state = "windup"
	elapsed = 0.0
	source_uid = uid

func show_event(event: Dictionary) -> void:
	var type := str(event.get("type", ""))
	if type not in ["charge", "spell", "spell_burst", "spell_multi", "attack", "heavy_charge"]:
		return
	var candidate := clip_for_kind(str(event.get("source_kind", "")))
	if candidate.is_empty():
		return
	var uid := int(event.get("source_uid", -1))
	if type == "charge":
		# One actor represents multiple automatic sources. Never erase an impact
		# with another source's simultaneous anticipation event.
		if state == "impact" or state == "recover":
			return
		clip = candidate
		state = "windup"
		elapsed = 0.0
		source_uid = uid
		return
	var activation := "%d@%s" % [uid, str(event.get("time", 0))]
	if activation == last_activation:
		return # Multiple damage segments at one activation share one action.
	last_activation = activation
	clip = candidate
	state = "impact"
	elapsed = 0.0
	source_uid = uid

func advance(delta: float) -> void:
	if state == "idle" or state == "windup":
		return
	elapsed += maxf(0.0, delta)
	if elapsed >= 0.42:
		state = "idle"
		clip = ""
		source_uid = -1
	elif elapsed >= 0.16:
		state = "recover"

func frame_index() -> int:
	return {"idle": 0, "windup": 1, "impact": 2, "recover": 3}[state]

func finish_battle() -> void:
	# A winning blow may finish its follow-through; a cancelled charge must not
	# leave the actor raising a sword forever in the result screen.
	if state == "windup":
		reset()

static func get_asset(id: String) -> Dictionary:
	if _assets.has(id):
		return _assets[id]
	if not FILES.has(id):
		return {}
	var path := ROOT + str(FILES[id])
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return {}
	image.convert(Image.FORMAT_RGBA8)
	var dimensions := image.get_size()
	var half := dimensions / 2
	var regions: Array[Rect2i] = [Rect2i(Vector2i.ZERO, half), Rect2i(Vector2i(half.x, 0), half), Rect2i(Vector2i(0, half.y), half), Rect2i(half, half)]
	# This dedicated attack sheet is not perfectly equal-cell aligned. The lower
	# greatblade tip extends 14px past the midpoint into otherwise empty gutter.
	# Use separate nonoverlapping source regions; never crop that weapon tip.
	if id == "knight-greatblade":
		regions[2].size.x = 582
		regions[3].position.x = 582
		regions[3].size.x = dimensions.x - 582
	var frames: Array[Dictionary] = []
	var above := 0.0
	var left := 0.0
	var right := 0.0
	for index in range(4):
		var bounds := _bounds(image, regions[index])
		var pivot := Vector2(float(FOOT_X[id][index]), bounds.end.y)
		above = maxf(above, pivot.y - bounds.position.y)
		left = maxf(left, pivot.x - bounds.position.x)
		right = maxf(right, bounds.end.x - pivot.x)
		frames.append({"source_rect": Rect2(bounds), "region": Rect2(regions[index]), "pivot": pivot,
			"cast_point": MAGE_CAST_POINTS[index] if id == "mage-cast" else pivot})
	var result := {"id": id, "path": path, "texture": ImageTexture.create_from_image(image), "size": dimensions,
		"frames": frames, "height": above, "left": left, "right": right}
	_assets[id] = result
	return result

static func _bounds(image: Image, region: Rect2i) -> Rect2i:
	var data := image.get_data()
	var minimum := region.end
	var maximum := Vector2i(-1, -1)
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if data[(y * image.get_width() + x) * 4 + 3] < 128:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE) if maximum.x >= 0 else Rect2i()
