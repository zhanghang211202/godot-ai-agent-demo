extends RefCounted
## C0 checkpoints are deliberately isolated from the legacy EmberSave format.
## Files are untrusted: validate every field before mutating a ClassRun.

const Run = preload("res://scripts/classes/class_run.gd")
const Catalog = preload("res://scripts/classes/class_catalog.gd")
const DEFAULT_PATH := "user://class-prototype-run.json"
const DOCUMENT_KIND := "class-prototype"
const SCHEMA_VERSION := 1
const RULES_VERSION := 1
const MAX_SAVE_BYTES := 65536
const NUMBER_LIMIT := 1000000

static func save_run(run: RefCounted, path: String = DEFAULT_PATH) -> Dictionary:
	if not run is Run:
		return _failure("保存できません：無効な職業データです。")
	if run.get("phase") != "prepare":
		return _failure("準備中のみ保存できます。戦闘を中断した場合は戦前から再開します。")
	var snapshot := _snapshot(run)
	if not snapshot["ok"]:
		return snapshot
	var checked := _validate(snapshot["data"])
	if not checked["ok"]:
		return checked
	var absolute := _absolute_path(path)
	if absolute.is_empty() or _is_legacy_path(absolute) or DirAccess.dir_exists_absolute(absolute):
		return _failure("保存先が無効です。旧版の遠征データには書き込めません。")
	# Never overwrite legacy, damaged, or future-version files with a new run.
	var had_previous := FileAccess.file_exists(absolute)
	if had_previous:
		var existing := _read_validated(absolute)
		if not existing["ok"]:
			return _failure("保存先は上書き可能な職業データではありません。元のファイルは保持されます。" + existing["message"])
	var temporary := absolute + ".tmp"
	var backup := absolute + ".bak"
	for sidecar in [temporary, backup]:
		if FileAccess.file_exists(sidecar) or DirAccess.dir_exists_absolute(sidecar):
			return _failure("一時ファイルまたはバックアップが残っています。復元用データを確認してください。")
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK:
		return _failure("保存フォルダーを作成できません：" + error_string(error))
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _failure("一時データを書き込めません：" + error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(snapshot["data"], "\t", true))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK or not _read_validated(temporary)["ok"]:
		_remove_file(temporary)
		return _failure("一時データの検証に失敗しました。元のデータは保持されます。")
	if had_previous:
		error = DirAccess.copy_absolute(absolute, backup)
		if error != OK:
			_remove_file(temporary)
			return _failure("バックアップできません。元のデータは保持されます。")
	error = DirAccess.rename_absolute(temporary, absolute)
	if error != OK:
		if had_previous and not FileAccess.file_exists(absolute):
			DirAccess.copy_absolute(backup, absolute)
		_remove_file(temporary)
		return _failure("保存データを置き換えられません。元データまたは .bak は保持されます。")
	_remove_file(backup)
	return {"ok": true, "message": "戦前の準備を保存しました。", "path": path}

static func load_run(run: RefCounted, path: String = DEFAULT_PATH) -> Dictionary:
	if not run is Run:
		return _failure("読込できません：無効な職業データです。")
	var loaded := _read_validated(path)
	if not loaded["ok"]:
		return loaded
	var data: Dictionary = loaded["data"]
	# Constructing a clean preparation state also clears every transient battle field.
	run.call("new_run", data["class_id"], data["seed"])
	for field in ["class_id", "items", "sources", "gold", "hp", "max_hp", "phase", "discarded_materials"]:
		run.set(field, data[field])
	run.set("seed_value", data["seed"])
	run.set("_next_uid", data["next_uid"])
	return {"ok": true, "message": "戦前の準備を復元しました。戦闘は最初から始まります。", "class_id": data["class_id"], "phase": "prepare"}

static func inspect_save(path: String = DEFAULT_PATH) -> Dictionary:
	var loaded := _read_validated(path)
	if not loaded["ok"]:
		return loaded
	var data: Dictionary = loaded["data"]
	return {"ok": true, "classification": "prototype", "kind": DOCUMENT_KIND,
		"schema_version": SCHEMA_VERSION, "rules_version": RULES_VERSION,
		"class_id": data["class_id"], "gold": data["gold"], "hp": data["hp"],
		"max_hp": data["max_hp"], "phase": "prepare", "item_count": data["items"].size(),
		"message": "戦前の準備から再開できます。", "path": path}

