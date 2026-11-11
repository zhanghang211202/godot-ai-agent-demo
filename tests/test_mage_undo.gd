extends SceneTree
## One-step board-only undo and checkpoint conservation; never touches player saves.
const Run = preload("res://scripts/classes/class_run.gd")
const CampaignSave = preload("res://scripts/classes/mage_campaign_save.gd")
const OUTPUT := "res://.tools/mage-undo-review"
const PLAYER_PATHS := ["user://mage-campaign-run.json", "user://mage-trial-run.json", "user://class-prototype-run.json", "user://emberpack-run.json"]
var ui: Control
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	_run.call_deferred()

func _state() -> Dictionary:
	return {"items": ui.run.items.duplicate(true), "sources": ui.run.sources.duplicate(true), "gold": ui.run.gold,
		"hp": ui.run.hp, "uid": ui.run._next_uid, "discarded": ui.run.discarded_materials.duplicate(true), "stage": ui.campaign_stage}

func _fingerprints() -> Dictionary:
	var hashes := {}
	for path in PLAYER_PATHS:
		hashes[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return hashes

func _load_state(path: String) -> Dictionary:
	var copy := Run.new()
	var loaded: Dictionary = CampaignSave.load_run(copy, path)
	return {"ok": loaded.ok, "items": copy.items.duplicate(true), "sources": copy.sources.duplicate(true), "gold": copy.gold,
		"hp": copy.hp, "uid": copy._next_uid, "discarded": copy.discarded_materials.duplicate(true), "stage": loaded.get("stage", -1)}

func _run() -> void:
	var player_saves := _fingerprints()
	var fixture_path := "res://.tools/test-saves/mage-undo-%d.json" % Time.get_ticks_usec()
	root.size = Vector2i(1440, 960)
	ui = load("res://scenes/mage_campaign.tscn").instantiate()
	ui.campaign_checkpoint_path = fixture_path
	root.add_child(ui)
	for _i in range(4): await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	check(ui._save() and ui.undo_button.disabled, "Fresh run has a safe separate save and no undo")
	var initial := _state()
	var preview: Dictionary = ui.run.preview_placement({"origin": "bag", "uid": 2}, Vector2i.ZERO)
	ui._show_placement_preview(preview)
	check(preview.ok and ui.preview_label.text.contains("合成で消費：微光の術式（1列3行）") and _state() == initial, "A preview identifies the consumed spell by its player-visible position without changing the board")
	for dimensions in [Vector2i(1280, 800), Vector2i(1440, 960), Vector2i(1920, 1080)]:
		root.size = dimensions
		for _i in range(4): await process_frame
		check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(ui.undo_button.get_global_rect()) and not ui.undo_button.get_global_rect().intersects(ui.carrier_label.get_global_rect()), str(dimensions) + " undo is visible beside the board heading")
	root.size = Vector2i(1440, 960)
	for _i in range(4): await process_frame
	ui._on_drop({"origin": "bag", "uid": 2, "rotated": false}, Vector2i.ZERO)
	check(ui.run.item_by_uid(1).kind == "arcane_nova" and ui.run.item_by_uid(2).is_empty() and not ui.undo_button.disabled, "Moving one owned spark onto another creates a reversible merge")
	var merged := _state()
	var merged_save := _load_state(fixture_path)
	merged_save.erase("ok")
	check(merged_save == merged, "The merged state is checkpointed")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT.path_join("merge.png")) == OK, "Merged board screenshot saved")
	await _click(ui.undo_button.get_global_rect().get_center())
	check(_state() == initial and ui.undo_button.disabled, "Real button click restores both original sparks exactly once")
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT.path_join("restored.png")) == OK, "Restored board screenshot saved")
	var restored := _load_state(fixture_path)
	check(restored.ok, "The reverted checkpoint remains valid")
	restored.erase("ok")
	check(restored == initial, "Undo writes the restored board to the campaign checkpoint")
	ui._on_drop({"origin": "bag", "uid": 3, "rotated": true}, Vector2i(2, 1))
	check(ui.run.item_by_uid(3).rotated and not ui.undo_button.disabled, "Committed rotation is undoable")
	var key := InputEventKey.new()
	key.keycode = KEY_Z
	key.ctrl_pressed = true
	key.pressed = true
	ui._unhandled_key_input(key)
	check(_state() == initial and ui.undo_button.disabled, "Ctrl+Z restores the original orientation")
	ui._on_drop({"origin": "bag", "uid": 3}, Vector2i(3, 1))
	var moved := _state()
	ui._on_drop({"origin": "bag", "uid": 3}, Vector2i(4, 0))
	check(_state() == moved and not ui.undo_button.disabled, "An invalid drop leaves the prior undo available")
	ui._undo_placement()
	check(_state() == initial, "Undo still restores the earlier move after a rejected drop")
	ui._on_drop({"origin": "bag", "uid": 3}, Vector2i(3, 1))
	var first_move := _state()
	ui._open_recipe_book()
	ui._undo_placement()
	check(_state() == first_move and not ui.undo_button.disabled, "A modal recipe book blocks undo without losing it")
	ui._close_recipe_book()
	ui._on_drop({"origin": "bag", "uid": 3}, Vector2i(3, 1))
	check(not ui.undo_button.disabled, "A no-op move does not erase the last meaningful edit")
	ui._on_drop({"origin": "bag", "uid": 3}, Vector2i(3, 2))
	ui._undo_placement()
	check(_state() == first_move and ui.undo_button.disabled, "Only the last board action is retained")
	ui._on_drop({"origin": "source", "index": 0}, Vector2i.ZERO)
	check(ui.run.item_by_uid(1).kind == "flame_glyph" and ui.run.sources[0].remaining == 0 and ui.undo_button.disabled, "Element absorption and source merge clear undo without refund")
	var acquired := _state()
	ui._undo_placement()
	check(_state() == acquired, "Undo cannot reverse or duplicate acquired materials")
	ui._on_drop({"origin": "bag", "uid": 3}, Vector2i(2, 1))
	ui.selected_uid = 4
	ui._discard()
	check(ui.run.item_by_uid(4).is_empty() and ui.undo_button.disabled, "Discard clears the board undo")
	var discarded := _state()
	ui._undo_placement()
	check(_state() == discarded, "Discard cannot be reversed")
	ui._new_class("mage")
	var before_conflict := _state()
	ui._on_drop({"origin": "bag", "uid": 3}, Vector2i(3, 1))
	var saved_before_conflict := FileAccess.get_sha256(fixture_path)
	var conflict := FileAccess.open(fixture_path + ".tmp", FileAccess.WRITE)
	conflict.store_string("keep")
	conflict.close()
	ui._undo_placement()
	check(_state() == before_conflict and ui.status_label.text.contains("保存できません") and FileAccess.get_sha256(fixture_path) == saved_before_conflict, "Undo reports an autosave failure and preserves the prior checkpoint")
	ui._start_battle()
	check(ui.run.phase == "prepare", "Battle cannot start while the restored state cannot be saved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path + ".tmp"))
	check(ui._save(), "The restored state can be saved after resolving the conflict")
	var after_conflict := _load_state(fixture_path)
	after_conflict.erase("ok")
	check(after_conflict == before_conflict, "Retry saves the correctly restored state")
	ui._new_class("mage")
	ui._on_drop({"origin": "bag", "uid": 3}, Vector2i(3, 1))
	ui._load()
	check(ui.undo_button.disabled, "Successful reload clears undo history")
	ui._on_drop({"origin": "bag", "uid": 3}, Vector2i(3, 2))
	ui.run.gold += 1
	var stale := _state()
	ui._undo_placement()
	check(_state() == stale and ui.undo_button.disabled, "Unexpected state changes invalidate undo without restoring resources")
	ui._new_class("mage")
	ui._on_drop({"origin": "bag", "uid": 3}, Vector2i(3, 1))
	check(not ui.undo_button.disabled, "A board edit prepares undo before battle")
	ui._start_battle()
	check(ui.run.phase == "battle" and ui.undo_button.disabled and ui._undo_signature.is_empty(), "Starting battle clears undo")
	var battle_items: Array = ui.run.items.duplicate(true)
	ui._undo_placement()
	check(ui.run.items == battle_items, "Undo cannot mutate the active battle")
	while ui.battle.phase == "battle":
		ui._process(0.1)
		ui.arena._process(0.1)
	check(ui.battle.phase == "won" and ui.run.gold == 4, "Actual victory produces the first-stage reward")
	ui._advance_campaign()
	ui._on_drop({"origin": "bag", "uid": 3}, Vector2i(2, 1))
	check(not ui.undo_button.disabled, "A new stage can create a new undo record")
	ui._on_drop({"origin": "source", "index": 3}, Vector2i(3, 2))
	check(ui.run.gold == 0 and ui.run.item_at(Vector2i(3, 2)).kind == "arcane_focus" and ui.undo_button.disabled, "Paid condensation clears undo and spends the earned residue")
	var purchased := _state()
	ui._undo_placement()
	check(_state() == purchased, "Undo does not refund or duplicate a paid item")
	check(_fingerprints() == player_saves, "Actual player checkpoint hashes remain unchanged")
	ui.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
	ui = load("res://scenes/mage_trial.tscn").instantiate()
	ui.persistence_enabled = false
	root.add_child(ui)
	for _i in range(4): await process_frame
	var trial_before := _state()
	ui._on_drop({"origin": "bag", "uid": 3}, Vector2i(3, 1))
	ui._undo_placement()
	check(_state() == trial_before, "Mage single-trial board also supports undo without changing its save")
	ui._on_drop({"origin": "bag", "uid": 3}, Vector2i(3, 1))
	ui._select_encounter("mirror_moth")
	check(ui.undo_button.disabled and ui._undo_signature.is_empty(), "Changing trial opponent clears the old undo immediately")
	ui.queue_free()
	await process_frame
	print("Mage undo: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_screen_transform() * position
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = motion.position
	press.global_position = motion.position
	Input.parse_input_event(press)
	await process_frame
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
