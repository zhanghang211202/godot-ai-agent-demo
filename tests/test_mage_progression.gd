extends SceneTree
## Real five-stage resource progression and v1/v2 checkpoint compatibility.
const Run = preload("res://scripts/classes/class_run.gd")
const Battle = preload("res://scripts/classes/class_battle.gd")
const Campaign = preload("res://scripts/classes/mage_campaign.gd")
const Save = preload("res://scripts/classes/mage_campaign_save.gd")
const Catalog = preload("res://scripts/classes/class_catalog.gd")
const Guide = preload("res://scripts/classes/mage_recipe_guide.gd")
const OUTPUT := "res://.tools/mage-progression-review"
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
		"hp": run.hp, "max_hp": run.max_hp, "phase": run.phase, "uid": run._next_uid,
		"seed": run.seed_value, "discarded": run.discarded_materials.duplicate(true), "campaign_rules_version": run.campaign_rules_version}

func _run() -> void:
	var fingerprints := {}
	for path in PLAYER_PATHS:
		fingerprints[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_legacy_save()
	await _legacy_ui()
	for kind in ["mixed", "solar", "frost", "same"]:
		await _play_route(kind)
	for path in fingerprints:
		check((FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing") == fingerprints[path], "Player save unchanged: " + path)
	print("Mage progression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _legacy_save() -> void:
	var path := OUTPUT.path_join("legacy-%d.json" % Time.get_ticks_usec())
	var run := Run.new()
	run.new_run("mage")
	run.sources = Campaign.initial_sources(1)
	check(run.acquire(0, Vector2i(3, 1)).ok and run.acquire(0, Vector2i(3, 1)).ok, "Legacy save contains two normally acquired free fire elements")
	check(Save.save_run(run, 0, path).ok, "Legacy v1 resource ledger saves")
	var saved := _state(run)
	var restored := Run.new()
	var loaded: Dictionary = Save.load_run(restored, path)
	check(loaded.ok and _state(restored) == saved and restored.campaign_rules_version == 1, "Legacy v1 ledger loads without losing items or changing its budget")
	check(Save.save_run(restored, 0, path).ok, "A restored v1 run can continue saving under its original resource rules")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(raw.schema_version == 1 and raw.rules_version == 1, "Resaving a v1 run does not silently migrate it")
	var forged: Dictionary = raw.duplicate(true)
	forged.schema_version = 2
	forged.rules_version = 2
	check(not Save._validate(forged).ok, "Legacy material totals cannot be relabelled as the reduced v2 budget")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _legacy_ui() -> void:
	var path := OUTPUT.path_join("legacy-ui-%d.json" % Time.get_ticks_usec())
	var original := Run.new()
	original.new_run("mage")
	original.sources = Campaign.initial_sources(1)
	check(original.acquire(0, Vector2i(3, 1)).ok and original.acquire(0, Vector2i(3, 1)).ok, "Legacy UI fixture uses both original fire elements")
	check(Save.save_run(original, 0, path).ok, "Legacy UI fixture writes an actual v1 checkpoint")
	var ui = load("res://scenes/mage_campaign.tscn").instantiate()
	ui.campaign_checkpoint_path = path
	root.add_child(ui)
	for _i in range(4): await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	check(ui.run.campaign_rules_version == 1 and _state(ui.run) == _state(original), "Campaign UI resumes an old run with its exact original resources")
	check(ui.status_label.text.contains("旧ルール"), "The restored legacy run explains that its original starting resources are preserved")
	ui._start_battle()
	check(ui.battle.phase == "battle", "The resumed legacy run can begin its real first battle")
	while ui.battle.phase == "battle":
		ui._process(0.1)
		ui.arena._process(0.1)
	check(ui.battle.phase == "won", "The resumed legacy run wins normally")
	var next: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(next.stage == 1 and next.rules_version == 1 and next.gold == 4, "Legacy victory checkpoints the next stage without changing its ledger version")
	ui._restore_before_battle()
	var retry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(ui.run.campaign_rules_version == 1 and retry.stage == 0 and retry.rules_version == 1, "Legacy retry restores and saves the original resource version")
	ui.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _drop(ui: Control, index: int, cell: Vector2i) -> void:
	var before: int = ui.run.sources[index].remaining
	ui._on_drop({"origin": "source", "index": index}, cell)
	check(int(ui.run.sources[index].remaining) == before - 1, "Normal source %d transaction succeeds at %s" % [index, cell])

func _play_route(kind: String) -> void:
	root.size = Vector2i(1440, 960)
	var ui = load("res://scenes/mage_campaign.tscn").instantiate()
	ui.persistence_enabled = false
	root.add_child(ui)
	for _i in range(4): await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	check(ui.run.campaign_rules_version == 2 and ui.run.sources.slice(0, 3).all(func(source: Dictionary): return source.remaining == 1), kind + " starts with one of each free element")
	var solar: Dictionary = Catalog.recipes_for("mage")[10]
	check(not Guide.plan(ui.run, solar).available, kind + " cannot start the two-fire advanced recipe before earning residue")
	if kind == "solar":
		await _capture("stage-one.png")
	match kind:
		"mixed":
			_drop(ui, 0, Vector2i.ZERO)
			_drop(ui, 1, Vector2i(3, 2))
			_drop(ui, 2, Vector2i(3, 2))
		"solar":
			ui._on_drop({"origin": "bag", "uid": 3}, Vector2i(3, 1))
			_drop(ui, 0, Vector2i.ZERO)
			_drop(ui, 1, Vector2i(3, 2))
			_drop(ui, 2, Vector2i(3, 2))
		"frost":
			ui._on_drop({"origin": "bag", "uid": 3}, Vector2i(3, 1))
			_drop(ui, 1, Vector2i.ZERO)
			_drop(ui, 0, Vector2i(0, 2))
		"same":
			_drop(ui, 0, Vector2i(3, 1))
	var last_stage := -1
	for stage in range(5):
		var reference := Battle.new()
		check(reference.start(ui.run.get_combat_config(), Campaign.encounter(stage)).ok, kind + " stage %d reference starts" % (stage + 1))
		ui._start_battle()
		while ui.battle.phase == "battle":
			ui._process(0.1)
			ui.arena._process(0.1)
			reference.tick(0.1)
		check(ui.battle.phase == "won" and ui.battle.get_summary() == reference.get_summary(), kind + " stage %d wins under actual independent rules" % (stage + 1))
		print("Progression ", kind, " stage ", stage + 1, ": ", ui.battle.phase, " HP ", ui.battle.hp, " time ", ui.battle.battle_time)
		if ui.battle.phase != "won": break
		last_stage = stage
		if stage == 4: break
		ui._primary_action()
		check(ui.campaign_stage == stage + 1 and ui.run.phase == "prepare", kind + " advances to the next real preparation")
		if kind == "solar" and stage == 0:
			check(ui.run.gold == 4 and Guide.plan(ui.run, solar).available, "First victory unlocks the two-fire route with an earned paid element")
			await _capture("solar-stage-two-before.png")
		if stage == 0:
			match kind:
				"mixed": _drop(ui, 3, Vector2i(2, 2))
				"solar": _drop(ui, 6, Vector2i.ZERO)
				"frost": _drop(ui, 2, Vector2i.ZERO)
				"same": _drop(ui, 6, Vector2i(3, 1))
		elif stage == 1:
			match kind:
				"mixed": _drop(ui, 4, Vector2i(4, 1))
				"solar", "frost": _drop(ui, 3, Vector2i(2, 2))
				"same":
					_drop(ui, 1, Vector2i(5, 1))
					_drop(ui, 7, Vector2i(5, 1))
		if kind == "solar" and stage == 0:
			check(ui.run.item_by_uid(1).kind == "solar_lance" and ui.run.gold == 2, "Solar upgrade consumes exactly two earned residue")
			await _capture("solar-stage-two-after.png")
		if stage == 1:
			var path := OUTPUT.path_join("%s-%d.json" % [kind, Time.get_ticks_usec()])
			var before := _state(ui.run)
			check(Save.save_run(ui.run, ui.campaign_stage, path).ok, kind + " v2 preparation saves its real material ledger")
			var restored := Run.new()
			var result: Dictionary = Save.load_run(restored, path)
			check(result.ok and result.stage == ui.campaign_stage and _state(restored) == before, kind + " v2 roundtrip preserves the budget and build")
			var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			raw.sources[0].remaining = 2
			check(not Save._validate(raw).ok, kind + " v2 rejects excess free stock")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(last_stage == 4, kind + " complete legal progression reaches and defeats the boss")
	ui.queue_free()
	await process_frame

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT.path_join(name)) == OK, "Captured actual preparation: " + name)
