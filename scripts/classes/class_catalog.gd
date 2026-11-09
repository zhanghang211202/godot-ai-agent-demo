extends RefCounted
## C0 fixed-resource rules prototype. It intentionally does not extend the legacy item pool.

const GRID_SIZE: Vector2i = Vector2i(6, 4)
const RULES_VERSION: int = 1
const CLASS_IDS: Array[String] = ["mage", "knight"]

static func class_info(id: String) -> Dictionary:
	match id:
		"mage":
			return {"name": "元素紡ぎの魔術師", "subtitle": "有限の元素 · 戦前に紡ぐ · 自動詠唱", "carrier": "魔法の紡ぎ盤", "background": "月光の観測庭", "accent": "b5a0eb"}
		"knight":
			return {"name": "聖堂騎士", "subtitle": "有限の武装 · 鍛造 · 溜め攻撃", "carrier": "遺物の整備盤", "background": "残火の聖堂", "accent": "e3bd73"}
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
			result = {"name": "微光の術式", "class_id": "mage", "size": Vector2i(1, 2), "color": "c9b3fa", "category": "attack", "description": "基本の自動術式。火の元素と紡ぐと、より広い爆炎の法印になる。", "damage": 5, "hits": 1, "interval": 1.5, "warmup": 0.4, "event_type": "spell"}
		"fire_mote":
			result = {"name": "火の元素", "class_id": "mage", "size": Vector2i.ONE, "color": "f29165", "category": "material", "description": "有限の元素。微光と爆炎、水と蒸気、風と炎風を紡ぐ。"}
		"water_mote":
			result = {"name": "水の元素", "class_id": "mage", "size": Vector2i.ONE, "color": "78c8e4", "category": "material", "description": "微光と氷矢、風と潮汐、火と蒸気を紡ぐ。素材もマスを使う。"}
		"wind_mote":
			result = {"name": "風の元素", "class_id": "mage", "size": Vector2i.ONE, "color": "94d7b3", "category": "material", "description": "微光と風刃、水と潮汐、火と炎風を紡ぐ。取得数には限りがある。"}
		"frost_bolt":
			result = {"name": "霜晶の氷矢", "class_id": "mage", "size": Vector2i(1, 2), "color": "9cdef7", "category": "attack", "description": "水と微光で紡ぐ氷矢。初回0.5秒、以後1.8秒ごとに単発攻撃。", "damage": 9, "hits": 1, "interval": 1.8, "warmup": 0.5, "event_type": "spell", "materials": {"spark": 1, "water_mote": 1}}
		"gale_blades":
			result = {"name": "旋回する風刃", "class_id": "mage", "size": Vector2i(2, 1), "color": "a0e7ba", "category": "attack", "description": "風と微光の双刃。1.4秒ごとに2回、各4ダメージ。結晶核は各段に有効。", "damage": 4, "hits": 2, "interval": 1.4, "warmup": 0.3, "event_type": "spell_multi", "materials": {"spark": 1, "wind_mote": 1}}
		"steam_burst":
			result = {"name": "蒸気爆破", "class_id": "mage", "size": Vector2i(2, 2), "color": "e5c4a0", "category": "attack", "description": "火と水で紡ぐ高圧の法印。初回1.9秒、以後3.4秒ごとに22ダメージ。", "damage": 22, "hits": 1, "interval": 3.4, "warmup": 1.9, "event_type": "spell_burst", "materials": {"fire_mote": 1, "water_mote": 1}}
		"ember_tornado":
			result = {"name": "炎風の渦", "class_id": "mage", "size": Vector2i(2, 3), "color": "f1a875", "category": "attack", "description": "火と風の大型術式。6マス使用、2.8秒ごとに4回、各6ダメージ。結晶核との接続にも空きが必要。", "damage": 6, "hits": 4, "interval": 2.8, "warmup": 1.2, "event_type": "spell_multi", "materials": {"fire_mote": 1, "wind_mote": 1}}
		"flame_glyph":
			result = {"name": "爆炎の法印", "class_id": "mage", "size": Vector2i(2, 2), "color": "ef936b", "category": "attack", "description": "集中した単発攻撃。初回1.6秒、以後3秒ごとに発動。4マス使用。", "damage": 18, "hits": 1, "interval": 3.0, "warmup": 1.6, "event_type": "spell_burst", "materials": {"spark": 1, "fire_mote": 1}}
		"tide_lances":
			result = {"name": "潮汐の連槍", "class_id": "mage", "size": Vector2i(3, 1), "color": "6ac7dc", "category": "attack", "description": "詠唱ごとに3回攻撃。横長のため配置場所を確保しよう。", "damage": 5, "hits": 3, "interval": 2.6, "warmup": 0.8, "event_type": "spell_multi", "materials": {"water_mote": 1, "wind_mote": 1}}
		"solar_crown":
			result = {"name": "陽炎の三連星", "class_id": "mage", "size": Vector2i(2, 2), "color": "ffc06c", "category": "attack", "description": "火を二つ重ねる三連星。3秒ごとに3回、各6ダメージ。", "damage": 6, "hits": 3, "interval": 3.0, "warmup": 0.8, "event_type": "spell_multi", "materials": {"fire_mote": 2}}
		"glacier_prism":
			result = {"name": "氷晶の大槍", "class_id": "mage", "size": Vector2i(1, 3), "color": "a5e6ff", "category": "attack", "description": "水を二つ重ねる大槍。2.8秒ごとに16ダメージ。", "damage": 16, "hits": 1, "interval": 2.8, "warmup": 1.1, "event_type": "spell_burst", "materials": {"water_mote": 2}}
		"storm_orbit":
			result = {"name": "暴風の五重輪", "class_id": "mage", "size": Vector2i(2, 2), "color": "9aefd2", "category": "attack", "description": "風を二つ重ねる五段攻撃。2.6秒ごとに各2ダメージ、結晶核の支援は各段に乗る。", "damage": 2, "hits": 5, "interval": 2.6, "warmup": 0.6, "event_type": "spell_multi", "materials": {"wind_mote": 2}}
		"arcane_nova":
			result = {"name": "星環の大魔法", "class_id": "mage", "size": Vector2i(2, 2), "color": "d5b8ff", "category": "attack", "description": "微光二つを一つの大魔法に紡ぐ。2.9秒ごとに26ダメージ。", "damage": 26, "hits": 1, "interval": 2.9, "warmup": 1.1, "event_type": "spell_burst", "materials": {"spark": 2}}
		"solar_lance":
			result = {"name": "熾陽の大槍", "class_id": "mage", "size": Vector2i(3, 2), "color": "ffb557", "category": "attack", "description": "爆炎の法印に火を重ねた大槍。6マスを使い、3.4秒ごとに32ダメージ。", "damage": 32, "hits": 1, "interval": 3.4, "warmup": 1.6, "event_type": "spell_burst", "materials": {"spark": 1, "fire_mote": 2}}
		"frost_orbit":
			result = {"name": "霜嵐の四重輪", "class_id": "mage", "size": Vector2i(3, 2), "color": "95eadf", "category": "attack", "description": "氷矢に風を重ねた四連撃。6マスを使い、2.4秒ごとに各5ダメージ。", "damage": 5, "hits": 4, "interval": 2.4, "warmup": 0.8, "event_type": "spell_multi", "materials": {"spark": 1, "water_mote": 1, "wind_mote": 1}}
		"arcane_focus":
			result = {"name": "集魔の結晶核", "class_id": "mage", "size": Vector2i.ONE, "color": "b79fe8", "category": "support", "description": "左右に接した術式の各段ダメージ+2。回転すると上下に接続。", "support_bonus": 2}
		"wind_prism":
			result = {"name": "疾風の結晶環", "class_id": "mage", "size": Vector2i(2, 1), "color": "9fdcc5", "category": "support", "description": "結晶核と風を紡ぐ。左右の術式の間隔を0.8倍（0.05秒単位で切上げ）。初回は変わらない。回転で上下に接続。結晶核の攻撃強化は失われる。複数は乗算、最短0.6倍。", "support_bonus": 0, "interval_factor": 0.8, "materials": {"arcane_focus": 1, "wind_mote": 1}}
		"moon_familiar":
			result = {"name": "月蛾の契約", "class_id": "mage", "size": Vector2i(2, 2), "color": "b4e8e5", "category": "summon", "description": "結晶核と水で月蛾を召喚。1契約につき1体、最大2体。初回0.8秒、以後2.2秒ごとに8ダメージ。敵は使い魔を狙わず、結晶核の強化や結晶環の加速も受けない。", "damage": 8, "hits": 1, "interval": 2.2, "warmup": 0.8, "event_type": "familiar_attack", "materials": {"arcane_focus": 1, "water_mote": 1}}
		"crowned_familiar":
			result = {"name": "月冠蛾の契約", "class_id": "mage", "size": Vector2i(3, 2), "color": "d7c4ff", "category": "summon", "description": "月蛾の契約に水を重ねて強化。1体分の上限と6マスを使い、初回1.1秒、以後2.6秒ごとに6ダメージを2回。敵は使い魔を狙わず、結晶核と結晶環の支援は受けない。", "damage": 6, "hits": 2, "interval": 2.6, "warmup": 1.1, "event_type": "familiar_attack", "materials": {"arcane_focus": 1, "water_mote": 2}}
		"mage_ward":
			result = {"name": "護符の板", "class_id": "mage", "size": Vector2i(2, 1), "color": "91a6dd", "category": "armor", "description": "被弾時に月の盾を展開し、各段のダメージを2軽減。盤上に置くと常時有効。", "armor": 2}
		"iron_blade":
			result = {"name": "制式長剣", "class_id": "knight", "size": Vector2i(1, 3), "color": "c6ccd2", "category": "attack", "description": "安定した基本攻撃。溜めの紋章と合わせると幅広い大剣になる。", "damage": 9, "hits": 1, "interval": 1.4, "warmup": 0.35, "event_type": "attack"}
		"greatblade":
			result = {"name": "誓約の大剣", "class_id": "knight", "size": Vector2i(2, 3), "color": "e5bd73", "category": "attack", "description": "溜めた後に重撃。以後3.2秒ごとに攻撃。6マスを使う。", "damage": 32, "hits": 1, "interval": 3.2, "warmup": 1.4, "event_type": "heavy_charge", "materials": {"iron_blade": 1, "charge_seal": 1}}
		"charge_seal":
			result = {"name": "溜めの紋章", "class_id": "knight", "size": Vector2i.ONE, "color": "d79c67", "category": "support", "description": "長剣と合わせて大剣を鍛造。左右の武器に+4、回転で上下に接続。", "support_bonus": 4}
		"knight_ward":
			result = {"name": "聖堂の装甲片", "class_id": "knight", "size": Vector2i(2, 1), "color": "e5d8b6", "category": "armor", "description": "防御+2。未実装のガードや反撃は発生しない。", "armor": 2}
	if not result.is_empty() and not result.has("materials"):
		result["materials"] = {kind: 1}
	return result

