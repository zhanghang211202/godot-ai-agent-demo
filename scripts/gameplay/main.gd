class_name EmberGame
extends Control

const Run = preload("res://scripts/gameplay/run_state.gd")
const Art = preload("res://scripts/visuals/pixel_art.gd")
const Save = preload("res://scripts/gameplay/run_save.gd")
const GRID_ORIGIN := Vector2(101, 478)
const CELL_SIZE := 76.0
const BAG_RECT := Rect2(32, 393, 598, 468)
const MARKET_RECT := Rect2(650, 393, 408, 468)
const NOTES_RECT := Rect2(1078, 393, 330, 468)
const BATTLE_RECT := Rect2(32, 103, 1018, 268)
const PRIMARY_RECT := Rect2(1040, 880, 368, 56)
const REFRESH_RECT := Rect2(909, 411, 129, 34)
const SELL_RECT := Rect2(445, 811, 160, 30)
const MENU_RECT := Rect2(566, 31, 232, 31)
const MENU_CONTINUE := Rect2(490, 337, 460, 48)
const MENU_SAVE := Rect2(490, 401, 460, 48)
const MENU_LOAD := Rect2(490, 465, 460, 48)
const MENU_NEW := Rect2(490, 529, 460, 48)
const BG := Color("101b1c")
const PANEL := Color("18282a")
const PANEL_EDGE := Color("3b504c")
const TEXT := Color("e8e6d2")
const MUTED := Color("94a8a0")
const GOLD := Color("e4bd76")
const TEAL := Color("83c6ad")
const RED := Color("e78d82")
const MONSTERS := ["slime", "wolf", "goblin", "boss", "boss"]
const LEVEL_NAMES := ["普通", "精良", "史诗"]
const LEVEL_COLORS := [Color("91b4aa"), Color("91b9e6"), Color("ecc276")]

