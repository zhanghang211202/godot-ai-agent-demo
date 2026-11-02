extends RefCounted

static func reward(ui) -> void:
	ui.draw_rect(ui.get_modal_overlay_rect(), Color(0.02, 0.045, 0.035, 0.82))
	var r: Rect2 = ui.layout.reward_panel_rect
	ui.Materials.draw_panel(ui, r, "dark")
	ui._center("森からの贈り物", Rect2(r.position + Vector2(20, 20), Vector2(r.size.x - 40, 48)), 30, ui.GOLD)
	ui._center("%d金貨を獲得 · 祝福をひとつ選ぼう" % ui.game.last_reward, Rect2(r.position + Vector2(20, 77), Vector2(r.size.x - 40, 28)), 16, ui.TEXT)
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
	ui._center("カードをクリック、または 1 / 2 / 3 で選択", Rect2(r.position + Vector2(20, 363), Vector2(r.size.x - 40, 28)), 15, ui.MUTED)

static func menu(ui) -> void:
	ui.draw_rect(ui.get_modal_overlay_rect(), Color(0.015, 0.04, 0.03, 0.9))
	var r: Rect2 = ui.layout.menu_panel_rect
	ui.Materials.draw_panel(ui, r, "leather")
	ui._center("火は消えず、旅は続く", Rect2(r.position + Vector2(25, 23), Vector2(r.size.x - 50, 48)), 28, ui.GOLD)
	var subtitle := "ひと休みして森の風を聴こう。"
	if ui._resume_prompt:
		subtitle = "第%d戦の準備データがあります。" % int(ui._save_info.get("wave", 1)) if ui._save_info.get("ok", false) else "旧データを読めません。確認後に新しい遠征を開始できます。"
	ui._center(subtitle, Rect2(r.position + Vector2(24, 85), Vector2(r.size.x - 48, 28)), 16, ui.MUTED)
	var continue_label := "前回の遠征を続ける   →" if ui._resume_prompt else "旅に戻る   →"
	if ui._resume_prompt and not ui._save_info.get("ok", false):
		continue_label = "旧データを読めません。新しい遠征を選択してください"
	ui._button(ui.MENU_CONTINUE, continue_label, true, 18, ui._resume_prompt and not ui._save_info.get("ok", false))
	ui._button(ui.MENU_SAVE, "準備を保存   S", false, 16, ui.game.phase not in ["prepare", "reward"] or ui._resume_prompt)
	var load_label := "データ読込 · 第%d戦 / %d金貨   L" % [ui._save_info.get("wave", 1), ui._save_info.get("gold", 0)] if ui._save_info.get("ok", false) else "準備データはありません"
	ui._button(ui.MENU_LOAD, load_label, false, 16, not ui._save_info.get("ok", false))
	ui._button(ui.MENU_NEW, "もう一度クリックして再出発" if ui._confirm_new_run else "新しい遠征を始める", false, 16)
	ui._center("戦闘を中断すると、戦前から再開します。", Rect2(r.position + Vector2(24, 402), Vector2(r.size.x - 48, 26)), 14, ui.MUTED)
	ui._center("準備と報酬を自動保存 · Esc で戻る", Rect2(r.position + Vector2(24, 430), Vector2(r.size.x - 48, 26)), 14, ui.TEAL)
	ui._center(ui._save_status, Rect2(r.position + Vector2(24, 461), Vector2(r.size.x - 48, 22)), 13, ui.RED if "失敗" in ui._save_status or "できません" in ui._save_status else ui.MUTED)

static func result(ui) -> void:
	if ui.game.phase == "reward" and not ui.game.reward_chosen:
		reward(ui)
		return
	var stage: Rect2 = ui.layout.battle_rect
	var r := Rect2(stage.get_center() - Vector2(260, 61), Vector2(520, 122))
	ui._frame(r, Color(0.06, 0.13, 0.11, 0.96), ui.RED if ui.game.phase == "lost" else ui.GOLD)
	var title := "星火の地へ到着" if ui.game.phase == "won" else ("火は消えず、旅は続く" if ui.game.phase == "lost" else "無事に帰還")
	ui._center(title, Rect2(r.position + Vector2(10, 10), Vector2(500, 42)), 27, ui.RED if ui.game.phase == "lost" else ui.GOLD)
	var line := "5戦の遠征を完了！" if ui.game.phase == "won" else ("盾と回復を強化して再挑戦。" if ui.game.phase == "lost" else "祝福を得ました。次の戦いに備えよう。")
	ui._center(line, Rect2(r.position + Vector2(10, 58), Vector2(500, 26)), 16, ui.TEXT)
	ui._center("出発ボタンか Space で続ける", Rect2(r.position + Vector2(10, 91), Vector2(500, 23)), 14, ui.MUTED)

static func help(ui) -> void:
	ui.draw_rect(ui.get_modal_overlay_rect(), Color(0.01, 0.04, 0.03, 0.9))
	var r: Rect2 = ui.layout.help_panel_rect
	ui.Materials.draw_panel(ui, r, "paper")
	var ink := Color("35483e")
	ui._center("ひとマスごとに、新たな可能性", Rect2(r.position + Vector2(24, 27), Vector2(r.size.x - 48, 50)), 30, ink)
	ui._center("森を巡る5戦 · バッグ構築と自動戦闘", Rect2(r.position + Vector2(24, 88), Vector2(r.size.x - 48, 30)), 17, Color("62705d"))
	var instructions := [
		["購入と配置", "装備をバッグにドラッグ、または選んで空きマスをクリック。"],
		["回転と整理", "R で回転、クリックで詳細、D で売却。右クリックで取消。"],
		["合成と接続", "同じ装備を重ねて強化。短剣と砥石から長剣を作れる。"],
		["方向と空間", "青点が強化方向。R で回転。長剣は3マス必要。"],
		["祝福と旅の記録", "勝利後に祝福を選び、Space で続行。Esc でメニュー。"],
	]
	for index in range(instructions.size()):
		var y: float = r.position.y + 171 + index * 77
		ui._label("0%d" % (index + 1), Vector2(r.position.x + 35, y), 24, Color("9a6c38"))
		ui._label(instructions[index][0], Vector2(r.position.x + 96, y), 20, ink)
		ui._label(instructions[index][1], Vector2(r.position.x + 96, y + 30), 17, Color("62705d"))
	ui._center("クリックして閉じる  /  Esc", Rect2(r.position + Vector2(24, 587), Vector2(r.size.x - 48, 30)), 16, ink)
