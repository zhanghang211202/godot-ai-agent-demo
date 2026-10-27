extends RefCounted
## C0 fixed-resource rules prototype. It intentionally does not extend the legacy item pool.

const GRID_SIZE: Vector2i = Vector2i(6, 4)
const RULES_VERSION: int = 1
const CLASS_IDS: Array[String] = ["mage", "knight"]

static func class_info(id: String) -> Dictionary:
	match id:
		"mage":
			return {"name": "元素编织师", "subtitle": "有限元素 · 战前编织 · 自动施法", "carrier": "法术编织盘", "background": "月光观测庭", "accent": "b5a0eb"}
		"knight":
			return {"name": "圣堂骑士", "subtitle": "有限武装 · 整备锻造 · 蓄势重击", "carrier": "遗物整备盘", "background": "余烬圣堂", "accent": "e3bd73"}
	return {}

static func create_info(id: String) -> Dictionary:
	match id:
		"mage": return {"gold": 0, "max_hp": 84}
		"knight": return {"gold": 12, "max_hp": 96}
	return {}

static func definition(kind: String) -> Dictionary:
	var result: Dictionary = {}
	match kind:
		"spark":
			result = {"name": "微光术式", "class_id": "mage", "size": Vector2i(1, 2), "color": "c9b3fa", "category": "attack", "description": "基础自动术式。与火元素编织成占地更大的焰爆法印。", "damage": 5, "hits": 1, "interval": 1.5, "warmup": 0.4, "event_type": "spell"}
		"fire_mote":
			result = {"name": "火元素", "class_id": "mage", "size": Vector2i.ONE, "color": "f29165", "category": "material", "description": "有限元素。与微光编织焰爆、与水编织蒸汽、与风编织焰风涡旋。"}
		"water_mote":
			result = {"name": "水元素", "class_id": "mage", "size": Vector2i.ONE, "color": "78c8e4", "category": "material", "description": "与微光编织冰矢、与风编织潮汐、与火编织蒸汽。原料也占格。"}
		"wind_mote":
			result = {"name": "风元素", "class_id": "mage", "size": Vector2i.ONE, "color": "94d7b3", "category": "material", "description": "与微光编织双风刃、与水编织潮汐、与火编织焰风涡旋。每局来源有限。"}
		"frost_bolt":
			result = {"name": "霜晶冰矢", "class_id": "mage", "size": Vector2i(1, 2), "color": "9cdef7", "category": "attack", "description": "水与微光编织的晶质冰矢。紧凑单击，首次0.5秒，每1.8秒释放。", "damage": 9, "hits": 1, "interval": 1.8, "warmup": 0.5, "event_type": "spell", "materials": {"spark": 1, "water_mote": 1}}
		"gale_blades":
			result = {"name": "回旋风刃", "class_id": "mage", "size": Vector2i(2, 1), "color": "a0e7ba", "category": "attack", "description": "风与微光编织的双刃。每1.4秒两段命中，各4伤害；晶核支援逐段生效。", "damage": 4, "hits": 2, "interval": 1.4, "warmup": 0.3, "event_type": "spell_multi", "materials": {"spark": 1, "wind_mote": 1}}
		"steam_burst":
			result = {"name": "蒸汽爆破", "class_id": "mage", "size": Vector2i(2, 2), "color": "e5c4a0", "category": "attack", "description": "火与水直接编织的高压法印。首次1.9秒，之后每3.4秒集中爆发22伤害。", "damage": 22, "hits": 1, "interval": 3.4, "warmup": 1.9, "event_type": "spell_burst", "materials": {"fire_mote": 1, "water_mote": 1}}
		"ember_tornado":
			result = {"name": "焰风涡旋", "class_id": "mage", "size": Vector2i(2, 3), "color": "f1a875", "category": "attack", "description": "火与风编织的大型术式。占六格，每2.8秒四段命中，各6伤害；需要为聚能连接预留空间。", "damage": 6, "hits": 4, "interval": 2.8, "warmup": 1.2, "event_type": "spell_multi", "materials": {"fire_mote": 1, "wind_mote": 1}}
		"flame_glyph":
			result = {"name": "焰爆法印", "class_id": "mage", "size": Vector2i(2, 2), "color": "ef936b", "category": "attack", "description": "单次集中爆发。每3秒释放，首次准备1.6秒，占用四格。", "damage": 18, "hits": 1, "interval": 3.0, "warmup": 1.6, "event_type": "spell_burst", "materials": {"spark": 1, "fire_mote": 1}}
		"tide_lances":
			result = {"name": "潮汐连枪", "class_id": "mage", "size": Vector2i(3, 1), "color": "6ac7dc", "category": "attack", "description": "每次施法产生三段命中。更宽的占格需要预留落点。", "damage": 5, "hits": 3, "interval": 2.6, "warmup": 0.8, "event_type": "spell_multi", "materials": {"water_mote": 1, "wind_mote": 1}}
		"arcane_focus":
			result = {"name": "聚能晶核", "class_id": "mage", "size": Vector2i.ONE, "color": "b79fe8", "category": "support", "description": "左右边缘连接到的术式每段伤害+2；旋转后改为上下连接。", "support_bonus": 2}
		"mage_ward":
			result = {"name": "护身符板", "class_id": "mage", "size": Vector2i(2, 1), "color": "91a6dd", "category": "armor", "description": "受击时展开月纹法盾，每段抵挡2伤害。保留在编织盘上即可持续保护。", "armor": 2}
		"iron_blade":
			result = {"name": "制式长剑", "class_id": "knight", "size": Vector2i(1, 3), "color": "c6ccd2", "category": "attack", "description": "稳定基础攻击。与蓄势徽记锻造为更宽的誓约重刃。", "damage": 9, "hits": 1, "interval": 1.4, "warmup": 0.35, "event_type": "attack"}
		"greatblade":
			result = {"name": "誓约重刃", "class_id": "knight", "size": Vector2i(2, 3), "color": "e5bd73", "category": "attack", "description": "蓄势后释放重击，之后每3.2秒攻击。六格占地会挤压支援与护甲。", "damage": 32, "hits": 1, "interval": 3.2, "warmup": 1.4, "event_type": "heavy_charge", "materials": {"iron_blade": 1, "charge_seal": 1}}
		"charge_seal":
			result = {"name": "蓄势徽记", "class_id": "knight", "size": Vector2i.ONE, "color": "d79c67", "category": "support", "description": "与长剑锻造重刃；保留时使左右连接武器伤害+4，旋转改为上下。", "support_bonus": 4}
		"knight_ward":
			result = {"name": "圣堂甲片", "class_id": "knight", "size": Vector2i(2, 1), "color": "e5d8b6", "category": "armor", "description": "护甲+2。这是护甲，不提供尚未实现的格挡或反击。", "armor": 2}
	if not result.is_empty() and not result.has("materials"):
		result["materials"] = {kind: 1}
	return result