var game: EmberRun = Run.new()
var font: Font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
var background: Texture2D = preload("res://assets/art/forest_background.png")
var mouse := Vector2.ZERO
var press_position := Vector2.ZERO
var drag: Dictionary = {}
var click_picked := false
var selected_uid := -1
var hover_kind := ""
var recipes_open := false
var recipe_page := 0
var help_open := false
var menu_open := false
var _resume_prompt := false
var _confirm_new_run := false
var _persistence_enabled := DisplayServer.get_name() != "headless"
var checkpoint_path := "user://emberpack-run.json"
var _save_info: Dictionary = {}
var _save_status := "整装与战利品阶段自动保存"
var muted := false
var speed := 1.0
var elapsed := 0.0
var hero_lunge := 0.0
var enemy_lunge := 0.0
var hero_flash := 0.0
var enemy_flash := 0.0
var merge_glow := 0.0
var toast_text := "拖动两把短剑叠在一起，试试你的第一次合成。"
var toast_time := 8.0
var toast_good := true
var floating: Array[Dictionary] = []
var item_flashes: Dictionary = {}
var battle_log: Array[String] = []
var _screenshot_path := ""
var _screenshot_frames := 0
var _auto_quit := false
var _result_delay := 0.0
var _sound_player: AudioStreamPlayer

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	RenderingServer.set_default_clear_color(BG)
	_sound_player = AudioStreamPlayer.new()
	_sound_player.volume_db = -22.0
	add_child(_sound_player)
	for argument in OS.get_cmdline_user_args():
		if argument == "--no-save" or argument == "--auto-quit" or argument.begins_with("--screenshot="):
			_persistence_enabled = false
		if argument.begins_with("--screenshot="):
			_screenshot_path = argument.trim_prefix("--screenshot=")
		if argument == "--auto-quit":
			_auto_quit = true
		if argument == "--demo-battle":
			game.buy(0, Vector2i(3, 0))
			game.buy(1, Vector2i(2, 2))
			game.move(int(game.items[1]["uid"]), Vector2i(0, 0))
			game.start_battle()
	if "--demo-reward" in OS.get_cmdline_user_args():
		game.buy(0, Vector2i(3, 0))
		game.buy(1, Vector2i(2, 2))
		game.move(int(game.items[1]["uid"]), Vector2i(0, 0))
		game.start_battle()
		while game.phase == "battle":
			game.tick(0.5)
	if "--demo-forge" in OS.get_cmdline_user_args():
		game.move(int(game.items[1]["uid"]), Vector2i(0, 0))
		game.move(int(game.item_at(Vector2i(0, 2))["uid"]), Vector2i(0, 0), true)
		game.buy(3, Vector2i(0, 0))
		game.buy(0, Vector2i(3, 0))
		game.buy(1, Vector2i(3, 0))
		game.buy(2, Vector2i(1, 3))
		selected_uid = int(game.item_at(Vector2i(0, 0))["uid"])
		recipes_open = true
		recipe_page = 1
		_toast("用初始的 18 金币，也能合成两件进阶装备。")
	if "--demo-menu" in OS.get_cmdline_user_args():
		menu_open = true
	if _persistence_enabled:
		_offer_saved_run()
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	hero_lunge = move_toward(hero_lunge, 0.0, delta * 5.0)
	enemy_lunge = move_toward(enemy_lunge, 0.0, delta * 5.0)
	hero_flash = maxf(0.0, hero_flash - delta * 4.0)
	enemy_flash = maxf(0.0, enemy_flash - delta * 4.0)
	merge_glow = maxf(0.0, merge_glow - delta)
	toast_time = maxf(0.0, toast_time - delta)
	_result_delay = maxf(0.0, _result_delay - delta)
	for uid in item_flashes:
		item_flashes[uid] = maxf(0.0, float(item_flashes[uid]) - delta * 1.6)
	for number in floating:
		number["age"] += delta
	floating = floating.filter(func(number: Dictionary) -> bool: return number["age"] < 1.15)
	if not help_open and not menu_open:
		for event in game.tick(delta * speed):
			_battle_event(event)
	if not _screenshot_path.is_empty():
		_screenshot_frames += 1
		if _screenshot_frames == 45:
			_capture.call_deferred()
	queue_redraw()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(_screenshot_path)
	print("EMBERPACK_SCREENSHOT ", _screenshot_path, " result=", error)
	if _auto_quit:
		get_tree().quit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_move(event.position)
	elif event is InputEventMouseButton:
		mouse = event.position
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press(event.position)
			else:
				_release(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			drag.clear()
			click_picked = false
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if help_open:
		if event.keycode == KEY_ESCAPE:
			help_open = false
		return
	if menu_open:
		match event.keycode:
			KEY_ESCAPE:
				if _resume_prompt:
					_load_checkpoint()
				else:
					menu_open = false
			KEY_S:
				_save_checkpoint(false)
			KEY_L:
				_load_checkpoint()
		return
	if game.phase == "reward" and not game.reward_chosen and event.keycode in [KEY_1, KEY_2, KEY_3]:
		_choose_blessing(int(event.keycode) - int(KEY_1))
		return
	match event.keycode:
		KEY_R:
			_rotate_drag()
		KEY_ESCAPE:
			if not drag.is_empty():
				drag.clear()
				click_picked = false
			else:
				_open_menu()
		KEY_SPACE:
			_primary_action()
		KEY_D, KEY_DELETE:
			_sell_selected()
		KEY_M:
			muted = not muted
		KEY_TAB:
			recipes_open = not recipes_open
	queue_redraw()

func _mouse_move(position: Vector2) -> void:
	mouse = position

func _press(position: Vector2) -> void:
	mouse = position
	press_position = position
	if help_open:
		help_open = false
		return
	if menu_open:
		_menu_press(position)
		return
	if MENU_RECT.has_point(position):
		_open_menu()
		return
	if Rect2(1314, 29, 94, 36).has_point(position):
		help_open = true
		return
	if Rect2(1210, 29, 88, 36).has_point(position):
		muted = not muted
		return
	if game.phase == "reward" and not game.reward_chosen:
		for index in range(game.reward_choices.size()):
			if _reward_rect(index).has_point(position):
				_choose_blessing(index)
				return
		if PRIMARY_RECT.has_point(position):
			_toast("先从三张卡片中选择一个旅途祝福。", false)
		return
	if PRIMARY_RECT.has_point(position):
		_primary_action()
		return
	if Rect2(952, 117, 80, 28).has_point(position):
		speed = 2.0 if speed == 1.0 else 1.0
		return
	if Rect2(1244, 411, 144, 34).has_point(position):
		recipes_open = not recipes_open
		return
	if recipes_open:
		if Rect2(1101, 810, 55, 30).has_point(position):
			recipe_page = posmod(recipe_page - 1, _recipe_page_count())
			return
		if Rect2(1330, 810, 55, 30).has_point(position):
			recipe_page = posmod(recipe_page + 1, _recipe_page_count())
			return
	if REFRESH_RECT.has_point(position):
		_apply_result(game.reroll())
		return
	if SELL_RECT.has_point(position):
		_sell_selected()
		return
	if not drag.is_empty() and click_picked:
		_drop(position)
		return
	if game.phase != "prepare":
		return
	var cell := _cell_at(position)
	if _in_grid(cell):
		var item: Dictionary = game.item_at(cell)
		if not item.is_empty():
			selected_uid = int(item["uid"])
			drag = item.duplicate(true)
			drag["source"] = "bag"
			drag["offset"] = cell - Vector2i(item["pos"])
			recipes_open = false
		return
	for index in range(4):
		if _shop_rect(index).has_point(position) and not game.shop_offers[index].is_empty():
			var kind: String = game.shop_offers[index]
			if game.gold < int(game.get_definition(kind)["cost"]):
				_toast("金币不足。可以先出售装备，或出发赚取奖励。", false)
				return
			drag = {"source": "shop", "offer_index": index, "kind": kind, "level": 1, "pos": Vector2i(-9, -9), "rotated": false, "uid": -100 - index, "offset": Vector2i.ZERO}
			selected_uid = -1
			recipes_open = false
			return

func _release(position: Vector2) -> void:
	mouse = position
	if drag.is_empty() or click_picked:
		return
	if position.distance_to(press_position) < 5.0:
		if drag["source"] == "shop":
			click_picked = true
			_toast("在背包里点击放下；按 R 旋转，右键取消。")
		else:
			drag.clear()
		return
	_drop(position)

func _drop(position: Vector2) -> void:
	var cell := _cell_at(position) - Vector2i(drag.get("offset", Vector2i.ZERO))
	var result: Dictionary
	if drag["source"] == "bag" and SELL_RECT.has_point(position):
		result = game.sell(int(drag["uid"]))
	elif _in_grid(_cell_at(position)):
		if drag["source"] == "shop":
			result = game.buy(int(drag["offer_index"]), cell, bool(drag["rotated"]))
		else:
			result = game.move(int(drag["uid"]), cell, bool(drag["rotated"]))
	else:
		result = {"ok": false, "message": "已取消放置，物品和金币都保留。"}
	if result.get("ok", false) and _in_grid(cell):
		var placed := game.item_at(cell)
		if not placed.is_empty():
			selected_uid = int(placed["uid"])
	drag.clear()
	click_picked = false
	_apply_result(result)

func _rotate_drag() -> void:
	if not drag.is_empty():
		drag["rotated"] = not bool(drag["rotated"])
		drag["offset"] = Vector2i.ZERO
		_tone(420.0, 0.04)
	elif selected_uid >= 0 and game.phase == "prepare":
		var item := game.item_by_uid(selected_uid)
		if not item.is_empty():
			_apply_result(game.move(selected_uid, item["pos"], not item["rotated"]))

func _sell_selected() -> void:
	if selected_uid >= 0:
		_apply_result(game.sell(selected_uid))
		selected_uid = -1
		drag.clear()
	else:
		_toast("先点击背包里的装备，再出售。", false)

func _primary_action() -> void:
	drag.clear()
	click_picked = false
	match game.phase:
		"prepare":
			battle_log.clear()
			if not _save_checkpoint():
				return
			_apply_result(game.start_battle())
		"reward":
			_apply_result(game.claim_reward())
			selected_uid = -1
		"won", "lost":
			game.new_run(randi())
			selected_uid = -1
			battle_log.clear()
			floating.clear()
			_toast("新的旅程，新的构筑。整理好行囊再出发吧。")
			_tone(523.0, 0.14)
			_save_checkpoint()

func _apply_result(result: Dictionary) -> void:
	var ok: bool = result.get("ok", false)
	_toast(str(result.get("message", "")), ok)
	if ok:
		match str(result.get("event", "")):
			"merge":
				merge_glow = 1.0
				_tone(784.0, 0.22)
			"buy", "sell", "reroll":
				_tone(590.0, 0.08)
			"battle":
				_tone(330.0, 0.2)
		_save_checkpoint()
	else:
		_tone(160.0, 0.07)

func _battle_event(event: Dictionary) -> void:
	var amount: int = int(event.get("amount", 0))
	match str(event["type"]):
		"hero_attack":
			hero_lunge = 1.0
			enemy_flash = 1.0
			var critical: bool = event.get("critical", false)
			_float_text(("暴击 " if critical else "") + str(amount), Vector2(824, 231), GOLD if critical else TEXT)
			item_flashes[int(event.get("uid", event.get("source_uid", -1)))] = 1.0
			battle_log.push_front("%s造成 %d 点伤害" % ["暴击！" if critical else "装备攻击", amount])
			_tone(390.0 if critical else 250.0, 0.035)
		"enemy_attack":
			enemy_lunge = 1.0
			hero_flash = 1.0
			_float_text("−" + str(amount), Vector2(223, 234), RED)
			battle_log.push_front("%s攻击，受到 %d 点伤害" % [game.enemy_name, amount])
		"heal", "potion":
			_float_text("+" + str(amount), Vector2(243, 224), TEAL)
			_tone(630.0, 0.07)
		"reflect":
			enemy_flash = 0.7
			_float_text("反伤 " + str(amount), Vector2(807, 254), TEAL)
			battle_log.push_front("苔刺反击，造成 %d 点伤害" % amount)
		"victory":
			_result_delay = 0.25
			_float_text("胜利  +%d 金币" % game.last_reward, Vector2(541, 211), GOLD)
			_toast("战斗胜利！获得 %d 金币，休息恢复 18 点生命。" % game.last_reward)
			_tone(784.0, 0.3)
			if game.phase == "won":
				_clear_checkpoint()
			else:
				_save_checkpoint()
		"defeat":
			_toast("旅程暂告一段落。试试升级护盾，搭配月露草再挑战。", false)
			_tone(150.0, 0.35)
			_clear_checkpoint()
	if battle_log.size() > 4:
		battle_log.resize(4)

func _float_text(text: String, position: Vector2, color: Color) -> void:
	floating.append({"text": text, "pos": position, "color": color, "age": 0.0})

func _toast(text: String, good: bool = true) -> void:
	toast_text = text
	toast_time = 5.0
	toast_good = good

func _open_menu() -> void:
	drag.clear()
	click_picked = false
	_confirm_new_run = false
	_resume_prompt = false
	_refresh_save_info()
	menu_open = true

func _refresh_save_info() -> void:
	if _persistence_enabled:
		_save_info = Save.inspect_save(checkpoint_path)
		_save_info["exists"] = Save.exists(checkpoint_path)

func _offer_saved_run() -> void:
	_refresh_save_info()
	if _save_info.get("exists", false):
		menu_open = true
		_resume_prompt = true

func _save_checkpoint(silent: bool = true) -> bool:
	if not _persistence_enabled:
		if not silent:
			_toast("测试或截图模式不写入真实存档。")
		return true
	if _resume_prompt:
		if not silent:
			_toast("先继续上次远征，或确认开始新的远征。", false)
		return false
	if game.phase not in ["prepare", "reward"]:
		if not silent:
			_toast("战斗前已留存整装记录。战斗结束后可以再次保存。", false)
		return false
	var result: Dictionary = Save.save_run(game, checkpoint_path)
	if result.get("ok", false):
		_save_status = "已保存 · 第 %d / 5 场 · %d 金币" % [game.wave, game.gold]
		_refresh_save_info()
	else:
		_save_status = "自动保存失败，可在菜单中重试"
	if not silent or not result.get("ok", false):
		_toast(str(result.get("message", "保存失败。")), result.get("ok", false))
	return bool(result.get("ok", false))

func _load_checkpoint() -> void:
	if not _persistence_enabled:
		_toast("测试或截图模式不读取真实存档。", false)
		return
	var result: Dictionary = Save.load_run(game, checkpoint_path)
	if result.get("ok", false):
		menu_open = false
		_resume_prompt = false
		selected_uid = -1
		drag.clear()
		floating.clear()
		battle_log.clear()
		_result_delay = 0.0
		_refresh_save_info()
	else:
		_save_status = str(result.get("message", "无法读取存档。"))
	_toast(str(result.get("message", "读取失败。")), result.get("ok", false))

func _clear_checkpoint() -> void:
	if _persistence_enabled:
		var result: Dictionary = Save.delete_save(checkpoint_path)
		if result.get("ok", false):
			_save_info.clear()
			_save_status = "本段旅程已结束"
		else:
			_refresh_save_info()
			_save_status = "存档清理失败，旧记录仍保留"
			_toast(str(result.get("message", "无法清理旧存档，请在重开前检查。")), false)

func _menu_press(position: Vector2) -> void:
	if MENU_CONTINUE.has_point(position):
		if _resume_prompt:
			_load_checkpoint()
		else:
			menu_open = false
	elif MENU_SAVE.has_point(position):
		_save_checkpoint(false)
	elif MENU_LOAD.has_point(position):
		_load_checkpoint()
	elif MENU_NEW.has_point(position):
		if not _confirm_new_run:
			_confirm_new_run = true
			return
		game.new_run(randi())
		menu_open = false
		_resume_prompt = false
		_confirm_new_run = false
		selected_uid = -1
		battle_log.clear()
		floating.clear()
		_toast("一只背包，一场新的冒险。")
		_save_checkpoint()

func _reward_rect(index: int) -> Rect2:
	return Rect2(327 + index * 270, 350, 246, 206)

func _choose_blessing(index: int) -> void:
	_apply_result(game.choose_reward(index))
	_tone(880.0, 0.2)

func _recipe_page_count() -> int:
	return ceili(float(Run.RECIPES.size() + 1) / 2.0)

func _tone(frequency: float, duration: float) -> void:
	if muted or not is_instance_valid(_sound_player):
		return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := int(22050 * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for index in samples:
		var phase_value: float = float(index) / 22050.0
		var envelope: float = pow(1.0 - float(index) / float(samples), 2.0)
		var value: int = int((sin(TAU * frequency * phase_value) + sin(TAU * frequency * 2.0 * phase_value) * 0.18) * envelope * 8000.0)
		data.encode_s16(index * 2, value)
	stream.data = data
	_sound_player.stream = stream
	_sound_player.play()

func _cell_at(position: Vector2) -> Vector2i:
	var p := (position - GRID_ORIGIN) / CELL_SIZE
	return Vector2i(floori(p.x), floori(p.y))

func _in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < 6 and cell.y < 4

func _shop_rect(index: int) -> Rect2:
	return Rect2(670 + (index % 2) * 192, 462 + (index / 2) * 171, 176, 155)

func _item_rect(item: Dictionary) -> Rect2:
	return Rect2(GRID_ORIGIN + Vector2(item["pos"]) * CELL_SIZE + Vector2(4, 4), Vector2(game.get_item_size(item)) * CELL_SIZE - Vector2(8, 8))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	_draw_background_details()
	_draw_header()
	_draw_battle()
	_draw_route()
	_draw_backpack()
	_draw_market()
	_draw_notes()
	_draw_footer()
	_draw_blessing_hover()
	if not drag.is_empty():
		_draw_drag()
	if game.phase in ["reward", "won", "lost"] and _result_delay <= 0.0:
		_draw_result()
	if help_open:
		_draw_help()
	if menu_open:
		_draw_menu()

func _draw_background_details() -> void:
	for x in range(0, 1440, 48):
		for y in range(0, 960, 48):
			draw_rect(Rect2(x + 23, y + 23, 2, 2), Color(0.7, 0.8, 0.7, 0.025))
	draw_line(Vector2(32, 84), Vector2(1408, 84), PANEL_EDGE, 1.0)

func _draw_header() -> void:
	_icon("backpack", Rect2(34, 22, 42, 44))
	_label("星火旅囊", Vector2(88, 48), 28, TEXT)
	_label("E M B E R P A C K", Vector2(90, 69), 10, GOLD)
	_label("整理行囊，向未知出发。", Vector2(281, 49), 15, MUTED)
	_button(MENU_RECT, "旅途菜单   /   Esc", false, 13)
	_icon("coin", Rect2(1060, 33, 26, 26))
	_label(str(game.gold), Vector2(1098, 54), 24, GOLD)
	_label("金币", Vector2(1141, 53), 12, MUTED)
	_button(Rect2(1210, 29, 88, 36), "静音" if muted else "音效 开", false, 13)
	_button(Rect2(1314, 29, 94, 36), "玩法  ?", false, 13)

func _draw_battle() -> void:
	var image_size := background.get_size()
	var crop_height: float = image_size.x * BATTLE_RECT.size.y / BATTLE_RECT.size.x
	var crop_y: float = clampf(image_size.y * 0.75 - crop_height * 0.88, 0.0, image_size.y - crop_height)
	draw_texture_rect_region(background, BATTLE_RECT, Rect2(0, crop_y, image_size.x, crop_height))
	draw_rect(BATTLE_RECT, Color(0.02, 0.08, 0.08, 0.19))
	draw_rect(Rect2(32, 103, 1018, 91), Color(0.02, 0.07, 0.07, 0.42))
	draw_rect(BATTLE_RECT, PANEL_EDGE, false, 2.0)
	_label("雾松古道", Vector2(52, 131), 12, Color("c5d2b6"))
	_label("Ⅰ  ·  逐光之旅", Vector2(52, 151), 11, Color("a6b8a3"))
	_button(Rect2(952, 117, 80, 28), "× %.0f" % speed, false, 13)
	_label("旅人 · 阿烬", Vector2(84, 198), 16, TEXT)
	_label(game.enemy_name, Vector2(766, 198), 16, TEXT)
	_health_bar(Rect2(84, 209, 228, 12), game.hp, game.max_hp, TEAL)
	_health_bar(Rect2(766, 209, 228, 12), game.enemy_hp, game.enemy_max_hp, RED)
	_label("%d / %d" % [game.hp, game.max_hp], Vector2(85, 239), 12, TEXT)
	_label("%d / %d" % [maxi(0, game.enemy_hp), game.enemy_max_hp], Vector2(767, 239), 12, TEXT)
	var mode_text := "整 装 待 发"
	if game.phase == "battle":
		mode_text = "自 动 战 斗  ·  %.1fs" % game.battle_time
	elif game.phase in ["reward", "won"]:
		mode_text = "胜 利 归 来"
	elif game.phase == "lost":
		mode_text = "旅 途 未 尽"
	_frame(Rect2(405, 119, 258, 31), Color(0.04, 0.13, 0.12, 0.85), Color("748270"))
	_center(mode_text, Rect2(405, 119, 258, 31), 12, TEXT)
	var hero_position := Vector2(157 + hero_lunge * 45.0, 225 + sin(elapsed * 3.1) * 2.0)
	var enemy_position := Vector2(768 - enemy_lunge * 43.0, 229 + sin(elapsed * 2.7 + 2.0) * 3.0)
	draw_ellipse_shadow(Vector2(240, 345), Vector2(70, 12))
	draw_ellipse_shadow(Vector2(848, 345), Vector2(72, 12))
	var hero_tint := Color.WHITE.lerp(Color("ffd4c4"), hero_flash)
	var enemy_tint := Color.WHITE.lerp(Color("ffdfbe"), enemy_flash)
	if game.phase == "lost":
		hero_tint = Color("7a8981")
	if game.enemy_hp <= 0:
		enemy_tint.a = 0.3
	draw_texture_rect(Art.character("hero"), Rect2(hero_position, Vector2(168, 144)), false, hero_tint)
	var enemy_kind: String = MONSTERS[clampi(game.wave - 1, 0, 4)]
	var enemy_size := Vector2(166, 142) if game.wave < 4 else Vector2(188, 162)
	if game.wave >= 4:
		enemy_position -= Vector2(6, 20)
	draw_texture_rect(Art.character(enemy_kind), Rect2(enemy_position, enemy_size), false, enemy_tint)
	if hero_lunge > 0.3:
		draw_arc(Vector2(300, 302), 45, -1.2, 1.0, 12, Color(1.0, 0.9, 0.65, hero_lunge), 4.0)
	if enemy_lunge > 0.3:
		draw_line(Vector2(784, 290), Vector2(754, 316), Color(1.0, 0.7, 0.5, enemy_lunge), 3.0)
	for i in range(14):
		var firefly := Vector2(70 + fmod(float(i) * 79.0 + elapsed * (5.0 + i % 3), 930.0), 260 + sin(elapsed * 0.5 + i * 2.1) * 55.0)
		draw_rect(Rect2(firefly, Vector2(2, 2)), Color(0.95, 0.9, 0.55, 0.32 + sin(elapsed * 2.0 + i) * 0.22))
	for number in floating:
		var color: Color = number["color"]
		color.a = minf(1.0, (1.15 - float(number["age"])) * 2.0)
		var p: Vector2 = number["pos"] - Vector2(0, float(number["age"]) * 54.0)
		_label(str(number["text"]), p + Vector2(1, 2), 23, Color(0.0, 0.0, 0.0, color.a * 0.8))
		_label(str(number["text"]), p, 23, color)

func _draw_route() -> void:
	_frame(Rect2(1070, 103, 338, 268))
	_label("C H A P T E R   0 1", Vector2(1094, 133), 11, GOLD)
	for index in range(game.blessings.size()):
		var blessing: Dictionary = game.get_blessing_definition(game.blessings[index])
		_icon(str(blessing.get("icon", "spark")), Rect2(1254 + index * 31, 114, 25, 25))
	_label("雾松遗迹", Vector2(1093, 170), 26, TEXT)
	_label(str(game.get_enemy_info().get("trait", "越过古道，寻找不熄的星火。")), Vector2(1094, 197), 12, MUTED)
	draw_line(Vector2(1113, 230), Vector2(1363, 230), Color("40594e"), 2.0)
	for index in range(5):
		var point := Vector2(1114 + index * 61, 230)
		var complete: bool = index < game.wave - 1
		var active: bool = index == game.wave - 1
		draw_circle(point, 13, GOLD if complete else (Color("d7c58f") if active else Color("293e37")))
		draw_circle(point, 13, Color("71816a") if active else Color("486353"), false, 1.0)
		_center(str(index + 1), Rect2(point - Vector2(13, 13), Vector2(26, 26)), 11, BG if complete or active else MUTED)
	_label("%02d / 05" % game.wave, Vector2(1096, 269), 18, GOLD)
	_label("旅途祝福 · %d 枚" % game.blessings.size(), Vector2(1234, 268), 12, TEAL if not game.blessings.is_empty() else MUTED)
	draw_line(Vector2(1094, 286), Vector2(1384, 286), PANEL_EDGE, 1.0)
	var stats := game.get_stats()
	_stat("攻击", str(stats["attack"]), Vector2(1097, 313), GOLD)
	_stat("护甲", str(stats["armor"]), Vector2(1193, 313), Color("a4c5d6"))
	_stat("恢复 / 2s", str(stats["regen"]), Vector2(1285, 313), TEAL)

func _draw_backpack() -> void:
	_frame(BAG_RECT)
	_icon("backpack", Rect2(53, 411, 29, 31))
	_label("旅人的背包", Vector2(93, 437), 22, TEXT)
	_label("BACKPACK", Vector2(94, 456), 9, MUTED)
	_frame(Rect2(528, 414, 76, 27), Color("203832"), Color("456353"))
	_center("6 × 4", Rect2(528, 414, 76, 27), 12, TEAL)
	# Leather gusset and stitches keep the grid feeling like a physical bag.
	_frame(Rect2(GRID_ORIGIN - Vector2(13, 13), Vector2(482, 330)), Color("27352e"), Color("6c6a4c"))
	for y in range(4):
		for x in range(6):
			var rect := Rect2(GRID_ORIGIN + Vector2(x, y) * CELL_SIZE + Vector2(3, 3), Vector2(CELL_SIZE - 6, CELL_SIZE - 6))
			draw_rect(rect, Color("172a25"))
			draw_rect(rect, Color("3b5142"), false, 1.0)
			draw_rect(Rect2(rect.position + Vector2(5, 5), Vector2(2, 2)), Color("4b5b45"))
			draw_rect(Rect2(rect.end - Vector2(7, 7), Vector2(2, 2)), Color("4b5b45"))
	var hover_cell := _cell_at(mouse)
	var hovered: Dictionary = game.item_at(hover_cell) if _in_grid(hover_cell) else {}
	var focus_item := game.item_by_uid(selected_uid)
	if not hovered.is_empty():
		focus_item = hovered
	_draw_adjacency(focus_item)
	for item in game.items:
		if not drag.is_empty() and drag["source"] == "bag" and drag["uid"] == item["uid"]:
			_draw_item(item, _item_rect(item), 0.24)
		else:
			_draw_item(item, _item_rect(item), 1.0, item["uid"] == selected_uid or (not hovered.is_empty() and hovered["uid"] == item["uid"]))
	_draw_support_markers()
	if merge_glow > 0.0:
		draw_rect(Rect2(GRID_ORIGIN - Vector2(9, 9), Vector2(474, 322)), Color(0.95, 0.77, 0.36, merge_glow * 0.5), false, 3.0)
	var stats := game.get_stats()
	_icon("spark", Rect2(54, 815, 24, 24))
	_label("%d 组邻接增益" % int(stats["synergy_count"]), Vector2(87, 834), 13, TEAL if stats["synergy_count"] > 0 else MUTED)
	_button(SELL_RECT, "出售选中物品", false, 12, game.phase != "prepare")

func _draw_adjacency(item: Dictionary) -> void:
	if item.is_empty() or item["kind"] not in ["whetstone", "ember"]:
		return
	for cell in game.get_support_cells(item):
		if _in_grid(cell):
			var rect := Rect2(GRID_ORIGIN + Vector2(cell) * CELL_SIZE + Vector2(2, 2), Vector2(72, 72))
			draw_rect(rect, Color(0.5, 0.8, 0.7, 0.12))
			draw_rect(rect, Color(0.5, 0.8, 0.7, 0.65), false, 2.0)

func _draw_support_markers() -> void:
	for support in game.items:
		if support["kind"] not in ["whetstone", "ember"]:
			continue
		var center := GRID_ORIGIN + (Vector2(support["pos"]) + Vector2(0.5, 0.5)) * CELL_SIZE
		for cell in game.get_support_cells(support):
			var cell_center := GRID_ORIGIN + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE
			var direction := (cell_center - center).normalized()
			var marker := center + direction * (CELL_SIZE / 2.0 - 1.0)
			var target := game.item_at(cell)
			var active: bool = not target.is_empty() and game.get_definition(target["kind"])["category"] == "weapon"
			draw_circle(marker, 5.0, Color("142820"))
			draw_circle(marker, 3.0, Color("8dcbea") if active else Color("507886"))

func _draw_item(item: Dictionary, rect: Rect2, opacity: float = 1.0, highlighted: bool = false) -> void:
	var kind: String = item["kind"]
	var level: int = int(item.get("level", 1))
	var rim: Color = LEVEL_COLORS[level - 1]
	var body := Color("29453f")
	if level == 2:
		body = Color("2c4053")
	elif level == 3:
		body = Color("554731")
	body.a = opacity
	rim.a = opacity * (1.0 if highlighted else 0.65)
	draw_rect(rect, body)
	draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), Color(0.4, 0.7, 0.6, opacity * 0.06))
	draw_rect(rect, GOLD if highlighted else rim, false, 2.0)
	draw_line(rect.position + Vector2(3, 3), rect.position + Vector2(rect.size.x - 4, 3), Color(0.9, 0.95, 0.8, opacity * 0.18), 1.0)
	var icon_size: float = minf(67.0, minf(rect.size.x, rect.size.y) - 7.0)
	var icon_rect := Rect2(rect.get_center() - Vector2(icon_size, icon_size) / 2.0, Vector2(icon_size, icon_size))
	if rect.size.y > rect.size.x * 1.4:
		var height: float = minf(rect.size.y - 28.0, 164.0)
		icon_rect = Rect2(rect.get_center() - Vector2(31, height / 2.0), Vector2(62, height))
	if rect.size.x > rect.size.y * 1.4:
		var width: float = minf(rect.size.x - 28.0, 164.0)
		icon_rect = Rect2(rect.get_center() - Vector2(width / 2.0, 31), Vector2(width, 62))
	_item_icon(item, icon_rect, Color(1, 1, 1, opacity))
	if level > 1:
		_label("Ⅱ" if level == 2 else "Ⅲ", rect.position + Vector2(7, 18), 12, rim)
	if game.get_adjacency_bonus(item) > 0:
		draw_circle(rect.end - Vector2(11, 11), 4.0, Color(TEAL, opacity))
	if game.phase == "battle" and game.get_definition(kind)["category"] == "weapon":
		var progress: float = game.get_weapon_cooldown_progress(int(item.get("uid", -1)))
		draw_rect(Rect2(rect.position + Vector2(4, rect.size.y - 7), Vector2(rect.size.x - 8, 3)), Color("14231f"))
		draw_rect(Rect2(rect.position + Vector2(4, rect.size.y - 7), Vector2((rect.size.x - 8) * progress, 3)), GOLD)
	var flash: float = float(item_flashes.get(item.get("uid", -1), 0.0))
	if flash > 0.0:
		draw_rect(rect, Color(0.98, 0.9, 0.55, flash * 0.26))
	if highlighted:
		for corner in [rect.position, Vector2(rect.end.x - 4, rect.position.y), rect.end - Vector2(4, 4), Vector2(rect.position.x, rect.end.y - 4)]:
			draw_rect(Rect2(corner - Vector2(1, 1), Vector2(5, 5)), GOLD)

