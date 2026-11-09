extends SceneTree
## Actual fourth-enemy attacks with and without mitigation; no player saves.
const Battle = preload("res://scripts/classes/class_battle.gd")
const OUTPUT := "res://.tools/mage-scribe-impact-review"
const PLAYER_PATHS := ["user://mage-campaign-run.json", "user://mage-trial-run.json", "user://class-prototype-run.json", "user://emberpack-run.json"]
var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var fingerprints := {}
	for path in PLAYER_PATHS:
		fingerprints[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for ward in [true, false]:
		await _battle(ward)
	for path in fingerprints:
		check((FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing") == fingerprints[path], "Player save unchanged: " + path)
	print("Mage scribe impact: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _battle(ward: bool) -> void:
	root.size = Vector2i(1440, 960)
	var ui = load("res://scenes/mage_campaign.tscn").instantiate()
	ui.persistence_enabled = false
	root.add_child(ui)
	for _i in range(4): await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	if not ward:
		check(ui.run.discard(4).ok, "Unwarded fixture removes the original ward through normal rules")
	ui.campaign_stage = 3
	ui.encounter_id = "astral_scribe"
	ui._sync()
	var reference := Battle.new()
	check(reference.start(ui.run.get_combat_config(), "astral_scribe").ok, "Independent fourth-enemy reference starts")
	ui._start_battle()
	check(ui.battle.phase == "battle", "Fixture starts the actual battle")
	var found := false
	while ui.battle.phase == "battle" and ui.battle.battle_time < 3.0:
		ui._process(0.05)
		ui.arena._process(0.05)
		reference.tick(0.05)
		var layout: Dictionary = ui.arena.get_art_layout()
		for effect: Dictionary in layout.spell_effects:
			if effect.kind != "scribe_rune": continue
			found = true
			check(effect.hits == 3 and layout.shields.size() == (1 if ward else 0), "Three real rune hits show a shield only when damage is mitigated")
			check(ui.battle.get_summary().damage_taken == (15 if ward else 21) and ui.battle.get_summary().armor_mitigated == (6 if ward else 0), "Ward and unwarded damage follow the actual battle rules")
			var before: Dictionary = ui.arena.get_art_report().duplicate(true)
			ui._pause()
			ui._process(0.5)
			ui.arena._process(0.5)
			check(ui.arena.get_art_report() == before, "Pause freezes the real rune and ward impact")
			ui._pause()
			await process_frame
			await RenderingServer.frame_post_draw
			var path := OUTPUT.path_join("ward.png" if ward else "no-ward.png")
			check(root.get_texture().get_image().save_png(path) == OK, "Captured the actual fourth-enemy impact")
			break
		if found: break
	check(found and ui.battle.get_summary() == reference.get_summary(), "Actual scribe impact matches independently stepped combat")
	ui.queue_free()
	await process_frame
