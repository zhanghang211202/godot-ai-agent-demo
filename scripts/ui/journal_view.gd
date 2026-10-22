extends RefCounted

const INK := Color("35453e")
const SOFT_INK := Color("627063")

static func draw(ui) -> void:
	var r: Rect2 = ui.layout.notes_rect
	ui.Materials.draw_panel(ui, r, "paper")
	ui._label("行囊手记", r.position + Vector2(22, 39), 22, INK)
	ui._button(ui.layout.recipe_toggle_rect, "装备详情" if ui.recipes_open else "合成图鉴", false, 14)
	if ui.recipes_open:
		draw_recipes(ui)
		return
	var item: Dictionary = ui._inspected_item()
	if item.is_empty():
		item = {"kind": "sword", "level": 1, "uid": -1, "pos": Vector2i(-9, -9), "rotated": false}
	var definition: Dictionary = ui.game.get_definition(item["kind"])
	var top: Vector2 = r.position + Vector2(22, 72)
	ui._frame(Rect2(top, Vector2(76, 76)), Color("d2d3b8"), Color("8f997f"))
	ui._icon(item["kind"], Rect2(top + Vector2(6, 6), Vector2(64, 64)))
	ui._label(str(definition["name"]), top + Vector2(92, 24), 20, INK)
	ui._label(ui.LEVEL_NAMES[int(item.get("level", 1)) - 1] + " · " + ui._category_name(definition["category"]), top + Vector2(92, 50), 14, SOFT_INK)
	var footprint: Vector2i = ui.game.get_item_size(item)
	ui._label("占格 %d × %d" % [footprint.x, footprint.y], top + Vector2(92, 74), 14, SOFT_INK)
	ui._wrapped(definition["description"], Rect2(top + Vector2(0, 98), Vector2(r.size.x - 44, 72)), 16, INK)
	var y: float = top.y + 188
	ui.draw_line(Vector2(top.x, y - 14), Vector2(r.end.x - 22, y - 14), Color("afb69a"), 1)
	var detail := "蓝点指定连接方向，旋转会改变生效格。" if item["kind"] == "whetstone" else "同种同级可升级；异物配方见合成图鉴。"
	if definition["category"] == "weapon":
		detail = "每次攻击 %d  ·  连接加成 +%d" % [ui.game.get_weapon_damage(item), ui.game.get_adjacency_bonus(item)]
	ui._wrapped(detail, Rect2(top.x, y, r.size.x - 44, 54), 16, INK)
	if r.size.y >= 420:
		ui._label("旅 途 笔 记", Vector2(top.x, r.end.y - 87), 13, SOFT_INK)
		var line: String = ui.battle_log[0] if ui.game.phase == "battle" and not ui.battle_log.is_empty() else "把一格留给下一次可能。"
		ui._wrapped(line, Rect2(top.x, r.end.y - 70, r.size.x - 44, 50), 15, INK)

static func draw_recipes(ui) -> void:
	var r: Rect2 = ui.layout.notes_rect
	var content := Rect2(r.position + Vector2(20, 70), Vector2(r.size.x - 40, r.size.y - 128))
	var row_height: float = minf(150.0, (content.size.y - 12) / 2.0)
	for row in range(2):
		var index: int = ui.recipe_page * 2 + row
		var first := "sword"
		var second := "sword"
		var result := "sword"
		var title := "同种同级 → 提升品质"
		if index > 0:
			if index - 1 >= ui.Run.RECIPES.size():
				continue
			var recipe: Dictionary = ui.Run.RECIPES[index - 1]
			first = recipe["first"]
			second = recipe["second"]
			result = recipe["result"]
			title = str(recipe["label"]) + " · " + str(ui.game.get_definition(result)["name"])
		var card := Rect2(content.position + Vector2(0, row * (row_height + 12)), Vector2(content.size.x, row_height))
		ui._frame(card, Color("d4d6bc"), Color("9aa58d"))
		var icon_y: float = card.position.y + maxf(6, (card.size.y - 96) * 0.4)
		var step: float = (card.size.x - 72) / 3.0
		for i in range(3):
			var kind: String = [first, second, result][i]
			ui._icon(kind, Rect2(card.position.x + 12 + i * step, icon_y, 48, 48))
		ui._label("+", Vector2(card.position.x + step - 3, icon_y + 31), 18, SOFT_INK)
		ui._label("→", Vector2(card.position.x + step * 2 - 5, icon_y + 31), 18, INK)
		ui._label(title, Vector2(card.position.x + 12, card.end.y - 13), 14, INK)
	ui._button(ui.layout.recipe_prev_rect, "←", false, 16)
	ui._button(ui.layout.recipe_next_rect, "→", false, 16)
	ui._center("%d / %d · 叠放即时合成" % [ui.recipe_page + 1, ui._recipe_page_count()], Rect2(r.position.x + 75, r.end.y - 46, r.size.x - 150, 30), 14, INK)
