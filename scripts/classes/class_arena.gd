extends Control
## C1 static battle-pose candidates over the unchanged C0 event engine.

const Art = preload("res://scripts/classes/class_art.gd")
var run: RefCounted
var battle: RefCounted
var last_event: Dictionary = {}
var flash := 0.0
var font: Font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")

func _ready() -> void:
	custom_minimum_size = Vector2(900, 280)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func show_event(event: Dictionary) -> void:
	if str(event.get("type", "")) in ["spell", "spell_burst", "spell_multi", "attack", "heavy_charge", "charge"]:
		last_event = event
		flash = 0.6
	queue_redraw()

func _process(delta: float) -> void:
	if battle != null and battle.paused:
		return
	if flash > 0:
		flash = maxf(0.0, flash - delta)
		queue_redraw()

func _active_actions() -> Array:
	if run == null:
		return []
	if battle != null and battle.phase != "idle":
		var snapshot: Dictionary = battle.get("_config")
		return snapshot.get("actions", [])
	return run.get_combat_config().get("actions", [])

func _hero_id() -> String:
	if run == null:
		return ""
	if run.class_id == "mage":
		return "mage-idle"
	var has_sword := false
	for action: Dictionary in _active_actions():
		if str(action.get("kind", "")) == "greatblade":
			return "knight-greatblade-idle"
		if str(action.get("kind", "")) == "iron_blade":
			has_sword = true
	return "knight-sword-idle" if has_sword else ""

func get_art_layout() -> Dictionary:
	# This drawing/report query never acquires items or ticks the rules.
	var hero_id := _hero_id()
	var background_id := "moon-court" if run != null and run.class_id == "mage" else "reliquary-hall"
	var hero: Dictionary = Art.get_asset(hero_id)
	var background: Dictionary = Art.get_asset(background_id)
	var scene := Rect2(1, 61, maxf(0, size.x - 2), maxf(0, size.y - 89))
	var background_crop := _background_crop(background, scene)
	var ground := size.y - 29.0
	var anchor := Vector2(roundf(size.x * 0.26), ground)
	var source: Rect2 = hero.get("source_rect", Rect2())
	var destination := Rect2()
	var factor := 0.0
	if source.has_area():
		var desired_height := minf(256.0, scene.size.y - 3.0)
		factor = minf(desired_height / source.size.y, (size.x * 0.34) / source.size.x)
		var extent := source.size * factor
		destination = Rect2(anchor - Vector2(extent.x * 0.5, extent.y), extent)
	var health: Array[Rect2] = [Rect2(16, 12, size.x * 0.30, 8), Rect2(size.x * 0.70 - 16, 12, size.x * 0.30, 8)]
	var phase := Rect2(size.x * 0.33, 8, size.x * 0.34, 43)
	var enemy := Rect2(Vector2(roundf(size.x * 0.76) - 60, ground - 166), Vector2(120, 166))
	var missing: Array[String] = []
	if hero_id != "" and hero.is_empty():
		missing.append(hero_id)
	if background.is_empty():
		missing.append(background_id)
	return {"class_id": str(run.class_id) if run != null else "", "hero_id": hero_id,
		"hero_path": Art.asset_path(hero_id), "background_id": background_id, "background_path": Art.asset_path(background_id),
		"source_size": hero.get("size", Vector2i.ZERO), "source_rect": source, "hero_rect": destination,
		"background_source_size": background.get("size", Vector2i.ZERO), "background_source_rect": background_crop,
		"stage_rect": Rect2(Vector2.ZERO, size), "scene_rect": scene, "ground_anchor": anchor, "ground_y": ground,
		"enemy_rect": enemy, "health_rects": health, "phase_rect": phase,
		"source_scale": Vector2.ONE * factor, "source_scale_is_integer": factor >= 1.0 and is_equal_approx(factor, roundf(factor)),
		"scaling_mode": "aspect-preserving nearest static source-fit experiment; logical sprite grid pending",
		"alpha_threshold": 128, "assets_ready": missing.is_empty(), "missing_assets": missing,
		"hero_visible": destination.has_area(), "animated": false, "enemy_placeholder": true}

