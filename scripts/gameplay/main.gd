class_name EmberGame
extends Control

const Run = preload("res://scripts/gameplay/run_state.gd")
const Art = preload("res://scripts/visuals/pixel_art.gd")
const GRID_ORIGIN := Vector2(101, 478)
const CELL_SIZE := 76.0
const BAG_RECT := Rect2(32, 393, 598, 468)
const MARKET_RECT := Rect2(650, 393, 408, 468)
const NOTES_RECT := Rect2(1078, 393, 330, 468)
const BATTLE_RECT := Rect2(32, 103, 1018, 268)
const PRIMARY_RECT := Rect2(1040, 880, 368, 56)
const REFRESH_RECT := Rect2(909, 411, 129, 34)
const SELL_RECT := Rect2(445, 811, 160, 30)
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
var help_open := false
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
		if argument.begins_with("--screenshot="):
			_screenshot_path = argument.trim_prefix("--screenshot=")
		if argument == "--auto-quit":
			_auto_quit = true
		if argument == "--demo-battle":
			game.buy(0, Vector2i(3, 0))
			game.buy(1, Vector2i(2, 2))
			game.move(int(game.items[1]["uid"]), Vector2i(0, 0))
			game.start_battle()
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
	if not help_open:
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
	match event.keycode:
		KEY_R:
			_rotate_drag()
		KEY_ESCAPE:
			drag.clear()
			click_picked = false
			help_open = false
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
	if Rect2(1314, 29, 94, 36).has_point(position):
		help_open = true
		return
	if Rect2(1210, 29, 88, 36).has_point(position):
		muted = not muted
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
		"victory":
			_result_delay = 0.25
			_float_text("胜利  +%d 金币" % game.last_reward, Vector2(541, 211), GOLD)
			_toast("战斗胜利！获得 %d 金币，休息恢复 18 点生命。" % game.last_reward)
			_tone(784.0, 0.3)
		"defeat":
			_toast("旅程暂告一段落。试试升级护盾，搭配月露草再挑战。", false)
			_tone(150.0, 0.35)
	if battle_log.size() > 4:
		battle_log.resize(4)

func _float_text(text: String, position: Vector2, color: Color) -> void:
	floating.append({"text": text, "pos": position, "color": color, "age": 0.0})

func _toast(text: String, good: bool = true) -> void:
	toast_text = text
	toast_time = 5.0
	toast_good = good

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
	if not drag.is_empty():
		_draw_drag()
	if game.phase in ["reward", "won", "lost"] and _result_delay <= 0.0:
		_draw_result()
	if help_open:
		_draw_help()

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
	_frame(Rect2(566, 31, 232, 31), Color("203632"), Color("426254"))
	_center("森林远征   /   可玩原型 01", Rect2(566, 31, 232, 31), 13, TEAL)
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
	_label("雾松遗迹", Vector2(1093, 170), 26, TEXT)
	_label("越过古道，寻找不熄的星火。", Vector2(1094, 197), 13, MUTED)
	draw_line(Vector2(1113, 230), Vector2(1363, 230), Color("40594e"), 2.0)
	for index in range(5):
		var point := Vector2(1114 + index * 61, 230)
		var complete: bool = index < game.wave - 1
		var active: bool = index == game.wave - 1
		draw_circle(point, 13, GOLD if complete else (Color("d7c58f") if active else Color("293e37")))
		draw_circle(point, 13, Color("71816a") if active else Color("486353"), false, 1.0)
		_center(str(index + 1), Rect2(point - Vector2(13, 13), Vector2(26, 26)), 11, BG if complete or active else MUTED)
	_label("%02d / 05" % game.wave, Vector2(1096, 269), 18, GOLD)
	_label("最终首领 · 灰烬树王", Vector2(1184, 268), 12, MUTED)
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
	if merge_glow > 0.0:
		draw_rect(Rect2(GRID_ORIGIN - Vector2(9, 9), Vector2(474, 322)), Color(0.95, 0.77, 0.36, merge_glow * 0.5), false, 3.0)
	var stats := game.get_stats()
	_icon("spark", Rect2(54, 815, 24, 24))
	_label("%d 组邻接增益" % int(stats["synergy_count"]), Vector2(87, 834), 13, TEAL if stats["synergy_count"] > 0 else MUTED)
	_button(SELL_RECT, "出售选中物品", false, 12, game.phase != "prepare")

