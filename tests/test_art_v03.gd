extends SceneTree
## Contract checks for the M1 source-art sample, independent of game balance.

const Art = preload("res://scripts/visuals/pixel_art_v03.gd")
const Legacy = preload("res://scripts/visuals/pixel_art.gd")
const Run = preload("res://scripts/gameplay/run_state.gd")
const OUTPUT := "res://assets/art/v03"
var checks := 0
var failures := 0


func _initialize() -> void:
	_test_clip_timing()
	_test_characters()
	_test_inventory()
	_test_manifest()
	print("EmberArtV03: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)


func _test_clip_timing() -> void:
	for clip in Art.CLIPS:
		var definition: Dictionary = Art.CLIPS[clip]
		var count := int(definition["frames"])
		var step := float(definition["seconds"])
		check(Art.frame_index(clip, -10.0) == 0, "%s negative time clamps" % clip)
		for index in range(count):
			check(Art.frame_index(clip, step * (index + 0.5)) == index, "%s frame %d midpoint" % [clip, index])
		var expected := 0 if definition["loop"] else count - 1
		check(Art.frame_index(clip, step * (count + 0.5)) == expected, "%s loop/end contract" % clip)
		if not definition["loop"]:
			check(Art.frame_index(clip, 1000.0) == count - 1, "%s holds final frame" % clip)
	check(Art.frame_index("missing", 0.23) == Art.frame_index("idle", 0.23), "Unknown clip falls back to idle timing")


func _test_characters() -> void:
	for kind in ["hero", "slime"]:
		check(Art.character_pivot(kind) == Vector2(32, 58), "%s feet pivot" % kind)
		var count := 0
		for clip in Art.CLIPS:
			var hashes := {}
			for frame in range(int(Art.CLIPS[clip]["frames"])):
				count += 1
				var image: Image = Art.character_frame(kind, clip, frame)
				var bounds := image.get_used_rect()
				hashes[image.get_data().hex_encode().sha256_text()] = true
				check(image.get_size() == Vector2i(64, 64), "%s/%s/%d source canvas" % [kind, clip, frame])
				check(bounds.size.x >= 25 and bounds.size.y >= 8, "%s/%s/%d has visible artwork" % [kind, clip, frame])
				check(bounds.position.x > 0 and bounds.end.x < 64 and bounds.position.y > 0 and bounds.end.y < 64, "%s/%s/%d remains inside transparent margins" % [kind, clip, frame])
				check(bounds.end.y >= 58 and bounds.end.y <= 59, "%s/%s/%d remains on contact baseline" % [kind, clip, frame])
				check(_binary_alpha(image), "%s/%s/%d uses solid source pixels" % [kind, clip, frame])
				var midpoint := float(Art.CLIPS[clip]["seconds"]) * (frame + 0.5)
				var texture: Texture2D = Art.character(kind, clip, midpoint)
				check(texture.get_image().get_data() == image.get_data(), "%s/%s/%d runtime frame matches authored pixels" % [kind, clip, frame])
				check(texture == Art.character(kind, clip, midpoint), "%s/%s/%d reuses cached texture" % [kind, clip, frame])
			check(hashes.size() == int(Art.CLIPS[clip]["frames"]), "%s/%s contains distinct frames" % [kind, clip])
			check(Art.character_frame(kind, clip, -1).get_data() == Art.character_frame(kind, clip, 0).get_data(), "%s/%s clamps negative frame" % [kind, clip])
			check(Art.character_frame(kind, clip, 999).get_data() == Art.character_frame(kind, clip, int(Art.CLIPS[clip]["frames"]) - 1).get_data(), "%s/%s clamps high frame" % [kind, clip])
		check(count == 14, "%s has 4 idle + 4 attack + 2 hurt + 4 defeat frames" % kind)
		check(Art.character(kind, "missing", 0.0) == Art.character(kind, "idle", 0.0), "%s unknown clip shares idle texture cache" % kind)
	for kind in ["wolf", "goblin", "boss", "tree"]:
		check(Art.character_pivot(kind) == Vector2(48, 88), "%s placeholder pivot" % kind)
		check(Art.character(kind).get_size() == Vector2(96, 96), "%s keeps legacy canvas without stretch" % kind)
	check(Art.character("tree") == Legacy.character("boss"), "Tree placeholder aliases the actual legacy boss")


func _test_inventory() -> void:
	check(Art.FOOTPRINTS.size() == 12, "M1 preserves 12 item content budget")
	for kind in Art.FOOTPRINTS:
		var footprint: Vector2i = Art.FOOTPRINTS[kind]
		var image: Image = Art.inventory_image(kind)
		check(footprint == Run.DEFINITIONS[kind]["size"], "%s art footprint agrees with gameplay" % kind)
		check(image.get_size() == footprint * 32, "%s canvas follows footprint" % kind)
		check(image.get_used_rect().has_area(), "%s silhouette is visible" % kind)
		check(_binary_alpha(image), "%s source has no antialiasing" % kind)
		var texture: Texture2D = Art.inventory(kind)
		check(texture == Art.inventory(kind), "%s inventory texture is cached" % kind)
		check(texture.get_image().get_data() == image.get_data(), "%s runtime inventory equals source pixels" % kind)
		check(Art.icon(kind).get_size() == Vector2(32, 32), "%s independent 32px thumbnail" % kind)
		check(Art.icon(kind) == Art.icon(kind), "%s thumbnail texture is cached" % kind)
		# A complete image rotation has an exact pixel mapping, including alpha.
		# The UI draws this same whole-image transform rather than fitting a
		# square icon into a swapped rectangle.
		var rotated := image.duplicate() as Image
		rotated.rotate_90(CLOCKWISE)
		check(rotated.get_size() == Vector2i(image.get_height(), image.get_width()), "%s 90 degree canvas swaps axes" % kind)
		var mismatch := false
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x, y) != rotated.get_pixel(image.get_height() - 1 - y, x):
					mismatch = true
		check(not mismatch, "%s rotation has zero changed pixels" % kind)
		for turn in range(3):
			rotated.rotate_90(CLOCKWISE)
		check(rotated.get_data() == image.get_data(), "%s four full rotations restore every pixel" % kind)
		if kind not in ["sword", "shield", "whetstone"]:
			var original: Image = Legacy.icon(kind).get_image()
			var offset := (image.get_size() - original.get_size()) / 2
			var crop := image.get_region(Rect2i(offset, original.get_size()))
			check(crop.get_data() == original.get_data(), "%s placeholder centers unchanged legacy thumbnail" % kind)
	check(Art.inventory_image("sword").get_used_rect().size.y > 48, "Sword has a dedicated tall silhouette")
	check(Art.inventory_image("shield").get_used_rect().size.x > 48, "Shield has a dedicated broad silhouette")
	check(Art.inventory_image("unknown").get_size() == Vector2i(32, 32), "Unknown inventory id falls back safely")


