extends SceneTree
## Native integration smoke test. Run with --headless --path . --script res://tests/ui_smoke.gd.
## Mouse actions use the same handlers as the real interface; combat time is accelerated.

const MAIN_SCENE := "res://scenes/main.tscn"
var ui: Control
var game: RefCounted
var constants: Dictionary
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load(MAIN_SCENE)
	if scene == null:
		push_error("Unable to load the main scene")
		quit(1)
		return
	ui = scene.instantiate()
	root.add_child(ui)
	await process_frame
	ui.set_process(false)
	ui.set("muted", true)
	game = ui.get("game")
	constants = ui.get_script().get_script_constant_map()
	check(game != null and game.get("phase") == "prepare", "Main scene opens in preparation")
	check(ui.size.x >= 1000.0 and ui.size.y >= 700.0, "Main interface has a usable viewport")
	_test_drag_merge_rotation()
	_test_purchase_cancel_sell()
	_test_help_and_input()
	await _test_native_input_route()
	_test_campaign()
	_test_defeat_restart()
	print("EmberGame UI smoke: %d checks, %d failures" % [checks, failures])
	ui.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _cell(cell: Vector2i) -> Vector2:
	return Vector2(constants["GRID_ORIGIN"]) + (Vector2(cell) + Vector2(0.5, 0.5)) * float(constants["CELL_SIZE"])

func _center(name: String) -> Vector2:
	var rect: Rect2 = constants[name]
	return rect.get_center()

func _click(position: Vector2) -> void:
	ui.call("_press", position)
	ui.call("_release", position)

func _drag(from: Vector2, to: Vector2, rotate: bool = false) -> void:
	ui.call("_press", from)
	ui.call("_mouse_move", from + Vector2(8, 8))
	if rotate:
		ui.call("_rotate_drag")
	ui.call("_mouse_move", to)
	ui.call("_release", to)

func _reset() -> void:
	game.call("new_run")
	ui.set("selected_uid", -1)
	ui.set("drag", {})
	ui.set("click_picked", false)
	ui.set("help_open", false)

func _items() -> Array:
	return game.get("items")

func _test_drag_merge_rotation() -> void:
	var selected_id: int = _items()[1]["uid"]
	_click(_cell(Vector2i(1, 0)))
	check(int(ui.get("selected_uid")) == selected_id and Dictionary(ui.get("drag")).is_empty(), "Clicking bag equipment selects without moving it")
	_drag(_cell(Vector2i(1, 0)), _cell(Vector2i(0, 0)))
	check(_items().size() == 2 and int(_items()[0]["level"]) == 2, "Mouse drag merges matching swords")
	check(not Dictionary(game.call("item_by_uid", int(ui.get("selected_uid")))).is_empty(), "Merge keeps its resulting item selected for follow-up actions")
	check(float(ui.get("merge_glow")) > 0.0, "Successful merge triggers visible feedback")
	_drag(_cell(Vector2i(0, 2)), _cell(Vector2i(0, 0)))
	check(_items().size() == 1 and _items()[0]["kind"] == "longsword", "Dragging whetstone onto sword triggers the cross-item recipe")
	var uid: int = _items()[0]["uid"]
	_drag(_cell(Vector2i(0, 0)), _cell(Vector2i(4, 3)), true)
	var rotated: Dictionary = game.call("item_by_uid", uid)
	check(rotated["pos"] == Vector2i(4, 3) and rotated["rotated"], "R during drag rotates and places equipment on the bottom row")
	_drag(_cell(Vector2i(4, 3)), _cell(Vector2i(5, 3)))
	check(game.call("item_by_uid", uid)["pos"] == Vector2i(4, 3), "Out-of-bounds UI drop preserves the item")
	check(not bool(ui.get("toast_good")) and Dictionary(ui.get("drag")).is_empty(), "Invalid UI drop ends dragging and shows an error")
	_drag(_cell(Vector2i(4, 3)), Vector2(30, 98))
	check(_items().size() == 1 and game.call("item_by_uid", uid)["pos"] == Vector2i(4, 3), "Dropping outside the bag safely cancels")
	_reset()
	_drag(_cell(Vector2i(0, 1)), _cell(Vector2i(4, 2)))
	check(game.call("item_at", Vector2i(4, 1))["kind"] == "sword", "Dragging from the second occupied cell preserves the grab offset")