func _draw_market() -> void:
	_frame(MARKET_RECT)
	_label("林间补给", Vector2(672, 437), 22, TEXT)
	_label("TRAVELING MERCHANT", Vector2(673, 456), 9, MUTED)
	_button(REFRESH_RECT, "刷新  %d 金" % game.reroll_cost, false, 12, game.phase != "prepare")
	for index in range(4):
		var rect := _shop_rect(index)
		var kind: String = game.shop_offers[index]
		if kind.is_empty():
			_frame(rect, Color("152422"), Color("2c4038"))
			_center("已收入行囊", Rect2(rect.position + Vector2(0, 54), Vector2(rect.size.x, 35)), 13, Color("546b5d"))
			continue
		var definition := game.get_definition(kind)
		var hover: bool = rect.has_point(mouse) and game.phase == "prepare"
		_frame(rect, Color("293a33") if hover else Color("20322e"), GOLD if hover else Color("46594b"))
		_icon(kind, Rect2(rect.position + Vector2(56, 9), Vector2(64, 64)))
		_center(str(definition["name"]), Rect2(rect.position + Vector2(6, 77), Vector2(rect.size.x - 12, 24)), 14, TEXT)
		var item_size: Vector2i = definition["size"]
		_label("%d × %d" % [item_size.x, item_size.y], rect.position + Vector2(12, 133), 11, MUTED)
		_icon("coin", Rect2(rect.position + Vector2(110, 116), Vector2(20, 20)))
		_label(str(definition["cost"]), rect.position + Vector2(137, 133), 16, GOLD if game.gold >= int(definition["cost"]) else RED)
	_label("点击选购，再点击背包空格放置。", Vector2(673, 836), 12, MUTED)

