extends SceneTree

const Run = preload("res://scripts/classes/class_run.gd")
const Save = preload("res://scripts/classes/class_save.gd")
const LegacyRun = preload("res://scripts/gameplay/run_state.gd")
const LegacySave = preload("res://scripts/gameplay/run_save.gd")
const DIRECTORY := "res://.tools/test-saves"
const MAGE := DIRECTORY + "/classes-save-mage.json"
const KNIGHT := DIRECTORY + "/classes-save-knight.json"
const INVALID := DIRECTORY + "/classes-save-invalid.json"
const ATOMIC := DIRECTORY + "/classes-save-atomic.json"
const RESET := DIRECTORY + "/classes-save-reset.json"
const LEGACY := DIRECTORY + "/classes-legacy/emberpack-run.json"
const LEGACY_OTHER := DIRECTORY + "/classes-save-legacy-copy.json"
var checks := 0
var failures := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY + "/classes-legacy"))
	_cleanup()
	_test_roundtrips_and_resource_replay()
	_test_restricted_phases()
	_test_invalid_documents_are_atomic()
	_test_legacy_and_future_files_are_preserved()
	_test_failed_write_preserves_old_file()
	_test_explicit_reset_with_backup()
	_cleanup()
	print("ClassSave C0: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _test_roundtrips_and_resource_replay() -> void:
	check(Save.DEFAULT_PATH == "user://class-prototype-run.json" and Save.DEFAULT_PATH != LegacySave.DEFAULT_PATH, "Experimental checkpoints have a separate default filename")
	var mage = Run.new()
	mage.new_run("mage", 9223372036854775806)
	check(mage.acquire(0, Vector2i(0, 0))["ok"], "Mage first limited fire source weaves a real flame glyph")
	check(mage.acquire(1, Vector2i(3, 2))["ok"] and mage.acquire(2, Vector2i(3, 2))["ok"], "Mage collects and combines water and wind into a real multihit spell")
	check(mage.acquire(0, Vector2i(0, 2))["ok"], "Mage exhausts the second fire charge through the normal acquisition API")
	var spare := mage.acquire(1, Vector2i(3, 3))
	check(spare["ok"] and mage.discard(int(spare.get("uid", -1)))["ok"], "Discarded raw ingredients remain in the resource ledger")
	check(mage.move(3, Vector2i(2, 1), true)["ok"], "Mage directional support is rotated before the checkpoint")
	check(Save.save_run(mage, MAGE)["ok"], "Legitimate mage preparation saves")
	var knight = Run.new()
	knight.new_run("knight", "-9223372036854775808".to_int())
	check(knight.acquire(1, Vector2i.ZERO)["ok"], "Knight pays for an actual greatblade forge")
	check(knight.acquire(1, Vector2i(2, 1))["ok"], "Knight buys the second finite support seal")
	var ward := knight.acquire(2, Vector2i(4, 3))
	check(ward["ok"] and knight.discard(int(ward.get("uid", -1)))["ok"], "Paid discarded armor does not refund gold or source stock")
	check(knight.move(2, Vector2i(4, 0), true)["ok"], "Knight non-square armor has a legal rotated footprint")
	check(Save.save_run(knight, KNIGHT)["ok"], "Legitimate knight preparation saves")
	for entry in [[mage, MAGE, "9223372036854775806", 0], [knight, KNIGHT, "-9223372036854775808", 1]]:
		var original: RefCounted = entry[0]
		var path: String = entry[1]
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(raw["kind"] == "class-prototype" and raw["schema_version"] == 1 and raw["rules_version"] == 1, "Class checkpoint has an independent discriminator and version pair")
		check(raw["seed"] is String and raw["seed"] == entry[2], "Signed 64-bit seed survives JSON as an exact decimal string")
		check(raw["items"][0]["pos"] is Array and raw["items"][0]["pos"].size() == 2, "Grid positions serialize as explicit coordinate pairs")
		var inspected := Save.inspect_save(path)
		check(inspected["ok"] and inspected["class_id"] == original.get("class_id") and inspected["item_count"] == original.get("items").size(), "Continue preview reports the saved class and item count")
		var target = Run.new()
		target.new_run("knight" if original.get("class_id") == "mage" else "mage", 1)
		target.phase = "battle"
		check(Save.load_run(target, path)["ok"], "Complete checkpoint validation permits loading into another active class")
		check(_fingerprint(target) == _fingerprint(original), "All preparation fields roundtrip exactly, including discarded components")
		check(target.phase == "prepare" and target.items[0]["pos"] is Vector2i, "Loading resets battle phase and reconstructs native grid coordinates")
		var before := _fingerprint(target)
		check(not target.acquire(int(entry[3]), Vector2i(5, 3))["ok"] and _fingerprint(target) == before, "Reload does not replenish an exhausted source")
		check(Save.save_run(target, path)["ok"], "A second valid checkpoint atomically replaces the first")
		check(not FileAccess.file_exists(path + ".tmp") and not FileAccess.file_exists(path + ".bak"), "Successful replacement removes its own temporary sidecars")

func _test_restricted_phases() -> void:
	var run = Run.new()
	run.new_run("mage")
	check(Save.save_run(run, ATOMIC)["ok"], "Phase preservation fixture is a valid independent checkpoint")
	var previous := FileAccess.get_file_as_string(ATOMIC)
	for phase in ["battle", "won", "lost", "reward", ""]:
		run.phase = phase
		check(not Save.save_run(run, ATOMIC)["ok"], "Cannot save non-preparation phase " + phase)
		check(FileAccess.get_file_as_string(ATOMIC) == previous, "Rejected phase leaves old checkpoint bytes intact")
	check(not Save.save_run(null, ATOMIC)["ok"] and not Save.load_run(null, ATOMIC)["ok"], "Null run arguments fail cleanly")
	check(not Save.save_run(LegacyRun.new(), ATOMIC)["ok"] and not Save.load_run(LegacyRun.new(), ATOMIC)["ok"], "Legacy run objects cannot be passed as experimental runs")
	check(not Save.save_run(RefCounted.new(), ATOMIC)["ok"], "Unrelated objects cannot be saved")

func _test_invalid_documents_are_atomic() -> void:
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAGE))
	for mutation in [
		["schema_version", 2, "future schema"], ["rules_version", 2, "future rules"],
		["schema_version", 1.5, "fractional schema"], ["kind", "other", "unknown discriminator"],
		["class_id", "alchemist", "unimplemented class"], ["class_id", 1, "non-string class"],
		["phase", "battle", "in-flight combat"], ["phase", "reward", "unsupported reward phase"],
		["gold", -1, "negative gold"], ["gold", 1000000, "fabricated gold"], ["gold", 0.5, "fractional gold"],
		["max_hp", 999, "fabricated health capacity"], ["hp", 0, "dead preparation"], ["hp", 83, "post-combat hp in preparation-only schema"],
		["seed", 123, "numeric seed with precision risk"], ["seed", "9223372036854775808", "overflowing positive seed"],
		["seed", "-9223372036854775809", "overflowing negative seed"], ["seed", "01", "noncanonical seed"],
		["seed", " 42", "whitespace seed"], ["seed", "+42", "signed positive seed"], ["seed", "1.0", "fractional seed string"],
		["next_uid", 1, "colliding next UID"], ["next_uid", 1000000, "fabricated UID counter"],
		["items", {}, "non-array items"], ["sources", [], "missing source slots"],
		["discarded_materials", {}, "erased discard history"], ["discarded_materials", {"water_mote": -1}, "negative discarded quantity"],
		["discarded_materials", {"water_mote": 100}, "fabricated discarded quantity"],
		["discarded_materials", {"unknown": 1}, "unknown discarded material"],
	]:
		var corrupt := valid.duplicate(true)
		corrupt[mutation[0]] = mutation[1]
		_expect_rejected(corrupt, mutation[2])
	for mutation in [
		["kind", "missing", "unknown item"], ["kind", "greatblade", "foreign class item"],
		["uid", 0, "zero UID"], ["uid", 0.5, "fractional UID"], ["uid", 1000000, "UID above counter"],
		["rotated", "false", "non-boolean rotation"], ["pos", {"x": 0, "y": 0}, "wrong coordinate representation"],
		["pos", [-1, 0], "negative cell"], ["pos", [0.5, 0], "fractional cell"],
		["pos", [6, 0], "off-grid origin"], ["pos", [5, 3], "footprint crossing grid bounds"],
	]:
		var corrupt := valid.duplicate(true)
		corrupt["items"][0][mutation[0]] = mutation[1]
		_expect_rejected(corrupt, mutation[2])
	for mutation in [
		["id", "unknown", "unknown source ID"], ["kind", "water_mote", "substituted source type"],
		["cost", -1, "negative source cost"], ["cost", 1, "altered source cost"],
		["remaining", 3, "source stock over cap"], ["remaining", -1, "negative source stock"],
		["remaining", 0.5, "fractional source stock"], ["remaining", 2, "replayed exhausted source"],
	]:
		var corrupt := valid.duplicate(true)
		corrupt["sources"][0][mutation[0]] = mutation[1]
		_expect_rejected(corrupt, mutation[2])
	var duplicate := valid.duplicate(true)
	duplicate["items"][1]["uid"] = duplicate["items"][0]["uid"]
	_expect_rejected(duplicate, "duplicate item UID")
	var overlap := valid.duplicate(true)
	overlap["items"][1]["pos"] = overlap["items"][0]["pos"].duplicate()
	_expect_rejected(overlap, "overlapping occupied cells")
	var source_duplicate := valid.duplicate(true)
	source_duplicate["sources"][1]["id"] = source_duplicate["sources"][0]["id"]
	_expect_rejected(source_duplicate, "duplicate source IDs")
	var coordinated_replay := valid.duplicate(true)
	coordinated_replay["sources"][0]["remaining"] = 2
	coordinated_replay["next_uid"] -= 2
	_expect_rejected(coordinated_replay, "source refill with a matching forged acquisition counter")
	var missing := valid.duplicate(true)
	missing.erase("seed")
	_expect_rejected(missing, "missing required seed")
	var forged_product := valid.duplicate(true)
	forged_product["items"][0]["kind"] = "tide_lances"
	_expect_rejected(forged_product, "legal-class product with forged ingredient provenance")
	var knight: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(KNIGHT))
	knight["gold"] += 1
	_expect_rejected(knight, "gold inconsistent with exact paid acquisition")
	_write_text(INVALID, "{ broken JSON")
	_expect_file_rejected("malformed JSON")
	_write_text(INVALID, JSON.stringify(valid).replace('"gold":0', '"gold":1e999'))
	_expect_file_rejected("non-finite or overflowing JSON number")
	_write_text(INVALID, " ".repeat(Save.MAX_SAVE_BYTES + 1))
	_expect_file_rejected("oversized input")
	for empty_root in [null, [], 42, "save"]:
		_expect_rejected(empty_root, "invalid root type")

