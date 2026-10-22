extends RefCounted

static func draw(ui) -> void:
	var l = ui.layout
	var r: Rect2 = l.bag_rect
	ui.Materials.draw_panel(ui, r, "leather")
	ui._icon("backpack", Rect2(r.position + Vector2(20, 16), Vector2(32, 32)))
	ui._label("旅人的行囊", r.position + Vector2(63, 39), 22, ui.TEXT)
	ui._label("6 × 4", Vector2(r.end.x - 68, r.position.y + 38), 14, ui.GOLD)
	var grid: Rect2 = l.grid_rect()
	ui._frame(grid.grow(8), Color("211e1b"), Color("8c6746"))
	for y in range(4):
		for x in range(6):
			var cell := Rect2(grid.position + Vector2(x, y) * l.cell_size, Vector2.ONE * l.cell_size)
			ui.draw_rect(cell.grow(-2), Color("303b32") if (x + y) % 2 == 0 else Color("2b352e"))
			ui.draw_rect(cell.grow(-3), Color("485044"), false, 1)
			ui.draw_rect(Rect2(cell.position + Vector2(6, 6), Vector2(2, 2)), Color("6a6550"))
	var hover_cell: Vector2i = ui._cell_at(ui.mouse)
	var hovered: Dictionary = ui.game.item_at(hover_cell) if ui._in_grid(hover_cell) else {}
	var focus: Dictionary = ui.game.item_by_uid(ui.selected_uid)
	if not hovered.is_empty():
		focus = hovered
	ui._draw_adjacency(focus)
	for item in ui.game.items:
		var held: bool = not ui.drag.is_empty() and ui.drag["source"] == "bag" and ui.drag["uid"] == item["uid"]
		ui._draw_item(item, ui._item_rect(item), 0.22 if held else 1.0, item["uid"] == ui.selected_uid or (not hovered.is_empty() and hovered["uid"] == item["uid"]))
	ui._draw_support_markers()
	if ui.merge_glow > 0.0:
		ui.draw_rect(grid.grow(8), Color(0.95, 0.77, 0.36, ui.merge_glow * 0.6), false, 3)
	var stats: Dictionary = ui.game.get_stats()
	ui._label("%d 组连接" % stats["synergy_count"], Vector2(r.position.x + 24, r.end.y - 27), 15, ui.TEAL)
	ui._button(l.sell_rect, "出售  /  D", false, 14, ui.game.phase != "prepare")
	if r.size.y > 410:
		ui._center("R 旋转  ·  同级叠放升级  ·  蓝点连接武器", Rect2(grid.position.x, grid.end.y + 18, grid.size.x, 26), 13, Color("b4b29a"))
