extends SceneTree
## Mage-only native slice, preview transactions and read-only timing.

const Run = preload("res://scripts/classes/class_run.gd")
const Battle = preload("res://scripts/classes/class_battle.gd")
const Save = preload("res://scripts/classes/class_save.gd")
const Art = preload("res://scripts/classes/mage_art.gd")
const Effects = preload("res://scripts/classes/mage_effects.gd")
const CHECKPOINT := "res://.tools/test-saves/mage-trial.json"
const PLAYER_PATHS := ["user://mage-trial-run.json", "user://class-prototype-run.json", "user://emberpack-run.json"]
var checks := 0
var failures := 0
var ui: Control
var layouts: Array[Dictionary] = []
var observed_states: Dictionary = {}
var observed_effects: Dictionary = {}
var layout_comparison: Dictionary = {}

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
	return {"class": run.class_id, "phase": run.phase, "items": run.items.duplicate(true), "sources": run.sources.duplicate(true), "gold": run.gold, "hp": run.hp, "uid": run._next_uid, "discarded": run.discarded_materials.duplicate(true)}

func _run() -> void:
	var fingerprints := {}
	for path in PLAYER_PATHS:
		fingerprints[path] = _fingerprint(path)
	_previews()
	_assets()
	_effect_model()
	root.size = Vector2i(1440, 960)
	ui = load("res://scenes/mage_trial.tscn").instantiate()
	check(ui.mage_focus and ui.checkpoint_path == "user://mage-trial-run.json", "Mage scene chooses a separate checkpoint by default")
	ui.persistence_enabled = false
	ui.checkpoint_path = CHECKPOINT
	root.add_child(ui)
	await process_frame
	await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	check(ui.run.class_id == "mage" and ui.class_buttons.keys() == ["mage"], "Focused entry exposes only the mage restart")
	var before := _state(ui.run)
	ui._new_class("knight")
	check(_state(ui.run) == before, "Focused entry cannot create a knight run")
	ui._select_source(0)
	ui.grid.hover_cell = Vector2i.ZERO
	ui.grid.update_preview()
	check(ui.preview_label.visible and ui.preview_label.text.contains("焰爆法印") and ui.preview_label.text.contains("20 × 1"), "Hover shows real product and support-adjusted damage")
	check(_state(ui.run) == before, "Native hover preview consumes no source or UID")
	ui._clear_selection()
	for action in [[0, Vector2i.ZERO], [1, Vector2i(3, 2)], [2, Vector2i(3, 2)]]:
		check(ui.run.acquire(action[0], action[1]).ok, "Runtime fixture uses legal finite element acquisition")
	ui._sync()
	check(ui.detail_label.text.contains("协同+2/段") and ui.detail_label.text.contains("每段承伤6"), "Preparation explains actual synergy and per-hit incoming damage")
	await _geometry()
	_live_battle()
	_compare_layouts()
	_checkpoints()
	for path in PLAYER_PATHS:
		check(_fingerprint(path) == fingerprints[path], "Player file remains untouched: " + path)
	Save.reset_prototype(CHECKPOINT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tools/mage-trial-review"))
	var report := FileAccess.open("res://.tools/mage-trial-review/test-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "layouts": layouts, "enemy_frames_observed": observed_states.keys(), "effects_observed": observed_effects.keys(), "layout_comparison": layout_comparison}, "\t"))
	report.close()
	print("Mage trial: %d checks, %d failures" % [checks, failures])
	ui.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _previews() -> void:
	var run := Run.new()
	run.new_run("mage")
	var before := _state(run)
	var preview := run.preview_placement({"origin": "source", "index": 0}, Vector2i.ZERO)
	check(preview.ok and preview.kind == "flame_glyph" and preview.size == Vector2i(2, 2) and preview.support_bonus == 2, "Preview uses real recipe footprint, target anchor and directional support")
	check(_state(run) == before, "Repeated transaction preview is read-only")
	var applied := run.acquire(0, Vector2i.ZERO)
	check(applied.ok and run.get_combat_config() == preview.combat and run.item_by_uid(applied.uid) == preview.item, "Preview and actual acquire produce identical combat/item state")
	var blocked := Run.new()
	blocked.new_run("mage")
	check(blocked.acquire(1, Vector2i(1, 0)).ok, "A legal element can block the larger recipe product")
	before = _state(blocked)
	preview = blocked.preview_placement({"origin": "source", "index": 0}, Vector2i.ZERO)
	check(not preview.ok and preview.message.contains("空间不足") and _state(blocked) == before, "Blocked product preview rejects without spending ingredients")
	check(not blocked.preview_placement({"origin": "source", "index": 99}, Vector2i.ZERO).ok, "Invalid source preview fails safely")
	var owned := Run.new()
	owned.new_run("mage")
	owned.acquire(1, Vector2i(3, 2))
	owned.acquire(2, Vector2i(4, 2))
	var wind: Dictionary = owned.item_at(Vector2i(4, 2))
	before = _state(owned)
	preview = owned.preview_placement({"origin": "bag", "uid": wind.uid}, Vector2i(3, 2))
	check(preview.ok and preview.kind == "tide_lances" and _state(owned) == before, "Owned source inside the product footprint is removed only on the preview copy")
	var merged := owned.move(int(wind.uid), Vector2i(3, 2))
	check(merged.ok and owned.get_combat_config() == preview.combat, "Owned-merge preview agrees with actual transaction")
	before = _state(owned)
	check(not owned.preview_placement({"origin": "bag", "uid": merged.uid, "rotated": true}, Vector2i(3, 2)).ok and _state(owned) == before, "Rotated out-of-bounds preview is atomic")
	preview = owned.preview_placement({"origin": "bag", "uid": merged.uid, "rotated": true}, Vector2i(5, 1))
	check(preview.ok and preview.size == Vector2i(1, 3), "Legal rotated tide preview uses its real vertical footprint")
	owned.phase = "battle"
	check(not owned.preview_placement({"origin": "source", "index": 0}, Vector2i.ZERO).ok, "Preview respects preparation-only operations")

func _assets() -> void:
	for kind in Art.ICONS:
		var icon := Art.icon(kind)
		check(not icon.is_empty() and Rect2(icon.region).encloses(icon.source_rect) and Rect2(icon.source_rect).has_area(), kind + " has an independent contained icon region")
	var enemy := Art.enemy()
	check(enemy.frames.size() == 4, "Sentinel uses a dedicated four-pose atlas")
	for frame in enemy.frames:
		check(Rect2(frame.region).encloses(frame.source_rect) and Rect2(Vector2.ZERO, Vector2(enemy.size)).encloses(frame.region), "Enemy pose stays inside its own source region")

func _effect_model() -> void:
	var effects := Effects.visible_effects([{"kind": "tide_lances", "target": "enemy", "age": 0.0, "hits": 1, "amount": 3}])
	check(effects.size() == 1 and effects[0].hits == 1, "A lethal single-segment tide effect never invents three emitted hits")
	check(Effects.visible_effects([{"kind": "spark", "target": "enemy", "age": 1.0, "hits": 1, "amount": 5}]).is_empty(), "Expired spell effects do not replay")

func _geometry() -> void:
	for dimensions in [Vector2i(1280, 800), Vector2i(1440, 960), Vector2i(1920, 1080)]:
		root.size = dimensions
		for _frame in range(4):
			await process_frame
		var layout: Dictionary = ui.arena.get_art_layout()
		check(not layout.enemy_placeholder and Rect2(layout.scene_rect).encloses(layout.enemy_rect) and not Rect2(layout.enemy_rect).intersects(layout.hero_rect), str(dimensions) + " complete enemy/hero fit separate standing areas")
		check(is_equal_approx(Rect2(layout.enemy_rect).end.y, layout.ground_y), str(dimensions) + " sentinel boots rest on the same floor")
		var rect: Rect2 = ui.grid.cell_rect(Vector2i(2, 1)).grow(-5)
		var visual: Dictionary = ui.grid.item_layout("arcane_focus", rect, false)
		check(minf(visual.icon_rect.size.x, visual.icon_rect.size.y) >= minf(rect.size.x, rect.size.y) * 0.5, str(dimensions) + " single-cell crystal is a readable icon, not a tiny symbol above a label")
		layouts.append({"viewport": [dimensions.x, dimensions.y], "visuals": ui.arena.get_art_report()})

func _live_battle() -> void:
	var reference := Battle.new()
	check(reference.start(ui.run.get_combat_config()).ok, "Independent battle accepts the legal mage configuration")
	ui._start_battle()
	var before: Dictionary = ui.battle.get_summary().duplicate(true)
	var timing: Dictionary = ui.battle.get_presentation_timing()
	timing.sources[1].remaining = 999
	check(ui.battle.get_summary() == before and ui.battle.get_presentation_timing().sources[1].remaining < 2, "Timing query returns isolated data and never advances the engine")
	var pause_checked := false
	for step in range(500):
		if ui.battle.phase != "battle":
			break
		ui._process(0.05)
		reference.tick(0.05 * ui.speed)
		observed_states[ui.arena.enemy_frame()] = true
		for effect in ui.arena.get_art_layout().spell_effects:
			observed_effects[str(effect.kind)] = true
		if not pause_checked and ui.battle.battle_time >= 1.5 and not ui.grid.active_sources.is_empty():
			pause_checked = true
			ui._pause()
			var frozen: Dictionary = ui.battle.get_presentation_timing()
			var highlights: Dictionary = ui.grid.active_sources.duplicate(true)
			var effects: Array = ui.arena.get_art_layout().spell_effects.duplicate(true)
			ui._process(1)
			ui.arena._process(1)
			ui.grid._process(1)
			check(frozen == ui.battle.get_presentation_timing() and highlights == ui.grid.active_sources and effects == ui.arena.get_art_layout().spell_effects, "Pause freezes enemy timing, cooldown, active highlights and spell effects")
			ui._pause()
			ui._speed()
		ui.arena._process(0.05)
		ui.grid._process(0.05)
	check(ui.battle.get_summary() == reference.get_summary() and ui.battle.battle_time == 8.6, "Enemy art/effects/preview/cooldown leave the complete reference result unchanged")
	check(observed_states.size() == 4, "Actual battle displays idle, anticipation, attack and stagger poses")
	check(observed_effects.has("spark") and observed_effects.has("flame_glyph") and observed_effects.has("tide_lances") and observed_effects.has("enemy"), "All three spells and actual incoming attacks create distinct effects")
	ui._restore_before_battle()
	check(ui.grid.active_sources.is_empty() and ui.arena.enemy_frame() == 0 and not ui.preview_label.visible, "Restoring preparation clears action highlights and returns enemy to idle")

func _checkpoints() -> void:
	var knight := Run.new()
	knight.new_run("knight")
	check(Save.save_run(knight, CHECKPOINT).ok, "Cross-class guard fixture uses an isolated valid checkpoint")
	var before := _state(ui.run)
	ui.persistence_enabled = true
	ui._load()
	check(_state(ui.run) == before and ui.status_label.text.contains("不是法师"), "Focused load rejects a valid knight checkpoint without changing the mage")
	check(ui._save(), "Mage preparation can be saved with the existing schema")
	ui._load()
	ui.persistence_enabled = false
	check(_state(ui.run) == before and ui.battle.phase == "idle", "Mage checkpoint roundtrip preserves exact prepared resources")

func _compare_layouts() -> void:
	var resources: Dictionary = {"sources": ui.run.sources.duplicate(true), "gold": ui.run.gold, "discarded": ui.run.discarded_materials.duplicate(true), "count": ui.run.items.size()}
	var preview: Dictionary = ui.run.preview_placement({"origin": "bag", "uid": 3}, Vector2i(2, 2))
	check(preview.ok and ui.run.move(3, Vector2i(2, 2)).ok and preview.combat == ui.run.get_combat_config(), "Moving the same crystal has a faithful preview and actual result")
	var config: Dictionary = ui.run.get_combat_config()
	check(config.actions[0].damage == 18 and config.actions[2].damage == 7 and config.actions[2].hits == 3, "Layout transfers support from 20-point flame to three 7-point tide segments")
	check(resources == {"sources": ui.run.sources, "gold": ui.run.gold, "discarded": ui.run.discarded_materials, "count": ui.run.items.size()}, "Layout comparison spends no extra resources or items")
	var battle := Battle.new()
	battle.start(config)
	while battle.phase == "battle":
		battle.tick(0.05)
	check(battle.phase == "won" and battle.battle_time < 8.6, "Same-resource layout change creates an observable result on this fixed enemy")
	layout_comparison = {"baseline_duration": 8.6, "tide_focus_summary": battle.get_summary(), "same_resources": resources}
