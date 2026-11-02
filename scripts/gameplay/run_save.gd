class_name EmberSave
extends RefCounted
## Validated JSON snapshots. Only preparation and reward screens are resumable.

const Rules = preload("res://scripts/gameplay/run_state.gd")
const DEFAULT_PATH := "user://emberpack-run.json"
const SCHEMA_VERSION := 1
const MAX_SAVE_BYTES := 1024 * 1024
const NUMBER_LIMIT := 1000000000

static func save_run(game: RefCounted, path: String = DEFAULT_PATH) -> Dictionary:
	if not game is Rules:
		return _failure("保存できません：無効な遠征です。")
	if game.get("phase") not in ["prepare", "reward"]:
		return _failure("準備または報酬の画面で保存してください。")
	var snapshot := _snapshot(game)
	if not snapshot["ok"]:
		return snapshot
	var validation := _validate(snapshot["data"])
	if not validation["ok"]:
		return validation
	var absolute_path := _absolute_path(path)
	if absolute_path.is_empty() or DirAccess.dir_exists_absolute(absolute_path):
		return _failure("保存先が無効です。")
	var error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if error != OK:
		return _failure("保存フォルダーを作成できません（%s）。" % error_string(error))
	var temporary_path := absolute_path + ".tmp"
	var backup_path := absolute_path + ".bak"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return _failure("一時データを書き込めません（%s）。" % error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(snapshot["data"], "\t", true))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		_remove_file(temporary_path)
		return _failure("保存に失敗しました。元データは保持されます。")
	# Keep a recoverable old copy even on filesystems whose replacement may fail.
	var had_previous := FileAccess.file_exists(absolute_path)
	if had_previous:
		error = DirAccess.copy_absolute(absolute_path, backup_path)
		if error != OK:
			_remove_file(temporary_path)
			return _failure("バックアップできません。元データは保持されます。")
	error = DirAccess.rename_absolute(temporary_path, absolute_path)
	if error != OK:
		if had_previous and not FileAccess.file_exists(absolute_path):
			DirAccess.copy_absolute(backup_path, absolute_path)
		_remove_file(temporary_path)
		return _failure("保存データを置き換えられません。元データまたは .bak は保持されます。")
	_remove_file(backup_path)
	return {"ok": true, "message": "遠征を保存しました。", "path": path}

static func load_run(game: RefCounted, path: String = DEFAULT_PATH) -> Dictionary:
	if not game is Rules:
		return _failure("読込できません：無効な遠征です。")
	var loaded := _read_validated(path)
	if not loaded["ok"]:
		return loaded
	# No mutation occurs until every field, item, and reward has passed validation.
	var data: Dictionary = loaded["data"]
	for field in ["items", "shop_offers", "gold", "wave", "hp", "max_hp", "phase", "last_reward", "blessings", "reward_choices", "reward_chosen"]:
		game.set(field, data[field])
	game.set("_next_uid", data["next_uid"])
	var rng: RandomNumberGenerator = game.get("_rng")
	rng.seed = data["rng"]["seed"]
	rng.state = data["rng"]["state"]
	game.set("battle_time", 0.0)
	game.set("battle_duration", 0.0)
	game.set("_accumulator", 0.0)
	game.set("_weapon_timers", {})
	game.set("_potion_used", {})
	game.set("_battle_stats", {})
	game.call("_set_enemy")
	if data["phase"] == "reward":
		game.set("enemy_hp", 0)
	return {"ok": true, "message": "保存した遠征を再開しました。", "wave": data["wave"], "phase": data["phase"]}

static func inspect_save(path: String = DEFAULT_PATH) -> Dictionary:
	var loaded := _read_validated(path)
	if not loaded["ok"]:
		return loaded
	var data: Dictionary = loaded["data"]
	return {
		"ok": true, "message": "遠征を再開できます。", "schema_version": SCHEMA_VERSION,
		"wave": data["wave"], "gold": data["gold"], "hp": data["hp"],
		"max_hp": data["max_hp"], "phase": data["phase"],
		"item_count": data["items"].size(), "blessings": data["blessings"].duplicate(),
		"reward_chosen": data["reward_chosen"], "path": path,
	}

static func exists(path: String = DEFAULT_PATH) -> bool:
	var absolute_path := _absolute_path(path)
	return not absolute_path.is_empty() and FileAccess.file_exists(absolute_path)

static func delete_save(path: String = DEFAULT_PATH) -> Dictionary:
	var absolute_path := _absolute_path(path)
	if absolute_path.is_empty() or DirAccess.dir_exists_absolute(absolute_path):
		return _failure("保存先が無効です。")
	for file_path in [absolute_path, absolute_path + ".tmp", absolute_path + ".bak"]:
		if FileAccess.file_exists(file_path):
			var error := DirAccess.remove_absolute(file_path)
			if error != OK:
				return _failure("保存データを削除できません（%s）。" % error_string(error))
	return {"ok": true, "message": "保存データを削除しました。"}

