class_name EmberGame
extends Control

const Run = preload("res://scripts/gameplay/run_state.gd")
const Art = preload("res://scripts/visuals/pixel_art_v03.gd")
const Materials = preload("res://scripts/ui/ember_theme.gd")
const Layout = preload("res://scripts/ui/ember_layout.gd")
const Forest = preload("res://scripts/ui/forest_stage.gd")
const BackpackView = preload("res://scripts/ui/backpack_view.gd")
const MarketView = preload("res://scripts/ui/market_view.gd")
const JournalView = preload("res://scripts/ui/journal_view.gd")
const OverlayView = preload("res://scripts/ui/overlay_view.gd")
const Save = preload("res://scripts/gameplay/run_save.gd")
var layout = Layout.new()
var GRID_ORIGIN := Vector2.ZERO
var CELL_SIZE := 64.0
var BAG_RECT: Rect2
var MARKET_RECT: Rect2
var NOTES_RECT: Rect2
var BATTLE_RECT: Rect2
var PRIMARY_RECT: Rect2
var REFRESH_RECT: Rect2
var SELL_RECT: Rect2
var MENU_RECT: Rect2
var MENU_CONTINUE: Rect2
var MENU_SAVE: Rect2
var MENU_LOAD: Rect2
var MENU_NEW: Rect2
const BG = Materials.BG
const PANEL = Materials.PANEL
const PANEL_EDGE = Materials.PANEL_EDGE
const TEXT = Materials.TEXT
const MUTED = Materials.MUTED
const GOLD = Materials.GOLD
const TEAL = Materials.TEAL
const RED = Materials.RED
const MONSTERS := ["slime", "wolf", "goblin", "boss", "boss"]
const LEVEL_NAMES := ["普通", "精良", "史诗"]
const LEVEL_COLORS := [Color("91b4aa"), Color("91b9e6"), Color("ecc276")]

var game: EmberRun = Run.new()
var font: Font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
var background: Texture2D = Forest.texture()
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
var hero_clip := "idle"
var enemy_clip := "idle"
var hero_clip_time := 0.0
var enemy_clip_time := 0.0
var effects: Array[Dictionary] = []
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
var _demo_drag := false
var _result_delay := 0.0
var _sound_player: AudioStreamPlayer

func _ready() -> void:
	get_window().min_size = Vector2i(1280, 800)
	resized.connect(_update_layout)
	_update_layout()
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
	if "--demo-drag" in OS.get_cmdline_user_args():
		_demo_drag = true
		_press(_shop_rect(0).get_center())
		_mouse_move(GRID_ORIGIN + Vector2(4.5, 1.5) * CELL_SIZE)
	if _persistence_enabled:
		_offer_saved_run()
	queue_redraw()

func _process(delta: float) -> void:
	if not help_open and not menu_open:
		var dt: float = delta * speed if game.phase == "battle" else delta
		elapsed += dt
		hero_clip_time += dt
		enemy_clip_time += dt
		if hero_clip in ["attack", "hurt"] and hero_clip_time >= (0.3 if hero_clip == "attack" else 0.16):
			hero_clip = "idle"
			hero_clip_time = 0.0
		if enemy_clip in ["attack", "hurt"] and enemy_clip_time >= (0.3 if enemy_clip == "attack" else 0.16):
			enemy_clip = "idle"
			enemy_clip_time = 0.0
		hero_lunge = move_toward(hero_lunge, 0.0, dt * 5)
		enemy_lunge = move_toward(enemy_lunge, 0.0, dt * 5)
		hero_flash = maxf(0, hero_flash - dt * 4)
		enemy_flash = maxf(0, enemy_flash - dt * 4)
		merge_glow = maxf(0, merge_glow - dt)
		toast_time = maxf(0, toast_time - delta)
		_result_delay = maxf(0, _result_delay - dt)
		for uid in item_flashes:
			item_flashes[uid] = maxf(0, float(item_flashes[uid]) - dt * 1.6)
		for number in floating:
			number["age"] += dt
		floating = floating.filter(func(number: Dictionary) -> bool: return number["age"] < 1.15)
		for effect in effects:
			effect["age"] += dt
		effects = effects.filter(func(effect: Dictionary) -> bool: return effect["age"] < 0.45)
		for event in game.tick(delta * speed):
			_battle_event(event)
	if not _screenshot_path.is_empty():
		if _demo_drag:
			mouse = GRID_ORIGIN + Vector2(4.5, 1.5) * CELL_SIZE
		_screenshot_frames += 1
		if _screenshot_frames == 90:
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
	if layout.header_help_rect.has_point(position):
		help_open = true
		return
	if layout.header_sound_rect.has_point(position):
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
	if layout.speed_rect.has_point(position):
		speed = 2.0 if speed == 1.0 else 1.0
		return
	if layout.recipe_toggle_rect.has_point(position):
		recipes_open = not recipes_open
		return
	if recipes_open:
		if layout.recipe_prev_rect.has_point(position):
			recipe_page = posmod(recipe_page - 1, _recipe_page_count())
			return
		if layout.recipe_next_rect.has_point(position):
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
			_reset_visuals()
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
				_reset_visuals()
				_tone(330.0, 0.2)
			"prepare":
				_reset_visuals()
		_save_checkpoint()
	else:
		_tone(160.0, 0.07)

