extends SceneTree

const Battle = preload("res://scripts/classes/class_battle.gd")
const ClassRun = preload("res://scripts/classes/class_run.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_test_spell_shapes_and_sources()
	_test_heavy_warmup()
	_test_determinism_and_pause()
	_test_validation_and_copy()
	_test_resolution_and_statistics()
	_test_long_frame_timeout_restart()
	_test_normal_class_getting_chains()
	print("ClassBattle C0: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _action(kind: String = "spark", damage: int = 5, hits: int = 1,
	interval: float = 1.5, warmup: float = 0.4, uid: int = 1) -> Dictionary:
	return {"uid": uid, "kind": kind, "name": "Source " + kind, "damage": damage,
		"hits": hits, "interval": interval, "warmup": warmup,
		"event_type": "heavy_charge" if kind == "greatblade" else "spell"}

func _config(actions: Array = [], class_id: String = "mage", health: int = 84, armor: int = 2) -> Dictionary:
	return {"class_id": class_id, "hp": health, "max_hp": health, "armor": armor,
		"actions": actions, "rules_version": 1}

func _damage_events(events: Array) -> Array:
	return events.filter(func(event: Dictionary) -> bool:
		return event["target"] == "enemy" and event["amount"] > 0)

func _finish(battle: RefCounted, delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for _frame in range(10000):
		if battle.phase != "battle":
			break
		events.append_array(battle.tick(delta))
	return events

func _test_spell_shapes_and_sources() -> void:
	var burst = Battle.new()
	var burst_action := _action("flame_glyph", 18, 1, 3.0, 1.6)
	burst_action["event_type"] = "spell_burst"
	check(burst.start(_config([burst_action]))["ok"], "A burst source starts")
	var burst_events: Array = _damage_events(burst.tick(1.6))
	check(burst_events.size() == 1 and burst_events[0]["amount"] == 18, "Burst is a single 18-damage hit")
	check(burst_events[0]["type"] == "spell_burst" and is_equal_approx(burst_events[0]["time"], 1.6), "Burst preserves event type and quantized warmup")
	var multi = Battle.new()
	var multi_action := _action("tide_lances", 5, 3, 2.6, 0.8, 27)
	multi_action["event_type"] = "spell_multi"
	check(multi.start(_config([multi_action]))["ok"], "A three-hit source starts")
	var events: Array = _damage_events(multi.tick(0.8))
	check(events.size() == 3, "One multi activation emits three bounded hits")
	for index in range(events.size()):
		check(events[index]["hit_index"] == index + 1 and events[index]["amount"] == 5, "Multi hit has an ordered index and its own damage")
		check(events[index]["source_uid"] == 27 and events[index]["source_kind"] == "tide_lances" and events[index]["source_name"] == "Source tide_lances", "Every multi hit keeps its exact source")
		check(is_equal_approx(events[index]["time"], 0.8) and events[index]["type"] == "spell_multi", "Multi hits resolve within one activation time")
	var summary: Dictionary = multi.get_summary()
	check(summary["by_source"][0]["activations"] == 1 and summary["by_source"][0]["hits"] == 3, "Statistics distinguish activation from hit count")
	check(summary["damage_dealt"] == 15 and multi.enemy_hp == 125, "Multi-source statistics equal HP loss")

func _test_heavy_warmup() -> void:
	var battle = Battle.new()
	var config := _config([_action("greatblade", 32, 1, 3.2, 1.4, 42)], "knight", 96)
	check(battle.start(config)["ok"], "Heavy knight starts")
	var first: Array = battle.tick(1.35)
	check(_damage_events(first).is_empty() and battle.enemy_hp == 140, "Warmup never applies early damage")
	check(first.size() == 1 and first[0]["type"] == "charge" and first[0]["time"] == 0.0 and first[0]["source_uid"] == 42, "Charge event occurs at time zero with source")
	var release: Array = _damage_events(battle.tick(0.05))
	check(release.size() == 1 and release[0]["amount"] == 32 and is_equal_approx(release[0]["time"], 1.4), "First heavy hit happens at its warmup boundary")
	var next: Array = battle.tick(3.2)
	var charges: Array = next.filter(func(event: Dictionary) -> bool: return event["type"] == "charge")
	var strikes: Array = _damage_events(next)
	check(charges.size() == 1 and is_equal_approx(charges[0]["time"], 3.2), "Repeated heavy hit has a new advance charge")
	check(strikes.size() == 1 and is_equal_approx(strikes[0]["time"], 4.6) and strikes[0]["source_kind"] == "greatblade", "Heavy repeats on interval, retaining source")
	check(battle.get_summary()["by_source"][0]["activations"] == 2, "Charge does not count as a damage activation")

func _test_determinism_and_pause() -> void:
	var config := _config([_action("flame_glyph", 18, 1, 3.0, 1.6), _action("tide_lances", 5, 3, 2.6, 0.8, 2)])
	var normal = Battle.new()
	var double_speed = Battle.new()
	var chunked = Battle.new()
	var varied = Battle.new()
	for battle in [normal, double_speed, chunked, varied]:
		check(battle.start(config)["ok"], "Determinism fixture starts")
	var normal_events := _finish(normal, 1.0 / 60.0)
	var double_events := _finish(double_speed, 2.0 / 60.0)
	var chunk_events := _finish(chunked, 0.7)
	var varied_events: Array[Dictionary] = []
	var frame := 0
	while varied.phase == "battle":
		varied_events.append_array(varied.tick([0.013, 0.087, 0.002, 0.298][frame % 4]))
		frame += 1
	check(normal_events == double_events and normal_events == chunk_events and normal_events == varied_events, "1x, 2x, long chunks and varying frames produce identical events")
	check(normal.get_summary() == double_speed.get_summary() and normal.get_summary() == chunked.get_summary() and normal.get_summary() == varied.get_summary(), "Frame schedules have identical complete statistics")
	var paused_battle = Battle.new()
	paused_battle.start(config)
	var prefix: Array[Dictionary] = paused_battle.tick(0.413)
	var before: Dictionary = paused_battle.get_summary()
	paused_battle.paused = true
	check(paused_battle.tick(80.0).is_empty(), "Paused battle emits no events")
	check(paused_battle.get_summary() == before, "Paused battle preserves timers and statistics")
	paused_battle.paused = false
	prefix.append_array(_finish(paused_battle, 0.071))
	check(prefix == normal_events and paused_battle.get_summary() == normal.get_summary(), "Resume preserves deterministic accumulator remainder")

func _test_validation_and_copy() -> void:
	var battle = Battle.new()
	var valid := _config([_action("greatblade", 32, 1, 3.2, 1.4)], "knight", 96)
	check(battle.start(valid)["ok"], "Validation baseline starts")
	battle.tick(0.35)
	var invalid: Array[Dictionary] = []
	for key in ["class_id", "hp", "max_hp", "armor", "rules_version", "actions"]:
		var missing := valid.duplicate(true)
		missing.erase(key)
		invalid.append(missing)
	for pair in [["class_id", "alchemist"], ["hp", 0], ["hp", 97], ["max_hp", 10001], ["armor", -1], ["armor", 101], ["hp", 96.0], ["rules_version", 2], ["actions", []]]:
		var corrupted := valid.duplicate(true)
		corrupted[pair[0]] = pair[1]
		invalid.append(corrupted)
	for pair in [["uid", 0], ["damage", -1], ["damage", 1.5], ["hits", 0], ["hits", 17], ["interval", 0.0], ["interval", INF], ["interval", NAN], ["warmup", -1.0], ["warmup", INF], ["warmup", 4.0], ["kind", ""], ["name", 4], ["event_type", ""]]:
		var corrupted := valid.duplicate(true)
		corrupted["actions"][0][pair[0]] = pair[1]
		invalid.append(corrupted)
	var duplicate := valid.duplicate(true)
	duplicate["actions"].append(duplicate["actions"][0].duplicate(true))
	invalid.append(duplicate)
	var before: Dictionary = battle.get_summary()
	for candidate: Dictionary in invalid:
		check(not battle.start(candidate)["ok"], "Invalid config is rejected")
		check(battle.get_summary() == before and battle.phase == "battle", "Rejected start preserves current battle atomically")
	var clean = Battle.new()
	clean.start(valid)
	clean.tick(0.35)
	check(_finish(battle, 0.05) == _finish(clean, 0.05), "Rejected starts preserve pending charge and fractional timers")
	var copied = Battle.new()
	var config := _config([_action("spark", 5)])
	copied.start(config)
	config["actions"][0]["damage"] = 10000
	config["actions"].clear()
	config["hp"] = 1
	var hits: Array = _damage_events(copied.tick(0.4))
	check(hits.size() == 1 and hits[0]["amount"] == 5 and copied.hp == 84, "Caller mutations cannot change copied combat inputs")
	var summary: Dictionary = copied.get_summary()
	summary["by_source"][0]["damage"] = 9000
	check(copied.get_summary()["by_source"][0]["damage"] == 5, "Summary copies do not expose engine statistics")
	var bad_delta_before: Dictionary = copied.get_summary()
	for delta in [-0.001, -200.0, INF, NAN, 0.0]:
		check(copied.tick(delta).is_empty() and copied.get_summary() == bad_delta_before, "Invalid or zero delta has no effect")

func _test_resolution_and_statistics() -> void:
	# At exactly 1.8 seconds both actors are ready. The hero wins the tie.
	var battle = Battle.new()
	battle.start(_config([_action("finisher", 200, 3, 1.8, 1.8), _action("second", 10, 1, 1.8, 1.8, 2)], "mage", 8, 0))
	var events: Array = battle.tick(1.8)
	var hits: Array = _damage_events(events)
	check(battle.phase == "won" and battle.hp == 8 and battle.enemy_hp == 0, "Hero lethal hit wins simultaneous attack boundary")
	check(hits.size() == 1 and hits[0]["amount"] == 140 and hits[0]["raw_amount"] == 200, "First lethal multi hit clips effective damage and stops remaining hits")
	check(events.filter(func(event: Dictionary) -> bool: return event["type"] == "enemy_attack").is_empty(), "Dead enemy cannot deal its scheduled damage")
	var summary: Dictionary = battle.get_summary()
	check(summary["damage_dealt"] == 140 and summary["raw_damage_dealt"] == 200 and summary["overkill_damage_dealt"] == 60, "Raw and effective damage are explicitly separated")
	check(summary["by_source"][1]["activations"] == 0 and summary["by_source"][1]["damage"] == 0, "Later same-step source never activates after a kill")
	check(events[-1]["type"] == "battle_end" and events[-1]["result"] == "won", "Exactly ordered terminal event follows lethal hit")
	for index in range(events.size()):
		check(events[index]["event_id"] == index + 1, "Every event receives a consecutive unique ID")
	var finished: Dictionary = battle.get_summary()
	check(battle.tick(100.0).is_empty() and battle.get_summary() == finished, "Finished battle never produces further events or statistics")
	var losing = Battle.new()
	losing.start(_config([_action("slow", 1, 1, 90.0, 90.0)], "mage", 5, 2))
	var loss_events: Array = losing.tick(2.0)
	var loss: Dictionary = losing.get_summary()
	check(losing.phase == "lost" and losing.hp == 0 and is_equal_approx(loss["duration"], 1.8), "Enemy lethal attack ends battle once")
	check(loss["raw_damage_taken"] == 8 and loss["armor_mitigated"] == 2 and loss["damage_taken"] == 5 and loss["overkill_damage_taken"] == 1, "Armor, overkill and effective received damage reconcile")
	check(loss_events[-1]["result"] == "lost" and losing.tick(90.0).is_empty(), "Loss emits one terminal result")
	var mixed = Battle.new()
	mixed.start(_config([_action("burst", 18, 1, 3.0, 1.6), _action("multi", 5, 3, 2.6, 0.8, 2)]))
	var all_events := _finish(mixed, 0.05)
	var damage_dealt := 0
	var damage_taken := 0
	var terminal_events := 0
	for event: Dictionary in all_events:
		if event["target"] == "enemy":
			damage_dealt += event["amount"]
		else:
			damage_taken += event["amount"]
		if event["type"] == "battle_end":
			terminal_events += 1
	var total: Dictionary = mixed.get_summary()
	var source_damage := 0
	for source: Dictionary in total["by_source"]:
		source_damage += source["damage"]
	check(damage_dealt == 140 - mixed.enemy_hp and total["damage_dealt"] == damage_dealt and source_damage == damage_dealt, "Event damage, source statistics and enemy HP agree")
	check(damage_taken == 84 - mixed.hp and total["damage_taken"] == damage_taken, "Enemy events, statistics and hero HP agree")
	check(terminal_events == 1, "Full simulation produces exactly one terminal event")

func _test_long_frame_timeout_restart() -> void:
	var config := _config([_action("slow", 1, 1, 90.0, 90.0)], "mage", 10000, 100)
	var long_frame = Battle.new()
	var small_frames = Battle.new()
	long_frame.start(config)
	small_frames.start(config)
	var long_events: Array = long_frame.tick(1000000000.0)
	var small_events := _finish(small_frames, 0.05)
	check(long_events == small_events and long_frame.get_summary() == small_frames.get_summary(), "Very long frame processes all relevant fixed steps within battle limit")
	check(long_frame.phase == "lost" and long_frame.get_summary()["result"] == "timeout" and long_frame.battle_time == 90.0, "No-kill battle has an explicit 90-second timeout")
	check(long_events.size() < 100 and long_frame.hp == 9950, "Timeout event count and armor-reduced damage stay bounded")
	var fresh = Battle.new()
	var fresh_config := _config([_action("greatblade", 32, 1, 3.2, 1.4)], "knight", 96)
	fresh.start(fresh_config)
	long_frame.paused = true
	check(long_frame.start(fresh_config)["ok"] and not long_frame.paused, "Restart resets paused state")
	check(long_frame.battle_time == 0.0 and long_frame.battle_duration == 0.0 and long_frame.hp == 96 and long_frame.enemy_hp == 140, "Restart clears terminal result, HP and clock")
	check(_finish(long_frame, 0.013) == _finish(fresh, 0.013) and long_frame.get_summary() == fresh.get_summary(), "Restart clears old accumulator, events, timers, IDs and statistics")
	var rounding = Battle.new()
	rounding.start(_config([_action("odd", 5, 1, 1.113, 0.101)]))
	check(_damage_events(rounding.tick(0.149)).is_empty(), "Non-grid warmup never fires earlier than configured")
	var rounded: Array = _damage_events(rounding.tick(0.001))
	check(rounded.size() == 1 and is_equal_approx(rounded[0]["time"], 0.15), "Non-grid timing rounds upward to the next 50 ms step")

func _test_normal_class_getting_chains() -> void:
	# These builds come from the actual finite sources, rather than spawning a
	# final weapon directly into the test configuration.
	for class_id in ["mage", "knight"]:
		var run = ClassRun.new()
		check(run.new_run(class_id)["ok"], "Normal class initialization succeeds")
		var baseline = Battle.new()
		check(baseline.start(run.get_combat_config())["ok"], "Unmodified ClassRun configuration is accepted")
		_finish(baseline, 0.05)
		check(baseline.phase == "won", "The actual starter build can finish the training opponent")
		if class_id == "mage":
			check(run.acquire(0, Vector2i.ZERO)["ok"], "Normal fire absorption weaves the starter spell")
			check(run.acquire(1, Vector2i(3, 2))["ok"], "Normal water absorption occupies inventory space")
			check(run.acquire(2, Vector2i(3, 2))["ok"], "Normal wind absorption weaves a multi spell")
		else:
			check(run.acquire(1, Vector2i.ZERO)["ok"], "Normal armory purchase forges the starter blade")
			check(run.acquire(1, Vector2i(2, 1))["ok"], "Remaining paid support connects to the large blade")
		var upgraded = Battle.new()
		check(upgraded.start(run.get_combat_config())["ok"], "Normally obtained class build is accepted")
		var events := _finish(upgraded, 0.037)
		check(upgraded.phase == "won" and upgraded.battle_duration < baseline.battle_duration, "Legal class progression produces a faster completed training battle")
		var source_kinds: Array = []
		for event: Dictionary in _damage_events(events):
			if event["source_kind"] not in source_kinds:
				source_kinds.append(event["source_kind"])
		if class_id == "mage":
			check("flame_glyph" in source_kinds and "tide_lances" in source_kinds, "Normal mage chain produces both differently behaving spell sources")
		else:
			check("greatblade" in source_kinds, "Normal knight chain produces the heavy weapon source")
