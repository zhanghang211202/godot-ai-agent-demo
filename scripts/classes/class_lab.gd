extends Control
## Playable C0 laboratory. A separate scene/save keeps the forest sample intact.

const RunRules = preload("res://scripts/classes/class_run.gd")
const Catalog = preload("res://scripts/classes/class_catalog.gd")
const BattleRules = preload("res://scripts/classes/class_battle.gd")
const Save = preload("res://scripts/classes/class_save.gd")
const GridView = preload("res://scripts/classes/class_grid.gd")
const ArenaView = preload("res://scripts/classes/class_arena.gd")
const MageArt = preload("res://scripts/classes/mage_art.gd")
const Encounters = preload("res://scripts/classes/mage_encounters.gd")
const RecipeGuide = preload("res://scripts/classes/mage_recipe_guide.gd")
const Rehearsal = preload("res://scripts/classes/mage_rehearsal.gd")
const Campaign = preload("res://scripts/classes/mage_campaign.gd")
const CampaignSave = preload("res://scripts/classes/mage_campaign_save.gd")

@export var mage_focus := false
@export var campaign_focus := false

var run = RunRules.new()
var battle = BattleRules.new()
var grid
var arena
var held: Dictionary = {}
var selected_uid := -1
var source_buttons: Array[Button] = []
var class_buttons: Dictionary = {}
var status_label: Label
var resources_label: Label
var carrier_label: Label
var detail_label: Label
var recipe_label: Label
var phase_label: Label
var primary_button: Button
var pause_button: Button
var speed_button: Button
var save_button: Button
var load_button: Button
var discard_button: Button
var rotate_button: Button
var undo_button: Button
var replay_button: Button
var rehearsal_button: Button
var workspace_button: Button
var workspace_panel: HBoxContainer
var summary_label: Label
var preview_label: Label
var detail_icon: TextureRect
var details_scroll: ScrollContainer
var details_content: VBoxContainer
var _rehearsal_signature := ""
var _undo_items: Array[Dictionary] = []
var _undo_signature := ""
var speed := 1.0
var encounter_id := "sentinel"
var encounter_selector: OptionButton
var campaign_stage_label: Label
var campaign_stage := 0
var recipe_button: Button
var condense_button: Button
var source_scroll: ScrollContainer
var recipe_overlay: ColorRect
var recipe_cards: Array[Button] = []
var recipe_close_button: Button
var persistence_enabled := true
@export var checkpoint_path := Save.DEFAULT_PATH
@export var campaign_checkpoint_path := CampaignSave.DEFAULT_PATH
var _capture_directory := ""
var _capture_class := "mage"
var _capture_done := false
var _auto_quit := false
var _capture_prepare_only := false
var _capture_sword := false
var _capture_loss := false
var _capture_tide_focus := false
var _capture_build := "baseline"
var _capture_no_ward := false
var _original_alpha_comparison := false
var _ready_frames := 0
var _last_phase := "idle"

func _ready() -> void:
	get_window().title = "月庭の魔術師 · 五つの試練" if campaign_focus else "月庭の魔術師の試練" if mage_focus else "職業ビルドの試練"
	for argument in OS.get_cmdline_user_args():
		if argument == "--no-save":
			persistence_enabled = false
		elif argument.begins_with("--capture-dir="):
			_capture_directory = argument.trim_prefix("--capture-dir=")
			persistence_enabled = false
		elif argument.begins_with("--class="):
			_capture_class = argument.trim_prefix("--class=")
		elif argument == "--auto-quit":
			_auto_quit = true
		elif argument == "--capture-prepare-only":
			_capture_prepare_only = true
		elif argument == "--capture-sword":
			_capture_sword = true
		elif argument == "--capture-loss":
			_capture_loss = true
		elif argument == "--capture-tide-focus":
			_capture_tide_focus = true
		elif argument == "--capture-no-ward":
			_capture_no_ward = true
		elif argument.begins_with("--capture-build="):
			_capture_build = argument.trim_prefix("--capture-build=")
		elif argument.begins_with("--encounter="):
			var selected := argument.trim_prefix("--encounter=")
			if selected in Encounters.IDS:
				encounter_id = selected
		elif argument == "--compare-original-alpha":
			_original_alpha_comparison = true
	_build_interface()
	resized.connect(_resize_layout)
	_resize_layout()
	_new_class("mage" if mage_focus else _capture_class if _capture_class in Catalog.CLASS_IDS else "mage")
	if campaign_focus and persistence_enabled and FileAccess.file_exists(campaign_checkpoint_path):
		_load()

