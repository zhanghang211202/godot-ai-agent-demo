extends SceneTree
## Record the real combat motion states with a manually advanced battle clock.

const OUTPUT := "res://.tools/mage-leg-revision-review"
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1440, 960)
	var ui = load("res://scenes/mage_trial.tscn").instantiate()
	ui.persistence_enabled = false
	root.add_child(ui)
	for _i in range(4):
		await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	ui._start_battle()
	for _i in range(4):
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var captured := {}
	for _step in range(30):
		var layout: Dictionary = ui.arena.get_art_layout()
		var state := str(layout.motion_state)
		if not captured.has(state):
			captured[state] = true
			check(str(layout.hero_path).ends_with("mage-pose-set-v1/characters/mage-poses.png"), state + " uses the selected seven-pose sheet")
			check(Rect2(layout.scene_rect).encloses(layout.hero_rect), state + " sprite stays inside stage")
			check(Rect2(layout.hero_rect).has_point(layout.hero_cast_point), state + " casting point stays on the sprite")
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(OUTPUT.path_join(state + ".png")) == OK, state + " viewport capture saved")
		ui._process(0.05)
		ui.arena._process(0.05)
		await process_frame
	check(captured.has("idle") and captured.has("windup") and captured.has("impact") and captured.has("recover"), "A real battle visits all four motion states")
	ui.queue_free()
	await process_frame
	print("Mage leg revision: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
