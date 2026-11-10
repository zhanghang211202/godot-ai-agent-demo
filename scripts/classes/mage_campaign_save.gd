extends RefCounted
## Independent preparation checkpoints; existing prototype and legacy files
## remain untouched. Validate the complete resource ledger before mutation.

const Run = preload("res://scripts/classes/class_run.gd")
const Catalog = preload("res://scripts/classes/class_catalog.gd")
const Campaign = preload("res://scripts/classes/mage_campaign.gd")
const ExistingSave = preload("res://scripts/classes/class_save.gd")
const DEFAULT_PATH := "user://mage-campaign-run.json"
const KIND := "mage-campaign"
const VERSION := Campaign.CURRENT_RULES_VERSION
const LEGACY_VERSION := 1
const MAX_BYTES := 65536

static func save_run(run: RefCounted, stage: int, path: String = DEFAULT_PATH, completed: bool = false, completion_hp: int = 0) -> Dictionary:
	if not run is Run:
		return _failure("遠征の保存対象が無効です。")
	var last_stage := Campaign.stage_count(run.campaign_rules_version) - 1
	if run.phase != "prepare" and not (completed and run.phase == "won" and stage == last_stage):
		return _failure("遠征は戦前の準備中のみ保存できます。")
	if completed and (run.phase != "won" or stage != last_stage):
		return _failure("未踏破の遠征を完了として保存できません。")
	var snapshot: Dictionary = ExistingSave._snapshot(run)
	if not snapshot.ok:
		return snapshot
	var raw: Dictionary = snapshot.data
	raw.kind = KIND
	raw.schema_version = run.campaign_rules_version
	raw.rules_version = run.campaign_rules_version
	raw["stage"] = stage
	raw["completed"] = completed
	raw["completed_hp"] = completion_hp if completed else 0
	raw.phase = "prepare"
	var checked := _validate(raw)
	if not checked.ok:
		return checked
	var absolute := _safe_path(path)
	if absolute.is_empty() or DirAccess.dir_exists_absolute(absolute):
		return _failure("遠征の保存先が無効です。")
	var previous := FileAccess.file_exists(absolute)
	if previous and not _read(absolute).ok:
		return _failure("保存先に別形式または破損したデータがあります。元のファイルは保持されます。")
	var temporary := absolute + ".tmp"
	var backup := absolute + ".bak"
	for sidecar in [temporary, backup]:
		if FileAccess.file_exists(sidecar) or DirAccess.dir_exists_absolute(sidecar):
			return _failure("復元用の一時ファイルが残っているため保存できません。")
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK:
		return _failure("遠征の保存先を作成できません。")
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _failure("遠征の一時データを書き込めません。")
	file.store_string(JSON.stringify(raw, "\t", true))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK or not _read(temporary).ok:
		ExistingSave._remove_file(temporary)
		return _failure("遠征の一時データを検証できません。元のデータは保持されます。")
	if previous:
		error = DirAccess.copy_absolute(absolute, backup)
		if error != OK:
			ExistingSave._remove_file(temporary)
			return _failure("遠征のバックアップを作成できません。")
	error = DirAccess.rename_absolute(temporary, absolute)
	if error != OK:
		if previous and not FileAccess.file_exists(absolute):
			DirAccess.copy_absolute(backup, absolute)
		ExistingSave._remove_file(temporary)
		return _failure("遠征を保存できません。元のデータまたはバックアップは保持されます。")
	ExistingSave._remove_file(backup)
	return {"ok": true, "message": "%d戦の踏破を保存しました。" % (last_stage + 1) if completed else "第%d戦の準備を保存しました。" % (stage + 1)}

static func load_run(run: RefCounted, path: String = DEFAULT_PATH) -> Dictionary:
	if not run is Run:
		return _failure("遠征の読込先が無効です。")
	var absolute := _safe_path(path)
	if absolute.is_empty():
		return _failure("遠征の読込先が無効です。")
	var loaded := _read(absolute)
	if not loaded.ok:
		return loaded
	var data: Dictionary = loaded.data
	run.new_run("mage", int(data.seed))
	run.campaign_rules_version = int(data.campaign_rules_version)
	run.items.assign(data.items)
	run.sources.assign(data.sources)
	run.gold = int(data.gold)
	run.hp = int(data.hp)
	run.max_hp = int(data.max_hp)
	run._next_uid = int(data.next_uid)
	run.discarded_materials = data.discarded_materials.duplicate(true)
	run.phase = "prepare"
	return {"ok": true, "stage": int(data.stage), "completed": bool(data.completed), "completed_hp": int(data.completed_hp), "message": "%d戦を踏破した記録を復元しました。" % Campaign.stage_count(run.campaign_rules_version) if data.completed else "第%d戦の準備を復元しました。" % (int(data.stage) + 1)}

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("保存された遠征データがありません。")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("遠征データを読み込めません。")
	if file.get_length() > MAX_BYTES:
		file.close()
		return _failure("遠征データが大きすぎます。")
	var contents := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(contents) != OK:
		return _failure("遠征データが破損しています。元のファイルは保持されます。")
	return _validate(json.data)