func _draw_notes() -> void:
	_frame(NOTES_RECT)
	_label("行囊手记", Vector2(1100, 437), 21, TEXT)
	_button(Rect2(1244, 411, 144, 34), "装备详情" if recipes_open else "合成图鉴  ↗", false, 12)
	if recipes_open:
		_draw_recipes()
		return
	var item: Dictionary = _inspected_item()
	if item.is_empty():
		item = {"kind": "sword", "level": 1, "uid": -1, "pos": Vector2i(-9, -9), "rotated": false}
	var definition := game.get_definition(str(item["kind"]))
	var level: int = int(item.get("level", 1))
	_frame(Rect2(1101, 465, 78, 78), Color("233e35"), LEVEL_COLORS[level - 1])
	_item_icon(item, Rect2(1108, 472, 64, 64))
	_label(str(definition["name"]), Vector2(1195, 490), 18, TEXT)
	_label(LEVEL_NAMES[level - 1] + "  ·  " + _category_name(str(definition["category"])), Vector2(1195, 515), 12, LEVEL_COLORS[level - 1])
	var item_size := game.get_item_size(item)
	_label("占用 %d × %d 格" % [item_size.x, item_size.y], Vector2(1195, 538), 11, MUTED)
	_wrapped(str(definition["description"]), Rect2(1101, 567, 284, 75), 14, TEXT)
	draw_line(Vector2(1101, 653), Vector2(1385, 653), PANEL_EDGE, 1.0)
	if definition["category"] == "weapon":
		var damage: int = game.get_weapon_damage(item)
		_label("每次攻击", Vector2(1101, 687), 13, MUTED)
		_label(str(damage), Vector2(1327, 689), 24, GOLD)
		var bonus: int = game.get_adjacency_bonus(item)
		_label("相邻增益", Vector2(1101, 721), 13, MUTED)
		_label("+%d 攻击" % bonus, Vector2(1284, 721), 14, TEAL)
	else:
		_label("整理提示", Vector2(1101, 687), 13, GOLD)
		var hint := "磨刀石只强化蓝点方向；按 R 将左右切换为上下。" if item["kind"] == "whetstone" else "蓝点标示生效格。留意装备形状，为下一次合成腾出空间。"
		_wrapped(hint, Rect2(1101, 704, 281, 48), 13, MUTED)
	_frame(Rect2(1101, 768, 284, 72), Color("23342d"), Color("425542"))
	if game.phase == "battle" and not battle_log.is_empty():
		_label("战况手记", Vector2(1115, 792), 12, GOLD)
		_label(battle_log[0], Vector2(1115, 819), 12, TEXT)
	else:
		_icon("spark", Rect2(1113, 781, 23, 23))
		_label("合成小贴士", Vector2(1145, 800), 13, GOLD)
		_label("同种同级叠放，合成更高一级。", Vector2(1115, 824), 12, MUTED)