func _battle_event(event: Dictionary) -> void:
	var amount: int = int(event.get("amount", 0))
	var feet := _stage_feet()
	match str(event["type"]):
		"hero_attack":
			var source: Dictionary = game.item_by_uid(int(event.get("uid", event.get("source_uid", -1))))
			var kind: String = source.get("kind", "sword")
			hero_lunge = 0.0 if kind in ["bow", "windbow"] else 1.0
			hero_clip = "attack"
			hero_clip_time = 0.0
			enemy_clip = "hurt"
			enemy_clip_time = 0.0
			effects.append({"kind": "arrow" if kind in ["bow", "windbow"] else ("fire_slash" if kind == "flame_sword" else "slash"), "age": 0.0})
			enemy_flash = 1.0
			var critical: bool = event.get("critical", false)
			_float_text(("暴击 " if critical else "") + str(amount), feet[1] - Vector2(25, 80), GOLD if critical else TEXT)
			item_flashes[int(event.get("uid", event.get("source_uid", -1)))] = 1.0
			battle_log.push_front("%s造成 %d 点伤害" % ["暴击！" if critical else "装备攻击", amount])
			_tone(390.0 if critical else 250.0, 0.035)
		"enemy_attack":
			enemy_lunge = 1.0
			enemy_clip = "attack"
			enemy_clip_time = 0.0
			hero_clip = "hurt"
			hero_clip_time = 0.0
			effects.append({"kind": "enemy", "age": 0.0})
			hero_flash = 1.0
			_float_text("−" + str(amount), feet[0] - Vector2(25, 85), RED)
			battle_log.push_front("%s攻击，受到 %d 点伤害" % [game.enemy_name, amount])
		"heal", "potion":
			effects.append({"kind": "heal", "age": 0.0})
			_float_text("+" + str(amount), feet[0] - Vector2(25, 90), TEAL)
			_tone(630.0, 0.07)
		"reflect":
			effects.append({"kind": "reflect", "age": 0.0})
			enemy_flash = 0.7
			_float_text("反伤 " + str(amount), feet[1] - Vector2(30, 60), TEAL)
			battle_log.push_front("苔刺反击，造成 %d 点伤害" % amount)
		"victory":
			enemy_clip = "defeat"
			enemy_clip_time = 0.0
			_result_delay = 0.25
			_float_text("胜利  +%d 金币" % game.last_reward, BATTLE_RECT.get_center() - Vector2(80, 20), GOLD)
			_toast("战斗胜利！获得 %d 金币，休息恢复 18 点生命。" % game.last_reward)
			_tone(784.0, 0.3)
			if game.phase == "won":
				_clear_checkpoint()
			else:
				_save_checkpoint()
		"defeat":
			hero_clip = "defeat"
			hero_clip_time = 0.0
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
		_reset_visuals()
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
		_reset_visuals()
		menu_open = false
		_resume_prompt = false
		_confirm_new_run = false
		selected_uid = -1
		battle_log.clear()
		floating.clear()
		_toast("一只背包，一场新的冒险。")
		_save_checkpoint()

