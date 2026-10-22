extends RefCounted

static func draw(ui) -> void:
	var r: Rect2 = ui.layout.market_rect
	ui.Materials.draw_panel(ui, r, "dark")
	ui._label("林间补给", r.position + Vector2(20, 39), 22, ui.TEXT)
	ui._button(ui.REFRESH_RECT, "刷新 %d 金" % ui.game.reroll_cost, false, 14, ui.game.phase != "prepare")
	for index in range(4):
		var card: Rect2 = ui.layout.shop_rect(index)
		var kind: String = ui.game.shop_offers[index]
		var active: bool = ui.game.phase == "prepare"
		if kind.is_empty():
			ui._frame(card, Color("172724"), Color("35473c"))
			ui._center("已收入行囊", card, 16, Color("758578"))
			continue
		var definition: Dictionary = ui.game.get_definition(kind)
		var hover: bool = card.has_point(ui.mouse) and active
		ui._frame(card, Color("384a3a") if hover else Color("263a31"), ui.GOLD if hover else Color("53614b"))
		ui.draw_line(card.position + Vector2(4, 4), Vector2(card.end.x - 4, card.position.y + 4), Color("61705a"), 1)
		var icon_size := 64.0
		var icon_y: float = card.position.y + maxf(5, (card.size.y - 116) * 0.4)
		ui._icon(kind, Rect2(Vector2(card.get_center().x - 32, icon_y), Vector2(icon_size, icon_size)), Color.WHITE if active else Color("789183"))
		ui._center(str(definition["name"]), Rect2(card.position.x + 4, icon_y + 64, card.size.x - 8, 26), 16, ui.TEXT if active else ui.MUTED)
		var footprint: Vector2i = definition["size"]
		ui._label("%d×%d" % [footprint.x, footprint.y], Vector2(card.position.x + 12, card.end.y - 15), 13, ui.MUTED)
		ui._icon("coin", Rect2(card.end - Vector2(57, 35), Vector2(24, 24)))
		ui._label(str(definition["cost"]), card.end - Vector2(26, 15), 18, ui.GOLD if ui.game.gold >= int(definition["cost"]) else ui.RED)
	ui._label("战斗中暂停交易" if ui.game.phase != "prepare" else "拖入行囊，或点击后选择落点", Vector2(r.position.x + 20, r.end.y - 17), 13, ui.MUTED)