func _test_manifest() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT + "/manifest.json"))
	check(parsed is Dictionary, "Asset manifest parses")
	if parsed is not Dictionary:
		return
	check(parsed["assets"].size() == 9, "Manifest has 2 sheets, 6 item assets and the forest stage")
	check(parsed["fallbacks"].size() == 13, "Manifest labels 9 inventory and 4 character placeholders")
	for entry in parsed["assets"]:
		var path := str(entry["path"])
		check(FileAccess.file_exists(path), "%s exported file exists" % entry["id"])
		check(FileAccess.get_sha256(path) == entry["sha256"], "%s exported hash matches manifest" % entry["id"])
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		check(image != null and image.get_size() == Vector2i(int(entry["source_size"][0]), int(entry["source_size"][1])), "%s exported size matches manifest" % entry["id"])
		if entry["kind"] == "character_sheet":
			var kind := str(entry["id"]).trim_prefix("character.")
			for row in range(4):
				var clip: String = ["idle", "attack", "hurt", "defeat"][row]
				for frame in range(int(Art.CLIPS[clip]["frames"])):
					var crop := image.get_region(Rect2i(frame * 64, row * 64, 64, 64))
					check(crop.get_data() == Art.character_frame(kind, clip, frame).get_data(), "%s/%s/%d sheet matches runtime source" % [kind, clip, frame])
	var contact := Image.load_from_file(ProjectSettings.globalize_path(OUTPUT + "/previews/animation_contact.png"))
	check(contact.get_size() == Vector2i(768, 1536), "Review contact sheet uses integer 3x source pixels")


func _binary_alpha(image: Image) -> bool:
	var data := image.get_data()
	for index in range(3, data.size(), 4):
		if data[index] != 0 and data[index] != 255:
			return false
	return true