static func classify_document(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return _failure("保存データのルートはオブジェクトである必要があります。")
	if not raw.has("kind") and _integer(raw.get("schema_version"), 1, 1):
		return {"ok": false, "classification": "legacy", "message": "旧形式 schema 1 です。旧版の遠征で読み込んでください。元データは変更しません。"}
	if raw.get("kind") != DOCUMENT_KIND:
		return {"ok": false, "classification": "unknown", "message": "不明な保存形式です。元データは保持されます。"}
	if not _integer(raw.get("schema_version"), SCHEMA_VERSION, SCHEMA_VERSION) or not _integer(raw.get("rules_version"), RULES_VERSION, RULES_VERSION):
		return {"ok": false, "classification": "unsupported", "message": "この保存形式またはルールのバージョンには対応していません。元データは保持されます。"}
	return {"ok": true, "classification": "prototype", "message": "職業試練の保存形式。"}

static func reset_prototype(path: String = DEFAULT_PATH) -> Dictionary:
	var absolute := _absolute_path(path)
	if absolute.is_empty() or _is_legacy_path(absolute) or DirAccess.dir_exists_absolute(absolute):
		return _failure("保存先が無効です。")
	if not FileAccess.file_exists(absolute):
		return {"ok": true, "message": "この保存先に戦前データはありません。"}
	var checked := _read_validated(absolute)
	if not checked["ok"]:
		return _failure("不明・旧版・破損ファイルはリセットできません。元データは保持されます。")
	var backup := absolute + ".reset.bak"
	var suffix := 0
	while FileAccess.file_exists(backup) or DirAccess.dir_exists_absolute(backup):
		suffix += 1
		if suffix > 1000:
			return _failure("バックアップが多すぎるためリセットしませんでした。")
		backup = absolute + ".reset-%d.bak" % suffix
	var error := DirAccess.copy_absolute(absolute, backup)
	if error != OK:
		return _failure("バックアップできないためリセットしませんでした。")
	error = DirAccess.remove_absolute(absolute)
	if error != OK:
		return _failure("データを削除できません。元データとバックアップは保持されます。")
	return {"ok": true, "message": "戦前データをリセットし、元データをバックアップしました。", "backup_path": backup}

static func _snapshot(run: RefCounted) -> Dictionary:
	var serialized: Array[Dictionary] = []
	var raw_items: Variant = run.get("items")
	if typeof(raw_items) != TYPE_ARRAY:
		return _failure("盤のデータが無効です。")
	for item in raw_items:
		if typeof(item) != TYPE_DICTIONARY or typeof(item.get("pos")) != TYPE_VECTOR2I:
			return _failure("盤上のアイテムデータが無効です。")
		var pos: Vector2i = item["pos"]
		serialized.append({"uid": item.get("uid"), "kind": item.get("kind"),
			"pos": [pos.x, pos.y], "rotated": item.get("rotated")})
	return {"ok": true, "data": {"kind": DOCUMENT_KIND, "schema_version": SCHEMA_VERSION,
		"rules_version": RULES_VERSION, "class_id": run.get("class_id"), "seed": str(run.get("seed_value")),
		"hp": run.get("hp"), "max_hp": run.get("max_hp"), "gold": run.get("gold"),
		"items": serialized, "sources": run.get("sources"), "next_uid": run.get("_next_uid"),
		"phase": run.get("phase"), "discarded_materials": run.get("discarded_materials")}}

static func _read_validated(path: String) -> Dictionary:
	var absolute := _absolute_path(path)
	if absolute.is_empty() or not FileAccess.file_exists(absolute):
		return _failure("読み込める職業データがありません。")
	var file := FileAccess.open(absolute, FileAccess.READ)
	if file == null:
		return _failure("職業データを読み込めません。")
	if file.get_length() > MAX_SAVE_BYTES:
		file.close()
		return _failure("職業データが大きすぎます。元ファイルは保持されます。")
	var source := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(source) != OK:
		return _failure("職業データが破損しています。元ファイルは保持されます。")
	return _validate(json.data)

static func _validate(raw: Variant) -> Dictionary:
	var classification := classify_document(raw)
	if not classification["ok"]:
		return classification
	var data: Dictionary = raw
	if typeof(data.get("class_id")) != TYPE_STRING or data["class_id"] not in Catalog.CLASS_IDS:
		return _failure("保存データに不明な職業が含まれます。")
	var class_id: String = data["class_id"]
	var seed_result := _decimal_int64(data.get("seed"))
	if not seed_result["ok"]:
		return _failure("シードは範囲内の正規の十進整数である必要があります。")
	var start: Dictionary = Catalog.create_info(class_id)
	if data.get("phase") != "prepare":
		return _failure("復元可能な戦前データではありません。")
	if not _integer(data.get("max_hp"), int(start["max_hp"]), int(start["max_hp"])) or not _integer(data.get("hp"), int(start["max_hp"]), int(start["max_hp"])):
		return _failure("準備中の HP は職業の初期値と一致する必要があります。")
	if not _integer(data.get("gold"), 0, int(start["gold"])) or not _integer(data.get("next_uid"), 1, NUMBER_LIMIT):
		return _failure("金貨またはアイテム番号が無効です。")
	var sources_result := _validate_sources(data.get("sources"), class_id)
	if not sources_result["ok"]:
		return sources_result
	if int(data["gold"]) != int(start["gold"]) - int(sources_result["spent"]):
		return _failure("金貨と取得済み素材の費用が一致しません。")
	var expected: Dictionary = sources_result["materials"]
	var initial_inventory: Array = Catalog.initial_inventory(class_id)
	if int(data["next_uid"]) != initial_inventory.size() + int(sources_result["claimed"]) + 1:
		return _failure("アイテム番号と素材の取得回数が一致しません。")
	for initial_item in initial_inventory:
		_add_materials(expected, Catalog.definition(initial_item["kind"])["materials"])
	var discarded: Variant = data.get("discarded_materials")
	if typeof(discarded) != TYPE_DICTIONARY:
		return _failure("廃棄素材の記録が無効です。")
	var actual: Dictionary = {}
	var normalized_discarded: Dictionary = {}
	for key in discarded:
		if typeof(key) != TYPE_STRING or not expected.has(key) or not _integer(discarded[key], 1, int(expected[key])):
			return _failure("廃棄素材の種類または数が無効です。")
		actual[key] = int(discarded[key])
		normalized_discarded[key] = int(discarded[key])
	var items_result := _validate_items(data.get("items"), class_id, int(data["next_uid"]), actual)
	if not items_result["ok"]:
		return items_result
	# Exact ingredient accounting prevents source replay and forged spell/weapon products.
	if expected.size() != actual.size():
		return _failure("盤、廃棄記録と有限素材の数が一致しません。")
	for key in expected:
		if not actual.has(key) or int(actual[key]) != int(expected[key]):
			return _failure("盤、廃棄記録と有限素材の数が一致しません。")
	return {"ok": true, "data": {"kind": DOCUMENT_KIND, "schema_version": SCHEMA_VERSION,
		"rules_version": RULES_VERSION, "class_id": class_id, "seed": seed_result["value"],
		"hp": int(data["hp"]), "max_hp": int(data["max_hp"]), "gold": int(data["gold"]),
		"next_uid": int(data["next_uid"]), "phase": "prepare", "items": items_result["items"],
		"sources": sources_result["sources"], "discarded_materials": normalized_discarded}}

static func _validate_sources(raw: Variant, class_id: String) -> Dictionary:
	var initial: Array = Catalog.initial_sources(class_id)
	if typeof(raw) != TYPE_ARRAY or raw.size() != initial.size():
		return _failure("素材取得元の一覧が無効です。")
	var expected_by_id: Dictionary = {}
	for entry in initial:
		expected_by_id[entry["id"]] = entry
	var seen: Dictionary = {}
	var spent := 0
	var claimed_total := 0
	var materials: Dictionary = {}
	var sources: Array[Dictionary] = []
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("id")) != TYPE_STRING or not expected_by_id.has(entry["id"]) or seen.has(entry["id"]):
			return _failure("素材取得元の識別子が不明または重複しています。")
		var initial_entry: Dictionary = expected_by_id[entry["id"]]
		if entry.get("kind") != initial_entry["kind"] or not _integer(entry.get("cost"), int(initial_entry["cost"]), int(initial_entry["cost"])) or not _integer(entry.get("remaining"), 0, int(initial_entry["remaining"])):
			return _failure("素材取得元のアイテム、費用または残数が無効です。")
		seen[entry["id"]] = true
		var claimed: int = int(initial_entry["remaining"]) - int(entry["remaining"])
		claimed_total += claimed
		spent += claimed * int(initial_entry["cost"])
		_add_materials(materials, Catalog.definition(initial_entry["kind"])["materials"], claimed)
		sources.append({"id": entry["id"], "kind": entry["kind"], "remaining": int(entry["remaining"]), "cost": int(entry["cost"])})
	return {"ok": true, "sources": sources, "spent": spent, "claimed": claimed_total, "materials": materials}

