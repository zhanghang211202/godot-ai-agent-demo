class_name EmberRun
extends RefCounted
## Pure, deterministic game rules. UI code owns drawing, input, and audio.

const GRID_SIZE := Vector2i(6, 4)
const MAX_LEVEL := 3
const DEFINITIONS := {
	"sword": {"name": "旅人短剑", "size": Vector2i(1, 2), "cost": 4, "description": "每 1.25 秒攻击。相同装备可合成；短剑 + 磨刀石 = 长剑。", "category": "weapon", "color": "a7c5d5"},
	"longsword": {"name": "淬锋长剑", "size": Vector2i(1, 3), "cost": 8, "description": "占据三格，每 1.35 秒重击。长剑 + 火种 = 焰纹大剑。", "category": "weapon", "color": "eed898"},
	"flame_sword": {"name": "焰纹大剑", "size": Vector2i(1, 3), "cost": 12, "description": "每 1.4 秒斩击，造成强力火焰伤害。", "category": "weapon", "color": "ef9c65"},
	"thorn_shield": {"name": "荆棘木盾", "size": Vector2i(2, 2), "cost": 9, "description": "提供护甲，受到攻击后向敌人反弹伤害。", "category": "armor", "color": "91b77c"},
	"windbow": {"name": "逐风猎弓", "size": Vector2i(3, 1), "cost": 9, "description": "占据三格，每 0.9 秒射击，增加 8% 暴击。", "category": "weapon", "color": "9acdbb"},
	"greater_potion": {"name": "浓缩暖心药", "size": Vector2i(1, 2), "cost": 8, "description": "每战一次：生命低于 50% 时大量恢复生命。", "category": "healing", "color": "dea3d2"},
	"shield": {"name": "橡木圆盾", "size": Vector2i(2, 2), "cost": 6, "description": "护甲减少每次受到的伤害，至少承受 1 点。", "category": "armor", "color": "c99662"},
	"bow": {"name": "林地猎弓", "size": Vector2i(2, 1), "cost": 5, "description": "每 1.05 秒射击，并增加 5% 暴击率。", "category": "weapon", "color": "cba87b"},
	"herb": {"name": "月露草", "size": Vector2i(1, 1), "cost": 3, "description": "战斗中每 2 秒恢复生命；升级提升恢复量。", "category": "healing", "color": "8cc89b"},
	"potion": {"name": "暖心药水", "size": Vector2i(1, 1), "cost": 5, "description": "每场战斗一次：生命低于 50% 时自动治疗。", "category": "healing", "color": "e0a4b6"},
	"whetstone": {"name": "银纹磨刀石", "size": Vector2i(1, 1), "cost": 4, "description": "强化左右蓝点上的武器；旋转后强化上下。与短剑合成长剑。", "category": "support", "color": "b1abc7"},
	"ember": {"name": "不熄火种", "size": Vector2i(1, 1), "cost": 4, "description": "增加暴击率，相邻武器获得额外攻击力。", "category": "support", "color": "efad68"},
}
const RECIPES: Array[Dictionary] = [
	{"first": "sword", "second": "whetstone", "result": "longsword", "label": "淬锋锻造"},
	{"first": "longsword", "second": "ember", "result": "flame_sword", "label": "焰纹锻造"},
	{"first": "shield", "second": "herb", "result": "thorn_shield", "label": "荆棘编织"},
	{"first": "bow", "second": "ember", "result": "windbow", "label": "逐风附魔"},
	{"first": "potion", "second": "herb", "result": "greater_potion", "label": "暖心浓缩"},
]
const BLESSINGS := {
	"vitality": {"name": "旅人的韧性", "description": "最大生命 +18，并恢复 18 点生命。", "icon": "vitality", "max_hp": 18, "heal": 18},
	"coin_pouch": {"name": "路边的宝藏", "description": "立即获得 8 金币，下一次补给更从容。", "icon": "fortune", "gold": 8},
	"keen_edge": {"name": "破甲之锋", "description": "每件武器攻击 +2，护甲 -1。", "icon": "fury", "attack_bonus": 2, "armor_bonus": -1},
	"ironbark": {"name": "古树庇佑", "description": "护甲 +2，暴击率 -3%。", "icon": "bastion", "armor_bonus": 2, "crit_bonus": -0.03},
	"moonwater": {"name": "月露低语", "description": "战斗中每 2 秒额外恢复 2 点生命。", "icon": "renewal", "regen_bonus": 2},
	"focus": {"name": "孤注一掷", "description": "暴击率 +12%，每 2 秒恢复量 -1。", "icon": "precision", "crit_bonus": 0.12, "regen_bonus": -1},
	"campfire": {"name": "温暖营火", "description": "立即恢复 28 点生命；每 2 秒恢复量 +1。", "icon": "potion", "heal": 28, "regen_bonus": 1},
}
const ENEMIES := [
	{"name": "苔团", "hp": 72, "attack": 8, "interval": 1.8, "trait": "行动缓慢，适合试验装备与蓝点布局。"},
	{"name": "暮林狼", "hp": 112, "attack": 11, "interval": 1.7, "trait": "攻击更频繁，盾牌能减轻每次伤害。"},
	{"name": "苔刃哥布林", "hp": 166, "attack": 15, "interval": 1.7, "trait": "生命与攻击提高，合成装备能加快战斗。"},
	{"name": "遗迹树卫", "hp": 238, "attack": 19, "interval": 1.6, "trait": "耐久强敌，护甲与持续恢复尤其有用。"},
	{"name": "灰烬树王", "hp": 350, "attack": 24, "interval": 1.5, "trait": "最终首领，用高阶装备和祝福挑战它。"},
]
const SHOP_POOL := ["sword", "shield", "bow", "herb", "potion", "whetstone", "ember"]
const SIMULATION_STEP := 0.05