func _test_purchase_cancel_sell() -> void:
	_reset()
	var shop_rect: Rect2 = ui.call("_shop_rect", 0)
	var before_gold: int = game.get("gold")
	_drag(shop_rect.get_center(), _cell(Vector2i(5, 3)))
	check(game.get("gold") == before_gold and game.get("shop_offers")[0] == "shield", "Invalid shop drop preserves currency and stock")
	_click(shop_rect.get_center())
	check(bool(ui.get("click_picked")), "Clicking a shop item begins click-to-place mode")
	_click(_cell(Vector2i(4, 0)))
	check(game.get("gold") == before_gold - 6 and _items().size() == 4, "Clicking a free tile purchases the selected shield")
	check(not bool(ui.get("click_picked")) and Dictionary(ui.get("drag")).is_empty(), "Purchase clears the held item")
	var item: Dictionary = game.call("item_at", Vector2i(4, 0))
	var refund: int = game.call("get_sell_price", item)
	_click(_cell(Vector2i(4, 0)))
	_click(_center("SELL_RECT"))
	check(_items().size() == 3 and game.get("gold") == before_gold - 6 + refund, "Selecting equipment and clicking Sell refunds the correct amount")
	var herb_rect: Rect2 = ui.call("_shop_rect", 1)
	_click(herb_rect.get_center())
	var cancel := InputEventMouseButton.new()
	cancel.button_index = MOUSE_BUTTON_RIGHT
	cancel.pressed = true
	cancel.position = herb_rect.get_center()
	ui.call("_gui_input", cancel)
	check(Dictionary(ui.get("drag")).is_empty() and not bool(ui.get("click_picked")), "Right-click cancels click-to-place mode")
	before_gold = game.get("gold")
	_click(_center("REFRESH_RECT"))
	check(game.get("gold") == before_gold - int(game.get("reroll_cost")) and game.get("shop_offers").size() == 4, "Refresh button changes stock and charges its displayed cost")

func _test_help_and_input() -> void:
	_reset()
	_click(Vector2(1361, 47))
	check(bool(ui.get("help_open")), "Help button opens the gameplay instructions")
	var blocked_key := InputEventKey.new()
	blocked_key.keycode = KEY_SPACE
	blocked_key.pressed = true
	ui.call("_unhandled_key_input", blocked_key)
	check(bool(ui.get("help_open")) and game.get("phase") == "prepare", "Gameplay shortcuts cannot start a battle behind the help overlay")
	_click(_center("PRIMARY_RECT"))
	check(not bool(ui.get("help_open")) and game.get("phase") == "prepare", "Clicking while help is open closes it without starting battle")
	_click(Vector2(1254, 47))
	check(not bool(ui.get("muted")), "Sound toggle updates the mute setting")
	ui.set("muted", true)
	_click(Vector2(992, 131))
	check(float(ui.get("speed")) == 2.0, "Battle speed toggle switches to 2x")
	_click(Vector2(992, 131))
	check(float(ui.get("speed")) == 1.0, "Battle speed toggle switches back to 1x")
	_click(Vector2(1316, 428))
	check(bool(ui.get("recipes_open")), "Recipe book button opens the recipe panel")
	var key := InputEventKey.new()
	key.keycode = KEY_TAB
	key.pressed = true
	ui.call("_unhandled_key_input", key)
	check(not bool(ui.get("recipes_open")), "Tab toggles the recipe panel")

