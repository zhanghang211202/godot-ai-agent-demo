extends SceneTree
## Real native Controls/input integration for C0 rules, not C1 art acceptance.

const SCENE := "res://scenes/class_lab.tscn"
const Save = preload("res://scripts/classes/class_save.gd")
const TEST_SAVE := "res://.tools/test-saves/class-ui-smoke.json"
var ui: Control
var checks := 0
var failures := 0
var default_save_before := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1440, 960)
	default_save_before = _file_fingerprint(Save.DEFAULT_PATH)
	var scene: PackedScene = load(SCENE)
	if scene == null:
		push_error("Unable to load C0 laboratory scene")
		quit(1)
		return
	ui = scene.instantiate()
	if ui == null or ui.get_script() == null:
		push_error("C0 laboratory script failed to load; stopping before cascaded errors")
		quit(1)
		return
	ui.set("persistence_enabled", false)
	ui.set("checkpoint_path", TEST_SAVE)
	root.add_child(ui)
	await _settle()
	ui.set_process(false)
	if ui.get("run") == null or ui.get("grid") == null or ui.get("arena") == null:
		push_error("C0 laboratory failed to create its run, grid or arena")
		quit(1)
		return
	check(ui.run.class_id == "mage" and ui.run.phase == "prepare", "Scene opens in mage preparation")
	check(not ui.persistence_enabled and ui.checkpoint_path == TEST_SAVE, "Smoke starts with persistence disabled and isolated fixture path")
	await _test_native_mage_flow()
	await _test_knight_flow()
	await _test_native_drag_rotation()
	await _test_snapshot_class_boundaries()
	await _test_responsive_layout()
	check(_file_fingerprint(Save.DEFAULT_PATH) == default_save_before, "Player default class checkpoint was never changed")
	var cleanup: Dictionary = Save.reset_prototype(TEST_SAVE)
	check(cleanup.ok and not FileAccess.file_exists(TEST_SAVE), "Only the isolated UI fixture checkpoint is cleaned")
	print("ClassLab C0 UI smoke: %d checks, %d failures" % [checks, failures])
	ui.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _settle() -> void:
	for _frame in range(3):
		await process_frame

