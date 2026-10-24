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
		return _failure("无法保存：无效的职业实验。")
	if run.get("phase") != "prepare":
		return _failure("仅可保存战前整备；战中退出后可读取战前检查点。")
	var snapshot := _snapshot(run)
	if not snapshot["ok"]:
		return snapshot
	var checked := _validate(snapshot["data"])
	if not checked["ok"]:
		return checked
	var absolute := _absolute_path(path)
	if absolute.is_empty() or _is_legacy_path(absolute) or DirAccess.dir_exists_absolute(absolute):
		return _failure("存档路径无效，不能写入旧远征路径。")
	# Never overwrite legacy, damaged, or future-version files with a new run.
	var had_previous := FileAccess.file_exists(absolute)
	if had_previous:
		var existing := _read_validated(absolute)
		if not existing["ok"]:
			return _failure("目标文件不是可覆盖的职业实验存档，已保留原文件。" + existing["message"])
	var temporary := absolute + ".tmp"
	var backup := absolute + ".bak"
	for sidecar in [temporary, backup]:
		if FileAccess.file_exists(sidecar) or DirAccess.dir_exists_absolute(sidecar):
			return _failure("发现已有临时文件或备份，已保留原文件；请先检查恢复资料。")
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK:
		return _failure("无法创建存档目录：" + error_string(error))
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _failure("无法写入临时存档：" + error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(snapshot["data"], "\t", true))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK or not _read_validated(temporary)["ok"]:
		_remove_file(temporary)
		return _failure("临时存档校验失败，原存档已保留。")
	if had_previous:
		error = DirAccess.copy_absolute(absolute, backup)
		if error != OK:
			_remove_file(temporary)
			return _failure("无法备份原存档，原文件已保留。")
	error = DirAccess.rename_absolute(temporary, absolute)
	if error != OK:
		if had_previous and not FileAccess.file_exists(absolute):
			DirAccess.copy_absolute(backup, absolute)
		_remove_file(temporary)
		return _failure("无法替换存档；原文件或 .bak 备份已保留。")
	_remove_file(backup)
	return {"ok": true, "message": "职业实验的战前检查点已保存。", "path": path}

static func load_run(run: RefCounted, path: String = DEFAULT_PATH) -> Dictionary:
	if not run is Run:
		return _failure("无法读取：无效的职业实验。")
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
	return {"ok": true, "message": "已恢复战前整备；战斗将从头开始。", "class_id": data["class_id"], "phase": "prepare"}

static func inspect_save(path: String = DEFAULT_PATH) -> Dictionary:
	var loaded := _read_validated(path)
	if not loaded["ok"]:
		return loaded
	var data: Dictionary = loaded["data"]
	return {"ok": true, "classification": "prototype", "kind": DOCUMENT_KIND,
		"schema_version": SCHEMA_VERSION, "rules_version": RULES_VERSION,
		"class_id": data["class_id"], "gold": data["gold"], "hp": data["hp"],
		"max_hp": data["max_hp"], "phase": "prepare", "item_count": data["items"].size(),
		"message": "可继续职业实验的战前整备。", "path": path}