func _build_interface() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	ui_theme.default_font_size = 17
	ui_theme.set_color("font_color", "Label", Color("dce2ed"))
	ui_theme.set_color("font_color", "Button", Color("e4e7ef"))
	ui_theme.set_stylebox("normal", "Button", _style(Color("283348"), Color("516077")))
	ui_theme.set_stylebox("hover", "Button", _style(Color("37455e"), Color("bca4e5")))
	ui_theme.set_stylebox("pressed", "Button", _style(Color("47415e"), Color("d4b8ff")))
	ui_theme.set_stylebox("disabled", "Button", _style(Color("202735"), Color("333d4e")))
	ui_theme.set_stylebox("panel", "PanelContainer", _style(Color("1c2534"), Color("3c485d")))
	theme = ui_theme
	var background := ColorRect.new()
	background.color = Color("101722")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var heading := _label("月庭の魔術師 · 五つの試練" if campaign_focus else "月庭の魔術師の試練" if mage_focus else "職業ビルドの試練", 25)
	if mage_focus:
		heading.add_theme_color_override("font_color", Color("e2d3ff"))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	if campaign_focus:
		campaign_stage_label = _label("", 19, Color("e5c783"))
		header.add_child(campaign_stage_label)
	elif mage_focus:
		encounter_selector = OptionButton.new()
		encounter_selector.custom_minimum_size = Vector2(205, 42)
		for id in Encounters.IDS:
			encounter_selector.add_item(str(Encounters.definition(id).name))
		encounter_selector.item_selected.connect(func(index: int): _select_encounter(Encounters.IDS[index]))
		header.add_child(encounter_selector)
	for id in Catalog.CLASS_IDS:
		if mage_focus and id != "mage":
			continue
		var b := _button("魔術師で開始" if id == "mage" else "騎士 H で開始", func(): _new_class(id))
		if mage_focus:
			b.text = "最初から" if campaign_focus else "魔術師の試練をやり直す"
		header.add_child(b)
		class_buttons[id] = b
	var notice := _label("敵の魔力残滓を集め、素材を凝結 → 魔法を紡ぐ → 次の戦いへ · 戦前に自動保存" if campaign_focus else "元素を吸収 → 魔法を紡ぐ → 結晶核・法盾を配置 → 敵を選ぶ" if mage_focus else "C1 戦闘演出サンプル · ダメージ / 防御 / 被弾 / フェード", 15, Color("b6acc5"))
	root.add_child(notice)
	arena = ArenaView.new()
	arena.run = run
	arena.battle = battle
	arena.pixel_cutout_enabled = not _original_alpha_comparison
	arena.mage_motion_variants_enabled = mage_focus
	if mage_focus:
		arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(arena)
	var body := HBoxContainer.new()
	workspace_panel = body
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_FILL if mage_focus else Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var inventory := _panel(body, 440, 1.35)
	carrier_label = _label("", 22)
	if mage_focus:
		var carrier_header := HBoxContainer.new()
		inventory.add_child(carrier_header)
		carrier_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		carrier_header.add_child(carrier_label)
		undo_button = _button("戻す", _undo_placement)
		undo_button.tooltip_text = "盤内の移動・回転・合成を1手戻します。吸収・凝結・廃棄・戦闘は戻せず、読み込みで履歴は消えます。Ctrl+Z"
		carrier_header.add_child(undo_button)
	else:
		inventory.add_child(carrier_label)
	grid = GridView.new()
	grid.run = run
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.cell_selected.connect(_on_cell_selected)
	grid.drop_requested.connect(_on_drop)
	grid.drag_started.connect(_on_drag_started)
	grid.preview_changed.connect(_show_placement_preview)
	inventory.add_child(grid)
	inventory.add_child(_label("ドラッグ · R 回転 · 右クリック取消  /  青：配置 · 金：合成", 14, Color("a7b4c5")))
	if not mage_focus:
		inventory.add_child(_label("赤：配置不可", 14, Color("a7b4c5")))
	var source_column := _panel(body, 270, 0.8)
	var source_heading := HBoxContainer.new()
	source_column.add_child(source_heading)
	resources_label = _label("", 20)
	resources_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_heading.add_child(resources_label)
	if mage_focus:
		recipe_button = _button("レシピ", _open_recipe_book)
		recipe_button.custom_minimum_size = Vector2(70, 38)
		recipe_button.tooltip_text = "%d種類の組み合わせを見て素材を選ぶ" % Catalog.recipes_for("mage").size()
		source_heading.add_child(recipe_button)
	if campaign_focus:
		condense_button = _button("凝結", _show_condense)
		condense_button.custom_minimum_size = Vector2(60, 38)
		condense_button.tooltip_text = "魔力残滓を元素や道具に変える一覧へ"
		source_heading.add_child(condense_button)
	source_scroll = ScrollContainer.new()
	source_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	source_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	source_column.add_child(source_scroll)
	var source_list := VBoxContainer.new()
	source_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_list.add_theme_constant_override("separation", 10)
	source_scroll.add_child(source_list)
	for index in range(9 if campaign_focus else 3):
		if campaign_focus and index == 3:
			source_list.add_child(_label("魔力残滓で凝結", 19, Color("e4cf9d")))
		var b := _button("", func(): _select_source(index))
		b.custom_minimum_size.y = 62
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.set_drag_forwarding(func(at: Vector2): return _source_drag(index, at), Callable(), Callable())
		source_buttons.append(b)
		source_list.add_child(b)
	source_list.add_child(_label("組み合わせ", 19))
	recipe_label = _label("", 16, Color("c9bbdf"))
	recipe_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source_list.add_child(recipe_label)
	var details := _panel(body, 285, 0.9)
	phase_label = _label("", 20)
	if campaign_focus:
		var phase_header := HBoxContainer.new()
		details.add_child(phase_header)
		phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		phase_header.add_child(phase_label)
		rehearsal_button = _button("予行演習", _rehearse)
		rehearsal_button.tooltip_text = "この敵との戦闘を試算。報酬や素材の消費はありません。"
		phase_header.add_child(rehearsal_button)
	else:
		details.add_child(phase_label)
	details_scroll = ScrollContainer.new()
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details.add_child(details_scroll)
	details_content = VBoxContainer.new()
	details_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_content.add_theme_constant_override("separation", 14)
	details_scroll.add_child(details_content)
	preview_label = _label("", 15, Color("e8c891"))
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.visible = false
	details_content.add_child(preview_label)
	detail_icon = TextureRect.new()
	detail_icon.custom_minimum_size = Vector2(52, 52)
	detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_icon.visible = false
	details_content.add_child(detail_icon)
	detail_label = _label("", 17)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_content.add_child(detail_label)
	summary_label = _label("", 16, Color("a8d7cb"))
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_content.add_child(summary_label)
	var item_actions := HBoxContainer.new()
	details.add_child(item_actions)
	rotate_button = _button("回転 R", _rotate)
	discard_button = _button("捨てる（返却なし）", _discard)
	item_actions.add_child(rotate_button)
	item_actions.add_child(discard_button)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	root.add_child(footer)
	save_button = _button("準備を保存", _save)
	load_button = _button("データ読込", _load)
	replay_button = _button("戦前に戻す", _restore_before_battle)
	footer.add_child(save_button)
	footer.add_child(load_button)
	footer.add_child(replay_button)
	pause_button = _button("一時停止", _pause)
	speed_button = _button("1×", _speed)
	footer.add_child(pause_button)
	footer.add_child(speed_button)
	if mage_focus and not campaign_focus:
		rehearsal_button = _button("予行演習", _rehearse)
		rehearsal_button.tooltip_text = "現在の配置で3種類の敵と仮想戦闘。素材や保存データは変わりません。"
		footer.add_child(rehearsal_button)
	if mage_focus:
		workspace_button = _button("盤面を畳む", _toggle_workspace)
		workspace_button.tooltip_text = "戦闘舞台を広く表示します。再度押すと盤面を表示します。"
		footer.add_child(workspace_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	primary_button = _button("戦闘開始  /  Space", _primary_action)
	primary_button.custom_minimum_size.x = 245
	if mage_focus:
		primary_button.add_theme_stylebox_override("normal", _style(Color("544374"), Color("d9bd83")))
		primary_button.add_theme_stylebox_override("hover", _style(Color("6a538e"), Color("f3dca8")))
		primary_button.add_theme_stylebox_override("pressed", _style(Color("41345c"), Color("e6c882")))
	footer.add_child(primary_button)
	status_label = _label("", 16, Color("dfc394"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 38
	root.add_child(status_label)
	if mage_focus:
		_build_recipe_book()

func _build_recipe_book() -> void:
	recipe_overlay = ColorRect.new()
	recipe_overlay.color = Color(0.025, 0.035, 0.075, 0.82)
	recipe_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	recipe_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	recipe_overlay.visible = false
	add_child(recipe_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recipe_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(850, 0)
	panel.add_theme_stylebox_override("panel", _style(Color("1c2539"), Color("b5a0d9")))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := _label("元素の紡ぎ方", 25, Color("e7dcff"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	recipe_close_button = _button("閉じる", _close_recipe_book)
	recipe_close_button.custom_minimum_size = Vector2(78, 40)
	heading.add_child(recipe_close_button)
	var hint := _label("魔法を選ぶと、合成できる素材が金枠で表示されます。赤枠は空き不足です。", 16, Color("b9c7d8"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	var cards := GridContainer.new()
	cards.columns = 2
	cards.add_theme_constant_override("h_separation", 12)
	cards.add_theme_constant_override("v_separation", 10)
	column.add_child(cards)
	for index in range(Catalog.recipes_for("mage").size()):
		var card := _button("", func(): _choose_recipe(index))
		card.custom_minimum_size = Vector2(0, 94)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.expand_icon = true
		card.add_theme_constant_override("icon_max_width", 56)
		card.add_theme_font_size_override("font_size", 16)
		recipe_cards.append(card)
		cards.add_child(card)
	var footer := _label("素材数には盤上の未合成素材も含みます。選択時には消費しません。Esc で閉じる。", 14, Color("9eb0c5"))
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(footer)

func _open_recipe_book() -> void:
	if not mage_focus or run.phase != "prepare" or recipe_overlay == null:
		return
	_refresh_recipe_book()
	recipe_overlay.visible = true
	for card in recipe_cards:
		if not card.disabled:
			card.grab_focus()
			return
	recipe_close_button.grab_focus()

func _show_condense() -> void:
	if campaign_focus and source_buttons.size() > 3:
		source_scroll.ensure_control_visible(source_buttons[3])

func _close_recipe_book() -> void:
	if recipe_overlay != null:
		recipe_overlay.visible = false

func _refresh_recipe_book() -> void:
	if recipe_overlay == null:
		return
	var recipes: Array[Dictionary] = Catalog.recipes_for("mage")
	for index in range(recipes.size()):
		var recipe: Dictionary = recipes[index]
		var definition: Dictionary = Catalog.definition(recipe.result)
		var available: Dictionary = RecipeGuide.availability(run, recipe)
		var route: Dictionary = RecipeGuide.plan(run, recipe)
		var first: Dictionary = Catalog.definition(recipe.first)
		var second: Dictionary = Catalog.definition(recipe.second)
		var counts := "%s %d / 2" % [first.name, available.counts[recipe.first]] if recipe.first == recipe.second else "%s %d · %s %d" % [first.name, available.counts[recipe.first], second.name, available.counts[recipe.second]]
		var status := counts if available.available else "先に%sを紡ぐ" % Catalog.definition(route.prerequisite.result).name if route.available else "魔力残滓が不足" if route.insufficient_funds else "不足：" + "、".join(route.missing.map(func(kind): return str(Catalog.definition(kind).name)))
		var card: Button = recipe_cards[index]
		card.text = "%s\n%d×%d マス · %d×%d回 / %.1f秒\n%s" % [recipe.label, definition.size.x, definition.size.y, definition.damage, definition.hits, definition.interval, status]
		card.icon = MageArt.icon(str(recipe.result)).get("atlas", null)
		card.disabled = not route.available
		card.tooltip_text = str(definition.description)

func _choose_recipe(index: int) -> void:
	var recipes: Array[Dictionary] = Catalog.recipes_for("mage")
	if recipe_overlay == null or not recipe_overlay.visible or run.phase != "prepare" or index < 0 or index >= recipes.size():
		return
	var choice: Dictionary = RecipeGuide.choose_planned(run, recipes[index])
	if not choice.ok:
		_notice("素材が足りません。配置を見直しましょう。")
		_refresh_recipe_book()
		return
	_close_recipe_book()
	held = choice.held.duplicate(true)
	selected_uid = int(held.uid) if held.origin == "bag" else -1
	grid.held = held
	if choice.needs_placement:
		_notice("まず%sを空きマスに置き、%sを重ねます。" % [Catalog.definition(choice.first_kind).name, Catalog.definition(choice.next_kind).name])
	elif not choice.preview.ok:
		_notice("%s：素材を移動するか R で回転できます。" % str(choice.preview.message))
	else:
		var target: Dictionary = run.item_by_uid(int(choice.target_uid))
		var rotation_note := "（回転済み）" if bool(choice.get("auto_rotated", false)) else ""
		_notice("素材%sを選択。金枠の%sをクリックして%sを紡ぎます。" % [rotation_note, Catalog.definition(target.kind).name, Catalog.definition(choice.product).name])
	if choice.has("prerequisite"):
		_notice("まず%sを紡ぎ、次にレシピから%sを選びます。%s" % [Catalog.definition(choice.prerequisite).name, Catalog.definition(choice.final_product).name, status_label.text])
	_sync()

func _panel(parent: Control, minimum_width: float, ratio: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = minimum_width
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 10)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	return column

func _label(text: String, point_size: int, color: Color = Color("dce2ed")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.pressed.connect(callback)
	return button

func _style(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

func _new_class(id: String) -> void:
	if mage_focus and id != "mage":
		_notice("魔術師の試練です。")
		return
	if run.phase == "battle":
		_notice("戦闘中は職業を変更できません。戦闘を終えるか戦前に戻してください。")
		return
	_close_recipe_book()
	_set_workspace_open(true)
	_rehearsal_signature = ""
	details_content.move_child(summary_label, details_content.get_child_count() - 1)
	grid.clear_merge_feedback()
	var result: Dictionary = run.new_run(id, 12345)
	if not result.ok:
		_notice(str(result.message))
		return
	_clear_undo()
	if campaign_focus:
		campaign_stage = 0
		encounter_id = Campaign.encounter(campaign_stage)
		run.sources.append_array(Campaign.shop_sources())
	battle = BattleRules.new()
	_before_battle = {}
	arena.battle = battle
	arena.reset_presentation()
	_clear_selection()
	summary_label.text = "五戦を踏破しよう。勝利で魔力残滓を獲得し、凝結欄で元素や道具に変換できます。各戦後HP全回復。戦前に自動保存します。" if campaign_focus else "まず火 + 微光、次に水 + 風を試そう。\n結晶核は左右の術式に各段+2。R で上下に回転。\n戦後は戦前の配置に戻せます。元素は有限、廃棄すると戻りません。" if mage_focus else "この試作は一戦のみ。\n素材は有限で補充されず、廃棄しても返却されません。"
	grid.active_sources.clear()
	_notice("魔術師：火を選んで微光に重ねると爆炎に。水と風は3連撃になります。" if id == "mage" else "騎士：溜めの紋章を長剣に重ねて大剣を鍛造。紋章を残して強化も可能。")
	_sync()
	grid.update_preview()

func _select_source(index: int) -> void:
	if run.phase != "prepare":
		return
	if index < 0 or index >= run.sources.size() or int(run.sources[index].remaining) <= 0 or run.gold < int(run.sources[index].cost):
		_notice("この素材は現在取得できません。")
		return
	held = {"origin": "source", "index": index, "rotated": false}
	selected_uid = -1
	grid.held = held
	var definition: Dictionary = run.get_definition(run.sources[index].kind)
	_notice("%sを選択：空きマスに置くか、対応素材に重ねます。R で回転。" % definition.name)
	_sync()
	grid.update_preview()

func _select_encounter(id: String) -> void:
	if not mage_focus or campaign_focus or run.phase != "prepare" or id not in Encounters.IDS:
		return
	encounter_id = id
	arena.encounter_id = id
	arena.reset_presentation()
	_notice(str(Encounters.definition(id).hint))
	_sync()

func _source_drag(index: int, _at: Vector2) -> Variant:
	if run.phase != "prepare" or index < 0 or index >= run.sources.size():
		return null
	if int(run.sources[index].remaining) <= 0 or run.gold < int(run.sources[index].cost):
		return null
	_select_source(index)
	return held.duplicate()

func _on_drag_started(data: Dictionary) -> void:
	if run.phase != "prepare" or str(data.get("origin", "")) != "bag":
		return
	var item: Dictionary = run.item_by_uid(int(data.get("uid", -1)))
	if item.is_empty():
		return
	held = data.duplicate(true)
	selected_uid = int(item.uid)
	grid.held = held
	_sync()

func _on_cell_selected(cell: Vector2i) -> void:
	if run.phase != "prepare":
		return
	if not held.is_empty():
		_on_drop(held, cell)
		return
	var item: Dictionary = run.item_at(cell)
	selected_uid = int(item.get("uid", -1))
	if not item.is_empty():
		held = {"origin": "bag", "uid": item.uid, "rotated": item.rotated}
	grid.held = held
	_sync()
	grid.update_preview()

func _on_drop(data: Dictionary, cell: Vector2i) -> void:
	var result: Dictionary
	var prior_items: Array[Dictionary] = []
	var owned := str(data.get("origin", "")) == "bag"
	if mage_focus and owned:
		prior_items.assign(run.items.duplicate(true))
	var rotated: bool = bool(data.get("rotated", false))
	# Native Godot drag data is a snapshot. R updates the active held item;
	# apply that orientation only when this drop is the same source/item.
	if not held.is_empty() and held.get("origin") == data.get("origin"):
		var identity_key := "index" if str(data.get("origin")) == "source" else "uid"
		if held.get(identity_key, -1) == data.get(identity_key, -2):
			rotated = bool(held.get("rotated", false))
	if str(data.get("origin", "")) == "source":
		result = run.acquire(int(data.get("index", -1)), cell, rotated)
	else:
		result = run.move(int(data.get("uid", -1)), cell, rotated)
	_notice(str(result.message))
	if result.ok:
		if mage_focus and owned and prior_items != run.items:
			_undo_items.assign(prior_items)
			_undo_signature = _undo_state_signature()
		elif mage_focus and not owned:
			_clear_undo()
		_clear_selection()
		if mage_focus and str(result.event) == "merge":
			grid.show_merge_feedback(int(result.uid))
	_sync()
	if result.ok:
		_autosave_campaign_change()

func _rotate() -> void:
	if run.phase != "prepare":
		return
	if not held.is_empty():
		held.rotated = not bool(held.get("rotated", false))
		grid.held = held
		_notice("配置するものを回転しました。マスをクリックして確定。")
		_sync()

func _discard() -> void:
	if selected_uid < 0:
		return
	var result: Dictionary = run.discard(selected_uid)
	_notice(str(result.message))
	if result.ok:
		_clear_undo()
		_clear_selection()
	_sync()
	if result.ok:
		_autosave_campaign_change()

func _undo_state_signature() -> String:
	return JSON.stringify([run.class_id, run.items, run.sources, run.gold, run.hp, run.max_hp, run._next_uid, run.discarded_materials, run.phase, campaign_stage, encounter_id])

func _clear_undo() -> void:
	_undo_items.clear()
	_undo_signature = ""

func _undo_placement() -> void:
	if not mage_focus or run.phase != "prepare" or _undo_signature.is_empty() or (recipe_overlay != null and recipe_overlay.visible):
		return
	if _undo_signature != _undo_state_signature():
		_clear_undo()
		_notice("準備状態が変わったため元に戻せません。")
		_sync()
		return
	run.items.assign(_undo_items.duplicate(true))
	_clear_undo()
	_clear_selection()
	grid.clear_merge_feedback()
	_notice("直前の盤内操作を元に戻しました。")
	_sync()
	_autosave_campaign_change()

func _clear_selection() -> void:
	held = {}
	selected_uid = -1
	if grid != null:
		grid.held = {}
		grid.selected_uid = -1
		grid.recipe_hints.clear()
		if run.phase != "battle":
			grid.active_sources.clear()
		grid.update_preview()

func _autosave_campaign_change() -> void:
	if not campaign_focus or not persistence_enabled or run.phase != "prepare":
		return
	var result: Dictionary = CampaignSave.save_run(run, campaign_stage, campaign_checkpoint_path)
	if not result.ok:
		_notice("配置は変更されましたが保存できません：" + str(result.message))

func _save() -> bool:
	if not persistence_enabled:
		_notice("検証・撮影モードではプレイヤーのデータを保存しません。")
		return false
	var final_victory: bool = campaign_focus and run.phase == "won" and campaign_stage == Encounters.CAMPAIGN_IDS.size() - 1
	var result: Dictionary = CampaignSave.save_run(run, campaign_stage, campaign_checkpoint_path, final_victory, battle.hp if final_victory else 0) if campaign_focus else Save.save_run(run, checkpoint_path)
	_notice(str(result.message))
	return bool(result.ok)

func _load() -> void:
	if not persistence_enabled:
		_notice("検証・撮影モードではプレイヤーのデータを読みません。")
		return
	if run.phase == "battle":
		_notice("戦闘中はデータを読み込めません。")
		return
	if mage_focus and not campaign_focus:
		var info: Dictionary = Save.inspect_save(checkpoint_path)
		if not info.ok or str(info.get("class_id", "")) != "mage":
			_notice(str(info.message) if not info.ok else "このデータは魔術師用ではありません。現在の準備は変更されません。")
			return
	var result: Dictionary = CampaignSave.load_run(run, campaign_checkpoint_path) if campaign_focus else Save.load_run(run, checkpoint_path)
	_notice(str(result.message))
	if result.ok:
		_clear_undo()
		if campaign_focus:
			campaign_stage = int(result.stage)
			encounter_id = Campaign.encounter(campaign_stage)
		_set_workspace_open(true)
		_rehearsal_signature = ""
		details_content.move_child(summary_label, details_content.get_child_count() - 1)
		battle = BattleRules.new()
		if campaign_focus and bool(result.get("completed", false)):
			battle.start(run.get_combat_config(), encounter_id)
			battle.phase = "won"
			battle.hp = int(result.completed_hp)
			battle.enemy_hp = 0
			run.phase = "won"
		_before_battle = {}
		arena.battle = battle
		arena.reset_presentation()
		if campaign_focus and bool(result.get("completed", false)):
			arena.feedback.outcome = "won"
			arena.feedback.enemy_exit = 1.0
		grid.clear_merge_feedback()
		_clear_selection()
		summary_label.text = "五つの試練を踏破した記録です。「最初から」で新しい遠征を始められます。" if campaign_focus and bool(result.get("completed", false)) else "遠征の準備を復元しました。戦闘はこの戦いの最初から始まります。" if campaign_focus else "準備時の状態を復元しました。旧版の遠征データは別扱いです。"
	_sync()

func _resize_layout() -> void:
	if arena != null:
		arena.custom_minimum_size.y = 350 if size.y >= 900 else 280
	if grid != null:
		grid.custom_minimum_size.y = (200 if size.y >= 900 else 164) if mage_focus else (230 if size.y >= 900 else 184)

func _set_workspace_open(open: bool) -> void:
	if not mage_focus or workspace_panel == null:
		return
	workspace_panel.visible = open
	workspace_button.text = "盤面を畳む" if open else "盤面を開く"

func _toggle_workspace() -> void:
	_set_workspace_open(not workspace_panel.visible)

var _before_battle: Dictionary = {}

func _primary_action() -> void:
	if campaign_focus and run.phase == "won":
		_advance_campaign()
	else:
		_start_battle()

func _advance_campaign() -> void:
	if not campaign_focus or run.phase != "won" or campaign_stage + 1 >= Encounters.CAMPAIGN_IDS.size():
		return
	_clear_undo()
	campaign_stage += 1
	encounter_id = Campaign.encounter(campaign_stage)
	run.hp = run.max_hp
	run.phase = "prepare"
	battle = BattleRules.new()
	arena.battle = battle
	arena.reset_presentation()
	_before_battle = {}
	grid.clear_merge_feedback()
	_set_workspace_open(true)
	_clear_selection()
	summary_label.text = "次の戦いに備えよう。HPは全回復、配置・元素・魔力残滓は引き継ぎます。凝結欄はスクロールできます。"
	if not persistence_enabled or _save():
		_notice("第%d戦：%s。魔力残滓で道具を凝結できます。" % [campaign_stage + 1, Encounters.definition(encounter_id).name])
	_sync()

func _start_battle() -> void:
	if run.phase != "prepare" or (recipe_overlay != null and recipe_overlay.visible):
		return
	var config: Dictionary = run.get_combat_config()
	# Validate a separate engine before persisting or changing the preparation state.
	var candidate = BattleRules.new()
	var result: Dictionary = candidate.start(config, encounter_id if mage_focus else "sentinel")
	if not result.ok:
		_notice(str(result.message))
		return
	if persistence_enabled and not _save():
		return
	_clear_undo()
	_before_battle = {"class_id": run.class_id, "items": run.items.duplicate(true), "sources": run.sources.duplicate(true), "gold": run.gold, "hp": run.hp, "max_hp": run.max_hp, "seed_value": run.seed_value, "next_uid": run._next_uid, "discarded": run.discarded_materials.duplicate(true)}
	_rehearsal_signature = ""
	details_content.move_child(summary_label, details_content.get_child_count() - 1)
	battle = candidate
	arena.battle = battle
	arena.reset_presentation()
	grid.clear_merge_feedback()
	run.phase = "battle"
	_set_workspace_open(false)
	_last_phase = "battle"
	_clear_selection()
	_notice("戦闘開始。停止や 1× / 2× の切り替えができます。")
	_sync()

func _restore_before_battle() -> void:
	if _before_battle.is_empty():
		_notice("今回の戦前データはありません。以前の保存データを読めます。")
		return
	_clear_undo()
	_set_workspace_open(true)
	run.new_run(str(_before_battle.class_id), int(_before_battle.seed_value))
	_rehearsal_signature = ""
	details_content.move_child(summary_label, details_content.get_child_count() - 1)
	run.items.assign(_before_battle.items.duplicate(true))
	run.sources.assign(_before_battle.sources.duplicate(true))
	run.gold = int(_before_battle.gold)
	run.hp = int(_before_battle.hp)
	run.max_hp = int(_before_battle.max_hp)
	run._next_uid = int(_before_battle.next_uid)
	run.discarded_materials = _before_battle.discarded.duplicate(true)
	battle = BattleRules.new()
	arena.battle = battle
	arena.reset_presentation()
	grid.clear_merge_feedback()
	_clear_selection()
	summary_label.text = "戦前の配置に戻りました。素材は追加・補充されません。"
	if not campaign_focus or not persistence_enabled or _save():
		_notice("戦前に戻りました。配置を調整して再挑戦できます。")
	_sync()

func _save_next_campaign_preparation() -> Dictionary:
	# A victory remains on screen, but the checkpoint represents the next
	# preparation. Work on an isolated copy; never mutate the displayed battle.
	var next = RunRules.new()
	next.new_run("mage", run.seed_value)
	next.items.assign(run.items.duplicate(true))
	next.sources.assign(run.sources.duplicate(true))
	next.gold = run.gold
	next.hp = run.max_hp
	next.max_hp = run.max_hp
	next._next_uid = run._next_uid
	next.discarded_materials = run.discarded_materials.duplicate(true)
	return CampaignSave.save_run(next, campaign_stage + 1, campaign_checkpoint_path)

func _pause() -> void:
	if battle.phase == "battle":
		battle.paused = not battle.paused
		_sync()

func _speed() -> void:
	speed = 2.0 if speed == 1.0 else 1.0
	_sync()

func _notice(message: String) -> void:
	if status_label != null:
		status_label.text = message

func _rehearsal_state_signature() -> String:
	# Include even unused raw elements: any committed layout edit invalidates the
	# visible forecast, while selecting/rotating a held preview does not.
	return JSON.stringify([run.class_id, run.items, run.sources, run.gold, run.hp, run.max_hp, encounter_id if campaign_focus else "", campaign_stage if campaign_focus else -1])

func _rehearse() -> void:
	if not mage_focus or run.phase != "prepare" or (recipe_overlay != null and recipe_overlay.visible):
		return
	var result: Dictionary = Rehearsal.simulate(run, [encounter_id] if campaign_focus else Encounters.IDS)
	if not result.ok:
		_notice(str(result.message))
		return
	var lines: PackedStringArray = ["第%d戦の予行演習 · 現在の配置" % (campaign_stage + 1) if campaign_focus else "予行演習 · 現在の配置", "乱数なしの現在ルールで仮想戦闘。報酬・素材消費なし。"]
	for encounter: Dictionary in result.encounters:
		var summary: Dictionary = encounter.summary
		var outcome := "勝利" if summary.result == "won" else "時間切れ" if summary.result == "timeout" else "敗北"
		lines.append("%s：%s · %.2f秒\n残りHP %d / %d · 与ダメージ %d\n法盾で軽減 %d · 被弾 %d回" % [encounter.name, outcome, summary.duration, summary.hp, summary.max_hp, summary.damage_dealt, summary.armor_mitigated, summary.enemy_attacks])
		for source: Dictionary in summary.by_source:
			lines.append("  %s #%d：%dダメージ · %d回発動 / %dヒット" % [source.name, source.uid, source.damage, source.activations, source.hits])
	summary_label.text = "\n".join(lines)
	_rehearsal_signature = _rehearsal_state_signature()
	details_content.move_child(summary_label, 0)
	details_scroll.scroll_vertical = 0
	_notice("予行演習の結果を表示しました。配置を変えると結果は消えます。")

func _sync() -> void:
	if not _rehearsal_signature.is_empty() and _rehearsal_signature != _rehearsal_state_signature():
		_rehearsal_signature = ""
		summary_label.text = "配置が変わりました。予行演習をもう一度実行してください。"
	if not _undo_signature.is_empty() and _undo_signature != _undo_state_signature():
		_clear_undo()
	arena.playback_speed = speed
	arena.encounter_id = encounter_id if mage_focus else "sentinel"
	if encounter_selector != null:
		encounter_selector.select(Encounters.IDS.find(encounter_id))
		encounter_selector.disabled = run.phase != "prepare"
		encounter_selector.tooltip_text = str(Encounters.definition(encounter_id).hint)
	grid.battle = battle
	grid.playback_speed = speed
	var info: Dictionary = Catalog.class_info(run.class_id)
	carrier_label.text = str(info.carrier) + "   6 × 4"
	resources_label.text = "残滓 %d" % run.gold if campaign_focus else "元素吸収 · 無料 / 有限" if run.class_id == "mage" else "武装補給 · %d 金貨" % run.gold
	resources_label.tooltip_text = "敵から得た魔力残滓。凝結に使います。" if campaign_focus else ""
	if campaign_stage_label != null:
		campaign_stage_label.text = "第 %d / %d 戦%s" % [campaign_stage + 1, Encounters.CAMPAIGN_IDS.size(), " · BOSS" if campaign_stage == Encounters.CAMPAIGN_IDS.size() - 1 else ""]
	for i in range(source_buttons.size()):
		var source: Dictionary = run.sources[i]
		var definition: Dictionary = run.get_definition(source.kind)
		var art := MageArt.icon(str(source.kind))
		source_buttons[i].icon = art.get("atlas", null)
		source_buttons[i].expand_icon = true
		source_buttons[i].add_theme_constant_override("icon_max_width", 36)
		var cost_label := "吸収" if int(source.cost) == 0 else "%d 残滓で凝結" % int(source.cost) if campaign_focus else "%d 金貨" % int(source.cost)
		source_buttons[i].text = "%s\n%s · 残り %d" % [definition.name, cost_label, int(source.remaining)]
		source_buttons[i].disabled = run.phase != "prepare" or int(source.remaining) <= 0 or run.gold < int(source.cost)
		source_buttons[i].tooltip_text = str(definition.description)
	var recipes: PackedStringArray = []
	for recipe in Catalog.recipes_for(run.class_id):
		recipes.append(str(recipe.label))
	recipe_label.text = "上の「レシピ」で%d種類の組み合わせを確認。\n完成品は重ねた相手の位置に配置されます。" % recipes.size() if mage_focus else "\n\n".join(recipes) + "\n\n完成品は重ねた相手の位置に配置。空き不足では素材や金貨を消費しません。"
	phase_label.text = "準備 · 配置可能" if run.phase == "prepare" else "戦闘 · 配置変更不可" if run.phase == "battle" else "戦闘終了 · 振り返り"
	var item: Dictionary = run.item_by_uid(selected_uid)
	var selected_art := MageArt.icon(str(item.get("kind", "")))
	detail_icon.visible = not selected_art.is_empty()
	detail_icon.texture = selected_art.get("atlas", null)
	if not item.is_empty():
		var definition: Dictionary = run.get_definition(item.kind)
		detail_label.text = "%s\n\n%s\n\n使用マス：%d × %d\n方向支援：+%d" % [definition.name, definition.description, run.get_item_size(item).x, run.get_item_size(item).y, run.get_adjacency_bonus(item)]
	else:
		var config: Dictionary = run.get_combat_config()
		if run.class_id == "mage":
			var enemy: Dictionary = Encounters.definition(encounter_id if mage_focus else "sentinel")
			var incoming := int(enemy.damage) - mini(int(config.armor), int(enemy.damage) - 1)
			var lines: PackedStringArray = ["%s HP%d · %d×%dダメージ / %.1f秒\n法盾で%d軽減 → 各段%dダメージ" % [enemy.name, enemy.hp, enemy.damage, enemy.hits, enemy.interval, int(config.armor), incoming], str(enemy.hint), "現在の魔法"]
			if enemy.has("pattern"):
				var pattern: Array = enemy.pattern
				lines[0] = "%s HP%d\n星弾 %d×%d / %.1f秒 → 重撃 %d×%d / %.1f秒\n法盾で各段%d軽減（最低1ダメージ）" % [enemy.name, enemy.hp, pattern[0].damage, pattern[0].hits, pattern[0].interval, pattern[1].damage, pattern[1].hits, pattern[1].interval, int(config.armor)]
			for action: Dictionary in config.actions:
				lines.append("%s：%d × %d回 / %.1f秒\n初回%.1f秒 · 接続+%d/回" % [action.name, action.damage, action.hits, action.interval, action.warmup, action.support_bonus])
			detail_label.text = "\n".join(lines)
		else:
			detail_label.text = "%s\n%s\n\n防御 %d · 攻撃手段 %d\n\n現在は%sを実装。\n\n%s · 4姿勢の攻撃と被弾・フェード演出を使用。" % [info.name, info.subtitle, int(config.armor), config.actions.size(), "大剣の鍛造と溜め攻撃", info.background]
	grid.selected_uid = selected_uid
	grid.recipe_hints = RecipeGuide.target_hints(run, held) if mage_focus else {}
	grid.queue_redraw()
	arena.queue_redraw()
	primary_button.disabled = run.phase != "prepare" and not (campaign_focus and run.phase == "won" and campaign_stage + 1 < Encounters.CAMPAIGN_IDS.size())
	primary_button.text = "次の戦いへ  /  Space" if campaign_focus and run.phase == "won" and campaign_stage + 1 < Encounters.CAMPAIGN_IDS.size() else "五つの試練を踏破" if campaign_focus and run.phase == "won" else "戦闘開始  /  Space"
	var final_victory: bool = campaign_focus and run.phase == "won" and campaign_stage == Encounters.CAMPAIGN_IDS.size() - 1
	save_button.disabled = (run.phase != "prepare" and not final_victory) or not persistence_enabled
	save_button.text = "踏破を保存" if final_victory else "準備を保存"
	load_button.disabled = run.phase == "battle" or not persistence_enabled
	pause_button.disabled = battle.phase != "battle"
	pause_button.text = "再開" if battle.paused else "一時停止"
	speed_button.text = "%d×" % int(speed)
	discard_button.disabled = run.phase != "prepare" or selected_uid < 0
	rotate_button.disabled = run.phase != "prepare" or held.is_empty()
	replay_button.disabled = _before_battle.is_empty()
	if recipe_button != null:
		recipe_button.disabled = run.phase != "prepare"
	if rehearsal_button != null:
		rehearsal_button.disabled = run.phase != "prepare"
	if undo_button != null:
		undo_button.disabled = run.phase != "prepare" or _undo_signature.is_empty()
	for id in class_buttons:
		class_buttons[id].disabled = run.phase == "battle"
	grid.update_preview()

func _process(delta: float) -> void:
	if battle.phase == "battle":
		var events: Array[Dictionary] = battle.tick(delta * speed)
		for event in events:
			arena.show_event(event)
			grid.show_event(event)
		arena.queue_redraw()
		if battle.phase in ["won", "lost"] and _last_phase == "battle":
			_last_phase = battle.phase
			run.phase = battle.phase
			var completion_error := ""
			if campaign_focus and battle.phase == "won":
				var reward := int(Campaign.REWARDS[campaign_stage])
				run.gold += reward
				arena.show_campaign_reward(reward)
				if persistence_enabled:
					var saved: Dictionary = CampaignSave.save_run(run, campaign_stage, campaign_checkpoint_path, true, battle.hp) if campaign_stage == Encounters.CAMPAIGN_IDS.size() - 1 else _save_next_campaign_preparation()
					if not saved.ok:
						completion_error = str(saved.message)
			_show_summary()
			if not completion_error.is_empty():
				_notice("勝利しましたが保存できません：" + completion_error)
			_sync()
	_ready_frames += 1
	if not _capture_directory.is_empty() and not _capture_done and _ready_frames > 10:
		_capture_done = true
		_capture_sequence.call_deferred()

func _show_placement_preview(preview: Dictionary) -> void:
	if preview_label == null:
		return
	preview_label.visible = not preview.is_empty()
	if preview.is_empty():
		return
	details_scroll.scroll_vertical = 0
	if not bool(preview.get("ok", false)):
		preview_label.text = "配置できません：" + str(preview.get("message", ""))
		return
	var item: Dictionary = preview.item
	var definition: Dictionary = run.get_definition(str(item.kind))
	preview_label.text = "%sプレビュー：%s\n%d×%dマス · 確定まで素材や資源は消費しません" % ["紡ぎ" if str(preview.event) == "merge" else "配置", definition.name, preview.size.x, preview.size.y]
	for action: Dictionary in preview.combat.actions:
		if int(action.uid) == int(item.uid):
			preview_label.text += "\n%d × %d回 / %.1f秒 · 接続+%d/回" % [action.damage, action.hits, action.interval, action.support_bonus]

func _show_summary() -> void:
	var summary: Dictionary = battle.get_summary()
	var lines: PackedStringArray = ["戦闘の振り返り · %s" % ("勝利" if battle.phase == "won" else "失敗"), "%.2f 秒 · 与ダメージ %d · 被ダメージ %d" % [float(summary.duration), int(summary.damage_dealt), int(summary.damage_taken)]]
	for source in summary.by_source:
		lines.append("%s：%d ダメージ / %d 回発動 / %d 回" % [source.name, int(source.damage), int(source.activations), int(source.hits)])
	if campaign_focus and battle.phase == "won":
		lines.append("魔力残滓 +%d · 所持 %d" % [int(Campaign.REWARDS[campaign_stage]), run.gold])
	summary_label.text = "\n".join(lines)
	if campaign_focus:
		_notice("五つの試練を踏破！" if battle.phase == "won" and campaign_stage == Encounters.CAMPAIGN_IDS.size() - 1 else "勝利！魔力残滓 +%d（所持 %d）。次の戦いへ。" % [int(Campaign.REWARDS[campaign_stage]), run.gold] if battle.phase == "won" else "敗北。戦前に戻して配置を変え、再挑戦できます。")
	else:
		_notice("戦闘終了。戦前に戻り魔法や敵を変えて再挑戦できます。" if mage_focus else "戦闘終了。戦前の配置に戻して比較できます。")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if recipe_overlay != null and recipe_overlay.visible:
		return
	match event.keycode:
		KEY_R: _rotate()
		KEY_Z:
			if event.ctrl_pressed: _undo_placement()
		KEY_SPACE: _primary_action()
		KEY_ESCAPE:
			_clear_selection()
			_sync()
		KEY_P: _pause()

func _input(event: InputEvent) -> void:
	if recipe_overlay != null and recipe_overlay.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_close_recipe_book()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_primary_action()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_clear_selection()
		_sync()

func _capture_sequence() -> void:
	# Capture only real frames; fixture actions use normal acquisition/move APIs.
	if DirAccess.make_dir_recursive_absolute(_capture_directory) != OK:
		push_error("Cannot create runtime capture directory")
		get_tree().quit(1)
		return
	await RenderingServer.frame_post_draw
	if not _capture_frame("prepare"):
		return
	if _capture_prepare_only:
		if _auto_quit:
			get_tree().quit()
		return
	if mage_focus and not _capture_loss and _capture_build == "baseline":
		_select_source(0)
		grid.hover_cell = Vector2i.ZERO
		grid.update_preview()
		await RenderingServer.frame_post_draw
		if not _capture_frame("preview-weave"):
			return
		_clear_selection()
	var fixture_actions: Array[Dictionary] = []
	if _capture_loss:
		if run.class_id != "mage":
			push_error("The legal loss fixture requires --class=mage")
			get_tree().quit(1)
			return
	elif run.class_id == "mage" and _capture_build == "frost_gale":
		fixture_actions.assign([{"source": 1, "cell": Vector2i(0, 0)}, {"source": 2, "cell": Vector2i(0, 2)}])
	elif run.class_id == "mage" and _capture_build == "steam_tornado":
		fixture_actions.assign([{"source": 0, "cell": Vector2i(3, 1)}, {"source": 1, "cell": Vector2i(3, 1)}, {"source": 0, "cell": Vector2i(0, 0)}, {"source": 2, "cell": Vector2i(0, 0)}])
	elif run.class_id == "mage" and _capture_build == "baseline":
		fixture_actions.assign([{"source": 0, "cell": Vector2i(0, 0)}, {"source": 1, "cell": Vector2i(3, 2)}, {"source": 2, "cell": Vector2i(3, 2)}])
	elif run.class_id == "mage":
		push_error("Unknown mage capture build: " + _capture_build)
		get_tree().quit(1)
		return
	elif not _capture_sword:
		fixture_actions.assign([{"source": 1, "cell": Vector2i(0, 0)}, {"source": 1, "cell": Vector2i(2, 1)}])
	var recorded_actions: Array[Dictionary] = []
	var discards: Array[int] = []
	if _capture_build == "steam_tornado" and not _capture_loss:
		discards.assign([1, 2])
	if _capture_no_ward:
		discards.append(4)
	for uid: int in discards:
		var discarded: Dictionary = run.discard(uid)
		if not discarded.ok:
			push_error("Capture discard failed")
			get_tree().quit(1)
			return
		recorded_actions.append({"operation": "discard", "uid": uid, "result": discarded})
	if _capture_loss:
		var uid: int = run.item_at(Vector2i.ZERO).uid
		var discarded: Dictionary = run.discard(uid)
		if not discarded.ok:
			push_error("Legal loss fixture discard failed")
			get_tree().quit(1)
			return
		recorded_actions.append({"operation": "discard", "uid": uid, "result": discarded})
	for action in fixture_actions:
		var result: Dictionary = run.acquire(int(action.source), action.cell)
		if not result.ok:
			push_error("Runtime capture acquisition failed: " + str(result.message))
			get_tree().quit(1)
			return
		recorded_actions.append({"source_index": action.source, "cell": [action.cell.x, action.cell.y], "result": result})
	if _capture_tide_focus and run.class_id == "mage" and not _capture_loss:
		var moved: Dictionary = run.move(3, Vector2i(2, 2))
		if not moved.ok:
			push_error("Tide focus fixture move failed")
			get_tree().quit(1)
			return
		recorded_actions.append({"operation": "move", "uid": 3, "cell": [2, 2], "result": moved})
	_sync()
	await RenderingServer.frame_post_draw
	if not _capture_frame("built"):
		return
	_start_battle()
	if battle.phase != "battle":
		push_error("Runtime capture battle did not start")
		get_tree().quit(1)
		return
	var captured_states: Array[String] = []
	var motion_samples: Array[Dictionary] = []
	var feedback_samples: Array[Dictionary] = []
	var feedback_captured: Array[String] = []
	var battle_frame := 0
	while battle.phase == "battle":
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		battle_frame += 1
		if not _capture_feedback(feedback_captured, feedback_samples):
			return
		var state: String = arena.motion.state
		if state in ["windup", "impact", "recover"] and state not in captured_states:
			captured_states.append(state)
			if not _capture_frame("motion-" + state):
				return
			motion_samples.append({"file": "%s-motion-%s.png" % [run.class_id, state], "battle_time": battle.battle_time, "visuals": arena.get_art_report()})
		if battle_frame == 25:
			if not _capture_frame("battle"):
				return
	# Let the final winning blow finish its visual follow-through.
	while arena.has_pending_presentation():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if not _capture_feedback(feedback_captured, feedback_samples):
			return
	await RenderingServer.frame_post_draw
	if not _capture_frame("result"):
		return
	var report := FileAccess.open(_capture_directory.path_join("%s-report.json" % run.class_id), FileAccess.WRITE)
	if report == null:
		push_error("Cannot write runtime fixture report")
		get_tree().quit(1)
		return
	report.store_string(JSON.stringify({"type": "runtime_capture_fixture", "class_id": run.class_id, "variant": "loss" if _capture_loss else "tide-focus" if _capture_tide_focus else "sword" if _capture_sword else "built", "build": _capture_build, "encounter_id": battle.encounter_id, "ward_equipped": not _capture_no_ward, "rules_version": Catalog.RULES_VERSION, "viewport": [int(size.x), int(size.y)], "persistence_enabled": persistence_enabled, "actions": recorded_actions, "remaining_sources": run.sources, "gold_after_acquisition": run.gold, "summary": battle.get_summary(), "visuals": arena.get_art_report(), "motion_samples": motion_samples, "feedback_samples": feedback_samples}, "\t", true))
	report.close()
	if _auto_quit:
		get_tree().quit()

func _capture_feedback(captured: Array[String], samples: Array[Dictionary]) -> bool:
	var feedback = arena.feedback
	var stages: Array[String] = []
	if run.class_id == "mage":
		if not arena.get_art_layout().shields.is_empty():
			stages.append("ward-hit")
		for effect: Dictionary in arena.get_art_layout().spell_effects:
			stages.append("effect-" + str(effect.kind))
			if float(effect.age) >= 0.06:
				stages.append("vfx-" + str(effect.phase) + "-" + str(effect.kind))
		for cast: Dictionary in arena.get_art_layout().spell_casts:
			if cast.phase == "gather" or (cast.remaining <= 0.15 and cast.remaining >= 0.08):
				stages.append("vfx-" + str(cast.phase) + "-" + str(cast.kind))
		if battle.phase == "battle" and arena.enemy_frame() == 1:
			stages.append("enemy-windup")
	if feedback.hero_hit > 0:
		stages.append("hero-hit")
	if feedback.enemy_hit > 0:
		stages.append("enemy-hit")
	for number in feedback.numbers:
		if int(number.hits) > 1:
			stages.append("multi-hit")
			break
	if feedback.hero_exit >= 0 and feedback.hero_exit < 0.6:
		stages.append("hero-exit")
	if feedback.enemy_exit >= 0 and feedback.enemy_exit < 0.6:
		stages.append("enemy-exit")
	for stage in stages:
		if stage in captured:
			continue
		if not _capture_frame(stage):
			return false
		captured.append(stage)
		samples.append({"file": "%s-%s.png" % [run.class_id, stage], "battle_time": battle.battle_time, "visuals": arena.get_art_report()})
	return true

func _capture_frame(stage: String) -> bool:
	var path := _capture_directory.path_join("%s-%s.png" % [run.class_id, stage])
	if FileAccess.file_exists(path):
		push_error("Runtime capture refuses to overwrite existing evidence: " + path)
		get_tree().quit(1)
		return false
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Runtime frame write failed: " + error_string(error))
		get_tree().quit(1)
		return false
	return true
