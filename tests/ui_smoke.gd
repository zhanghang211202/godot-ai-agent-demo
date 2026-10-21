extends SceneTree
## Native integration smoke test. Run with --headless --path . --script res://tests/ui_smoke.gd.
## Mouse actions use the same handlers as the real interface; combat time is accelerated.

const MAIN_SCENE := "res://scenes/main.tscn"
const Save = preload("res://scripts/gameplay/run_save.gd")
const TEST_CHECKPOINT := "res://.tools/test-saves/ui-smoke.json"
const CORRUPT_CHECKPOINT := "res://.tools/test-saves/ui-smoke-corrupt.json"
const BLOCKED_CHECKPOINT := "res://.tools/test-saves/ui-smoke-blocked.json"
const DELETE_FAILURE_DIRECTORY := "res://.tools/test-saves/ui-smoke-delete-target"
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
	_test_directional_support()
	_test_menu_pause_and_codex()
	await _test_native_input_route()
	_test_campaign()
	_test_defeat_restart()
	_test_menu_save_load()
	_test_checkpoint_failure_protection()
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

func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	ui.call("_unhandled_key_input", event)

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
	ui.set("menu_open", false)
	ui.set("_resume_prompt", false)
	ui.set("_confirm_new_run", false)
	ui.set("recipes_open", false)
	ui.set("recipe_page", 0)
	ui.set("speed", 1.0)

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
	_drag(_cell(Vector2i(0, 0)), _cell(Vector2i(3, 3)), true)
	var rotated: Dictionary = game.call("item_by_uid", uid)
	check(rotated["pos"] == Vector2i(3, 3) and rotated["rotated"], "R during drag rotates a three-cell longsword onto the bottom row")
	check(game.call("item_at", Vector2i(5, 3))["uid"] == uid, "Three-cell longsword occupies the full bottom-row footprint")
	_drag(_cell(Vector2i(3, 3)), _cell(Vector2i(4, 3)))
	check(game.call("item_by_uid", uid)["pos"] == Vector2i(3, 3), "Out-of-bounds three-cell UI drop preserves the item")
	check(not bool(ui.get("toast_good")) and Dictionary(ui.get("drag")).is_empty(), "Invalid UI drop ends dragging and shows an error")
	_drag(_cell(Vector2i(3, 3)), Vector2(30, 98))
	check(_items().size() == 1 and game.call("item_by_uid", uid)["pos"] == Vector2i(3, 3), "Dropping outside the bag safely cancels")
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

func _test_directional_support() -> void:
	_reset()
	var stone: Dictionary = game.call("item_at", Vector2i(0, 2))
	var uid: int = stone["uid"]
	var initial_attack: int = game.call("get_stats")["attack"]
	check(stone["rotated"] and game.call("get_support_cells", stone).has(Vector2i(0, 1)), "Initial rotated whetstone blue dot points to the starter sword")
	_click(_cell(Vector2i(0, 2)))
	_key(KEY_R)
	stone = game.call("item_by_uid", uid)
	check(not stone["rotated"] and game.call("get_stats")["attack"] < initial_attack, "Selected-support rotation updates directional attack feedback")
	check(bool(ui.get("toast_good")) and game.call("get_support_cells", stone) == [Vector2i(1, 2)], "Support rotation succeeds and exposes horizontal blue-dot feedback")
	_key(KEY_R)
	check(game.call("item_by_uid", uid)["rotated"] and game.call("get_stats")["attack"] == initial_attack, "Rotating the selected support back restores its visible combat bonus")

