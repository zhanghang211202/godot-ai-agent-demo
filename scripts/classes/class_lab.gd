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

@export var mage_focus := false

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
var replay_button: Button
var summary_label: Label
var preview_label: Label
var detail_icon: TextureRect
var details_scroll: ScrollContainer
var speed := 1.0
var encounter_id := "sentinel"
var encounter_selector: OptionButton
var persistence_enabled := true
@export var checkpoint_path := Save.DEFAULT_PATH
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
	var heading := _label("月庭法师试炼" if mage_focus else "职业构筑试炼", 25)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	if mage_focus:
		encounter_selector = OptionButton.new()
		encounter_selector.custom_minimum_size = Vector2(205, 42)
		for id in Encounters.IDS:
			encounter_selector.add_item(str(Encounters.definition(id).name))
		encounter_selector.item_selected.connect(func(index: int): _select_encounter(Encounters.IDS[index]))
		header.add_child(encounter_selector)
	for id in Catalog.CLASS_IDS:
		if mage_focus and id != "mage":
			continue
		var b := _button("新法师实验" if id == "mage" else "新 H 骑士实验", func(): _new_class(id))
		if mage_focus:
			b.text = "重新开始法师试炼"
		header.add_child(b)
		class_buttons[id] = b
	var notice := _label("吸收元素 → 六种编织配方 → 连接晶核 / 保留法盾 → 选择敌人" if mage_focus else "C1 战斗反馈样板 · 命中数字 / 护甲 / 受击 / 淡出 · 有限资源与固定训练敌人", 15, Color("b6acc5"))
	root.add_child(notice)
	arena = ArenaView.new()
	arena.run = run
	arena.battle = battle
	arena.pixel_cutout_enabled = not _original_alpha_comparison
	root.add_child(arena)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var inventory := _panel(body, 440, 1.35)
	carrier_label = _label("", 22)
	inventory.add_child(carrier_label)
	grid = GridView.new()
	grid.run = run
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.cell_selected.connect(_on_cell_selected)
	grid.drop_requested.connect(_on_drop)
	grid.preview_changed.connect(_show_placement_preview)
	inventory.add_child(grid)
	inventory.add_child(_label("点击 / 拖放 · R 旋转 · 右键取消", 14, Color("a7b4c5")))
	inventory.add_child(_label("青色可放 · 红色无效 · 金色尝试组合", 14, Color("a7b4c5")))
	var source_column := _panel(body, 270, 0.8)
	resources_label = _label("", 20)
	source_column.add_child(resources_label)
	var source_scroll := ScrollContainer.new()
	source_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	source_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	source_column.add_child(source_scroll)
	var source_list := VBoxContainer.new()
	source_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_list.add_theme_constant_override("separation", 10)
	source_scroll.add_child(source_list)
	for index in range(3):
		var b := _button("", func(): _select_source(index))
		b.custom_minimum_size.y = 62
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.set_drag_forwarding(func(at: Vector2): return _source_drag(index, at), Callable(), Callable())
		source_buttons.append(b)
		source_list.add_child(b)
	source_list.add_child(_label("组合配方", 19))
	recipe_label = _label("", 16, Color("c9bbdf"))
	recipe_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source_list.add_child(recipe_label)
	var details := _panel(body, 285, 0.9)
	phase_label = _label("", 20)
	details.add_child(phase_label)
	details_scroll = ScrollContainer.new()
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details.add_child(details_scroll)
	var details_content := VBoxContainer.new()
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
	rotate_button = _button("旋转 R", _rotate)
	discard_button = _button("丢弃（无返还）", _discard)
	item_actions.add_child(rotate_button)
	item_actions.add_child(discard_button)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	root.add_child(footer)
	save_button = _button("保存准备", _save)
	load_button = _button("读取实验", _load)
	replay_button = _button("恢复战前", _restore_before_battle)
	footer.add_child(save_button)
	footer.add_child(load_button)
	footer.add_child(replay_button)
	pause_button = _button("暂停", _pause)
	speed_button = _button("1×", _speed)
	footer.add_child(pause_button)
	footer.add_child(speed_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	primary_button = _button("开始训练  /  空格", _start_battle)
	primary_button.custom_minimum_size.x = 245
	footer.add_child(primary_button)
	status_label = _label("", 16, Color("dfc394"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 38
	root.add_child(status_label)

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
		_notice("当前为法师试炼。")
		return
	if run.phase == "battle":
		_notice("训练中不能切换职业，请先完成这一战或恢复战前。")
		return
	var result: Dictionary = run.new_run(id, 12345)
	if not result.ok:
		_notice(str(result.message))
		return
	battle = BattleRules.new()
	_before_battle = {}
	arena.battle = battle
	arena.reset_presentation()
	_clear_selection()
	summary_label.text = "先尝试火 + 微光，再试水 + 风。\n晶核左右连接术式：每段+2，R旋转改为上下。\n一战后可恢复同一配置调整；元素有限，丢弃不返还。" if mage_focus else "本实验只验证一战，不是六流派完整 Demo。\n有限来源不会刷新；丢弃不返还素材或金币。"
	grid.active_sources.clear()
	_notice("法师：先点火元素，再点微光术式编织焰爆；水与风可组合三段法术。" if id == "mage" else "骑士：购入蓄势徽记并叠到长剑上，锻造六格重刃；保留徽记也可连接强化。")
	_sync()
	grid.update_preview()

func _select_source(index: int) -> void:
	if run.phase != "prepare":
		return
	held = {"origin": "source", "index": index, "rotated": false}
	selected_uid = -1
	grid.held = held
	var definition: Dictionary = run.get_definition(run.sources[index].kind)
	_notice("已选择%s：点击空格摆放，或点击兼容材料尝试配方。R 旋转。" % definition.name)
	_sync()
	grid.update_preview()

func _select_encounter(id: String) -> void:
	if not mage_focus or run.phase != "prepare" or id not in Encounters.IDS:
		return
	encounter_id = id
	arena.encounter_id = id
	arena.reset_presentation()
	_notice(str(Encounters.definition(id).hint))
	_sync()

func _source_drag(index: int, _at: Vector2) -> Variant:
	if run.phase != "prepare" or int(run.sources[index].remaining) <= 0:
		return null
	_select_source(index)
	return held.duplicate()

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
		_clear_selection()
	_sync()

func _rotate() -> void:
	if run.phase != "prepare":
		return
	if not held.is_empty():
		held.rotated = not bool(held.get("rotated", false))
		grid.held = held
		_notice("待放物件已旋转；点击格位确认。")
		grid.queue_redraw()
		grid.update_preview()

func _discard() -> void:
	if selected_uid < 0:
		return
	var result: Dictionary = run.discard(selected_uid)
	_notice(str(result.message))
	if result.ok:
		_clear_selection()
	_sync()

func _clear_selection() -> void:
	held = {}
	selected_uid = -1
	if grid != null:
		grid.held = {}
		grid.selected_uid = -1
		if run.phase != "battle":
			grid.active_sources.clear()
		grid.update_preview()

func _save() -> bool:
	if not persistence_enabled:
		_notice("当前为隔离验证/截图模式，不写入玩家存档。")
		return false
	var result: Dictionary = Save.save_run(run, checkpoint_path)
	_notice(str(result.message))
	return bool(result.ok)

func _load() -> void:
	if not persistence_enabled:
		_notice("当前为隔离验证/截图模式，不读取玩家存档。")
		return
	if mage_focus:
		var info: Dictionary = Save.inspect_save(checkpoint_path)
		if not info.ok or str(info.get("class_id", "")) != "mage":
			_notice(str(info.message) if not info.ok else "该检查点不是法师配置，当前整备未改变。")
			return
	var result: Dictionary = Save.load_run(run, checkpoint_path)
	_notice(str(result.message))
	if result.ok:
		battle = BattleRules.new()
		_before_battle = {}
		arena.battle = battle
		arena.reset_presentation()
		_clear_selection()
		summary_label.text = "已恢复实验准备快照。旧版远征使用独立存档，不在这里转换。"
	_sync()

func _resize_layout() -> void:
	if arena != null:
		arena.custom_minimum_size.y = 350 if size.y >= 900 else 280
	if grid != null:
		grid.custom_minimum_size.y = 230 if size.y >= 900 else 184

var _before_battle: Dictionary = {}

func _start_battle() -> void:
	if run.phase != "prepare":
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
	_before_battle = {"class_id": run.class_id, "items": run.items.duplicate(true), "sources": run.sources.duplicate(true), "gold": run.gold, "hp": run.hp, "max_hp": run.max_hp, "seed_value": run.seed_value, "next_uid": run._next_uid, "discarded": run.discarded_materials.duplicate(true)}
	battle = candidate
	arena.battle = battle
	arena.reset_presentation()
	run.phase = "battle"
	_last_phase = "battle"
	_clear_selection()
	_notice("训练开始。动作与连线显示规则事件；可暂停或切换 1× / 2×。")
	_sync()

func _restore_before_battle() -> void:
	if _before_battle.is_empty():
		_notice("还没有本次启动中的战前快照；可读取之前保存的实验。")
		return
	run.new_run(str(_before_battle.class_id), int(_before_battle.seed_value))
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
	_clear_selection()
	summary_label.text = "回到原战前配置，不重复发资源，不刷新来源。"
	_notice("已恢复战前。调整布局后可再次训练。")
	_sync()

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

func _sync() -> void:
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
	resources_label.text = "吸收元素 · 免费 / 有限" if run.class_id == "mage" else "武装补给 · %d 金币" % run.gold
	for i in range(source_buttons.size()):
		var source: Dictionary = run.sources[i]
		var definition: Dictionary = run.get_definition(source.kind)
		var art := MageArt.icon(str(source.kind))
		source_buttons[i].icon = art.get("atlas", null)
		source_buttons[i].expand_icon = true
		source_buttons[i].add_theme_constant_override("icon_max_width", 36)
		source_buttons[i].text = "%s\n%s · 剩余 %d" % [definition.name, "吸收" if int(source.cost) == 0 else "%d 金币" % int(source.cost), int(source.remaining)]
		source_buttons[i].disabled = run.phase != "prepare" or int(source.remaining) <= 0 or run.gold < int(source.cost)
		source_buttons[i].tooltip_text = str(definition.description)
	var recipes: PackedStringArray = []
	for recipe in Catalog.recipes_for(run.class_id):
		recipes.append(str(recipe.label))
	recipe_label.text = "\n\n".join(recipes) + "\n\n产物锚在被叠放物件的位置。空间不足不扣材料或金币。"
	phase_label.text = "准备 · 可调整" if run.phase == "prepare" else "战斗 · 准备操作锁定" if run.phase == "battle" else "训练结束 · 一战复盘"
	var item: Dictionary = run.item_by_uid(selected_uid)
	var selected_art := MageArt.icon(str(item.get("kind", "")))
	detail_icon.visible = not selected_art.is_empty()
	detail_icon.texture = selected_art.get("atlas", null)
	if not item.is_empty():
		var definition: Dictionary = run.get_definition(item.kind)
		detail_label.text = "%s\n\n%s\n\n实际占格：%d × %d\n方向支援：+%d" % [definition.name, definition.description, run.get_item_size(item).x, run.get_item_size(item).y, run.get_adjacency_bonus(item)]
	else:
		var config: Dictionary = run.get_combat_config()
		if run.class_id == "mage":
			var enemy: Dictionary = Encounters.definition(encounter_id if mage_focus else "sentinel")
			var incoming := int(enemy.damage) - mini(int(config.armor), int(enemy.damage) - 1)
			var lines: PackedStringArray = ["%s%d生命 · %d×%d伤害 / %.1f秒\n法盾减伤%d → 每段承伤%d" % [enemy.name, enemy.hp, enemy.damage, enemy.hits, enemy.interval, int(config.armor), incoming], str(enemy.hint), "当前法术"]
			for action: Dictionary in config.actions:
				lines.append("%s：%d × %d段 / %.1f秒\n首次%.1f秒 · 协同+%d/段" % [action.name, action.damage, action.hits, action.interval, action.warmup, action.support_bonus])
			detail_label.text = "\n".join(lines)
		else:
			detail_label.text = "%s\n%s\n\n护甲 %d · 攻击来源 %d\n\n本次仅实现%s。\n\n%s · 四帧施法/攻击与受击/淡出反馈已接入；专用受击、退场姿势和其他流派待制作。" % [info.name, info.subtitle, int(config.armor), config.actions.size(), "重刃的锻造与蓄势", info.background]
	grid.selected_uid = selected_uid
	grid.queue_redraw()
	arena.queue_redraw()
	primary_button.disabled = run.phase != "prepare"
	save_button.disabled = run.phase != "prepare" or not persistence_enabled
	load_button.disabled = run.phase == "battle" or not persistence_enabled
	pause_button.disabled = battle.phase != "battle"
	pause_button.text = "继续" if battle.paused else "暂停"
	speed_button.text = "%d×" % int(speed)
	discard_button.disabled = run.phase != "prepare" or selected_uid < 0
	rotate_button.disabled = run.phase != "prepare" or held.is_empty()
	replay_button.disabled = _before_battle.is_empty()
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
			_show_summary()
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
		preview_label.text = "无法放置：" + str(preview.get("message", ""))
		return
	var item: Dictionary = preview.item
	var definition: Dictionary = run.get_definition(str(item.kind))
	preview_label.text = "%s预览：%s\n占格%d×%d · 确认前不扣元素" % ["编织" if str(preview.event) == "merge" else "放置", definition.name, preview.size.x, preview.size.y]
	for action: Dictionary in preview.combat.actions:
		if int(action.uid) == int(item.uid):
			preview_label.text += "\n%d × %d段 / %.1f秒 · 协同+%d/段" % [action.damage, action.hits, action.interval, action.support_bonus]

func _show_summary() -> void:
	var summary: Dictionary = battle.get_summary()
	var lines: PackedStringArray = ["一战复盘 · %s" % ("胜利" if battle.phase == "won" else "失败"), "%.2f 秒 · 有效输出 %d · 承伤 %d" % [float(summary.duration), int(summary.damage_dealt), int(summary.damage_taken)]]
	for source in summary.by_source:
		lines.append("%s：%d 伤害 / %d 次激活 / %d 段" % [source.name, int(source.damage), int(source.activations), int(source.hits)])
	summary_label.text = "\n".join(lines)
	_notice("挑战结束。恢复战前可调整法术和目标，再次挑战。" if mage_focus else "训练结束。可恢复同一战前配置做对照；这里没有五战奖励或完整三流派。")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_R: _rotate()
		KEY_SPACE: _start_battle()
		KEY_ESCAPE:
			_clear_selection()
			_sync()
		KEY_P: _pause()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_start_battle()
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
