extends SceneTree
## Typography-only fixtures: direct placement exercises every shape, not acquisition.

const Catalog = preload("res://scripts/classes/class_catalog.gd")
const KINDS := ["spark", "fire_mote", "water_mote", "wind_mote", "flame_glyph", "tide_lances", "arcane_focus", "mage_ward", "iron_blade", "greatblade", "charge_seal", "knight_ward"]
const PLAYER_PATHS := ["user://class-prototype-run.json", "user://emberpack-run.json"]
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _fingerprint(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func _run() -> void:
	var fingerprints := {}
	for path in PLAYER_PATHS:
		fingerprints[path] = _fingerprint(path)
	var scene: PackedScene = load("res://scenes/class_lab.tscn")
	var ui: Control = scene.instantiate()
	ui.set("persistence_enabled", false)
	root.add_child(ui)
	await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	for resolution in [Vector2i(1280, 800), Vector2i(1440, 960), Vector2i(1920, 1080)]:
		root.size = resolution
		for frame in range(4):
			await process_frame
		for kind in KINDS:
			var definition: Dictionary = Catalog.definition(kind)
			for rotated in [false, true]:
				ui.run.new_run(str(definition.class_id), 42)
				var item := {"uid": 1, "kind": kind, "pos": Vector2i.ZERO, "rotated": rotated}
				ui.run.items.assign([item])
				var shape: Vector2i = ui.run.get_item_size(item)
				var cell: Rect2 = ui.grid.cell_rect(Vector2i.ZERO)
				var rect := Rect2(cell.position, Vector2(shape) * cell.size.x).grow(-5)
				var before := {"items": ui.run.items.duplicate(true), "sources": ui.run.sources.duplicate(true), "gold": ui.run.gold}
				var visual: Dictionary = ui.grid.item_layout(kind, rect, rotated)
				var label: Dictionary = visual.label
				var icon: Rect2 = visual.icon_rect
				var readable: bool = (not label.lines.is_empty() and int(label.font_size) >= 14) or (icon.has_area() and icon.size.x >= 10 and icon.size.y >= 10)
				readable = readable and (not icon.has_area() or rect.encloses(icon))
				var text_boxes: Array[Rect2] = []
				for index in range(label.lines.size()):
					var position: Vector2 = label.baselines[index]
					var width: float = ui.grid.font.get_string_size(label.lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x
					var ascent: float = ui.grid.font.get_ascent(label.font_size)
					var descent: float = ui.grid.font.get_descent(label.font_size)
					var ink := Rect2(position - Vector2(0, ascent), Vector2(width, ascent + descent))
					readable = readable and rect.grow(-2).encloses(ink)
					text_boxes.append(ink)
					readable = readable and (not icon.has_area() or not ink.intersects(icon))
				var supports_clear := true
				for point: Vector2 in label.support_points:
					var mark := Rect2(point - Vector2.ONE * 2, Vector2.ONE * 4)
					supports_clear = supports_clear and rect.grow(0.1).encloses(mark)
					for text_box in text_boxes:
						supports_clear = supports_clear and not mark.intersects(text_box)
				if definition.category == "support":
					var pair: Array = label.support_points
					supports_clear = supports_clear and pair.size() == 2
					if pair.size() == 2:
						var offset: Vector2 = pair[1] - pair[0]
						supports_clear = supports_clear and (offset.y > 0 and is_zero_approx(offset.x) if rotated else offset.x > 0 and is_zero_approx(offset.y))
				check(readable and supports_clear, "%s %s rotated=%s text and directional markers remain inside the item without overlap" % [resolution, kind, rotated])
				var tooltip: String = ui.grid._get_tooltip(rect.get_center())
				check(tooltip.contains(str(definition.name)) and tooltip.contains(str(definition.description)), "%s %s rotated=%s full name and description remain accessible" % [resolution, kind, rotated])
				ui.grid.queue_redraw()
				await process_frame
				if before != {"items": ui.run.items.duplicate(true), "sources": ui.run.sources.duplicate(true), "gold": ui.run.gold}:
					check(false, "Typography never changes the fixture's items, sources or gold")
	for path in PLAYER_PATHS:
		check(_fingerprint(path) == fingerprints[path], "Grid labels never access player checkpoint: " + path)
	ui.queue_free()
	await process_frame
	print("Class grid labels: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