func _reward_rect(index: int) -> Rect2:
	return layout.reward_rect(index)

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
	return layout.shop_rect(index)

func _item_rect(item: Dictionary) -> Rect2:
	return Rect2(GRID_ORIGIN + Vector2(item["pos"]) * CELL_SIZE, Vector2(game.get_item_size(item)) * CELL_SIZE)

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
	for x in range(24, int(size.x), 48):
		for y in range(20, int(size.y), 48):
			draw_rect(Rect2(x, y, 2, 2), Color(0.7, 0.8, 0.7, 0.035))
	draw_line(Vector2(24, 78), Vector2(size.x - 24, 78), PANEL_EDGE, 1)

func _draw_header() -> void:
	_icon("backpack", Rect2(28, 18, 48, 48))
	_label("星火旅囊", Vector2(90, 43), 28, TEXT)
	_label("E M B E R P A C K   /   雾松篇", Vector2(92, 65), 11, GOLD)
	if size.x >= 1400:
		_label("把一格，留给下一次可能。", Vector2(300, 44), 16, MUTED)
	_button(MENU_RECT, "旅途菜单  /  Esc", false, 15)
	_icon("coin", Rect2(size.x - 400, 28, 32, 32))
	_label(str(game.gold), Vector2(size.x - 356, 54), 26, GOLD)
	_label("金币", Vector2(size.x - 309, 51), 14, MUTED)
	_button(layout.header_sound_rect, "静音" if muted else "音效 开", false, 15)
	_button(layout.header_help_rect, "玩法  ?", false, 15)

func _draw_battle() -> void:
	var r: Rect2 = BATTLE_RECT
	var scale_value: int = layout.art_scale
	var source_size := Vector2(floorf(r.size.x / scale_value), floorf(r.size.y / scale_value))
	var source_origin := Vector2(floorf((background.get_width() - source_size.x) / 2.0), 144 - source_size.y)
	draw_texture_rect_region(background, Rect2(r.position, source_size * scale_value), Rect2(source_origin, source_size))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 78)), Color(0.025, 0.08, 0.07, 0.73))
	draw_rect(r, Color("78816a"), false, 2)
	var feet := _stage_feet()
	draw_ellipse_shadow(feet[0], Vector2(37, 6) * scale_value / 2.0)
	draw_ellipse_shadow(feet[1], Vector2(34, 6) * scale_value / 2.0)
	var hero_texture: Texture2D = Art.character("hero", hero_clip, hero_clip_time)
	var hero_position: Vector2 = (feet[0] - Art.character_pivot("hero") * scale_value + Vector2(hero_lunge * 10, 0)).snapped(Vector2.ONE * scale_value)
	draw_texture_rect(hero_texture, Rect2(hero_position, hero_texture.get_size() * scale_value), false, Color.WHITE.lerp(Color("ffb596"), hero_flash * 0.5))
	var enemy_kind: String = MONSTERS[clampi(game.wave - 1, 0, 4)]
	var enemy_texture: Texture2D = Art.character(enemy_kind, enemy_clip, enemy_clip_time)
	var enemy_position: Vector2 = (feet[1] - Art.character_pivot(enemy_kind) * scale_value - Vector2(enemy_lunge * 10, 0)).snapped(Vector2.ONE * scale_value)
	var enemy_tint := Color.WHITE.lerp(Color("ffd7a0"), enemy_flash * 0.6)
	if game.enemy_hp <= 0 and enemy_kind != "slime":
		enemy_tint.a = 0.3
	draw_texture_rect(enemy_texture, Rect2(enemy_position, enemy_texture.get_size() * scale_value), false, enemy_tint)
	_draw_combat_effects(feet)
	_label("阿烬 · 雾松古道", r.position + Vector2(22, 28), 17, TEXT)
	_label(game.enemy_name, Vector2(r.end.x - 250, r.position.y + 28), 17, TEXT)
	var bar_width: float = minf(224, r.size.x * 0.25)
	_health_bar(Rect2(r.position + Vector2(22, 40), Vector2(bar_width, 10)), game.hp, game.max_hp, TEAL)
	_health_bar(Rect2(r.end.x - 250, r.position.y + 40, bar_width, 10), game.enemy_hp, game.enemy_max_hp, RED)
	_label("%d / %d" % [game.hp, game.max_hp], r.position + Vector2(22, 69), 14, TEXT)
	_label("%d / %d" % [maxi(0, game.enemy_hp), game.enemy_max_hp], Vector2(r.end.x - 250, r.position.y + 69), 14, TEXT)
	var mode := "整 装 待 发"
	if game.phase == "battle":
		mode = "自动战斗  ·  %.1fs" % game.battle_time
	elif game.phase in ["reward", "won"]:
		mode = "胜 利 归 来"
	elif game.phase == "lost":
		mode = "旅 途 未 尽"
	_center(mode, Rect2(r.get_center().x - 115, r.position.y + 17, 230, 36), 16, GOLD)
	_button(layout.speed_rect, "× %.0f" % speed, false, 14)
	for number in floating:
		var color: Color = number["color"]
		color.a = minf(1, (1.15 - float(number["age"])) * 2)
		var p: Vector2 = number["pos"] - Vector2(0, float(number["age"]) * 45)
		_label(number["text"], p + Vector2(2, 2), 24, Color(0.02, 0.06, 0.04, color.a))
		_label(number["text"], p, 24, color)

