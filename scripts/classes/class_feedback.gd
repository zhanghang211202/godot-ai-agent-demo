extends RefCounted
## Bounded event presentation. No HP, damage, status or cooldown computation.

const HIT_TIME := 0.26
const NUMBER_TIME := 0.90
const EXIT_TIME := 0.70
const MAX_NUMBERS := 24
const HERO_ATTACKS := ["spell", "spell_burst", "spell_multi", "attack", "heavy_charge"]
var numbers: Array[Dictionary] = []
var hero_hit := 0.0
var enemy_hit := 0.0
var hero_exit := -1.0
var enemy_exit := -1.0
var outcome := ""
var _seen: Array[int] = []

func reset() -> void:
	numbers.clear()
	hero_hit = 0.0
	enemy_hit = 0.0
	hero_exit = -1.0
	enemy_exit = -1.0
	outcome = ""
	_seen.clear()

func show_event(event: Dictionary) -> void:
	var event_id := int(event.get("event_id", 0))
	if event_id > 0:
		if event_id in _seen:
			return
		_seen.append(event_id)
		if _seen.size() > 64:
			_seen.pop_front()
	var type := str(event.get("type", ""))
	if type == "battle_end":
		outcome = str(event.get("result", ""))
		if outcome == "won":
			enemy_exit = 0.0
		elif outcome == "lost":
			hero_exit = 0.0
		return
	if not outcome.is_empty():
		return
	var target := str(event.get("target", ""))
	if not ((type in HERO_ATTACKS and target == "enemy") or (type == "enemy_attack" and target == "hero")):
		return
	if target == "hero":
		hero_hit = HIT_TIME
	else:
		enemy_hit = HIT_TIME
	var key := "%s:%s:%s" % [target, str(event.get("source_uid", 0)), str(event.get("time", 0))]
	# Simultaneous multi-hit damage shares one readable number, while retaining
	# its actual hit count and the exact effective/raw values from the engine.
	for number in numbers:
		if number.key == key:
			number.amount += int(event.get("amount", 0))
			number.raw += int(event.get("raw_amount", event.get("amount", 0)))
			number.armor += int(event.get("armor_mitigated", 0))
			number.hits += 1
			return
	numbers.append({"key": key, "target": target, "amount": int(event.get("amount", 0)),
		"raw": int(event.get("raw_amount", event.get("amount", 0))), "armor": int(event.get("armor_mitigated", 0)),
		"hits": 1, "kind": str(event.get("source_kind", "")), "age": 0.0})
	if numbers.size() > MAX_NUMBERS:
		numbers.pop_front()

func advance(delta: float) -> void:
	var step := maxf(0.0, delta)
	hero_hit = maxf(0.0, hero_hit - step)
	enemy_hit = maxf(0.0, enemy_hit - step)
	if hero_exit >= 0:
		hero_exit = minf(EXIT_TIME, hero_exit + step)
	if enemy_exit >= 0:
		enemy_exit = minf(EXIT_TIME, enemy_exit + step)
	for number in numbers:
		number.age += step
	for index in range(numbers.size() - 1, -1, -1):
		if float(numbers[index].age) >= NUMBER_TIME:
			numbers.remove_at(index)

func is_active() -> bool:
	return hero_hit > 0 or enemy_hit > 0 or not numbers.is_empty() or (hero_exit >= 0 and hero_exit < EXIT_TIME) or (enemy_exit >= 0 and enemy_exit < EXIT_TIME)

func opacity(target: String) -> float:
	var elapsed := hero_exit if target == "hero" else enemy_exit
	return 1.0 if elapsed < 0 else 1.0 - clampf(elapsed / EXIT_TIME, 0, 1)

func report() -> Dictionary:
	return {"hero_hit_remaining": hero_hit, "enemy_hit_remaining": enemy_hit,
		"hero_exit_elapsed": hero_exit, "enemy_exit_elapsed": enemy_exit,
		"hero_opacity": opacity("hero"), "enemy_opacity": opacity("enemy"),
		"outcome": outcome, "numbers": numbers.duplicate(true), "active": is_active()}
