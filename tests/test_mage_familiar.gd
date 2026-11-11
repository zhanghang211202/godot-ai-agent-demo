extends SceneTree
## A real per-contract companion, combat clock, UI and save boundaries.
const Run = preload("res://scripts/classes/class_run.gd")
const Battle = preload("res://scripts/classes/class_battle.gd")
const Catalog = preload("res://scripts/classes/class_catalog.gd")
const Campaign = preload("res://scripts/classes/mage_campaign.gd")
const CampaignSave = preload("res://scripts/classes/mage_campaign_save.gd")
const TrialSave = preload("res://scripts/classes/class_save.gd")
const MageArt = preload("res://scripts/classes/mage_art.gd")
const Timeline = preload("res://scenes/components/mage_cast_timeline.tscn")
const Guide = preload("res://scripts/classes/mage_recipe_guide.gd")
const OUTPUT := "res://.tools/mage-familiar-review"
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

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var hashes := {}
	for path in PLAYER_PATHS:
		hashes[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	_model()
	_crowned_model()
	_wind_model()
	await _timeline()
	await _ui()
	for path in hashes:
		check((FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing") == hashes[path], "Player save unchanged: " + path)
	print("Mage familiar: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _model() -> void:
	var run := Run.new()
	run.new_run("mage")
	var before := _state(run)
	var preview: Dictionary = run.preview_placement({"origin": "source", "index": 1}, Vector2i(2, 1))
	check(preview.ok and preview.item.kind == "moon_familiar" and preview.size == Vector2i(2, 2) and _state(run) == before, "Water and focus preview a four-cell contract without consumption")
	check(run.acquire(1, Vector2i(2, 1)).ok and run.get_combat_config() == preview.combat, "Real weaving matches the contract preview")
	var config: Dictionary = run.get_combat_config()
	var actions: Array = config.actions.filter(func(action: Dictionary): return action.get("summon", false))
	check(actions.size() == 1 and actions[0].uid == 3 and actions[0].damage == 8 and is_equal_approx(actions[0].interval, 2.2), "The equipped contract identifies its own independent attack source")
	var trial := OUTPUT.path_join("trial-%d.json" % Time.get_ticks_usec())
	check(TrialSave.save_run(run, trial).ok, "Single-trial material ledger accepts one focus and one water in the contract")
	var restored := Run.new()
	check(TrialSave.load_run(restored, trial).ok and _state(restored) == _state(run), "Single-trial save restores the exact familiar contract")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(trial))
	config.actions = [actions[0]]
	var battle := Battle.new()
	check(battle.start(config, Campaign.encounter(0)).ok and battle.get_summons().size() == 1, "A contract creates one live combat entity")
	var detached: Array = battle.get_summons()
	detached.clear()
	check(battle.get_summons().size() == 1 and battle.get_summons()[0].uid == 3, "Entity snapshots cannot mutate the live companion")
	var hits: Array = battle.tick(5.3).filter(func(event: Dictionary): return event.type == "familiar_attack")
	check(hits.size() == 3 and hits.all(func(event: Dictionary): return event.source_uid == 3 and event.source_kind == "moon_familiar") and is_equal_approx(hits[0].time, 0.8) and is_equal_approx(hits[1].time, 3.0) and is_equal_approx(hits[2].time, 5.2), "The companion independently attacks at its actual warmup and interval")
	check(battle.get_summary().by_source[0].damage == 24 and battle.get_summary().by_source[0].hits == 3, "Combat recap attributes each hit to the contract UID")
	var frozen := battle.get_summary()
	battle.paused = true
	check(battle.tick(3.0).is_empty() and battle.get_summary() == frozen and battle.get_summons().size() == 1, "Pause freezes the companion and its combat clock")
	battle.paused = false
	var two := config.duplicate(true)
	var second: Dictionary = actions[0].duplicate(true)
	second.uid = 100
	two.actions.append(second)
	check(battle.start(two, Campaign.encounter(0)).ok and battle.get_summons().size() == 2, "Two contracts create two distinct bounded entities")
	var two_hits: Array = battle.tick(0.8).filter(func(event: Dictionary): return event.type == "familiar_attack")
	check(two_hits.size() == 2 and two_hits[0].source_uid != two_hits[1].source_uid, "Simultaneous companions retain separate source IDs")
	var invalid := two.duplicate(true)
	var third: Dictionary = second.duplicate(true)
	third.uid = 101
	invalid.actions.append(third)
	var before_invalid := battle.get_summary()
	check(not battle.start(invalid, Campaign.encounter(0)).ok and battle.get_summary() == before_invalid and battle.get_summons().size() == 2, "A third companion is rejected without changing the running battle")
	var finishing := Battle.new()
	check(finishing.start(config, Campaign.encounter(0)).ok, "Lethal companion fixture starts")
	finishing.enemy_hp = 5
	var final_hits: Array = finishing.tick(0.8).filter(func(event: Dictionary): return event.type == "familiar_attack")
	check(finishing.phase == "won" and final_hits.size() == 1 and final_hits[0].amount == 5 and finishing.get_summons().is_empty(), "A finishing hit is capped by actual HP and clears the live entity")
	var defeated_config := config.duplicate(true)
	defeated_config.hp = 1
	var defeated := Battle.new()
	check(defeated.start(defeated_config, Campaign.encounter(0)).ok, "Low-health mage fixture starts")
	defeated.tick(1.8)
	check(defeated.phase == "lost" and defeated.get_summons().is_empty(), "Mage defeat also ends and clears the companion")
	var art := MageArt.icon("moon_familiar")
	check(not art.is_empty() and Rect2(art.region).encloses(Rect2(art.source_rect).grow(1)), "The companion sprite has a complete separate source region")
	check(Catalog.recipes_for("mage")[13].result == "moon_familiar", "The contract is appended after existing stable recipes")

func _crowned_model() -> void:
	var recipe: Dictionary = Catalog.recipes_for("mage")[14]
	check(recipe.result == "crowned_familiar", "The evolved contract is appended after the existing recipe")
	var campaign := Run.new()
	campaign.new_run("mage")
	campaign.sources = Campaign.initial_sources(2)
	var before := _state(campaign)
	check(not Guide.plan(campaign, recipe).available and _state(campaign) == before, "New campaigns cannot get two water elements before earning residue")
	campaign.gold = 4
	var plan: Dictionary = Guide.plan(campaign, recipe)
	check(plan.available and not plan.direct and plan.required_cost == 2 and plan.prerequisite.result == "moon_familiar", "The guide accounts for both water elements and offers the prerequisite")
	var blocked := Run.new()
	blocked.new_run("mage")
	check(blocked.move(2, Vector2i(4, 2)).ok and blocked.acquire(1, Vector2i(2, 1)).ok, "Place an obstacle beside the basic contract")
	var old_state := _state(blocked)
	var preview: Dictionary = blocked.preview_placement({"origin": "source", "index": 1}, Vector2i(2, 1))
	check(not preview.ok and not blocked.acquire(1, Vector2i(2, 1)).ok and _state(blocked) == old_state, "The six-cell upgrade cannot consume water when its larger footprint is blocked")
	var run := Run.new()
	run.new_run("mage")
	check(run.acquire(1, Vector2i(2, 1)).ok and run.acquire(1, Vector2i(2, 1)).ok, "Two real water elements upgrade the basic contract")
	var actions: Array = run.get_combat_config().actions.filter(func(action: Dictionary): return action.get("summon", false))
	check(actions.size() == 1 and actions[0].kind == "crowned_familiar" and actions[0].uid == 3 and actions[0].damage == 6 and actions[0].hits == 2 and is_equal_approx(actions[0].interval, 2.6), "The upgraded contract has one entity with a two-hit attack")
	var path := OUTPUT.path_join("crowned-trial-%d.json" % Time.get_ticks_usec())
	check(TrialSave.save_run(run, path).ok, "The upgraded raw-material ledger saves")
	var restored := Run.new()
	check(TrialSave.load_run(restored, path).ok and _state(restored) == _state(run), "The upgraded contract restores with its water and UID")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var config: Dictionary = run.get_combat_config()
	config.actions = actions
	var battle := Battle.new()
	check(battle.start(config, Campaign.encounter(0)).ok and battle.get_summons().size() == 1 and battle.get_summons()[0].kind == "crowned_familiar", "The evolved contract creates one distinct live companion")
	var hits: Array = battle.tick(3.7).filter(func(event: Dictionary): return event.type == "familiar_attack")
	check(hits.size() == 4 and hits.all(func(event: Dictionary): return event.amount == 6 and event.source_uid == 3) and is_equal_approx(hits[0].time, 1.1) and is_equal_approx(hits[2].time, 3.7), "Two actual hits share a source and repeat on the upgraded clock")
	var finishing := Battle.new()
	check(finishing.start(config, Campaign.encounter(0)).ok, "Upgraded lethal fixture starts")
	finishing.enemy_hp = 5
	var lethal: Array = finishing.tick(1.1).filter(func(event: Dictionary): return event.type == "familiar_attack")
	check(finishing.phase == "won" and lethal.size() == 1 and lethal[0].amount == 5 and finishing.get_summons().is_empty(), "Lethal first hit does not invent a second hit or leave a companion")
	var art := MageArt.icon("crowned_familiar")
	check(not art.is_empty() and Rect2(art.region).encloses(Rect2(art.source_rect).grow(1)), "The evolved companion has a complete independent sprite")

func _wind_model() -> void:
	var run := Run.new()
	run.new_run("mage")
	run.campaign_rules_version = 2
	run.sources = Campaign.initial_sources(2)
	var recipe: Dictionary = Catalog.recipes_for("mage")[15]
	var plan: Dictionary = Guide.plan(run, recipe)
	check(recipe.result == "wind_familiar" and plan.available and not plan.direct and plan.required_cost == 0 and plan.prerequisite.result == "moon_familiar", "The wind route uses only one initial water and one initial wind")
	check(run.acquire(1, Vector2i(2, 1)).ok, "First weave the regular familiar")
	var before := _state(run)
	var preview: Dictionary = run.preview_placement({"origin": "source", "index": 2}, Vector2i(2, 1))
	check(preview.ok and preview.item.kind == "wind_familiar" and preview.size == Vector2i(2, 2) and _state(run) == before, "Wind upgrade previews the compact contract without consuming resources")
	check(run.acquire(2, Vector2i(2, 1)).ok and run.get_combat_config() == preview.combat, "Actual wind weaving agrees with the preview")
	var actions: Array = run.get_combat_config().actions.filter(func(action: Dictionary): return action.get("summon", false))
	check(actions.size() == 1 and actions[0].kind == "wind_familiar" and actions[0].damage == 6 and actions[0].hits == 1 and is_equal_approx(actions[0].warmup, 0.6) and is_equal_approx(actions[0].interval, 1.5), "The fast companion retains one UID and its distinct attack clock")
	var path := OUTPUT.path_join("wind-trial-%d.json" % Time.get_ticks_usec())
	check(CampaignSave.save_run(run, 0, path).ok, "The wind contract saves its exact campaign raw ingredients")
	var restored := Run.new()
	check(CampaignSave.load_run(restored, path).ok and _state(restored) == _state(run), "The wind contract restores its original UID and elemental ledger")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var config: Dictionary = run.get_combat_config()
	config.actions = actions
	var battle := Battle.new()
	check(battle.start(config, Campaign.encounter(0)).ok and battle.get_summons()[0].kind == "wind_familiar", "A wind contract creates one fast companion")
	var hits: Array = battle.tick(3.6).filter(func(event: Dictionary): return event.type == "familiar_attack")
	check(hits.size() == 3 and hits.all(func(event: Dictionary): return event.amount == 6 and event.source_uid == 3) and is_equal_approx(hits[0].time, 0.6) and is_equal_approx(hits[1].time, 2.1) and is_equal_approx(hits[2].time, 3.6), "Fast companion attacks follow their actual independent clock")
	var icon := MageArt.icon("wind_familiar")
	check(not icon.is_empty() and Rect2(icon.region).encloses(Rect2(icon.source_rect).grow(1)), "Wind familiar has its own complete sprite")

func _timeline() -> void:
	var timeline = Timeline.instantiate()
	root.add_child(timeline)
	await process_frame
	timeline.sync_prediction([{"target": "enemy", "kind": "moon_familiar", "source_uid": 3, "summon": true, "remaining": 0.1}])
	check(timeline.mode == "idle" and timeline.pose == 0, "An approaching familiar shot does not make the mage cast")
	timeline.sync_prediction([{"target": "enemy", "kind": "crowned_familiar", "source_uid": 3, "summon": true, "remaining": 0.1}])
	check(timeline.mode == "idle" and timeline.pose == 0, "The upgraded companion prediction does not animate the mage")
	timeline.sync_prediction([{"target": "enemy", "kind": "wind_familiar", "source_uid": 3, "summon": true, "remaining": 0.1}])
	check(timeline.mode == "idle" and timeline.pose == 0, "The wind companion prediction does not animate the mage")
	timeline.show_event({"type": "familiar_attack", "target": "enemy", "time": 0.8, "source_uid": 3})
	check(timeline.mode == "idle" and timeline.pose == 0, "A familiar hit does not trigger the mage's own AnimationPlayer")
	timeline.queue_free()
	await process_frame

func _ui() -> void:
	root.size = Vector2i(1440, 960)
	var ui = load("res://scenes/mage_campaign.tscn").instantiate()
	ui.persistence_enabled = false
	root.add_child(ui)
	for _i in range(4): await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	ui._open_recipe_book()
	for _i in range(3): await process_frame
	ui.recipe_scroll.ensure_control_visible(ui.recipe_cards[13])
	for _i in range(3): await process_frame
	check(not ui.recipe_cards[13].disabled and ui.recipe_cards[13].text.contains("使い魔"), "The actual recipe book exposes the familiar contract")
	await _capture("recipe.png")
	var before := _state(ui.run)
	ui.recipe_cards[13].pressed.emit()
	check(ui.held.get("origin") == "source" and ui.held.get("index") == 1 and _state(ui.run) == before, "Selecting the contract chooses water without consuming it")
	check(ui.grid.recipe_hints.size() == 1 and ui.grid.recipe_hints.has(3) and ui.grid.recipe_hints[3].product == "moon_familiar", "Guided contract highlights focus only, not the competing ice recipe")
	ui._on_cell_selected(Vector2i(2, 1))
	check(ui.run.item_by_uid(3).kind == "moon_familiar", "Ordinary UI weaving creates the real contract")
	await _capture("prepare.png")
	var prepared := _state(ui.run)
	ui._rehearse()
	check(ui.summary_label.text.contains("月蛾の契約（3列2行）") and _state(ui.run) == prepared, "Rehearsal attributes companion damage to its board position without consuming the contract")
	var path := OUTPUT.path_join("campaign-%d.json" % Time.get_ticks_usec())
	check(CampaignSave.save_run(ui.run, 0, path).ok, "A new campaign can save the familiar with exact materials")
	var restored := Run.new()
	check(CampaignSave.load_run(restored, path).ok and _state(restored) == _state(ui.run), "The familiar contract reloads without extra summons or ingredients")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var reference := Battle.new()
	check(reference.start(ui.run.get_combat_config(), ui.encounter_id).ok, "Independent familiar battle starts")
	ui._start_battle()
	check(ui.battle.get_summons().size() == 1 and ui.arena.get_art_layout().familiars.size() == 1, "The actual battle displays its one live companion")
	for dimensions in [Vector2i(1280, 800), Vector2i(1440, 960), Vector2i(1920, 1080)]:
		root.size = dimensions
		for _i in range(4): await process_frame
		var layout: Dictionary = ui.arena.get_art_layout()
		var rect: Rect2 = layout.familiars[0].rect
		check(Rect2(layout.scene_rect).encloses(rect) and not rect.intersects(layout.hero_rect) and not rect.intersects(layout.enemy_rect), str(dimensions) + " familiar is inside the battle and separated from both actors")
		await _capture("battle-%d.png" % dimensions.x)
	root.size = Vector2i(1440, 960)
	for _i in range(4): await process_frame
	var saw_flight := false
	var checked_pause := false
	var frames_path := OUTPUT.path_join("frames")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(frames_path))
	var recorded_frames := 0
	while ui.battle.phase == "battle" and ui.battle.battle_time < 2.0:
		ui._process(0.05)
		ui.arena._process(0.05)
		reference.tick(0.05)
		if ui.battle.battle_time <= 1.2 + 0.00001:
			await process_frame
			await RenderingServer.frame_post_draw
			if root.get_texture().get_image().save_png(frames_path.path_join("frame-%02d.png" % recorded_frames)) == OK:
				recorded_frames += 1
		for cast: Dictionary in ui.arena.get_art_layout().spell_casts:
			if cast.kind == "moon_familiar" and cast.phase == "flight" and not saw_flight:
				saw_flight = true
				await _capture("familiar-flight.png")
				var frozen: Dictionary = ui.arena.get_art_report().duplicate(true)
				var saved_summary: Dictionary = ui.battle.get_summary()
				ui._pause()
				ui._process(0.5)
				ui.arena._process(0.5)
				checked_pause = ui.arena.get_art_report() == frozen and ui.battle.get_summary() == saved_summary
				ui._pause()
	check(saw_flight and ui.battle.get_summary() == reference.get_summary(), "A real familiar projectile is shown without changing combat results")
	check(recorded_frames == 24, "Recorded 24 actual battle frames at controlled 50 ms intervals")
	check(checked_pause, "Pausing real combat freezes the familiar's position, flight and combat state")
	check(ui.battle.hp < ui.battle.max_hp and ui.battle.get_summons().size() == 1, "Enemy attacks target the mage and do not remove an active familiar")
	ui._restore_before_battle()
	check(ui.arena.get_art_layout().familiars.is_empty(), "Returning to preparation removes the battle entity")
	check(ui.run.discard(1).ok and ui.run.discard(2).ok, "Isolated companion fixture removes both mage spell sources through normal rules")
	ui._sync()
	ui._start_battle()
	var mage_stayed_idle := true
	while ui.battle.phase == "battle" and ui.battle.battle_time < 0.9:
		ui._process(0.05)
		ui.arena._process(0.05)
		mage_stayed_idle = mage_stayed_idle and ui.arena.mage_cast_timeline.mode == "idle" and ui.arena.mage_cast_timeline.pose == 0
	check(mage_stayed_idle and ui.battle.get_summary().by_source[0].damage == 8, "A real companion-only shot deals damage without moving the mage's cast AnimationPlayer")
	ui.queue_free()
	await process_frame

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT.path_join(name)) == OK, "Captured actual UI: " + name)
