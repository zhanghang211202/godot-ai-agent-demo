extends SceneTree

const ClassRun = preload("res://scripts/classes/class_run.gd")
const Catalog = preload("res://scripts/classes/class_catalog.gd")

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_test_catalog_and_reset()
	_test_acquisition_atomicity()
	_test_placement_and_rotation()
	_test_spell_recipes()
	_test_product_space_and_rotation()
	_test_support_edges()
	_test_knight_chain()
	_test_discards_and_conservation()
	_test_phase_and_class_boundaries()
	print("ClassRun C0: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _state(run: RefCounted) -> Dictionary:
	return {"class_id": run.class_id, "items": run.items.duplicate(true), "sources": run.sources.duplicate(true), "gold": run.gold, "hp": run.hp, "max_hp": run.max_hp, "phase": run.phase, "seed": run.seed_value, "uid": run._next_uid, "discarded": run.discarded_materials.duplicate(true)}

func _new(id: String = "mage") -> RefCounted:
	var run: RefCounted = ClassRun.new()
	check(run.new_run(id, 9876)["ok"], "Known class can start: " + id)
	return run

func _test_catalog_and_reset() -> void:
	check(Catalog.GRID_SIZE == Vector2i(6, 4), "Class experiment retains 24-cell grid")
	check(Catalog.CLASS_IDS == ["mage", "knight"], "Only two C0 classes exist")
	check(Catalog.class_info("unknown").is_empty() and Catalog.definition("unknown").is_empty(), "Unknown catalog IDs do not silently resolve")
	var run: RefCounted = _new()
	check(run.seed_value == 9876 and run.hp == 84 and run.gold == 0, "Mage initial rules are explicit")
	check(run.items.size() == 4 and run._next_uid == 5, "Initial mage inventory owns stable unique instances")
	var before: Dictionary = _state(run)
	check(not run.new_run("unknown", 0)["ok"], "Unknown class reset is rejected")
	check(_state(run) == before, "Unknown reset is fully atomic")
	var detached: Array[Dictionary] = Catalog.initial_inventory("mage")
	detached[0]["kind"] = "greatblade"
	check(Catalog.initial_inventory("mage")[0]["kind"] == "spark", "Catalog provides independent inventories")
	check(run.new_run("knight", 22)["ok"] and run.hp == 96 and run.gold == 12, "Known reset changes class and resources")
	check(run.discarded_materials.is_empty() and run._next_uid == 3 and run.items.size() == 2, "Reset clears old resource ledger and instances")

func _test_acquisition_atomicity() -> void:
	var run: RefCounted = _new()
	var before: Dictionary = _state(run)
	check(not run.acquire(-1, Vector2i(3, 2))["ok"] and not run.acquire(99, Vector2i(3, 2))["ok"], "Invalid source indices fail")
	check(not run.acquire(0, Vector2i(-1, 0))["ok"], "Out-of-bounds absorption fails")
	check(not run.acquire(0, Vector2i(4, 0))["ok"], "Nonrecipe occupied tile blocks absorption")
	check(_state(run) == before, "All failed absorption attempts preserve state")
	check(run.acquire(0, Vector2i(3, 2))["ok"] and run.acquire(0, Vector2i(4, 2))["ok"], "Two finite fire shares are obtainable")
	check(run.gold == 0 and run.sources[0]["remaining"] == 0, "Free absorption consumes stock without spending gold")
	before = _state(run)
	check(not run.acquire(0, Vector2i(5, 3))["ok"] and _state(run) == before, "Exhausted source cannot produce extra material")
	check(run.item_at(Vector2i(3, 2))["kind"] == "fire_mote", "Absorbed element occupies an actual cell")

func _test_placement_and_rotation() -> void:
	var run: RefCounted = _new("knight")
	check(run.move(1, Vector2i(2, 3), true)["ok"], "Rotated three-cell blade fits bottom row")
	check(run.get_item_size(run.item_by_uid(1)) == Vector2i(3, 1), "Rotation changes rectangular footprint")
	check(run.item_at(Vector2i(4, 3))["uid"] == 1 and run.item_at(Vector2i(0, 2)).is_empty(), "Footprint lookup occupies and releases all cells")
	var before: Dictionary = _state(run)
	check(not run.move(1, Vector2i(5, 3), true)["ok"], "Rotated footprint cannot exceed right edge")
	check(not run.move(1, Vector2i(1, -1))["ok"], "Negative coordinate cannot place weapon")
	check(not run.move(9999, Vector2i.ZERO)["ok"] and _state(run) == before, "Invalid and blocked moves are atomic")
	check(run.move(1, Vector2i(5, 1), false)["ok"], "Unrotated blade fits exact right and bottom edge")
	check(run.can_place(run.item_by_uid(1), Vector2i(5, 1), 1), "Placement check can ignore moving instance")
	check(not run.can_place(run.item_by_uid(1), Vector2i(5, 1)), "Placement check detects original occupied instance")

func _test_spell_recipes() -> void:
	var run: RefCounted = _new()
	check(run.get_merge_result({"kind": "fire_mote"}, {"kind": "spark"}) == "flame_glyph", "Fire and basic structure form burst spell")
	check(run.get_merge_result({"kind": "spark"}, {"kind": "fire_mote"}) == "flame_glyph", "Recipe direction is symmetric")
	check(run.get_merge_result({"kind": "fire_mote"}, {"kind": "fire_mote"}).is_empty(), "Unlisted same-element combination creates no free output")
	check(run.acquire(0, Vector2i.ZERO)["event"] == "merge", "Element source may weave directly onto starter spell")
	check(run.item_by_uid(1)["kind"] == "flame_glyph" and run.items.size() == 4, "Direct weave replaces target and consumes source exactly once")
	check(run._next_uid == 6 and run.sources[0]["remaining"] == 1, "Direct weave records acquisition even when retaining target UID")
	check(run.acquire(1, Vector2i(3, 3))["ok"], "Water can be acquired normally")
	var water_uid: int = int(run.item_at(Vector2i(3, 3))["uid"])
	check(run.acquire(2, Vector2i(3, 3))["event"] == "merge", "Wind weaves with owned water")
	check(run.item_by_uid(water_uid)["kind"] == "tide_lances", "Water target retains identity as multihit spell")
	var config: Dictionary = run.get_combat_config()
	var burst: Dictionary = {}
	var multi: Dictionary = {}
	for action: Dictionary in config["actions"]:
		if action["kind"] == "flame_glyph": burst = action
		if action["kind"] == "tide_lances": multi = action
	check(not burst.is_empty() and not multi.is_empty(), "Legal starting resources reach two real spell behaviors together")
	check(burst["hits"] == 1 and burst["event_type"] == "spell_burst" and burst["interval"] == 3.0, "Burst has single high-damage automatic behavior")
	check(multi["hits"] == 3 and multi["event_type"] == "spell_multi" and multi["interval"] == 2.6, "Tide has a distinct three-hit cadence")
	check(config["armor"] == 2 and config["class_id"] == "mage" and config["rules_version"] == 1, "Combat config carries explicit class defense and version")
	check(_is_conserved(run), "Two spell acquisitions conserve all raw ingredients")

func _test_product_space_and_rotation() -> void:
	var run: RefCounted = _new()
	check(run.acquire(1, Vector2i(5, 3))["ok"], "One-cell water fits bottom-right")
	var before: Dictionary = _state(run)
	check(not run.acquire(2, Vector2i(5, 3))["ok"], "Larger direct weave checks full product footprint")
	check(_state(run) == before, "Failed direct weave consumes no source, money, UID or material")
	var water_uid: int = int(run.item_at(Vector2i(5, 3))["uid"])
	check(run.move(water_uid, Vector2i(3, 0))["ok"], "Water moves beside occupied ward")
	check(run.acquire(2, Vector2i(5, 3))["ok"], "Wind is acquired into its own physical cell")
	var wind_uid: int = int(run.item_at(Vector2i(5, 3))["uid"])
	before = _state(run)
	check(not run.move(wind_uid, Vector2i(3, 0), false)["ok"], "Horizontal tide output cannot overlap ward")
	check(_state(run) == before, "Failed owned-material weave preserves both ingredients and orientation")
	check(run.move(wind_uid, Vector2i(3, 0), true)["event"] == "merge", "Rotating product permits valid vertical weave")
	check(run.get_item_size(run.item_by_uid(water_uid)) == Vector2i(1, 3), "Product uses requested orientation rather than old material dimensions")
	check(run.item_by_uid(wind_uid).is_empty() and run.item_at(Vector2i(3, 2))["uid"] == water_uid, "Owned weave consumes source and occupies new full footprint")
	check(_is_conserved(run), "Rotated merge preserves constituent ledger")

func _test_support_edges() -> void:
	var run: RefCounted = _new()
	check(run.get_adjacency_bonus(run.item_by_uid(1)) == 0, "Initial focus has no invisible global effect")
	check(run.acquire(0, Vector2i.ZERO)["ok"], "Burst formed for edge test")
	check(run.get_adjacency_bonus(run.item_by_uid(1)) == 2, "Support touches distant occupied edge, not only target origin")
	check(run.move(3, Vector2i(2, 1), true)["ok"], "Square support may rotate direction without changing footprint")
	check(run.get_adjacency_bonus(run.item_by_uid(1)) == 0, "Rotation removes horizontal connection")
	check(run.move(3, Vector2i(1, 2), true)["ok"], "Rotated support can connect upward to wide spell")
	check(run.get_adjacency_bonus(run.item_by_uid(1)) == 2, "Upward connection uses true spell footprint")
	check(run.get_adjacency_bonus(run.item_by_uid(4)) == 0, "Armor receives no accidental attack bonus")
	var actions: Array = run.get_combat_config()["actions"]
	check(actions[0]["damage"] == 20 and actions[0]["support_bonus"] == 2 and actions[0]["base_damage"] == 18, "Config reports effective and explainable supported damage")

func _test_knight_chain() -> void:
	var run: RefCounted = _new("knight")
	var before: Dictionary = _state(run)
	check(not run.acquire(0, Vector2i(5, 3))["ok"] and _state(run) == before, "Failed paid purchase preserves stock and gold")
	check(run.acquire(1, Vector2i.ZERO)["event"] == "merge", "Normal paid armory chain forges greatblade from starter")
	check(run.gold == 8 and run.sources[1]["remaining"] == 1, "Forging pays one seal price and one share")
	check(run.get_item_size(run.item_by_uid(1)) == Vector2i(2, 3), "Heavy weapon consumes six real cells")
	check(run.acquire(1, Vector2i(2, 1))["ok"] and run.gold == 4, "Second finite seal can support forged blade")
	check(run.get_adjacency_bonus(run.item_by_uid(1)) == 4, "Knight support is derived from connected occupied edge")
	var action: Dictionary = run.get_combat_config()["actions"][0]
	check(action["kind"] == "greatblade" and action["event_type"] == "heavy_charge", "Heavy blade retains distinct source and charge event category")
	check(action["damage"] == 36 and action["warmup"] == 1.4 and action["interval"] == 3.2, "Heavy action uses charge timing and support amount")
	before = _state(run)
	check(not run.acquire(0, Vector2i(3, 1))["ok"] and _state(run) == before, "Insufficient gold purchase is atomic")
	check(not run.acquire(1, Vector2i(5, 3))["ok"] and _state(run) == before, "Second seal exhausts finite support stock")
	check(run.acquire(2, Vector2i(3, 3))["ok"] and run.gold == 1, "Affordable defense purchase spends exact remaining gold")
	check(run.get_combat_config()["armor"] == 4, "Multiple physical ward items contribute explicit armor")
	check(_is_conserved(run), "Natural heavy route conserves purchased materials")

func _test_discards_and_conservation() -> void:
	var run: RefCounted = _new("knight")
	check(run.acquire(1, Vector2i.ZERO)["ok"], "Greatblade obtained before discard")
	var before_gold: int = run.gold
	check(run.discard(1)["ok"] and run.gold == before_gold, "Discard does not refund money")
	check(run.discarded_materials == {"iron_blade": 1, "charge_seal": 1}, "Discarded product accounts for both raw constituents")
	check(_is_conserved(run), "Discarded product remains included in conservation")
	var before: Dictionary = _state(run)
	check(not run.discard(1)["ok"] and _state(run) == before, "Repeated discard cannot produce extra loss or refund")
	check(run.new_run("mage")["ok"] and run.discarded_materials.is_empty(), "New run removes prior class discard ledger")

func _test_phase_and_class_boundaries() -> void:
	var run: RefCounted = _new()
	check(not run.can_place({"kind": "iron_blade", "rotated": false}, Vector2i(3, 1)), "Mage cannot place knight-only equipment")
	check(run.get_merge_result({"kind": "iron_blade"}, {"kind": "charge_seal"}).is_empty(), "Mage cannot invoke knight-only recipe")
	check(not run.can_place({"kind": "not_an_item"}, Vector2i(3, 1)), "Unknown item cannot be placed")
	run.sources[0]["kind"] = "charge_seal"
	var before: Dictionary = _state(run)
	check(not run.acquire(0, Vector2i(3, 1))["ok"] and _state(run) == before, "Foreign source kind is rejected atomically")
	run.new_run("mage")
	run.phase = "battle"
	before = _state(run)
	check(not run.acquire(0, Vector2i(3, 1))["ok"], "Battle cannot acquire new resources")
	check(not run.move(1, Vector2i(3, 1))["ok"] and not run.discard(1)["ok"], "Battle cannot move or discard items")
	check(_state(run) == before, "Forbidden battle preparation mutations leave state intact")

func _is_conserved(run: RefCounted) -> bool:
	var budget: Dictionary = {}
	for item: Dictionary in Catalog.initial_inventory(run.class_id):
		_add_materials(budget, Catalog.definition(str(item["kind"]))["materials"])
	var initial: Array[Dictionary] = Catalog.initial_sources(run.class_id)
	for index: int in range(initial.size()):
		var count: int = int(initial[index]["remaining"]) - int(run.sources[index]["remaining"])
		var source_materials: Dictionary = Catalog.definition(str(initial[index]["kind"]))["materials"]
		for kind: Variant in source_materials:
			budget[kind] = int(budget.get(kind, 0)) + int(source_materials[kind]) * count
	var actual: Dictionary = run.discarded_materials.duplicate(true)
	for item: Dictionary in run.items:
		_add_materials(actual, Catalog.definition(str(item["kind"]))["materials"])
	for kind: Variant in budget.keys():
		if int(budget[kind]) == 0:
			budget.erase(kind)
	return actual == budget

func _add_materials(total: Dictionary, materials: Dictionary) -> void:
	for kind: Variant in materials:
		total[kind] = int(total.get(kind, 0)) + int(materials[kind])
