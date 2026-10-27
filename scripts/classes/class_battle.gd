extends RefCounted
## C0's one-battle rules. Drawing and animation never decide damage.
## Time is quantized upward to 50 ms. Hero actions resolve in input order,
## before an enemy attack on the same step. The first lethal hit ends the battle.

const STEP := 0.05
const TIME_LIMIT := 90.0
const MAX_STEPS := 1800
const ENEMY_HP := 140
const ENEMY_ATTACK := 8
const ENEMY_INTERVAL_STEPS := 36
const ENEMY_NAME := "训练守卫"
const ZERO_STATS := {"damage_dealt": 0, "raw_damage_dealt": 0, "damage_taken": 0,
	"raw_damage_taken": 0, "armor_mitigated": 0, "enemy_attacks": 0,
	"overkill_damage_dealt": 0, "overkill_damage_taken": 0}

var phase: String = "idle"
var hp: int = 0
var max_hp: int = 0
var enemy_hp: int = 0
var enemy_max_hp: int = ENEMY_HP
var enemy_name: String = ENEMY_NAME
var battle_time: float = 0.0
var battle_duration: float = 0.0
var paused: bool = false

var _config: Dictionary = {}
var _actions: Array[Dictionary] = []
var _stats: Dictionary = ZERO_STATS.duplicate(true)
var _by_source: Dictionary = {}
var _source_order: Array[int] = []
var _initial_events: Array[Dictionary] = []
var _event_id: int = 0
var _step_index: int = 0
var _enemy_next_step: int = ENEMY_INTERVAL_STEPS
var _accumulator: float = 0.0
var _result: String = "idle"
var _armor: int = 0

func start(config: Dictionary) -> Dictionary:
	# Validate and copy before modifying any running battle, including its timers.
	var error := _validate(config)
	if not error.is_empty():
		return {"ok": false, "message": error}
	_config = config.duplicate(true)
	_actions.clear()
	_by_source.clear()
	_source_order.clear()
	_initial_events.clear()
	_event_id = 0
	_step_index = 0
	_enemy_next_step = ENEMY_INTERVAL_STEPS
	_accumulator = 0.0
	battle_time = 0.0
	battle_duration = 0.0
	paused = false
	phase = "battle"
	_result = "battle"
	hp = int(_config["hp"])
	max_hp = int(_config["max_hp"])
	_armor = int(_config["armor"])
	enemy_hp = ENEMY_HP
	enemy_max_hp = ENEMY_HP
	enemy_name = ENEMY_NAME
	_stats = ZERO_STATS.duplicate(true)
	for source: Dictionary in _config["actions"]:
		var action: Dictionary = source.duplicate(true)
		var warmup_steps := _steps(float(action["warmup"]))
		var interval_steps := _steps(float(action["interval"]))
		action["interval_steps"] = interval_steps
		action["warmup_steps"] = warmup_steps
		action["next_step"] = warmup_steps if warmup_steps > 0 else interval_steps
		action["charge_step"] = 0 if warmup_steps > 0 else -1
		action["charged"] = warmup_steps > 0
		_actions.append(action)
		var uid: int = action["uid"]
		_source_order.append(uid)
		_by_source[uid] = {"uid": uid, "kind": action["kind"], "name": action["name"],
			"damage": 0, "raw_damage": 0, "activations": 0, "hits": 0}
		if warmup_steps > 0:
			_initial_events.append(_event("charge", action, 0, "enemy"))
	return {"ok": true, "message": "一战实验开始"}

