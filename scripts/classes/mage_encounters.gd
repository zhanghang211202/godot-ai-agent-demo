extends RefCounted
## Mage-only encounter choices. The default preserves the C0 combat baseline.

const IDS := ["sentinel", "mirror_moth", "thorn_golem"]

static func definition(id: String) -> Dictionary:
	match id:
		"sentinel":
			return {"id": id, "name": "月庭巡卫", "hp": 140, "damage": 8, "hits": 1, "interval": 1.8, "windup": 0.64, "effect": "enemy", "height": 204, "lift": 0, "hint": "稳定单击。先熟悉法术与聚能晶核。"}
		"mirror_moth":
			return {"id": id, "name": "镜翼灵蛾", "hp": 108, "damage": 6, "hits": 2, "interval": 2.1, "windup": 0.7, "effect": "moth_bolt", "height": 156, "lift": 28, "hint": "成对星弹：每次两段，各6伤害。法盾逐段减伤。"}
		"thorn_golem":
			return {"id": id, "name": "荆棘石像", "hp": 220, "damage": 18, "hits": 1, "interval": 3.4, "windup": 1.1, "effect": "thorn_crash", "height": 218, "lift": 0, "hint": "长蓄势重击：每3.4秒18伤害。高生命考验持续输出。"}
	return {}
