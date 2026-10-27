extends Control
## Dedicated action-frame sample over the unchanged C0 event engine.

const Art = preload("res://scripts/classes/class_art.gd")
const Motion = preload("res://scripts/classes/class_motion.gd")
const Feedback = preload("res://scripts/classes/class_feedback.gd")
const MageArt = preload("res://scripts/classes/mage_art.gd")
const MageEffects = preload("res://scripts/classes/mage_effects.gd")
var motion = Motion.new()
var feedback = Feedback.new()
var pixel_cutout_enabled := true
var actor_sprite: Sprite2D
var actor_material: ShaderMaterial
var enemy_sprite: Sprite2D
var enemy_material: ShaderMaterial
var effects_layer: Node2D
var playback_speed := 1.0
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
	actor_sprite = Sprite2D.new()
	actor_sprite.centered = false
	actor_sprite.region_enabled = true
	actor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor_material = ShaderMaterial.new()
	actor_material.shader = preload("res://scripts/classes/class_actor.gdshader")
	actor_sprite.material = actor_material
	add_child(actor_sprite)
	enemy_sprite = Sprite2D.new()
	enemy_sprite.centered = false
	enemy_sprite.region_enabled = true
	enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	enemy_material = ShaderMaterial.new()
	enemy_material.shader = actor_material.shader
	enemy_sprite.material = enemy_material
	add_child(enemy_sprite)
	effects_layer = Node2D.new()
	effects_layer.draw.connect(_draw_feedback)
	add_child(effects_layer)

func show_event(event: Dictionary) -> void:
	motion.show_event(event)
	feedback.show_event(event)
	if str(event.get("type", "")) == "battle_end":
		motion.finish_battle()
	if str(event.get("type", "")) in ["spell", "spell_burst", "spell_multi", "attack", "heavy_charge", "charge"]:
		last_event = event
		flash = 0.6
	queue_redraw()

func reset_presentation() -> void:
	last_event = {}
	flash = 0.0
	motion.reset()
	feedback.reset()
	queue_redraw()
	if effects_layer != null:
		effects_layer.queue_redraw()

func has_pending_presentation() -> bool:
	return motion.state != "idle" or feedback.is_active()

func _process(delta: float) -> void:
	if battle != null and battle.paused:
		return
	if flash > 0 or has_pending_presentation() or (battle != null and battle.phase == "battle"):
		motion.advance(delta * playback_speed)
		feedback.advance(delta * playback_speed)
		flash = maxf(0.0, flash - delta * playback_speed)
		queue_redraw()
		effects_layer.queue_redraw()

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

func enemy_frame() -> int:
	if feedback.enemy_exit >= 0:
		return 3
	if feedback.hero_hit > 0:
		return 2
	if feedback.enemy_hit > 0:
		return 3
	if battle != null and battle.phase == "battle" and float(battle.get_presentation_timing().enemy_remaining) <= 0.35:
		return 1
	return 0