func tick(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if phase != "battle" or paused or not is_finite(delta) or delta <= 0.0:
		return events
	# A battle has at most 1800 steps. Even a suspended-window frame is bounded,
	# while every relevant step is retained (rather than silently dropping damage).
	_accumulator += minf(delta, TIME_LIMIT)
	events.append_array(_initial_events)
	_initial_events.clear()
	while _accumulator + 0.000000001 >= STEP and phase == "battle":
		_accumulator = maxf(0.0, _accumulator - STEP)
		_step_index += 1
		battle_time = snappedf(float(_step_index) * STEP, 0.000001)
		_step(events)
	if phase != "battle":
		_accumulator = 0.0
	return events

func get_summary() -> Dictionary:
	var sources: Array[Dictionary] = []
	for uid: int in _source_order:
		sources.append(_by_source[uid].duplicate(true))
	var result: Dictionary = _stats.duplicate(true)
	result.merge({"result": _result, "duration": battle_time,
		"class_id": _config.get("class_id", ""), "rules_version": 1,
		"initial_hp": _config.get("hp", 0), "hp": hp, "max_hp": max_hp,
		"enemy_hp": enemy_hp, "enemy_max_hp": enemy_max_hp,
		"by_source": sources, "event_count": _event_id}, true)
	return result

func get_presentation_timing() -> Dictionary:
	# Read-only UI query. It never schedules or resolves an attack.
	var sources: Dictionary = {}
	for action: Dictionary in _actions:
		var initial: bool = int(_by_source[int(action.uid)].activations) == 0
		var period: int = int(action.warmup_steps) if initial and int(action.warmup_steps) > 0 else int(action.interval_steps)
		var remaining := maxf(0, float(int(action.next_step) - _step_index) * STEP)
		sources[int(action.uid)] = {"remaining": remaining, "progress": clampf(1.0 - remaining / (maxi(1, period) * STEP), 0, 1), "charging": bool(action.charged)}
	return {"sources": sources, "enemy_remaining": maxf(0, float(_enemy_next_step - _step_index) * STEP), "substep": _accumulator}

func _step(events: Array[Dictionary]) -> void:
	for action: Dictionary in _actions:
		if action["warmup_steps"] > 0 and not action["charged"] and _step_index >= action["charge_step"]:
			action["charged"] = true
			events.append(_event("charge", action, 0, "enemy"))
		if _step_index < action["next_step"]:
			continue
		var source: Dictionary = _by_source[action["uid"]]
		source["activations"] += 1
		for hit in range(1, int(action["hits"]) + 1):
			var raw: int = action["damage"]
			var effective := mini(enemy_hp, raw)
			enemy_hp -= effective
			_stats["damage_dealt"] += effective
			_stats["raw_damage_dealt"] += raw
			_stats["overkill_damage_dealt"] += raw - effective
			source["damage"] += effective
			source["raw_damage"] += raw
			source["hits"] += 1
			var event := _event(action["event_type"], action, effective, "enemy")
			event["raw_amount"] = raw
			event["hit_index"] = hit
			events.append(event)
			if enemy_hp <= 0:
				_finish("won", events)
				return
		action["next_step"] += action["interval_steps"]
		action["charge_step"] = action["next_step"] - action["warmup_steps"]
		action["charged"] = false
		if action["warmup_steps"] > 0 and action["charge_step"] <= _step_index:
			action["charged"] = true
			events.append(_event("charge", action, 0, "enemy"))
	if _step_index >= _enemy_next_step:
		_enemy_next_step += ENEMY_INTERVAL_STEPS
		var mitigated := mini(_armor, ENEMY_ATTACK - 1)
		var after_armor := ENEMY_ATTACK - mitigated
		var effective := mini(hp, after_armor)
		hp -= effective
		_stats["raw_damage_taken"] += ENEMY_ATTACK
		_stats["damage_taken"] += effective
		_stats["armor_mitigated"] += mitigated
		_stats["overkill_damage_taken"] += after_armor - effective
		_stats["enemy_attacks"] += 1
		var event := _event("enemy_attack", {}, effective, "hero")
		event["raw_amount"] = ENEMY_ATTACK
		event["armor_mitigated"] = mitigated
		events.append(event)
		if hp <= 0:
			_finish("lost", events)
			return
	if _step_index >= MAX_STEPS:
		_finish("timeout", events)

func _finish(result: String, events: Array[Dictionary]) -> void:
	if phase != "battle":
		return
	_result = result
	phase = "won" if result == "won" else "lost"
	battle_duration = battle_time
	var event := _event("battle_end", {}, 0, "enemy" if result == "won" else "hero")
	event["result"] = result
	events.append(event)

func _event(type: String, source: Dictionary, amount: int, target: String) -> Dictionary:
	_event_id += 1
	return {"event_id": _event_id, "time": battle_time, "type": type,
		"source_uid": source.get("uid", 0),
		"source_kind": source.get("kind", "enemy" if type == "enemy_attack" else "battle"),
		"source_name": source.get("name", enemy_name if type == "enemy_attack" else "战斗规则"),
		"amount": amount, "target": target}

func _steps(seconds: float) -> int:
	return int(ceil(seconds / STEP - 0.000000001))

func _integer_in(value: Variant, low: int, high: int) -> bool:
	return typeof(value) == TYPE_INT and value >= low and value <= high

func _number_in(value: Variant, low: float, high: float) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and value >= low and value <= high

func _text(value: Variant, limit: int) -> bool:
	return typeof(value) == TYPE_STRING and not value.strip_edges().is_empty() and value.length() <= limit

func _validate(config: Dictionary) -> String:
	if typeof(config.get("class_id")) != TYPE_STRING or config.get("class_id") not in ["mage", "knight"]:
		return "未知职业"
	if not _integer_in(config.get("rules_version"), 1, 1):
		return "不支持的职业规则版本"
	if not _integer_in(config.get("max_hp"), 1, 10000) or not _integer_in(config.get("hp"), 1, 10000):
		return "生命数据无效"
	if config["hp"] > config["max_hp"] or not _integer_in(config.get("armor"), 0, 100):
		return "生命或护甲超出范围"
	if not config.get("actions") is Array or config["actions"].is_empty() or config["actions"].size() > 24:
		return "至少需要一个合法攻击来源，最多二十四个"
	var seen: Dictionary = {}
	for action: Variant in config["actions"]:
		if not action is Dictionary:
			return "攻击来源格式无效"
		if not _integer_in(action.get("uid"), 1, 1000000000) or seen.has(action.get("uid")):
			return "攻击来源标识无效或重复"
		seen[action["uid"]] = true
		if not _text(action.get("kind"), 128) or not _text(action.get("name"), 128) or not _text(action.get("event_type"), 64):
			return "攻击来源名称或事件类型无效"
		if not _integer_in(action.get("damage"), 1, 10000) or not _integer_in(action.get("hits"), 1, 16):
			return "攻击伤害或段数超出范围"
		if not _number_in(action.get("interval"), STEP, TIME_LIMIT) or not _number_in(action.get("warmup"), 0.0, TIME_LIMIT):
			return "攻击时间无效"
		if action["warmup"] > action["interval"]:
			return "蓄势时长不能超过攻击间隔"
	return ""
