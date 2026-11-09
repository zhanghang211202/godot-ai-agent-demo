extends SceneTree
## Earned wind/support weaving, actual cooldowns, UI and material conservation.
const Run = preload("res://scripts/classes/class_run.gd")
const Catalog = preload("res://scripts/classes/class_catalog.gd")
const Battle = preload("res://scripts/classes/class_battle.gd")
const Campaign = preload("res://scripts/classes/mage_campaign.gd")
const CampaignSave = preload("res://scripts/classes/mage_campaign_save.gd")
const TrialSave = preload("res://scripts/classes/class_save.gd")
const MageArt = preload("res://scripts/classes/mage_art.gd")
const OUTPUT := "res://.tools/mage-haste-review"
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
		"hp": run.hp, "uid": run._next_uid, "phase": run.phase, "discarded": run.discarded_materials.duplicate(true), "version": run.campaign_rules_version}

func _action(run: RefCounted, uid: int) -> Dictionary:
	for action: Dictionary in run.get_combat_config().actions:
		if action.uid == uid: return action
	return {}

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var fingerprints := {}
	for path in PLAYER_PATHS:
		fingerprints[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	_model()
	await _ui()
	for path in fingerprints:
		check((FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing") == fingerprints[path], "Player save unchanged: " + path)
	print("Mage haste: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _model() -> void:
	var run := Run.new()
	run.new_run("mage")
	check(run.move(1, Vector2i(1, 0)).ok, "A real board move positions spark beside the focus")
	var original := _action(run, 1)
	check(original.damage == 7 and is_equal_approx(original.interval, 1.5), "Original focus increases each spark hit by two")
	var before := _state(run)
	var preview: Dictionary = run.preview_placement({"origin": "source", "index": 2}, Vector2i(2, 1))
	check(preview.ok and preview.item.kind == "wind_prism" and preview.size == Vector2i(2, 1) and _state(run) == before, "Wind and focus preview their support product without consuming anything")
	var preview_action: Array = preview.combat.actions.filter(func(entry: Dictionary): return entry.uid == 1)
	check(preview_action.size() == 1 and preview_action[0].damage == 5 and is_equal_approx(preview_action[0].interval, 1.2), "Preview shows the damage-for-speed tradeoff")
	check(run.acquire(2, Vector2i(2, 1)).ok and run.get_combat_config() == preview.combat, "Actual weaving exactly matches the preview")
	check(run.item_by_uid(3).kind == "wind_prism" and run.sources[2].remaining == 1, "One focus and one finite wind element are consumed")
	var accelerated := _action(run, 1)
	var unrelated := _action(run, 2)
	check(accelerated.damage == 5 and is_equal_approx(accelerated.interval, 1.2) and is_equal_approx(accelerated.warmup, 0.4), "Only subsequent intervals change; first cast and base damage remain honest")
	check(unrelated.damage == 5 and is_equal_approx(unrelated.interval, 1.5), "A nonadjacent spark receives no speed bonus")
	check(float(accelerated.damage) / accelerated.interval < float(original.damage) / original.interval, "For a low-damage spark, converting focus to speed can reduce sustained damage")
	var heavy := Run.new()
	heavy.new_run("mage")
	check(heavy.acquire(0, Vector2i.ZERO).ok, "The comparison creates a real supported flame glyph")
	var before_heavy := _action(heavy, 1)
	check(heavy.acquire(2, Vector2i(2, 1)).ok, "The same board converts its focus into a wind support")
	var after_heavy := _action(heavy, 1)
	check(before_heavy.damage == 20 and after_heavy.damage == 18 and float(after_heavy.damage) / after_heavy.interval > float(before_heavy.damage) / before_heavy.interval, "A high-damage flame glyph benefits from speed despite losing per-hit damage")
	var battle := Battle.new()
	check(battle.start(run.get_combat_config(), Campaign.encounter(0)).ok, "The accelerated legal board starts actual combat")
	var times: Array = battle.tick(4.05).filter(func(event: Dictionary): return event.get("source_uid") == 1 and event.type == "spell").map(func(event: Dictionary): return event.time)
	check(times.size() == 4 and is_equal_approx(times[0], 0.4) and is_equal_approx(times[1], 1.6) and is_equal_approx(times[2], 2.8) and is_equal_approx(times[3], 4.0), "Real combat fires at the displayed 1.20-second interval")
	check(run.move(3, Vector2i(2, 1), true).ok and is_equal_approx(_action(run, 1).interval, 1.5), "Rotating the support breaks the old horizontal connection")
	check(run.move(1, Vector2i(1, 0), true).ok and is_equal_approx(_action(run, 1).interval, 1.2), "Rotated support connects to the spell above")
	var timing_fixture := Run.new()
	timing_fixture.new_run("mage")
	timing_fixture.items.assign([
		{"uid": 1, "kind": "gale_blades", "pos": Vector2i.ZERO, "rotated": false},
		{"uid": 2, "kind": "wind_prism", "pos": Vector2i(2, 0), "rotated": false},
	])
	check(is_equal_approx(_action(timing_fixture, 1).interval, 1.15), "A 1.12-second result rounds up to the actual 50 ms combat step")
	timing_fixture.items.append({"uid": 3, "kind": "wind_prism", "pos": Vector2i(0, 1), "rotated": true})
	check(is_equal_approx(timing_fixture.get_interval_factor(timing_fixture.items[0]), 0.64) and is_equal_approx(_action(timing_fixture, 1).interval, 0.9), "Two distinct directional supports multiply and respect clock quantization")
	var trial_path := OUTPUT.path_join("trial-%d.json" % Time.get_ticks_usec())
	check(TrialSave.save_run(run, trial_path).ok, "The old single-trial ledger accepts the new material-preserving item")
	var copy := Run.new()
	check(TrialSave.load_run(copy, trial_path).ok and _state(copy) == _state(run), "Single-trial save restores rotation and original raw ingredients")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(trial_path))
	var icon := MageArt.icon("wind_prism")
	check(not icon.is_empty() and Rect2(icon.region).encloses(Rect2(icon.source_rect).grow(1)), "Wind support uses a separate uncropped icon")
	check(Catalog.recipes_for("mage").size() == 13 and Catalog.recipes_for("mage")[12].result == "wind_prism", "The support recipe is appended without changing prior recipe indices")

func _ui() -> void:
	root.size = Vector2i(1440, 960)
	var ui = load("res://scenes/mage_campaign.tscn").instantiate()
	ui.persistence_enabled = false
	root.add_child(ui)
	for _i in range(4): await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	ui._on_drop({"origin": "bag", "uid": 1}, Vector2i(1, 0))
	ui._open_recipe_book()
	for _i in range(3): await process_frame
	ui.recipe_scroll.ensure_control_visible(ui.recipe_cards[12])
	for _i in range(3): await process_frame
	check(ui.recipe_overlay.visible and not ui.recipe_cards[12].disabled and ui.recipe_cards[12].text.contains("約20%短縮") and not ui.recipe_cards[12].text.contains("%%"), "The new support recipe is visible and explains its effect")
	await _capture("recipe.png")
	root.size = Vector2i(1280, 800)
	for _i in range(4): await process_frame
	ui.recipe_scroll.ensure_control_visible(ui.recipe_cards[12])
	for _i in range(3): await process_frame
	await _capture("recipe-1280.png")
	root.size = Vector2i(1440, 960)
	for _i in range(4): await process_frame
	var before := _state(ui.run)
	ui.recipe_cards[12].pressed.emit()
	check(ui.held.get("origin") == "source" and ui.held.get("index") == 2 and _state(ui.run) == before, "Recipe guidance selects actual wind without consumption")
	var preview: Dictionary = ui.run.preview_placement(ui.held, Vector2i(2, 1))
	ui._show_placement_preview(preview)
	check(ui.preview_label.text.contains("1.20秒") and _state(ui.run) == before, "Placement preview exposes the connected spell's real accelerated interval")
	await _capture("preview.png")
	ui._on_cell_selected(Vector2i(2, 1))
	check(ui.run.item_by_uid(3).kind == "wind_prism" and is_equal_approx(_action(ui.run, 1).interval, 1.2), "Normal UI weaving produces the working support")
	await _capture("prepared.png")
	var path := OUTPUT.path_join("campaign-%d.json" % Time.get_ticks_usec())
	check(CampaignSave.save_run(ui.run, 0, path).ok, "New campaign saves the haste product with conserved ingredients")
	var restored := Run.new()
	check(CampaignSave.load_run(restored, path).ok and _state(restored) == _state(ui.run), "Campaign v2 loads the exact new support and resources")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var reference := Battle.new()
	check(reference.start(ui.run.get_combat_config(), ui.encounter_id).ok, "Haste UI battle has an independent rules reference")
	ui._start_battle()
	while ui.battle.phase == "battle":
		ui._process(0.05)
		ui.arena._process(0.05)
		reference.tick(0.05)
	check(ui.battle.get_summary() == reference.get_summary(), "Haste, spell presentation and actual combat results agree")
	ui.queue_free()
	await process_frame

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT.path_join(name)) == OK, "Captured actual UI: " + name)