var items: Array[Dictionary] = []
var shop_offers: Array[String] = []
var phase: String = "prepare"
var gold: int = 18
var wave: int = 1
var hp: int = 100
var max_hp: int = 100
var enemy_hp: int = 72
var enemy_max_hp: int = 72
var enemy_name: String = "苔团"
var battle_time: float = 0.0
var battle_duration: float = 0.0
var last_reward: int = 0
var reroll_cost: int = 2
var reward_choices: Array[String] = []
var blessings: Array[String] = []
var reward_chosen: bool = false

var _rng := RandomNumberGenerator.new()
var _next_uid: int = 1
var _weapon_timers: Dictionary = {}
var _potion_used: Dictionary = {}
var _enemy_timer: float = 1.8
var _regen_timer: float = 2.0
var _accumulator: float = 0.0
var _battle_stats: Dictionary = {}

func _init() -> void:
	new_run()

func new_run(seed_value: int = 12345) -> void:
	_rng.seed = seed_value
	phase = "prepare"
	gold = 18
	wave = 1
	hp = 100
	max_hp = 100
	_next_uid = 1
	items.clear()
	reward_choices.clear()
	blessings.clear()
	reward_chosen = false
	_add_item("sword", Vector2i(0, 0))
	_add_item("sword", Vector2i(1, 0))
	var starting_stone: Dictionary = _add_item("whetstone", Vector2i(0, 2))
	starting_stone["rotated"] = true
	shop_offers.assign(["shield", "herb", "bow", "ember"])
	battle_time = 0.0
	battle_duration = 0.0
	last_reward = 0
	_accumulator = 0.0
	_weapon_timers.clear()
	_potion_used.clear()
	_set_enemy()

func get_definition(kind: String) -> Dictionary:
	return DEFINITIONS.get(kind, {}).duplicate(true)

func get_blessing_definition(id: String) -> Dictionary:
	return BLESSINGS.get(id, {}).duplicate(true)

func get_enemy_info() -> Dictionary:
	var info: Dictionary = ENEMIES[clampi(wave - 1, 0, ENEMIES.size() - 1)].duplicate(true)
	info["wave"] = wave
	info["is_boss"] = wave == ENEMIES.size()
	return info

func get_item_size(item: Dictionary) -> Vector2i:
	var size: Vector2i = DEFINITIONS.get(item.get("kind", ""), {}).get("size", Vector2i.ONE)
	return Vector2i(size.y, size.x) if item.get("rotated", false) else size

func item_at(cell: Vector2i) -> Dictionary:
	for item in items:
		if Rect2i(item["pos"], get_item_size(item)).has_point(cell):
			return item
	return {}

func item_by_uid(uid: int) -> Dictionary:
	for item in items:
		if item["uid"] == uid:
			return item
	return {}

func can_place(item: Dictionary, cell: Vector2i, ignore_uid: int = -1) -> bool:
	return _fits(item, cell, [ignore_uid])

