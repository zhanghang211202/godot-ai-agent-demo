extends SceneTree
## Five real battles, finite rewards, normal board operations, no player saves.

const Catalog = preload("res://scripts/classes/class_catalog.gd")
const Run = preload("res://scripts/classes/class_run.gd")
const Battle = preload("res://scripts/classes/class_battle.gd")
const Save = preload("res://scripts/classes/class_save.gd")
const Guide = preload("res://scripts/classes/mage_recipe_guide.gd")
const Campaign = preload("res://scripts/classes/mage_campaign.gd")
const Art = preload("res://scripts/classes/mage_art.gd")
const Feedback = preload("res://scripts/classes/class_feedback.gd")
const Effects = preload("res://scripts/classes/mage_effects.gd")
const OUTPUT := "res://.tools/mage-campaign-review"
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

func _same_elements() -> void:
	var recipes := Catalog.recipes_for("mage")
	check(recipes.size() == 14, "Twelve spell recipes, one wind support and one familiar contract are available")
	for pair in [["solar_crown", 0], ["glacier_prism", 1], ["storm_orbit", 2], ["arcane_nova", -1]]:
		var run := Run.new()
		run.new_run("mage")
		var product: String = pair[0]
		var recipe: Dictionary = recipes.filter(func(r: Dictionary): return r.result == product)[0]
		check(Guide.availability(run, recipe).available, product + " requires two real ingredients")
		if int(pair[1]) >= 0:
			check(run.acquire(pair[1], Vector2i(3, 1)).ok and run.acquire(pair[1], Vector2i(3, 1)).ok, product + " weaves through ordinary source transactions")
		else:
			check(run.move(2, Vector2i.ZERO).ok, product + " weaves the two owned sparks")
		check(run.items.any(func(item: Dictionary): return item.kind == product), product + " is on the board")
		var art: Dictionary = Art.icon(product)
		check(not art.is_empty() and Rect2(art.region).encloses(Rect2(art.source_rect).grow(1)), product + " has a separate complete icon")
		var combat := Battle.new()
		check(combat.start(run.get_combat_config()).ok, product + " starts a legal battle")
		var events := combat.tick(float(Catalog.definition(product).warmup))
		var hits := events.filter(func(e: Dictionary): return e.get("source_kind") == product and e.get("target") == "enemy" and e.type != "charge")
		check(hits.size() == int(Catalog.definition(product).hits), product + " emits its declared real hit count")
		var feedback := Feedback.new()
		for event: Dictionary in hits: feedback.show_event(event)
		check(Effects.visible_effects(feedback.numbers).any(func(e: Dictionary): return e.kind == product and e.hits == hits.size()), product + " produces an impact matching real hits")
		var checkpoint := "res://.tools/test-saves/campaign-recipe-" + product + ".json"
		check(Save.save_run(run, checkpoint).ok, product + " preserves the old checkpoint material ledger")
		var copy := Run.new()
		check(Save.load_run(copy, checkpoint).ok and copy.get_combat_config() == run.get_combat_config(), product + " roundtrips through old save format")
		Save.reset_prototype(checkpoint)
	var limited := Run.new()
	limited.new_run("mage")
	var choice: Dictionary = Guide.choose(limited, recipes[6])
	check(choice.ok and choice.needs_placement and choice.held.index == 0, "Same-element recipe guides the first ingredient without spending it")
	check(limited.acquire(0, Vector2i(3, 1)).ok, "The first same-element ingredient can be placed")
	choice = Guide.choose(limited, recipes[6])
	check(choice.ok and not choice.needs_placement and choice.preview.ok and choice.product == "solar_crown", "The guide identifies the second identical ingredient and legal target")
	limited.new_run("mage")
	limited.discard(2)
	var nova: Dictionary = recipes[9]
	check(not Guide.availability(limited, nova).available, "One remaining spark is insufficient for a two-spark recipe")
	limited.new_run("mage")
	limited.sources.append_array(Campaign.shop_sources())
	check(limited.acquire(0, Vector2i(3, 1)).ok and limited.acquire(0, Vector2i(3, 1)).ok, "Budget fixture uses both free fire elements normally")
	limited.gold = 2
	var blocked: Dictionary = Guide.availability(limited, recipes[6])
	check(not blocked.available and blocked.insufficient_funds and blocked.required_cost == 4, "Two paid ingredients require their combined residue cost")

