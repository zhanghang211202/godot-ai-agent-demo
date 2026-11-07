extends SceneTree
## Real event timing, AnimationPlayer, rendered frames and unchanged battle results.
const CastScene = preload("res://scenes/components/mage_cast_timeline.tscn")
const Motion = preload("res://scripts/classes/class_motion.gd")
const Battle = preload("res://scripts/classes/class_battle.gd")
const OUTPUT := "res://.tools/mage-motion-v2-review"
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	_run.call_deferred()

func _cast(remaining: float, kind: String) -> Dictionary:
	return {"target": "enemy", "source_uid": 1, "remaining": remaining, "kind": kind}

func _run() -> void:
	var timeline = CastScene.instantiate()
	root.add_child(timeline)
	await process_frame
	check(timeline.player.has_animation("cast") and timeline.player.has_animation("swing") and timeline.player.has_animation("gesture"), "Three AnimationPlayer timelines exist")
	timeline.sync_prediction([_cast(0.64, "flame_glyph")])
	check(timeline.clip == "mage-swing" and timeline.pose == 0, "Fire uses the initial staff swing pose")
	timeline.sync_prediction([_cast(0.42, "flame_glyph")])
	check(timeline.pose == 1 and timeline.player.current_animation == "swing", "Staff rises on its own AnimationPlayer timeline")
	timeline.sync_prediction([_cast(0.24, "flame_glyph")])
	check(timeline.pose == 2, "Staff points toward target when flight starts")
	timeline.show_event({"type": "spell_burst", "target": "enemy", "source_kind": "flame_glyph", "source_uid": 1, "time": 1.6})
	var before: float = timeline.player.current_animation_position
	timeline.advance(0.2, true, 2.0)
	check(is_equal_approx(timeline.player.current_animation_position, before), "Pause freezes the swing")
	timeline.advance(0.085, false, 2.0)
	check(timeline.pose == 3 and timeline.clip == "mage-swing", "Recovery follows the combat clock at double speed")
	timeline.advance(1.0, false, 1.0)
	timeline.sync_prediction([_cast(0.5, "spark")])
	check(timeline.clip == "mage-cast" and timeline.player.current_animation == "cast", "Basic magic retains the original pose set")
	timeline.sync_prediction([_cast(0.24, "frost_bolt")])
	check(timeline.clip == "mage-gesture" and timeline.pose == 2 and timeline.player.current_animation == "gesture", "Water magic releases from the open-hand pose")
	for clip in ["mage-swing", "mage-gesture"]:
		var asset: Dictionary = Motion.get_asset(clip)
		check(asset.frames.size() == 4, clip + " has four separate source poses")
		for frame: Dictionary in asset.frames:
			check(Rect2(frame.region).encloses(Rect2(frame.source_rect)) and Rect2(frame.source_rect).has_point(frame.cast_point), clip + " pose and release point fit their region")
	timeline.queue_free()
	await process_frame
	await _integration()
	await _gesture_integration()
	print("Mage motion variants: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _integration() -> void:
	root.size = Vector2i(1440, 960)
	var ui = load("res://scenes/mage_campaign.tscn").instantiate()
	ui.persistence_enabled = false
	root.add_child(ui)
	for _i in range(4): await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	check(ui.run.acquire(0, Vector2i.ZERO).ok and ui.run.discard(2).ok, "A normal fire merge and discard create a single-spell fixture")
	var reference := Battle.new()
	check(reference.start(ui.run.get_combat_config(), ui.encounter_id).ok, "Independent reference battle starts")
	ui._start_battle()
	var directory := OUTPUT.path_join("swing-frames")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var seen := {}
	var captured := 0
	for step in range(55):
		ui._process(0.05)
		reference.tick(0.05)
		ui.arena._process(0.05)
		var layout: Dictionary = ui.arena.get_art_layout()
		if str(layout.motion_clip) == "mage-swing":
			seen[int(layout.motion_frame)] = true
			check(Rect2(layout.scene_rect).encloses(layout.hero_rect) and not Rect2(layout.hero_rect).intersects(layout.enemy_rect), "Swing stays on stage and clear of enemy")
		if step >= 17 and step <= 42:
			await process_frame
			await RenderingServer.frame_post_draw
			if root.get_texture().get_image().save_png(directory.path_join("frame-%02d.png" % captured)) == OK:
				captured += 1
	check(seen.has(0) and seen.has(1) and seen.has(2) and seen.has(3), "Actual spell visits all four swing poses")
	check(captured == 26, "Captured 26 actual 50ms game steps")
	check(ui.battle.get_summary() == reference.get_summary(), "Animation does not alter damage, timings or combat result")
	ui.queue_free()
	await process_frame

func _gesture_integration() -> void:
	var ui = load("res://scenes/mage_campaign.tscn").instantiate()
	ui.persistence_enabled = false
	root.add_child(ui)
	for _i in range(4): await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	check(ui.run.acquire(1, Vector2i.ZERO).ok and ui.run.discard(2).ok, "A normal water merge makes the gesture fixture")
	var reference := Battle.new()
	check(reference.start(ui.run.get_combat_config(), ui.encounter_id).ok, "Independent gesture reference starts")
	ui._start_battle()
	var directory := OUTPUT.path_join("gesture-frames")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var seen := {}
	var captured := 0
	for step in range(25):
		ui._process(0.05)
		reference.tick(0.05)
		ui.arena._process(0.05)
		var layout: Dictionary = ui.arena.get_art_layout()
		if str(layout.motion_clip) == "mage-gesture":
			seen[int(layout.motion_frame)] = true
			check(Rect2(layout.scene_rect).encloses(layout.hero_rect) and not Rect2(layout.hero_rect).intersects(layout.enemy_rect), "Gesture stays on stage and clear of enemy")
		await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(directory.path_join("frame-%02d.png" % step)) == OK:
			captured += 1
	check(seen.has(1) and seen.has(2) and seen.has(3), "Real water spell visits gather, release and recovery")
	check(captured == 25 and ui.battle.get_summary() == reference.get_summary(), "Gesture capture leaves all combat results unchanged")
	for dimensions in [Vector2i(1280, 800), Vector2i(1440, 960), Vector2i(1920, 1080)]:
		root.size = dimensions
		for _i in range(4): await process_frame
		var heights: Array[float] = []
		for clip in ["mage-cast", "mage-swing", "mage-gesture"]:
			var release_points: Array[Vector2] = []
			for pose in range(4):
				ui.arena.mage_cast_timeline.mode = "prediction"
				ui.arena.mage_cast_timeline.clip = clip
				ui.arena.mage_cast_timeline.pose = pose
				var layout: Dictionary = ui.arena.get_art_layout()
				check(Rect2(layout.scene_rect).encloses(layout.hero_rect) and not Rect2(layout.hero_rect).intersects(layout.enemy_rect), "%s %s pose %d remains inside the stage" % [str(dimensions), clip, pose])
				check(is_equal_approx(Rect2(layout.hero_rect).end.y, float(layout.ground_y)), "%s %s pose %d keeps the foot anchor" % [str(dimensions), clip, pose])
				heights.append(float(layout.hero_body_height))
				release_points.append(layout.hero_release_point)
				if pose == 2:
					check(Vector2(layout.hero_cast_point).distance_to(layout.hero_release_point) < 0.01, "%s %s projectile starts at the visible release point" % [str(dimensions), clip])
			for point in release_points:
				check(point.distance_to(release_points[0]) < 0.01, "%s %s release point does not drift with other poses" % [str(dimensions), clip])
		var minimum: float = heights.min()
		var maximum: float = heights.max()
		check(minimum > 0 and maximum - minimum < 0.05, "%s body landmark height remains constant across all 12 poses" % str(dimensions))
	root.size = Vector2i(1440, 960)
	for _i in range(4): await process_frame
	var comparison := OUTPUT.path_join("size-comparison")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(comparison))
	for clip in ["mage-cast", "mage-swing", "mage-gesture"]:
		ui.arena.mage_cast_timeline.mode = "prediction"
		ui.arena.mage_cast_timeline.clip = clip
		ui.arena.mage_cast_timeline.pose = 2
		ui.arena.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(comparison.path_join(clip + ".png")) == OK, clip + " size comparison rendered")
	ui.queue_free()
	await process_frame
