extends SceneTree

const Run = preload("res://scripts/gameplay/run_state.gd")
const Save = preload("res://scripts/gameplay/run_save.gd")
const DIRECTORY := "res://.tools/test-saves"
const ROUNDTRIP := DIRECTORY + "/roundtrip.json"
const REWARD := DIRECTORY + "/reward.json"
const INVALID := DIRECTORY + "/invalid.json"
const ATOMIC := DIRECTORY + "/atomic.json"
var checks := 0
var failures := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	_cleanup()
	_test_roundtrip_and_rng()
	_test_reward_roundtrip()
	_test_restricted_phases()
	_test_corruption_is_atomic()
	_test_failed_write_preserves_old_save()
	_test_delete_and_missing()
	_cleanup()
	print("EmberSave: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _test_roundtrip_and_rng() -> void:
	var source = Run.new()
	source.new_run(9223372036854775806)
	check(source.move(source.items[0]["uid"], Vector2i(4, 3), true)["ok"], "Roundtrip setup uses a legal rotated weapon")
	check(source.buy(1, Vector2i(2, 2))["ok"], "Roundtrip setup purchases a healing item")
	var rng: RandomNumberGenerator = source.get("_rng")
	for index in range(7):
		rng.randi()
	var saved := Save.save_run(source, ROUNDTRIP)
	check(saved["ok"] and Save.exists(ROUNDTRIP), "Preparation run saves in the isolated test directory")
	if not saved["ok"]:
		return
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUNDTRIP))
	check(raw["schema_version"] == 1 and raw["items"][0]["pos"] is Dictionary, "JSON stores a version and explicit grid coordinates")
	check(raw["rng"]["seed"] is String and raw["rng"]["seed"] == "9223372036854775806", "64-bit RNG seed is stored as an exact decimal string")
	check(raw["rng"]["state"] is String and raw["rng"]["state"] == str(rng.state), "64-bit RNG state is stored without JSON number precision loss")
	var inspected := Save.inspect_save(ROUNDTRIP)
	check(inspected["ok"] and inspected["wave"] == source.wave and inspected["gold"] == source.gold and inspected["item_count"] == source.items.size(), "Continue metadata is read without loading the active run")
	var target = Run.new()
	target.new_run(41)
	check(Save.load_run(target, ROUNDTRIP)["ok"], "Validated preparation snapshot loads")
	check(_fingerprint(source) == _fingerprint(target), "Every persisted field roundtrips exactly")
	check(target.items[0]["pos"] is Vector2i and target.items[0]["rotated"], "Loaded grid positions and rotation have native types")
	var target_rng: RandomNumberGenerator = target.get("_rng")
	var same_sequence := true
	for index in range(12):
		if rng.randi() != target_rng.randi():
			same_sequence = false
	check(same_sequence, "Resumed RNG continues the exact next random sequence")
	source.reroll()
	target.reroll()
	check(source.shop_offers == target.shop_offers and source.gold == target.gold, "The next paid shop refresh matches an uninterrupted run")
	check(not FileAccess.file_exists(ROUNDTRIP + ".tmp") and not FileAccess.file_exists(ROUNDTRIP + ".bak"), "Successful save leaves no temporary or backup files")
	# Replacing an existing valid file exercises the real rename path on Windows.
	check(Save.save_run(target, ROUNDTRIP)["ok"] and Save.inspect_save(ROUNDTRIP)["gold"] == target.gold, "An existing save is replaced with the latest snapshot")
	rng.seed = "-9223372036854775808".to_int()
	rng.randi()
	check(Save.save_run(source, ROUNDTRIP)["ok"] and Save.load_run(target, ROUNDTRIP)["ok"] and _fingerprint(source) == _fingerprint(target), "Negative 64-bit RNG seed also roundtrips exactly")