func _draw_recipes() -> void:
	_label("五条进阶路线，让小行囊大有不同。", Vector2(1101, 480), 12, MUTED)
	for row in range(2):
		var index: int = recipe_page * 2 + row
		if index == 0:
			_recipe_row("sword", "sword", "sword", "同种同级 → 提升品质", 500 + row * 134, true)
		elif index - 1 < Run.RECIPES.size():
			var recipe: Dictionary = Run.RECIPES[index - 1]
			var title: String = str(recipe["label"]) + " · " + str(game.get_definition(recipe["result"])["name"])
			_recipe_row(recipe["first"], recipe["second"], recipe["result"], title, 500 + row * 134, false)
	_wrapped("叠放材料即时合成；产物需要足够空间，拖动时可预览占格。", Rect2(1101, 767, 282, 38), 12, MUTED)
	_button(Rect2(1101, 810, 55, 30), "←", false, 15)
	_center("%d / %d" % [recipe_page + 1, _recipe_page_count()], Rect2(1158, 810, 168, 30), 12, GOLD)
	_button(Rect2(1330, 810, 55, 30), "→", false, 15)

func _recipe_row(first: String, second: String, result: String, title: String, y: float, upgrade: bool) -> void:
	_frame(Rect2(1101, y, 284, 119), Color("20332d"), Color("465b46"))
	_icon(first, Rect2(1112, y + 12, 53, 53))
	_label("+", Vector2(1172, y + 46), 18, MUTED)
	_icon(second, Rect2(1193, y + 12, 53, 53))
	_label("→", Vector2(1252, y + 46), 18, GOLD)
	_icon(result, Rect2(1291, y + 9, 61, 61))
	if upgrade:
		_label("Ⅱ", Vector2(1355, y + 30), 14, GOLD)
	_label(title, Vector2(1113, y + 100), 12, TEXT)