static func _snapshot(game: RefCounted) -> Dictionary:
	var serialized_items: Array[Dictionary] = []
	for item in game.get("items"):
		if typeof(item) != TYPE_DICTIONARY or typeof(item.get("pos")) != TYPE_VECTOR2I:
			return _failure("装備データが無効です。元データは上書きしません。")
		var pos: Vector2i = item["pos"]
		serialized_items.append({
			"uid": item.get("uid"), "kind": item.get("kind"), "level": item.get("level"),
			"pos": {"x": pos.x, "y": pos.y}, "rotated": item.get("rotated"),
		})
	var rng: RandomNumberGenerator = game.get("_rng")
	var data := {
		"schema_version": SCHEMA_VERSION, "items": serialized_items,
		"shop_offers": game.get("shop_offers").duplicate(),
		"gold": game.get("gold"), "wave": game.get("wave"),
		"hp": game.get("hp"), "max_hp": game.get("max_hp"),
		"phase": game.get("phase"), "last_reward": game.get("last_reward"),
		"rng": {"seed": str(rng.seed), "state": str(rng.state)},
		"next_uid": game.get("_next_uid"),
		"blessings": game.get("blessings").duplicate(),
		"reward_choices": game.get("reward_choices").duplicate(),
		"reward_chosen": game.get("reward_chosen"),
	}
	return {"ok": true, "data": data}

static func _read_validated(path: String) -> Dictionary:
	var absolute_path := _absolute_path(path)
	if absolute_path.is_empty() or not FileAccess.file_exists(absolute_path):
		return _failure("再開できるデータがありません。")
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return _failure("データを読み込めません。")
	if file.get_length() > MAX_SAVE_BYTES:
		file.close()
		return _failure("データが大きすぎるため読み込みませんでした。")
	var source := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(source) != OK:
		return _failure("データが破損しています。現在の遠征は変更されません。")
	return _validate(json.data)

