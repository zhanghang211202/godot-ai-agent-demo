extends Control
## Native drag/drop grid for the class rules laboratory, not final item artwork.

signal cell_selected(cell: Vector2i)
signal drop_requested(data: Dictionary, cell: Vector2i)

const Catalog = preload("res://scripts/classes/class_catalog.gd")
const SHORT_LABELS := {
	"spark": "微光", "fire_mote": "火", "water_mote": "水", "wind_mote": "风",
	"flame_glyph": "焰爆", "tide_lances": "潮汐", "arcane_focus": "晶",
	"mage_ward": "护符", "iron_blade": "长剑", "greatblade": "重刃",
	"charge_seal": "势", "knight_ward": "甲片",
}
var run: RefCounted
var selected_uid := -1
var held: Dictionary = {}
var hover_cell := Vector2i(-1, -1)
var font: Font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")

func _ready() -> void:
	custom_minimum_size = Vector2(420, 286)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

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
		queue_redraw()
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
	queue_redraw()
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
		var label := label_layout(str(item.kind), rect, bool(item.rotated))
		for index in range(label.lines.size()):
			draw_string(font, label.baselines[index], label.lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size, tint.lightened(0.35))
		for point: Vector2 in label.support_points:
			draw_circle(point, 2, Color("8bdfd1"))
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
			var tint := Color("e3b76f") if not merge_kind.is_empty() else Color("75d3bd") if run.can_place(candidate, hover_cell, int(candidate.uid)) else Color("ed8a93")
			var preview_rect := Rect2(cell_rect(hover_cell).position, Vector2(run.get_item_size(candidate)) * board.size.x / 6.0)
			draw_rect(preview_rect.grow(-3), Color(tint, 0.15))
			draw_rect(preview_rect.grow(-3), tint, false, 2)

func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(5)
	return box
