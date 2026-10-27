extends RefCounted
## Separate C0 laboratory; none of these methods mutate legacy EmberRun or its saves.

const Catalog = preload("res://scripts/classes/class_catalog.gd")

var class_id: String = ""
var items: Array[Dictionary] = []
var sources: Array[Dictionary] = []
var gold: int = 0
var hp: int = 0
var max_hp: int = 0
var phase: String = "prepare"
var seed_value: int = 12345
var _next_uid: int = 1
## Raw ingredients intentionally lost by discard. Required for exact save conservation.
var discarded_materials: Dictionary = {}

func new_run(id: String = "mage", seed: int = 12345) -> Dictionary:
	var info: Dictionary = Catalog.create_info(id)
	if info.is_empty():
		return _failure("未知职业，当前整备未改变。")
	class_id = id
	seed_value = seed
	items = Catalog.initial_inventory(id)
	sources = Catalog.initial_sources(id)
	gold = int(info["gold"])
	max_hp = int(info["max_hp"])
	hp = max_hp
	phase = "prepare"
	discarded_materials.clear()
	_next_uid = items.size() + 1
	return {"ok": true, "event": "new_run", "message": "已开启固定来源的 C0 一战规则切片。"}

func get_definition(kind: String) -> Dictionary:
	return Catalog.definition(kind)

func get_item_size(item: Dictionary) -> Vector2i:
	var definition: Dictionary = get_definition(str(item.get("kind", "")))
	if definition.is_empty():
		return Vector2i.ZERO
	var size: Vector2i = definition["size"]
	if bool(item.get("rotated", false)):
		return Vector2i(size.y, size.x)
	return size

func item_at(cell: Vector2i) -> Dictionary:
	for item: Dictionary in items:
		var rect: Rect2i = Rect2i(item["pos"], get_item_size(item))
		if rect.has_point(cell):
			return item
	return {}

func item_by_uid(uid: int) -> Dictionary:
	for item: Dictionary in items:
		if int(item["uid"]) == uid:
			return item
	return {}

func can_place(item: Dictionary, cell: Vector2i, ignore_uid: int = -1) -> bool:
	return _can_place_ignoring(item, cell, [ignore_uid])

func _can_place_ignoring(item: Dictionary, cell: Vector2i, ignored: Array) -> bool:
	var definition: Dictionary = get_definition(str(item.get("kind", "")))
	if definition.is_empty() or str(definition["class_id"]) != class_id:
		return false
	var size: Vector2i = get_item_size(item)
	if cell.x < 0 or cell.y < 0 or size.x <= 0 or size.y <= 0:
		return false
	if cell.x + size.x > Catalog.GRID_SIZE.x or cell.y + size.y > Catalog.GRID_SIZE.y:
		return false
	var candidate_rect: Rect2i = Rect2i(cell, size)
	for other: Dictionary in items:
		if int(other["uid"]) in ignored:
			continue
		if candidate_rect.intersects(Rect2i(other["pos"], get_item_size(other))):
			return false
	return true

func acquire(source_index: int, cell: Vector2i, rotated: bool = false) -> Dictionary:
	if phase != "prepare":
		return _failure("只有整备阶段可以取得资源。")
	if source_index < 0 or source_index >= sources.size():
		return _failure("无效资源来源。")
	var source: Dictionary = sources[source_index]
	var definition: Dictionary = get_definition(str(source.get("kind", "")))
	if definition.is_empty() or str(definition["class_id"]) != class_id:
		return _failure("该来源不属于当前职业。")
	if int(source["remaining"]) <= 0:
		return _failure("本次来源已耗尽，不会自动刷新。")
	var cost: int = int(source["cost"])
	if cost < 0 or gold < cost:
		return _failure("金币不足。")
	var candidate: Dictionary = {"uid": _next_uid, "kind": source["kind"], "pos": cell, "rotated": rotated}
	var result: Dictionary = _place_or_merge(candidate, cell, false)
	if not bool(result["ok"]):
		return result
	gold -= cost
	source["remaining"] = int(source["remaining"]) - 1
	_next_uid += 1
	result["cost"] = cost
	result["source_id"] = source["id"]
	return result