func _draw_route() -> void:
	var r: Rect2 = layout.route_rect
	Materials.draw_panel(self, r, "dark")
	_label("C H A P T E R   0 1", r.position + Vector2(20, 32), 11, GOLD)
	for i in range(game.blessings.size()):
		var blessing: Dictionary = game.get_blessing_definition(game.blessings[i])
		_icon(blessing.get("icon", "spark"), layout.blessing_rect(i))
	_label("雾松遗迹", r.position + Vector2(20, 70), 26, TEXT)
	_wrapped(game.get_enemy_info().get("trait", ""), Rect2(r.position + Vector2(20, 85), Vector2(r.size.x - 40, 48)), 14, MUTED)
	var node_y: float = r.end.y - 83
	draw_line(Vector2(r.position.x + 33, node_y), Vector2(r.end.x - 33, node_y), PANEL_EDGE, 2)
	for index in range(5):
		var point := Vector2(r.position.x + 33 + index * (r.size.x - 66) / 4.0, node_y)
		var complete: bool = index < game.wave - 1
		var active: bool = index == game.wave - 1
		draw_circle(point, 12, GOLD if complete or active else Color("2a4036"))
		draw_circle(point, 12, Color("a99c6f") if active else Color("5a725b"), false, 1)
		_center(str(index + 1), Rect2(point - Vector2(12, 12), Vector2(24, 24)), 14, BG if complete or active else MUTED)
	var stats := game.get_stats()
	var labels := ["攻击", "护甲", "恢复/2s"]
	var values := [str(stats["attack"]), str(stats["armor"]), str(stats["regen"])]
	for i in range(3):
		var x: float = r.position.x + 22 + i * (r.size.x - 40) / 3.0
		_label(labels[i], Vector2(x, r.end.y - 45), 13, MUTED)
		_label(values[i], Vector2(x, r.end.y - 18), 23, [GOLD, Color("a4c5d6"), TEAL][i])

func _draw_backpack() -> void:
	BackpackView.draw(self)

func _draw_adjacency(item: Dictionary) -> void:
	if item.is_empty() or item["kind"] not in ["whetstone", "ember"]:
		return
	for cell in game.get_support_cells(item):
		if _in_grid(cell):
			var rect := Rect2(GRID_ORIGIN + Vector2(cell) * CELL_SIZE + Vector2(2, 2), Vector2.ONE * (CELL_SIZE - 4))
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
	_item_icon(item, rect, Color(1, 1, 1, opacity))
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
	MarketView.draw(self)

func _draw_notes() -> void:
	JournalView.draw(self)