func _inspected_item() -> Dictionary:
	if not drag.is_empty():
		return drag
	var cell := _cell_at(mouse)
	if _in_grid(cell):
		var item := game.item_at(cell)
		if not item.is_empty():
			return item
	for index in range(4):
		if _shop_rect(index).has_point(mouse) and not game.shop_offers[index].is_empty():
			return {"kind": game.shop_offers[index], "level": 1, "uid": -1, "pos": Vector2i(-9, -9), "rotated": false}
	return game.item_by_uid(selected_uid)

func _draw_footer() -> void:
	var color := TEAL if toast_good else RED
	if toast_time > 0.0:
		draw_rect(Rect2(32, 879, 985, 55), Color("20312a") if toast_good else Color("3b2b28"))
		draw_rect(Rect2(32, 879, 3, 55), color)
		_label(toast_text, Vector2(49, 912), 13, color)
	else:
		_label("拖放整理   /   R 旋转   /   D 出售   /   空格 出发   /   右键 取消", Vector2(36, 912), 13, MUTED)
	var button_label := "整装出发   →"
	if game.phase == "battle":
		button_label = "战斗进行中  ·  %.1fs" % game.battle_time
	elif game.phase == "reward":
		button_label = "领取补给，继续旅程   →" if game.reward_chosen else "先选择一个旅途祝福"
	elif game.phase == "won":
		button_label = "再开始一段旅程   ↻"
	elif game.phase == "lost":
		button_label = "重新整理行囊   ↻"
	_button(PRIMARY_RECT, button_label, true, 18, game.phase == "battle" or (game.phase == "reward" and not game.reward_chosen))
	_label(_save_status if _persistence_enabled else "一只背包，一段未知的旅程。", Vector2(34, 950), 10, Color("60796c"))
	_label("EMBERPACK  /  PLAYABLE DEMO 0.2", Vector2(1113, 950), 9, Color("60796c"))

