extends SceneTree
## Real events, lifecycle, bounded transient data. GPU coverage is separate.

const Feedback = preload("res://scripts/classes/class_feedback.gd")
const Battle = preload("res://scripts/classes/class_battle.gd")
const Save = preload("res://scripts/classes/class_save.gd")
const CHECKPOINT := "res://.tools/test-saves/class-feedback.json"
var checks := 0
var failures := 0
var ui: Control
var results: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _hit(id: int, target := "enemy", amount := 5, time := 0.8) -> Dictionary:
	return {"event_id": id, "type": "spell_multi" if target == "enemy" else "enemy_attack", "target": target,
		"source_uid": 6 if target == "enemy" else 0, "source_kind": "tide_lances" if target == "enemy" else "enemy",
		"amount": amount, "raw_amount": amount + 2, "armor_mitigated": 2 if target == "hero" else 0, "time": time}

func _run() -> void:
	var fingerprints := {}
	for path in [Save.DEFAULT_PATH, "user://emberpack-run.json"]:
		fingerprints[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	_model()
	root.size = Vector2i(1440, 960)
	ui = load("res://scenes/class_lab.tscn").instantiate()
	ui.persistence_enabled = false
	ui.checkpoint_path = CHECKPOINT
	root.add_child(ui)
	await process_frame
	await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	for variant in ["mage", "greatblade", "sword", "loss"]:
		_integration(variant)
	_lifecycle()
	for path in fingerprints:
		var after := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
		check(after == fingerprints[path], "Player save unchanged: " + path)
	Save.reset_prototype(CHECKPOINT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tools/c1-feedback-review"))
	var report := FileAccess.open("res://.tools/c1-feedback-review/test-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "fixtures": results}, "\t"))
	report.close()
	print("Class feedback: %d checks, %d failures" % [checks, failures])
	ui.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _model() -> void:
	var model := Feedback.new()
	model.show_event({"type": "charge", "amount": 0})
	check(not model.is_active(), "Charge does not invent damage feedback")
	model.show_event(_hit(1))
	model.show_event(_hit(1))
	check(model.numbers.size() == 1 and model.numbers[0].amount == 5 and model.numbers[0].hits == 1, "Replayed event ID is ignored")
	model.show_event(_hit(2))
	model.show_event(_hit(3))
	check(model.numbers.size() == 1 and model.numbers[0].amount == 15 and model.numbers[0].raw == 21 and model.numbers[0].hits == 3, "Three actual segments aggregate exact effective/raw values")
	model.show_event(_hit(4, "hero", 6, 1.8))
	check(model.numbers.size() == 2 and model.numbers[1].armor == 2 and model.hero_hit > 0 and model.enemy_hit > 0, "Incoming hit and engine-provided armor mitigation are distinct")
	model.show_event(_hit(5, "enemy", 2, 2.6))
	check(model.numbers.size() == 3, "Next activation is not merged with old one")
	model.advance(1.0)
	check(not model.is_active() and model.numbers.is_empty(), "Expired numbers/hit state are released")
	for id in range(100, 180):
		model.show_event(_hit(id, "enemy", 1, float(id)))
	check(model.numbers.size() == Feedback.MAX_NUMBERS and model._seen.size() == 64, "Suspended-frame bursts have bounded presentation memory")
	model.show_event({"type": "battle_end", "result": "won"})
	check(model.enemy_exit == 0 and model.hero_exit < 0, "Victory only exits defeated target")
	model.advance(Feedback.EXIT_TIME / 2)
	check(is_equal_approx(model.opacity("enemy"), 0.5) and model.opacity("hero") == 1, "Exit fade has correct halfway opacity")
	model.advance(2)
	check(model.opacity("enemy") == 0 and not model.is_active(), "Exit settles without changing model outcome")
	model.reset()
	model.show_event({"type": "battle_end", "result": "timeout"})
	check(model.hero_exit < 0 and model.enemy_exit < 0, "Timeout does not pretend either living actor died")
	model.reset()
	model.show_event({"type": "battle_end", "result": "lost"})
	check(model.hero_exit == 0 and model.enemy_exit < 0, "Defeat only exits the hero")
	model.reset()
	check(model.report().outcome == "" and not model.is_active() and model.opacity("hero") == 1, "Reset restores fully visible clean state")

func _integration(variant: String) -> void:
	ui._new_class("mage" if variant in ["mage", "loss"] else "knight")
	if variant == "mage":
		for action in [[0, Vector2i.ZERO], [1, Vector2i(3, 2)], [2, Vector2i(3, 2)]]:
			check(ui.run.acquire(action[0], action[1]).ok, "Mage uses finite legal acquisition")
	elif variant == "greatblade":
		check(ui.run.acquire(1, Vector2i.ZERO).ok, "Heavy uses real recipe")
		check(ui.run.acquire(1, Vector2i(2, 1)).ok, "Heavy uses finite support")
	elif variant == "loss":
		check(ui.run.discard(int(ui.run.item_at(Vector2i.ZERO).uid)).ok, "Loss fixture legally discards one starter attack")
		check(ui.run.hp == 84 and ui.run.get_combat_config().actions.size() == 1, "Loss fixture retains actual health and one legal attack")
	ui.speed = 1
	ui._sync()
	var reference := Battle.new()
	check(reference.start(ui.run.get_combat_config()).ok, variant + " independent engine starts")
	ui._start_battle()
	var paused_once := false
	var saw_hero_hit := false
	var saw_enemy_hit := false
	var saw_three := false
	for step in range(2000):
		if ui.battle.phase != "battle":
			break
		ui._process(0.05)
		reference.tick(0.05 * ui.speed)
		var feedback = ui.arena.feedback
		saw_hero_hit = saw_hero_hit or feedback.hero_hit > 0
		saw_enemy_hit = saw_enemy_hit or feedback.enemy_hit > 0
		for number in feedback.numbers:
			saw_three = saw_three or number.hits == 3
		if feedback.hero_hit > 0 and not paused_once and ui.battle.phase == "battle":
			paused_once = true
			ui._pause()
			var before: Dictionary = feedback.report()
			var summary: Dictionary = ui.battle.get_summary().duplicate(true)
			ui._process(1)
			ui.arena._process(1)
			check(feedback.report() == before and ui.battle.get_summary() == summary, variant + " real incoming hit/number/flash pause with rules")
			ui._pause()
			ui._speed()
		ui.arena._process(0.05)
	check(paused_once and saw_hero_hit and saw_enemy_hit, variant + " actual battle contains both incoming and outgoing feedback")
	if variant == "mage":
		check(saw_three, "Actual tide spell displays grouped three-hit result")
	check(ui.battle.get_summary() == reference.get_summary(), variant + " feedback/cutout/pause/speed leave all summary fields unchanged")
	check(ui.arena.feedback.outcome == ("lost" if variant == "loss" else "won"), variant + " end event maps true result")
	ui.arena._process(2)
	check(not ui.arena.has_pending_presentation(), variant + " all result effects settle")
	var target := "hero" if variant == "loss" else "enemy"
	check(ui.arena.feedback.opacity(target) == 0 and ui.arena.feedback.opacity("enemy" if target == "hero" else "hero") == 1, variant + " only defeated side fades")
	results.append({"variant": variant, "summary": ui.battle.get_summary(), "visuals": ui.arena.get_art_report()})
	ui._restore_before_battle()
	check(ui.arena.feedback.report().outcome == "" and not ui.arena.feedback.is_active() and ui.arena.feedback.opacity("hero") == 1, variant + " restore clears terminal fade and numbers")
	# Both speed settings advance the same effect clock as action playback.
	ui.arena.show_event(_hit(999, "hero"))
	ui.speed = 2
	ui._sync()
	ui.arena._process(0.1)
	check(is_equal_approx(ui.arena.feedback.numbers[0].age, 0.2), variant + " 2x advances numbers by twice wall time")
	ui.arena.reset_presentation()

func _lifecycle() -> void:
	ui._new_class("mage")
	check(Save.save_run(ui.run, CHECKPOINT).ok, "Lifecycle uses isolated file")
	ui._new_class("knight")
	ui.arena.show_event(_hit(1, "hero"))
	ui.persistence_enabled = true
	ui._load()
	ui.persistence_enabled = false
	check(ui.run.class_id == "mage" and not ui.arena.feedback.is_active(), "Cross-class load resets incoming hit feedback")
	ui.arena.show_event(_hit(2))
	ui._new_class("knight")
	check(not ui.arena.feedback.is_active() and ui.arena.feedback.numbers.is_empty(), "New class clears old floating numbers")
