extends SceneTree

const HitScene = preload("res://scenes/components/mage_hit_motion.tscn")
const Battle = preload("res://scripts/classes/class_battle.gd")
const OUTPUT := "res://.tools/mage-hit-motion-review"
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var actor = HitScene.instantiate()
	root.add_child(actor)
	await process_frame
	var hit := {"type": "enemy_attack", "target": "hero", "event_id": 10, "time": 2.1}
	check(actor.position == Vector2.ZERO and actor.player.has_animation("hit"), "AnimationPlayer starts at neutral with a hit clip")
	check(not actor.show_hit({"type": "spell", "target": "enemy"}), "Enemy-targeted spells do not animate the hero")
	check(actor.show_hit(hit), "Actual enemy hit starts the animation")
	actor.advance_motion(0.05, false, 1.0)
	check(actor.position == Vector2(-5, 0), "First recoil frame moves only horizontally")
	var stopped: Vector2 = actor.position
	actor.advance_motion(1.0, true, 2.0)
	check(actor.position == stopped, "Pause freezes the manual animation clock")
	check(not actor.show_hit(hit), "Duplicate event does not restart recoil")
	check(not actor.show_hit({"type": "enemy_attack", "target": "hero", "event_id": 11, "time": 2.1}), "Simultaneous multi-hit segments share a recoil")
	actor.advance_motion(0.02, false, 2.0)
	check(actor.position == Vector2(-3, 0), "Double speed advances the timeline twice as fast")
	check(actor.show_hit({"type": "enemy_attack", "target": "hero", "event_id": 12, "time": 2.2}), "Later hit restarts an interrupted reaction")
	check(not actor.show_hit(hit), "An older duplicate cannot restart the newer reaction")
	actor.advance_motion(0.3, false, 1.0)
	check(actor.position == Vector2.ZERO and not actor.player.is_playing(), "Reaction finishes at the original anchor")
	actor.show_hit({"type": "enemy_attack", "target": "hero", "event_id": 13, "time": 3.0})
	actor.advance_motion(0.05, false, 1.0)
	actor.reset_motion()
	check(actor.position == Vector2.ZERO and not actor.player.is_playing(), "Reset clears interrupted motion")
	check(actor.show_hit(hit), "Reset permits a new battle to reuse event IDs and times")
	actor.queue_free()
	await _integration()
	print("Mage hit motion: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _integration() -> void:
	root.size = Vector2i(1440, 960)
	var ui = load("res://scenes/mage_trial.tscn").instantiate()
	ui.persistence_enabled = false
	root.add_child(ui)
	await process_frame
	await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	ui._select_encounter("mirror_moth")
	var reference = Battle.new()
	check(reference.start(ui.run.get_combat_config(), "mirror_moth").ok, "Independent moth battle accepts the original build")
	ui._start_battle()
	var found_hit := false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	while ui.battle.phase == "battle":
		ui._process(0.05)
		reference.tick(0.05)
		if ui.arena.feedback.hero_hit > 0 and not found_hit:
			await _capture("frame0000.png")
		ui.arena._process(0.05)
		if ui.arena.feedback.hero_hit > 0 and not found_hit:
			found_hit = true
			check(ui.arena.mage_hit_motion.position == Vector2(-5, 0), "A real two-segment attack moves the mage once")
			check(ui.arena.feedback.numbers[-1].hits == 2, "The real two-segment hit is grouped without losing its damage")
			var layout: Dictionary = ui.arena.get_art_layout()
			check(ui.arena._mage_effect_rect(layout).position == Vector2(layout.hero_rect.position) + Vector2(-5, 0), "Ward follows the animated body")
			var before: Dictionary = ui.battle.get_summary().duplicate(true)
			ui._pause()
			ui._process(1.0)
			ui.arena._process(1.0)
			check(ui.arena.mage_hit_motion.position == Vector2(-5, 0) and before == ui.battle.get_summary(), "Pause holds the real recoil and combat result")
			ui._pause()
			await _capture("frame0001.png")
			ui.arena._process(0.05)
			await _capture("frame0002.png")
			ui.arena._process(0.05)
			await _capture("frame0003.png")
			ui.arena._process(0.08)
			await _capture("frame0004.png")
			check(ui.arena.mage_hit_motion.position == Vector2.ZERO, "Captured recovery returns to the original position")
	check(found_hit and ui.battle.get_summary() == reference.get_summary(), "Full fight outcome exactly matches the independent rules engine")
	ui.arena._process(1.0)
	check(ui.arena.mage_hit_motion.position == Vector2.ZERO and not ui.arena.mage_hit_motion.player.is_playing(), "Real battle ends with no residual recoil")
	ui._restore_before_battle()
	check(ui.arena.mage_hit_motion.position == Vector2.ZERO, "Restoring preparation clears the wrapper")
	ui.queue_free()
	await process_frame

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT.path_join(name)) == OK, "Native viewport frame saved: " + name)