func get_art_report() -> Dictionary:
	var layout := get_art_layout()
	var report: Dictionary = {}
	for key in layout:
		var value: Variant = layout[key]
		if value is Rect2:
			report[key] = [value.position.x, value.position.y, value.size.x, value.size.y]
		elif value is Vector2 or value is Vector2i:
			report[key] = [value.x, value.y]
		elif key == "health_rects":
			var bars: Array = []
			for rect: Rect2 in value:
				bars.append([rect.position.x, rect.position.y, rect.size.x, rect.size.y])
			report[key] = bars
		else:
			report[key] = value
	return report

func _draw() -> void:
	if run == null or battle == null:
		return
	var layout := get_art_layout()
	var tint := Color("c0afe8") if run.class_id == "mage" else Color("e5c88c")
	draw_rect(layout.stage_rect, Color("141c2b"))
	_draw_background(layout)
	# A continuous foreground ledge anchors both actors.
	draw_rect(Rect2(1, layout.ground_y, size.x - 2, 8), Color("333748") if run.class_id == "mage" else Color("474036"))
	draw_line(Vector2(1, layout.ground_y), Vector2(size.x - 1, layout.ground_y), Color("9e95af") if run.class_id == "mage" else Color("b2a184"), 1)
	_shadow(layout.ground_anchor, 39, tint)
	_shadow(Vector2(layout.enemy_rect.get_center().x, layout.ground_y), 35, tint)
	var hero: Dictionary = Art.get_asset(layout.hero_id)
	if layout.hero_visible:
		draw_texture_rect_region(hero.texture, layout.hero_rect, layout.source_rect)
	else:
		_center("待配武装" if layout.hero_id == "" else "角色静态稿待载入", layout.ground_anchor - Vector2(0, 55), 16, tint)
	_draw_training_target(layout.enemy_rect, tint)
	_draw_hud(layout, tint)
	var footer_name := "月光观测庭" if run.class_id == "mage" else "余烬圣堂"
	draw_rect(Rect2(1, size.y - 21, size.x - 2, 20), Color("111925"))
	draw_string(font, Vector2(14, size.y - 6), footer_name + " · 静态样板", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b6b4c6"))
	var note := "角色动作待制作 · 训练敌人占位"
	var note_width := font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, Vector2(size.x - note_width - 14, size.y - 6), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b6b4c6"))
	draw_rect(layout.stage_rect, Color("6a6073") if run.class_id == "mage" else Color("78694e"), false, 1)

func _draw_background(layout: Dictionary) -> void:
	var background: Dictionary = Art.get_asset(layout.background_id)
	if background.is_empty():
		return
	var scene: Rect2 = layout.scene_rect
	draw_texture_rect_region(background.texture, scene, layout.background_source_rect)
	draw_rect(scene, Color(0.025, 0.035, 0.065, 0.14))

func _background_crop(background: Dictionary, scene: Rect2) -> Rect2:
	if background.is_empty() or not scene.has_area():
		return Rect2()
	var dimensions := Vector2(background.size)
	# The reliquary source has a vertical ledge below the walkable floor.
	# Align feet to the stone plane rather than the front face of that ledge.
	var floor_end := dimensions.y * 0.86 if background.get("id", "") == "reliquary-hall" else dimensions.y
	var factor := maxf(scene.size.x / dimensions.x, scene.size.y / floor_end)
	var crop_extent := scene.size / factor
	return Rect2(Vector2((dimensions.x - crop_extent.x) * 0.5, floor_end - crop_extent.y), crop_extent)

func _draw_training_target(rect: Rect2, tint: Color) -> void:
	var center := rect.get_center().x
	var floor_y := rect.end.y
	var wood := Color("6f5040")
	var brass := Color("b49a65")
	draw_rect(Rect2(center - 6, floor_y - 139, 12, 133), wood.darkened(0.15))
	draw_rect(Rect2(center - 42, floor_y - 7, 84, 7), wood)
	draw_rect(Rect2(center - 50, floor_y - 113, 100, 13), wood.darkened(0.1))
	draw_rect(Rect2(center - 27, floor_y - 134, 54, 79), wood)
	draw_rect(Rect2(center - 22, floor_y - 129, 44, 69), Color("473e3b"))
	draw_rect(Rect2(center - 19, floor_y - 125, 38, 61), brass.darkened(0.3), false, 2)
	draw_circle(Vector2(center, floor_y - 153), 13, Color("8b7260"))
	draw_arc(Vector2(center, floor_y - 153), 13, 0, TAU, 12, brass, 2, false)
	draw_line(Vector2(center - 7, floor_y - 153), Vector2(center + 7, floor_y - 153), Color("302d31"), 3)
	draw_circle(Vector2(center, floor_y - 95), 13, tint.darkened(0.25))
	draw_circle(Vector2(center, floor_y - 95), 7, wood.darkened(0.4))
	draw_line(Vector2(center - 10, floor_y - 80), Vector2(center + 10, floor_y - 80), brass, 2)

func _draw_hud(layout: Dictionary, tint: Color) -> void:
	draw_rect(Rect2(1, 1, size.x - 2, 60), Color("111a29"))
	var hp_value: int = battle.hp if battle.phase != "idle" else run.hp
	var hp_max: int = battle.max_hp if battle.phase != "idle" else run.max_hp
	_bar(layout.health_rects[0], hp_value, hp_max, tint)
	var enemy_hp: int = battle.enemy_hp if battle.phase != "idle" else 140
	var enemy_max: int = battle.enemy_max_hp if battle.phase != "idle" else 140
	_bar(layout.health_rects[1], enemy_hp, enemy_max, Color("d3858b"))
	draw_string(font, Vector2(16, 44), "%s  %d / %d" % ["月庭法师" if run.class_id == "mage" else "圣堂骑士", hp_value, hp_max], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, tint)
	draw_string(font, Vector2(size.x * 0.70 - 16, 44), "训练守卫（占位）  %d / %d" % [enemy_hp, enemy_max], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("d9a2a7"))
	var center_text := "准备完成后自动执行"
	if battle.phase == "battle":
		center_text = "已暂停" if battle.paused else "自动执行  %.1f 秒" % battle.battle_time
	elif battle.phase == "won":
		center_text = "训练胜利 · 查看来源复盘"
	elif battle.phase == "lost":
		center_text = "训练失败 · 调整后再试"
	_center(center_text, Vector2(size.x / 2, 28), 16, Color("d8dce7"))
	if flash > 0 and not last_event.is_empty():
		var label_text: String = str(last_event.get("source_name", ""))
		if str(last_event.get("type", "")) == "charge":
			label_text += " · 蓄势"
		else:
			label_text += "  -%d" % int(last_event.get("amount", 0))
			var from: Vector2 = layout.hero_rect.get_center() if layout.hero_visible else layout.ground_anchor - Vector2(0, 75)
			var to: Vector2 = layout.enemy_rect.get_center()
			draw_line(from, to, Color(tint, minf(0.85, flash * 1.8)), 2)
		_center(label_text, Vector2(size.x / 2, 52), 15, tint)

func _shadow(position: Vector2, radius: float, tint: Color) -> void:
	draw_set_transform(position - Vector2(0, 2), 0.0, Vector2(1, 0.19))
	draw_circle(Vector2.ZERO, radius, Color(0.035, 0.025, 0.055, 0.6))
	draw_set_transform(Vector2.ZERO)
	draw_line(position - Vector2(radius * 0.65, 0), position + Vector2(radius * 0.65, 0), tint.darkened(0.65), 1)

func _center(text: String, position: Vector2, font_size: int, color: Color) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, position - Vector2(width / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _bar(rect: Rect2, value: int, maximum: int, color: Color) -> void:
	draw_rect(rect, Color("2c3647"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(float(value) / maxi(1, maximum), 0, 1), rect.size.y)), color)
