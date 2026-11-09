extends SceneTree
## Multi-step weaving, conservation, normal UI, and actual combat effects.
const Run = preload("res://scripts/classes/class_run.gd")
const Catalog = preload("res://scripts/classes/class_catalog.gd")
const Guide = preload("res://scripts/classes/mage_recipe_guide.gd")
const Campaign = preload("res://scripts/classes/mage_campaign.gd")
const CampaignSave = preload("res://scripts/classes/mage_campaign_save.gd")
const ClassSave = preload("res://scripts/classes/class_save.gd")
const Battle = preload("res://scripts/classes/class_battle.gd")
const Art = preload("res://scripts/classes/mage_art.gd")
const OUTPUT := "res://.tools/mage-advanced-review"
const PLAYER_PATHS := ["user://mage-campaign-run.json", "user://mage-trial-run.json", "user://class-prototype-run.json", "user://emberpack-run.json"]
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
	return {"items": run.items.duplicate(true), "sources": run.sources.duplicate(true), "gold": run.gold, "hp": run.hp,
		"uid": run._next_uid, "discarded": run.discarded_materials.duplicate(true), "phase": run.phase}

func _fingerprints() -> Dictionary:
	var result := {}
	for path in PLAYER_PATHS:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return result

func _recipe(kind: String) -> Dictionary:
	for recipe in Catalog.recipes_for("mage"):
		if recipe.result == kind:
			return recipe
	return {}

func _weave(run: RefCounted, kind: String) -> void:
	var first := 0 if kind == "solar_lance" else 1
	var second := 0 if kind == "solar_lance" else 2
	check(run.move(3, Vector2i(3, 1)).ok, kind + " moves the focus to leave six cells free")
	check(run.acquire(first, Vector2i.ZERO).ok, kind + " creates the actual base spell")
	var recipe := _recipe(kind)
	var before := _state(run)
	var choice: Dictionary = Guide.choose(run, recipe)
	check(Guide.availability(run, recipe).available and choice.ok and choice.preview.ok and _state(run) == before, kind + " becomes discoverable without consuming ingredients")
	check(run.acquire(second, Vector2i.ZERO).ok, kind + " weaves the second element normally")
	check(run.item_by_uid(1).kind == kind and run.item_by_uid(1).pos == Vector2i.ZERO, kind + " occupies the intended target location")