func _test_reward_roundtrip() -> void:
	var source = Run.new()
	check(source.start_battle()["ok"], "Reward test starts a real encounter")
	source.tick(90.0)
	check(source.phase == "reward" and source.reward_choices.size() == 3, "Real victory produces three pending blessing choices")
	if source.phase != "reward":
		return
	check(Save.save_run(source, REWARD)["ok"], "Pending reward phase can be saved")
	var target = Run.new()
	target.start_battle()
	target.tick(0.4)
	check(Save.load_run(target, REWARD)["ok"] and _fingerprint(source) == _fingerprint(target), "Loading pending rewards restores their exact choices and RNG")
	check(target.enemy_hp == 0 and target.battle_time == 0.0 and Dictionary(target.get("_weapon_timers")).is_empty(), "Reward load resets transient combat while keeping the defeated enemy")
	var picked: String = source.reward_choices[0]
	var chosen: Dictionary = source.call("choose_reward", 0)
	check(chosen["ok"] and source.reward_chosen and source.reward_choices.is_empty(), "A real blessing choice produces a settled reward state")
	check(Save.save_run(source, REWARD)["ok"] and Save.load_run(target, REWARD)["ok"], "Settled reward phase also roundtrips")
	check(_fingerprint(source) == _fingerprint(target) and picked in target.blessings, "Chosen blessing and its immediate health or coin effects persist")
	source.claim_reward()
	target.claim_reward()
	check(source.phase == "prepare" and _fingerprint(source) == _fingerprint(target), "Resumed reward advances identically to uninterrupted preparation")
	check(Save.save_run(target, REWARD)["ok"], "Preparation with an owned blessing passes validation")

func _test_restricted_phases() -> void:
	var game = Run.new()
	check(Save.save_run(game, ATOMIC)["ok"], "An old save is available for preservation tests")
	var previous := FileAccess.get_file_as_string(ATOMIC)
	for phase in ["battle", "won", "lost"]:
		game.phase = phase
		check(not Save.save_run(game, ATOMIC)["ok"], "Saving %s is rejected" % phase)
		check(FileAccess.get_file_as_string(ATOMIC) == previous, "Rejected %s save leaves the previous file untouched" % phase)
	check(not Save.save_run(null, ATOMIC)["ok"] and not Save.load_run(null, ATOMIC)["ok"], "Null run arguments fail cleanly")
	check(not Save.save_run(RefCounted.new(), ATOMIC)["ok"], "An unrelated object cannot be saved")

func _test_corruption_is_atomic() -> void:
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUNDTRIP))
	for mutation in [
		["schema_version", 99, "unsupported version"],
		["phase", "battle", "in-flight combat phase"],
		["gold", -1, "negative currency"],
		["gold", 1.5, "fractional currency"],
		["wave", 0, "zero encounter"],
		["wave", 99, "unknown encounter"],
		["hp", 1000001, "health above maximum"],
		["hp", 0, "non-living resumable hero"],
		["max_hp", 0, "zero maximum health"],
		["last_reward", -9, "negative reward"],
		["next_uid", 1, "next UID colliding with equipment"],
		["shop_offers", ["sword"], "wrong shop size"],
		["shop_offers", ["sword", "shield", "unknown", ""], "unknown shop offer"],
		["items", "bad", "non-array backpack"],
		["blessings", ["unknown_blessing"], "unknown blessing"],
		["reward_choices", ["vitality", "vitality", "focus"], "duplicate reward choices"],
		["reward_chosen", true, "settled reward during preparation"],
	]:
		var corrupted := valid.duplicate(true)
		corrupted[mutation[0]] = mutation[1]
		_expect_rejected(corrupted, mutation[2])
	for mutation in [
		["kind", "unknown", "unknown equipment"],
		["level", 4, "equipment level above cap"],
		["level", 1.2, "fractional equipment level"],
		["rotated", "false", "string rotation flag"],
		["uid", 0, "non-positive UID"],
		["pos", {"x": -1, "y": 0}, "negative grid position"],
		["pos", {"x": 0.2, "y": 0}, "fractional grid position"],
		["pos", {"x": 5, "y": 3}, "equipment beyond the right edge"],
	]:
		var corrupted := valid.duplicate(true)
		corrupted["items"][0][mutation[0]] = mutation[1]
		_expect_rejected(corrupted, mutation[2])
	var duplicate_uid := valid.duplicate(true)
	duplicate_uid["items"][1]["uid"] = duplicate_uid["items"][0]["uid"]
	_expect_rejected(duplicate_uid, "duplicate equipment UID")
	var overlap := valid.duplicate(true)
	overlap["items"][1]["pos"] = overlap["items"][0]["pos"].duplicate()
	_expect_rejected(overlap, "colliding item footprints")
	var rng_number := valid.duplicate(true)
	rng_number["rng"]["seed"] = 123.0
	_expect_rejected(rng_number, "numeric RNG seed")
	var rng_overflow := valid.duplicate(true)
	rng_overflow["rng"]["state"] = "9223372036854775808"
	_expect_rejected(rng_overflow, "overflowing RNG state")
	var missing := valid.duplicate(true)
	missing.erase("rng")
	_expect_rejected(missing, "missing RNG state")
	var bad_reward := valid.duplicate(true)
	bad_reward["phase"] = "reward"
	bad_reward["reward_choices"] = []
	_expect_rejected(bad_reward, "missing pending reward choices")
	var duplicate_blessing := valid.duplicate(true)
	duplicate_blessing["wave"] = 3
	duplicate_blessing["blessings"] = ["vitality", "vitality"]
	_expect_rejected(duplicate_blessing, "duplicate owned blessing")
	var missing_blessing := valid.duplicate(true)
	missing_blessing["wave"] = 2
	_expect_rejected(missing_blessing, "missing prior encounter blessing")
	var early_blessing := valid.duplicate(true)
	early_blessing["blessings"] = ["vitality"]
	_expect_rejected(early_blessing, "blessing before any encounter victory")
	var malformed := FileAccess.open(INVALID, FileAccess.WRITE)
	malformed.store_string("{ broken JSON")
	malformed.close()
	var game = Run.new()
	var before := _fingerprint(game)
	check(not Save.load_run(game, INVALID)["ok"] and _fingerprint(game) == before, "Malformed JSON does not change the active run")
	check(not Save.inspect_save(INVALID)["ok"], "Continue metadata rejects a malformed file")

