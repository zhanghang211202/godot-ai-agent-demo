extends RefCounted

static func reward(ui) -> void:
	ui.draw_rect(ui.get_modal_overlay_rect(), Color(0.02, 0.045, 0.035, 0.82))
	var r: Rect2 = ui.layout.reward_panel_rect
	ui.Materials.draw_panel(ui, r, "dark")
	ui._center("林间的馈赠", Rect2(r.position + Vector2(20, 20), Vector2(r.size.x - 40, 48)), 30, ui.GOLD)
	ui._center("获得 %d 金币 · 选择一枚祝福，让下一程有所不同" % ui.game.last_reward, Rect2(r.position + Vector2(20, 77), Vector2(r.size.x - 40, 28)), 16, ui.TEXT)
	for index in range(ui.game.reward_choices.size()):
		var blessing: Dictionary = ui.game.get_blessing_definition(ui.game.reward_choices[index])
		var card: Rect2 = ui._reward_rect(index)
		ui.Materials.draw_panel(ui, card, "paper")
		if card.has_point(ui.mouse):
			ui.draw_rect(card.grow(-2), ui.GOLD, false, 3)
		ui._label("0%d" % (index + 1), card.position + Vector2(16, 29), 16, Color("6c694b"))
		ui._icon(blessing.get("icon", "spark"), Rect2(card.get_center().x - 32, card.position.y + 20, 64, 64))
		ui._center(blessing["name"], Rect2(card.position + Vector2(12, 95), Vector2(card.size.x - 24, 32)), 22, Color("34483d"))
		ui._wrapped(blessing["description"], Rect2(card.position + Vector2(22, 141), Vector2(card.size.x - 44, 65)), 16, Color("536351"))
	ui._center("点击卡片，或按 1 / 2 / 3 选择", Rect2(r.position + Vector2(20, 363), Vector2(r.size.x - 40, 28)), 15, ui.MUTED)

static func menu(ui) -> void:
	ui.draw_rect(ui.get_modal_overlay_rect(), Color(0.015, 0.04, 0.03, 0.9))
	var r: Rect2 = ui.layout.menu_panel_rect
	ui.Materials.draw_panel(ui, r, "leather")
	ui._center("火光尚在，旅途待续", Rect2(r.position + Vector2(25, 23), Vector2(r.size.x - 50, 48)), 28, ui.GOLD)
	var subtitle := "歇一歇，听听林间的风。"
	if ui._resume_prompt:
		subtitle = "找到第 %d 场的整装记录。" % int(ui._save_info.get("wave", 1)) if ui._save_info.get("ok", false) else "旧记录无法读取，确认后可开始新远征。"
	ui._center(subtitle, Rect2(r.position + Vector2(24, 85), Vector2(r.size.x - 48, 28)), 16, ui.MUTED)
	var continue_label := "继续上次远征   →" if ui._resume_prompt else "返回当前旅程   →"
	if ui._resume_prompt and not ui._save_info.get("ok", false):
		continue_label = "原记录无法读取，请选择新远征"
	ui._button(ui.MENU_CONTINUE, continue_label, true, 18, ui._resume_prompt and not ui._save_info.get("ok", false))
	ui._button(ui.MENU_SAVE, "保存当前整装   S", false, 16, ui.game.phase not in ["prepare", "reward"] or ui._resume_prompt)
	var load_label := "读取存档 · 第 %d 场 / %d 金币   L" % [ui._save_info.get("wave", 1), ui._save_info.get("gold", 0)] if ui._save_info.get("ok", false) else "尚未留下整装记录"
	ui._button(ui.MENU_LOAD, load_label, false, 16, not ui._save_info.get("ok", false))
	ui._button(ui.MENU_NEW, "再次点击，确认重新出发" if ui._confirm_new_run else "开始新的远征", false, 16)
	ui._center("战斗退出后，从该场开战前继续。", Rect2(r.position + Vector2(24, 402), Vector2(r.size.x - 48, 26)), 14, ui.MUTED)
	ui._center("准备与奖励自动保存 · Esc 返回", Rect2(r.position + Vector2(24, 430), Vector2(r.size.x - 48, 26)), 14, ui.TEAL)
	ui._center(ui._save_status, Rect2(r.position + Vector2(24, 461), Vector2(r.size.x - 48, 22)), 13, ui.RED if "失败" in ui._save_status or "无法" in ui._save_status else ui.MUTED)

static func result(ui) -> void:
	if ui.game.phase == "reward" and not ui.game.reward_chosen:
		reward(ui)
		return
	var stage: Rect2 = ui.layout.battle_rect
	var r := Rect2(stage.get_center() - Vector2(260, 61), Vector2(520, 122))
	ui._frame(r, Color(0.06, 0.13, 0.11, 0.96), ui.RED if ui.game.phase == "lost" else ui.GOLD)
	var title := "抵达星火之地" if ui.game.phase == "won" else ("火光未熄，旅途未尽" if ui.game.phase == "lost" else "这一程，平安归来")
	ui._center(title, Rect2(r.position + Vector2(10, 10), Vector2(500, 42)), 27, ui.RED if ui.game.phase == "lost" else ui.GOLD)
	var line := "五场远征完成！" if ui.game.phase == "won" else ("强化护盾与恢复能力，再来一次。" if ui.game.phase == "lost" else "祝福已收入行囊，准备下一场。")
	ui._center(line, Rect2(r.position + Vector2(10, 58), Vector2(500, 26)), 16, ui.TEXT)
	ui._center("点击出发按钮，或按空格继续", Rect2(r.position + Vector2(10, 91), Vector2(500, 23)), 14, ui.MUTED)

static func help(ui) -> void:
	ui.draw_rect(ui.get_modal_overlay_rect(), Color(0.01, 0.04, 0.03, 0.9))
	var r: Rect2 = ui.layout.help_panel_rect
	ui.Materials.draw_panel(ui, r, "paper")
	var ink := Color("35483e")
	ui._center("每一格，都有新的可能", Rect2(r.position + Vector2(24, 27), Vector2(r.size.x - 48, 50)), 30, ink)
	ui._center("五波森林远征 · 背包构筑与自动战斗", Rect2(r.position + Vector2(24, 88), Vector2(r.size.x - 48, 30)), 17, Color("62705d"))
	var instructions := [
		["购买与摆放", "拖动商店装备到背包；也可点击选购，再点击空格。"],
		["旋转与整理", "R 旋转，点击查看属性，D 出售。右键取消放置。"],
		["合成与协同", "同种同级叠放升级；短剑 + 磨刀石能合成长剑。"],
		["方向与空间", "蓝点指定加成方向，R 可旋转；长剑需要三格空间。"],
		["祝福与旅途记录", "胜利后选择祝福，空格继续；Esc 打开暂停菜单。"],
	]
	for index in range(instructions.size()):
		var y: float = r.position.y + 171 + index * 77
		ui._label("0%d" % (index + 1), Vector2(r.position.x + 35, y), 24, Color("9a6c38"))
		ui._label(instructions[index][0], Vector2(r.position.x + 96, y), 20, ink)
		ui._label(instructions[index][1], Vector2(r.position.x + 96, y + 30), 17, Color("62705d"))
	ui._center("点击任意位置关闭  /  Esc", Rect2(r.position + Vector2(24, 587), Vector2(r.size.x - 48, 30)), 16, ink)
