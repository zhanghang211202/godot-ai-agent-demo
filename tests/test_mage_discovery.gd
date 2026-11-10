extends SceneTree
## Actual native input and GPU screenshots for the recipe book and grid hints.

const Run = preload("res://scripts/classes/class_run.gd")
const Catalog = preload("res://scripts/classes/class_catalog.gd")
const Guide = preload("res://scripts/classes/mage_recipe_guide.gd")
const PLAYER_PATHS := ["user://mage-trial-run.json", "user://class-prototype-run.json", "user://emberpack-run.json"]
const OUTPUT := "res://.tools/mage-discovery-review"
var checks := 0
var failures := 0
var ui: Control
var layouts: Array[Dictionary] = []
var captures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _state(run: RefCounted) -> Dictionary:
	return {"items": run.items.duplicate(true), "sources": run.sources.duplicate(true), "uid": run._next_uid, "discarded": run.discarded_materials.duplicate(true), "gold": run.gold, "phase": run.phase}

func _fingerprint(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func _model() -> void:
	var run := Run.new()
	run.new_run("mage")
	var recipes: Array[Dictionary] = Catalog.recipes_for("mage")
	var before := _state(run)
	for recipe in recipes:
		if recipe.result in ["solar_lance", "frost_orbit", "crowned_familiar", "wind_familiar"]:
			check(not Guide.availability(run, recipe).available, str(recipe.result) + " requires its base spell to be woven first")
		else:
			check(Guide.availability(run, recipe).available, str(recipe.result) + " ingredients are counted from actual board and finite source")
	var choice := Guide.choose(run, recipes[2])
	check(choice.ok and choice.held.origin == "source" and choice.held.index == 1 and choice.target_uid == 1 and choice.preview.ok, "Ice arrow selects water and an existing spark without spending")
	var hints := Guide.target_hints(run, choice.held)
	check(hints.size() == 3 and hints[1].ok and hints[2].ok and hints[1].product == "frost_bolt" and hints[3].ok and hints[3].product == "moon_familiar", "Water highlights both starter spells and the compatible familiar contract")
	check(_state(run) == before, "Opening guide and evaluating all target previews preserve every material and UID")
	choice = Guide.choose(run, recipes[4])
	check(choice.ok and choice.needs_placement and choice.first_kind == "fire_mote" and choice.next_kind == "water_mote", "Two source-only ingredients are explained as two normal steps")
	run.new_run("mage")
	check(run.acquire(0, Vector2i(3, 2)).ok and run.acquire(1, Vector2i(4, 2)).ok, "Both steam ingredients can first be placed normally")
	before = _state(run)
	choice = Guide.choose(run, recipes[4])
	check(choice.ok and choice.held.origin == "bag" and choice.preview.ok, "Guide prefers owned ingredients even when source stock remains")
	check(_state(run) == before, "Owned-ingredient selection is read-only")
	var target: Dictionary = run.item_by_uid(choice.target_uid)
	check(run.move(choice.held.uid, target.pos, choice.held.rotated).ok and run.get_combat_config() == choice.preview.combat, "Guided owned merge agrees with the actual transaction, including consumed footprint")
	run.new_run("mage")
	check(run.acquire(0, Vector2i(3, 2)).ok, "Rotation fixture places the first vortex ingredient")
	before = _state(run)
	choice = Guide.choose(run, recipes[5])
	check(choice.ok and choice.get("auto_rotated", false) and choice.held.rotated and choice.preview.size == Vector2i(3, 2), "Guide chooses a rotated product when only that footprint fits")
	check(_state(run) == before and Guide.target_hints(run, choice.held)[choice.target_uid].ok, "Rotated guidance and highlight do not alter the board")
	run.new_run("mage")
	check(run.acquire(0, Vector2i(5, 3)).ok, "Blocked fixture uses a legal single-cell material")
	before = _state(run)
	choice = Guide.choose(run, recipes[4])
	check(choice.ok and not choice.preview.ok and not Guide.target_hints(run, choice.held)[choice.target_uid].ok and _state(run) == before, "Impossible product is marked blocked and consumes nothing")
	run.new_run("mage")
	check(run.discard(1).ok and run.discard(2).ok, "Unavailable fixture removes both starter spells normally")
	var available := Guide.availability(run, recipes[2])
	check(not available.available and available.missing == ["spark"] and not Guide.choose(run, recipes[2]).ok, "Missing ingredients cannot be invented by the guide")
	run.phase = "battle"
	check(Guide.target_hints(run, {"origin": "source", "index": 0}).is_empty() and not Guide.choose(run, recipes[4]).ok, "Guidance respects the locked battle phase")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var fingerprints := {}
	for path in PLAYER_PATHS:
		fingerprints[path] = _fingerprint(path)
	_model()
	root.size = Vector2i(1440, 960)
	ui = load("res://scenes/mage_trial.tscn").instantiate()
	ui.persistence_enabled = false
	root.add_child(ui)
	await process_frame
	await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	var original := _state(ui.run)
	await _click(ui.recipe_button.get_global_rect().get_center())
	check(ui.recipe_overlay.visible and ui.recipe_cards.size() == 16, "Real button opens sixteen actual recipe cards")
	for dimensions in [Vector2i(1280, 800), Vector2i(1440, 960), Vector2i(1920, 1080)]:
		root.size = dimensions
		for _frame in range(4): await process_frame
		var viewport := Rect2(Vector2.ZERO, Vector2(dimensions))
		var rects: Array = []
		check(viewport.encloses(ui.recipe_scroll.get_global_rect()), str(dimensions) + " recipe scroll area remains within the window")
		for card: Button in ui.recipe_cards:
			ui.recipe_scroll.ensure_control_visible(card)
			for _frame in range(2): await process_frame
			var rect := card.get_global_rect()
			check(ui.recipe_scroll.get_global_rect().encloses(rect) and rect.has_area(), str(dimensions) + " recipe card is reachable within the scroll area")
			var local_rect := card.get_rect()
			for previous: Rect2 in rects:
				check(not local_rect.intersects(previous), str(dimensions) + " recipe cards do not overlap")
			rects.append(local_rect)
		layouts.append({"viewport": [dimensions.x, dimensions.y], "cards": rects.map(func(rect: Rect2): return [rect.position.x, rect.position.y, rect.size.x, rect.size.y])})
	root.size = Vector2i(1440, 960)
	for _frame in range(4): await process_frame
	ui.recipe_scroll.ensure_control_visible(ui.recipe_cards[2])
	for _frame in range(2): await process_frame
	await _capture("recipe-book")
	await _click(ui.recipe_cards[2].get_global_rect().get_center())
	check(not ui.recipe_overlay.visible and ui.held.origin == "source" and ui.held.index == 1 and _state(ui.run) == original, "Native ice card click selects water without consuming it")
	check(ui.grid.recipe_hints.size() == 2 and ui.grid.recipe_hints[1].ok and ui.grid.recipe_hints[2].ok and not ui.grid.recipe_hints.has(3), "Ice recipe highlights only the two ingredients that make ice, not the familiar contract")
	await _capture("recipe-targets")
	await _move(_cell(Vector2i.ZERO))
	check(ui.preview_label.visible and ui.preview_label.text.contains("霜晶の氷矢") and _state(ui.run) == original, "Hover shows the real ice output and remains non-destructive")
	await _capture("recipe-preview")
	await _click(_cell(Vector2i.ZERO))
	check(ui.run.item_by_uid(1).kind == "frost_bolt" and ui.run.sources[1].remaining == 1 and ui.held.is_empty(), "Native target click commits the actual one-element merge")
	check(ui.grid.merge_uid == 1 and ui.grid.merge_remaining > 0 and ui.grid.recipe_hints.is_empty(), "Successful merge flashes the product and clears target hints")
	await _capture("merge-feedback")
	ui.grid._process(1)
	check(ui.grid.merge_remaining == 0 and ui.run.item_by_uid(1).kind == "frost_bolt", "Merge flash expires without changing the resulting item")
	ui._new_class("mage")
	check(ui.run.discard(1).ok and ui.run.discard(2).ok, "Missing-material native fixture uses ordinary discards")
	ui._sync()
	await _click(ui.recipe_button.get_global_rect().get_center())
	check(ui.recipe_cards[2].disabled and ui.recipe_cards[2].text.contains("不足") and not ui.recipe_cards[4].disabled, "Book distinguishes a missing spark from an available fire/water recipe")
	var before := _state(ui.run)
	await _key(KEY_SPACE)
	check(ui.run.phase == "prepare" and _state(ui.run) == before, "Space in the book does not start battle or spend ingredients")
	if not ui.recipe_overlay.visible:
		await _click(ui.recipe_button.get_global_rect().get_center())
	await _key(KEY_ESCAPE)
	check(not ui.recipe_overlay.visible and _state(ui.run) == before, "Escape closes the book without altering the build")
	ui._new_class("mage")
	check(ui.run.acquire(0, Vector2i(3, 1)).ok and ui.run.acquire(1, Vector2i(4, 1)).ok, "Drag fixture uses two separately acquired materials")
	ui._sync()
	var stock: Array = ui.run.sources.duplicate(true)
	await _drag(_cell(Vector2i(3, 1)), _cell(Vector2i(4, 1)))
	check(ui.run.item_at(Vector2i(4, 1)).get("kind") == "steam_burst" and ui.run.sources == stock, "Real board drag merges owned fire and water without spending extra stock")
	check(ui.grid.merge_remaining > 0 and ui.held.is_empty(), "Drag merge receives the same product feedback and clears drag state")
	await _capture("owned-drag-merge")
	ui._start_battle()
	check(ui.recipe_button.disabled and not ui.recipe_overlay.visible and ui.grid.merge_remaining == 0, "Battle locks the book and clears preparation feedback")
	ui._open_recipe_book()
	check(not ui.recipe_overlay.visible, "Book cannot be opened programmatically during battle")
	for path in PLAYER_PATHS:
		check(_fingerprint(path) == fingerprints[path], "Discovery fixture leaves player file untouched: " + path)
	var report := FileAccess.open(OUTPUT.path_join("test-report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "renderer": RenderingServer.get_video_adapter_name(), "layouts": layouts, "captures": captures}, "\t"))
	report.close()
	print("Mage discovery: %d checks, %d failures" % [checks, failures])
	ui.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _cell(cell: Vector2i) -> Vector2:
	return ui.grid.get_global_rect().position + ui.grid.cell_rect(cell).get_center()

func _move(position: Vector2, mask: int = 0, relative: Vector2 = Vector2.ZERO) -> void:
	# Godot's native drag-and-drop queries the OS cursor separately from parsed
	# events. Keep them in sync when exercising the real GUI input path.
	Input.warp_mouse(root.get_screen_transform() * position)
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_screen_transform() * position
	motion.global_position = motion.position
	motion.relative = relative
	motion.button_mask = mask
	Input.parse_input_event(motion)
	await process_frame

func _click(position: Vector2) -> void:
	await _move(position)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = root.get_screen_transform() * position
	press.global_position = press.position
	Input.parse_input_event(press)
	await process_frame
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

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

func _drag(from: Vector2, to: Vector2) -> void:
	await _move(from)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = root.get_screen_transform() * from
	press.global_position = press.position
	Input.parse_input_event(press)
	await process_frame
	await _move(from + Vector2(12, 0), MOUSE_BUTTON_MASK_LEFT, Vector2(12, 0))
	await _move(to, MOUSE_BUTTON_MASK_LEFT, to - from)
	var release: InputEventMouseButton = press.duplicate()
	release.position = root.get_screen_transform() * to
	release.global_position = release.position
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
	await process_frame

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUTPUT.path_join(name + ".png"))
	check(result == OK, name + " native screenshot saved")
	captures.append(name + ".png")
