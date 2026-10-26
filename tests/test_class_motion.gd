extends SceneTree
## Action timing/geometry/integration checks. Not full art-quality acceptance.

const Motion = preload("res://scripts/classes/class_motion.gd")
const Battle = preload("res://scripts/classes/class_battle.gd")
const Save = preload("res://scripts/classes/class_save.gd")
const CHECKPOINT := "res://.tools/test-saves/class-motion.json"
var checks := 0
var failures := 0
var ui: Control
var measurements: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func _event(type: String, kind: String, uid := 1, time := 1.0, hit := 0) -> Dictionary:
	return {"type": type, "source_kind": kind, "source_uid": uid, "time": time, "hit_index": hit}

func _run() -> void:
	var fingerprints := {}
	for path in [Save.DEFAULT_PATH, "user://emberpack-run.json"]:
		fingerprints[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	_test_state_machine()
	root.size = Vector2i(1440, 960)
	ui = load("res://scenes/class_lab.tscn").instantiate()
	ui.persistence_enabled = false
	ui.checkpoint_path = CHECKPOINT
	root.add_child(ui)
	await process_frame
	await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	for id in ["mage", "sword", "greatblade"]:
		_prepare(id)
		await _geometry(id)
		_integration(id)
	await _lifecycle()
	for path in fingerprints:
		var after := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
		check(after == fingerprints[path], "Motion tests never write player checkpoint " + path)
	Save.reset_prototype(CHECKPOINT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tools/c1-motion-review"))
	var file := FileAccess.open("res://.tools/c1-motion-review/test-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "layouts": measurements}, "\t"))
	file.close()
	print("Class motion: %d checks, %d failures" % [checks, failures])
	ui.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _test_state_machine() -> void:
	for kind in ["spark", "flame_glyph", "tide_lances", "iron_blade", "greatblade"]:
		var player := Motion.new()
		player.show_event(_event("charge", kind))
		player.advance(20)
		check(player.state == "windup" and player.frame_index() == 1, kind + " holds anticipation until an actual impact")
		player.show_event(_event("attack", kind))
		check(player.state == "impact" and player.frame_index() == 2, kind + " impact begins on damage event")
		player.advance(0.17)
		player.show_event(_event("attack", kind, 1, 1.0, 2))
		check(player.state == "recover" and player.frame_index() == 3, kind + " same activation's extra hit does not restart action")
		player.show_event(_event("charge", kind, 2))
		check(player.state == "recover", kind + " simultaneous charge cannot erase impact follow-through")
		player.advance(0.26)
		check(player.state == "idle" and player.clip == "", kind + " returns to idle")
		player.show_event(_event("attack", kind, 1, 2.0))
		check(player.state == "impact", kind + " next activation starts again")
		player.finish_battle()
		check(player.state == "impact", kind + " winning impact may finish visually")
		player.reset()
		player.show_event(_event("charge", kind))
		player.finish_battle()
		check(player.state == "idle", kind + " result never leaves unfinished anticipation")
	var unknown := Motion.new()
	unknown.show_event(_event("enemy_attack", "enemy"))
	check(unknown.clip == "", "Enemy attack never fabricates a hero action")

func _prepare(id: String) -> void:
	ui._new_class("mage" if id == "mage" else "knight")
	if id == "mage":
		for action in [[0, Vector2i.ZERO], [1, Vector2i(3, 2)], [2, Vector2i(3, 2)]]:
			check(ui.run.acquire(action[0], action[1]).ok, "Mage motion fixture uses legal finite acquisition")
	elif id == "greatblade":
		check(ui.run.acquire(1, Vector2i.ZERO).ok, "Greatblade uses actual forge recipe")
		check(ui.run.acquire(1, Vector2i(2, 1)).ok, "Greatblade uses actual finite support source")
	ui._sync()

func _geometry(id: String) -> void:
	var kind := "spark" if id == "mage" else "iron_blade" if id == "sword" else "greatblade"
	var clip := Motion.clip_for_kind(kind)
	var asset := Motion.get_asset(clip)
	check(asset.frames.size() == 4, clip + " has four dedicated frames")
	var source := Image.load_from_file(asset.path)
	check(source.get_pixel(0, 0).a == 0, clip + " has actual transparent background")
	for dimensions in [Vector2i(1280, 800), Vector2i(1440, 960), Vector2i(1920, 1080)]:
		root.size = dimensions
		for _frame in range(4):
			await process_frame
		var common_scale := -1.0
		for index in range(4):
			ui.arena.motion.reset()
			if index == 1:
				ui.arena.show_event(_event("charge", kind))
			elif index >= 2:
				ui.arena.show_event(_event("attack", kind))
				if index == 3:
					ui.arena.motion.advance(0.17)
			var layout: Dictionary = ui.arena.get_art_layout()
			var rect: Rect2 = layout.hero_rect
			var frame: Dictionary = asset.frames[index]
			check(layout.motion_frame == index and layout.motion_clip == clip, clip + " selects actual frame %d" % index)
			check(Rect2(frame.region).encloses(frame.source_rect) and Rect2(Vector2.ZERO, Vector2(asset.size)).encloses(frame.region), clip + " source region contains complete visible frame")
			check(Rect2(layout.scene_rect).grow(0.1).encloses(rect) and not rect.intersects(layout.enemy_rect), clip + " whole weapon/actor fits stage without enemy overlap")
			check(is_equal_approx(rect.end.y, layout.ground_y), clip + " boot baseline rests on ground")
			var scale: float = layout.source_scale.x
			check(common_scale < 0 or is_equal_approx(common_scale, scale), clip + " uses one scale across action frames")
			common_scale = scale
			measurements.append({"variant": id, "viewport": [dimensions.x, dimensions.y], "frame": index, "visuals": ui.arena.get_art_report()})
	ui.arena.reset_presentation()

func _integration(id: String) -> void:
	var reference := Battle.new()
	check(reference.start(ui.run.get_combat_config()).ok, id + " independent engine starts")
	ui._start_battle()
	ui._process(0.05)
	reference.tick(0.05)
	check(ui.arena.motion.state == "windup", id + " real initial charge animates")
	# Pause an actual impact, not just windup (which holds even when unpaused).
	for _step in range(60):
		if ui.arena.motion.state == "impact":
			break
		ui._process(0.05)
		reference.tick(0.05 * ui.speed)
	ui._pause()
	var before: Dictionary = ui.battle.get_summary().duplicate(true)
	var state: String = ui.arena.motion.state
	var elapsed: float = ui.arena.motion.elapsed
	var flash: float = ui.arena.flash
	ui._process(1.0)
	ui.arena._process(1.0)
	check(state == "impact" and ui.battle.get_summary() == before and ui.arena.motion.state == state and ui.arena.motion.elapsed == elapsed and ui.arena.flash == flash, id + " pause freezes real impact, rules and event flash")
	ui._pause()
	var states := {}
	for step in range(2000):
		if ui.battle.phase != "battle":
			break
		ui._process(0.05)
		reference.tick(0.05 * ui.speed)
		states[ui.arena.motion.state] = true
		ui.arena._process(0.05)
		if step == 8:
			ui._speed()
	check(states.has("impact") and states.has("recover"), id + " actual battle displays articulated impact and recovery")
	check(ui.battle.get_summary() == reference.get_summary(), id + " pause/speed/action leaves every independent result field unchanged")
	ui.arena._process(1)
	check(ui.arena.motion.state == "idle", id + " result settles after winning follow-through")
	ui._restore_before_battle()
	check(ui.arena.motion.state == "idle" and ui.arena.last_event.is_empty(), id + " restoring preparation clears transient presentation")
	# Verify duration scaling independently of the rules tick.
	ui.arena.show_event(_event("attack", "spark" if id == "mage" else "iron_blade", 99))
	ui.speed = 1
	ui._sync()
	ui.arena._process(0.1)
	check(ui.arena.motion.state == "impact", id + " 1x retains impact at 100ms")
	ui.arena.reset_presentation()
	ui.arena.show_event(_event("attack", "spark" if id == "mage" else "iron_blade", 99))
	ui.speed = 2
	ui._sync()
	ui.arena._process(0.1)
	check(ui.arena.motion.state == "recover", id + " 2x reaches recovery at 100ms wall clock")
	ui.speed = 1
	ui._sync()
	ui.arena.reset_presentation()

func _lifecycle() -> void:
	ui._new_class("mage")
	check(Save.save_run(ui.run, CHECKPOINT).ok, "Lifecycle uses isolated checkpoint")
	ui._new_class("knight")
	ui.arena.show_event(_event("charge", "greatblade"))
	ui.persistence_enabled = true
	ui._load()
	ui.persistence_enabled = false
	check(ui.run.class_id == "mage" and ui.arena.motion.state == "idle" and ui.arena.last_event.is_empty(), "Cross-class load clears previous weapon animation")
	ui.arena.show_event(_event("attack", "spark"))
	ui._new_class("knight")
	check(ui.arena.motion.state == "idle" and ui.arena.get_art_layout().motion_clip == "knight-sword", "New class clears prior spell clip")