static func _validate_items(raw: Variant, class_id: String, next_uid: int, material_totals: Dictionary) -> Dictionary:
	var grid: Vector2i = Catalog.GRID_SIZE
	if typeof(raw) != TYPE_ARRAY or raw.size() > grid.x * grid.y:
		return _failure("盤の一覧が無効か、アイテムが多すぎます。")
	var occupied: Dictionary = {}
	var uids: Dictionary = {}
	var items: Array[Dictionary] = []
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			return _failure("盤上のアイテムが無効です。")
		if not _integer(entry.get("uid"), 1, next_uid - 1) or uids.has(int(entry["uid"])):
			return _failure("アイテム番号が重複または範囲外です。")
		if typeof(entry.get("kind")) != TYPE_STRING:
			return _failure("不明なアイテムです。")
		var definition: Dictionary = Catalog.definition(entry["kind"])
		if definition.is_empty() or definition.get("class_id") != class_id:
			return _failure("不明なアイテムか、この職業では使えません。")
		if typeof(entry.get("rotated")) != TYPE_BOOL or typeof(entry.get("pos")) != TYPE_ARRAY or entry["pos"].size() != 2:
			return _failure("アイテムの向きまたは座標が無効です。")
		if not _integer(entry["pos"][0], 0, grid.x - 1) or not _integer(entry["pos"][1], 0, grid.y - 1):
			return _failure("アイテムの座標が範囲外です。")
		var pos := Vector2i(int(entry["pos"][0]), int(entry["pos"][1]))
		var size: Vector2i = definition["size"]
		if entry["rotated"]:
			size = Vector2i(size.y, size.x)
		if pos.x + size.x > grid.x or pos.y + size.y > grid.y:
			return _failure("アイテムが盤からはみ出しています。")
		for y in range(pos.y, pos.y + size.y):
			for x in range(pos.x, pos.x + size.x):
				var cell := Vector2i(x, y)
				if occupied.has(cell):
					return _failure("アイテムのマスが重なっています。")
				occupied[cell] = true
		uids[int(entry["uid"])] = true
		_add_materials(material_totals, definition["materials"])
		items.append({"uid": int(entry["uid"]), "kind": entry["kind"], "pos": pos, "rotated": entry["rotated"]})
	return {"ok": true, "items": items}

