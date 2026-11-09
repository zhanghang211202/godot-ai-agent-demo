extends SceneTree
## Independent campaign checkpoint, accounting and actual UI continuation.

const Run = preload("res://scripts/classes/class_run.gd")
const Battle = preload("res://scripts/classes/class_battle.gd")
const Campaign = preload("res://scripts/classes/mage_campaign.gd")
const Save = preload("res://scripts/classes/mage_campaign_save.gd")
const ClassSave = preload("res://scripts/classes/class_save.gd")
const DIR := "res://.tools/test-saves/mage-campaign-checkpoint"
const FILE := DIR + "/campaign.json"
const BAD := DIR + "/bad.json"
const UI_FILE := DIR + "/ui.json"
const OUTPUT := "res://.tools/mage-campaign-save-review"
const PLAYER_PATHS := ["user://mage-trial-run.json", "user://class-prototype-run.json", "user://emberpack-run.json", "user://mage-campaign-run.json"]
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	_run.call_deferred()

func _state(run: RefCounted) -> Dictionary:
	return {"class_id": run.class_id, "items": run.items.duplicate(true), "sources": run.sources.duplicate(true), "gold": run.gold, "hp": run.hp, "max_hp": run.max_hp, "uid": run._next_uid, "phase": run.phase, "seed": run.seed_value, "discarded": run.discarded_materials.duplicate(true), "campaign_rules_version": run.campaign_rules_version}

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _cleanup() -> void:
	for path in [FILE, FILE + ".tmp", FILE + ".bak", BAD, BAD + ".tmp", BAD + ".bak", UI_FILE, UI_FILE + ".tmp", UI_FILE + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_cleanup()
	var fingerprints := {}
	for path in PLAYER_PATHS:
		fingerprints[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	check(Save.DEFAULT_PATH not in PLAYER_PATHS.slice(0, 3), "Campaign checkpoint has an independent filename")
	var run := Run.new()
	run.new_run("mage", 9223372036854775806)
	run.sources.append_array(Campaign.shop_sources())
	check(run.acquire(0, Vector2i.ZERO).ok and run.acquire(1, Vector2i(3, 2)).ok and run.acquire(2, Vector2i(3, 2)).ok, "Checkpoint fixture uses legal element weaving")
	check(Save.save_run(run, 0, FILE).ok, "A valid initial preparation saves")
	var battle := Battle.new()
	check(battle.start(run.get_combat_config(), Campaign.encounter(0)).ok, "First checkpoint build starts a real battle")
	battle.tick(Battle.TIME_LIMIT)
	check(battle.phase == "won", "First checkpoint build wins before receiving residue")
	run.gold += Campaign.REWARDS[0]
	check(run.acquire(3, Vector2i(2, 2)).ok, "Earned residue condenses an actual crystal")
	check(Save.save_run(run, 1, FILE).ok and not FileAccess.file_exists(FILE + ".tmp") and not FileAccess.file_exists(FILE + ".bak"), "Stage-two checkpoint atomically replaces the prior checkpoint")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	check(raw.kind == Save.KIND and raw.stage == 1 and raw.seed == "9223372036854775806", "Campaign schema preserves stage and exact 64-bit seed")
	var restored := Run.new()
	restored.new_run("knight")
	var loaded: Dictionary = Save.load_run(restored, FILE)
	check(loaded.ok and loaded.stage == 1 and _state(restored) == _state(run), "Roundtrip restores all board, stock, residue and stage fields")
	check(not Save.save_run(run, 1, DIR + "/emberpack-run.json").ok and not Save.save_run(run, 1, DIR + "/mage-trial-run.json").ok and not Save.save_run(run, 1, DIR + "/class-prototype-run.json").ok, "Legacy and single-trial filenames cannot be campaign targets")
	for phase in ["battle", "won", "lost"]:
		run.phase = phase
		check(not Save.save_run(run, 1, FILE).ok, "Saving rejects " + phase)
	run.phase = "prepare"
	var good_bytes := FileAccess.get_file_as_string(FILE)
	_write(FILE + ".tmp", "keep")
	check(not Save.save_run(run, 1, FILE).ok and FileAccess.get_file_as_string(FILE) == good_bytes and FileAccess.get_file_as_string(FILE + ".tmp") == "keep", "Stale sidecar prevents replacement without modifying either file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE + ".tmp"))
	for mutation in [["kind", "other"], ["schema_version", 2], ["stage", 2], ["stage", 5], ["stage", 0.5], ["completed", true], ["completed_hp", 20], ["gold", 100], ["gold", -1], ["next_uid", 1], ["hp", 0], ["phase", "battle"], ["seed", "01"], ["sources", []]]:
		var damaged: Dictionary = raw.duplicate(true)
		damaged[mutation[0]] = mutation[1]
		_expect_invalid(damaged, str(mutation[0]), restored)
	for mutation in [["cost", 0], ["remaining", 2], ["id", "other"], ["kind", "spark"]]:
		var damaged: Dictionary = raw.duplicate(true)
		damaged.sources[3][mutation[0]] = mutation[1]
		_expect_invalid(damaged, "source " + str(mutation[0]), restored)
	var overlap: Dictionary = raw.duplicate(true)
	overlap.items[1].pos = overlap.items[0].pos.duplicate()
	_expect_invalid(overlap, "overlapping items", restored)
	var unknown_item: Dictionary = raw.duplicate(true)
	unknown_item.items[0].kind = "greatblade"
	_expect_invalid(unknown_item, "foreign item", restored)
	_write(BAD, "{broken")
	var before := _state(restored)
	check(not Save.load_run(restored, BAD).ok and _state(restored) == before and not Save.save_run(run, 1, BAD).ok and FileAccess.get_file_as_string(BAD) == "{broken", "Malformed existing data is never loaded or overwritten")
	await _ui_roundtrip()
	for path in fingerprints:
		var after := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
		check(after == fingerprints[path], "Real player save remains unchanged: " + path)
	_cleanup()
	print("Mage campaign save: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _expect_invalid(raw: Dictionary, label: String, target: RefCounted) -> void:
	var bytes := JSON.stringify(raw)
	_write(BAD, bytes)
	var before := _state(target)
	check(not Save.load_run(target, BAD).ok and _state(target) == before, label + " is rejected atomically")
	check(FileAccess.get_file_as_string(BAD) == bytes, label + " remains untouched")

func _ui_roundtrip() -> void:
	root.size = Vector2i(1440, 960)
	var ui = load("res://scenes/mage_campaign.tscn").instantiate()
	ui.campaign_checkpoint_path = UI_FILE
	root.add_child(ui)
	for _i in range(4): await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	check(ui.persistence_enabled and ui.save_button.visible and ui.load_button.visible, "Campaign exposes independent save and load controls")
	check(ui.run.acquire(0, Vector2i.ZERO).ok and ui.run.acquire(1, Vector2i(3, 2)).ok and ui.run.acquire(2, Vector2i(3, 2)).ok, "UI checkpoint fixture uses ordinary weaving")
	ui._start_battle()
	check(ui.battle.phase == "battle" and FileAccess.file_exists(UI_FILE), "Starting combat automatically writes a stage-one preparation")
	var initial_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UI_FILE))
	check(initial_data.schema_version == 2 and initial_data.rules_version == 2, "A new campaign checkpoints the reduced-resource rules version")
	var during := _state(ui.run)
	ui._load()
	check(ui.battle.phase == "battle" and _state(ui.run) == during, "Loading is refused during active combat")
	while ui.battle.phase == "battle":
		ui._process(0.1)
		ui.arena._process(0.1)
	check(ui.battle.phase == "won" and ui.run.gold == 4, "Real first victory earns four residue")
	var next_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UI_FILE))
	check(next_data.stage == 1 and next_data.gold == 4 and not next_data.completed, "Victory immediately checkpoints the next preparation and reward")
	var resumed = load("res://scenes/mage_campaign.tscn").instantiate()
	resumed.campaign_checkpoint_path = UI_FILE
	root.add_child(resumed)
	for _i in range(3): await process_frame
	check(resumed.campaign_stage == 1 and resumed.run.gold == 4 and resumed.run.phase == "prepare", "A fresh game automatically resumes the earned next stage")
	resumed.queue_free()
	await process_frame
	ui._restore_before_battle()
	var retry_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UI_FILE))
	check(ui.campaign_stage == 0 and ui.run.gold == 0 and retry_data.stage == 0 and retry_data.gold == 0 and retry_data.rules_version == 2 and ui.run.campaign_rules_version == 2, "Choosing retry preserves both the original board and its reduced-resource rules")
	ui._start_battle()
	while ui.battle.phase == "battle":
		ui._process(0.1)
		ui.arena._process(0.1)
	check(ui.battle.phase == "won" and ui.run.gold == 4, "Retry does not duplicate its reward")
	ui._primary_action()
	check(ui.campaign_stage == 1 and ui.run.phase == "prepare", "Victory proceeds to stage-two preparation")
	var check_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UI_FILE))
	check(check_data.stage == 1 and check_data.gold == 4, "Advancing automatically checkpoints the earned reward")
	ui.source_buttons[3].pressed.emit()
	ui._on_cell_selected(Vector2i(2, 2))
	var after_purchase: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UI_FILE))
	check(ui.run.gold == 0 and after_purchase.gold == 0 and after_purchase.sources[3].remaining == 0, "A confirmed purchase is automatically checkpointed")
	check(ui._save(), "Purchased crystal can also be saved manually")
	var saved := _state(ui.run)
	ui._new_class("mage")
	check(ui.campaign_stage == 0, "A new run resets only the in-memory campaign")
	ui._load()
	check(ui.campaign_stage == 1 and ui.encounter_id == Campaign.encounter(1) and _state(ui.run) == saved, "Load returns to the saved stage and purchased build")
	for _i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT.path_join("restored-stage-two.png")) == OK, "Saved a Japanese runtime screenshot of the restored preparation")
	for stage in range(1, 5):
		ui._start_battle()
		check(ui.battle.phase == "battle", "Restored campaign starts stage %d" % (stage + 1))
		if stage == 4:
			_write(UI_FILE + ".tmp", "keep")
		while ui.battle.phase == "battle":
			ui._process(0.1)
			ui.arena._process(0.1)
		check(ui.battle.phase == "won", "Restored campaign wins stage %d" % (stage + 1))
		if ui.battle.phase != "won": break
		if stage < 4:
			ui._primary_action()
			var progress: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UI_FILE))
			check(progress.stage == stage + 1 and not progress.completed and progress.gold == ui.run.gold, "Next stage automatically preserves residue and progress")
			if stage == 1:
				_write(UI_FILE + ".tmp", "keep")
				ui.source_buttons[4].pressed.emit()
				ui._on_cell_selected(Vector2i(4, 1))
				check(ui.run.gold == 0 and ui.run.item_at(Vector2i(4, 1)).kind == "mage_ward", "Restored run can spend the next reward on a ward")
				check(ui.status_label.text.contains("保存できません") and FileAccess.get_file_as_string(UI_FILE + ".tmp") == "keep", "Failed automatic save reports its error and preserves the sidecar")
				ui._start_battle()
				check(ui.run.phase == "prepare" and ui.battle.phase == "idle", "Combat does not start when its required checkpoint cannot be saved")
				DirAccess.remove_absolute(ProjectSettings.globalize_path(UI_FILE + ".tmp"))
				check(ui._save(), "Preparation can be saved after the conflict is resolved")
		else:
			var winning_hp: int = ui.battle.hp
			check(ui.status_label.text.contains("保存できません") and not ui.save_button.disabled, "Final victory remains manually saveable after an automatic save failure")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(UI_FILE + ".tmp"))
			check(ui._save(), "Completed campaign can be saved after the conflict is resolved")
			var cleared: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UI_FILE))
			check(cleared.stage == 4 and cleared.completed and cleared.completed_hp == winning_hp, "Boss victory saves the actual completed result and remaining HP")
			ui._new_class("mage")
			ui._load()
			check(ui.campaign_stage == 4 and ui.run.phase == "won" and ui.battle.hp == winning_hp and ui.battle.enemy_hp == 0 and ui.primary_button.disabled, "Reload retains the cleared boss and real final HP")
			var reopened = load("res://scenes/mage_campaign.tscn").instantiate()
			reopened.campaign_checkpoint_path = UI_FILE
			root.add_child(reopened)
			for _i in range(3): await process_frame
			check(reopened.campaign_stage == 4 and reopened.run.phase == "won" and reopened.battle.hp == winning_hp, "A fresh game automatically restores the cleared result")
			reopened.queue_free()
			await process_frame
			for _i in range(4): await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(OUTPUT.path_join("restored-completion.png")) == OK, "Saved the restored completion screen")
			var completed_state := _state(ui.run)
			_write(BAD, "{broken")
			ui.campaign_checkpoint_path = BAD
			ui._load()
			check(_state(ui.run) == completed_state and ui.campaign_stage == 4 and ui.battle.phase == "won" and FileAccess.get_file_as_string(BAD) == "{broken", "UI rejects corrupt saves without changing the current result")
	ui.queue_free()
	await process_frame
