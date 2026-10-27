extends Control
## Native drag/drop grid for the class rules laboratory, not final item artwork.

signal cell_selected(cell: Vector2i)
signal drop_requested(data: Dictionary, cell: Vector2i)
signal preview_changed(preview: Dictionary)

const Catalog = preload("res://scripts/classes/class_catalog.gd")
const MageArt = preload("res://scripts/classes/mage_art.gd")
const SHORT_LABELS := {
	"spark": "微光", "fire_mote": "火", "water_mote": "水", "wind_mote": "风",
	"flame_glyph": "焰爆", "tide_lances": "潮汐", "arcane_focus": "晶",
	"mage_ward": "护符", "iron_blade": "长剑", "greatblade": "重刃",
	"charge_seal": "势", "knight_ward": "甲片",
	"frost_bolt": "冰矢", "gale_blades": "风刃", "steam_burst": "蒸爆", "ember_tornado": "焰涡",
}
var run: RefCounted
var battle: RefCounted
var playback_speed := 1.0
var active_sources: Dictionary = {}
var current_preview: Dictionary = {}
var selected_uid := -1
var held: Dictionary = {}
var hover_cell := Vector2i(-1, -1)
var font: Font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")

func _ready() -> void:
	custom_minimum_size = Vector2(420, 286)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	clip_contents = true
	mouse_exited.connect(func():
		hover_cell = Vector2i(-1, -1)
		update_preview())

func _process(delta: float) -> void:
	if battle == null or battle.paused:
		return
	var had_active_sources := not active_sources.is_empty()
	for uid in active_sources.keys():
		active_sources[uid] = maxf(0, float(active_sources[uid]) - delta * playback_speed)
		if active_sources[uid] <= 0:
			active_sources.erase(uid)
	if battle.phase == "battle" or had_active_sources:
		queue_redraw()

func show_event(event: Dictionary) -> void:
	if str(event.get("type", "")) in ["spell", "spell_burst", "spell_multi"]:
		active_sources[int(event.get("source_uid", -1))] = 0.28
		queue_redraw()

func update_preview() -> void:
	current_preview = run.preview_placement(held, hover_cell) if run != null and run.phase == "prepare" and not held.is_empty() and hover_cell.x >= 0 else {}
	preview_changed.emit(current_preview)
	queue_redraw()

func grid_rect() -> Rect2:
	var cell_size: float = floor(minf((size.x - 20.0) / 6.0, (size.y - 20.0) / 4.0))
	var dimensions := Vector2(6, 4) * cell_size
	return Rect2((size - dimensions) * 0.5, dimensions)

func cell_rect(cell: Vector2i) -> Rect2:
	var board := grid_rect()
	return Rect2(board.position + Vector2(cell) * board.size.x / 6.0, Vector2.ONE * board.size.x / 6.0)

func cell_at(local_position: Vector2) -> Vector2i:
	var board := grid_rect()
	if not board.has_point(local_position):
		return Vector2i(-1, -1)
	return Vector2i((local_position - board.position) / (board.size.x / 6.0))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_cell = cell_at(event.position)
		update_preview()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell := cell_at(event.position)
		if cell.x >= 0:
			cell_selected.emit(cell)

func _get_drag_data(at_position: Vector2) -> Variant:
	if run == null or run.phase != "prepare":
		return null
	var item: Dictionary = run.item_at(cell_at(at_position))
	if item.is_empty():
		return null
	var preview := Label.new()
	preview.add_theme_font_override("font", font)
	preview.text = str(run.get_definition(item.kind).name) + " · 松开以放置"
	set_drag_preview(preview)
	return {"origin": "bag", "uid": item.uid, "rotated": item.rotated}

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	hover_cell = cell_at(at_position)
	update_preview()
	return run != null and run.phase == "prepare" and data is Dictionary and data.get("origin", "") in ["bag", "source"] and hover_cell.x >= 0

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		drop_requested.emit(data, cell_at(at_position))

func _get_tooltip(at_position: Vector2) -> String:
	if run == null:
		return ""
	var item: Dictionary = run.item_at(cell_at(at_position))
	if item.is_empty():
		return ""
	var definition: Dictionary = run.get_definition(item.kind)
	return str(definition.name) + "\n" + str(definition.get("description", ""))