func _model(kind: String) -> void:
	var run := Run.new()
	run.new_run("mage")
	var recipe := _recipe(kind)
	check(not recipe.is_empty() and not Guide.availability(run, recipe).available, kind + " requires its base spell first")
	var first := 0 if kind == "solar_lance" else 1
	var second := 0 if kind == "solar_lance" else 2
	check(run.acquire(first, Vector2i.ZERO).ok, kind + " blocked fixture creates its base")
	var before := _state(run)
	var rejected: Dictionary = run.acquire(second, Vector2i.ZERO)
	check(not rejected.ok and _state(run) == before, kind + " blocked six-cell upgrade consumes nothing")
	run.new_run("mage")
	_weave(run, kind)
	var action: Dictionary = run.get_combat_config().actions.filter(func(a: Dictionary): return a.kind == kind)[0]
	check(action.support_bonus == 2 and action.damage == int(Catalog.definition(kind).damage) + 2, kind + " receives directional support on each hit")
	var battle := Battle.new()
	check(battle.start(run.get_combat_config(), Campaign.encounter(0)).ok, kind + " starts a real fight")
	var hits := battle.tick(float(action.warmup)).filter(func(e: Dictionary): return e.get("source_kind") == kind and e.type != "charge")
	check(hits.size() == int(action.hits), kind + " produces its declared real hit count")
	var art: Dictionary = Art.icon(kind)
	check(not art.is_empty() and Rect2(art.region).encloses(Rect2(art.source_rect).grow(1)), kind + " icon is separate and not cropped")
	var trial_file := "res://.tools/test-saves/advanced-trial-%s-%d.json" % [kind, Time.get_ticks_usec()]
	check(ClassSave.save_run(run, trial_file).ok, kind + " satisfies the old trial material ledger")
	var trial_copy := Run.new()
	check(ClassSave.load_run(trial_copy, trial_file).ok and _state(trial_copy) == _state(run), kind + " survives trial checkpoint roundtrip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(trial_file))
	var campaign_run := Run.new()
	campaign_run.new_run("mage")
	campaign_run.sources.append_array(Campaign.shop_sources())
	_weave(campaign_run, kind)
	var campaign_file := "res://.tools/test-saves/advanced-campaign-%s-%d.json" % [kind, Time.get_ticks_usec()]
	check(CampaignSave.save_run(campaign_run, 0, campaign_file).ok, kind + " satisfies the campaign material ledger")
	var campaign_copy := Run.new()
	check(CampaignSave.load_run(campaign_copy, campaign_file).ok and _state(campaign_copy) == _state(campaign_run), kind + " survives campaign checkpoint roundtrip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(campaign_file))

func _run() -> void:
	var saves := _fingerprints()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_model("solar_lance")
	_model("frost_orbit")
	_campaign_build("solar_lance")
	_campaign_build("frost_orbit")
	await _integration("solar_lance")
	await _integration("frost_orbit")
	check(_fingerprints() == saves, "Actual player saves are unchanged")
	print("Mage advanced spells: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _campaign_build(kind: String) -> void:
	var run := Run.new()
	run.new_run("mage")
	_weave(run, kind)
	if kind == "solar_lance":
		check(run.acquire(1, Vector2i(3, 2)).ok and run.acquire(2, Vector2i(3, 2)).ok, "Solar build adds a legal water/wind companion")
	else:
		check(run.acquire(0, Vector2i(0, 2)).ok, "Frost build adds a legal fire companion")
	for stage in range(5):
		var battle := Battle.new()
		check(battle.start(run.get_combat_config(), Campaign.encounter(stage)).ok, kind + " build starts stage %d" % (stage + 1))
		battle.tick(Battle.TIME_LIMIT)
		print("Advanced %s stage %d: %s HP %d time %.2f" % [kind, stage + 1, battle.phase, battle.hp, battle.battle_time])
		check(battle.phase == "won", kind + " build beats stage %d with the initial finite elements" % (stage + 1))

func _integration(kind: String) -> void:
	root.size = Vector2i(1440, 960)
	var ui = load("res://scenes/mage_campaign.tscn").instantiate()
	ui.persistence_enabled = false
	root.add_child(ui)
	for _i in range(4): await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	if kind == "solar_lance":
		_win_first_battle(ui)
	var first := 0 if kind == "solar_lance" else 1
	var index := 10 if kind == "solar_lance" else 11
	ui._on_drop({"origin": "bag", "uid": 3}, Vector2i(3, 1))
	ui._on_drop({"origin": "source", "index": first}, Vector2i.ZERO)
	ui._open_recipe_book()
	check(ui.recipe_overlay.visible and not ui.recipe_cards[index].disabled, kind + " card unlocks after its base spell")
	ui.recipe_cards[index].pressed.emit()
	check(not ui.recipe_overlay.visible and not ui.held.is_empty(), kind + " recipe card selects the next element")
	ui._on_cell_selected(Vector2i.ZERO)
	check(ui.run.item_by_uid(1).kind == kind, kind + " is crafted through ordinary UI")
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT.path_join(kind + "-prepare.png")) == OK, kind + " prepared board captured")
	var reference := Battle.new()
	check(reference.start(ui.run.get_combat_config(), ui.encounter_id).ok, kind + " independent reference starts")
	ui._start_battle()
	var seen_effect := false
	var seen_release := false
	while ui.battle.phase == "battle" and ui.battle.battle_time < 5.0:
		ui._process(0.05)
		reference.tick(0.05)
		ui.arena._process(0.05)
		var layout: Dictionary = ui.arena.get_art_layout()
		for cast: Dictionary in layout.spell_casts:
			if cast.kind == kind and cast.phase == "flight" and float(cast.remaining) <= 0.12 and layout.motion_clip == ("mage-swing" if kind == "solar_lance" else "mage-gesture") and not seen_release:
				seen_release = true
				await process_frame
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(OUTPUT.path_join(kind + "-flight.png")) == OK, kind + " projectile flight captured")
		for effect: Dictionary in layout.spell_effects:
			if effect.kind == kind and float(effect.age) >= 0.1 and not seen_effect:
				seen_effect = true
				await process_frame
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(OUTPUT.path_join(kind + "-impact.png")) == OK, kind + " impact captured")
	check(seen_release and seen_effect, kind + " uses the intended mage animation and visible impact")
	check(ui.battle.get_summary() == reference.get_summary(), kind + " presentation preserves actual combat")
	ui._restore_before_battle()
	ui._new_class("mage")
	if kind == "solar_lance":
		_win_first_battle(ui)
	ui._on_drop({"origin": "bag", "uid": 3}, Vector2i(3, 1))
	ui._on_drop({"origin": "source", "index": first}, Vector2i.ZERO)
	var second := 6 if kind == "solar_lance" else 2
	ui._on_drop({"origin": "source", "index": second}, Vector2i(3, 2))
	var before_owned := _state(ui.run)
	var material: Dictionary = ui.run.item_at(Vector2i(3, 2))
	check(not material.is_empty(), kind + " second ingredient is placed on the board")
	if not material.is_empty():
		ui._on_drop({"origin": "bag", "uid": int(material.uid)}, Vector2i.ZERO)
		check(ui.run.item_by_uid(1).kind == kind and not ui.undo_button.disabled, kind + " can be woven from two owned ingredients and undone")
		ui._undo_placement()
		check(_state(ui.run) == before_owned, kind + " owned merge undo restores both ingredients without refunding stock")
	ui.queue_free()
	await process_frame

func _win_first_battle(ui: Control) -> void:
	ui._start_battle()
	while ui.battle.phase == "battle":
		ui._process(0.1)
		ui.arena._process(0.1)
	check(ui.battle.phase == "won", "Solar integration earns its paid element through the opening battle")
	ui._primary_action()
	check(ui.campaign_stage == 1 and ui.run.gold == 4, "Solar integration starts from the real second-stage reward")
