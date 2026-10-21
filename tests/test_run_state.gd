extends SceneTree

const RunRules = preload("res://scripts/gameplay/run_state.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_test_purchase_integrity()
	_test_grid_and_rotation()
	_test_merges()
	_test_synergy()
	_test_battle_loop()
	_test_loss_and_restart()
	_test_timing_determinism()
	_test_derived_equipment()
	_test_blessings()
	print("EmberRun: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _test_purchase_integrity() -> void:
	var run = RunRules.new()
	var starting_gold: int = run.gold
	var original_items: int = run.items.size()
	check(not run.buy(0, Vector2i(5, 3))["ok"], "Out-of-bounds purchase is rejected")
	check(run.gold == starting_gold and run.items.size() == original_items, "Rejected purchase changes neither money nor items")
	check(not run.buy(0, Vector2i(0, 0))["ok"], "Blocked purchase is rejected")
	check(run.gold == starting_gold and run.shop_offers[0] == "shield", "Blocked purchase preserves money and stock")
	check(run.buy(0, Vector2i(4, 0))["ok"], "Shield purchase fits")
	check(run.gold == starting_gold - 6 and run.items.size() == original_items + 1, "Successful purchase charges exact cost")
	check(not run.buy(0, Vector2i(4, 2))["ok"], "Sold shop slot cannot be purchased twice")
	check(run.gold == starting_gold - 6, "Repeated purchase does not charge")
	run.gold = 1
	check(not run.buy(1, Vector2i(3, 3))["ok"], "Unaffordable purchase is rejected")
	check(run.gold == 1, "Unaffordable purchase preserves money")

func _test_grid_and_rotation() -> void:
	var run = RunRules.new()
	var sword: Dictionary = run.items[0]
	var uid: int = sword["uid"]
	check(not run.move(uid, Vector2i(-1, 0))["ok"], "Negative grid coordinate is rejected")
	check(not run.move(uid, Vector2i(5, 3))["ok"], "Vertical sword cannot extend below bag")
	check(run.move(uid, Vector2i(4, 3), true)["ok"], "Rotated sword fits bottom row")
	check(run.get_item_size(run.item_by_uid(uid)) == Vector2i(2, 1), "Rotation changes occupied footprint")
	check(run.item_at(Vector2i(5, 3)).get("uid", -1) == uid, "Second occupied tile resolves the same item")
	check(run.item_at(Vector2i(4, 2)).is_empty(), "Rotation releases old vertical footprint")
	check(not run.move(uid, Vector2i(5, 3), true)["ok"], "Horizontal sword cannot extend beyond bag")
	check(run.item_by_uid(uid)["pos"] == Vector2i(4, 3), "Failed move preserves position")

func _test_merges() -> void:
	var run = RunRules.new()
	var target_uid: int = run.items[0]["uid"]
	var source_uid: int = run.items[1]["uid"]
	check(run.move(source_uid, Vector2i(0, 0))["event"] == "merge", "Same items merge on drop")
	check(run.items.size() == 2 and run.item_by_uid(target_uid)["level"] == 2, "Merge removes source and upgrades target")
	var stone_uid: int = run.items[1]["uid"]
	check(run.move(stone_uid, Vector2i(0, 0))["ok"], "Sword and whetstone recipe works")
	check(run.item_by_uid(target_uid)["kind"] == "longsword" and run.item_by_uid(target_uid)["level"] == 2, "Cross recipe preserves upgraded sword level")
	check(run.items.size() == 1, "Cross recipe consumes both ingredients into one item")
	var top_item: Dictionary = run.items[0].duplicate()
	top_item["uid"] = 999
	top_item["level"] = 3
	var other_top: Dictionary = top_item.duplicate()
	other_top["uid"] = 998
	check(run.get_merge_result(top_item, other_top).is_empty(), "Level 3 cap is enforced")
	run.new_run()
	run.shop_offers.assign(["sword", "shield", "herb", "ember"])
	check(run.buy(0, Vector2i(0, 0))["event"] == "merge", "Shop purchase can merge directly into owned equipment")
	check(run.items.size() == 3 and run.items[0]["level"] == 2 and run.gold == 14, "Shop merge charges once and keeps correct item count")
	run.new_run()
	var starting_count: int = run.items.size()
	var sword_uid: int = run.items[0]["uid"]
	check(run.move(sword_uid, Vector2i(0, 2), true)["ok"], "Cross recipe honors requested rotation")
	check(run.item_at(Vector2i(1, 2))["kind"] == "longsword" and run.items.size() == starting_count - 1, "Rotated cross recipe consumes the original source once")
	run.new_run()
	check(run.move(run.items[2]["uid"], Vector2i(3, 3))["ok"], "Recipe setup moves support into edge cell")
	var count_before: int = run.items.size()
	check(not run.can_merge(run.items[0], run.item_at(Vector2i(3, 3))), "Merge preview rejects vertical sword recipe at the bottom edge")
	var rotated_shop_sword := {"uid": -100, "kind": "sword", "level": 1, "pos": Vector2i.ZERO, "rotated": true}
	check(run.can_merge(rotated_shop_sword, run.item_at(Vector2i(3, 3))), "Merge preview accepts a fitting rotated shop candidate with a negative UID")
	check(not run.move(run.items[0]["uid"], Vector2i(3, 3))["ok"], "Cross recipe refuses a result that extends beyond the bag")
	check(run.items.size() == count_before and run.item_at(Vector2i(3, 3))["kind"] == "whetstone", "Rejected recipe preserves both original items")

func _test_synergy() -> void:
	var run = RunRules.new()
	var original_attack: int = run.get_stats()["attack"]
	check(run.get_stats()["synergy_count"] == 1, "Starting placement demonstrates one active adjacency bonus")
	var stone_uid: int = run.items[2]["uid"]
	check(run.move(stone_uid, Vector2i(5, 3))["ok"], "Support can move to remote tile")
	check(run.get_stats()["attack"] < original_attack and run.get_stats()["synergy_count"] == 0, "Moving support away removes its benefit")
	check(run.move(stone_uid, Vector2i(2, 0))["ok"], "Support can be placed beside other sword")
	check(run.get_stats()["synergy_count"] == 1 and run.get_stats()["attack"] == original_attack, "Side adjacency empowers a weapon")
	check(run.move(stone_uid, Vector2i(2, 2))["ok"], "Support can be placed diagonally")
	check(run.get_stats()["synergy_count"] == 0, "Diagonal contact does not grant adjacency")
	check(run.move(stone_uid, Vector2i(0, 2))["ok"], "Unrotated whetstone can be placed below a weapon")
	check(run.get_adjacency_bonus(run.items[0]) == 0, "Unrotated whetstone does not empower above or below")
	check(run.get_support_cells(run.item_by_uid(stone_uid)) == [Vector2i(1, 2)], "Whetstone blue dots show only valid horizontal neighbors")
	check(run.move(stone_uid, Vector2i(0, 2), true)["ok"], "Whetstone can rotate without changing its footprint")
	check(run.get_adjacency_bonus(run.items[0]) == 3, "Rotated whetstone empowers the weapon above")
	check(run.get_support_cells(run.item_by_uid(stone_uid)).has(Vector2i(0, 1)), "Blue dots agree with the actual directional bonus")
	var ember := {"kind": "ember", "pos": Vector2i(3, 2), "rotated": true}
	check(run.get_support_cells(ember).size() == 4, "Ember always empowers all four cardinal neighbors")

func _test_battle_loop() -> void:
	var run = RunRules.new()
	# A legal six-cell starter purchase, followed by an actual five-encounter run.
	check(run.buy(0, Vector2i(4, 0))["ok"], "Campaign buys defensive equipment")
	check(run.buy(1, Vector2i(2, 0))["ok"], "Campaign buys healing")
	check(run.buy(2, Vector2i(2, 2))["ok"], "Campaign buys a third weapon")
	check(run.buy(3, Vector2i(1, 2))["ok"], "Campaign buys adjacency support")
	# Reward shops are seed-deterministic; play by placing or upgrading affordable gear.
	var attacks: int = 0
	var healing: int = 0
	for encounter in range(5):
		if run.phase == "prepare":
			_shop_automatically(run)
			check(run.start_battle()["ok"], "Encounter %d starts" % (encounter + 1))
		var elapsed: float = 0.0
		while run.phase == "battle" and elapsed < 95.0:
			var events: Array[Dictionary] = run.tick(0.1)
			for event in events:
				if event["type"] == "hero_attack":
					attacks += 1
				elif event["type"] == "heal":
					healing += 1
			elapsed += 0.1
		check(run.phase == "reward" or run.phase == "won", "Encounter %d is winnable with a legal starter strategy" % (encounter + 1))
		if run.phase == "lost":
			break
		if run.phase == "reward":
			check(not run.claim_reward()["ok"], "Reward cannot be skipped before choosing a blessing")
			check(not run.reward_choices.any(func(id): return id in run.blessings), "Victory never offers an already owned blessing")
			check(run.reward_choices.size() == 3 and run.choose_reward(0)["ok"], "Victory offers three selectable blessings")
			check(run.claim_reward()["ok"], "Victory advances to next preparation")
	check(run.phase == "won" and run.wave == 5, "Five victories complete the campaign")
	check(run.blessings.size() == 4 and run.reward_choices.is_empty(), "Completed campaign has four blessings and no final boss choice")
	check(attacks > 10 and healing > 0, "Battle emits attack and healing animation events")
	check(not run.start_battle()["ok"] and run.tick(1.0).is_empty(), "Won campaign cannot continue fighting")

func _shop_automatically(run) -> void:
	# Simulate a player trying merges first, then open spaces. No game state is forged.
	for slot in range(run.shop_offers.size()):
		if run.shop_offers[slot].is_empty():
			continue
		var purchased: bool = false
		for item in run.items.duplicate():
			var test_item := {"uid": -100, "kind": run.shop_offers[slot], "level": 1, "rotated": false}
			if not run.get_merge_result(test_item, item).is_empty():
				if run.buy(slot, item["pos"])["ok"]:
					purchased = true
					break
		if purchased:
			continue
		for y in range(4):
			for x in range(6):
				if run.buy(slot, Vector2i(x, y))["ok"]:
					purchased = true
					break
			if purchased:
				break

func _test_loss_and_restart() -> void:
	var run = RunRules.new()
	run.hp = 1
	check(run.start_battle()["ok"], "Low health encounter starts")
	check(not run.reroll()["ok"] and not run.sell(run.items[0]["uid"])["ok"], "Combat locks shopping and selling")
	var events: Array[Dictionary] = run.tick(10.0)
	check(run.phase == "lost" and run.hp == 0, "Taking lethal damage ends the run")
	check(events.any(func(event): return event["type"] == "defeat"), "Defeat emits an animation event")
	run.new_run()
	check(run.phase == "prepare" and run.wave == 1 and run.hp == 100 and run.gold == 18, "Restart resets the campaign")
	check(run.items.size() == 3 and run.shop_offers[0] == "shield", "Restart restores equipment and starter shop")

func _test_timing_determinism() -> void:
	var slow_frames = RunRules.new()
	var fast_frames = RunRules.new()
	slow_frames.start_battle()
	fast_frames.start_battle()
	var slow_events: Array[Dictionary] = slow_frames.tick(6.0)
	var fast_events: Array[Dictionary] = []
	for index in range(120):
		fast_events.append_array(fast_frames.tick(0.05))
	check(slow_frames.hp == fast_frames.hp and slow_frames.enemy_hp == fast_frames.enemy_hp, "Simulation outcome is independent of render frame size")
	check(slow_events == fast_events, "Seeded combat emits deterministic events at different frame sizes")
	var slow_ending: Array[Dictionary] = slow_frames.tick(90.0)
	var fast_ending: Array[Dictionary] = []
	while fast_frames.phase == "battle":
		fast_ending.append_array(fast_frames.tick(0.05))
	check(slow_ending == fast_ending and slow_frames.reward_choices == fast_frames.reward_choices, "Frame-independent combat also generates identical blessing choices")

func _test_derived_equipment() -> void:
	var run = RunRules.new()
	check(run.get_definition("longsword")["size"] == Vector2i(1, 3), "Longsword occupies three cells")
	check(run.get_definition("flame_sword")["size"] == Vector2i(1, 3), "Flame sword occupies three cells")
	check(run.get_definition("windbow")["size"] == Vector2i(3, 1), "Windbow occupies three horizontal cells")
	check(run.get_definition("greater_potion")["size"] == Vector2i(1, 2), "Greater potion occupies two cells")
	check(RunRules.RECIPES.size() == 5, "Recipe guide exposes all five cross recipes")
	for recipe in RunRules.RECIPES:
		check(recipe["result"] not in RunRules.SHOP_POOL, "Derived item %s is crafted instead of sold" % recipe["result"])
	check(run.move(run.items[2]["uid"], Vector2i(0, 0))["ok"], "Starter sword crafts a vertical three-cell longsword")
	check(run.buy(3, Vector2i(0, 0))["ok"] and run.item_at(Vector2i(0, 0))["kind"] == "flame_sword", "Longsword and ember craft a flame sword")
	check(run.buy(0, Vector2i(3, 0))["ok"] and run.buy(1, Vector2i(3, 0))["ok"], "Shield and herb craft thorn shield")
	check(run.get_stats()["thorns"] == 3 and run.get_stats()["armor"] == 5, "Thorn shield grants both armor and reflection")
	run.start_battle()
	var reflected_events: Array[Dictionary] = run.tick(2.0)
	check(reflected_events.any(func(event): return event.get("reflected", false) and event["amount"] == 3), "Thorn shield reflects enemy attacks during combat")
	run.new_run()
	run.shop_offers.assign(["bow", "ember", "potion", "herb"])
	check(run.buy(0, Vector2i(3, 0))["ok"] and run.buy(1, Vector2i(3, 0))["ok"], "Bow and ember craft a fitting windbow")
	check(run.item_at(Vector2i(5, 0))["kind"] == "windbow", "Windbow really occupies its third cell")
	check(run.buy(2, Vector2i(4, 2))["ok"] and run.buy(3, Vector2i(4, 2))["ok"], "Potion and herb craft greater potion")
	run.hp = 40
	run.start_battle()
	var potion_events: Array[Dictionary] = run.tick(0.1)
	check(potion_events.any(func(event): return event["type"] == "heal" and event["amount"] == 42), "Greater potion delivers its enhanced one-use heal")
	var later_events: Array[Dictionary] = run.tick(20.0)
	check(not later_events.any(func(event): return event["type"] == "heal"), "Greater potion does not recharge within the same battle")
	run.new_run()
	check(run.buy(2, Vector2i(4, 3))["ok"], "Edge bow setup is legal")
	var money_before: int = run.gold
	check(not run.buy(3, Vector2i(4, 3))["ok"], "Windbow recipe is rejected when its third cell extends beyond the bag")
	check(run.gold == money_before and run.shop_offers[3] == "ember" and run.item_at(Vector2i(4, 3))["kind"] == "bow", "Rejected shop recipe preserves ingredients, money, and stock")

func _test_blessings() -> void:
	var run = RunRules.new()
	check(not run.choose_reward(0)["ok"], "A blessing cannot be chosen before victory")
	run.start_battle()
	run.tick(90.0)
	check(run.phase == "reward" and run.reward_choices.size() == 3, "Victory exposes three blessing choices")
	var chosen_id: String = run.reward_choices[0]
	var original_choices: Array[String] = run.reward_choices.duplicate()
	check(not run.choose_reward(-1)["ok"] and run.reward_choices == original_choices, "Invalid blessing index does not change rewards")
	check(run.choose_reward(0)["ok"] and run.blessings == [chosen_id], "Choice records the actual selected blessing")
	check(run.reward_chosen and run.reward_choices.is_empty(), "Choosing clears pending choices and marks the reward selected")
	check(not run.choose_reward(0)["ok"], "A reward can only be selected once")
	check(run.claim_reward()["ok"] and not run.reward_chosen and run.reward_choices.is_empty(), "Continuing resets pending reward state")
	run.new_run()
	check(run.blessings.is_empty() and not run.reward_chosen and run.reward_choices.is_empty(), "New run clears every blessing state")
	# Exact effect fixtures use the same valid reward state exposed by a victory.
	run.phase = "reward"
	run.hp = 40
	run.reward_choices.assign(["vitality", "coin_pouch", "campfire"])
	check(run.choose_reward(0)["ok"] and run.max_hp == 118 and run.hp == 58, "Vitality increases maximum health and heals immediately")
	run.new_run()
	run.phase = "reward"
	run.reward_choices.assign(["coin_pouch", "vitality", "campfire"])
	check(run.choose_reward(0)["ok"] and run.gold == 26, "Coin blessing pays its immediate reward once")
	run.new_run()
	run.blessings.assign(["keen_edge", "ironbark", "moonwater", "focus"])
	var stats: Dictionary = run.get_stats()
	check(stats["attack"] == 17 and stats["armor"] == 1 and stats["regen"] == 1, "Blessing benefits and tradeoffs combine in combat statistics")
	check(is_equal_approx(float(stats["crit"]), 0.14), "Critical chance includes positive and negative blessing effects")
	check(not run.get_enemy_info()["trait"].is_empty() and run.get_enemy_info()["wave"] == 1, "Enemy preview includes a concise trait hint")
