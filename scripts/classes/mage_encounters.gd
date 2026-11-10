extends RefCounted
## Mage-only encounter choices. The default preserves the C0 combat baseline.

const IDS := ["sentinel", "mirror_moth", "thorn_golem"]
const CAMPAIGN_IDS := ["campaign_sentinel", "campaign_moth", "campaign_golem", "astral_scribe", "moon_crowned"]
const EXTENDED_CAMPAIGN_IDS := ["campaign_sentinel", "campaign_moth", "campaign_golem", "moon_lantern", "extended_astral_scribe", "astral_serpent", "extended_moon_crowned"]

static func definition(id: String) -> Dictionary:
	match id:
		"campaign_sentinel":
			return {"id": id, "name": "月庭の衛兵", "hp": 110, "damage": 6, "hits": 1, "interval": 1.8, "windup": 0.64, "effect": "enemy", "height": 204, "lift": 0, "hint": "安定した単発攻撃。まずは術式と結晶核に慣れよう。"}
		"campaign_moth":
			return {"id": id, "name": "鏡翼の蛾", "hp": 145, "damage": 6, "hits": 2, "interval": 2.1, "windup": 0.7, "effect": "moth_bolt", "height": 156, "lift": 28, "hint": "星弾を2発、各6ダメージ。法盾は各段を軽減する。"}
		"campaign_golem":
			return {"id": id, "name": "茨の石像", "hp": 190, "damage": 16, "hits": 1, "interval": 3.4, "windup": 1.1, "effect": "thorn_crash", "height": 218, "lift": 0, "hint": "長い溜めからの重撃。3.4秒ごとに16ダメージ。高い体力に注意。"}
		"moon_lantern":
			return {"id": id, "name": "月灯の精霊", "hp": 205, "damage": 9, "hits": 2, "interval": 2.5, "windup": 0.8, "effect": "lantern_flare", "height": 190, "lift": 24, "hint": "青い灯火を2発、各9ダメージ。法盾はそれぞれの命中を軽減する。"}
		"astral_serpent":
			return {"id": id, "name": "星巡りの蛇", "hp": 240, "damage": 14, "hits": 2, "interval": 3.1, "windup": 1.0, "effect": "serpent_comet", "height": 240, "lift": 12, "hint": "星の牙を2発、各14ダメージ。長い溜めの後に強い連撃を放つ。"}
		"sentinel":
			return {"id": id, "name": "月庭の衛兵", "hp": 140, "damage": 8, "hits": 1, "interval": 1.8, "windup": 0.64, "effect": "enemy", "height": 204, "lift": 0, "hint": "安定した単発攻撃。まずは術式と結晶核に慣れよう。"}
		"mirror_moth":
			return {"id": id, "name": "鏡翼の蛾", "hp": 108, "damage": 6, "hits": 2, "interval": 2.1, "windup": 0.7, "effect": "moth_bolt", "height": 156, "lift": 28, "hint": "星弾を2発、各6ダメージ。法盾は各段を軽減する。"}
		"thorn_golem":
			return {"id": id, "name": "茨の石像", "hp": 220, "damage": 18, "hits": 1, "interval": 3.4, "windup": 1.1, "effect": "thorn_crash", "height": 218, "lift": 0, "hint": "長い溜めからの重撃。3.4秒ごとに18ダメージ。高い体力に注意。"}
		"sentinel_elite":
			return {"id": id, "name": "月庭の双星衛兵", "hp": 170, "damage": 7, "hits": 2, "interval": 2.1, "windup": 0.7, "effect": "enemy", "height": 230, "lift": 0, "hint": "強化された衛兵。2.1秒ごとに7ダメージを2回。"}
		"astral_scribe":
			return {"id": id, "name": "星詠みの書霊", "hp": 220, "damage": 7, "hits": 3, "interval": 2.4, "windup": 0.8, "effect": "scribe_rune", "height": 220, "lift": 18, "hint": "浮遊する書霊が2.4秒ごとに7ダメージの符弾を3発放つ。法盾は各段を軽減する。"}
		"extended_astral_scribe":
			return {"id": id, "name": "星詠みの書霊", "hp": 245, "damage": 7, "hits": 3, "interval": 2.4, "windup": 0.8, "effect": "scribe_rune", "height": 220, "lift": 18, "hint": "浮遊する書霊が2.4秒ごとに7ダメージの符弾を3発放つ。法盾は各段を軽減する。"}
		"moon_crowned":
			return {"id": id, "name": "月冠の星守", "hp": 260, "damage": 10, "hits": 2, "interval": 2.7, "windup": 0.8, "effect": "boss_star", "height": 250, "lift": 0, "hint": "BOSS：星弾2連撃と、長く溜める重撃を交互に放つ。", "pattern": [
				{"damage": 10, "hits": 2, "interval": 2.7, "windup": 0.8, "effect": "boss_star"},
				{"damage": 19, "hits": 1, "interval": 3.1, "windup": 1.1, "effect": "boss_crash"}]}
		"extended_moon_crowned":
			return {"id": id, "name": "月冠の星守", "hp": 300, "damage": 12, "hits": 2, "interval": 2.7, "windup": 0.8, "effect": "boss_star", "height": 250, "lift": 0, "hint": "BOSS：星弾2連撃と、長く溜める重撃を交互に放つ。", "pattern": [
				{"damage": 12, "hits": 2, "interval": 2.7, "windup": 0.8, "effect": "boss_star"},
				{"damage": 21, "hits": 1, "interval": 3.1, "windup": 1.1, "effect": "boss_crash"}]}
	return {}
