extends SceneTree
## Real AnimationPlayer and deterministic combat; no saved player data.

const CastScene = preload("res://scenes/components/mage_cast_timeline.tscn")
const Battle = preload("res://scripts/classes/class_battle.gd")
const Effects = preload("res://scripts/classes/mage_effects.gd")
const OUTPUT := "res://.tools/mage-cast-sync-review"
const PLAYER_PATHS := ["user://mage-trial-run.json", "user://class-prototype-run.json", "user://emberpack-run.json"]
var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	_run.call_deferred()

func _cast(remaining: float, uid: int = 1) -> Dictionary:
	return {"target": "enemy", "source_uid": uid, "remaining": remaining}

func _hit(time: float, uid: int = 1) -> Dictionary:
	return {"type": "spell", "target": "enemy", "source_uid": uid, "time": time}

func _run() -> void:
	var fingerprints := {}
	for path in PLAYER_PATHS:
		fingerprints[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	var timeline = CastScene.instantiate()
	root.add_child(timeline)
	await process_frame
	check(timeline.player.has_animation("cast") and timeline.pose == 0, "Native AnimationPlayer starts in idle")
	check(timeline.player.get_animation("swing").get_track_count() == 1, "Swing animates only the existing pose track, without whole-character lean")
	var simultaneous := [{"uid": 2, "kind": "tide_lances", "hits": 3}, {"uid": 1, "kind": "flame_glyph", "hits": 1}]
	var shared_timing := {"sources": {1: {"remaining": 0.2}, 2: {"remaining": 0.2}}}
	timeline.sync_prediction(Effects.visible_casts(simultaneous, shared_timing))
	var chosen_clip: String = timeline.clip
	simultaneous.reverse()
	timeline.sync_prediction(Effects.visible_casts(simultaneous, shared_timing))
	check(chosen_clip == "mage-swing" and timeline.clip == chosen_clip and timeline.pose == 2, "Simultaneous different spells keep the same AnimationPlayer clip when source order changes")
	timeline.reset()
	timeline.sync_prediction([{"target": "enemy", "source_uid": 1, "kind": "flame_glyph", "remaining": 0.30}])
	check(timeline.clip == "mage-swing" and timeline.pose == 3, "Swing uses the existing diagonal staff pose between windup and release")
	timeline.sync_prediction([{"target": "enemy", "source_uid": 1, "kind": "flame_glyph", "remaining": 0.14}])
	check(timeline.pose == 2, "Swing reaches the existing release pose before the attack")
	timeline.reset()
	timeline.sync_prediction([_cast(0.50)])
	check(timeline.pose == 1 and timeline.mode == "prediction", "Gather uses the windup pose")
	timeline.sync_prediction([_cast(0.24), _cast(0.24, 2)])
	check(timeline.pose == 2, "Two simultaneous flights use a single release pose at the projectile boundary")
	timeline.show_event(_hit(1.0))
	var hit_position: float = timeline.player.current_animation_position
	timeline.show_event(_hit(1.0, 2))
	check(timeline.mode == "recovery" and is_equal_approx(timeline.player.current_animation_position, hit_position), "Same-step source or multi-hit does not restart follow-through")
	timeline.advance(0.17, true, 2.0)
	check(is_equal_approx(timeline.player.current_animation_position, hit_position), "Pause freezes AnimationPlayer")
	timeline.advance(0.085, false, 2.0)
	check(timeline.pose == 3, "Double speed advances recovery with the combat clock")
	timeline.sync_prediction([_cast(0.5, 3)])
	check(timeline.pose == 3 and timeline.mode == "recovery", "A later gather does not interrupt recovery")
	timeline.sync_prediction([_cast(0.2, 3)])
	check(timeline.pose == 2 and timeline.mode == "prediction", "A nearby next flight switches directly back to release")
	timeline.sync_prediction([])
	check(timeline.pose == 0 and timeline.mode == "idle", "A cancelled forecast resets the pose")
	timeline.sync_prediction([_cast(0.1)])
	timeline.finish_battle()
	check(timeline.pose == 0 and timeline.mode == "idle", "A defeated mage cancels a predicted flight")
	timeline.show_event(_hit(2.0))
	timeline.finish_battle()
	check(timeline.mode == "recovery" and timeline.pose == 2, "A real finishing hit retains follow-through")
	timeline.advance(1.0, false, 1.0)
	check(timeline.mode == "idle" and timeline.pose == 0, "Finishing follow-through settles")
	timeline.queue_free()
	await process_frame
	await _integration()
	for path in fingerprints:
		var after := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
		check(after == fingerprints[path], "Player save unchanged: " + path)
	print("Mage cast sync: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _integration() -> void:
	root.size = Vector2i(1440, 960)
	var ui = load("res://scenes/mage_trial.tscn").instantiate()
	ui.persistence_enabled = false
	root.add_child(ui)
	for _i in range(4): await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	var reference := Battle.new()
	check(reference.start(ui.run.get_combat_config()).ok, "Independent two-spark battle starts")
	ui._start_battle()
	for _i in range(4): await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var seen := {}
	var paused := false
	for step in range(2000):
		if ui.battle.phase != "battle": break
		ui._process(0.05)
		reference.tick(0.05 * ui.speed)
		ui.arena._process(0.05)
		var layout: Dictionary = ui.arena.get_art_layout()
		var friendly: Array = []
		for cast: Dictionary in layout.spell_casts:
			if cast.target == "enemy": friendly.append(cast)
		if friendly.size() >= 2 and not seen.has("volley"):
			seen.volley = true
			check(ui.arena._source_cast_offset(int(friendly[0].source_uid)) != ui.arena._source_cast_offset(int(friendly[1].source_uid)), "Simultaneous equipped sources have distinct stable emitters")
		if friendly.size() >= 2 and friendly[0].phase == "flight" and not seen.has("flight"):
			seen.flight = true
			check(layout.motion_frame == 2 and ui.arena.mage_cast_timeline.mode == "prediction", "Real simultaneous projectile flight uses the release frame before damage")
			check(ui.battle.get_summary().damage_dealt == 0, "Release pose does not cause early damage")
			await _capture("volley-flight.png")
			ui._pause()
			var frozen: Dictionary = ui.arena.get_art_report().duplicate(true)
			ui._process(1.0)
			ui.arena._process(1.0)
			check(ui.arena.get_art_report() == frozen, "Pausing an actual volley freezes pose and VFX")
			ui._pause()
			ui._speed()
			paused = true
		if ui.battle.get_summary().damage_dealt > 0 and not seen.has("impact"):
			seen.impact = true
			check(layout.motion_frame == 2 and ui.arena.mage_cast_timeline.mode == "recovery", "Actual damage begins follow-through in release pose")
			await _capture("volley-impact.png")
		if ui.arena.mage_cast_timeline.pose == 3 and not seen.has("recover"):
			seen.recover = true
			await _capture("volley-recover.png")
	check(paused and seen.has("volley") and seen.has("flight") and seen.has("impact") and seen.has("recover"), "Actual battle visits simultaneous flight, impact and recovery")
	check(ui.battle.get_summary() == reference.get_summary(), "Pause, 2x and animation preserve every combat result field")
	ui._restore_before_battle()
	check(ui.arena.mage_cast_timeline.mode == "idle", "Returning to preparation clears the timeline")
	await _record_sequence(ui)
	if OS.get_environment("MAGE_CAPTURE_MOTION") == "1":
		await _record_swing(ui)
	ui.queue_free()
	await process_frame

func _record_sequence(ui: Control) -> void:
	# Controlled 50 ms steps from a fresh legal build, suitable for an honestly
	# labelled animation review rather than a real-time performance claim.
	ui._new_class("mage")
	ui.speed = 1.0
	ui._sync()
	ui._start_battle()
	for _i in range(4): await process_frame
	var directory := OUTPUT.path_join("frames")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var saved := true
	for index in range(17):
		await process_frame
		await RenderingServer.frame_post_draw
		saved = root.get_texture().get_image().save_png(directory.path_join("frame-%02d.png" % index)) == OK and saved
		ui._process(0.05)
		ui.arena._process(0.05)
	check(saved, "Saved 17 real battle frames at controlled 50 ms intervals")

func _record_swing(ui: Control) -> void:
	ui._restore_before_battle()
	ui._new_class("mage")
	ui._on_drop({"origin": "source", "index": 0}, Vector2i.ZERO)
	check(ui.run.item_by_uid(1).kind == "flame_glyph", "Motion fixture creates the actual flame spell through a normal merge")
	ui.speed = 1.0
	ui._start_battle()
	for _i in range(15):
		ui._process(0.05)
		ui.arena._process(0.05)
	var directory := OUTPUT.path_join("swing-frames")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var saw_swing := false
	var saw_transition := false
	var saw_release := false
	var minimum_body := INF
	var maximum_body := 0.0
	var unmoved_rotation := true
	var saved := true
	for index in range(25):
		ui.arena.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		saved = root.get_texture().get_image().save_png(directory.path_join("frame-%02d.png" % index)) == OK and saved
		saw_swing = saw_swing or ui.arena.mage_cast_timeline.clip == "mage-swing"
		var layout: Dictionary = ui.arena.get_art_layout()
		var casts: Array = layout.spell_casts
		var flame_casts: Array = casts.filter(func(cast: Dictionary): return cast.kind == "flame_glyph")
		if not flame_casts.is_empty() and ui.arena.mage_cast_timeline.clip == "mage-swing":
			minimum_body = minf(minimum_body, layout.hero_body_height)
			maximum_body = maxf(maximum_body, layout.hero_body_height)
			unmoved_rotation = unmoved_rotation and is_zero_approx(ui.arena.actor_sprite.rotation) and is_zero_approx(ui.arena.mage_hit_motion.rotation)
			saw_transition = saw_transition or (flame_casts[0].phase == "gather" and ui.arena.mage_cast_timeline.pose == 3)
			saw_release = saw_release or (flame_casts[0].phase == "flight" and ui.arena.mage_cast_timeline.pose == 2)
		ui._process(0.05)
		ui.arena._process(0.05)
	check(saved and saw_swing and saw_transition and saw_release, "Saved 25 real swing frames showing anticipation, diagonal pose and release")
	check(unmoved_rotation and minimum_body > 0.0 and maximum_body - minimum_body < 0.01, "Swing keeps the original character angle and normalized body height throughout")

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT.path_join(name)) == OK, "Saved runtime capture: " + name)
