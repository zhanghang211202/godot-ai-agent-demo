extends Control
## Schematic live rule visualization. Production characters/backgrounds are pending.

var run: RefCounted
var battle: RefCounted
var last_event: Dictionary = {}
var flash := 0.0
var font: Font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")

func _ready() -> void:
	custom_minimum_size = Vector2(900, 154)
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

func _draw() -> void:
	if run == null or battle == null:
		return
	var tint := Color("baa4ee") if run.class_id == "mage" else Color("e3bd73")
	draw_rect(Rect2(Vector2.ZERO, size), Color("151c29"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("3d495c"), false, 1)
	var left := Vector2(size.x * 0.23, size.y * 0.58)
	var right := Vector2(size.x * 0.77, size.y * 0.58)
	draw_line(Vector2(32, size.y - 24), Vector2(size.x - 32, size.y - 24), Color("39465a"), 1)
	draw_arc(left, 26, 0, TAU, 6 if run.class_id == "mage" else 4, tint, 2, true)
	draw_arc(left, 17, 0, TAU, 4, tint.darkened(0.25), 1, true)
	draw_string(font, left + Vector2(-16, 7), "法" if run.class_id == "mage" else "刃", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, tint)
	draw_rect(Rect2(right - Vector2(23, 25), Vector2(46, 50)), Color("364558"))
	draw_string(font, right + Vector2(-17, 7), "靶", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("bacbdc"))
	var hp_value: int = battle.hp if battle.phase != "idle" else run.hp
	var hp_max: int = battle.max_hp if battle.phase != "idle" else run.max_hp
	_bar(Rect2(24, 15, size.x * 0.38, 8), hp_value, hp_max, tint)
	var enemy_hp: int = battle.enemy_hp if battle.phase != "idle" else 140
	var enemy_max: int = battle.enemy_max_hp if battle.phase != "idle" else 140
	_bar(Rect2(size.x * 0.62 - 24, 15, size.x * 0.38, 8), enemy_hp, enemy_max, Color("d3858b"))
	draw_string(font, Vector2(24, 47), "本体  %d / %d" % [hp_value, hp_max], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, tint)
	draw_string(font, Vector2(size.x * 0.62 - 24, 47), "同条件训练守卫  %d / %d" % [enemy_hp, enemy_max], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("d9a2a7"))
	var center_text := "准备完成后自动执行"
	if battle.phase == "battle":
		center_text = "已暂停" if battle.paused else "自动执行  %.1f 秒" % battle.battle_time
	elif battle.phase == "won":
		center_text = "训练胜利 · 查看来源复盘"
	elif battle.phase == "lost":
		center_text = "训练失败 · 调整后再试"
	_center(center_text, Vector2(size.x / 2, 66), 18, Color("d8dce7"))
	_center("规则示意图 · 非最终角色与背景", Vector2(size.x / 2, size.y - 7), 13, Color("8f9bb0"))
	if flash > 0 and not last_event.is_empty():
		var label_text: String = str(last_event.get("source_name", ""))
		if str(last_event.get("type", "")) == "charge":
			label_text += " · 蓄势"
		else:
			draw_line(left + Vector2(34, 0), right - Vector2(34, 0), Color(tint, minf(1, flash * 2)), 3)
			label_text += "  -%d" % int(last_event.get("amount", 0))
		_center(label_text, Vector2(size.x / 2, 104), 17, tint)

func _center(text: String, position: Vector2, font_size: int, color: Color) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, position - Vector2(width / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _bar(rect: Rect2, value: int, maximum: int, color: Color) -> void:
	draw_rect(rect, Color("2c3647"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(float(value) / maxi(1, maximum), 0, 1), rect.size.y)), color)
