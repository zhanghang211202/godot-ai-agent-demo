extends SceneTree
## Real v3 campaigns, new encounters, and non-migrating v1/v2 save boundaries.
const Run = preload("res://scripts/classes/class_run.gd")
const Battle = preload("res://scripts/classes/class_battle.gd")
const Campaign = preload("res://scripts/classes/mage_campaign.gd")
const Save = preload("res://scripts/classes/mage_campaign_save.gd")
const MageArt = preload("res://scripts/classes/mage_art.gd")
const OUTPUT := "res://.tools/mage-seven-review"
const PLAYER_PATHS := ["user://mage-campaign-run.json", "user://mage-trial-run.json", "user://class-prototype-run.json", "user://emberpack-run.json"]
var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	_run.call_deferred()

func _state(run: RefCounted) -> Dictionary:
	return {"items": run.items.duplicate(true), "sources": run.sources.duplicate(true), "gold": run.gold,
		"hp": run.hp, "max_hp": run.max_hp, "uid": run._next_uid, "phase": run.phase,
		"discarded": run.discarded_materials.duplicate(true), "version": run.campaign_rules_version}

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var fingerprints := {}
	for path in PLAYER_PATHS:
		fingerprints[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	check(Campaign.stage_count(1) == 5 and Campaign.stage_count(2) == 5 and Campaign.stage_count(3) == 7, "Campaign length follows its rules version")
	check(Campaign.encounter(4, 1) == "moon_crowned" and Campaign.encounter(4, 2) == "moon_crowned" and Campaign.encounter(6, 3) == "extended_moon_crowned", "Old final encounters stay at stage five and new boss is stage seven")
	check(Campaign.encounters(3).duplicate().size() == 7 and Campaign.encounters(3).duplicate().all(func(id: String): return Campaign.encounters(3).count(id) == 1), "All seven encounters have distinct IDs")
	for id in ["moon_lantern", "astral_serpent"]:
		var art: Dictionary = MageArt.enemy(id)
		check(not art.is_empty() and art.single_pose and art.frames.size() == 4 and Rect2(art.frames[0].region).encloses(art.frames[0].source_rect), id + " has a complete standalone source used for all procedural poses")
	_enemy_rules()
	_fixed_pressure()
	_expanded_stock()
	await _restart_confirmation()
	for version in [1, 2]:
		await _legacy(version)
	for kind in ["mixed", "wind", "crowned"]:
		await _play(kind)
	for path in fingerprints:
		check((FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing") == fingerprints[path], "Actual player save unchanged: " + path)
	print("Mage seven-stage: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _restart_confirmation() -> void:
	var path := OUTPUT.path_join("restart-%d.json" % Time.get_ticks_usec())
	var old := Run.new()
	old.new_run("mage")
	old.campaign_rules_version = 2
	old.sources = Campaign.initial_sources(2)
	old.gold = 19
	check(Save.save_run(old, 4, path).ok, "Restart fixture has an existing five-stage checkpoint")
	var old_hash := FileAccess.get_sha256(path)
	var ui = load("res://scenes/mage_campaign.tscn").instantiate()
	ui.campaign_checkpoint_path = path
	root.add_child(ui)
	for _i in range(4): await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.class_buttons["mage"].pressed.emit()
	for _i in range(3): await process_frame
	check(ui.restart_dialog.visible and ui.campaign_stage == 4 and ui.run.campaign_rules_version == 2 and FileAccess.get_sha256(path) == old_hash, "Restart asks first without changing the run or checkpoint")
	if not DisplayServer.get_name().to_lower().contains("headless"):
		root.get_texture().get_image().save_png(OUTPUT.path_join("restart-confirmation.png"))
	for dimensions in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		ui.restart_dialog.hide()
		root.size = dimensions
		await process_frame
		ui.class_buttons["mage"].pressed.emit()
		for _i in range(3): await process_frame
		check(Rect2i(Vector2i.ZERO, dimensions).encloses(Rect2i(ui.restart_dialog.position, ui.restart_dialog.size)), "Restart dialog fits %s" % dimensions)
		if not DisplayServer.get_name().to_lower().contains("headless"):
			root.get_texture().get_image().save_png(OUTPUT.path_join("restart-confirmation-%dx%d.png" % [dimensions.x, dimensions.y]))
	var cancel := InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.pressed = true
	Input.parse_input_event(cancel)
	for _i in range(3): await process_frame
	check(not ui.restart_dialog.visible and ui.campaign_stage == 4 and FileAccess.get_sha256(path) == old_hash, "Cancelling restart preserves the old checkpoint")
	root.size = Vector2i(1440, 960)
	await process_frame
	ui.class_buttons["mage"].pressed.emit()
	await process_frame
	check(ui.restart_dialog.get_cancel_button().has_focus(), "Restart initially focuses the cancel action")
	var accept := InputEventKey.new()
	accept.keycode = KEY_ENTER
	accept.pressed = true
	Input.parse_input_event(accept)
	for _i in range(3): await process_frame
	check(ui.campaign_stage == 4 and FileAccess.get_sha256(path) == old_hash, "Enter on the default focus does not replace the checkpoint")
	ui.restart_dialog.hide()
	ui.class_buttons["mage"].pressed.emit()
	await process_frame
	ui.restart_dialog.get_ok_button().pressed.emit()
	await process_frame
	var fresh := Run.new()
	var loaded: Dictionary = Save.load_run(fresh, path)
	check(loaded.ok and loaded.stage == 0 and fresh.campaign_rules_version == 3 and ui.run.campaign_rules_version == 3 and _state(fresh) == _state(ui.run), "Confirming writes a new seven-stage checkpoint immediately")
	ui._start_battle()
	ui.class_buttons["mage"].pressed.emit()
	check(not ui.restart_dialog.visible and ui.run.phase == "battle", "Restart cannot open or replace a running battle")
	ui.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _expanded_stock() -> void:
	var run := Run.new()
	run.new_run("mage")
	run.campaign_rules_version = 3
	run.sources = Campaign.initial_sources(3)
	run.gold = 13
	check(run.acquire(3, Vector2i(4, 2)).ok and run.acquire(3, Vector2i(5, 2)).ok and run.acquire(4, Vector2i(4, 1)).ok, "Three earned rewards can buy two separate crystal cores and a ward")
	check(run.gold == 1 and run.sources[3].remaining == 0 and run.sources[4].remaining == 1, "Expanded stock and earned residue are consumed exactly once")
	var path := OUTPUT.path_join("expanded-stock-%d.json" % Time.get_ticks_usec())
	check(Save.save_run(run, 3, path).ok, "The v3 ledger accepts two purchases from the expanded stock")
	var copy := Run.new()
	var loaded: Dictionary = Save.load_run(copy, path)
	check(loaded.ok and loaded.stage == 3 and _state(copy) == _state(run), "Expanded stock survives checkpoint restoration")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	raw.schema_version = 2
	raw.rules_version = 2
	check(not Save._validate(raw).ok, "Expanded stock cannot be forged into an old v2 ledger")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _enemy_rules() -> void:
	var run := Run.new()
	run.new_run("mage")
	for sample in [["moon_lantern", 2.5, 9, 7], ["astral_serpent", 3.1, 14, 12]]:
		var battle := Battle.new()
		check(battle.start(run.get_combat_config(), sample[0]).ok, str(sample[0]) + " accepts a real mage board")
		var attacks: Array = battle.tick(sample[1]).filter(func(event: Dictionary): return event.type == "enemy_attack")
		check(attacks.size() == 2 and attacks.all(func(event: Dictionary): return event.raw_amount == sample[2] and event.amount == sample[3] and event.armor_mitigated == 2), str(sample[0]) + " applies ward mitigation to both actual hits")

func _fixed_pressure() -> void:
	# The same board is legal by the fourth preparation after earning 13 residue.
	# Comparing it across all enemies isolates enemy pressure from future upgrades.
	var run := Run.new()
	run.new_run("mage")
	run.campaign_rules_version = 3
	run.sources = Campaign.initial_sources(3)
	check(run.acquire(0, Vector2i.ZERO).ok and run.acquire(1, Vector2i(3, 2)).ok and run.acquire(2, Vector2i(3, 2)).ok, "Fixed pressure board weaves its initial elements")
	run.gold = 13
	check(run.acquire(3, Vector2i(2, 2)).ok and run.acquire(4, Vector2i(4, 1)).ok and run.acquire(5, Vector2i(0, 2)).ok, "Fixed pressure board spends only the first three rewards")
	var path := OUTPUT.path_join("fixed-pressure-%d.json" % Time.get_ticks_usec())
	check(Save.save_run(run, 3, path).ok, "Fixed comparison is a valid fourth-preparation ledger")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var previous_hp := run.max_hp
	var previous_time := 0.0
	for stage in range(7):
		var battle := Battle.new()
		check(battle.start(run.get_combat_config(), Campaign.encounter(stage, 3)).ok, "Fixed comparison starts stage %d" % (stage + 1))
		battle.tick(Battle.TIME_LIMIT)
		print("Seven fixed stage ", stage + 1, ": ", battle.phase, " HP ", battle.hp, " time ", battle.battle_time)
		check(battle.phase == "won" and battle.hp < previous_hp and battle.battle_time >= previous_time, "Fixed board sees rising pressure at stage %d" % (stage + 1))
		previous_hp = battle.hp
		previous_time = battle.battle_time

func _legacy(version: int) -> void:
	var path := OUTPUT.path_join("legacy-%d-%d.json" % [version, Time.get_ticks_usec()])
	var run := Run.new()
	run.new_run("mage")
	run.campaign_rules_version = version
	run.sources = Campaign.initial_sources(version)
	check(run.acquire(0, Vector2i.ZERO).ok and run.acquire(1, Vector2i(3, 2)).ok and run.acquire(2, Vector2i(3, 2)).ok, "Legacy %d build uses its actual starting elements" % version)
	run.gold = 19
	check(run.acquire(3, Vector2i(2, 2)).ok and run.acquire(4, Vector2i(4, 1)).ok, "Legacy %d spends only earned residue" % version)
	check(Save.save_run(run, 4, path).ok, "Legacy %d stage-five preparation saves" % version)
	var saved := _state(run)
	var ui = load("res://scenes/mage_campaign.tscn").instantiate()
	ui.campaign_checkpoint_path = path
	root.add_child(ui)
	for _i in range(4): await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	check(ui.run.campaign_rules_version == version and _state(ui.run) == saved and ui.campaign_stage == 4 and ui.encounter_id == "moon_crowned" and ui.campaign_stage_label.text.contains("/ 5"), "Legacy %d resumes its original fifth battle and inventory" % version)
	ui._start_battle()
	while ui.battle.phase == "battle":
		ui._process(0.1)
		ui.arena._process(0.1)
	check(ui.battle.phase == "won" and ui.primary_button.disabled, "Legacy %d boss remains the final battle" % version)
	var finished_hp: int = ui.battle.hp
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(raw.completed and raw.stage == 4 and raw.rules_version == version, "Legacy %d victory saves in its original version" % version)
	ui._load()
	check(ui.run.phase == "won" and ui.encounter_id == "moon_crowned" and ui.battle.hp == finished_hp and ui.campaign_stage == 4, "Legacy %d completed save restores its boss and HP" % version)
	raw.completed = false
	raw.completed_hp = 0
	raw.stage = 5
	check(not Save._validate(raw).ok, "Legacy %d cannot silently enter the new stage sequence" % version)
	ui.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _drop(ui: Control, index: int, cell: Vector2i) -> void:
	var stock: int = ui.run.sources[index].remaining
	ui._on_drop({"origin": "source", "index": index}, cell)
	check(int(ui.run.sources[index].remaining) == stock - 1, "Real source %d acquisition at %s" % [index, cell])

func _play(kind: String) -> void:
	root.size = Vector2i(1440, 960)
	var ui = load("res://scenes/mage_campaign.tscn").instantiate()
	var checkpoint := OUTPUT.path_join("ui-%s-%d.json" % [kind, Time.get_ticks_usec()])
	ui.persistence_enabled = kind == "mixed"
	ui.campaign_checkpoint_path = checkpoint
	root.add_child(ui)
	for _i in range(4): await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	check(ui.run.campaign_rules_version == 3 and ui.campaign_stage_label.text.contains("/ 7") and ui.run.sources.slice(0, 3).all(func(source: Dictionary): return source.remaining == 1), kind + " starts the new seven-stage budget")
	check(ui.run.sources[3].remaining == 2 and ui.run.sources[6].remaining == 3, kind + " starts the v3 finite shop ledger")
	match kind:
		"mixed":
			_drop(ui, 0, Vector2i.ZERO)
			_drop(ui, 1, Vector2i(3, 2))
			_drop(ui, 2, Vector2i(3, 2))
		"wind":
			_drop(ui, 1, Vector2i(2, 1))
			_drop(ui, 2, Vector2i(2, 1))
			_drop(ui, 0, Vector2i.ZERO)
		"crowned":
			_drop(ui, 1, Vector2i(2, 1))
			_drop(ui, 0, Vector2i.ZERO)
			_drop(ui, 2, Vector2i(0, 2))
	var sixth_hp := 0
	for stage in range(7):
		var id := Campaign.encounter(stage, 3)
		check(ui.campaign_stage == stage and ui.encounter_id == id and ui.run.phase == "prepare", kind + " advances to the expected stage %d" % (stage + 1))
		var reference := Battle.new()
		check(reference.start(ui.run.get_combat_config(), id).ok, kind + " reference starts stage %d" % (stage + 1))
		if kind == "mixed" and stage in [3, 5]:
			await _capture("prepare-%s.png" % id)
		ui._start_battle()
		if kind == "mixed" and stage in [3, 5]:
			for dimensions in [Vector2i(1280, 800), Vector2i(1440, 960), Vector2i(1920, 1080)]:
				root.size = dimensions
				for _i in range(4): await process_frame
				var layout: Dictionary = ui.arena.get_art_layout()
				var viewport := Rect2(Vector2.ZERO, Vector2(dimensions))
				check(viewport.encloses(ui.campaign_stage_label.get_global_rect()) and not ui.campaign_stage_label.get_global_rect().intersects(ui.class_buttons["mage"].get_global_rect()), str(dimensions) + " seven-stage progress does not overlap restart")
				check(layout.enemy_path.contains("moon-lantern.png" if stage == 3 else "astral-serpent.png") and Rect2(layout.scene_rect).encloses(layout.enemy_rect) and not Rect2(layout.enemy_rect).intersects(layout.hero_rect), str(dimensions) + " " + id + " is complete and separated from the mage")
				if stage == 5:
					check(Rect2(layout.enemy_rect).size.y > Rect2(layout.hero_rect).size.y * 1.1, str(dimensions) + " serpent is visibly larger than the mage")
				var deadline: int = ui.battle._enemy_next_step
				for pose_index in range(4):
					ui.arena.feedback.hero_hit = 1.0 if pose_index == 2 else 0.0
					ui.arena.feedback.enemy_hit = 1.0 if pose_index == 3 else 0.0
					ui.battle._enemy_next_step = ui.battle._step_index + (1 if pose_index == 1 else 1000)
					var pose: Dictionary = ui.arena.get_art_layout()
					check(pose.enemy_frame == pose_index and Rect2(pose.scene_rect).encloses(pose.enemy_rect) and not Rect2(pose.enemy_rect).intersects(pose.hero_rect), str(dimensions) + " " + id + " procedural pose %d fits" % pose_index)
				ui.battle._enemy_next_step = deadline
				ui.arena.feedback.hero_hit = 0.0
				ui.arena.feedback.enemy_hit = 0.0
				if dimensions.x == 1440: await _capture("battle-%s.png" % id)
			root.size = Vector2i(1440, 960)
			for _i in range(4): await process_frame
		var effect_kind := "lantern_flare" if stage == 3 else "serpent_comet" if stage == 5 else ""
		var saw_flight := false
		var saw_impact := false
		while ui.battle.phase == "battle":
			ui._process(0.05)
			ui.arena._process(0.05)
			reference.tick(0.05)
			if kind == "mixed" and not effect_kind.is_empty():
				var layout: Dictionary = ui.arena.get_art_layout()
				if not saw_flight and layout.spell_casts.any(func(cast: Dictionary): return cast.kind == effect_kind and cast.phase == "flight"):
					saw_flight = true
					await _capture("flight-%s.png" % id)
				if not saw_impact and layout.spell_effects.any(func(effect: Dictionary): return effect.kind == effect_kind and effect.hits == 2):
					saw_impact = true
					await _capture("impact-%s.png" % id)
		if kind == "mixed" and not effect_kind.is_empty():
			check(saw_flight and saw_impact, id + " shows its actual two-hit attack flight and impact")
		check(ui.battle.phase == "won" and ui.battle.get_summary() == reference.get_summary(), kind + " wins stage %d with exact independent combat results" % (stage + 1))
		print("Seven ", kind, " stage ", stage + 1, " ", id, ": ", ui.battle.phase, " HP ", ui.battle.hp, " time ", ui.battle.battle_time)
		if ui.battle.phase != "won": break
		if kind == "mixed":
			var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(checkpoint))
			check(raw.rules_version == 3 and raw.stage == mini(stage + 1, 6) and raw.completed == (stage == 6) and raw.gold == ui.run.gold, "Real v3 victory checkpoints stage %d and its earned balance" % (stage + 1))
			if stage in [2, 5, 6]:
				var resumed = load("res://scenes/mage_campaign.tscn").instantiate()
				resumed.campaign_checkpoint_path = checkpoint
				root.add_child(resumed)
				for _i in range(4): await process_frame
				check(resumed.run.campaign_rules_version == 3 and resumed.campaign_stage == mini(stage + 1, 6) and resumed.encounter_id == Campaign.encounter(mini(stage + 1, 6), 3) and resumed.run.gold == ui.run.gold and (resumed.run.phase == "won" if stage == 6 else resumed.run.phase == "prepare"), "A fresh UI restores v3 stage %d without changing its version" % (stage + 1))
				if stage == 6:
					check(resumed.battle.hp == ui.battle.hp and resumed.primary_button.disabled, "A fresh UI restores the actual seven-stage boss result")
				resumed.queue_free()
				await process_frame
		if stage == 5: sixth_hp = ui.battle.hp
		if stage == 6:
			check(ui.primary_button.disabled and ui.battle.hp < sixth_hp, kind + " final boss pressures this fixed route more than stage six")
			var complete_path := OUTPUT.path_join("%s-complete-%d.json" % [kind, Time.get_ticks_usec()])
			check(Save.save_run(ui.run, stage, complete_path, true, ui.battle.hp).ok, kind + " seven-stage completion saves")
			var copy := Run.new()
			var loaded: Dictionary = Save.load_run(copy, complete_path)
			check(loaded.ok and loaded.completed and loaded.stage == 6 and copy.campaign_rules_version == 3 and copy.gold == ui.run.gold, kind + " completion restores the v3 ledger")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(complete_path))
			break
		ui._primary_action()
		match kind:
			"mixed":
				if stage == 0: _drop(ui, 3, Vector2i(2, 2))
				elif stage == 1: _drop(ui, 4, Vector2i(4, 1))
				elif stage == 2: _drop(ui, 5, Vector2i(0, 2))
			"wind":
				if stage == 0: _drop(ui, 5, Vector2i(4, 2))
				elif stage == 1: _drop(ui, 4, Vector2i(4, 1))
				elif stage == 2: _drop(ui, 6, Vector2i(0, 2))
				elif stage == 3: _drop(ui, 3, Vector2i(2, 0))
			"crowned":
				if stage == 0: _drop(ui, 7, Vector2i(2, 1))
				elif stage == 1:
					ui._on_drop({"origin": "bag", "uid": 3}, Vector2i(2, 2))
					check(ui.run.item_by_uid(3).pos == Vector2i(2, 2), "Move the large contract to make room")
					_drop(ui, 3, Vector2i(2, 0))
					_drop(ui, 7, Vector2i(2, 0))
				elif stage == 2: _drop(ui, 4, Vector2i(0, 3))
				elif stage == 3: _drop(ui, 5, Vector2i(5, 2))
		if stage in [2, 5]:
			var path := OUTPUT.path_join("%s-stage-%d-%d.json" % [kind, stage + 2, Time.get_ticks_usec()])
			var before := _state(ui.run)
			check(Save.save_run(ui.run, ui.campaign_stage, path).ok, kind + " saves its earned v3 materials at stage %d" % (stage + 2))
			var copy := Run.new()
			var loaded: Dictionary = Save.load_run(copy, path)
			check(loaded.ok and loaded.stage == stage + 1 and _state(copy) == before, kind + " restores the exact v3 stage and ledger")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	ui.queue_free()
	await process_frame
	if FileAccess.file_exists(checkpoint):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(checkpoint))

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT.path_join(name)) == OK, "Captured actual UI " + name)
