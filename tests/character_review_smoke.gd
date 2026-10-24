extends SceneTree
## Real native Control/input checks for the concept fixture, not RV-03 combat acceptance.

const SCENE := "res://scenes/character_review.tscn"
const REVIEW = preload("res://scripts/art_review/character_review.gd")
const PLAYER_PATHS := ["user://class-prototype-run.json", "user://emberpack-run.json"]
var checks := 0
var failures := 0
var ui: Control
var fingerprints := {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for path in PLAYER_PATHS:
		fingerprints[path] = _fingerprint(path)
	root.size = Vector2i(1440, 960)
	var scene: PackedScene = load(SCENE)
	if scene == null:
		push_error("Character concept study scene could not be loaded")
		quit(1)
		return
	ui = scene.instantiate()
	root.add_child(ui)
	await _settle()
	check(ui.failures.is_empty(), "All six raw concept PNGs loaded without importer dependency")
	check(ui.textures.size() == 6 and ui.bounds.size() == 6, "Six distinct review entries have textures and nonempty bounds")
	_test_sources()
	check(ui.selections == [0, 3], "Review defaults to the selected appearance baselines: mage A and knight A")
	await _test_input()
	await _test_layout()
	for path in PLAYER_PATHS:
		check(_fingerprint(path) == fingerprints[path], "Review never changes player checkpoint: " + path)
	check(ui._capture_directory.is_empty() and not ui._capture_done, "Normal review does not automatically save screenshots")
	print("Character concept study smoke: %d checks, %d failures" % [checks, failures])
	ui.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _settle() -> void:
	for frame in range(4):
		await process_frame

func _fingerprint(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func _test_sources() -> void:
	for entry in REVIEW.ENTRIES:
		var path: String = REVIEW.ART_ROOT + entry.file
		if not FileAccess.file_exists(path):
			check(false, entry.id + " source PNG exists")
			continue
		var image := Image.load_from_file(path)
		check(image != null and not image.is_empty(), entry.id + " is a decodable PNG")
		if image == null or image.is_empty():
			continue
		check(image.get_width() >= 512 and image.get_height() >= 768, entry.id + " is a large concept illustration, not a tiny runtime sprite")
		check(image.detect_alpha() != Image.ALPHA_NONE, entry.id + " contains actual transparency")
		var rect := image.get_used_rect()
		check(rect.has_area() and Rect2i(Vector2i.ZERO, image.get_size()).encloses(rect), entry.id + " nontransparent bounds stay inside PNG")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release: InputEventKey = event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func _click(button: Button) -> void:
	var point := root.get_screen_transform() * button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release: InputEventMouseButton = event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func _test_input() -> void:
	await _key(KEY_RIGHT)
	check(ui.selections == [1, 3] and ui.selectors[0].selected == 1, "Native right key changes only the viewed left entry to mage B")
	await _key(KEY_RIGHT)
	check(ui.selections == [2, 3], "Native right key reaches mage C")
	await _key(KEY_TAB)
	await _key(KEY_LEFT)
	check(ui.active_column == 1 and ui.selections == [2, 2], "Tab changes active column and left key changes only that viewed entry")
	await _click(ui.filter_button)
	check(not ui.nearest, "Native sampling button toggles linear filtering")
	await _key(KEY_N)
	check(ui.nearest, "Native N key restores nearest sampling")
	await _click(ui.background_button)
	check(ui.light_background, "Native background button switches to light ground")
	await _key(KEY_B)
	check(not ui.light_background, "Native B key restores dark ground")
	for index in range(REVIEW.ENTRIES.size()):
		ui.select_entry(0, index)
		await _settle()
		check(ui.selectors[0].selected == index, "Selector reaches " + REVIEW.ENTRIES[index].id)
		var id: String = REVIEW.ENTRIES[index].id
		if ui.bounds.has(id):
			check(ui.full_views[0].source_rect == ui.bounds[id], id + " full view uses visible source bounds")
			var texture: Texture2D = ui.textures[id]
			check(ui.head_views[0].source_rect == REVIEW.ENTRIES[index].face_rect, id + " face view uses its explicitly reviewed source region")
			check(Rect2(Vector2.ZERO, texture.get_size()).encloses(ui.head_views[0].source_rect), id + " face region stays within the original PNG; no sprite slicing")
	ui.select_entry(0, 0)
	ui.select_entry(1, 3)

func _test_layout() -> void:
	for resolution in [Vector2i(1280, 800), Vector2i(1440, 960), Vector2i(1920, 1080)]:
		root.size = resolution
		await _settle()
		var viewport := Rect2(Vector2.ZERO, Vector2(resolution))
		for column in range(2):
			check(viewport.encloses(ui.cards[column].get_global_rect()), "%s column %d card stays inside native viewport" % [resolution, column])
			check(viewport.encloses(ui.selectors[column].get_global_rect()), "%s column %d selector is visible" % [resolution, column])
			for index in range(REVIEW.SCALE_HEIGHTS.size()):
				var view = ui.scale_views[column][index]
				check(viewport.encloses(view.get_global_rect()), "%s column %d scale %d remains visible" % [resolution, column, index])
				if not view.source_rect.has_area():
					continue
				var destination: Rect2 = view.destination_rect()
				check(is_equal_approx(destination.size.y, REVIEW.SCALE_HEIGHTS[index]), "%s column %d scale %d has exact static occupied height" % [resolution, column, index])
				check(is_equal_approx(destination.size.x / destination.size.y, view.source_rect.size.x / view.source_rect.size.y), "%s column %d scale %d preserves aspect ratio" % [resolution, column, index])
				check(Rect2(Vector2.ZERO, view.size).encloses(destination), "%s column %d scale %d never clips its source bounds" % [resolution, column, index])
		check(viewport.encloses(ui.status_label.get_global_rect()), "%s limitation footer remains visible" % resolution)