func _test_legacy_and_future_files_are_preserved() -> void:
	var legacy = LegacyRun.new()
	check(LegacySave.save_run(legacy, LEGACY)["ok"], "Real schema 1 legacy fixture is written only under .tools/test-saves")
	var bytes := FileAccess.get_file_as_string(LEGACY)
	var classification := Save.classify_document(JSON.parse_string(bytes))
	check(not classification["ok"] and classification["classification"] == "legacy", "Kindless schema 1 is recognized without automatic class mapping")
	var run = Run.new()
	run.new_run("knight")
	var before := _fingerprint(run)
	check(not Save.load_run(run, LEGACY)["ok"] and _fingerprint(run) == before, "Loading legacy data does not mutate a class run")
	check(not Save.save_run(run, LEGACY)["ok"] and not Save.reset_prototype(LEGACY)["ok"], "Experimental save and reset reject the legacy filename")
	check(FileAccess.get_file_as_string(LEGACY) == bytes, "Original legacy bytes survive all attempted class operations")
	_write_text(LEGACY_OTHER, bytes)
	check(not Save.save_run(run, LEGACY_OTHER)["ok"] and not Save.reset_prototype(LEGACY_OTHER)["ok"], "Renaming a legacy file does not bypass format protection")
	check(FileAccess.get_file_as_string(LEGACY_OTHER) == bytes, "Renamed legacy fixture remains unchanged")
	for mutation in [["schema_version", 99], ["rules_version", 99], ["class_id", "unknown"]]:
		var future: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAGE))
		future[mutation[0]] = mutation[1]
		_write_text(INVALID, JSON.stringify(future))
		var previous := FileAccess.get_file_as_string(INVALID)
		check(not Save.save_run(run, INVALID)["ok"] and not Save.reset_prototype(INVALID)["ok"], "Unknown versions and classes cannot be silently replaced or reset")
		check(FileAccess.get_file_as_string(INVALID) == previous, "Unrecognized checkpoint bytes are preserved")
	_write_text(INVALID, "not JSON")
	check(not Save.save_run(run, INVALID)["ok"] and FileAccess.get_file_as_string(INVALID) == "not JSON", "Corrupt content is never overwritten by a new run")