static func _add_materials(destination: Dictionary, materials: Dictionary, multiplier: int = 1) -> void:
	for key in materials:
		var amount := int(materials[key]) * multiplier
		if amount > 0:
			destination[key] = int(destination.get(key, 0)) + amount

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum

static func _decimal_int64(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_STRING or not value.is_valid_int():
		return {"ok": false}
	var parsed: int = value.to_int()
	return {"ok": str(parsed) == value, "value": parsed}

static func _absolute_path(path: String) -> String:
	if path.strip_edges().is_empty() or path.ends_with("/") or path.ends_with("\\") or path.to_utf8_buffer().has(0):
		return ""
	var absolute := ProjectSettings.globalize_path(path if path.is_absolute_path() else "res://" + path).simplify_path()
	# Reject Win32 aliases (trailing dots/spaces and alternate data streams),
	# so a spelling variant cannot escape the separate-file boundary.
	var components := absolute.replace("\\", "/").split("/")
	for index in range(components.size()):
		var component: String = components[index]
		if component.ends_with(".") or component.ends_with(" "):
			return ""
		if ":" in component and not (index == 0 and component.length() == 2 and component.ends_with(":")):
			return ""
	return absolute

static func _is_legacy_path(absolute: String) -> bool:
	# Inspection may recognize it, but no experimental write/reset may target it.
	return absolute.get_file().to_lower() == "emberpack-run.json"

static func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "classification": "invalid", "message": message}