static func classify_document(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return _failure("存档根节点必须是对象。")
	if not raw.has("kind") and _integer(raw.get("schema_version"), 1, 1):
		return {"ok": false, "classification": "legacy", "message": "检测到旧 schema 1 格式。请在旧远征中读取；不会映射职业或修改旧文件。"}
	if raw.get("kind") != DOCUMENT_KIND:
		return {"ok": false, "classification": "unknown", "message": "未知存档类型，已保留原文件。"}
	if not _integer(raw.get("schema_version"), SCHEMA_VERSION, SCHEMA_VERSION) or not _integer(raw.get("rules_version"), RULES_VERSION, RULES_VERSION):
		return {"ok": false, "classification": "unsupported", "message": "职业实验的存档或规则版本不受支持，已保留原文件。"}
	return {"ok": true, "classification": "prototype", "message": "职业实验格式。"}

static func reset_prototype(path: String = DEFAULT_PATH) -> Dictionary:
	var absolute := _absolute_path(path)
	if absolute.is_empty() or _is_legacy_path(absolute) or DirAccess.dir_exists_absolute(absolute):
		return _failure("存档路径无效。")
	if not FileAccess.file_exists(absolute):
		return {"ok": true, "message": "此路径没有职业实验检查点。"}
	var checked := _read_validated(absolute)
	if not checked["ok"]:
		return _failure("不能重置未知、旧版或损坏文件，原文件已保留。")
	var backup := absolute + ".reset.bak"
	var suffix := 0
	while FileAccess.file_exists(backup) or DirAccess.dir_exists_absolute(backup):
		suffix += 1
		if suffix > 1000:
			return _failure("备份文件过多，未重置检查点。")
		backup = absolute + ".reset-%d.bak" % suffix
	var error := DirAccess.copy_absolute(absolute, backup)
	if error != OK:
		return _failure("无法备份检查点，未重置。")
	error = DirAccess.remove_absolute(absolute)
	if error != OK:
		return _failure("无法移除检查点，原文件与备份已保留。")
	return {"ok": true, "message": "职业实验检查点已重置，原文件已备份。", "backup_path": backup}

static func _snapshot(run: RefCounted) -> Dictionary:
	var serialized: Array[Dictionary] = []
	var raw_items: Variant = run.get("items")
	if typeof(raw_items) != TYPE_ARRAY:
		return _failure("背包数据无效。")
	for item in raw_items:
		if typeof(item) != TYPE_DICTIONARY or typeof(item.get("pos")) != TYPE_VECTOR2I:
			return _failure("背包物件数据无效。")
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
		return _failure("没有可读取的职业实验存档。")
	var file := FileAccess.open(absolute, FileAccess.READ)
	if file == null:
		return _failure("无法读取职业实验存档。")
	if file.get_length() > MAX_SAVE_BYTES:
		file.close()
		return _failure("职业实验存档过大，已保留原文件。")
	var source := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(source) != OK:
		return _failure("职业实验存档内容损坏，已保留原文件。")
	return _validate(json.data)

static func _validate(raw: Variant) -> Dictionary:
	var classification := classify_document(raw)
	if not classification["ok"]:
		return classification
	var data: Dictionary = raw
	if typeof(data.get("class_id")) != TYPE_STRING or data["class_id"] not in Catalog.CLASS_IDS:
		return _failure("存档包含未知职业。")
	var class_id: String = data["class_id"]
	var seed_result := _decimal_int64(data.get("seed"))
	if not seed_result["ok"]:
		return _failure("种子必须为不溢出的规范十进制整数字符串。")
	var start: Dictionary = Catalog.create_info(class_id)
	if data.get("phase") != "prepare":
		return _failure("存档不是可恢复的战前整备。")
	if not _integer(data.get("max_hp"), int(start["max_hp"]), int(start["max_hp"])) or not _integer(data.get("hp"), int(start["max_hp"]), int(start["max_hp"])):
		return _failure("一战实验的整备生命值必须与职业初始值一致。")
	if not _integer(data.get("gold"), 0, int(start["gold"])) or not _integer(data.get("next_uid"), 1, NUMBER_LIMIT):
		return _failure("金币或物件序号无效。")
	var sources_result := _validate_sources(data.get("sources"), class_id)
	if not sources_result["ok"]:
		return sources_result
	if int(data["gold"]) != int(start["gold"]) - int(sources_result["spent"]):
		return _failure("金币与已领取来源的花费不符。")
	var expected: Dictionary = sources_result["materials"]
	var initial_inventory: Array = Catalog.initial_inventory(class_id)
	if int(data["next_uid"]) != initial_inventory.size() + int(sources_result["claimed"]) + 1:
		return _failure("物件序号与实际资源领取次数不符。")
	for initial_item in initial_inventory:
		_add_materials(expected, Catalog.definition(initial_item["kind"])["materials"])
	var discarded: Variant = data.get("discarded_materials")
	if typeof(discarded) != TYPE_DICTIONARY:
		return _failure("丢弃材料账本无效。")
	var actual: Dictionary = {}
	var normalized_discarded: Dictionary = {}
	for key in discarded:
		if typeof(key) != TYPE_STRING or not expected.has(key) or not _integer(discarded[key], 1, int(expected[key])):
			return _failure("丢弃材料账本含非法种类或数量。")
		actual[key] = int(discarded[key])
		normalized_discarded[key] = int(discarded[key])
	var items_result := _validate_items(data.get("items"), class_id, int(data["next_uid"]), actual)
	if not items_result["ok"]:
		return items_result
	# Exact ingredient accounting prevents source replay and forged spell/weapon products.
	if expected.size() != actual.size():
		return _failure("背包、丢弃记录与有限来源的材料账不符。")
	for key in expected:
		if not actual.has(key) or int(actual[key]) != int(expected[key]):
			return _failure("背包、丢弃记录与有限来源的材料账不符。")
	return {"ok": true, "data": {"kind": DOCUMENT_KIND, "schema_version": SCHEMA_VERSION,
		"rules_version": RULES_VERSION, "class_id": class_id, "seed": seed_result["value"],
		"hp": int(data["hp"]), "max_hp": int(data["max_hp"]), "gold": int(data["gold"]),
		"next_uid": int(data["next_uid"]), "phase": "prepare", "items": items_result["items"],
		"sources": sources_result["sources"], "discarded_materials": normalized_discarded}}

static func _validate_sources(raw: Variant, class_id: String) -> Dictionary:
	var initial: Array = Catalog.initial_sources(class_id)
	if typeof(raw) != TYPE_ARRAY or raw.size() != initial.size():
		return _failure("资源来源列表无效。")
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
			return _failure("资源来源标识未知或重复。")
		var initial_entry: Dictionary = expected_by_id[entry["id"]]
		if entry.get("kind") != initial_entry["kind"] or not _integer(entry.get("cost"), int(initial_entry["cost"]), int(initial_entry["cost"])) or not _integer(entry.get("remaining"), 0, int(initial_entry["remaining"])):
			return _failure("资源来源的物件、费用或剩余次数无效。")
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
		return _failure("背包列表无效或物件过多。")
	var occupied: Dictionary = {}
	var uids: Dictionary = {}
	var items: Array[Dictionary] = []
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			return _failure("背包物件无效。")
		if not _integer(entry.get("uid"), 1, next_uid - 1) or uids.has(int(entry["uid"])):
			return _failure("物件序号重复或越界。")
		if typeof(entry.get("kind")) != TYPE_STRING:
			return _failure("未知物件种类。")
		var definition: Dictionary = Catalog.definition(entry["kind"])
		if definition.is_empty() or definition.get("class_id") != class_id:
			return _failure("物件未知或不属于此职业。")
		if typeof(entry.get("rotated")) != TYPE_BOOL or typeof(entry.get("pos")) != TYPE_ARRAY or entry["pos"].size() != 2:
			return _failure("物件方向或坐标格式无效。")
		if not _integer(entry["pos"][0], 0, grid.x - 1) or not _integer(entry["pos"][1], 0, grid.y - 1):
			return _failure("物件坐标越界。")
		var pos := Vector2i(int(entry["pos"][0]), int(entry["pos"][1]))
		var size: Vector2i = definition["size"]
		if entry["rotated"]:
			size = Vector2i(size.y, size.x)
		if pos.x + size.x > grid.x or pos.y + size.y > grid.y:
			return _failure("物件超出背包边界。")
		for y in range(pos.y, pos.y + size.y):
			for x in range(pos.x, pos.x + size.x):
				var cell := Vector2i(x, y)
				if occupied.has(cell):
					return _failure("物件占格重叠。")
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
