extends SceneTree
## Read-only guidance for two-step recipes, shared stock, cost and actual UI.
const Run = preload("res://scripts/classes/class_run.gd")
const Catalog = preload("res://scripts/classes/class_catalog.gd")
const Guide = preload("res://scripts/classes/mage_recipe_guide.gd")
const Campaign = preload("res://scripts/classes/mage_campaign.gd")
const OUTPUT := "res://.tools/mage-chain-guide-review"
const PLAYER_PATHS := ["user://mage-campaign-run.json", "user://mage-trial-run.json", "user://class-prototype-run.json", "user://emberpack-run.json"]
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	_run.call_deferred()

func _state(run: RefCounted) -> Dictionary:
	return {"items": run.items.duplicate(true), "sources": run.sources.duplicate(true), "gold": run.gold,
		"hp": run.hp, "phase": run.phase, "uid": run._next_uid, "discarded": run.discarded_materials.duplicate(true)}

func _fingerprints() -> Dictionary:
	var hashes := {}
	for path in PLAYER_PATHS:
		hashes[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return hashes

func _model() -> void:
	var recipes: Array = Catalog.recipes_for("mage")
	var run := Run.new()
	run.new_run("mage")
	for index in [10, 11]:
		var recipe: Dictionary = recipes[index]
		var before := _state(run)
		var route: Dictionary = Guide.plan(run, recipe)
		var choice: Dictionary = Guide.choose_planned(run, recipe)
		check(route.available and not route.direct and route.required_cost == 0, str(recipe.result) + " plans both steps from actual finite free ingredients")
		check(choice.ok and choice.prerequisite == recipe.first and choice.final_product == recipe.result and _state(run) == before, str(recipe.result) + " selects its prerequisite without spending")
	var budget := Run.new()
	budget.new_run("mage")
	budget.sources.append_array(Campaign.shop_sources())
	# Synthetic stock fixture isolates shared-cost accounting; it is never saved.
	budget.sources[0].remaining = 0
	budget.gold = 3
	var before := _state(budget)
	var route: Dictionary = Guide.plan(budget, recipes[10])
	check(not route.available and route.insufficient_funds and route.required_cost == 4 and route.missing.is_empty(), "Two paid fire units cost four total, not two independently affordable units")
	check(not Guide.choose_planned(budget, recipes[10]).ok and _state(budget) == before, "Insufficient combined budget is read-only and cannot start guidance")
	budget.gold = 4
	check(Guide.plan(budget, recipes[10]).available, "Exact shared budget permits the route")
	budget.sources[6].remaining = 1
	route = Guide.plan(budget, recipes[10])
	check(not route.available and "fire_mote" in route.missing, "Limited stock cannot be counted twice")
	var blocked := Run.new()
	blocked.new_run("mage")
	check(blocked.acquire(0, Vector2i.ZERO).ok, "Space fixture creates the base flame")
	var direct := Guide.choose_planned(blocked, recipes[10])
	check(direct.ok and not direct.preview.ok, "Available ingredients do not hide a blocked final footprint")
	blocked.sources[0].remaining = 0
	route = Guide.plan(blocked, recipes[10])
	check(not route.available and "fire_mote" in route.missing and not route.has("prerequisite"), "Existing base does not cause a misleading second base to be planned")
	blocked.phase = "battle"
	check(not Guide.choose_planned(blocked, recipes[10]).ok, "Guidance cannot execute during battle")

func _run() -> void:
	var player_saves := _fingerprints()
	_model()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for kind in ["solar_lance", "frost_orbit"]:
		await _ui_route(kind)
	check(_fingerprints() == player_saves, "Guide fixture leaves actual player saves unchanged")
	print("Mage chain guide: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _ui_route(kind: String) -> void:
	root.size = Vector2i(1440, 960)
	var ui = load("res://scenes/mage_campaign.tscn").instantiate()
	ui.persistence_enabled = false
	root.add_child(ui)
	for _i in range(4): await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	ui._on_drop({"origin": "bag", "uid": 3}, Vector2i(3, 1))
	var before := _state(ui.run)
	var index := 10 if kind == "solar_lance" else 11
	var first := 0 if kind == "solar_lance" else 1
	var base := "flame_glyph" if kind == "solar_lance" else "frost_bolt"
	ui._open_recipe_book()
	for _i in range(3): await process_frame
	check(not ui.recipe_cards[index].disabled and ui.recipe_cards[index].text.contains("先に"), kind + " card explains its available prerequisite")
	if kind == "solar_lance":
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OUTPUT.path_join("book.png")) == OK, "Planned recipe book screenshot saved")
	await _click(ui.recipe_cards[index].get_global_rect().get_center())
	if ui.recipe_overlay.visible or ui.held.get("origin") != "source" or int(ui.held.get("index", -1)) != first:
		print("Guide click diagnostic ", kind, " overlay=", ui.recipe_overlay.visible, " held=", ui.held, " status=", ui.status_label.text, " card=", ui.recipe_cards[index].get_global_rect())
	check(not ui.recipe_overlay.visible and ui.held.get("origin") == "source" and int(ui.held.get("index", -1)) == first and ui.status_label.text.contains(Catalog.definition(base).name), kind + " real click selects the base ingredient and explains the next step")
	check(_state(ui.run) == before, kind + " selecting a route spends no material")
	if kind == "solar_lance":
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OUTPUT.path_join("first-step.png")) == OK, "First planned step screenshot saved")
	ui._on_cell_selected(Vector2i.ZERO)
	check(ui.run.item_by_uid(1).kind == base, kind + " first merge uses the ordinary transaction")
	ui._open_recipe_book()
	check(not ui.recipe_cards[index].disabled and not ui.recipe_cards[index].text.contains("先に"), kind + " card changes to the direct second step")
	ui.recipe_cards[index].pressed.emit()
	ui._on_cell_selected(Vector2i.ZERO)
	check(ui.run.item_by_uid(1).kind == kind, kind + " second merge completes the actual spell")
	ui.queue_free()
	await process_frame

func _click(position: Vector2) -> void:
	Input.warp_mouse(root.get_screen_transform() * position)
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_screen_transform() * position
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = motion.position
	press.global_position = motion.position
	Input.parse_input_event(press)
	await process_frame
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