func buy(offer_index: int, cell: Vector2i, rotated: bool = false) -> Dictionary:
	if phase != "prepare":
		return _result(false, "战斗结束后才能整理行囊。")
	if offer_index < 0 or offer_index >= shop_offers.size() or shop_offers[offer_index].is_empty():
		return _result(false, "这件货品已售出。")
	var kind: String = shop_offers[offer_index]
	var cost: int = DEFINITIONS[kind]["cost"]
	if gold < cost:
		return _result(false, "金币不足。")
	var candidate := {"uid": _next_uid, "kind": kind, "level": 1, "pos": cell, "rotated": rotated}
	var target: Dictionary = item_at(cell)
	var merge_result: Dictionary = {}
	if not target.is_empty() and not get_merge_result(candidate, target).is_empty():
		merge_result = _merge(candidate, target)
		if not merge_result["ok"]:
			return merge_result
	elif not can_place(candidate, cell):
		return _result(false, "这里放不下，试试旋转或腾出空格。")
	else:
		items.append(candidate)
	gold -= cost
	_next_uid += 1
	shop_offers[offer_index] = ""
	if not merge_result.is_empty():
		return merge_result
	return _result(true, "购入了" + str(DEFINITIONS[kind]["name"]) + "。", "buy")

func move(uid: int, cell: Vector2i, rotated: bool = false) -> Dictionary:
	if phase != "prepare":
		return _result(false, "战斗结束后才能整理行囊。")
	var item: Dictionary = item_by_uid(uid)
	if item.is_empty():
		return _result(false, "找不到这件物品。")
	var candidate: Dictionary = item.duplicate()
	candidate["rotated"] = rotated
	var target: Dictionary = item_at(cell)
	if not target.is_empty() and target["uid"] != uid and not get_merge_result(item, target).is_empty():
		return _merge(candidate, target)
	if not can_place(candidate, cell, uid):
		return _result(false, "这里放不下，试试旋转或腾出空格。")
	item["pos"] = cell
	item["rotated"] = rotated
	return _result(true, "已整理行囊。", "move")

func sell(uid: int) -> Dictionary:
	if phase != "prepare":
		return _result(false, "战斗结束后才能出售。")
	var item: Dictionary = item_by_uid(uid)
	if item.is_empty():
		return _result(false, "找不到这件物品。")
	var refund: int = get_sell_price(item)
	items.erase(item)
	gold += refund
	return _result(true, "出售获得 %d 金币。" % refund, "sell")

func get_sell_price(item: Dictionary) -> int:
	return maxi(1, int(DEFINITIONS[item["kind"]]["cost"]) * (1 << (int(item["level"]) - 1)) / 2)

func reroll() -> Dictionary:
	if phase != "prepare":
		return _result(false, "战斗结束后商人才会补货。")
	if gold < reroll_cost:
		return _result(false, "刷新需要 %d 金币。" % reroll_cost)
	gold -= reroll_cost
	_roll_shop()
	return _result(true, "商人补上了新货。", "reroll")

func get_merge_result(source: Dictionary, target: Dictionary) -> String:
	if source.get("uid", -1) == target.get("uid", -2):
		return ""
	var source_kind: String = source.get("kind", "")
	var target_kind: String = target.get("kind", "")
	if source_kind == target_kind and source.get("level", 1) == target.get("level", 1) and int(target.get("level", 1)) < MAX_LEVEL:
		return source_kind
	for recipe in RECIPES:
		if (source_kind == recipe["first"] and target_kind == recipe["second"]) or (source_kind == recipe["second"] and target_kind == recipe["first"]):
			return recipe["result"]
	return ""

func can_merge(source: Dictionary, target: Dictionary) -> bool:
	var merged: Dictionary = _get_merged_item(source, target)
	return not merged.is_empty() and _fits(merged, merged["pos"], [source.get("uid", -1), target.get("uid", -2)])

func get_merge_preview(source: Dictionary, target: Dictionary) -> Dictionary:
	return _get_merged_item(source, target).duplicate(true)

