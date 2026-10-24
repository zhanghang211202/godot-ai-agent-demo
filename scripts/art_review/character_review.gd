extends Control
## Native concept comparison fixture. This scene never reads or writes player saves.
## Raw PNGs live under docs/.gdignore: this is a local development review tool.

const ART_ROOT := "res://docs/concepts/2026-10-24-characters/"
const ENTRIES := [
	{"id": "MA", "name": "法师 A · 月庭礼装", "file": "mage-a-lunar.png", "face_rect": Rect2(380, 180, 350, 350), "note": "月庭仪式感 · 长袍与月形法杖"},
	{"id": "MB", "name": "法师 B · 巡游短装", "file": "mage-b-wayfarer.png", "face_rect": Rect2(390, 50, 330, 360), "note": "旅行感 · 短外套与清晰腿部轮廓"},
	{"id": "MC", "name": "法师 C · 奥术战装", "file": "mage-c-arcane.png", "face_rect": Rect2(430, 80, 360, 350), "note": "战术感 · 分层战装与施法轮廓"},
	{"id": "KA", "name": "骑士 A · 旌旗长枪", "file": "knight-a-banner.png", "face_rect": Rect2(430, 180, 330, 350), "note": "仪仗感 · 高马尾与长枪旗帜"},
	{"id": "KB", "name": "骑士 B · 轻甲先锋", "file": "knight-b-vanguard.png", "face_rect": Rect2(420, 80, 350, 350), "note": "目标：轻甲先锋\n实图仍偏重甲与大盾，待调整"},
	{"id": "KC", "name": "骑士 C · 遗物重刃", "file": "knight-c-relic.png", "face_rect": Rect2(380, 240, 330, 350), "note": "重装感 · 分段甲片与重刃轮廓"},
]
const SCALE_HEIGHTS := [128, 160, 192]

class ImageStudy extends Control:
	var image_texture: Texture2D
	var source_rect := Rect2()
	var target_height := 0.0
	var light_background := false
	var drawn_rect := Rect2()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("d6d3ce") if light_background else Color("151d2c"))
		var baseline := Color("b8b1a9") if light_background else Color("354258")
		draw_line(Vector2(8, size.y - 8), Vector2(size.x - 8, size.y - 8), baseline, 1)
		drawn_rect = destination_rect()
		if image_texture != null and source_rect.has_area() and drawn_rect.has_area():
			draw_texture_rect_region(image_texture, drawn_rect, source_rect)

	func destination_rect() -> Rect2:
		if not source_rect.has_area():
			return Rect2()
		var available := (size - Vector2(16, 16)).max(Vector2.ZERO)
		var factor := minf(available.x / source_rect.size.x, available.y / source_rect.size.y)
		if target_height > 0:
			factor = minf(factor, target_height / source_rect.size.y)
		var extent := source_rect.size * factor
		return Rect2(Vector2((size.x - extent.x) * 0.5, size.y - 8 - extent.y), extent)

var textures: Dictionary = {}
var bounds: Dictionary = {}
var failures: Array[String] = []
var selections := [0, 3]
var selectors: Array[OptionButton] = []
var full_views: Array[ImageStudy] = []
var head_views: Array[ImageStudy] = []
var scale_views: Array = []
var detail_labels: Array[Label] = []
var cards: Array[PanelContainer] = []
var active_label: Label
var filter_button: Button
var background_button: Button
var status_label: Label
var nearest := true
var light_background := false
var active_column := 0
var _capture_directory := ""
var _auto_quit := false
var _capture_done := false

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_directory = argument.trim_prefix("--capture-dir=")
		elif argument.begins_with("--left="):
			selections[0] = index_for_id(argument.trim_prefix("--left="))
		elif argument.begins_with("--right="):
			selections[1] = index_for_id(argument.trim_prefix("--right="))
		elif argument == "--auto-quit":
			_auto_quit = true
	_load_images()
	_build_interface()
	for column in range(2):
		select_entry(column, selections[column])
	_refresh_display()
	if not _capture_directory.is_empty():
		_capture_after_layout.call_deferred()