func _test_menu_pause_and_codex() -> void:
	_reset()
	_click(Vector2(1316, 428))
	var pages: int = ui.call("_recipe_page_count")
	check(bool(ui.get("recipes_open")) and pages == 3, "Recipe guide opens with all v0.2 recipes across three pages")
	_click(Vector2(1357, 825))
	check(ui.get("recipe_page") == 1, "Recipe guide next arrow advances a page")
	_click(Vector2(1357, 825))
	_click(Vector2(1357, 825))
	check(ui.get("recipe_page") == 0, "Recipe guide next arrow wraps after its last page")
	_click(Vector2(1128, 825))
	check(ui.get("recipe_page") == pages - 1, "Recipe guide previous arrow wraps to its last page")
	_key(KEY_TAB)
	_click(_center("PRIMARY_RECT"))
	ui.call("_process", 0.25)
	_click(_center("MENU_RECT"))
	var paused_time: float = game.get("battle_time")
	var paused_hp: int = game.get("hp")
	var paused_enemy_hp: int = game.get("enemy_hp")
	check(bool(ui.get("menu_open")) and game.get("phase") == "battle", "Header menu opens during a live battle")
	ui.call("_process", 5.0)
	check(is_equal_approx(float(game.get("battle_time")), paused_time) and game.get("hp") == paused_hp and game.get("enemy_hp") == paused_enemy_hp, "Open menu pauses the battle clock and all combat damage")
	_key(KEY_SPACE)
	check(bool(ui.get("menu_open")) and game.get("phase") == "battle", "Gameplay shortcuts remain blocked behind the pause menu")
	_key(KEY_ESCAPE)
	check(not bool(ui.get("menu_open")) and game.get("phase") == "battle", "Escape returns from the pause menu to the existing battle")
	ui.call("_process", 0.1)
	check(float(game.get("battle_time")) > paused_time, "Closing the menu resumes combat time")
	_reset()

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
			var options: Array = game.get("reward_choices").duplicate()
			var owned_before: int = game.get("blessings").size()
			_click(_center("PRIMARY_RECT"))
			check(game.get("phase") == "reward" and game.get("reward_choices") == options, "Reward continuation is blocked until a blessing is selected")
			var reward_rect: Rect2 = ui.call("_reward_rect", 0)
			_click(reward_rect.get_center())
			check(bool(game.get("reward_chosen")) and game.get("blessings").size() == owned_before + 1 and game.get("reward_choices").is_empty(), "Mouse click selects one blessing and clears the reward cards")
			var chosen_gold: int = game.get("gold")
			var chosen_max_hp: int = game.get("max_hp")
			_click(reward_rect.get_center())
			_key(KEY_1)
			check(game.get("blessings").size() == owned_before + 1 and game.get("gold") == chosen_gold and game.get("max_hp") == chosen_max_hp, "Repeated card clicks and number shortcuts cannot grant another blessing")
			_click(_center("PRIMARY_RECT"))
			check(game.get("phase") == "prepare" and int(game.get("wave")) == encounter + 2, "Reward button advances the route")
	check(game.get("phase") == "won" and int(game.get("wave")) == 5, "Five encounters reach the final victory state")
	check(game.get("blessings").size() == 4, "The UI campaign acquires exactly four journey blessings")
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

