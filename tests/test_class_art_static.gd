extends SceneTree
## Native static-art integration checks. These are not animation or full RV-03 acceptance.

const SCENE := "res://scenes/class_lab.tscn"
const Save = preload("res://scripts/classes/class_save.gd")
const Battle = preload("res://scripts/classes/class_battle.gd")
const TEST_SAVE := "res://.tools/test-saves/class-art-static.json"
const REPORT := "res://.tools/c1-static-review/test-report.json"
const PLAYER_PATHS := ["user://class-prototype-run.json", "user://emberpack-run.json"]
const ASSET_ROOT := "res://assets/art/c1-static-v1/"
const SOURCES := [
	{"file": "characters/mage-idle.png", "transparent": true},
	{"file": "characters/knight-sword-idle.png", "transparent": true},
	{"file": "characters/knight-greatblade-idle.png", "transparent": true},
	{"file": "environments/moon-court.png", "transparent": false},
	{"file": "environments/reliquary-hall.png", "transparent": false},
]
var checks := 0
var failures := 0
var ui: Control
var player_fingerprints := {}
var source_measurements: Array[Dictionary] = []
var layout_measurements: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for path in PLAYER_PATHS:
		player_fingerprints[path] = _fingerprint(path)
	_test_sources()
	root.size = Vector2i(1440, 960)
	var scene: PackedScene = load(SCENE)
	if scene == null:
		push_error("Static-art check cannot load the class laboratory")
		quit(1)
		return
	ui = scene.instantiate()
	ui.set("persistence_enabled", false)
	ui.set("checkpoint_path", TEST_SAVE)
	root.add_child(ui)
	await _settle()
	ui.set_process(false)
	ui.arena.set_process(false)
	if not ui.arena.has_method("get_art_layout"):
		push_error("Static-art geometry report is unavailable")
		ui.queue_free()
		await process_frame
		quit(1)
		return
	await _test_mapping_and_lifecycle()
	for path in PLAYER_PATHS:
		check(_fingerprint(path) == player_fingerprints[path], "Art integration never changes player checkpoint: " + path)
	var cleaned: Dictionary = Save.reset_prototype(TEST_SAVE)
	check(cleaned.ok and not FileAccess.file_exists(TEST_SAVE), "Only the isolated art-test checkpoint is removed")
	_write_report()
	print("Class static art: %d checks, %d failures" % [checks, failures])
	ui.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _settle() -> void:
	for _frame in range(4):
		await process_frame