func _draw_recipes() -> void:
	JournalView.draw_recipes(self)

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
	var r: Rect2 = layout.footer_rect
	if toast_time > 0:
		draw_rect(r, Color("20332b") if toast_good else Color("3b2b28"))
		draw_rect(Rect2(r.position, Vector2(3, r.size.y)), TEAL if toast_good else RED)
		_wrapped(toast_text, Rect2(r.position + Vector2(14, 8), r.size - Vector2(28, 12)), 15, TEAL if toast_good else RED)
	else:
		_wrapped("拖放整理  /  R 旋转  /  D 出售  /  空格 出发", Rect2(r.position + Vector2(4, 10), r.size), 15, MUTED)
	var label := "整装出发    →"
	match game.phase:
		"battle": label = "战斗中  ·  %.1fs" % game.battle_time
		"reward": label = "继续旅程    →" if game.reward_chosen else "先选择一个旅途祝福"
		"won", "lost": label = "重新出发    ↻"
	_button(PRIMARY_RECT, label, true, 20, game.phase == "battle" or (game.phase == "reward" and not game.reward_chosen))
	_label(_save_status if _persistence_enabled else "一只背包，一段未知的旅程。", Vector2(26, size.y - 7), 11, Color("83947c"))
	_label("EMBERPACK / 0.3 ART SAMPLE", Vector2(size.x - 260, size.y - 7), 10, Color("83947c"))

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
	var display_size := Vector2(item_size) * CELL_SIZE
	var origin := mouse - Vector2(offset) * CELL_SIZE - Vector2(30, 30)
	_draw_item(drag, Rect2(origin, display_size), 0.87, true)
	_frame(Rect2(mouse + Vector2(17, display_size.y + 5), Vector2(142, 29)), Color("162720"), GOLD)
	_center("R 旋转  /  右键取消", Rect2(mouse + Vector2(17, display_size.y + 5), Vector2(142, 29)), 11, TEXT)

func _draw_result() -> void:
	OverlayView.result(self)

func _draw_reward_choices() -> void:
	OverlayView.reward(self)

func _draw_menu() -> void:
	OverlayView.menu(self)

func _draw_blessing_hover() -> void:
	if menu_open or help_open or (game.phase == "reward" and not game.reward_chosen):
		return
	for i in range(game.blessings.size()):
		if layout.blessing_rect(i).has_point(mouse):
			var blessing: Dictionary = game.get_blessing_definition(game.blessings[i])
			var r := Rect2(layout.route_rect.position + Vector2(0, 50), Vector2(layout.route_rect.size.x, 116))
			_frame(r, Color("21392e"), GOLD)
			_label(blessing["name"], r.position + Vector2(20, 30), 20, GOLD)
			_wrapped(blessing["description"], Rect2(r.position + Vector2(20, 48), r.size - Vector2(40, 60)), 16, TEXT)
			return

func _draw_help() -> void:
	OverlayView.help(self)

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
		if character == "\n" or font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x:
			_label(line, Vector2(rect.position.x, y), font_size, color)
			y += font_size + 7
			line = ""
			if y > rect.end.y + 1:
				return
		if character != "\n":
			line += character
	if not line.is_empty() and y <= rect.end.y + 1:
		_label(line, Vector2(rect.position.x, y), font_size, color)

func _button(rect: Rect2, text: String, primary: bool = false, font_size: int = 14, disabled: bool = false) -> void:
	Materials.draw_button(self, rect, rect.has_point(mouse), primary, disabled)
	_center(text, rect, font_size, MUTED if disabled else (Color("ffdf9c") if primary else TEXT))

