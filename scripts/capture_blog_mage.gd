extends SceneTree
## Capture a real seven-stage campaign with saves disabled; no game state is faked.
const OUTPUT := "res://.tools/blog-mage-current"

func _initialize() -> void:
	_run.call_deferred()

func _drop(ui: Control, index: int, cell: Vector2i) -> bool:
	var before: int = ui.run.sources[index].remaining
	ui._on_drop({"origin": "source", "index": index}, cell)
	return int(ui.run.sources[index].remaining) == before - 1

func _capture(path: String) -> bool:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().save_png(path) == OK

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	root.size = Vector2i(1440, 960)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.path_join("boss-frames")))
	var ui = load("res://scenes/mage_campaign.tscn").instantiate()
	ui.persistence_enabled = false
	root.add_child(ui)
	for _i in range(4): await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	if not (_drop(ui, 0, Vector2i.ZERO) and _drop(ui, 1, Vector2i(3, 2)) and _drop(ui, 2, Vector2i(3, 2))):
		_fail("Could not build the normal starting configuration")
		return
	ui.recipe_button.pressed.emit()
	if not ui.recipe_overlay.visible or not await _capture(OUTPUT.path_join("recipes.png")):
		_fail("Recipe screen capture failed")
		return
	ui._close_recipe_book()
	for stage in range(6):
		if ui.campaign_stage != stage:
			_fail("Unexpected campaign stage")
			return
		if stage == 5:
			if ui.encounter_id != "astral_serpent" or not await _capture(OUTPUT.path_join("sixth-stage.png")):
				_fail("Sixth-stage preparation capture failed")
				return
		ui._start_battle()
		var steps := 0
		while ui.battle.phase == "battle" and steps < 3000:
			ui._process(0.1)
			ui.arena._process(0.1)
			steps += 1
		if ui.battle.phase != "won":
			_fail("Normal progression failed at stage %d" % (stage + 1))
			return
		ui._primary_action()
		if stage == 0 and not _drop(ui, 3, Vector2i(2, 2)):
			_fail("Could not add focus")
			return
		if stage == 1 and not _drop(ui, 4, Vector2i(4, 1)):
			_fail("Could not add ward")
			return
		if stage == 2 and not _drop(ui, 5, Vector2i(0, 2)):
			_fail("Could not add extra spell")
			return
	if ui.campaign_stage != 6 or ui.encounter_id != "extended_moon_crowned":
		_fail("Did not reach the seventh-stage boss")
		return
	ui._start_battle()
	for _i in range(12):
		ui._process(0.1)
		ui.arena._process(0.1)
	var seen_poses := {}
	for index in range(45):
		if ui.battle.phase != "battle":
			_fail("Boss battle ended before capture finished")
			return
		var layout: Dictionary = ui.arena.get_art_layout()
		if layout.motion_clip != "mage-swing":
			_fail("Unexpected mage sprite in boss battle")
			return
		seen_poses[int(layout.motion_frame)] = true
		ui.arena.queue_redraw()
		if not await _capture(OUTPUT.path_join("boss-frames/frame%04d.png" % index)):
			_fail("Failed to capture frame %d" % index)
			return
		ui._process(0.1)
		ui.arena._process(0.1)
	if seen_poses.size() < 3:
		_fail("Boss capture did not show enough mage poses")
		return
	print("Blog capture: normal stages 1-6 won; stage 6 and recipes captured; 45 boss frames at 0.1 seconds; poses ", seen_poses.keys(), "; saves disabled")
	ui.queue_free()
	await process_frame
	quit(0)