func _boss_pattern() -> void:
	var boss_art: Dictionary = Art.enemy("moon_crowned")
	check(boss_art.frames.size() == 4, "Boss has four dedicated animation frames")
	for frame: Dictionary in boss_art.frames:
		check(Rect2(frame.region).encloses(Rect2(frame.source_rect).grow(1)) and Rect2(frame.source_rect).has_point(frame.cast_point), "Boss frame is uncropped and its cast point remains on the sprite")
	var run := Run.new()
	run.new_run("mage")
	var config: Dictionary = run.get_combat_config()
	for action: Dictionary in config.actions: action.damage = 1
	var boss := Battle.new()
	check(boss.start(config, "moon_crowned").ok, "Boss encounter starts with valid mage config")
	var events := boss.tick(5.8)
	var incoming := events.filter(func(e: Dictionary): return e.type == "enemy_attack")
	check(incoming.size() == 3 and incoming[0].source_kind == "boss_star" and incoming[1].source_kind == "boss_star" and incoming[2].source_kind == "boss_crash", "Boss alternates a two-hit volley and a charged heavy hit")
	check(is_equal_approx(incoming[0].time, 2.7) and is_equal_approx(incoming[2].time, 5.8), "Boss timings follow the declared pattern")

func _distinct_enemies() -> void:
	var paths: Array[String] = []
	for stage in range(5):
		var art: Dictionary = Art.enemy(Campaign.encounter(stage))
		check(not art.is_empty() and art.frames.size() == 4, "Stage %d has four enemy poses" % (stage + 1))
		if art.is_empty():
			continue
		paths.append(str(art.path))
		for frame: Dictionary in art.frames:
			var bounds: Rect2 = frame.source_rect
			check(bounds.has_area() and Rect2(frame.region).encloses(bounds.grow(1) if stage == 3 else bounds), "Stage %d enemy pose fits its atlas cell" % (stage + 1))
	check(paths.size() == 5 and paths.duplicate().reduce(func(acc: Array, path: String):
		if path not in acc: acc.append(path)
		return acc, []).size() == 5, "All five stages have distinct enemy art")
	var run := Run.new()
	run.new_run("mage")
	var config: Dictionary = run.get_combat_config()
	for action: Dictionary in config.actions: action.damage = 1
	var battle := Battle.new()
	check(battle.start(config, "astral_scribe").ok, "Fourth enemy starts its own encounter")
	var incoming := battle.tick(2.4).filter(func(e: Dictionary): return e.type == "enemy_attack")
	check(incoming.size() == 3 and incoming.all(func(e: Dictionary): return e.source_kind == "scribe_rune" and e.amount == 5), "Fourth enemy fires three rune hits reduced separately by ward")
	var feedback := Feedback.new()
	for event: Dictionary in incoming: feedback.show_event(event)
	var effects := Effects.visible_effects(feedback.numbers)
	check(effects.size() == 1 and effects[0].kind == "scribe_rune" and effects[0].hits == 3, "Rune impact reflects the three actual warded hits")
	config.hp = 6
	var lethal := Battle.new()
	check(lethal.start(config, "astral_scribe").ok, "Low-health scribe fixture starts normally")
	feedback.reset()
	for event: Dictionary in lethal.tick(2.4): feedback.show_event(event)
	effects = Effects.visible_effects(feedback.numbers).filter(func(effect: Dictionary): return effect.kind == "scribe_rune")
	check(lethal.phase == "lost" and effects.size() == 1 and effects[0].hits == 2, "Lethal rune impact presents only the two hits that actually occurred")

func _second_build() -> void:
	var run := Run.new()
	run.new_run("mage")
	for action in [[0, Vector2i(3, 1)], [0, Vector2i(3, 1)], [1, Vector2i(5, 1)], [1, Vector2i(5, 1)], [2, Vector2i(1, 2)], [2, Vector2i(1, 2)]]:
		check(run.acquire(action[0], action[1]).ok, "Second build legally weaves repeated elements")
	check(run.items.any(func(i: Dictionary): return i.kind == "solar_crown") and run.items.any(func(i: Dictionary): return i.kind == "glacier_prism") and run.items.any(func(i: Dictionary): return i.kind == "storm_orbit"), "Second build contains three distinct same-element spells")
	for stage in range(5):
		var battle := Battle.new()
		check(battle.start(run.get_combat_config(), Campaign.encounter(stage)).ok, "Second build starts stage %d" % (stage + 1))
		battle.tick(Battle.TIME_LIMIT)
		check(battle.phase == "won", "Second build can beat stage %d with normal health" % (stage + 1))