func get_support_cells(item: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var directions: Array[Vector2i] = []
	if item.get("kind", "") == "whetstone":
		directions.assign([Vector2i.UP, Vector2i.DOWN] if item.get("rotated", false) else [Vector2i.LEFT, Vector2i.RIGHT])
	elif item.get("kind", "") == "ember":
		directions.assign([Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT])
	var origin: Vector2i = item.get("pos", Vector2i.ZERO)
	for direction in directions:
		var cell: Vector2i = origin + direction
		if Rect2i(Vector2i.ZERO, GRID_SIZE).has_point(cell):
			result.append(cell)
	return result

func get_adjacency_bonus(item: Dictionary) -> int:
	if DEFINITIONS[item["kind"]]["category"] != "weapon":
		return 0
	var bonus: int = 0
	for support in items:
		var affected: bool = false
		var weapon_rect := Rect2i(item["pos"], get_item_size(item))
		for cell in get_support_cells(support):
			if weapon_rect.has_point(cell):
				affected = true
				break
		if not affected:
			continue
		var level_index: int = int(support["level"]) - 1
		if support["kind"] == "whetstone":
			bonus += [3, 6, 10][level_index]
		elif support["kind"] == "ember":
			bonus += [2, 4, 7][level_index]
	return bonus

func get_weapon_damage(item: Dictionary) -> int:
	if DEFINITIONS.get(item.get("kind", ""), {}).get("category", "") != "weapon":
		return 0
	var values: Array = {"sword": [5, 12, 27], "longsword": [12, 27, 56], "flame_sword": [17, 36, 72], "bow": [4, 10, 23], "windbow": [7, 17, 37]}.get(item["kind"], [0, 0, 0])
	return maxi(1, int(values[int(item["level"]) - 1]) + get_adjacency_bonus(item) + int(_blessing_total("attack_bonus")))

func get_weapon_cooldown_progress(uid: int) -> float:
	var item: Dictionary = item_by_uid(uid)
	if item.is_empty() or not _weapon_timers.has(uid):
		return 0.0
	if phase != "battle":
		return 1.0
	return clampf(1.0 - float(_weapon_timers[uid]) / _weapon_interval(item["kind"]), 0.0, 1.0)

func get_stats() -> Dictionary:
	var result := {"attack": 0, "armor": int(_blessing_total("armor_bonus")), "regen": int(_blessing_total("regen_bonus")), "crit": 0.05 + _blessing_total("crit_bonus"), "synergy_count": 0, "dps": 0.0, "thorns": 0}
	for item in items:
		var kind: String = item["kind"]
		var level_index: int = int(item["level"]) - 1
		if DEFINITIONS[kind]["category"] == "weapon":
			var damage: int = get_weapon_damage(item)
			result["attack"] += damage
			result["dps"] += float(damage) / _weapon_interval(kind)
			if get_adjacency_bonus(item) > 0:
				result["synergy_count"] += 1
		if kind == "shield":
			result["armor"] += [4, 8, 14][level_index]
		elif kind == "thorn_shield":
			result["armor"] += [5, 10, 17][level_index]
			result["thorns"] += [3, 7, 14][level_index]
		elif kind == "herb":
			result["regen"] += [2, 5, 11][level_index]
		elif kind == "ember":
			result["crit"] += [0.08, 0.14, 0.22][level_index]
		elif kind == "bow":
			result["crit"] += 0.05
		elif kind == "windbow":
			result["crit"] += 0.08
	result["armor"] = maxi(0, int(result["armor"]))
	result["regen"] = maxi(0, int(result["regen"]))
	result["crit"] = clampf(float(result["crit"]), 0.0, 0.65)
	result["reflect"] = result["thorns"]
	return result

func start_battle() -> Dictionary:
	if phase != "prepare":
		return _result(false, "当前无法出发。")
	if int(get_stats()["attack"]) == 0:
		return _result(false, "至少带上一件武器再出发。")
	phase = "battle"
	battle_time = 0.0
	battle_duration = 0.0
	_accumulator = 0.0
	_battle_stats = get_stats()
	_weapon_timers.clear()
	_potion_used.clear()
	var weapon_index: int = 0
	for item in items:
		if DEFINITIONS[item["kind"]]["category"] == "weapon":
			_weapon_timers[item["uid"]] = 0.35 + float(weapon_index) * 0.18
			weapon_index += 1
	_enemy_timer = 1.2
	_regen_timer = 2.0
	_set_enemy()
	return _result(true, "遭遇了" + enemy_name + "！", "battle")

func tick(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if phase != "battle" or delta <= 0.0:
		return events
	_accumulator += delta
	while _accumulator + 0.000001 >= SIMULATION_STEP and phase == "battle":
		_accumulator -= SIMULATION_STEP
		_step_battle(SIMULATION_STEP, events)
	return events

func claim_reward() -> Dictionary:
	if phase != "reward":
		return _result(false, "还没有可领取的战利品。")
	if not reward_chosen:
		return _result(false, "先选择一项旅途祝福，再继续出发。")
	wave += 1
	phase = "prepare"
	reward_choices.clear()
	reward_chosen = false
	_roll_shop()
	_set_enemy()
	return _result(true, "前方是第 %d 场遭遇。" % wave, "prepare")

func choose_reward(index: int) -> Dictionary:
	if phase != "reward" or reward_chosen:
		return _result(false, "当前没有可选择的旅途祝福。")
	if index < 0 or index >= reward_choices.size():
		return _result(false, "请选择一项旅途祝福。")
	var id: String = reward_choices[index]
	if not BLESSINGS.has(id) or id in blessings:
		return _result(false, "这项旅途祝福已领取。")
	var blessing: Dictionary = BLESSINGS[id]
	blessings.append(id)
	max_hp += int(blessing.get("max_hp", 0))
	hp = mini(max_hp, hp + int(blessing.get("heal", 0)))
	gold += int(blessing.get("gold", 0))
	reward_choices.clear()
	reward_chosen = true
	return _result(true, "获得祝福：" + str(blessing["name"]) + "。", "blessing")

func _add_item(kind: String, pos: Vector2i, level: int = 1) -> Dictionary:
	var item := {"uid": _next_uid, "kind": kind, "level": level, "pos": pos, "rotated": false}
	_next_uid += 1
	items.append(item)
	return item

func _fits(item: Dictionary, cell: Vector2i, ignore_uids: Array) -> bool:
	var size: Vector2i = get_item_size(item)
	if cell.x < 0 or cell.y < 0 or cell.x + size.x > GRID_SIZE.x or cell.y + size.y > GRID_SIZE.y:
		return false
	var rect := Rect2i(cell, size)
	for other in items:
		if other["uid"] in ignore_uids:
			continue
		if rect.intersects(Rect2i(other["pos"], get_item_size(other))):
			return false
	return true

func _merge(source: Dictionary, target: Dictionary) -> Dictionary:
	var merged: Dictionary = _get_merged_item(source, target)
	if merged.is_empty():
		return _result(false, "同类同级物品才可升级。")
	if not _fits(merged, merged["pos"], [source["uid"], target["uid"]]):
		return _result(false, "合成后的装备放不下，先腾出空间或旋转材料。")
	var owned_source: Dictionary = item_by_uid(source["uid"])
	if not owned_source.is_empty():
		items.erase(owned_source)
	target.assign(merged)
	return _result(true, "合成成功：%s · %d 阶！" % [DEFINITIONS[merged["kind"]]["name"], merged["level"]], "merge")

func _get_merged_item(source: Dictionary, target: Dictionary) -> Dictionary:
	var result_kind: String = get_merge_result(source, target)
	if result_kind.is_empty():
		return {}
	var merged: Dictionary = target.duplicate()
	merged["kind"] = result_kind
	merged["level"] = int(target["level"]) + 1 if source["kind"] == target["kind"] else maxi(int(source["level"]), int(target["level"]))
	for recipe in RECIPES:
		if recipe["result"] == result_kind and source["kind"] == recipe["first"]:
			merged["rotated"] = source.get("rotated", false)
			break
	return merged

func _adjacent(a: Dictionary, b: Dictionary) -> bool:
	var ar := Rect2i(a["pos"], get_item_size(a))
	var br := Rect2i(b["pos"], get_item_size(b))
	var vertical_overlap: bool = ar.position.y < br.end.y and ar.end.y > br.position.y
	var horizontal_overlap: bool = ar.position.x < br.end.x and ar.end.x > br.position.x
	return ((ar.end.x == br.position.x or br.end.x == ar.position.x) and vertical_overlap) or ((ar.end.y == br.position.y or br.end.y == ar.position.y) and horizontal_overlap)

func _weapon_interval(kind: String) -> float:
	return {"sword": 1.25, "longsword": 1.35, "flame_sword": 1.4, "bow": 1.05, "windbow": 0.9}.get(kind, 1.25)

func _blessing_total(key: String) -> float:
	var total: float = 0.0
	for id in blessings:
		total += float(BLESSINGS.get(id, {}).get(key, 0.0))
	return total

func _roll_rewards() -> void:
	reward_choices.clear()
	reward_chosen = false
	var available: Array[String] = []
	for id in BLESSINGS:
		if id not in blessings:
			available.append(id)
	for index in range(mini(3, available.size())):
		var selected: int = _rng.randi_range(0, available.size() - 1)
		reward_choices.append(available[selected])
		available.remove_at(selected)

func _roll_shop() -> void:
	shop_offers.clear()
	for index in range(4):
		shop_offers.append(SHOP_POOL[_rng.randi_range(0, SHOP_POOL.size() - 1)])

func _set_enemy() -> void:
	var enemy: Dictionary = ENEMIES[clampi(wave - 1, 0, ENEMIES.size() - 1)]
	enemy_name = enemy["name"]
	enemy_max_hp = enemy["hp"]
	enemy_hp = enemy_max_hp

func _step_battle(step: float, events: Array[Dictionary]) -> void:
	battle_time += step
	battle_duration = battle_time
	for item in items:
		var uid: int = item["uid"]
		if not _weapon_timers.has(uid):
			continue
		_weapon_timers[uid] -= step
		if float(_weapon_timers[uid]) > 0.0:
			continue
		_weapon_timers[uid] += _weapon_interval(item["kind"])
		var critical: bool = _rng.randf() < float(_battle_stats["crit"])
		var damage: int = get_weapon_damage(item) * (2 if critical else 1)
		enemy_hp = maxi(0, enemy_hp - damage)
		events.append({"type": "hero_attack", "uid": uid, "source_uid": uid, "amount": damage, "critical": critical, "target": "enemy"})
		if enemy_hp == 0:
			_finish_victory(events)
			return
	_enemy_timer -= step
	if _enemy_timer <= 0.0:
		var enemy: Dictionary = ENEMIES[wave - 1]
		_enemy_timer += float(enemy["interval"])
		var damage: int = maxi(1, int(enemy["attack"]) - int(_battle_stats["armor"]))
		hp = maxi(0, hp - damage)
		events.append({"type": "enemy_attack", "uid": -1, "amount": damage, "target": "hero"})
		if hp == 0:
			phase = "lost"
			events.append({"type": "defeat", "uid": -1, "amount": 0})
			return
		var reflected: int = int(_battle_stats.get("reflect", 0))
		if reflected > 0:
			enemy_hp = maxi(0, enemy_hp - reflected)
			var shield_uid: int = -1
			for shield in items:
				if shield["kind"] == "thorn_shield":
					shield_uid = shield["uid"]
					break
			events.append({"type": "reflect", "uid": shield_uid, "source_uid": shield_uid, "amount": reflected, "critical": false, "reflected": true, "target": "enemy"})
			if enemy_hp == 0:
				_finish_victory(events)
				return
	_regen_timer -= step
	if _regen_timer <= 0.0:
		_regen_timer += 2.0
		_heal(int(_battle_stats["regen"]), -1, events)
	if hp <= max_hp / 2:
		for item in items:
			if hp > max_hp / 2:
				break
			if item["kind"] in ["potion", "greater_potion"] and not _potion_used.has(item["uid"]):
				_potion_used[item["uid"]] = true
				var healing: Array = [42, 78, 130] if item["kind"] == "greater_potion" else [22, 44, 80]
				_heal(healing[int(item["level"]) - 1], item["uid"], events)
	if battle_time >= 90.0:
		phase = "lost"
		hp = 0
		events.append({"type": "defeat", "uid": -1, "amount": 0, "reason": "timeout"})

func _heal(amount: int, uid: int, events: Array[Dictionary]) -> void:
	var healed: int = mini(amount, max_hp - hp)
	if healed <= 0:
		return
	hp += healed
	events.append({"type": "heal", "uid": uid, "amount": healed, "target": "hero"})

func _finish_victory(events: Array[Dictionary]) -> void:
	last_reward = 7 + wave * 2
	gold += last_reward
	hp = mini(max_hp, hp + 18)
	phase = "won" if wave == 5 else "reward"
	if phase == "reward":
		_roll_rewards()
	else:
		reward_choices.clear()
		reward_chosen = false
	events.append({"type": "victory", "uid": -1, "amount": last_reward, "gold": last_reward, "final": wave == 5})

func _result(ok: bool, message: String, event: String = "") -> Dictionary:
	return {"ok": ok, "message": message, "event": event}