func _expect_rejected(payload: Variant, description: String) -> void:
	var file := FileAccess.open(INVALID, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	var game = Run.new()
	game.gold = 123
	var before := _fingerprint(game)
	check(not Save.load_run(game, INVALID)["ok"], "Reject " + description)
	check(_fingerprint(game) == before, "Rejected " + description + " preserves the active run")
	check(not Save.inspect_save(INVALID)["ok"], "Continue preview also rejects " + description)

func _test_failed_write_preserves_old_save() -> void:
	var game = Run.new()
	check(Save.save_run(game, ATOMIC)["ok"], "Atomic failure test has an existing valid save")
	var previous := FileAccess.get_file_as_string(ATOMIC)
	# An empty directory at the temporary filename reliably simulates a write failure.
	check(DirAccess.make_dir_absolute(ATOMIC + ".tmp") == OK, "Temporary-file failure fixture is created inside the project")
	game.gold += 10
	check(not Save.save_run(game, ATOMIC)["ok"], "Temporary write failure is reported")
	check(FileAccess.get_file_as_string(ATOMIC) == previous and Save.inspect_save(ATOMIC)["ok"], "Write failure keeps the previous valid save intact")
	DirAccess.remove_absolute(ATOMIC + ".tmp")
	game.items[1]["pos"] = game.items[0]["pos"]
	check(not Save.save_run(game, ATOMIC)["ok"] and FileAccess.get_file_as_string(ATOMIC) == previous, "Invalid active state cannot overwrite the previous save")
	check(not Save.save_run(Run.new(), "")["ok"], "Empty paths are rejected")

func _test_delete_and_missing() -> void:
	check(Save.delete_save(ATOMIC)["ok"] and not Save.exists(ATOMIC), "Deleting a save removes the isolated file")
	check(Save.delete_save(ATOMIC)["ok"], "Deleting an already missing save is harmless")
	var game = Run.new()
	var before := _fingerprint(game)
	check(not Save.load_run(game, ATOMIC)["ok"] and _fingerprint(game) == before, "Missing save does not alter the active run")
	check(not Save.inspect_save(ATOMIC)["ok"], "Missing save has no continue metadata")

func _fingerprint(game: RefCounted) -> String:
	var data: Dictionary = {}
	for key in ["items", "shop_offers", "gold", "wave", "hp", "max_hp", "phase", "last_reward", "blessings", "reward_choices", "reward_chosen", "_next_uid"]:
		data[key] = game.get(key)
	var rng: RandomNumberGenerator = game.get("_rng")
	data["seed"] = str(rng.seed)
	data["state"] = str(rng.state)
	return var_to_str(data)

func _cleanup() -> void:
	for path in [ROUNDTRIP, REWARD, INVALID, ATOMIC]:
		Save.delete_save(path)
	# Remove only this test's known empty fixture, never recurse through directories.
	if DirAccess.dir_exists_absolute(ATOMIC + ".tmp"):
		DirAccess.remove_absolute(ATOMIC + ".tmp")