func _test_failed_write_preserves_old_file() -> void:
	var run = Run.new()
	run.new_run("knight")
	check(Save.save_run(run, ATOMIC)["ok"], "Atomic failure test begins with an existing valid checkpoint")
	var previous := FileAccess.get_file_as_string(ATOMIC)
	check(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(ATOMIC + ".tmp")) == OK, "Known empty directory blocks the temporary filename")
	check(run.acquire(1, Vector2i.ZERO)["ok"], "A legal edit makes the new snapshot different")
	check(not Save.save_run(run, ATOMIC)["ok"] and FileAccess.get_file_as_string(ATOMIC) == previous, "Temporary write obstruction preserves old checkpoint bytes")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ATOMIC + ".tmp"))
	_write_text(ATOMIC + ".bak", "external recovery content")
	check(not Save.save_run(run, ATOMIC)["ok"] and FileAccess.get_file_as_string(ATOMIC) == previous, "An existing recovery sidecar prevents destructive replacement")
	check(FileAccess.get_file_as_string(ATOMIC + ".bak") == "external recovery content", "Unknown recovery sidecar is preserved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ATOMIC + ".bak"))
	run.items[1]["pos"] = run.items[0]["pos"]
	check(not Save.save_run(run, ATOMIC)["ok"] and FileAccess.get_file_as_string(ATOMIC) == previous, "Invalid in-memory grid cannot overwrite a valid checkpoint")
	run.new_run("knight")
	for path in ["", " ", DIRECTORY + "/", DIRECTORY, DIRECTORY + "/classes-save-alias.json.", DIRECTORY + "/classes-save-alias.json ", DIRECTORY + "/classes-save-alias.json:stream", DIRECTORY + "/classes-legacy/emberpack-run.json."]:
		check(not Save.save_run(run, path)["ok"], "Empty or directory paths fail safely")
	check(not Save.save_run(run, ATOMIC + "/child.json")["ok"] and FileAccess.get_file_as_string(ATOMIC) == previous, "A file blocking the parent directory preserves the original checkpoint")
	check(not Save.load_run(run, DIRECTORY + "/classes-save-missing.json")["ok"], "Missing checkpoint reports failure")

func _test_explicit_reset_with_backup() -> void:
	var run = Run.new()
	run.new_run("mage")
	check(Save.save_run(run, RESET)["ok"], "Reset fixture is a valid class checkpoint")
	var previous := FileAccess.get_file_as_string(RESET)
	var reset := Save.reset_prototype(RESET)
	check(reset["ok"] and not FileAccess.file_exists(RESET), "Explicit reset removes only a validated experimental checkpoint")
	check(FileAccess.get_file_as_string(RESET + ".reset.bak") == previous, "Reset leaves an exact recoverable old snapshot")
	check(Save.save_run(run, RESET)["ok"], "A new class run can occupy the reset path")
	check(Save.reset_prototype(RESET)["ok"] and FileAccess.get_file_as_string(RESET + ".reset.bak") == previous and FileAccess.file_exists(RESET + ".reset-1.bak"), "Repeated explicit reset does not overwrite the first backup")
	check(Save.reset_prototype(RESET)["ok"], "Resetting an already absent class checkpoint is harmless")

func _expect_rejected(payload: Variant, description: String) -> void:
	_write_text(INVALID, JSON.stringify(payload))
	_expect_file_rejected(description)

func _expect_file_rejected(description: String) -> void:
	var target = Run.new()
	target.new_run("knight", 91)
	target.acquire(1, Vector2i.ZERO)
	var before := _fingerprint(target)
	var source_before := FileAccess.get_file_as_string(INVALID)
	check(not Save.load_run(target, INVALID)["ok"], "Reject " + description)
	check(_fingerprint(target) == before, "Rejecting " + description + " leaves all run fields unchanged")
	check(not Save.inspect_save(INVALID)["ok"] and FileAccess.get_file_as_string(INVALID) == source_before, "Preview rejection preserves original bytes for " + description)

func _write_text(path: String, source: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		check(false, "Fixture file can be written: " + path)
		return
	file.store_string(source)
	file.close()

func _fingerprint(run: RefCounted) -> String:
	var data: Dictionary = {}
	for field in ["class_id", "items", "sources", "gold", "hp", "max_hp", "phase", "seed_value", "_next_uid", "discarded_materials"]:
		data[field] = run.get(field)
	return var_to_str(data)

func _cleanup() -> void:
	for path in [MAGE, KNIGHT, INVALID, ATOMIC, RESET, LEGACY, LEGACY_OTHER]:
		for suffix in ["", ".tmp", ".bak", ".reset.bak", ".reset-1.bak"]:
			var absolute := ProjectSettings.globalize_path(path + suffix)
			if FileAccess.file_exists(absolute):
				DirAccess.remove_absolute(absolute)
	# Remove only this known empty obstruction fixture, never recurse through directories.
	if DirAccess.dir_exists_absolute(ATOMIC + ".tmp"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ATOMIC + ".tmp"))
