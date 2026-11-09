extends SceneTree
## Deterministic, legal boards give a repeatable balance baseline, not a player study.
const Run = preload("res://scripts/classes/class_run.gd")
const Battle = preload("res://scripts/classes/class_battle.gd")
const Campaign = preload("res://scripts/classes/mage_campaign.gd")
const Encounters = preload("res://scripts/classes/mage_encounters.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	var beginner := Run.new()
	beginner.new_run("mage")
	var opening := _fight(beginner, 0)
	check(opening.phase == "won" and opening.hp >= 30, "Unchanged starter board can learn the first battle with room to spare")
	check(_fight(beginner, 2).phase == "lost", "Starter board does not trivialize the later campaign")
	var mixed := Run.new()
	mixed.new_run("mage")
	for op in [[0, Vector2i.ZERO], [1, Vector2i(3, 2)], [2, Vector2i(3, 2)]]:
		check(mixed.acquire(op[0], op[1]).ok, "Mixed build legally acquires and weaves free elements")
	var last_hp := mixed.max_hp
	var last_duration := 0.0
	for stage in range(5):
		var battle := _fight(mixed, stage)
		print("Balance mixed stage %d: %s HP %d time %.2f" % [stage + 1, battle.phase, battle.hp, battle.battle_time])
		check(battle.phase == "won", "Mixed build beats stage %d" % (stage + 1))
		check(battle.hp <= last_hp and battle.battle_time >= last_duration, "Mixed build observes rising pressure at stage %d" % (stage + 1))
		last_hp = battle.hp
		last_duration = battle.battle_time
	var specialist := Run.new()
	specialist.new_run("mage")
	for op in [[0, Vector2i(3, 1)], [0, Vector2i(3, 1)], [1, Vector2i(5, 1)], [1, Vector2i(5, 1)], [2, Vector2i(1, 2)], [2, Vector2i(1, 2)]]:
		check(specialist.acquire(op[0], op[1]).ok, "Same-element build legally weaves its ingredients")
	var first_specialist_hp := 0
	var first_specialist_duration := 0.0
	for stage in range(5):
		var battle := _fight(specialist, stage)
		print("Balance specialist stage %d: %s HP %d time %.2f" % [stage + 1, battle.phase, battle.hp, battle.battle_time])
		check(battle.phase == "won", "Same-element build beats stage %d" % (stage + 1))
		if stage == 0:
			first_specialist_hp = battle.hp
			first_specialist_duration = battle.battle_time
		if stage == 4:
			check(battle.hp >= 10 and battle.hp <= 50 and battle.battle_time >= 9.0 and battle.battle_time <= 16.0, "Specialist boss fight remains viable while allowing meaningful enemy pressure")
			check(battle.hp < first_specialist_hp and battle.battle_time > first_specialist_duration, "The final battle pressures this build more than the opening fight")
	check(Encounters.definition("sentinel").hp == 140 and Encounters.definition("mirror_moth").hp == 108 and Encounters.definition("thorn_golem").hp == 220, "Legacy single-trial enemies retain original balance")
	_campaign_v2_pressure()
	print("Mage balance: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _campaign_v2_pressure() -> void:
	# These boards spend only the actual v2 opening budget and receive no
	# rewards. They measure pressure without pretending this is human play.
	for build in ["starter", "mixed", "familiar", "haste"]:
		var run := Run.new()
		run.new_run("mage")
		run.campaign_rules_version = 2
		run.sources = Campaign.initial_sources(2)
		var operations := []
		match build:
			"mixed":
				operations = [[0, Vector2i.ZERO], [1, Vector2i(3, 2)], [2, Vector2i(3, 2)]]
			"familiar":
				operations = [[1, Vector2i(2, 1)], [0, Vector2i.ZERO], [2, Vector2i(0, 2)]]
			"haste":
				operations = [[2, Vector2i(2, 1)], [0, Vector2i.ZERO], [1, Vector2i(0, 2)]]
		for operation: Array in operations:
			check(run.acquire(operation[0], operation[1]).ok, build + " spends only one of each v2 starting element")
		check(run.gold == 0 and run.sources.slice(0, 3).all(func(source: Dictionary): return source.remaining <= 1), build + " has no earned resources or legacy free stock")
		var first: RefCounted = _fight(run, 0)
		var fourth: RefCounted = _fight(run, 3)
		var boss: RefCounted = _fight(run, 4)
		print("V2 opening-only ", build, ": first=", first.phase, " HP ", first.hp, " fourth=", fourth.phase, " HP ", fourth.hp, " boss=", boss.phase, " HP ", boss.hp)
		check(first.phase == "won" and first.hp >= 30, build + " opening is survivable")
		check(fourth.hp < first.hp and boss.hp < first.hp, build + " encounters exert more pressure later")
		if build == "starter":
			check(fourth.phase == "lost" and boss.phase == "lost", "An unchanged starter board cannot coast through the late campaign")
		elif build == "haste":
			check(fourth.phase == "lost" and boss.phase == "lost", "Unupgraded haste needs further development against late enemies")
		else:
			check(fourth.phase == "won" and boss.phase == "won" and boss.hp > 0 and boss.hp <= 10, build + " no-reward boss win has a narrow margin")

func _fight(run: RefCounted, stage: int) -> RefCounted:
	var battle := Battle.new()
	var result: Dictionary = battle.start(run.get_combat_config(), Campaign.encounter(stage))
	check(result.ok, "Legal build starts stage %d" % (stage + 1))
	battle.tick(Battle.TIME_LIMIT)
	return battle