static func _validate(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or raw.get("kind") != KIND or not ExistingSave._integer(raw.get("schema_version"), LEGACY_VERSION, VERSION) or not ExistingSave._integer(raw.get("rules_version"), LEGACY_VERSION, VERSION) or int(raw.schema_version) != int(raw.rules_version):
		return _failure("未対応の遠征データです。元のファイルは保持されます。")
	var last_stage := Campaign.stage_count(int(raw.rules_version)) - 1
	if raw.get("class_id") != "mage" or raw.get("phase") != "prepare" or not ExistingSave._integer(raw.get("stage"), 0, last_stage):
		return _failure("遠征の職業、進行または状態が無効です。")
	var completed: Variant = raw.get("completed", false)
	if typeof(completed) != TYPE_BOOL or (completed and int(raw.stage) != last_stage):
		return _failure("遠征の踏破状態が無効です。")
	var initial: Dictionary = Catalog.create_info("mage")
	if not ExistingSave._integer(raw.get("completed_hp", 0), 1 if completed else 0, int(initial.max_hp) if completed else 0):
		return _failure("踏破時の HP が無効です。")
	if not ExistingSave._integer(raw.get("hp"), initial.max_hp, initial.max_hp) or not ExistingSave._integer(raw.get("max_hp"), initial.max_hp, initial.max_hp):
		return _failure("戦前の HP が無効です。")
	var seed := ExistingSave._decimal_int64(raw.get("seed"))
	if not seed.ok or not ExistingSave._integer(raw.get("next_uid"), 1, ExistingSave.NUMBER_LIMIT):
		return _failure("遠征の識別子またはシードが無効です。")
	var expected_sources: Array = Campaign.initial_sources(int(raw.rules_version))
	if typeof(raw.get("sources")) != TYPE_ARRAY or raw.sources.size() != expected_sources.size():
		return _failure("元素や凝結の一覧が無効です。")
	var sources: Array[Dictionary] = []
	var expected := {}
	var claimed := 0
	var spent := 0
	for index in range(expected_sources.size()):
		var base: Dictionary = expected_sources[index]
		var source: Variant = raw.sources[index]
		if typeof(source) != TYPE_DICTIONARY or source.get("id") != base.id or source.get("kind") != base.kind or not ExistingSave._integer(source.get("cost"), base.cost, base.cost) or not ExistingSave._integer(source.get("remaining"), 0, base.remaining):
			return _failure("元素や凝結の在庫が無効です。")
		var used := int(base.remaining) - int(source.remaining)
		claimed += used
		spent += used * int(base.cost)
		ExistingSave._add_materials(expected, Catalog.definition(base.kind).materials, used)
		sources.append({"id": base.id, "kind": base.kind, "remaining": int(source.remaining), "cost": int(base.cost)})
	var earned := 0
	var stage_rewards := Campaign.rewards(int(raw.rules_version))
	for index in range(int(raw.stage)):
		earned += int(stage_rewards[index])
	if not ExistingSave._integer(raw.get("gold"), 0, earned) or int(raw.gold) != earned - spent:
		return _failure("魔力残滓の収支が一致しません。")
	var initial_items: Array = Catalog.initial_inventory("mage")
	if int(raw.next_uid) != initial_items.size() + claimed + 1:
		return _failure("遠征のアイテム番号と取得回数が一致しません。")
	for item: Dictionary in initial_items:
		ExistingSave._add_materials(expected, Catalog.definition(item.kind).materials)
	if typeof(raw.get("discarded_materials")) != TYPE_DICTIONARY:
		return _failure("廃棄素材の記録が無効です。")
	var actual := {}
	var discarded := {}
	for key in raw.discarded_materials:
		if typeof(key) != TYPE_STRING or not expected.has(key) or not ExistingSave._integer(raw.discarded_materials[key], 1, expected[key]):
			return _failure("廃棄素材の記録が無効です。")
		actual[key] = int(raw.discarded_materials[key])
		discarded[key] = int(raw.discarded_materials[key])
	var items := ExistingSave._validate_items(raw.get("items"), "mage", int(raw.next_uid), actual)
	if not items.ok:
		return items
	if completed and not items.items.any(func(item: Dictionary): return Catalog.definition(item.kind).category in ["attack", "summon"]):
		return _failure("踏破記録の攻撃手段がありません。")
	if expected.size() != actual.size():
		return _failure("盤面と素材の数が一致しません。")
	for key in expected:
		if not actual.has(key) or int(actual[key]) != int(expected[key]):
			return _failure("盤面と素材の数が一致しません。")
	return {"ok": true, "data": {"stage": int(raw.stage), "completed": completed, "completed_hp": int(raw.get("completed_hp", 0)), "campaign_rules_version": int(raw.rules_version), "seed": seed.value, "hp": int(raw.hp), "max_hp": int(raw.max_hp), "gold": int(raw.gold), "next_uid": int(raw.next_uid), "items": items.items, "sources": sources, "discarded_materials": discarded}}

static func _safe_path(path: String) -> String:
	var absolute := ExistingSave._absolute_path(path)
	if absolute.is_empty() or absolute.get_file().to_lower() in ["emberpack-run.json", "class-prototype-run.json", "mage-trial-run.json"]:
		return ""
	return absolute

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