func _draw_drag() -> void:
	var item_size := game.get_item_size(drag)
	var offset: Vector2i = drag.get("offset", Vector2i.ZERO)
	var cell := _cell_at(mouse) - offset
	if _in_grid(_cell_at(mouse)):
		var target := game.item_at(cell)
		var has_recipe: bool = not target.is_empty() and not game.get_merge_result(drag, target).is_empty()
		var merging: bool = has_recipe and game.can_merge(drag, target)
		var allowed: bool = game.can_place(drag, cell, int(drag.get("uid", -1))) or merging
		var preview := Rect2(GRID_ORIGIN + Vector2(cell) * CELL_SIZE + Vector2(3, 3), Vector2(item_size) * CELL_SIZE - Vector2(6, 6))
		if merging:
			var product: Dictionary = game.get_merge_preview(drag, target)
			preview = Rect2(GRID_ORIGIN + Vector2(product["pos"]) * CELL_SIZE + Vector2(3, 3), Vector2(game.get_item_size(product)) * CELL_SIZE - Vector2(6, 6))
		draw_rect(preview, Color(0.7, 0.9, 0.7, 0.18) if allowed else Color(0.9, 0.3, 0.25, 0.24))
		draw_rect(preview, GOLD if merging else (TEAL if allowed else RED), false, 2.0)
		if merging:
			_label("可合成  ✦", preview.position + Vector2(4, -9), 14, GOLD)
		elif has_recipe:
			_label("合成空间不足", preview.position + Vector2(4, -9), 13, RED)
	var display_size := Vector2(item_size) * CELL_SIZE - Vector2(8, 8)
	var origin := mouse - Vector2(offset) * CELL_SIZE - Vector2(30, 30)
	_draw_item(drag, Rect2(origin, display_size), 0.87, true)
	_frame(Rect2(mouse + Vector2(17, display_size.y + 5), Vector2(142, 29)), Color("162720"), GOLD)
	_center("R 旋转  /  右键取消", Rect2(mouse + Vector2(17, display_size.y + 5), Vector2(142, 29)), 11, TEXT)

func _draw_result() -> void:
	if game.phase == "reward" and not game.reward_chosen:
		_draw_reward_choices()
		return
	var won: bool = game.phase == "won"
	var lost: bool = game.phase == "lost"
	var rect := Rect2(364, 238, 510, 118)
	_frame(rect, Color(0.06, 0.14, 0.11, 0.95), RED if lost else GOLD)
	_center("抵达星火之地" if won else ("火光未熄，旅途未尽" if lost else "这一程，平安归来"), Rect2(374, 246, 490, 45), 25, RED if lost else GOLD)
	var line := "五场远征全部完成！你的行囊已足以照亮森林。" if won else ("强化护盾与恢复能力，再来一次。" if lost else "祝福已收入行囊 · 下一波 %d / 5" % [game.wave + 1])
	_center(line, Rect2(374, 298, 490, 27), 13, TEXT)
	_center("点击右下按钮，或按空格继续", Rect2(374, 326, 490, 20), 11, MUTED)

func _draw_reward_choices() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1440, 865)), Color(0.01, 0.05, 0.035, 0.72))
	_frame(Rect2(291, 231, 858, 382), Color("1c3029"), GOLD)
	_center("林间的馈赠", Rect2(326, 249, 788, 48), 30, GOLD)
	_center("胜利获得 %d 金币 · 选择一枚祝福，陪伴接下来的旅程" % game.last_reward, Rect2(326, 303, 788, 29), 14, TEXT)
	for index in range(game.reward_choices.size()):
		var id: String = game.reward_choices[index]
		var blessing: Dictionary = game.get_blessing_definition(id)
		var rect := _reward_rect(index)
		var hovered: bool = rect.has_point(mouse)
		_frame(rect, Color("34503c") if hovered else Color("243e32"), GOLD if hovered else Color("58745b"))
		_label("0%d" % [index + 1], rect.position + Vector2(14, 26), 13, GOLD)
		_icon(str(blessing.get("icon", "spark")), Rect2(rect.position + Vector2(89, 19), Vector2(68, 68)))
		_center(str(blessing.get("name", id)), Rect2(rect.position + Vector2(8, 89), Vector2(230, 35)), 20, TEXT)
		_wrapped(str(blessing.get("description", "")), Rect2(rect.position + Vector2(22, 135), Vector2(202, 52)), 14, MUTED)
	_center("点击卡片，或按 1 / 2 / 3 选择 · 每场战斗只能领取一次", Rect2(327, 574, 786, 24), 12, MUTED)