static func _validate(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return _failure("保存形式が無効です。")
	var data: Dictionary = raw
	if not _integer(data.get("schema_version"), 1, SCHEMA_VERSION):
		return _failure("この保存バージョンには対応していません。")
	var rules_script: Script = Rules
	var rule_constants: Dictionary = rules_script.get_script_constant_map()
	var definitions: Dictionary = rule_constants["DEFINITIONS"]
	var blessing_definitions: Dictionary = rule_constants.get("BLESSINGS", {})
	var grid: Vector2i = rule_constants["GRID_SIZE"]
	var wave_count: int = rule_constants["ENEMIES"].size()
	if typeof(data.get("phase")) != TYPE_STRING or data["phase"] not in ["prepare", "reward"]:
		return _failure("このデータからは再開できません。")
	for field in ["gold", "last_reward"]:
		if not _integer(data.get(field), 0, NUMBER_LIMIT):
			return _failure("金貨または報酬のデータが無効です。")
	if not _integer(data.get("wave"), 1, wave_count):
		return _failure("ステージのデータが無効です。")
	if data["phase"] == "reward" and int(data["wave"]) >= wave_count:
		return _failure("最終ステージに続行待ちの報酬はありません。")
	if not _integer(data.get("max_hp"), 1, 1000000) or not _integer(data.get("hp"), 1, int(data["max_hp"])):
		return _failure("HP データが無効です。")
	if not _integer(data.get("next_uid"), 1, NUMBER_LIMIT):
		return _failure("装備番号が無効です。")
	if typeof(data.get("items")) != TYPE_ARRAY or data["items"].size() > grid.x * grid.y:
		return _failure("バッグのデータが無効です。")
	var items: Array[Dictionary] = []
	var occupied: Dictionary = {}
	var uids: Dictionary = {}
	for raw_item in data["items"]:
		if typeof(raw_item) != TYPE_DICTIONARY:
			return _failure("装備のデータが無効です。")
		var item: Dictionary = raw_item
		if not _integer(item.get("uid"), 1, int(data["next_uid"]) - 1) or uids.has(int(item["uid"])):
			return _failure("装備番号が重複または範囲外です。")
		if typeof(item.get("kind")) != TYPE_STRING or not definitions.has(item["kind"]):
			return _failure("不明な装備が含まれます。")
		if not _integer(item.get("level"), 1, int(rule_constants["MAX_LEVEL"])) or typeof(item.get("rotated")) != TYPE_BOOL:
			return _failure("装備の品質または向きが無効です。")
		if typeof(item.get("pos")) != TYPE_DICTIONARY or not _integer(item["pos"].get("x"), 0, grid.x - 1) or not _integer(item["pos"].get("y"), 0, grid.y - 1):
			return _failure("装備の座標が無効です。")
		var pos := Vector2i(int(item["pos"]["x"]), int(item["pos"]["y"]))
		var footprint: Vector2i = definitions[item["kind"]]["size"]
		if item["rotated"]:
			footprint = Vector2i(footprint.y, footprint.x)
		if pos.x + footprint.x > grid.x or pos.y + footprint.y > grid.y:
			return _failure("装備がバッグからはみ出しています。")
		for y in range(pos.y, pos.y + footprint.y):
			for x in range(pos.x, pos.x + footprint.x):
				var cell := Vector2i(x, y)
				if occupied.has(cell):
					return _failure("装備が重なっています。")
				occupied[cell] = true
		uids[int(item["uid"])] = true
		items.append({"uid": int(item["uid"]), "kind": item["kind"], "level": int(item["level"]), "pos": pos, "rotated": item["rotated"]})
	if typeof(data.get("shop_offers")) != TYPE_ARRAY or data["shop_offers"].size() != 4:
		return _failure("商店のデータが無効です。")
	var shop_offers: Array[String] = []
	for kind in data["shop_offers"]:
		if typeof(kind) != TYPE_STRING or (kind != "" and kind not in rule_constants["SHOP_POOL"]):
			return _failure("商店に不明な商品があります。")
		shop_offers.append(kind)
	var blessings_result := _validate_ids(data.get("blessings"), blessing_definitions)
	var choices_result := _validate_ids(data.get("reward_choices"), blessing_definitions)
	if not blessings_result["ok"] or not choices_result["ok"] or typeof(data.get("reward_chosen")) != TYPE_BOOL:
		return _failure("祝福または報酬データが無効です。")
	var blessings: Array[String] = blessings_result["ids"]
	var choices: Array[String] = choices_result["ids"]
	var expected_blessings: int = int(data["wave"]) - 1
	if data["phase"] == "reward" and data["reward_chosen"]:
		expected_blessings += 1
	if blessings.size() != expected_blessings:
		return _failure("このステージの祝福の数が無効です。")
	if data["phase"] == "prepare":
		if data["reward_chosen"] or not choices.is_empty():
			return _failure("準備中に未選択の報酬は残せません。")
	elif data["reward_chosen"]:
		if not choices.is_empty() or blessings.is_empty():
			return _failure("受取済みの報酬状態が無効です。")
	elif choices.size() != 3:
		return _failure("報酬には3つの祝福候補が必要です。")
	for id in choices:
		if id in blessings:
			return _failure("候補は取得済みの祝福と重複できません。")
	if typeof(data.get("rng")) != TYPE_DICTIONARY:
		return _failure("乱数の状態がありません。")
	var seed_value := _decimal_int64(data["rng"].get("seed"))
	var state_value := _decimal_int64(data["rng"].get("state"))
	if not seed_value["ok"] or not state_value["ok"]:
		return _failure("乱数の状態が無効です。")
	return {"ok": true, "data": {
		"schema_version": SCHEMA_VERSION, "items": items, "shop_offers": shop_offers,
		"gold": int(data["gold"]), "wave": int(data["wave"]), "hp": int(data["hp"]), "max_hp": int(data["max_hp"]),
		"phase": data["phase"], "last_reward": int(data["last_reward"]), "next_uid": int(data["next_uid"]),
		"rng": {"seed": seed_value["value"], "state": state_value["value"]},
		"blessings": blessings, "reward_choices": choices, "reward_chosen": data["reward_chosen"],
	}}

static func _validate_ids(raw: Variant, definitions: Dictionary) -> Dictionary:
	if typeof(raw) != TYPE_ARRAY:
		return {"ok": false}
	var ids: Array[String] = []
	for id in raw:
		if typeof(id) != TYPE_STRING or not definitions.has(id) or id in ids:
			return {"ok": false}
		ids.append(id)
	return {"ok": true, "ids": ids}

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum

static func _decimal_int64(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_STRING or not value.is_valid_int():
		return {"ok": false}
	var parsed: int = value.to_int()
	# Round-tripping rejects overflow, whitespace, leading zeroes, and partial strings.
	return {"ok": str(parsed) == value, "value": parsed}

static func _absolute_path(path: String) -> String:
	if path.strip_edges().is_empty() or path.ends_with("/") or path.ends_with("\\"):
		return ""
	return ProjectSettings.globalize_path(path if path.is_absolute_path() else "res://" + path)

static func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