func _run() -> void:
	var fingerprints := {}
	for path in PLAYER_PATHS:
		fingerprints[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	_same_elements()
	_boss_pattern()
	_distinct_enemies()
	_second_build()
	root.size = Vector2i(1440, 960)
	var ui = load("res://scenes/mage_campaign.tscn").instantiate()
	ui.persistence_enabled = false
	root.add_child(ui)
	for _i in range(4): await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	check(ui.campaign_focus and not ui.persistence_enabled and ui.encounter_id == Campaign.encounter(0) and ui.run.gold == 0, "Campaign opens separately without player checkpoint writes")
	check(ui.source_buttons.size() == 9 and ui.source_buttons[3].disabled and ui.resources_label.text.contains("残滓"), "Free elements and residue condensation are available in one preparation UI")
	ui._rehearse()
	check(not ui._rehearsal_signature.is_empty() and ui.details_content.get_child(0) == ui.summary_label, "The forecast appears first after rehearsal")
	ui._select_source(0)
	check(ui.detail_label.text.contains("火の元素") and ui.detail_label.text.contains("無料で吸収") and ui.detail_icon.visible, "Selecting a free element shows its effect, availability and icon")
	check(not ui._rehearsal_signature.is_empty() and ui.summary_label.get_index() == ui.details_content.get_child_count() - 1 and ui.details_scroll.scroll_vertical == 0, "Selecting a source reveals its details while retaining the forecast below")
	await _capture("source-fire-inspect.png")
	root.size = Vector2i(1280, 800)
	for _i in range(4): await process_frame
	await _capture("source-fire-1280.png")
	root.size = Vector2i(1440, 960)
	for _i in range(4): await process_frame
	var selected_before: Dictionary = ui.held.duplicate(true)
	var inventory_before: Array = ui.run.items.duplicate(true)
	var sources_before: Array = ui.run.sources.duplicate(true)
	check(ui._source_drag(3, Vector2.ZERO) == null and ui.held == selected_before, "Dragging an unaffordable source cannot return a previously selected element")
	check(ui.run.items == inventory_before and ui.run.sources == sources_before and ui.run.gold == 0, "Rejected source dragging does not consume inventory, stock or residue")
	check(ui._source_drag(-1, Vector2.ZERO) == null and ui._source_drag(ui.run.sources.size(), Vector2.ZERO) == null, "Source dragging safely rejects invalid indices")
	var drag: Variant = ui._source_drag(1, Vector2.ZERO)
	check(drag is Dictionary and drag.origin == "source" and drag.index == 1, "An affordable source drag carries the requested material")
	var saved_remaining: int = ui.run.sources[0].remaining
	ui.run.sources[0].remaining = 0
	check(ui._source_drag(0, Vector2.ZERO) == null and ui.held.index == 1, "An exhausted source cannot start a drag or replace the current selection")
	ui.run.sources[0].remaining = saved_remaining
	ui.run.phase = "battle"
	check(ui._source_drag(0, Vector2.ZERO) == null and ui.held.index == 1, "Source dragging is locked during battle")
	ui.run.phase = "prepare"
	ui.run.gold = 4
	ui._select_source(4)
	check(ui.detail_label.text.contains("護符の板") and ui.detail_label.text.contains("4残滓で凝結") and ui.detail_label.text.contains("2 × 1"), "Selecting a paid ward describes its effect, actual price and footprint")
	ui._rotate()
	check(ui.detail_label.text.contains("1 × 2") and ui.run.sources == sources_before and ui.run.items == inventory_before and ui.run.gold == 4, "Rotating the unpurchased ward updates its footprint without consuming resources")
	await _capture("source-ward-rotated.png")
	ui.run.gold = 0
	ui._clear_selection()
	ui._sync()
	check(ui.detail_label.text.contains("月庭の衛兵") and not ui.detail_icon.visible, "Clearing the selection restores the enemy overview")
	for dimensions in [Vector2i(1280, 800), Vector2i(1440, 960), Vector2i(1920, 1080)]:
		root.size = dimensions
		for _i in range(4): await process_frame
		var viewport := Rect2(Vector2.ZERO, Vector2(dimensions))
		check(viewport.encloses(ui.condense_button.get_global_rect()) and viewport.encloses(ui.recipe_button.get_global_rect()) and not ui.condense_button.get_global_rect().intersects(ui.recipe_button.get_global_rect()), str(dimensions) + " recipe and condensation controls are visible and separate")
		check(viewport.encloses(ui.save_button.get_global_rect()) and viewport.encloses(ui.load_button.get_global_rect()) and viewport.encloses(ui.primary_button.get_global_rect()) and not ui.load_button.get_global_rect().intersects(ui.primary_button.get_global_rect()), str(dimensions) + " save and battle controls remain usable")
	root.size = Vector2i(1440, 960)
	for _i in range(4): await process_frame
	check(ui.run.acquire(0, Vector2i.ZERO).ok and ui.run.acquire(1, Vector2i(3, 2)).ok and ui.run.acquire(2, Vector2i(3, 2)).ok, "Five-battle build uses only normal finite acquisition and weaving")
	ui._sync()
	await _capture("stage-1-prepare.png")
	ui.recipe_button.pressed.emit()
	check(ui.recipe_overlay.visible and ui.recipe_cards.size() == 14, "Campaign can inspect all fourteen recipes")
	await _capture("campaign-recipes.png")
	ui._close_recipe_book()
	for stage in range(5):
		check(ui.campaign_stage == stage and ui.encounter_id == Campaign.encounter(stage), "Stage %d selects the intended enemy" % (stage + 1))
		if stage == 3:
			check(ui.arena.get_art_layout().enemy_path.contains("astral-scribe"), "Fourth battle shows its own enemy artwork")
			await _capture("stage-4-prepare.png")
		if stage == 4:
			check(ui.campaign_stage_label.text.contains("BOSS") and ui.arena.get_art_layout().enemy_path.contains("moon-crowned"), "Final battle uses the named boss and dedicated sprite")
			await _capture("boss-prepare.png")
		var before_gold: int = ui.run.gold
		ui.primary_button.pressed.emit()
		check(ui.battle.phase == "battle" and not ui.workspace_panel.visible, "Stage %d starts through the main button" % (stage + 1))
		if stage in [3, 4]:
			var deadline: int = ui.battle._enemy_next_step
			for dimensions in [Vector2i(1280, 800), Vector2i(1440, 960), Vector2i(1920, 1080)]:
				root.size = dimensions
				for _i in range(4): await process_frame
				for frame in range(4):
					ui.arena.feedback.hero_hit = 1.0 if frame == 2 else 0.0
					ui.arena.feedback.enemy_hit = 1.0 if frame == 3 else 0.0
					ui.battle._enemy_next_step = ui.battle._step_index + (1 if frame == 1 else 1000)
					var pose: Dictionary = ui.arena.get_art_layout()
					check(pose.enemy_frame == frame and Rect2(pose.scene_rect).encloses(pose.enemy_rect) and not Rect2(pose.enemy_rect).intersects(pose.hero_rect), str(dimensions) + " stage %d pose %d is contained and distinct" % [stage + 1, frame])
				ui.arena.feedback.hero_hit = 0.0
				ui.arena.feedback.enemy_hit = 0.0
				ui.battle._enemy_next_step = deadline
				if dimensions.x != 1440:
					ui.arena.queue_redraw()
					await _capture(("boss-battle-%d.png" if stage == 4 else "stage-4-battle-%d.png") % dimensions.x)
			root.size = Vector2i(1440, 960)
			for _i in range(4): await process_frame
		var reference := Battle.new()
		reference.start(ui.run.get_combat_config(), ui.encounter_id)
		var boss_effects := {}
		var saw_scribe_rune := false
		while ui.battle.phase == "battle":
			ui._process(0.1)
			ui.arena._process(0.1)
			reference.tick(0.1 * ui.speed)
			if stage == 4:
				for effect: Dictionary in ui.arena.get_art_layout().spell_effects:
					if effect.kind in ["boss_star", "boss_crash"] and not boss_effects.has(effect.kind):
						boss_effects[effect.kind] = true
						await _capture("boss-" + str(effect.kind) + ".png")
			if stage == 3 and not saw_scribe_rune:
				for effect: Dictionary in ui.arena.get_art_layout().spell_effects:
					if effect.kind == "scribe_rune":
						saw_scribe_rune = true
						await _capture("stage-4-scribe-rune.png")
		check(ui.battle.phase == "won" and ui.battle.get_summary() == reference.get_summary(), "Stage %d wins with unchanged independent rules" % (stage + 1))
		print("Campaign stage %d: %s at %.2fs, HP %d" % [stage + 1, ui.battle.phase, ui.battle.battle_time, ui.battle.hp])
		if ui.battle.phase != "won": break
		if stage == 3:
			check(saw_scribe_rune, "Fourth battle renders the real rune attack")
		if stage == 4:
			check(boss_effects.has("boss_star") and boss_effects.has("boss_crash"), "Real boss battle renders both distinct attacks")
		check(ui.run.gold == before_gold + Campaign.REWARDS[stage], "Stage %d drops residue exactly once" % (stage + 1))
		ui._process(1.0)
		check(ui.run.gold == before_gold + Campaign.REWARDS[stage], "Stage %d does not repeat its reward" % (stage + 1))
		if stage == 0:
			check(ui.arena.campaign_reward == Campaign.REWARDS[0], "Victory exposes the actual residue drop")
			await _capture("stage-1-reward.png")
			ui._restore_before_battle()
			check(ui.run.gold == 0 and ui.run.phase == "prepare", "Retry restores the pre-battle residue balance")
			ui._start_battle()
			while ui.battle.phase == "battle":
				ui._process(0.1)
				ui.arena._process(0.1)
			check(ui.battle.phase == "won" and ui.run.gold == Campaign.REWARDS[0], "Replaying a stage cannot duplicate its reward")
		if stage < 4:
			ui.primary_button.pressed.emit()
			check(ui.run.phase == "prepare" and ui.run.hp == ui.run.max_hp and ui.workspace_panel.visible, "Next stage restores HP and returns to preparation")
			if stage == 0:
				check(not ui.source_buttons[3].disabled, "First reward makes the crystal core affordable")
				ui.condense_button.pressed.emit()
				for _i in range(3): await process_frame
				check(ui.source_scroll.scroll_vertical > 0 and ui.source_scroll.get_global_rect().intersects(ui.source_buttons[3].get_global_rect()), "Condense button reveals the purchasable item list")
				await _capture("stage-2-residue.png")
				ui.source_buttons[3].pressed.emit()
				ui._on_cell_selected(Vector2i(2, 2))
				check(ui.run.gold == 0 and ui.run.item_at(Vector2i(2, 2)).kind == "arcane_focus", "Residue is spent once to condense a real support item")
				await _capture("stage-2-condense.png")
			elif stage == 1:
				ui.source_buttons[4].pressed.emit()
				ui._on_cell_selected(Vector2i(4, 1))
				check(ui.run.gold == 0 and ui.run.item_at(Vector2i(4, 1)).kind == "mage_ward", "Second reward can create another ward using board space")
		else:
			check(ui.primary_button.disabled and ui.status_label.text.contains("踏破"), "Boss victory completes the five-battle campaign")
	ui._new_class("mage")
	check(ui.run.discard(1).ok, "Defeat fixture uses a normal discarded spell")
	check(ui.run.discard(4).ok, "Defeat fixture also sacrifices the starting ward")
	ui._start_battle()
	while ui.battle.phase == "battle":
		ui._process(0.1)
		ui.arena._process(0.1)
	check(ui.battle.phase == "lost" and ui.run.gold == 0 and ui.primary_button.disabled, "A defeat grants no residue and cannot advance")
	ui._restore_before_battle()
	check(ui.campaign_stage == 0 and ui.run.phase == "prepare" and ui.run.gold == 0 and ui.run.item_by_uid(1).is_empty(), "Retry restores the same legally prepared build")
	await _render_new_spells(ui)
	for path in fingerprints:
		var after := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
		check(after == fingerprints[path], "Player save is unchanged: " + path)
	ui.queue_free()
	await process_frame
	print("Mage campaign: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _render_new_spells(ui: Control) -> void:
	for pair in [["solar_crown", 0], ["glacier_prism", 1], ["storm_orbit", 2], ["arcane_nova", -1]]:
		ui._new_class("mage")
		var kind: String = pair[0]
		if int(pair[1]) >= 0:
			ui._start_battle()
			while ui.battle.phase == "battle":
				ui._process(0.1)
				ui.arena._process(0.1)
			check(ui.battle.phase == "won", kind + " fixture earns residue in the first battle")
			ui._primary_action()
			check(ui.run.acquire(pair[1], Vector2i(3, 1)).ok and ui.run.acquire(int(pair[1]) + 6, Vector2i(3, 1)).ok, kind + " rendered fixture weaves a free element and an earned paid element")
		else:
			check(ui.run.move(2, Vector2i.ZERO).ok, kind + " rendered fixture uses owned sparks")
		ui._start_battle()
		var found := false
		while ui.battle.phase == "battle" and not found:
			ui._process(0.05)
			ui.arena._process(0.05)
			for effect: Dictionary in ui.arena.get_art_layout().spell_effects:
				if effect.kind == kind:
					found = true
					await _capture("spell-" + kind + ".png")
					break
		check(found, kind + " renders an effect from a real combat event")
		ui._restore_before_battle()

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT.path_join(name)) == OK, "Saved native screenshot: " + name)
