extends SceneTree
## Additive mage content: legal material ledger, enemy cadence and real wards.

const Run = preload("res://scripts/classes/class_run.gd")
const Catalog = preload("res://scripts/classes/class_catalog.gd")
const Battle = preload("res://scripts/classes/class_battle.gd")
const Save = preload("res://scripts/classes/class_save.gd")
const Encounters = preload("res://scripts/classes/mage_encounters.gd")
const Art = preload("res://scripts/classes/mage_art.gd")
const Feedback = preload("res://scripts/classes/class_feedback.gd")
const Shield = preload("res://scripts/classes/mage_shield.gd")
const PLAYER_PATHS := ["user://mage-trial-run.json", "user://class-prototype-run.json", "user://emberpack-run.json"]
const OUTPUT := "res://.tools/mage-expansion-review"
var checks := 0
var failures := 0
var ui: Control
var results: Array[Dictionary] = []
var geometry: Array[Dictionary] = []
var shield_pixels: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _fingerprint(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func _state(run: RefCounted) -> Dictionary:
	return {"items": run.items.duplicate(true), "sources": run.sources.duplicate(true), "uid": run._next_uid, "discarded": run.discarded_materials.duplicate(true), "gold": run.gold}

func _weave(run: RefCounted, kind: String) -> void:
	var actions: Array = []
	match kind:
		"frost_bolt": actions = [[1, Vector2i.ZERO]]
		"gale_blades": actions = [[2, Vector2i.ZERO]]
		"steam_burst": actions = [[0, Vector2i(3, 1)], [1, Vector2i(3, 1)]]
		"ember_tornado": actions = [[0, Vector2i(3, 1)], [2, Vector2i(3, 1)]]
		"frost_gale": actions = [[1, Vector2i.ZERO], [2, Vector2i(0, 2)]]
		"steam_tornado":
			check(run.discard(1).ok and run.discard(2).ok, "Wide spell fixture clears space by legal recorded discards")
			actions = [[0, Vector2i(3, 1)], [1, Vector2i(3, 1)], [0, Vector2i.ZERO], [2, Vector2i.ZERO]]
		_: actions = [[0, Vector2i.ZERO], [1, Vector2i(3, 2)], [2, Vector2i(3, 2)]]
	for action in actions:
		check(run.acquire(action[0], action[1]).ok, kind + " fixture uses legal finite acquisition/merge")

func _recipes_and_saves() -> void:
	var recipes: Array = Catalog.recipes_for("mage")
	check(recipes.size() == 6, "Six binary recipes cover the four available mage ingredient kinds")
	var run := Run.new()
	run.new_run("mage")
	for recipe in recipes:
		check(run.get_merge_result({"kind": recipe.first}, {"kind": recipe.second}) == recipe.result and run.get_merge_result({"kind": recipe.second}, {"kind": recipe.first}) == recipe.result, str(recipe.result) + " recipe is symmetric and stable")
	for kind: String in Art.EXTRA_ICONS:
		run.new_run("mage")
		_weave(run, kind)
		var found := false
		for item: Dictionary in run.items:
			found = found or item.kind == kind
		check(found, kind + " becomes a real placed spell, not just a recipe label")
		var checkpoint := "res://.tools/test-saves/mage-expansion-" + kind + ".json"
		check(Save.save_run(run, checkpoint).ok, kind + " satisfies exact raw-material conservation")
		var copy := Run.new()
		check(Save.load_run(copy, checkpoint).ok and _state(copy) == _state(run) and copy.get_combat_config() == run.get_combat_config(), kind + " roundtrip keeps materials, UID, footprint and combat")
		Save.reset_prototype(checkpoint)
		var icon := Art.icon(kind)
		check(not icon.is_empty() and Rect2(icon.region).encloses(icon.source_rect), kind + " has an independent complete icon region")
		check(Rect2(icon.region).encloses(Rect2(icon.source_rect).grow(1)), kind + " keeps a transparent margin instead of clipping an adjacent row's icon")
	run.new_run("mage")
	check(run.acquire(0, Vector2i(3, 2)).ok, "Material can be placed where a tall product cannot fit")
	var before := _state(run)
	var preview := run.preview_placement({"origin": "source", "index": 2}, Vector2i(3, 2))
	check(not preview.ok and _state(run) == before, "Blocked six-cell vortex preview preserves stock and material ledger")
	preview = run.preview_placement({"origin": "source", "index": 2, "rotated": true}, Vector2i(3, 2))
	check(preview.ok and preview.size == Vector2i(3, 2) and _state(run) == before, "Rotation makes the same six-cell product legal without spending on preview")
	check(run.acquire(2, Vector2i(3, 2), true).ok and run.get_combat_config() == preview.combat, "Rotated vortex applies the exact preview transaction")

func _enemy_rules() -> void:
	var run := Run.new()
	run.new_run("mage")
	var config: Dictionary = run.get_combat_config()
	for id in Encounters.IDS:
		var battle := Battle.new()
		check(battle.start(config, id).ok, id + " accepts the same mage preparation")
		var enemy := Encounters.definition(id)
		var events: Array = battle.tick(float(enemy.interval) - 0.05)
		var incoming: Array = events.filter(func(event: Dictionary): return event.type == "enemy_attack")
		check(incoming.is_empty(), id + " anticipation cannot deal early damage")
		events = battle.tick(0.05)
		incoming = events.filter(func(event: Dictionary): return event.type == "enemy_attack")
		check(incoming.size() == int(enemy.hits), id + " emits the promised actual hit count on its first attack")
		var blocked := 0
		var damage := 0
		for event in incoming:
			blocked += int(event.armor_mitigated)
			damage += int(event.amount)
		check(blocked == int(enemy.hits) * 2 and damage == int(enemy.hits) * (int(enemy.damage) - 2), id + " ward mitigates each actual segment")
		var original: Dictionary = battle.get_summary()
		var timing: Dictionary = battle.get_presentation_timing()
		check(not battle.start(config, "missing").ok and battle.get_summary() == original and battle.get_presentation_timing() == timing and battle.encounter_id == id, id + " rejects unknown encounter atomically")
		var copy := battle.get_encounter()
		copy.damage = 999
		check(battle.get_encounter().damage == enemy.damage, id + " presentation query cannot modify enemy rules")
	var lethal_config: Dictionary = config.duplicate(true)
	lethal_config.hp = 1
	var lethal := Battle.new()
	lethal.start(lethal_config, "mirror_moth")
	var emitted: Array = lethal.tick(2.1)
	check(emitted.filter(func(event: Dictionary): return event.type == "enemy_attack").size() == 1 and lethal.phase == "lost" and lethal.hp == 0, "Lethal first moth bolt cancels its second hit instead of damaging below zero")
	var knight := Run.new()
	knight.new_run("knight")
	check(not Battle.new().start(knight.get_combat_config(), "mirror_moth").ok, "Mage encounter expansion does not silently alter the knight entry")

func _shield_model() -> void:
	check(Shield.visible_shields([]).is_empty(), "No incoming event means no shield flash")
	var model := Feedback.new()
	model.show_event({"event_id": 1, "time": 1.8, "type": "enemy_attack", "target": "hero", "source_uid": 0, "source_kind": "enemy", "amount": 6, "raw_amount": 8, "armor_mitigated": 2})
	var shields := Shield.visible_shields(model.numbers)
	check(shields.size() == 1 and shields[0].absorbed == 2 and shields[0].hits == 1, "A real mitigation event reveals the ward and exact blocked amount")
	model.show_event({"event_id": 1, "time": 1.8, "type": "enemy_attack", "target": "hero", "amount": 6, "armor_mitigated": 2})
	check(Shield.visible_shields(model.numbers)[0].absorbed == 2, "Duplicate event cannot flash or count the ward twice")
	model.advance(0.47)
	check(Shield.visible_shields(model.numbers).is_empty(), "Ward flash expires while damage number may remain")
	check(Shield.visible_shields([{"target": "hero", "armor": 0, "age": 0.0, "hits": 1}]).is_empty(), "Unprotected incoming damage never shows a magical shield")
	for id in ["mirror_moth", "thorn_golem"]:
		var art := Art.enemy(id)
		check(art.frames.size() == 4, id + " has four dedicated runtime poses")
		for frame in art.frames:
			check(Rect2(frame.region).encloses(frame.source_rect) and Rect2(frame.region).has_point(frame.cast_point), id + " pose and manually placed core stay inside its independent source region")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var fingerprints := {}
	for path in PLAYER_PATHS:
		fingerprints[path] = _fingerprint(path)
	_recipes_and_saves()
	_enemy_rules()
	_shield_model()
	root.size = Vector2i(1440, 960)
	ui = load("res://scenes/mage_trial.tscn").instantiate()
	ui.persistence_enabled = false
	root.add_child(ui)
	await process_frame
	await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	for data in [["sentinel", "baseline"], ["mirror_moth", "frost_gale"], ["thorn_golem", "steam_tornado"]]:
		await _native_battle(data[0], data[1])
	for path in PLAYER_PATHS:
		check(_fingerprint(path) == fingerprints[path], "Player file remains untouched: " + path)
	var report := FileAccess.open(OUTPUT.path_join("test-report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "renderer": RenderingServer.get_video_adapter_name(), "results": results, "layouts": geometry, "shield_gpu": shield_pixels}, "\t"))
	report.close()
	print("Mage expansion: %d checks, %d failures" % [checks, failures])
	ui.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _native_battle(id: String, build: String) -> void:
	ui._new_class("mage")
	_weave(ui.run, build)
	ui._select_encounter(id)
	check(ui.encounter_id == id and ui.encounter_selector.selected == Encounters.IDS.find(id), id + " is selected through the native preparation handler")
	for dimensions in [Vector2i(1280, 800), Vector2i(1440, 960), Vector2i(1920, 1080)]:
		root.size = dimensions
		for _frame in range(3):
			await process_frame
		var layout: Dictionary = ui.arena.get_art_layout()
		check(not layout.enemy_placeholder and Rect2(layout.scene_rect).encloses(layout.enemy_rect) and not Rect2(layout.hero_rect).intersects(layout.enemy_rect), id + str(dimensions) + " full enemy silhouette fits a separate standing area")
		check(is_equal_approx(Rect2(layout.enemy_rect).end.y, float(layout.ground_y) - float(Encounters.definition(id).lift)), id + " uses its explicit ground/hover anchor")
		check(Rect2(layout.enemy_rect).has_point(layout.enemy_cast_point), id + " projectile and incoming spell target the visible body/core")
		geometry.append({"encounter_id": id, "viewport": [dimensions.x, dimensions.y], "visuals": ui.arena.get_art_report()})
	root.size = Vector2i(1440, 960)
	await process_frame
	await process_frame
	var reference := Battle.new()
	reference.start(ui.run.get_combat_config(), id)
	ui._start_battle()
	var frozen_id: String = ui.encounter_id
	ui._select_encounter("sentinel" if id != "sentinel" else "mirror_moth")
	check(ui.encounter_id == frozen_id and ui.encounter_selector.disabled, id + " cannot switch enemy mid-battle")
	var saw_shield := false
	var observed_spells := {}
	for step in range(1500):
		if ui.battle.phase != "battle":
			break
		ui._process(0.05)
		reference.tick(0.05 * ui.speed)
		ui.arena._process(0.05)
		var layout: Dictionary = ui.arena.get_art_layout()
		for effect: Dictionary in layout.spell_effects:
			if effect.target == "enemy":
				observed_spells[effect.kind] = true
		if not saw_shield and not layout.shields.is_empty():
			saw_shield = true
			ui._pause()
			var frozen: Dictionary = ui.arena.get_art_report().duplicate(true)
			ui.arena._process(1)
			ui._process(1)
			check(ui.arena.get_art_report() == frozen, id + " pause freezes the real reactive shield and all spells")
			await _shield_readback(id)
			ui._pause()
			ui._speed()
	check(saw_shield and ui.battle.get_summary() == reference.get_summary(), id + " real ward/VFX/pause/2x preserve the independent complete battle result")
	check(ui.battle.phase == "won" and observed_spells.size() >= 2, id + " legal finite build wins with distinct actual spell events")
	results.append({"encounter_id": id, "build": build, "observed_spells": observed_spells.keys(), "summary": ui.battle.get_summary()})
	ui.arena._process(2)
	check(ui.arena.get_art_layout().shields.is_empty(), id + " shield settles after battle end")
	ui._restore_before_battle()
	check(ui.arena.get_art_layout().shields.is_empty() and ui.run.phase == "prepare", id + " preparation restore clears the ward flash")
	check(ui.run.discard(4).ok and ui.run.get_combat_config().armor == 0, "Ward can be legally discarded to remove protection")
	ui.speed = 1
	ui._sync()
	ui._start_battle()
	ui._process(float(Encounters.definition(id).interval))
	check(ui.arena.get_art_layout().shields.is_empty(), id + " incoming attacks with no ward show no false bubble")
	ui._restore_before_battle()

func _shield_readback(id: String) -> void:
	ui.arena.shield_effects_enabled = false
	ui.arena.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	ui.arena.shield_effects_enabled = true
	ui.arena.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()
	var first := before.get_data()
	var second := after.get_data()
	var clip := Rect2i(Rect2(ui.arena.get_global_rect().position + ui.arena.effects_layer.position, ui.arena.effects_layer.size))
	var inside := 0
	var outside := 0
	for y in after.get_height():
		for x in after.get_width():
			var offset := (y * after.get_width() + x) * 4
			if first[offset] != second[offset] or first[offset + 1] != second[offset + 1] or first[offset + 2] != second[offset + 2]:
				if clip.has_point(Vector2i(x, y)): inside += 1
				else: outside += 1
	check(inside > 300 and outside == 0, id + " actual GPU shield changes stage pixels and leaves HUD/board untouched")
	after.save_png(OUTPUT.path_join("shield-" + id + ".png"))
	shield_pixels.append({"encounter_id": id, "changed_inside": inside, "changed_outside": outside})
