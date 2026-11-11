extends SceneTree
## Current-stage forecasts use real battle rules and never mutate run or saves.
const Battle = preload("res://scripts/classes/class_battle.gd")
const Campaign = preload("res://scripts/classes/mage_campaign.gd")
const Rehearsal = preload("res://scripts/classes/mage_rehearsal.gd")
const OUTPUT := "res://.tools/mage-campaign-rehearsal-review"
const PLAYER_PATHS := ["user://mage-campaign-run.json", "user://mage-trial-run.json", "user://class-prototype-run.json", "user://emberpack-run.json"]
var ui: Control
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	_run.call_deferred()

func _state() -> Dictionary:
	return {"items": ui.run.items.duplicate(true), "sources": ui.run.sources.duplicate(true), "uid": ui.run._next_uid,
		"discarded": ui.run.discarded_materials.duplicate(true), "gold": ui.run.gold, "hp": ui.run.hp,
		"phase": ui.run.phase, "stage": ui.campaign_stage, "encounter": ui.encounter_id, "battle": ui.battle.get_summary().duplicate(true)}

func _fingerprints() -> Dictionary:
	var result := {}
	for path in PLAYER_PATHS:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return result

func _run() -> void:
	var player_saves := _fingerprints()
	var fixture_path := "res://.tools/test-saves/campaign-rehearsal-%d.json" % Time.get_ticks_usec()
	root.size = Vector2i(1440, 960)
	ui = load("res://scenes/mage_campaign.tscn").instantiate()
	ui.developer_tools_enabled = true
	ui.campaign_checkpoint_path = fixture_path
	root.add_child(ui)
	for _i in range(4): await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	check(ui._save(), "Campaign test creates its own checkpoint")
	var checkpoint := FileAccess.get_sha256(fixture_path)
	check(not Rehearsal.simulate(ui.run, []).ok and not Rehearsal.simulate(ui.run, ["unknown"]).ok, "Missing or unknown enemies are rejected")
	for dimensions in [Vector2i(1280, 800), Vector2i(1440, 960), Vector2i(1920, 1080)]:
		root.size = dimensions
		for _i in range(4): await process_frame
		var viewport := Rect2(Vector2.ZERO, Vector2(dimensions))
		check(viewport.encloses(ui.rehearsal_button.get_global_rect()) and not ui.rehearsal_button.get_global_rect().intersects(ui.phase_label.get_global_rect()), str(dimensions) + " forecast control fits without overlapping the phase heading")
	root.size = Vector2i(1440, 960)
	for _i in range(4): await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for stage in range(5):
		ui.campaign_stage = stage
		ui.encounter_id = Campaign.encounter(stage)
		ui._sync()
		var before := _state()
		var result: Dictionary = Rehearsal.simulate(ui.run, [ui.encounter_id])
		check(result.ok and result.encounters.size() == 1 and result.encounters[0].id == ui.encounter_id, "Stage %d simulates only its actual opponent" % (stage + 1))
		var reference := Battle.new()
		check(reference.start(ui.run.get_combat_config(), ui.encounter_id).ok, "Stage %d reference starts" % (stage + 1))
		while reference.phase == "battle":
			reference.tick(0.05)
		check(reference.get_summary() == result.encounters[0].summary, "Stage %d forecast matches separately stepped combat" % (stage + 1))
		if stage == 0:
			await _click(ui.rehearsal_button.get_global_rect().get_center())
		else:
			ui.rehearsal_button.pressed.emit()
		var summary: Dictionary = reference.get_summary()
		check(ui.summary_label.text.contains("第%d戦の予行演習" % (stage + 1)) and ui.summary_label.text.contains(reference.enemy_name), "Stage %d displays its own result" % (stage + 1))
		check(ui.summary_label.text.contains("残りHP %d / %d" % [summary.hp, summary.max_hp]) and ui.summary_label.text.contains("法盾で軽減 %d" % summary.armor_mitigated), "Stage %d displays actual health and ward mitigation" % (stage + 1))
		check(_state() == before and FileAccess.get_sha256(fixture_path) == checkpoint, "Stage %d rehearsal changes no run, battle, or checkpoint" % (stage + 1))
		if stage in [0, 4]:
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(OUTPUT.path_join("stage-%d.png" % (stage + 1))) == OK, "Stage %d fixture screenshot saved" % (stage + 1))
	ui.campaign_stage = 0
	ui.encounter_id = Campaign.encounter(0)
	ui._sync()
	check(ui.summary_label.text.contains("配置が変わりました") and ui._rehearsal_signature.is_empty(), "Changing the encounter invalidates a prior forecast")
	ui._rehearse()
	check(ui.run.move(3, Vector2i(3, 1)).ok, "A legal edit changes the board")
	ui._sync()
	check(ui.summary_label.text.contains("配置が変わりました") and ui._rehearsal_signature.is_empty(), "Changing the board invalidates a prior forecast")
	ui._new_class("mage")
	check(ui.run.discard(1).ok and ui.run.discard(2).ok, "Invalid-build fixture has no attacks")
	var invalid_before := _state()
	ui._rehearse()
	check(_state() == invalid_before and not ui.status_label.text.is_empty(), "Invalid builds report failure without changing the run")
	ui._new_class("mage")
	ui._start_battle()
	var battle_before := _state()
	var during_checkpoint := FileAccess.get_sha256(fixture_path)
	check(ui.rehearsal_button.disabled, "Rehearsal is disabled during battle")
	ui._rehearse()
	check(_state() == battle_before and FileAccess.get_sha256(fixture_path) == during_checkpoint, "Rehearsal cannot mutate a live battle")
	check(_fingerprints() == player_saves, "Actual player checkpoints are unchanged")
	ui.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
	print("Mage campaign rehearsal: %d checks, %d failures" % [checks, failures])
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