func _test_campaign() -> void:
	_reset()
	_drag_shop(0, Vector2i(4, 0))
	_drag_shop(1, Vector2i(2, 0))
	_drag_shop(2, Vector2i(2, 2))
	_drag_shop(3, Vector2i(1, 2))
	check(game.get("gold") == 0 and _items().size() == 7, "Starter loadout can be purchased entirely through mouse dragging")
	for encounter in range(5):
		if game.get("phase") != "prepare":
			break
		_shop_with_mouse()
		_click(_center("PRIMARY_RECT"))
		check(game.get("phase") == "battle", "Primary button starts encounter %d" % (encounter + 1))
		var locked_gold: int = game.get("gold")
		_click(_center("REFRESH_RECT"))
		check(game.get("gold") == locked_gold, "Battle locks shop refresh in encounter %d" % (encounter + 1))
		var steps := 0
		while game.get("phase") == "battle" and steps < 950:
			ui.call("_process", 0.1)
			steps += 1
		check(game.get("phase") in ["reward", "won"], "UI simulation wins encounter %d using legal purchases" % (encounter + 1))
		check(not Array(ui.get("battle_log")).is_empty(), "Encounter %d drives UI combat feedback" % (encounter + 1))
		if game.get("phase") == "reward":
			_click(_center("PRIMARY_RECT"))
			check(game.get("phase") == "prepare" and int(game.get("wave")) == encounter + 2, "Reward button advances the route")
	check(game.get("phase") == "won" and int(game.get("wave")) == 5, "Five encounters reach the final victory state")
	_click(_center("PRIMARY_RECT"))
	check(game.get("phase") == "prepare" and int(game.get("wave")) == 1 and _items().size() == 3, "Victory button restarts a fresh playable run")

func _test_native_input_route() -> void:
	# Exercise engine input routing in addition to the coordinate-based handler tests.
	ui.set("muted", true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	# Dummy headless windows are 64x64; events enter in window coordinates.
	# Convert the game's logical canvas coordinates through its stretch transform.
	press.position = root.get_screen_transform() * Vector2(1254, 47)
	press.global_position = press.position
	Input.parse_input_event(press)
	await process_frame
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
	check(not bool(ui.get("muted")), "Native mouse events reach the main Control interface")
	ui.set("muted", true)
	ui.set("recipes_open", false)
	var key := InputEventKey.new()
	key.keycode = KEY_TAB
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	check(bool(ui.get("recipes_open")), "Native key events reach the keyboard shortcuts")
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
	ui.set("recipes_open", false)

func _drag_shop(slot: int, cell: Vector2i, rotated: bool = false) -> void:
	var shop_rect: Rect2 = ui.call("_shop_rect", slot)
	_drag(shop_rect.get_center(), _cell(cell), rotated)

func _shop_with_mouse() -> void:
	for slot in range(4):
		var offers: Array = game.get("shop_offers")
		if str(offers[slot]).is_empty():
			continue
		var definition: Dictionary = game.call("get_definition", offers[slot])
		if int(game.get("gold")) < int(definition["cost"]):
			continue
		var purchased := false
		var candidate := {"uid": -100 - slot, "kind": offers[slot], "level": 1, "rotated": false}
		for item in _items().duplicate():
			if not str(game.call("get_merge_result", candidate, item)).is_empty():
				_drag_shop(slot, item["pos"])
				if str(game.get("shop_offers")[slot]).is_empty():
					purchased = true
					break
		if purchased:
			continue
		for y in range(4):
			for x in range(6):
				if bool(game.call("can_place", candidate, Vector2i(x, y))):
					_drag_shop(slot, Vector2i(x, y))
					purchased = str(game.get("shop_offers")[slot]).is_empty()
					if purchased:
						break
			if purchased:
				break

func _test_defeat_restart() -> void:
	_reset()
	# This fixture only shortens the defeat case; the win path above never forges state.
	game.set("hp", 1)
	_click(_center("PRIMARY_RECT"))
	ui.call("_process", 5.0)
	check(game.get("phase") == "lost", "Lethal combat reaches the defeat interface")
	_click(_center("PRIMARY_RECT"))
	check(game.get("phase") == "prepare" and game.get("hp") == 100 and game.get("gold") == 18, "Defeat button restores a fresh run")