func _draw_menu() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1440, 960)), Color(0.01, 0.05, 0.035, 0.88))
	_frame(Rect2(444, 210, 552, 475), Color("1c3029"), GOLD)
	_center("火光尚在，旅途待续", Rect2(480, 234, 480, 48), 28, GOLD)
	var subtitle := "歇一歇，听听林间的风。"
	if _resume_prompt:
		subtitle = "找到第 %d 场的整装记录，可以继续上一次远征。" % int(_save_info.get("wave", 1)) if _save_info.get("ok", false) else "现有记录暂时无法读取，确认后才能开始新远征。"
	_center(subtitle, Rect2(480, 290, 480, 27), 13, MUTED)
	var continue_label := "继续上次远征   →" if _resume_prompt else "返回当前旅程   →"
	if _resume_prompt and not _save_info.get("ok", false):
		continue_label = "原记录无法读取，请选择新远征"
	_button(MENU_CONTINUE, continue_label, true, 17, _resume_prompt and not _save_info.get("ok", false))
	_button(MENU_SAVE, "保存当前整装   S", false, 16, game.phase not in ["prepare", "reward"] or _resume_prompt)
	var load_text := "读取存档 · 第 %d 场 / %d 金币   L" % [int(_save_info.get("wave", 1)), int(_save_info.get("gold", 0))] if _save_info.get("ok", false) else "尚未留下整装记录"
	_button(MENU_LOAD, load_text, false, 15, not _save_info.get("ok", false))
	_button(MENU_NEW, "再次点击，确认重新出发" if _confirm_new_run else "开始新的远征", false, 16)
	var record_hint: String = str(_save_info.get("message", "")) if _resume_prompt and not _save_info.get("ok", false) else "战斗中退出会回到开战前的整装记录。"
	_center(record_hint, Rect2(480, 599, 480, 24), 12, RED if _resume_prompt and not _save_info.get("ok", false) else MUTED)
	_center("准备与战利品阶段自动保存 · Esc 返回", Rect2(480, 630, 480, 24), 12, TEAL)
	_center(_save_status, Rect2(480, 657, 480, 20), 11, RED if "失败" in _save_status or "无法" in _save_status else MUTED)

func _draw_blessing_hover() -> void:
	if menu_open or help_open or (game.phase == "reward" and not game.reward_chosen):
		return
	for index in range(game.blessings.size()):
		if Rect2(1252 + index * 31, 112, 29, 29).has_point(mouse):
			var blessing: Dictionary = game.get_blessing_definition(game.blessings[index])
			_frame(Rect2(1054, 148, 354, 112), Color("21392e"), GOLD)
			_label(str(blessing.get("name", "旅途祝福")), Vector2(1074, 180), 18, GOLD)
			_wrapped(str(blessing.get("description", "")), Rect2(1074, 196, 314, 48), 14, TEXT)
			return

func _draw_help() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1440, 960)), Color(0.01, 0.04, 0.03, 0.86))
	_frame(Rect2(320, 160, 800, 625), Color("1b3029"), GOLD)
	_center("每一格，都有新的可能", Rect2(350, 199, 740, 54), 30, GOLD)
	_center("五波森林远征 · 背包构筑与自动战斗", Rect2(350, 263, 740, 30), 15, MUTED)
	var instructions := [
		["01", "购买与摆放", "拖动商店装备到背包；也可以点击选购，再点击空格。"],
		["02", "旋转与整理", "按 R 旋转选中的装备；点击装备查看属性，D 出售。"],
		["03", "合成与协同", "同种同级叠放可升级；短剑 + 磨刀石能合成长剑。"],
		["04", "方向与空间", "蓝点决定磨刀石加成方向，R 可旋转；长剑需要三格空间。"],
		["05", "祝福与旅途记录", "胜利后选择祝福，空格继续。Esc 打开菜单，随时歇脚。"],
	]
	for index in range(instructions.size()):
		var y: float = 338 + index * 76
		_label(instructions[index][0], Vector2(366, y), 22, GOLD)
		_label(instructions[index][1], Vector2(425, y), 18, TEXT)
		_label(instructions[index][2], Vector2(425, y + 28), 14, MUTED)
	_center("点击任意位置关闭  /  Esc", Rect2(360, 736, 720, 27), 13, TEAL)

func _category_name(category: String) -> String:
	return {"weapon": "武器", "armor": "防具", "healing": "恢复", "support": "辅助"}.get(category, category)

func _frame(rect: Rect2, fill: Color = PANEL, edge: Color = PANEL_EDGE) -> void:
	draw_rect(Rect2(rect.position + Vector2(0, 4), rect.size), Color(0.0, 0.0, 0.0, 0.16))
	draw_rect(rect, fill)
	draw_rect(rect, edge, false, 1.0)
	draw_rect(Rect2(rect.position, Vector2(4, 4)), edge)
	draw_rect(Rect2(rect.end - Vector2(4, 4), Vector2(4, 4)), edge)

func _label(text: String, position: Vector2, font_size: int = 14, color: Color = TEXT) -> void:
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _center(text: String, rect: Rect2, font_size: int = 14, color: Color = TEXT) -> void:
	var baseline: float = rect.position.y + (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	draw_string(font, Vector2(rect.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, color)

func _wrapped(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var line := ""
	var y: float = rect.position.y + font_size
	for character in text:
		if font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x:
			_label(line, Vector2(rect.position.x, y), font_size, color)
			y += font_size + 9
			line = ""
		line += character
	if not line.is_empty():
		_label(line, Vector2(rect.position.x, y), font_size, color)

func _button(rect: Rect2, text: String, primary: bool = false, font_size: int = 14, disabled: bool = false) -> void:
	var hovered: bool = rect.has_point(mouse) and not disabled
	var fill := Color("dec084") if primary else Color("263e34")
	var edge := GOLD if primary else Color("506653")
	var ink := Color("263326") if primary else TEXT
	if hovered:
		fill = fill.lightened(0.12)
		edge = Color("ffe0a1")
	if disabled:
		fill = Color("2e4038")
		edge = Color("4c5b49")
		ink = MUTED
	_frame(rect, fill, edge)
	if primary and not disabled:
		draw_line(rect.position + Vector2(3, 3), Vector2(rect.end.x - 3, rect.position.y + 3), Color("f9e1ae"), 1.0)
	_center(text, rect, font_size, ink)

func _icon(kind: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
	draw_texture_rect(Art.icon(kind), rect, false, tint)

func _item_icon(item: Dictionary, rect: Rect2, tint: Color = Color.WHITE) -> void:
	if item.get("rotated", false):
		draw_set_transform(rect.get_center(), PI / 2.0)
		draw_texture_rect(Art.icon(str(item["kind"])), Rect2(-Vector2(rect.size.y, rect.size.x) / 2.0, Vector2(rect.size.y, rect.size.x)), false, tint)
		draw_set_transform(Vector2.ZERO)
	else:
		_icon(str(item["kind"]), rect, tint)

func _health_bar(rect: Rect2, value: int, maximum: int, color: Color) -> void:
	draw_rect(Rect2(rect.position - Vector2(1, 1), rect.size + Vector2(2, 2)), Color("14221c"))
	draw_rect(rect, Color("29382e"))
	var ratio: float = clampf(float(value) / maxf(1.0, float(maximum)), 0.0, 1.0)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), color)
	draw_rect(Rect2(rect.position + Vector2(0, 1), Vector2(rect.size.x * ratio, 2)), color.lightened(0.2))

func _stat(title: String, value: String, position: Vector2, color: Color) -> void:
	_label(title, position, 11, MUTED)
	_label(value, position + Vector2(0, 33), 25, color)

func draw_ellipse_shadow(center: Vector2, radius: Vector2) -> void:
	var points := PackedVector2Array()
	for index in range(28):
		var angle: float = TAU * float(index) / 28.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, Color(0.02, 0.08, 0.05, 0.3))