func _icon(kind: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
	var texture: Texture2D = Art.icon(kind)
	var pixel_scale: int = maxi(1, floori(minf(rect.size.x / texture.get_width(), rect.size.y / texture.get_height())))
	var display_size := texture.get_size() * pixel_scale
	draw_texture_rect(texture, Rect2((rect.get_center() - display_size / 2.0).floor(), display_size), false, tint)

func _item_icon(item: Dictionary, rect: Rect2, tint: Color = Color.WHITE) -> void:
	var texture: Texture2D = Art.inventory(item["kind"])
	var source_size := texture.get_size()
	var pixel_scale: int = layout.art_scale
	if item.get("rotated", false):
		draw_set_transform(rect.get_center(), PI / 2.0)
		draw_texture_rect(texture, Rect2(-source_size * pixel_scale / 2.0, source_size * pixel_scale), false, tint)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect(texture, Rect2((rect.get_center() - source_size * pixel_scale / 2.0).floor(), source_size * pixel_scale), false, tint)

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

func _update_layout() -> void:
	layout.update(get_viewport_rect().size)
	background = Forest.texture_for_width(ceili(layout.battle_rect.size.x / layout.art_scale))
	GRID_ORIGIN = layout.grid_origin
	CELL_SIZE = layout.cell_size
	BAG_RECT = layout.bag_rect
	MARKET_RECT = layout.market_rect
	NOTES_RECT = layout.notes_rect
	BATTLE_RECT = layout.battle_rect
	PRIMARY_RECT = layout.primary_rect
	REFRESH_RECT = layout.refresh_rect
	SELL_RECT = layout.sell_rect
	MENU_RECT = layout.menu_rect
	MENU_CONTINUE = layout.menu_continue
	MENU_SAVE = layout.menu_save
	MENU_LOAD = layout.menu_load
	MENU_NEW = layout.menu_new
	queue_redraw()

func get_modal_overlay_rect() -> Rect2:
	return layout.modal_overlay_rect

func _stage_feet() -> Array[Vector2]:
	var pixel_scale: int = layout.art_scale
	var crop_y: float = 144 - floorf(BATTLE_RECT.size.y / pixel_scale)
	var ground: float = BATTLE_RECT.position.y + (Forest.ground_y() - crop_y) * pixel_scale
	return [Vector2(floorf((BATTLE_RECT.position.x + BATTLE_RECT.size.x * 0.23) / pixel_scale) * pixel_scale, ground), Vector2(floorf((BATTLE_RECT.position.x + BATTLE_RECT.size.x * 0.78) / pixel_scale) * pixel_scale, ground)]

func _reset_visuals() -> void:
	hero_clip = "idle"
	enemy_clip = "idle"
	hero_clip_time = 0.0
	enemy_clip_time = 0.0
	hero_lunge = 0.0
	enemy_lunge = 0.0
	hero_flash = 0.0
	enemy_flash = 0.0
	merge_glow = 0.0
	_result_delay = 0.0
	effects.clear()
	item_flashes.clear()
	floating.clear()

func _draw_combat_effects(feet: Array[Vector2]) -> void:
	for effect in effects:
		var age: float = float(effect["age"]) / 0.45
		var alpha: float = 1.0 - age
		var hero: Vector2 = feet[0] - Vector2(0, 57)
		var enemy: Vector2 = feet[1] - Vector2(0, 52)
		match str(effect["kind"]):
			"arrow":
				var point := hero.lerp(enemy, minf(age * 4, 1))
				draw_line(point - Vector2(35, 0), point, Color(0.95, 0.84, 0.58, alpha), 3)
				draw_line(point - Vector2(8, 5), point, Color(1, 0.96, 0.77, alpha), 3)
				draw_line(point - Vector2(8, -5), point, Color(1, 0.96, 0.77, alpha), 3)
			"slash", "fire_slash":
				var c := Color("ffb15b") if effect["kind"] == "fire_slash" else Color("f0e6b0")
				c.a = alpha
				draw_arc(enemy, 32 + age * 16, -1.2, 1.0, 9, c, 5)
			"heal":
				for i in range(5):
					var p := hero + Vector2(-34 + i * 17, -age * 45 + (i % 2) * 14)
					draw_rect(Rect2(p, Vector2(4, 9)), Color(0.55, 0.85, 0.65, alpha))
			"reflect":
				for i in range(5):
					var p := enemy + Vector2((i - 2) * 16, -10 + abs(i - 2) * 12)
					draw_line(p + Vector2(0, 14), p - Vector2(0, 14), Color(0.73, 0.87, 0.61, alpha), 4)
			"enemy":
				draw_line(hero - Vector2(15, 24), hero + Vector2(16, 18), Color(0.95, 0.55, 0.4, alpha), 4)