func get_art_layout() -> Dictionary:
	# This drawing/report query never acquires items or ticks the rules.
	var hero_id := _hero_id()
	var background_id := "moon-court" if run != null and run.class_id == "mage" else "reliquary-hall"
	var hero: Dictionary = Art.get_asset(hero_id)
	var default_clip := {"mage-idle": "mage-cast", "knight-sword-idle": "knight-sword", "knight-greatblade-idle": "knight-greatblade"}.get(hero_id, "") as String
	var clip_id: String = motion.clip if not motion.clip.is_empty() else default_clip
	var animated_hero := Motion.get_asset(clip_id)
	var frame_index: int = motion.frame_index() if not motion.clip.is_empty() else 0
	var background: Dictionary = Art.get_asset(background_id)
	var scene := Rect2(1, 61, maxf(0, size.x - 2), maxf(0, size.y - 89))
	var background_crop := _background_crop(background, scene)
	var ground := size.y - 29.0
	var anchor := Vector2(roundf(size.x * 0.26), ground)
	var source: Rect2 = hero.get("source_rect", Rect2())
	var destination := Rect2()
	var factor := 0.0
	var cast_point := anchor - Vector2(0, 110)
	if source.has_area():
		var desired_height := minf(256.0, scene.size.y - 3.0)
		factor = minf(desired_height / source.size.y, (size.x * 0.34) / source.size.x)
		var extent := source.size * factor
		destination = Rect2(anchor - Vector2(extent.x * 0.5, extent.y), extent)
	if not animated_hero.is_empty():
		var frame: Dictionary = animated_hero.frames[frame_index]
		source = frame.source_rect
		factor = minf(minf(256.0, scene.size.y - 3.0) / float(animated_hero.height), (size.x * 0.34) / float(animated_hero.left + animated_hero.right))
		destination = Rect2(anchor + (source.position - Vector2(frame.pivot)) * factor, source.size * factor)
		cast_point = anchor + (Vector2(frame.cast_point) - Vector2(frame.pivot)) * factor
		hero = animated_hero
	var health: Array[Rect2] = [Rect2(16, 12, size.x * 0.30, 8), Rect2(size.x * 0.70 - 16, 12, size.x * 0.30, 8)]
	var phase := Rect2(size.x * 0.33, 8, size.x * 0.34, 43)
	var enemy := Rect2(Vector2(roundf(size.x * 0.76) - 60, ground - 166), Vector2(120, 166))
	var enemy_art: Dictionary = MageArt.enemy() if run != null and run.class_id == "mage" else {}
	var enemy_anchor := Vector2(roundf(size.x * 0.76), ground)
	var enemy_source := Rect2()
	var enemy_factor := 0.0
	var enemy_index := enemy_frame()
	if not enemy_art.is_empty():
		var frame: Dictionary = enemy_art.frames[enemy_index]
		enemy_source = frame.source_rect
		enemy_factor = minf(minf(204, scene.size.y - 6) / float(enemy_art.height), size.x * 0.24 / float(enemy_art.left + enemy_art.right))
		enemy = Rect2(enemy_anchor + (enemy_source.position - Vector2(frame.pivot)) * enemy_factor, enemy_source.size * enemy_factor)
	var missing: Array[String] = []
	if hero_id != "" and hero.is_empty():
		missing.append(hero_id)
	if background.is_empty():
		missing.append(background_id)
	return {"class_id": str(run.class_id) if run != null else "", "hero_id": hero_id,
		"hero_path": hero.get("path", ""), "background_id": background_id, "background_path": Art.asset_path(background_id),
		"source_size": hero.get("size", Vector2i.ZERO), "source_rect": source, "hero_rect": destination, "hero_cast_point": cast_point,
		"background_source_size": background.get("size", Vector2i.ZERO), "background_source_rect": background_crop,
		"stage_rect": Rect2(Vector2.ZERO, size), "scene_rect": scene, "ground_anchor": anchor, "ground_y": ground,
		"enemy_rect": enemy, "health_rects": health, "phase_rect": phase,
		"source_scale": Vector2.ONE * factor, "source_scale_is_integer": factor >= 1.0 and is_equal_approx(factor, roundf(factor)),
		"scaling_mode": "common clip scale and measured boot anchors, nearest source-fit; logical pixel grid pending",
		"alpha_threshold": 128, "assets_ready": missing.is_empty(), "missing_assets": missing,
		"hero_visible": destination.has_area(), "animated": not animated_hero.is_empty(), "enemy_placeholder": enemy_art.is_empty(),
		"enemy_path": enemy_art.get("path", ""), "enemy_source_rect": enemy_source, "enemy_scale": enemy_factor, "enemy_frame": enemy_index, "enemy_anchor": enemy_anchor,
		"motion_clip": clip_id, "motion_state": motion.state, "motion_frame": frame_index,
		"alpha_render_mode": "cutout >=128, opaque interior" if pixel_cutout_enabled else "original alpha comparison",
		"feedback": feedback.report(), "spell_effects": MageEffects.visible_effects(feedback.numbers) if run != null and run.class_id == "mage" else []}

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
	_shadow(layout.ground_anchor, 39, tint, feedback.opacity("hero"))
	_shadow(layout.enemy_anchor, 35, tint, feedback.opacity("enemy"))
	var hero: Dictionary = Art.get_asset(layout.hero_id)
	if layout.animated:
		hero = Motion.get_asset(layout.motion_clip)
	if layout.hero_visible:
		actor_sprite.visible = true
		actor_sprite.texture = hero.texture
		actor_sprite.region_rect = layout.source_rect
		actor_sprite.position = layout.hero_rect.position + Vector2(roundf(sin(feedback.hero_hit * 90.0) * 3.0) if feedback.hero_hit > 0 else 0.0, 0)
		actor_sprite.scale = layout.source_scale
		actor_material.set_shader_parameter("cutout_enabled", pixel_cutout_enabled)
		actor_material.set_shader_parameter("hurt_strength", 0.65 * feedback.hero_hit / Feedback.HIT_TIME)
		actor_material.set_shader_parameter("actor_opacity", feedback.opacity("hero"))
	else:
		actor_sprite.visible = false
		_center("待配武装" if layout.hero_id == "" else "角色静态稿待载入", layout.ground_anchor - Vector2(0, 55), 16, tint)
	var enemy_alpha: float = feedback.opacity("enemy")
	enemy_sprite.visible = not layout.enemy_placeholder
	if not layout.enemy_placeholder:
		var enemy_art := MageArt.enemy()
		enemy_sprite.texture = enemy_art.texture
		enemy_sprite.region_rect = layout.enemy_source_rect
		enemy_sprite.position = layout.enemy_rect.position
		enemy_sprite.scale = Vector2.ONE * float(layout.enemy_scale)
		enemy_material.set_shader_parameter("cutout_enabled", pixel_cutout_enabled)
		enemy_material.set_shader_parameter("hurt_strength", feedback.enemy_hit / Feedback.HIT_TIME * 0.45)
		enemy_material.set_shader_parameter("actor_opacity", enemy_alpha)
	elif enemy_alpha > 0:
		var pivot := Vector2(layout.enemy_rect.get_center().x, layout.ground_y)
		var lean := (1.0 - enemy_alpha) * 0.12 + sin(feedback.enemy_hit * 80) * 0.025
		draw_set_transform(pivot, lean)
		_draw_training_target(Rect2(layout.enemy_rect.position - pivot, layout.enemy_rect.size), Color(tint.lightened(feedback.enemy_hit), enemy_alpha))
		draw_set_transform(Vector2.ZERO)
	_draw_hud(layout, tint)
	var footer_name := "月光观测庭" if run.class_id == "mage" else "余烬圣堂"
	draw_rect(Rect2(1, size.y - 21, size.x - 2, 20), Color("111925"))
	draw_string(font, Vector2(14, size.y - 6), footer_name + " · 动作样板", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b6b4c6"))
	var note := "微光 / 焰爆 / 潮汐 · 元素编织" if run.class_id == "mage" else "命中 / 受击 / 淡出反馈 · 专用姿势待制作"
	var note_width := font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, Vector2(size.x - note_width - 14, size.y - 6), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b6b4c6"))
	draw_rect(layout.stage_rect, Color("6a6073") if run.class_id == "mage" else Color("78694e"), false, 1)
	effects_layer.queue_redraw()

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
	var alpha := tint.a
	var wood := Color(Color("6f5040").lightened(feedback.enemy_hit), alpha)
	var brass := Color(Color("b49a65").lightened(feedback.enemy_hit), alpha)
	draw_rect(Rect2(center - 6, floor_y - 139, 12, 133), wood.darkened(0.15))
	draw_rect(Rect2(center - 42, floor_y - 7, 84, 7), wood)
	draw_rect(Rect2(center - 50, floor_y - 113, 100, 13), wood.darkened(0.1))
	draw_rect(Rect2(center - 27, floor_y - 134, 54, 79), wood)
	draw_rect(Rect2(center - 22, floor_y - 129, 44, 69), Color(Color("473e3b"), alpha))
	draw_rect(Rect2(center - 19, floor_y - 125, 38, 61), brass.darkened(0.3), false, 2)
	draw_circle(Vector2(center, floor_y - 153), 13, Color(Color("8b7260"), alpha))
	draw_arc(Vector2(center, floor_y - 153), 13, 0, TAU, 12, brass, 2, false)
	draw_line(Vector2(center - 7, floor_y - 153), Vector2(center + 7, floor_y - 153), Color(Color("302d31"), alpha), 3)
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
	draw_string(font, Vector2(size.x * 0.70 - 16, 44), "%s  %d / %d" % ["月庭巡卫 · 训练" if run.class_id == "mage" else "训练守卫（占位）", enemy_hp, enemy_max], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("d9a2a7"))
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
			if run.class_id != "mage":
				draw_line(from, to, Color(tint, minf(0.85, flash * 1.8)), 2)
		_center(label_text, Vector2(size.x / 2, 52), 15, tint)

func _shadow(position: Vector2, radius: float, tint: Color, opacity := 1.0) -> void:
	if opacity <= 0:
		return
	draw_set_transform(position - Vector2(0, 2), 0.0, Vector2(1, 0.19))
	draw_circle(Vector2.ZERO, radius, Color(0.035, 0.025, 0.055, 0.6 * opacity))
	draw_set_transform(Vector2.ZERO)
	draw_line(position - Vector2(radius * 0.65, 0), position + Vector2(radius * 0.65, 0), Color(tint.darkened(0.65), opacity), 1)

func _draw_feedback() -> void:
	if run == null or battle == null:
		return
	var layout := get_art_layout()
	if run.class_id == "mage":
		for effect: Dictionary in layout.spell_effects:
			var hero_point: Vector2 = layout.ground_anchor - Vector2(0, 110) if effect.target == "hero" else layout.hero_cast_point
			MageEffects.draw_effect(effects_layer, effect, hero_point, layout.enemy_anchor - Vector2(0, 100))
	var slots := {"hero": 0, "enemy": 0}
	for index in range(feedback.numbers.size() - 1, -1, -1):
		var number: Dictionary = feedback.numbers[index]
		var target: String = number.target
		var origin := Vector2(layout.ground_anchor.x + 220, layout.ground_y - 75) if target == "hero" else Vector2(layout.enemy_anchor.x - 170, layout.ground_y - 75)
		var slot: int = slots[target]
		if slot >= 3:
			continue
		slots[target] += 1
		var progress: float = number.age / Feedback.NUMBER_TIME
		var text := "-%d" % int(number.amount)
		if int(number.hits) > 1:
			text += " · %d段" % int(number.hits)
		if int(number.armor) > 0:
			text += "  护甲抵挡%d" % int(number.armor)
		var point := origin + Vector2(0, -progress * 30 - slot * 24)
		point.y = maxf(84, point.y)
		var color := Color("ffb8b0") if target == "hero" else Color("ffe1a0") if number.kind == "greatblade" else Color("b9e7ff")
		color.a = clampf((1.0 - progress) * 2, 0, 1)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		point.x = clampf(point.x, 8 + width / 2, size.x - 8 - width / 2)
		effects_layer.draw_string(font, point - Vector2(width / 2, 0) + Vector2(1, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.03, 0.025, 0.04, color.a))
		effects_layer.draw_string(font, point - Vector2(width / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)
	if feedback.enemy_hit > 0:
		var center: Vector2 = layout.enemy_rect.get_center()
		var radius: float = 10 + (1.0 - feedback.enemy_hit / Feedback.HIT_TIME) * 20
		effects_layer.draw_arc(center, radius, 0, TAU, 12, Color(1.0, 0.87, 0.65, feedback.enemy_hit / Feedback.HIT_TIME), 2, false)

func _center(text: String, position: Vector2, font_size: int, color: Color) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, position - Vector2(width / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _bar(rect: Rect2, value: int, maximum: int, color: Color) -> void:
	draw_rect(rect, Color("2c3647"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(float(value) / maxi(1, maximum), 0, 1), rect.size.y)), color)