func _test_menu_save_load() -> void:
	_reset()
	var original_path: String = ui.get("checkpoint_path")
	ui.set("checkpoint_path", TEST_CHECKPOINT)
	Save.delete_save(TEST_CHECKPOINT)
	ui.set("_persistence_enabled", true)
	_drag_shop(0, Vector2i(4, 0))
	var saved_items: Array = _items().duplicate(true)
	var saved_gold: int = game.get("gold")
	_click(_center("MENU_RECT"))
	_click(_center("MENU_SAVE"))
	var saved_info: Dictionary = Save.inspect_save(TEST_CHECKPOINT)
	check(saved_info.get("ok", false) and saved_info.get("gold") == saved_gold and saved_info.get("item_count") == saved_items.size(), "Menu Save writes a real validated checkpoint at an isolated project test path")
	var saved_text: String = FileAccess.get_file_as_string(TEST_CHECKPOINT)
	_click(_center("MENU_CONTINUE"))
	game.set("gold", 77)
	game.set("hp", 37)
	game.call("move", _items()[0]["uid"], Vector2i(2, 2))
	_click(_center("MENU_RECT"))
	_click(_center("MENU_LOAD"))
	check(not bool(ui.get("menu_open")) and game.get("gold") == saved_gold and game.get("hp") == 100 and _items() == saved_items, "Menu Load restores currency, health, and layout after in-memory changes")
	check(Dictionary(ui.get("drag")).is_empty() and ui.get("selected_uid") == -1, "Loading clears stale item selection and held-item state")
	game.set("gold", 66)
	_click(_center("MENU_RECT"))
	ui.set("_resume_prompt", true)
	_key(KEY_S)
	check(FileAccess.get_file_as_string(TEST_CHECKPOINT) == saved_text and bool(ui.get("menu_open")), "S cannot overwrite a saved run while the resume prompt is active")
	_click(_center("MENU_SAVE"))
	check(FileAccess.get_file_as_string(TEST_CHECKPOINT) == saved_text and game.get("gold") == 66, "Clicking the disabled resume Save button preserves the existing checkpoint")
	_click(_center("MENU_CONTINUE"))
	check(not bool(ui.get("menu_open")) and not bool(ui.get("_resume_prompt")) and game.get("gold") == saved_gold, "Resume Continue loads the previous journey instead of the temporary initial state")
	_click(_center("PRIMARY_RECT"))
	ui.call("_process", 0.25)
	_click(_center("MENU_RECT"))
	var before_disabled_save: String = FileAccess.get_file_as_string(TEST_CHECKPOINT)
	_click(_center("MENU_SAVE"))
	check(game.get("phase") == "battle" and FileAccess.get_file_as_string(TEST_CHECKPOINT) == before_disabled_save, "Disabled battle Save cannot replace the pre-battle checkpoint")
	var before_restart_gold: int = game.get("gold")
	_click(_center("MENU_NEW"))
	check(bool(ui.get("_confirm_new_run")) and bool(ui.get("menu_open")) and game.get("phase") == "battle" and game.get("gold") == before_restart_gold, "First New Journey click only requests confirmation")
	_click(_center("MENU_NEW"))
	check(not bool(ui.get("menu_open")) and not bool(ui.get("_confirm_new_run")) and game.get("phase") == "prepare" and game.get("gold") == 18 and _items().size() == 3, "Second New Journey click confirms and starts a fresh run")
	check(Save.inspect_save(TEST_CHECKPOINT).get("gold", -1) == 18, "Confirmed new journey saves its fresh preparation state")
	ui.set("_persistence_enabled", false)
	Save.delete_save(TEST_CHECKPOINT)
	ui.set("checkpoint_path", original_path)
	_reset()