static func recipes_for(class_id: String) -> Array[Dictionary]:
	var recipes: Array[Dictionary] = []
	match class_id:
		"mage":
			recipes.append({"first": "fire_mote", "second": "spark", "result": "flame_glyph", "label": "火 + 微光 → 焰爆法印"})
			recipes.append({"first": "water_mote", "second": "wind_mote", "result": "tide_lances", "label": "水 + 风 → 潮汐连枪"})
			recipes.append({"first": "water_mote", "second": "spark", "result": "frost_bolt", "label": "水 + 微光 → 霜晶冰矢"})
			recipes.append({"first": "wind_mote", "second": "spark", "result": "gale_blades", "label": "风 + 微光 → 回旋风刃"})
			recipes.append({"first": "fire_mote", "second": "water_mote", "result": "steam_burst", "label": "火 + 水 → 蒸汽爆破"})
			recipes.append({"first": "fire_mote", "second": "wind_mote", "result": "ember_tornado", "label": "火 + 风 → 焰风涡旋"})
		"knight":
			recipes.append({"first": "iron_blade", "second": "charge_seal", "result": "greatblade", "label": "长剑 + 蓄势徽记 → 誓约重刃"})
	return recipes

static func initial_inventory(id: String) -> Array[Dictionary]:
	var inventory: Array[Dictionary] = []
	match id:
		"mage":
			inventory.assign([
				{"uid": 1, "kind": "spark", "pos": Vector2i(0, 0), "rotated": false},
				{"uid": 2, "kind": "spark", "pos": Vector2i(0, 2), "rotated": false},
				{"uid": 3, "kind": "arcane_focus", "pos": Vector2i(2, 1), "rotated": false},
				{"uid": 4, "kind": "mage_ward", "pos": Vector2i(4, 0), "rotated": false},
			])
		"knight":
			inventory.assign([
				{"uid": 1, "kind": "iron_blade", "pos": Vector2i(0, 0), "rotated": false},
				{"uid": 2, "kind": "knight_ward", "pos": Vector2i(4, 0), "rotated": false},
			])
	return inventory

static func initial_sources(id: String) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	match id:
		"mage":
			sources.assign([
				{"id": "observatory_fire", "kind": "fire_mote", "remaining": 2, "cost": 0},
				{"id": "observatory_water", "kind": "water_mote", "remaining": 2, "cost": 0},
				{"id": "observatory_wind", "kind": "wind_mote", "remaining": 2, "cost": 0},
			])
		"knight":
			sources.assign([
				{"id": "armory_blade", "kind": "iron_blade", "remaining": 1, "cost": 6},
				{"id": "armory_charge", "kind": "charge_seal", "remaining": 2, "cost": 4},
				{"id": "armory_ward", "kind": "knight_ward", "remaining": 1, "cost": 3},
			])
	return sources
