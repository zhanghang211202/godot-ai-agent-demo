extends SceneTree
## The selected seven-pose atlas, real combat timing and presentation priority.
const Motion = preload("res://scripts/classes/class_motion.gd")
const Battle = preload("res://scripts/classes/class_battle.gd")
const OUTPUT := "res://.tools/mage-pose-set-review"
var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1440, 960)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var art: Dictionary = Motion.get_asset("mage-poses")
	check(art.frames.size() == 7, "Selected sheet contains one idle, three attack and three guard regions")
	for frame: Dictionary in art.frames:
		check(Rect2(frame.region).encloses(frame.source_rect) and Rect2(frame.source_rect).has_point(frame.cast_point), "Each measured pose and staff point fits its region")
	var ui = load("res://scenes/mage_campaign.tscn").instantiate()
	ui.persistence_enabled = false
	root.add_child(ui)
	for _i in range(4): await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	var timeline = ui.arena.mage_cast_timeline
	timeline.rng.seed = 24680
	var seen := {}
	for _i in range(30):
		timeline.reset()
		timeline.sync_prediction([{"target": "enemy", "source_uid": 1, "remaining": 0.3}])
		var choice: int = timeline.attack_variant
		seen[choice] = true
		timeline.sync_prediction([{"target": "enemy", "source_uid": 1, "remaining": 0.2}])
		check(timeline.attack_variant == choice, "An attack keeps its selected pose throughout a cast")
	check(seen.size() == 3, "Seeded presentation randomness reaches all three attacks")
	timeline.reset()
	var reference := Battle.new()
	check(reference.start(ui.run.get_combat_config(), ui.encounter_id).ok, "Independent combat starts")
	ui._start_battle()
	for _i in range(4): await process_frame
	var captured := {}
	for _step in range(3000):
		if ui.battle.phase != "battle": break
		ui._process(0.05)
		reference.tick(0.05)
		ui.arena._process(0.05)
		var layout: Dictionary = ui.arena.get_art_layout()
		if layout.motion_frame in [1, 2, 3]:
			captured[int(layout.motion_frame)] = true
	check(ui.battle.get_summary() == reference.get_summary(), "Random poses leave the combat outcome unchanged")
	check(not captured.is_empty(), "A real fight shows an attack pose")
	ui._restore_before_battle()
	ui._start_battle()
	ui.arena.reset_presentation()
	# Force each pose only for a labelled screenshot and geometry comparison.
	for dimensions in [Vector2i(1280, 800), Vector2i(1440, 960), Vector2i(1920, 1080)]:
		root.size = dimensions
		for _i in range(4): await process_frame
		var heights: Array[float] = []
		for index in range(7):
			timeline.mode = "prediction" if index in [1, 2, 3] else "idle"
			timeline.clip = "mage-poses"
			timeline.pose = 2 if index in [1, 2, 3] else 0
			timeline.attack_variant = clampi(index, 1, 3)
			ui.arena.mage_hit_motion.guard_frame = index if index >= 4 else 0
			if index >= 4:
				ui.arena.mage_hit_motion.player.play("hit")
			var layout: Dictionary = ui.arena.get_art_layout()
			check(layout.motion_frame == index and layout.motion_clip == "mage-poses", "%s selects pose %d" % [str(dimensions), index])
			check(Rect2(layout.scene_rect).encloses(layout.hero_rect) and not Rect2(layout.hero_rect).intersects(layout.enemy_rect), "%s pose %d stays on stage" % [str(dimensions), index])
			heights.append(float(layout.hero_body_height))
			if index in [1, 2, 3]:
				check(Vector2(layout.hero_cast_point).distance_to(layout.hero_release_point) < 0.01, "%s attack %d emits from its staff" % [str(dimensions), index])
			if dimensions.x == 1440:
				ui.arena.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(OUTPUT.path_join("pose-%d.png" % index)) == OK, "Saved labelled pose fixture %d" % index)
		check(float(heights.max()) - float(heights.min()) < 0.05, "%s body height is stable across poses" % str(dimensions))
	# Controlled hit while the cast is already visible: shield reaction cannot interrupt it.
	timeline.mode = "prediction"
	timeline.pose = 2
	timeline.attack_variant = 2
	ui.arena.mage_hit_motion.reset_motion()
	ui.arena.show_event({"type": "enemy_attack", "target": "hero", "event_id": 8000, "time": 100.0, "amount": 4, "armor_mitigated": 2})
	check(ui.arena.get_art_layout().motion_frame == 2 and ui.arena.mage_hit_motion.guard_frame == 0, "Mitigated hit never interrupts an active attack")
	check(not ui.arena.get_art_layout().shields.is_empty(), "A shield still appears over an active attack")
	ui._restore_before_battle()
	ui._start_battle()
	# The fixture delays the attacks, so an actual enemy hit lands during idle.
	for action: Dictionary in ui.battle._actions:
		action.next_step = 10000
	var real_guard := false
	for _step in range(50):
		ui._process(0.05)
		ui.arena._process(0.05)
		var layout: Dictionary = ui.arena.get_art_layout()
		if layout.motion_frame in [4, 5, 6]:
			real_guard = true
			check(not layout.shields.is_empty(), "A real mitigated hit selects an embedded shield pose")
			ui.arena.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(OUTPUT.path_join("real-guard.png")) == OK, "Saved real defensive hit fixture")
			break
	check(real_guard, "A real enemy hit produces a guard pose when not casting")
	ui.arena.reset_presentation()
	ui.arena.mage_hit_motion.rng.seed = 98765
	var guard_choices := {}
	for index in range(30):
		ui.arena.show_event({"type": "enemy_attack", "target": "hero", "event_id": 9000 + index, "time": 200.0 + index, "amount": 4, "armor_mitigated": 2})
		guard_choices[ui.arena.mage_hit_motion.guard_frame] = true
	check(guard_choices.size() == 3 and guard_choices.has(4) and guard_choices.has(5) and guard_choices.has(6), "Seeded hit randomness reaches all three guard poses")
	ui.arena.show_event({"type": "enemy_attack", "target": "hero", "event_id": 9999, "time": 300.0, "amount": 4, "armor_mitigated": 0})
	check(ui.arena.mage_hit_motion.guard_frame == 0, "An unmitigated hit does not falsely show a magical shield")
	ui.arena.reset_presentation()
	ui.battle._actions[0].next_step = ui.battle._step_index + 5
	ui.arena.show_event({"type": "enemy_attack", "target": "hero", "event_id": 10000, "time": 301.0, "amount": 4, "armor_mitigated": 2})
	check(ui.arena.mage_hit_motion.guard_frame == 0, "An imminent cast wins even before its prediction timeline is updated")
	ui.queue_free()
	await process_frame
	print("Mage pose set: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