func _test_checkpoint_failure_protection() -> void:
	_reset()
	var original_path: String = ui.get("checkpoint_path")
	Save.delete_save(CORRUPT_CHECKPOINT)
	Save.delete_save(BLOCKED_CHECKPOINT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CORRUPT_CHECKPOINT).get_base_dir())
	var corrupt_bytes: PackedByteArray = '{"schema_version":1,"items":[broken'.to_utf8_buffer()
	var corrupt_file := FileAccess.open(CORRUPT_CHECKPOINT, FileAccess.WRITE)
	if corrupt_file == null:
		check(false, "Corrupt-checkpoint fixture can be written in the isolated project directory")
		return
	corrupt_file.store_buffer(corrupt_bytes)
	corrupt_file.close()
	ui.set("checkpoint_path", CORRUPT_CHECKPOINT)
	ui.set("_persistence_enabled", true)
	game.set("gold", 66)
	ui.call("_offer_saved_run")
	check(bool(ui.get("menu_open")) and bool(ui.get("_resume_prompt")), "An existing corrupt checkpoint still opens the protected startup resume menu")
	check(not Dictionary(ui.get("_save_info")).get("ok", true) and Dictionary(ui.get("_save_info")).get("exists", false), "Startup distinguishes a corrupt existing checkpoint from an absent save")
	_key(KEY_S)
	check(FileAccess.get_file_as_bytes(CORRUPT_CHECKPOINT) == corrupt_bytes, "Resume S preserves the exact bytes of a corrupt existing checkpoint")
	_click(_center("MENU_CONTINUE"))
	check(bool(ui.get("menu_open")) and bool(ui.get("_resume_prompt")) and game.get("gold") == 66, "Failed corrupt-checkpoint Continue keeps the protected menu and current state")
	_click(_center("MENU_NEW"))
	check(bool(ui.get("_confirm_new_run")) and FileAccess.get_file_as_bytes(CORRUPT_CHECKPOINT) == corrupt_bytes, "First New Journey confirmation preserves the corrupt record byte for byte")
	_click(_center("MENU_NEW"))
	check(not bool(ui.get("menu_open")) and not bool(ui.get("_resume_prompt")) and Save.inspect_save(CORRUPT_CHECKPOINT).get("ok", false) and game.get("gold") == 18, "Second New Journey confirmation replaces the corrupt record with a valid fresh checkpoint")
	ui.set("checkpoint_path", BLOCKED_CHECKPOINT)
	check(bool(ui.call("_save_checkpoint", false)), "Save-failure fixture starts from a valid existing preparation checkpoint")
	var before_failed_save: PackedByteArray = FileAccess.get_file_as_bytes(BLOCKED_CHECKPOINT)
	var blocked_temporary: String = ProjectSettings.globalize_path(BLOCKED_CHECKPOINT + ".tmp")
	check(DirAccess.make_dir_recursive_absolute(blocked_temporary) == OK, "An isolated directory can block the checkpoint temporary-file path")
	_click(_center("PRIMARY_RECT"))
	check(game.get("phase") == "prepare" and is_zero_approx(float(game.get("battle_time"))), "A failed pre-battle checkpoint prevents the primary button from starting combat")
	check(not bool(ui.get("toast_good")) and not str(ui.get("toast_text")).is_empty() and str(ui.get("_save_status")).contains("失败"), "Pre-battle save failure retains visible error feedback")
	check(FileAccess.get_file_as_bytes(BLOCKED_CHECKPOINT) == before_failed_save, "Failed pre-battle checkpoint leaves the previous saved bytes untouched")
	check(DirAccess.remove_absolute(blocked_temporary) == OK, "Blocked temporary-path fixture is removed after the save-failure check")
	# A directory deterministically exercises deletion failure without relying on OS file-lock semantics.
	var delete_directory: String = ProjectSettings.globalize_path(DELETE_FAILURE_DIRECTORY)
	check(DirAccess.make_dir_recursive_absolute(delete_directory) == OK, "An isolated directory can model a checkpoint deletion failure")
	ui.set("checkpoint_path", DELETE_FAILURE_DIRECTORY)
	ui.set("_save_info", {"ok": true, "wave": 99})
	ui.call("_clear_checkpoint")
	check(DirAccess.dir_exists_absolute(delete_directory) and str(ui.get("_save_status")).contains("失败") and not bool(ui.get("toast_good")), "Failed checkpoint deletion preserves the target and reports failure instead of successful cleanup")
	check(not Dictionary(ui.get("_save_info")).get("ok", true), "Failed checkpoint deletion refreshes stale cached save metadata")
	ui.set("_persistence_enabled", false)
	Save.delete_save(CORRUPT_CHECKPOINT)
	Save.delete_save(BLOCKED_CHECKPOINT)
	check(DirAccess.remove_absolute(delete_directory) == OK and not Save.exists(CORRUPT_CHECKPOINT) and not Save.exists(BLOCKED_CHECKPOINT), "Checkpoint-protection regression fixtures are fully cleaned from the project test directory")
	ui.set("checkpoint_path", original_path)
	_reset()