func _fingerprint(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func _state() -> Dictionary:
	return {"class_id": ui.run.class_id, "items": ui.run.items.duplicate(true),
		"sources": ui.run.sources.duplicate(true), "gold": ui.run.gold,
		"hp": ui.run.hp, "max_hp": ui.run.max_hp, "phase": ui.run.phase,
		"next_uid": ui.run._next_uid, "discarded": ui.run.discarded_materials.duplicate(true),
		"seed": ui.run.seed_value, "battle": ui.battle.get_summary().duplicate(true)}

func _test_sources() -> void:
	for source in SOURCES:
		var path: String = ASSET_ROOT + source.file
		var picture := Image.load_from_file(path) if FileAccess.file_exists(path) else null
		check(picture != null and not picture.is_empty(), source.file + " is a decodable source PNG")
		if picture == null or picture.is_empty():
			continue
		picture.convert(Image.FORMAT_RGBA8)
		var data: PackedByteArray = picture.get_data()
		var zero := 0
		var partial := 0
		var opaque := 0
		var alpha_min := 255
		var alpha_max := 0
		var solid_min := picture.get_size()
		var solid_max := Vector2i(-1, -1)
		var solid_count := 0
		for index in range(3, data.size(), 4):
			var alpha: int = data[index]
			if alpha == 0:
				zero += 1
			elif alpha == 255:
				opaque += 1
			else:
				partial += 1
			if alpha > 0:
				alpha_min = mini(alpha_min, alpha)
			alpha_max = maxi(alpha_max, alpha)
			if alpha >= 128:
				var pixel: int = index >> 2
				var point := Vector2i(pixel % picture.get_width(), floori(float(pixel) / picture.get_width()))
				solid_min.x = mini(solid_min.x, point.x)
				solid_min.y = mini(solid_min.y, point.y)
				solid_max.x = maxi(solid_max.x, point.x)
				solid_max.y = maxi(solid_max.y, point.y)
				solid_count += 1
		var visible: Rect2i = picture.get_used_rect()
		var solid := Rect2i(solid_min, solid_max - solid_min + Vector2i.ONE) if solid_count > 0 else Rect2i()
		check(visible.has_area() and Rect2i(Vector2i.ZERO, picture.get_size()).encloses(visible), source.file + " has measurable visible content inside its source canvas")
		if source.transparent:
			check(zero > 0 and partial + opaque > 0, source.file + " contains actual transparent negative space and a visible character")
		else:
			check(zero == 0 and opaque == picture.get_width() * picture.get_height(), source.file + " is an opaque background without transparent holes")
		source_measurements.append({"file": source.file, "source_size": [picture.get_width(), picture.get_height()],
			"nonzero_alpha_rect": _rect(visible), "transparent_pixels": zero, "partial_pixels": partial,
			"opaque_pixels": opaque, "minimum_nonzero_alpha": alpha_min, "maximum_alpha": alpha_max,
			"alpha_ge_128_rect": _rect(solid), "alpha_ge_128_pixels": solid_count,
			"sha256": FileAccess.get_sha256(path)})
	if source_measurements.size() == SOURCES.size():
		check(source_measurements[3].sha256 != source_measurements[4].sha256, "Mage and knight backgrounds are distinct source images")

func _layout(expected_hero: String, expected_background: String) -> Dictionary:
	var before := _state()
	var report: Dictionary = ui.arena.get_art_layout()
	check(report.get("hero_id", "missing") == expected_hero and report.get("background_id", "missing") == expected_background,
		"Actual build selects " + expected_hero + " and " + expected_background)
	check(report.get("assets_ready", false) and report.get("missing_assets", ["unknown"]).is_empty(), "Selected source assets are ready")
	ui.arena.queue_redraw()
	check(_state() == before, "Reading visual geometry and queuing a draw never changes sources or battle statistics")
	return report

func _new_class(id: String) -> void:
	ui.class_buttons[id].pressed.emit()
	ui.arena.set_process(false)
	await _settle()

func _acquire(index: int, cell: Vector2i) -> void:
	var result: Dictionary = ui.run.acquire(index, cell)
	check(result.ok, "Static-art fixture uses a legal finite acquisition at " + str(cell))
	ui._sync()

func _test_mapping_and_lifecycle() -> void:
	await _new_class("mage")
	_layout("mage-idle", "moon-court")
	_acquire(0, Vector2i.ZERO)
	_acquire(1, Vector2i(3, 2))
	_acquire(2, Vector2i(3, 2))
	await _test_layouts("mage-idle", "moon-court")
	var saved := Save.save_run(ui.run, TEST_SAVE)
	check(saved.ok, "Mage preparation is written only to the explicit isolated checkpoint")
	var saved_mage: Array[Dictionary] = ui.run.items.duplicate(true)
	await _finish_and_compare("mage", "mage-idle", "moon-court")
	ui.replay_button.pressed.emit()
	_layout("mage-idle", "moon-court")
	await _new_class("knight")
	_layout("knight-sword-idle", "reliquary-hall")
	await _test_layouts("knight-sword-idle", "reliquary-hall")
	var discarded: Dictionary = ui.run.discard(int(ui.run.item_at(Vector2i.ZERO).uid))
	check(discarded.ok, "An actual weapon may be discarded before testing unarmed presentation")
	ui._sync()
	var unarmed := _layout("", "reliquary-hall")
	check(not Rect2(unarmed.get("hero_rect", Rect2())).has_area(), "A weaponless build does not show a baked sword or greatblade")
	await _new_class("knight")
	_acquire(1, Vector2i.ZERO)
	_acquire(1, Vector2i(2, 1))
	_layout("knight-greatblade-idle", "reliquary-hall")
	await _test_layouts("knight-greatblade-idle", "reliquary-hall")
	await _finish_and_compare("knight", "knight-greatblade-idle", "reliquary-hall")
	ui.replay_button.pressed.emit()
	_layout("knight-greatblade-idle", "reliquary-hall")
	ui.persistence_enabled = true
	ui._load()
	ui.persistence_enabled = false
	ui._sync()
	check(ui.run.class_id == "mage" and ui.run.items == saved_mage and ui._before_battle.is_empty(), "Cross-class load restores the saved build and clears knight transient state")
	_layout("mage-idle", "moon-court")
	await _new_class("knight")
	_layout("knight-sword-idle", "reliquary-hall")

func _finish_and_compare(id: String, expected_hero: String, expected_background: String) -> void:
	var before: Dictionary = ui.run.get_combat_config().duplicate(true)
	var reference := Battle.new()
	var started: Dictionary = reference.start(before)
	check(started.ok, id + " reference engine accepts the legal art fixture build")
	ui._start_battle()
	_layout(expected_hero, expected_background)
	for step in range(2000):
		if ui.run.phase != "battle":
			break
		if step % 20 == 0:
			ui.arena.get_art_layout()
			ui.arena.queue_redraw()
		reference.tick(0.05)
		ui._process(0.05)
	check(ui.battle.get_summary() == reference.get_summary(), id + " art and event display leave the independent deterministic engine result unchanged")
	var old_report = JSON.parse_string(FileAccess.get_file_as_string("res://docs/devlog/screenshots/c0-class-rules-v1/" + id + "-report.json"))
	# JSON does not retain GDScript's typed arrays and integer representation.
	var current_json = JSON.parse_string(JSON.stringify(ui.battle.get_summary()))
	check(old_report is Dictionary and current_json == old_report.get("summary", {}), id + " legal fixture still matches the recorded C0 result in every serialized summary field")
	_layout(expected_hero, expected_background)

func _test_layouts(hero: String, background: String) -> void:
	for dimensions in [Vector2i(1280, 800), Vector2i(1440, 960), Vector2i(1920, 1080)]:
		var before := _state()
		root.size = dimensions
		await _settle()
		var label := "%s %dx%d" % [hero, dimensions.x, dimensions.y]
		var report: Dictionary = ui.arena.get_art_layout()
		var viewport := Rect2(Vector2.ZERO, Vector2(dimensions))
		var stage: Rect2 = report.get("stage_rect", Rect2())
		var scene: Rect2 = report.get("scene_rect", Rect2())
		var actor: Rect2 = report.get("hero_rect", Rect2())
		var enemy: Rect2 = report.get("enemy_rect", Rect2())
		var source: Rect2 = report.get("source_rect", Rect2())
		var source_size: Vector2i = report.get("source_size", Vector2i.ZERO)
		var background_source: Rect2 = report.get("background_source_rect", Rect2())
		var background_size: Vector2i = report.get("background_source_size", Vector2i.ZERO)
		check(report.get("hero_id", "") == hero and report.get("background_id", "") == background and report.get("assets_ready", false), label + " resize preserves loaded visual identity")
		check(viewport.grow(0.1).encloses(ui.arena.get_global_rect()) and viewport.grow(0.1).encloses(ui.grid.get_global_rect())
			and not ui.arena.get_global_rect().intersects(ui.grid.get_global_rect()), label + " stage and complete board fit the native viewport without overlap")
		check(stage.grow(0.1).encloses(scene) and scene.grow(0.1).encloses(actor) and scene.grow(0.1).encloses(enemy)
			and not actor.intersects(enemy) and actor.size.y >= 128, label + " complete actor/weapon and training target fit the standing area separately")
		var hud_clear := not actor.intersects(report.get("phase_rect", Rect2()))
		for rect in report.get("health_rects", []):
			hud_clear = hud_clear and not actor.intersects(rect) and not enemy.intersects(rect)
		check(hud_clear, label + " health and phase information do not cover character or weapon")
		check(source.has_area() and Rect2(Vector2.ZERO, Vector2(source_size)).encloses(source)
			and actor.has_area() and is_equal_approx(source.size.aspect(), actor.size.aspect())
			and is_equal_approx(actor.end.y, float(report.get("ground_y", -1))), label + " destination preserves source aspect and rests at the measured ground line")
		check(background_source.has_area() and Rect2(Vector2.ZERO, Vector2(background_size)).grow(0.1).encloses(background_source)
			and is_equal_approx(background_source.size.aspect(), scene.size.aspect()), label + " background uses a contained uniform cover crop instead of distortion")
		check(viewport.grow(0.1).encloses(ui.primary_button.get_global_rect()) and ui.primary_button.size.y >= 40
			and ui.detail_label.get_theme_font_size("font_size") >= 16 and ui.primary_button.get_theme_font_size("font_size") >= 16,
			label + " primary action and native body text remain usable")
		check(_state() == before, label + " settling and reading the layout does not alter gameplay")
		layout_measurements.append({"viewport": [dimensions.x, dimensions.y], "hero_id": hero,
			"background_id": background, "source_rect": _rect(source), "hero_rect": _rect(actor),
			"stage_rect": _rect(stage), "scene_rect": _rect(scene), "enemy_rect": _rect(enemy),
			"ground_y": report.get("ground_y"), "source_size": [source_size.x, source_size.y],
			"background_source_rect": _rect(background_source), "background_source_size": [background_size.x, background_size.y]})
	root.size = Vector2i(1440, 960)
	await _settle()

func _rect(value) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]

func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"test": "native static-art integration; no animation acceptance",
			"checks": checks, "failures": failures, "source_measurements": source_measurements,
			"layout_measurements": layout_measurements}, "\t", true))