func move(uid: int, cell: Vector2i, rotated: bool = false) -> Dictionary:
	if phase != "prepare":
		return _failure("只有整备阶段可以移动或合成。")
	var original: Dictionary = item_by_uid(uid)
	if original.is_empty():
		return _failure("未找到物件。")
	var candidate: Dictionary = original.duplicate(true)
	candidate["rotated"] = rotated
	return _place_or_merge(candidate, cell, true)

func preview_placement(data: Dictionary, cell: Vector2i) -> Dictionary:
	# Run the actual transaction on an isolated copy. This includes owned-source
	# removal, product anchoring, stock/cost validation and directional support.
	var copy = get_script().new()
	for field in ["class_id", "gold", "hp", "max_hp", "phase", "seed_value", "_next_uid"]:
		copy.set(field, get(field))
	copy.items.assign(items.duplicate(true))
	copy.sources.assign(sources.duplicate(true))
	copy.discarded_materials = discarded_materials.duplicate(true)
	var result: Dictionary
	if str(data.get("origin", "")) == "source":
		result = copy.acquire(int(data.get("index", -1)), cell, bool(data.get("rotated", false)))
	elif str(data.get("origin", "")) == "bag":
		result = copy.move(int(data.get("uid", -1)), cell, bool(data.get("rotated", false)))
	else:
		return _failure("未选择物件。")
	if not result.ok:
		return result
	var item: Dictionary = copy.item_by_uid(int(result.uid))
	result["item"] = item.duplicate(true)
	result["size"] = copy.get_item_size(item)
	result["combat"] = copy.get_combat_config()
	result["support_bonus"] = copy.get_adjacency_bonus(item)
	return result

func _place_or_merge(candidate: Dictionary, cell: Vector2i, owned: bool) -> Dictionary:
	var uid: int = int(candidate["uid"])
	var target: Dictionary = item_at(cell)
	if not target.is_empty() and int(target["uid"]) != uid:
		var product_kind: String = get_merge_result(candidate, target)
		if product_kind.is_empty():
			return _failure("目标不符合任何本职业配方。")
		var product: Dictionary = {"uid": target["uid"], "kind": product_kind, "pos": target["pos"], "rotated": candidate["rotated"]}
		var ignored: Array = [int(target["uid"])]
		if owned:
			ignored.append(uid)
		if not _can_place_ignoring(product, product["pos"], ignored):
			return _failure("合成产物空间不足；材料、来源次数与金币均已保留。")
		if owned:
			_remove_uid(uid)
		var actual_target: Dictionary = item_by_uid(int(target["uid"]))
		actual_target["kind"] = product_kind
		actual_target["rotated"] = candidate["rotated"]
		return {"ok": true, "event": "merge", "uid": target["uid"], "kind": product_kind, "message": "合成完成：" + str(get_definition(product_kind)["name"])}
	var ignore_uid: int = uid if owned else -1
	if not can_place(candidate, cell, ignore_uid):
		return _failure("物件越界、空间被占用或不属于当前职业。")
	if owned:
		var actual_item: Dictionary = item_by_uid(uid)
		actual_item["pos"] = cell
		actual_item["rotated"] = candidate["rotated"]
	else:
		candidate["pos"] = cell
		items.append(candidate)
	return {"ok": true, "event": "move" if owned else "acquire", "uid": uid, "kind": candidate["kind"], "message": "已放置：" + str(get_definition(candidate["kind"])["name"])}

