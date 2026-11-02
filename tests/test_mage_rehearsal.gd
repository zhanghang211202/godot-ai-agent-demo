extends SceneTree
## Real UI click and independent deterministic comparison; no player saves.
const Run = preload("res://scripts/classes/class_run.gd")
const Battle = preload("res://scripts/classes/class_battle.gd")
const Rehearsal = preload("res://scripts/classes/mage_rehearsal.gd")
const OUTPUT := "res://.tools/mage-rehearsal-review"
const PLAYER_PATHS := ["user://mage-trial-run.json", "user://class-prototype-run.json", "user://emberpack-run.json"]
var ui: Control
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	_run.call_deferred()

func _state() -> Dictionary:
	return {"items": ui.run.items.duplicate(true), "sources": ui.run.sources.duplicate(true), "uid": ui.run._next_uid,
		"discarded": ui.run.discarded_materials.duplicate(true), "gold": ui.run.gold, "hp": ui.run.hp,
		"phase": ui.run.phase, "battle": ui.battle.get_summary().duplicate(true)}

func _fingerprints() -> Dictionary:
	var result := {}
	for path in PLAYER_PATHS:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return result

func _run() -> void:
	var player_saves := _fingerprints()
	var knight := Run.new()
	knight.new_run("knight")
	check(not Rehearsal.simulate(knight).ok, "Rehearsal does not change legacy knight behavior")
	root.size = Vector2i(1440, 960)
	ui = load("res://scenes/mage_trial.tscn").instantiate()
	ui.persistence_enabled = false
	root.add_child(ui)
	await process_frame
	await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	var before := _state()
	var result: Dictionary = Rehearsal.simulate(ui.run)
	check(result.ok and result.encounters.size() == 3 and _state() == before, "All three encounters simulate without changing the run or live battle")
	for encounter: Dictionary in result.encounters:
		var reference := Battle.new()
		check(reference.start(ui.run.get_combat_config(), encounter.id).ok, str(encounter.id) + " real engine starts")
		while reference.phase == "battle":
			reference.tick(0.05)
		check(reference.get_summary() == encounter.summary, str(encounter.id) + " forecast matches a separately stepped real battle")
	for dimensions in [Vector2i(1280, 800), Vector2i(1440, 960), Vector2i(1920, 1080)]:
		root.size = dimensions
		for _i in range(4): await process_frame
		check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(ui.rehearsal_button.get_global_rect()), str(dimensions) + " rehearsal button fits viewport")
	root.size = Vector2i(1440, 960)
	for _i in range(4): await process_frame
	await _click(ui.rehearsal_button.get_global_rect().get_center())
	check(ui.summary_label.text.contains("予行演習") and ui.summary_label.text.contains("鏡翼の蛾") and ui.summary_label.text.contains("茨の石像"), "Real click displays Japanese results for each encounter")
	check(_state() == before and ui.run.phase == "prepare", "Opening results consumes no source and does not start battle")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT.path_join("rehearsal.png")) == OK, "Native rehearsal screenshot saved")
	for dimensions in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.size = dimensions
		for _i in range(4): await process_frame
		check(ui.summary_label.text.contains("予行演習") and not ui._rehearsal_signature.is_empty(), str(dimensions) + " results remain visible after resize")
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OUTPUT.path_join("rehearsal-%d.png" % dimensions.x)) == OK, str(dimensions) + " native screenshot saved")
	root.size = Vector2i(1440, 960)
	for _i in range(4): await process_frame
	check(ui.run.move(3, Vector2i(3, 1)).ok, "Changed-build fixture moves the focus legally")
	ui._sync()
	check(ui.summary_label.text.contains("配置が変わりました") and not ui.summary_label.text.contains("鏡翼の蛾"), "A changed build invalidates its old forecast")
	ui._new_class("mage")
	ui._rehearse()
	check(ui.run.acquire(0, Vector2i(3, 2)).ok, "Raw material fixture places an unused element")
	ui._sync()
	check(ui.summary_label.text.contains("配置が変わりました"), "Even an unused material placement invalidates the displayed forecast")
	ui._new_class("mage")
	check(ui.run.discard(1).ok and ui.run.discard(2).ok, "No-attack fixture uses normal discards")
	before = _state()
	ui._rehearse()
	check(_state() == before and not ui.status_label.text.is_empty(), "An invalid build reports an error without consumption")
	ui._new_class("mage")
	ui._start_battle()
	check(ui.rehearsal_button.disabled and not Rehearsal.simulate(ui.run).ok, "Rehearsal cannot run during live combat")
	check(_fingerprints() == player_saves, "No player checkpoint was changed")
	ui.queue_free()
	await process_frame
	print("Mage rehearsal: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_screen_transform() * position
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = motion.position
	press.global_position = motion.position
	Input.parse_input_event(press)
	await process_frame
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
