extends RefCounted
## An isolated deterministic combat rehearsal. Never changes the real run,
## real battle, RNG, checkpoint, animation, or source inventory.

const Battle = preload("res://scripts/classes/class_battle.gd")
const Encounters = preload("res://scripts/classes/mage_encounters.gd")

static func simulate(run: RefCounted, encounter_ids: Array = Encounters.IDS) -> Dictionary:
	if run == null or run.class_id != "mage" or run.phase != "prepare":
		return {"ok": false, "message": "予行演習は魔術師の準備中に行えます。"}
	var config: Dictionary = run.get_combat_config()
	var encounters: Array[Dictionary] = []
	if encounter_ids.is_empty():
		return {"ok": false, "message": "予行演習の相手がありません。"}
	for id in encounter_ids:
		var simulation = Battle.new()
		var started: Dictionary = simulation.start(config, id)
		if not started.ok:
			return started
		simulation.tick(Battle.TIME_LIMIT)
		encounters.append({"id": id, "name": Encounters.definition(id).name,
			"summary": simulation.get_summary()})
	return {"ok": true, "encounters": encounters}