func discard(uid: int) -> Dictionary:
	if phase != "prepare":
		return _failure("只有整备阶段可以舍弃物件。")
	var item: Dictionary = item_by_uid(uid)
	if item.is_empty():
		return _failure("未找到物件。")
	var materials: Dictionary = get_definition(str(item["kind"]))["materials"]
	for kind: Variant in materials:
		discarded_materials[kind] = int(discarded_materials.get(kind, 0)) + int(materials[kind])
	_remove_uid(uid)
	return {"ok": true, "event": "discard", "message": "已舍弃；不会退款或返还元素。"}

func _remove_uid(uid: int) -> void:
	for index: int in range(items.size()):
		if int(items[index]["uid"]) == uid:
			items.remove_at(index)
			return

func get_merge_result(source: Dictionary, target: Dictionary) -> String:
	var first: String = str(source.get("kind", ""))
	var second: String = str(target.get("kind", ""))
	var first_def: Dictionary = get_definition(first)
	var second_def: Dictionary = get_definition(second)
	if first_def.is_empty() or second_def.is_empty():
		return ""
	if str(first_def["class_id"]) != class_id or str(second_def["class_id"]) != class_id:
		return ""
	for recipe: Dictionary in Catalog.recipes_for(class_id):
		if (first == recipe["first"] and second == recipe["second"]) or (second == recipe["first"] and first == recipe["second"]):
			return str(recipe["result"])
	return ""

func get_support_cells(item: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var definition: Dictionary = get_definition(str(item.get("kind", "")))
	if definition.is_empty() or str(definition["category"]) != "support":
		return cells
	var size: Vector2i = get_item_size(item)
	var pos: Vector2i = item["pos"]
	if bool(item.get("rotated", false)):
		for x: int in range(size.x):
			cells.append(pos + Vector2i(x, -1))
			cells.append(pos + Vector2i(x, size.y))
	else:
		for y: int in range(size.y):
			cells.append(pos + Vector2i(-1, y))
			cells.append(pos + Vector2i(size.x, y))
	return cells

func get_adjacency_bonus(item: Dictionary) -> int:
	var definition: Dictionary = get_definition(str(item.get("kind", "")))
	if definition.is_empty() or str(definition["category"]) != "attack" or str(definition["class_id"]) != class_id:
		return 0
	var bonus: int = 0
	var rect: Rect2i = Rect2i(item["pos"], get_item_size(item))
	for support: Dictionary in items:
		var support_def: Dictionary = get_definition(str(support["kind"]))
		if support_def.is_empty() or str(support_def["class_id"]) != class_id:
			continue
		for cell: Vector2i in get_support_cells(support):
			if rect.has_point(cell):
				bonus += int(support_def.get("support_bonus", 0))
				break
	return bonus

func get_combat_config() -> Dictionary:
	var actions: Array[Dictionary] = []
	var supports: Array[Dictionary] = []
	var armor: int = 0
	for item: Dictionary in items:
		var definition: Dictionary = get_definition(str(item["kind"]))
		if definition.is_empty() or str(definition["class_id"]) != class_id:
			continue
		armor += int(definition.get("armor", 0))
		if str(definition["category"]) == "attack":
			var bonus: int = get_adjacency_bonus(item)
			actions.append({"uid": item["uid"], "kind": item["kind"], "name": definition["name"], "damage": int(definition["damage"]) + bonus, "base_damage": definition["damage"], "support_bonus": bonus, "hits": definition["hits"], "interval": definition["interval"], "warmup": definition["warmup"], "event_type": definition["event_type"]})
		elif str(definition["category"]) == "support":
			supports.append({"uid": item["uid"], "kind": item["kind"], "name": definition["name"], "bonus": definition["support_bonus"], "cells": get_support_cells(item)})
	return {"class_id": class_id, "hp": hp, "max_hp": max_hp, "armor": armor, "actions": actions, "supports": supports, "rules_version": Catalog.RULES_VERSION}

func _failure(message: String) -> Dictionary:
	return {"ok": false, "event": "rejected", "message": message}