func _draw_adjacency(item: Dictionary) -> void:
	if item.is_empty() or item["kind"] not in ["whetstone", "ember"]:
		return
	var pos: Vector2i = item["pos"]
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var cell: Vector2i = pos + direction
		if _in_grid(cell):
			var rect := Rect2(GRID_ORIGIN + Vector2(cell) * CELL_SIZE + Vector2(2, 2), Vector2(72, 72))
			draw_rect(rect, Color(0.5, 0.8, 0.7, 0.12))
			draw_rect(rect, Color(0.5, 0.8, 0.7, 0.65), false, 2.0)

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
		icon_rect = Rect2(rect.get_center() - Vector2(31, 52), Vector2(62, 104))
	if rect.size.x > rect.size.y * 1.4:
		icon_rect = Rect2(rect.get_center() - Vector2(51, 31), Vector2(102, 62))
	_icon(kind, icon_rect, Color(1, 1, 1, opacity))
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
	_icon(str(item["kind"]), Rect2(1108, 472, 64, 64))
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
		_wrapped("将辅助装备放在武器上下左右，让每一格都发挥作用。", Rect2(1101, 704, 281, 48), 13, MUTED)
	_frame(Rect2(1101, 768, 284, 72), Color("23342d"), Color("425542"))
	if game.phase == "battle" and not battle_log.is_empty():
		_label("战况手记", Vector2(1115, 792), 12, GOLD)
		_label(battle_log[0], Vector2(1115, 819), 12, TEXT)
	else:
		_icon("spark", Rect2(1113, 781, 23, 23))
		_label("合成小贴士", Vector2(1145, 800), 13, GOLD)
		_label("同种同级叠放，合成更高一级。", Vector2(1115, 824), 12, MUTED)

func _draw_recipes() -> void:
	_label("让小小行囊，装下更多可能。", Vector2(1101, 480), 13, MUTED)
	_recipe_row("sword", "sword", "sword", "同种同级 → 提升品质", 507, true)
	_recipe_row("sword", "whetstone", "longsword", "旅人短剑 + 磨刀石 → 长剑", 645, false)
	_wrapped("将左侧材料拖到另一件装备上即可合成。精良与史诗品质会进一步提高属性。", Rect2(1101, 790, 282, 53), 12, MUTED)

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
		button_label = "领取补给，继续旅程   →"
	elif game.phase == "won":
		button_label = "再开始一段旅程   ↻"
	elif game.phase == "lost":
		button_label = "重新整理行囊   ↻"
	_button(PRIMARY_RECT, button_label, true, 18, game.phase == "battle")
	_label("一只背包，一段未知的旅程。", Vector2(34, 950), 10, Color("60796c"))
	_label("EMBERPACK  /  ORIGINAL PLAYABLE DEMO", Vector2(1086, 950), 9, Color("60796c"))

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
	var won: bool = game.phase == "won"
	var lost: bool = game.phase == "lost"
	var rect := Rect2(364, 238, 510, 118)
	_frame(rect, Color(0.06, 0.14, 0.11, 0.95), RED if lost else GOLD)
	_center("抵达星火之地" if won else ("火光未熄，旅途未尽" if lost else "这一程，平安归来"), Rect2(374, 246, 490, 45), 25, RED if lost else GOLD)
	var line := "五场远征全部完成！你的行囊已足以照亮森林。" if won else ("强化护盾与恢复能力，再来一次。" if lost else "+%d 金币  ·  休息恢复生命  ·  下一波 %d / 5" % [game.last_reward, game.wave + 1])
	_center(line, Rect2(374, 298, 490, 27), 13, TEXT)
	_center("点击右下按钮，或按空格继续", Rect2(374, 326, 490, 20), 11, MUTED)

func _draw_help() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1440, 960)), Color(0.01, 0.04, 0.03, 0.86))
	_frame(Rect2(320, 160, 800, 625), Color("1b3029"), GOLD)
	_center("每一格，都有新的可能", Rect2(350, 199, 740, 54), 30, GOLD)
	_center("五波森林远征 · 背包构筑与自动战斗", Rect2(350, 263, 740, 30), 15, MUTED)
	var instructions := [
		["01", "购买与摆放", "拖动商店装备到背包；也可以点击选购，再点击空格。"],
		["02", "旋转与整理", "按 R 旋转选中的装备；点击装备查看属性，D 出售。"],
		["03", "合成与协同", "同种同级叠放可升级；短剑 + 磨刀石能合成长剑。"],
		["04", "准备好，再出发", "磨刀石和火种强化邻接武器。盾与草药帮助你走得更远。"],
		["05", "让行囊替你战斗", "空格开始自动战斗；胜利后获得金币、恢复生命并继续。"],
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