func label_layout(kind: String, rect: Rect2, rotated: bool) -> Dictionary:
	var definition: Dictionary = Catalog.definition(kind)
	var full_name := str(definition.get("name", kind))
	var point_size := 16 if grid_rect().size.x >= 420 else 14
	var text_rect := rect.grow(-4)
	var line_height := font.get_height(point_size)
	var lines := _label_lines(full_name, text_rect.size.x, point_size)
	var abbreviated := not _label_fits(lines, text_rect.size, point_size)
	if abbreviated:
		lines = _label_lines(str(SHORT_LABELS.get(kind, full_name.left(1))), text_rect.size.x, point_size)
	if not _label_fits(lines, text_rect.size, point_size):
		lines = _label_lines(str(SHORT_LABELS.get(kind, full_name)).left(1), text_rect.size.x, point_size)
		if not _label_fits(lines, text_rect.size, point_size):
			lines.clear()
	var baselines: Array[Vector2] = []
	var bounds: Array[Rect2] = []
	var first_y := text_rect.position.y + (text_rect.size.y - lines.size() * line_height) * 0.5 + font.get_ascent(point_size)
	for index in range(lines.size()):
		var width := font.get_string_size(lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x
		var baseline := Vector2(text_rect.get_center().x - width * 0.5, first_y + index * line_height)
		baselines.append(baseline)
		bounds.append(Rect2(baseline - Vector2(0, font.get_ascent(point_size)), Vector2(width, line_height)))
	var supports: Array[Vector2] = []
	if str(definition.get("category", "")) == "support":
		# Put the horizontal/vertical pair on the border, away from the label.
		if rotated:
			supports.assign([rect.position + Vector2(2, 4), Vector2(rect.position.x + 2, rect.end.y - 4)])
		else:
			supports.assign([rect.position + Vector2(4, 2), Vector2(rect.end.x - 4, rect.position.y + 2)])
	return {"full_name": full_name, "lines": lines, "font_size": point_size,
		"baselines": baselines, "bounds": bounds, "text_rect": text_rect,
		"abbreviated": abbreviated, "support_points": supports}

func item_layout(kind: String, rect: Rect2, rotated: bool) -> Dictionary:
	var art := MageArt.icon(kind)
	var label := label_layout(kind, rect, rotated)
	if art.is_empty():
		return {"icon_rect": Rect2(), "label": label}
	var icon_space := rect.grow(-5)
	if Vector2i(Catalog.definition(kind).size) == Vector2i.ONE:
		label.lines = []
		label.baselines = []
		label.bounds = []
	elif rect.size.x > rect.size.y * 1.4:
		var width := minf(rect.size.y - 10, rect.size.x * 0.35)
		icon_space.size.x = width
		label = label_layout(kind, Rect2(rect.position + Vector2(width + 6, 0), rect.size - Vector2(width + 6, 0)), rotated)
	else:
		var label_height := font.get_height(16 if grid_rect().size.x >= 420 else 14) + 10
		icon_space.size.y = maxf(10, icon_space.size.y - label_height)
		label = label_layout(kind, Rect2(Vector2(rect.position.x, rect.end.y - label_height), Vector2(rect.size.x, label_height)), rotated)
	# Direction points always refer to the full occupied rectangle.
	label.support_points = label_layout(kind, rect, rotated).support_points
	var source: Rect2 = art.source_rect
	var factor := minf(icon_space.size.x / source.size.x, icon_space.size.y / source.size.y)
	var extent := source.size * factor
	return {"icon_rect": Rect2(icon_space.get_center() - extent / 2, extent), "label": label}

func _label_lines(text: String, width: float, point_size: int) -> Array[String]:
	var lines: Array[String] = []
	var current := ""
	for character in text:
		if not current.is_empty() and font.get_string_size(current + character, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x > width:
			lines.append(current)
			current = ""
		current += character
	if not current.is_empty():
		lines.append(current)
	return lines

func _label_fits(lines: Array[String], extent: Vector2, point_size: int) -> bool:
	if lines.is_empty() or lines.size() * font.get_height(point_size) > extent.y:
		return false
	for line in lines:
		if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x > extent.x:
			return false
	return true

func _draw() -> void:
	if run == null:
		return
	var board := grid_rect()
	draw_style_box(_box(Color("17202c"), Color("475368")), board.grow(7))
	for y in range(4):
		for x in range(6):
			var cell := cell_rect(Vector2i(x, y))
			draw_rect(cell.grow(-2), Color("222c3b") if (x + y) % 2 == 0 else Color("1d2735"))
			draw_rect(cell.grow(-2), Color("354257"), false, 1)
	var focus: Dictionary = run.item_by_uid(selected_uid)
	var timing_sources: Dictionary = battle.get_presentation_timing().sources if battle != null and battle.phase == "battle" else {}
	if not focus.is_empty():
		for support_cell in run.get_support_cells(focus):
			if support_cell.x >= 0 and support_cell.x < 6 and support_cell.y >= 0 and support_cell.y < 4:
				draw_rect(cell_rect(support_cell).grow(-4), Color(0.5, 0.84, 0.78, 0.25))
	for item in run.items:
		var dimensions: Vector2i = run.get_item_size(item)
		var rect := Rect2(cell_rect(item.pos).position, Vector2(dimensions) * board.size.x / 6.0).grow(-5)
		var definition: Dictionary = run.get_definition(item.kind)
		var tint := Color(str(definition.get("color", "90a7be")))
		draw_style_box(_box(tint.darkened(0.76), tint if int(item.uid) == selected_uid else tint.darkened(0.3)), rect)
		var visual := item_layout(str(item.kind), rect, bool(item.rotated))
		var art := MageArt.icon(str(item.kind))
		if not art.is_empty():
			draw_texture_rect_region(art.texture, visual.icon_rect, art.source_rect)
		var label: Dictionary = visual.label
		for index in range(label.lines.size()):
			draw_string(font, label.baselines[index], label.lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size, tint.lightened(0.35))
		for point: Vector2 in label.support_points:
			draw_circle(point, 2, Color("8bdfd1"))
		if active_sources.has(int(item.uid)):
			draw_rect(rect.grow(-1), Color(1, 0.88, 0.55, float(active_sources[int(item.uid)]) / 0.28), false, 2)
		if run.class_id == "mage" and battle != null and battle.phase == "battle" and str(definition.category) == "attack":
			var timings: Dictionary = timing_sources
			if timings.has(int(item.uid)):
				var bar := Rect2(Vector2(rect.position.x + 3, rect.end.y - 3), Vector2(rect.size.x - 6, 2))
				draw_rect(bar, Color("141e2d"))
				draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(timings[int(item.uid)].progress), 2)), Color("cdb6ff"))
	if hover_cell.x >= 0 and not held.is_empty() and run.phase == "prepare":
		var candidate: Dictionary = {}
		if held.origin == "bag":
			candidate = run.item_by_uid(int(held.uid)).duplicate(true)
		elif int(held.get("index", -1)) >= 0 and int(held.index) < run.sources.size():
			candidate = {"kind": run.sources[int(held.index)].kind, "rotated": false, "uid": -1}
		if not candidate.is_empty():
			candidate.rotated = held.get("rotated", false)
			var occupied: Dictionary = run.item_at(hover_cell)
			var merge_kind: String = run.get_merge_result(candidate, occupied) if not occupied.is_empty() else ""
			var valid := bool(current_preview.get("ok", false))
			var tint := Color("e3b76f") if valid and not merge_kind.is_empty() else Color("75d3bd") if valid else Color("ed8a93")
			var position := hover_cell
			if not merge_kind.is_empty():
				candidate.kind = merge_kind
				position = occupied.pos
			var preview_rect := Rect2(cell_rect(position).position, Vector2(run.get_item_size(candidate)) * board.size.x / 6.0)
			draw_rect(preview_rect.grow(-3), Color(tint, 0.15))
			draw_rect(preview_rect.grow(-3), tint, false, 2)

func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(5)
	return box