static func recipes_for(class_id: String) -> Array[Dictionary]:
	var recipes: Array[Dictionary] = []
	match class_id:
		"mage":
			recipes.append({"first": "fire_mote", "second": "spark", "result": "flame_glyph", "label": "火 + 微光 → 爆炎の法印"})
			recipes.append({"first": "water_mote", "second": "wind_mote", "result": "tide_lances", "label": "水 + 風 → 潮汐の連槍"})
			recipes.append({"first": "water_mote", "second": "spark", "result": "frost_bolt", "label": "水 + 微光 → 霜晶の氷矢"})
			recipes.append({"first": "wind_mote", "second": "spark", "result": "gale_blades", "label": "風 + 微光 → 旋回する風刃"})
			recipes.append({"first": "fire_mote", "second": "water_mote", "result": "steam_burst", "label": "火 + 水 → 蒸気爆破"})
			recipes.append({"first": "fire_mote", "second": "wind_mote", "result": "ember_tornado", "label": "火 + 風 → 炎風の渦"})
			recipes.append({"first": "fire_mote", "second": "fire_mote", "result": "solar_crown", "label": "火 + 火 → 陽炎の三連星"})
			recipes.append({"first": "water_mote", "second": "water_mote", "result": "glacier_prism", "label": "水 + 水 → 氷晶の大槍"})
			recipes.append({"first": "wind_mote", "second": "wind_mote", "result": "storm_orbit", "label": "風 + 風 → 暴風の五重輪"})
			recipes.append({"first": "spark", "second": "spark", "result": "arcane_nova", "label": "微光 + 微光 → 星環の大魔法"})
			recipes.append({"first": "flame_glyph", "second": "fire_mote", "result": "solar_lance", "label": "爆炎 + 火 → 熾陽の大槍"})
			recipes.append({"first": "frost_bolt", "second": "wind_mote", "result": "frost_orbit", "label": "氷矢 + 風 → 霜嵐の四重輪"})
			recipes.append({"first": "arcane_focus", "second": "wind_mote", "result": "wind_prism", "label": "結晶核 + 風 → 疾風の結晶環"})
			recipes.append({"first": "arcane_focus", "second": "water_mote", "result": "moon_familiar", "label": "結晶核 + 水 → 月蛾の契約"})
			recipes.append({"first": "moon_familiar", "second": "water_mote", "result": "crowned_familiar", "label": "月蛾 + 水 → 月冠蛾の契約"})
		"knight":
			recipes.append({"first": "iron_blade", "second": "charge_seal", "result": "greatblade", "label": "長剣 + 溜めの紋章 → 誓約の大剣"})
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