func _file_fingerprint(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func _state() -> Dictionary:
	return {"class_id": ui.run.class_id, "items": ui.run.items.duplicate(true),
		"sources": ui.run.sources.duplicate(true), "gold": ui.run.gold,
		"hp": ui.run.hp, "max_hp": ui.run.max_hp, "phase": ui.run.phase,
		"next_uid": ui.run._next_uid, "discarded": ui.run.discarded_materials.duplicate(true)}

func _cell_center(cell: Vector2i) -> Vector2:
	return ui.grid.get_global_transform() * ui.grid.cell_rect(cell).get_center()

func _native_click(position: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_screen_transform() * position
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = button
	press.pressed = true
	press.position = motion.position
	press.global_position = press.position
	Input.parse_input_event(press)
	await process_frame
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func _native_key(keycode: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	var release: InputEventKey = key.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func _source_to_cell(source: int, cell: Vector2i) -> void:
	ui.source_buttons[source].pressed.emit()
	await _native_click(_cell_center(cell))

func _finish_training() -> void:
	for _frame in range(1000):
		if ui.run.phase != "battle":
			break
		ui._process(0.1)

func _test_native_mage_flow() -> void:
	check(ui.resources_label.text.contains("吸收") and ui.resources_label.text.contains("有限"), "Mage source panel explains finite absorption")
	check(ui.source_buttons[0].text.contains("火元素") and ui.source_buttons[0].text.contains("剩余 2"), "Mage source button exposes name and remaining count")
	# Full window-coordinate input routing, including the native Button itself.
	await _native_click(ui.source_buttons[0].get_global_rect().get_center())
	check(ui.held.get("origin") == "source" and ui.held.get("index") == 0, "Native source Button click enters click-to-place mode")
	await _native_click(_cell_center(Vector2i.ZERO))
	check(ui.run.item_at(Vector2i.ZERO).get("kind") == "flame_glyph", "Native source-to-grid clicks weave a real burst spell")
	check(ui.run.sources[0].remaining == 1 and ui.run.gold == 0 and ui.held.is_empty(), "Successful free absorption consumes one source and clears selection")
	await _source_to_cell(1, Vector2i(3, 2))
	await _source_to_cell(2, Vector2i(3, 2))
	check(ui.run.item_at(Vector2i(5, 2)).get("kind") == "tide_lances", "Native grid placement weaves a three-cell multi-hit spell")
	check(ui.run.sources[1].remaining == 1 and ui.run.sources[2].remaining == 1, "Both multi-spell ingredient sources are paid once")
	var before := _state()
	ui.source_buttons[0].pressed.emit()
	await _native_click(_cell_center(Vector2i(4, 0)))
	check(_state() == before and not ui.held.is_empty(), "Invalid source drop on incompatible armor loses no source, material or currency")
	await _native_click(_cell_center(Vector2i(4, 0)), MOUSE_BUTTON_RIGHT)
	check(ui.held.is_empty() and ui.selected_uid == -1 and ui.grid.held.is_empty(), "Native right click cancels source placement without paying")
	await _native_click(_cell_center(Vector2i(2, 1)))
	var focus: Dictionary = ui.run.item_at(Vector2i(2, 1))
	var focus_uid := int(focus.get("uid", -1))
	check(ui.selected_uid == focus_uid and focus_uid > 0, "Native grid click selects the directional support")
	check(ui.detail_label.text.contains("聚能晶核") and ui.detail_label.text.contains("实际占格"), "Selected item details expose the actual support and occupied shape")
	await _native_key(KEY_R)
	check(ui.held.get("rotated", false), "Native R rotates the pending item")
	await _native_click(_cell_center(Vector2i(2, 1)))
	check(ui.run.item_by_uid(focus_uid).get("rotated", false), "Rotated support commits through grid click")
	await _native_click(_cell_center(Vector2i(2, 1)))
	await _native_key(KEY_R)
	await _native_click(_cell_center(Vector2i(2, 1)))
	check(not ui.run.item_by_uid(focus_uid).get("rotated", true), "Second real rotation restores the original support direction")
	var preparation := _state()
	ui.primary_button.pressed.emit()
	check(ui.run.phase == "battle" and ui.battle.phase == "battle", "Native primary Button signal starts validated battle rules")
	check(ui.primary_button.disabled and ui.class_buttons.mage.disabled and ui.class_buttons.knight.disabled and ui.source_buttons[0].disabled, "Battle locks class, preparation and source controls")
	check(ui.save_button.disabled and ui.load_button.disabled, "Battle does not expose checkpoint changes")
	await _native_click(ui.class_buttons.knight.get_global_rect().get_center())
	await _native_click(ui.source_buttons[0].get_global_rect().get_center())
	await _native_click(_cell_center(Vector2i.ZERO))
	check(ui.run.class_id == "mage" and ui.run.items == preparation.items and ui.run.sources == preparation.sources, "Disabled native controls and grid cannot alter a running build")
	ui._process(0.25)
	ui.pause_button.pressed.emit()
	var paused: Dictionary = ui.battle.get_summary()
	var flash: float = ui.arena.flash
	ui._process(8.0)
	ui.arena._process(8.0)
	check(ui.battle.paused and ui.pause_button.text == "继续" and ui.battle.get_summary() == paused and ui.arena.flash == flash, "Pause freezes simulation, event statistics and schematic animation")
	ui.pause_button.pressed.emit()
	ui.speed_button.pressed.emit()
	var prior_time: float = ui.battle.battle_time
	ui._process(0.25)
	check(ui.speed == 2.0 and ui.speed_button.text == "2×" and is_equal_approx(ui.battle.battle_time - prior_time, 0.5), "2x UI advances the engine exactly twice the supplied delta")
	_finish_training()
	check(ui.run.phase == "won" and ui.battle.phase == "won" and ui.battle.enemy_hp == 0, "Normally assembled mage build completes the training battle")
	check(ui.summary_label.text.contains("一战复盘") and ui.summary_label.text.contains("焰爆法印") and ui.summary_label.text.contains("潮汐连枪"), "Result panel displays both actual spell contributions")
	check(not ui.replay_button.disabled and not ui.class_buttons.knight.disabled, "Finished battle permits comparison or another class")
	ui.replay_button.pressed.emit()
	check(_state() == preparation and ui.battle.phase == "idle", "Restoring preparation returns the exact finite-resource checkpoint")
	ui.replay_button.pressed.emit()
	check(_state() == preparation, "Repeated restoration does not replenish absorbed sources or duplicate items")

func _test_knight_flow() -> void:
	ui.class_buttons.knight.pressed.emit()
	check(ui.run.class_id == "knight" and ui.run.gold == 12 and ui._before_battle.is_empty(), "New class clears the other class's transient battle checkpoint")
	check(ui.resources_label.text.contains("12 金币") and ui.source_buttons[1].text.contains("4 金币"), "Knight source panel exposes actual finite purchase cost")
	ui.source_buttons[1].pressed.emit()
	await _native_click(_cell_center(Vector2i(4, 0)))
	check(ui.run.gold == 12 and ui.run.sources[1].remaining == 2, "Rejected paid drop preserves both coins and source count")
	await _native_click(_cell_center(Vector2i.ZERO))
	check(ui.run.item_at(Vector2i(1, 2)).get("kind") == "greatblade" and ui.run.gold == 8 and ui.run.sources[1].remaining == 1, "Normal paid UI forge creates a six-cell heavy blade")
	await _source_to_cell(1, Vector2i(2, 1))
	check(ui.run.gold == 4 and ui.run.sources[1].remaining == 0 and ui.source_buttons[1].disabled, "Second paid support exhausts its source without extra charges")
	check(ui.run.get_adjacency_bonus(ui.run.item_at(Vector2i.ZERO)) == 4, "Second support's real position strengthens the heavy blade")
	var preparation := _state()
	ui.primary_button.pressed.emit()
	ui._process(0.05)
	check(ui.arena.last_event.get("type") == "charge" and ui.arena.last_event.get("source_kind") == "greatblade", "Live arena receives a source-tagged heavy charge event")
	_finish_training()
	check(ui.run.phase == "won" and ui.summary_label.text.contains("誓约重刃"), "Knight finishes with a real heavy-weapon contribution summary")
	ui.replay_button.pressed.emit()
	check(_state() == preparation and ui.run.gold == 4 and ui.run.sources[1].remaining == 0, "Knight battle restore preserves spent gold and exhausted sources")

func _native_drag_rotated(from: Vector2, to: Vector2) -> void:
	var screen_from: Vector2 = root.get_screen_transform() * from
	var screen_to: Vector2 = root.get_screen_transform() * to
	var motion := InputEventMouseMotion.new()
	motion.position = screen_from
	motion.global_position = screen_from
	Input.parse_input_event(motion)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = screen_from
	press.global_position = screen_from
	Input.parse_input_event(press)
	await process_frame
	for position in [screen_from + Vector2(20, 12), screen_to]:
		var move_event := InputEventMouseMotion.new()
		move_event.position = position
		move_event.global_position = position
		move_event.relative = Vector2(20, 12)
		move_event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(move_event)
		await process_frame
	check(root.gui_is_dragging(), "Native pointer motion actually starts a Godot GUI drag")
	await _native_key(KEY_R)
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	release.button_mask = 0
	release.position = screen_to
	release.global_position = screen_to
	Input.parse_input_event(release)
	await _settle()

func _test_native_drag_rotation() -> void:
	ui.class_buttons.knight.pressed.emit()
	await _settle()
	await _native_drag_rotated(_cell_center(Vector2i.ZERO), _cell_center(Vector2i(3, 2)))
	var blade: Dictionary = ui.run.item_at(Vector2i(5, 2))
	check(blade.get("kind") == "iron_blade" and blade.get("rotated", false) and blade.pos == Vector2i(3, 2), "R during a real bag drag commits the preview orientation, not the old drag payload")
	check(ui.run.item_at(Vector2i.ZERO).is_empty(), "Rotated native drag releases the original footprint")
	ui.class_buttons.knight.pressed.emit()
	await _settle()
	await _native_drag_rotated(ui.source_buttons[2].get_global_rect().get_center(), _cell_center(Vector2i(3, 2)))
	var armor: Dictionary = ui.run.item_at(Vector2i(3, 3))
	check(armor.get("kind") == "knight_ward" and armor.get("rotated", false), "R during a real source drag commits the rotated purchased footprint")
	check(ui.run.gold == 9 and ui.run.sources[2].remaining == 0, "Rotated native source drag charges exactly once")
	ui.source_buttons[0].grab_focus()
	await _native_key(KEY_SPACE)
	check(ui.run.phase == "battle" and ui.battle.phase == "battle", "Space starts training even when a native source Button owns focus")
	_finish_training()
	ui.class_buttons.mage.pressed.emit()
	await _settle()

func _test_snapshot_class_boundaries() -> void:
	var cleanup: Dictionary = Save.reset_prototype(TEST_SAVE)
	check(cleanup.ok, "Dedicated checkpoint path is safe to use")
	if not cleanup.ok:
		return
	ui.class_buttons.mage.pressed.emit()
	var mage := _state()
	ui.replay_button.pressed.emit()
	check(_state() == mage and ui._before_battle.is_empty(), "New mage cannot restore a previous knight battle")
	ui.persistence_enabled = true
	ui._sync()
	ui.save_button.pressed.emit()
	check(FileAccess.file_exists(TEST_SAVE) and Save.inspect_save(TEST_SAVE).get("class_id") == "mage", "Save Button persists only the explicitly isolated mage checkpoint")
	ui.class_buttons.knight.pressed.emit()
	# Keep the separate mage checkpoint while a second class completes a battle.
	ui.persistence_enabled = false
	ui._sync()
	ui.primary_button.pressed.emit()
	_finish_training()
	check(not ui._before_battle.is_empty() and ui._before_battle.class_id == "knight", "Knight run creates its own transient battle checkpoint")
	ui.persistence_enabled = true
	ui._sync()
	ui.load_button.pressed.emit()
	check(ui.run.class_id == "mage" and ui.run.phase == "prepare" and ui._before_battle.is_empty(), "Cross-class load clears the old knight battle checkpoint")
	check(ui.battle.phase == "idle" and ui.arena.battle == ui.battle and ui.held.is_empty(), "Load installs a clean engine and clears pending interaction")
	ui.replay_button.pressed.emit()
	check(_state() == mage, "Replay after a cross-class load cannot resurrect another class or resources")
	ui.persistence_enabled = false
	ui._sync()

func _test_responsive_layout() -> void:
	for dimensions in [Vector2i(1280, 800), Vector2i(1440, 960), Vector2i(1920, 1080)]:
		var before := _state()
		root.size = dimensions
		await _settle()
		var label := "%dx%d" % [dimensions.x, dimensions.y]
		var viewport := Rect2(Vector2.ZERO, Vector2(dimensions))
		check(ui.size.is_equal_approx(Vector2(dimensions)), label + " uses the native output size")
		check(_state() == before, label + " resizing changes no inventory or finite sources")
		for control in [ui.grid, ui.arena, ui.carrier_label, ui.resources_label, ui.phase_label, ui.primary_button, ui.pause_button, ui.speed_button, ui.save_button, ui.load_button, ui.replay_button, ui.status_label]:
			check(viewport.grow(0.1).encloses(control.get_global_rect()), label + " visible control fits: " + str(control.get_path()))
		for button in ui.source_buttons:
			check(viewport.encloses(button.get_global_rect()) and button.size.x > 100 and button.size.y >= 42, label + " source Button remains visible and usable")
		var grid_rect: Rect2 = ui.grid.grid_rect()
		check(Rect2(Vector2.ZERO, ui.grid.size).encloses(grid_rect) and grid_rect.size.x > 240, label + " complete 6x4 board stays inside its native Control")
		check(not ui.grid.get_global_rect().intersects(ui.source_buttons[0].get_global_rect()) and not ui.grid.get_global_rect().intersects(ui.arena.get_global_rect()), label + " inventory does not overlap sources or battle display")
		var mapping_ok := true
		for y in range(4):
			for x in range(6):
				var cell := Vector2i(x, y)
				mapping_ok = mapping_ok and ui.grid.cell_at(ui.grid.cell_rect(cell).get_center()) == cell
		check(mapping_ok and ui.grid.cell_at(grid_rect.end + Vector2.ONE) == Vector2i(-1, -1), label + " all 24 cell centers and outside boundary map correctly")
		await _native_click(ui.source_buttons[0].get_global_rect().get_center())
		await _native_click(_cell_center(Vector2i(5, 3)))
		check(ui.run.item_at(Vector2i(5, 3)).get("kind") == "fire_mote" and ui.run.sources[0].remaining == 1, label + " resized native source-to-grid clicks place in the intended corner cell")
		ui.class_buttons.mage.pressed.emit()
	root.size = Vector2i(1440, 960)
	await _settle()
