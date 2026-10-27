extends SceneTree
## Native GPU + real one-battle clock. Presentation must not change combat.

const Effects = preload("res://scripts/classes/mage_effects.gd")
const Art = preload("res://scripts/classes/mage_spell_art.gd")
const Battle = preload("res://scripts/classes/class_battle.gd")
const PLAYER_PATHS := ["user://mage-trial-run.json", "user://class-prototype-run.json", "user://emberpack-run.json"]
const OUTPUT := "res://.tools/mage-vfx-review"
var checks := 0
var failures := 0
var ui: Control
var observed: Dictionary = {}
var gpu_samples: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _fingerprint(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func _model() -> void:
	var actions := [{"uid": 1, "kind": "spark", "hits": 1}, {"uid": 2, "kind": "tide_lances", "hits": 3}]
	var timing := {"sources": {1: {"remaining": 0.5}, 2: {"remaining": 0.2}}, "enemy_remaining": 0.3, "substep": 0.0}
	var original := timing.duplicate(true)
	var casts := Effects.visible_casts(actions, timing)
	check(casts.size() == 3 and casts[0].kind == "tide_lances" and casts[0].phase == "flight" and casts[0].planned_hits == 3, "Imminent three-lance flight reads actual source timing")
	check(casts[1].kind == "enemy" and casts[1].target == "hero" and casts[2].phase == "gather", "Enemy core and friendly orb gather independently")
	casts[0].remaining = 999
	check(timing == original, "Choreography returns isolated data without changing cooldowns")
	timing.substep = 0.025
	check(is_equal_approx(Effects.visible_casts(actions, timing)[0].remaining, 0.175), "Flight interpolates the unconsumed substep without ticking rules")
	check(Effects.visible_casts(actions, {"sources": {1: {"remaining": 0.0}, 2: {"remaining": 0.8}}}).is_empty(), "Expired and distant casts produce no speculative impact")
	var many: Array = []
	var sources := {}
	for index in range(24):
		many.append({"uid": index, "kind": "spark", "hits": 1})
		sources[index] = {"remaining": 0.6 - index * 0.02}
	casts = Effects.visible_casts(many, {"sources": sources})
	check(casts.size() == 6 and casts[0].source_uid == 23, "Twenty-four legal sources retain six imminent casts, not an unbounded particle queue")
	var hits := [{"kind": "tide_lances", "target": "enemy", "age": 0.0, "hits": 1, "amount": 1}]
	var impact := Effects.visible_effects(hits)
	check(impact.size() == 1 and impact[0].hits == 1 and impact[0].phase == "impact", "Lethal tide shows one true hit, not the three planned lances")
	hits[0].age = 0.3
	check(Effects.visible_effects(hits)[0].phase == "residue", "Lingering fragments are distinct from the damaging impact")
	hits[0].age = 0.9
	check(Effects.visible_effects(hits).is_empty(), "Every impact expires before its feedback number is released")
	hits[0].age = 0.0
	hits[0].amount = 0
	check(Effects.visible_effects(hits).is_empty(), "A charge or zero-damage event cannot invent an impact")
	for kind: String in Art.MASKS:
		var texture := Art.texture(kind)
		var image := texture.get_image()
		var colors := {}
		var opaque := 0
		var partial := 0
		for y in image.get_height():
			for x in image.get_width():
				var color := image.get_pixel(x, y)
				if color.a > 0:
					opaque += 1
					colors[color.to_rgba32()] = true
					if color.a < 1:
						partial += 1
		check(opaque > 20 and partial == 0 and colors.size() == 5, kind + " uses five opaque authored colors and clear transparent space")
		check(Art.texture(kind) == texture, kind + " texture is cached rather than rebuilt per frame")
	check(Art.texture("flame", 0).get_image().get_data() != Art.texture("flame", 1).get_image().get_data(), "Flame tongues have integer-pixel animation variants")
	check(Art.texture("unknown") == null, "Unknown effect art fails without loading unrelated assets")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var fingerprints := {}
	for path in PLAYER_PATHS:
		fingerprints[path] = _fingerprint(path)
	_model()
	root.size = Vector2i(1440, 960)
	ui = load("res://scenes/mage_trial.tscn").instantiate()
	ui.persistence_enabled = false
	ui.checkpoint_path = "res://.tools/test-saves/mage-vfx.json"
	root.add_child(ui)
	await process_frame
	await process_frame
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	for action in [[0, Vector2i.ZERO], [1, Vector2i(3, 2)], [2, Vector2i(3, 2)]]:
		check(ui.run.acquire(action[0], action[1]).ok, "VFX fixture uses ordinary finite element acquisitions")
	ui._sync()
	var reference := Battle.new()
	reference.start(ui.run.get_combat_config())
	ui._start_battle()
	var paused_once := false
	var flame_readback := false
	for index in range(1000):
		if ui.battle.phase != "battle":
			break
		ui._process(0.025)
		reference.tick(0.025 * ui.speed)
		ui.arena._process(0.025)
		ui.grid._process(0.025)
		var layout: Dictionary = ui.arena.get_art_layout()
		for cast: Dictionary in layout.spell_casts:
			observed["%s:%s" % [cast.kind, cast.phase]] = true
		for effect: Dictionary in layout.spell_effects:
			observed["%s:%s" % [effect.kind, effect.phase]] = true
		if index == 0:
			await _gpu_readback("gather")
		if not paused_once and ui.battle.battle_time >= 0.2:
			paused_once = true
			ui._pause()
			var frozen: Dictionary = ui.arena.get_art_report().duplicate(true)
			var summary: Dictionary = ui.battle.get_summary()
			ui._process(0.7)
			ui.arena._process(0.7)
			check(ui.arena.get_art_report() == frozen and ui.battle.get_summary() == summary, "Pause freezes flight, ring, residue and combat clocks together")
			ui._pause()
			await _gpu_readback("flight")
			ui._speed()
		if not flame_readback and ui.battle.battle_time >= 1.65:
			flame_readback = true
			await _gpu_readback("impact")
	check(paused_once and flame_readback, "Native test visits flight and actual flame impact")
	check(ui.battle.get_summary() == reference.get_summary() and ui.battle.battle_time == 8.6, "Smooth VFX, pause and 2x leave every combat summary field identical")
	for kind in ["spark", "flame_glyph", "tide_lances", "enemy"]:
		check(observed.has(kind + ":gather") and observed.has(kind + ":flight") and observed.has(kind + ":impact") and observed.has(kind + ":residue"), kind + " traverses gather, flight, true impact and residue in actual battle")
	check(ui.arena.get_art_layout().spell_casts.is_empty(), "Battle end cancels all predicted flights without resolving another hit")
	ui.arena._process(2)
	check(ui.arena.get_art_layout().spell_effects.is_empty() and not ui.arena.has_pending_presentation(), "All VFX settle after the final true event")
	ui._restore_before_battle()
	check(ui.arena.get_art_layout().spell_casts.is_empty() and ui.arena.get_art_layout().spell_effects.is_empty(), "Restoring preparation clears all choreography")
	# Isolated rule fixture: one overpowered tide source ends on its first hit.
	# This is not a player build or footage; verify real Battle -> Feedback flow.
	var lethal_config: Dictionary = ui.run.get_combat_config().duplicate(true)
	var tide: Dictionary = lethal_config.actions[2].duplicate(true)
	tide.damage = 200
	lethal_config.actions = [tide]
	var lethal := Battle.new()
	check(lethal.start(lethal_config).ok, "Lethal truncation fixture is a valid isolated rule configuration")
	ui.battle = lethal
	ui.arena.battle = lethal
	for event: Dictionary in lethal.tick(0.8):
		ui.arena.show_event(event)
	var final_effects: Array = ui.arena.get_art_layout().spell_effects
	check(lethal.phase == "won" and lethal.get_summary().by_source[0].hits == 1 and final_effects.size() == 1 and final_effects[0].hits == 1, "Actual lethal engine event emits exactly one impact despite a three-hit source")
	check(ui.arena.get_art_layout().spell_casts.is_empty(), "A lethal event leaves no future flight or fabricated second/third hit")
	for path in PLAYER_PATHS:
		check(_fingerprint(path) == fingerprints[path], "VFX verification leaves player file untouched: " + path)
	var report := FileAccess.open(OUTPUT.path_join("test-report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "renderer": RenderingServer.get_video_adapter_name(), "observed": observed.keys(), "gpu_samples": gpu_samples, "summary": reference.get_summary()}, "\t"))
	report.close()
	print("Mage VFX: %d checks, %d failures" % [checks, failures])
	ui.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _gpu_readback(label: String) -> void:
	ui.arena.queue_redraw()
	ui.arena.effects_layer.visible = false
	ui.arena.ground_effects_layer.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	ui.arena.effects_layer.visible = true
	ui.arena.ground_effects_layer.visible = true
	await process_frame
	await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()
	var clip: Rect2i = Rect2i(Rect2(ui.arena.get_global_rect().position + ui.arena.effects_layer.position, ui.arena.effects_layer.size))
	var first := before.get_data()
	var second := after.get_data()
	var inside := 0
	var outside := 0
	for y in after.get_height():
		for x in after.get_width():
			var offset := (y * after.get_width() + x) * 4
			if first[offset] != second[offset] or first[offset + 1] != second[offset + 1] or first[offset + 2] != second[offset + 2]:
				if clip.has_point(Vector2i(x, y)):
					inside += 1
				else:
					outside += 1
	check(inside > 80, label + " draws visible native GPU effect pixels")
	check(outside == 0, label + " VFX never overwrite HUD, footer or board outside the stage")
	after.save_png(OUTPUT.path_join("gpu-" + label + ".png"))
	gpu_samples.append({"phase": label, "changed_inside": inside, "changed_outside": outside, "clip": [clip.position.x, clip.position.y, clip.size.x, clip.size.y]})