func index_for_id(id: String) -> int:
	for index in range(ENTRIES.size()):
		if ENTRIES[index].id == id.to_upper():
			return index
	return 0

func _load_images() -> void:
	for entry in ENTRIES:
		var path: String = ART_ROOT + entry.file
		if not FileAccess.file_exists(path):
			failures.append(entry.id + "：概念图尚未生成")
			continue
		var picture := Image.load_from_file(path)
		if picture == null or picture.is_empty():
			failures.append(entry.id + "：PNG 读取失败")
			continue
		var used := picture.get_used_rect()
		if not used.has_area():
			failures.append(entry.id + "：PNG 无可见内容")
			continue
		textures[entry.id] = ImageTexture.create_from_image(picture)
		bounds[entry.id] = Rect2(used)

func _build_interface() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color", "Label", Color("e0e5ee"))
	for kind in ["Button", "OptionButton"]:
		ui_theme.set_color("font_color", kind, Color("e0e5ee"))
		ui_theme.set_stylebox("normal", kind, _style(Color("253146"), Color("4a5c76")))
		ui_theme.set_stylebox("hover", kind, _style(Color("35435d"), Color("c7b5e1")))
		ui_theme.set_stylebox("pressed", kind, _style(Color("43405b"), Color("d9c7ee")))
		ui_theme.set_stylebox("focus", kind, _style(Color(0, 0, 0, 0), Color("e0b96e")))
	theme = ui_theme
	var background := ColorRect.new()
	background.color = Color("0c1320")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	add_child(margin)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 8)
	margin.add_child(root_box)
	root_box.add_child(_label("角色造型概念审稿  /  CHARACTER STUDY", 24, Color("efe4d1")))
	var warning := _label("已选外观基准：MA 月庭礼装＋KA 旌旗长枪 · 专用战斗精灵/动画待制作\n切换仅供观察，不改变基准；静态缩放不代表战斗尺寸、像素密度或 RV-03 验收通过。", 15, Color("f0c98d"))
	root_box.add_child(warning)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 12)
	root_box.add_child(toolbar)
	filter_button = _button("", func(): set_nearest(not nearest))
	background_button = _button("", func(): set_light_background(not light_background))
	toolbar.add_child(filter_button)
	toolbar.add_child(background_button)
	active_label = _label("", 15, Color("aab9cf"))
	active_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toolbar.add_child(active_label)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(columns)
	for column in range(2):
		_build_column(columns, column)
	status_label = _label("面部观察区：人工选定源图区域（非独立头像素材） · 128 / 160 / 192 px：非零 alpha 包围盒占高（可能含微弱残留），均为概念图静态缩放。", 13, Color("a5b1c5"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(status_label)
	if not failures.is_empty():
		status_label.text = "图像未完整加载：" + "；".join(failures)
		status_label.add_theme_color_override("font_color", Color("ffb0a2"))

func _build_column(parent: HBoxContainer, column: int) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style(Color("1b2638"), Color("40516b")))
	parent.add_child(card)
	cards.append(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var choice := OptionButton.new()
	choice.focus_mode = Control.FOCUS_NONE
	for entry in ENTRIES:
		choice.add_item(entry.id + "  " + entry.name)
	choice.item_selected.connect(func(index: int):
		active_column = column
		select_entry(column, index)
		_refresh_display())
	box.add_child(choice)
	selectors.append(choice)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(top)
	var full := ImageStudy.new()
	full.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	full.size_flags_stretch_ratio = 1.5
	full.custom_minimum_size = Vector2(0, 180)
	top.add_child(full)
	full_views.append(full)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_stretch_ratio = 1.0
	top.add_child(details)
	details.add_child(_label("头部与衣甲细节", 15, Color("c8b89c")))
	var head := ImageStudy.new()
	head.size_flags_vertical = Control.SIZE_EXPAND_FILL
	head.custom_minimum_size = Vector2(0, 140)
	details.add_child(head)
	head_views.append(head)
	var detail := _label("", 14, Color("b9c6da"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.x = 120
	details.add_child(detail)
	detail_labels.append(detail)
	box.add_child(_label("静态轮廓观察 · 原图非透明区域占高", 14, Color("c8b89c")))
	var sizes := HBoxContainer.new()
	sizes.add_theme_constant_override("separation", 6)
	box.add_child(sizes)
	var views: Array[ImageStudy] = []
	for pixels in SCALE_HEIGHTS:
		var sample := VBoxContainer.new()
		sample.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sizes.add_child(sample)
		var small := ImageStudy.new()
		small.custom_minimum_size.y = 208
		small.target_height = pixels
		sample.add_child(small)
		views.append(small)
		var caption := _label("%d px" % pixels, 13, Color("c0cbdd"))
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sample.add_child(caption)
	scale_views.append(views)

func select_entry(column: int, index: int) -> void:
	if column < 0 or column > 1:
		return
	index = posmod(index, ENTRIES.size())
	selections[column] = index
	if selectors.size() <= column:
		return
	selectors[column].select(index)
	var entry: Dictionary = ENTRIES[index]
	var source: Rect2 = bounds.get(entry.id, Rect2())
	var texture: Texture2D = textures.get(entry.id)
	full_views[column].image_texture = texture
	full_views[column].source_rect = source
	head_views[column].image_texture = texture
	head_views[column].source_rect = entry.face_rect if texture != null else Rect2()
	for view: ImageStudy in scale_views[column]:
		view.image_texture = texture
		view.source_rect = source
	detail_labels[column].text = entry.note + "\n\n外观道具仅表达造型，\n不表示新增职业机制。"
	_refresh_display()

func set_nearest(value: bool) -> void:
	nearest = value
	_refresh_display()

func set_light_background(value: bool) -> void:
	light_background = value
	_refresh_display()

func _refresh_display() -> void:
	if filter_button == null:
		return
	filter_button.text = "采样：最近邻  [N]" if nearest else "采样：平滑  [N]"
	background_button.text = "底色：深  [B]" if not light_background else "底色：浅  [B]"
	active_label.text = "当前：%s栏 · Tab 切栏 · ← → 切方案" % ("左" if active_column == 0 else "右")
	for column in range(2):
		var all_views: Array = [full_views[column], head_views[column]]
		all_views.append_array(scale_views[column])
		for view: ImageStudy in all_views:
			view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if nearest else CanvasItem.TEXTURE_FILTER_LINEAR
			view.light_background = light_background
			view.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_LEFT:
			select_entry(active_column, selections[active_column] - 1)
		KEY_RIGHT:
			select_entry(active_column, selections[active_column] + 1)
		KEY_TAB:
			active_column = 1 - active_column
		KEY_N:
			set_nearest(not nearest)
		KEY_B:
			set_light_background(not light_background)
		_:
			return
	_refresh_display()
	get_viewport().set_input_as_handled()

func _capture_after_layout() -> void:
	for frame in range(8):
		await get_tree().process_frame
	if _capture_done:
		return
	_capture_done = true
	if DisplayServer.get_name() == "headless":
		push_error("Concept study screenshots require a rendered window, not --headless.")
		if _auto_quit:
			get_tree().quit(1)
		return
	var target := ProjectSettings.globalize_path(_capture_directory)
	var error := DirAccess.make_dir_recursive_absolute(target)
	if error == OK:
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var file_name := "character-study-%s-%s-%dx%d.png" % [ENTRIES[selections[0]].id, ENTRIES[selections[1]].id, image.get_width(), image.get_height()]
		error = image.save_png(target.path_join(file_name))
		print("Character concept study fixture screenshot: %s (%s)" % [target.path_join(file_name), error_string(error)])
	if _auto_quit:
		get_tree().quit(0 if error == OK and failures.is_empty() else 1)

func _label(text: String, size: int = 16, color := Color("e0e5ee")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button

func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style
