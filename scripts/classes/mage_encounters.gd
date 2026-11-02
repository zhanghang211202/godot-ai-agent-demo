extends RefCounted
## Mage-only encounter choices. The default preserves the C0 combat baseline.

const IDS := ["sentinel", "mirror_moth", "thorn_golem"]

static func definition(id: String) -> Dictionary:
	match id:
		"sentinel":
			return {"id": id, "name": "月庭の衛兵", "hp": 140, "damage": 8, "hits": 1, "interval": 1.8, "windup": 0.64, "effect": "enemy", "height": 204, "lift": 0, "hint": "安定した単発攻撃。まずは術式と結晶核に慣れよう。"}
		"mirror_moth":
			return {"id": id, "name": "鏡翼の蛾", "hp": 108, "damage": 6, "hits": 2, "interval": 2.1, "windup": 0.7, "effect": "moth_bolt", "height": 156, "lift": 28, "hint": "星弾を2発、各6ダメージ。法盾は各段を軽減する。"}
		"thorn_golem":
			return {"id": id, "name": "茨の石像", "hp": 220, "damage": 18, "hits": 1, "interval": 3.4, "windup": 1.1, "effect": "thorn_crash", "height": 218, "lift": 0, "hint": "長い溜めからの重撃。3.4秒ごとに18ダメージ。高い体力に注意。"}
	return {}
