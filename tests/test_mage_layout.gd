extends SceneTree
## Native window layout and actual battle state; persistence is disabled.

const OUTPUT := "res://.tools/mage-layout-review"
var checks := 0
var failures := 0
var ui: Control

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	_run.call_deferred()

func _settle() -> void:
	for _i in range(4):
		await process_frame

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT.path_join(name)) == OK, "Saved " + name)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(1440, 960)
	ui = load("res://scenes/mage_trial.tscn").instantiate()
	ui.persistence_enabled = false
	root.add_child(ui)
	await _settle()
	ui.set_process(false)
	ui.arena.set_process(false)
	ui.grid.set_process(false)
	for dimensions in [Vector2i(1280, 800), Vector2i(1440, 960), Vector2i(1920, 1080)]:
		root.size = dimensions
		ui._new_class("mage")
		await _settle()
		var viewport := Rect2(Vector2.ZERO, Vector2(dimensions))
		var prepared: Rect2 = ui.arena.get_global_rect()
		check(ui.workspace_panel.visible and viewport.encloses(prepared) and viewport.encloses(ui.grid.get_global_rect()), str(dimensions) + " prepared stage and board fit")
		check(not prepared.intersects(ui.grid.get_global_rect()) and ui.grid.cell_rect(Vector2i.ZERO).size.x >= 32, str(dimensions) + " board remains separate and usable")
		check(prepared.size.y > ui.workspace_panel.size.y, str(dimensions) + " stage is taller than the preparation panel")
		check(ui.arena.get_footer_note() == "編成：術式 2 · 使い魔 0", str(dimensions) + " preparation footer summarizes equipped sources")
		var before: Dictionary = ui.run.get_combat_config().duplicate(true)
		ui.workspace_button.pressed.emit()
		await _settle()
		check(not ui.workspace_panel.visible and ui.arena.size.y > prepared.size.y and ui.run.get_combat_config() == before, str(dimensions) + " collapse enlarges stage without changing build")
		ui.workspace_button.pressed.emit()
		await _settle()
		check(ui.workspace_panel.visible and ui.run.get_combat_config() == before, str(dimensions) + " toggle reopens the same build")
		for id in ["sentinel", "mirror_moth", "thorn_golem"]:
			ui._select_encounter(id)
			await _settle()
			var layout: Dictionary = ui.arena.get_art_layout()
			var hero: Rect2 = layout.hero_rect
			var enemy: Rect2 = layout.enemy_rect
			check(Rect2(layout.scene_rect).encloses(hero) and Rect2(layout.scene_rect).encloses(enemy) and not hero.intersects(enemy), str(dimensions) + " " + id + " silhouettes fit")
			if id == "thorn_golem":
				print("Golem proportions ", dimensions, ": hero=", hero.size, ", enemy=", enemy.size)
				check(enemy.size.y > hero.size.y * 1.4 and enemy.size.x > hero.size.x * 1.7, str(dimensions) + " golem is visibly larger than the mage")
			elif id == "mirror_moth":
				check(enemy.size.y < hero.size.y * 0.8, str(dimensions) + " moth remains smaller than the mage")
			elif id == "sentinel":
				check(enemy.size.y > hero.size.y * 1.2, str(dimensions) + " sentinel is visibly taller than the mage")
		if dimensions.x == 1440:
			await _capture("prepare-golem-1440.png")
		ui._start_battle()
		await _settle()
		check(ui.battle.phase == "battle" and not ui.workspace_panel.visible and ui.arena.size.y > prepared.size.y, str(dimensions) + " battle automatically expands stage")
		var next_note: String = ui.arena.get_footer_note()
		check(next_note.contains("次の発動") and next_note.contains("微光の術式") and next_note.contains("0.4秒") and next_note.contains("同時2件"), str(dimensions) + " independent simultaneous starter casts are visible")
		var unchanged: Dictionary = ui.battle.get_summary()
		check(ui.arena.get_footer_note() == next_note and ui.battle.get_summary() == unchanged, "Reading the countdown never advances combat")
		ui._process(0.15)
		check(ui.arena.get_footer_note() != next_note and ui.battle.phase == "battle", "The displayed next cast follows actual combat time")
		ui._pause()
		var paused_note: String = ui.arena.get_footer_note()
		ui._process(0.5)
		check(ui.arena.get_footer_note() == paused_note, "Pausing freezes the displayed countdown")
		ui._pause()
		ui._process(0.2)
		check(ui.arena.get_footer_note().contains("0.1秒"), "The last 50 ms round upward instead of displaying a premature zero")
		var battle_layout: Dictionary = ui.arena.get_art_layout()
		var battle_hero: Rect2 = battle_layout.hero_rect
		var battle_enemy: Rect2 = battle_layout.enemy_rect
		check(battle_enemy.size.y > battle_hero.size.y * 1.2 and battle_enemy.size.x > battle_hero.size.x * 1.4, str(dimensions) + " golem remains larger after battle stage expansion")
		var enemy_deadline: int = ui.battle._enemy_next_step
		for frame in range(4):
			ui.arena.feedback.hero_hit = 1.0 if frame == 2 else 0.0
			ui.arena.feedback.enemy_hit = 1.0 if frame == 3 else 0.0
			ui.battle._enemy_next_step = ui.battle._step_index + (1 if frame == 1 else 1000)
			var pose: Dictionary = ui.arena.get_art_layout()
			check(pose.enemy_frame == frame and Rect2(pose.scene_rect).encloses(pose.enemy_rect) and not Rect2(pose.enemy_rect).intersects(pose.hero_rect), str(dimensions) + " golem pose %d fits the stage" % frame)
		ui.arena.feedback.hero_hit = 0.0
		ui.arena.feedback.enemy_hit = 0.0
		ui.battle._enemy_next_step = enemy_deadline
		check(viewport.encloses(ui.workspace_button.get_global_rect()) and viewport.encloses(ui.primary_button.get_global_rect()), str(dimensions) + " battle controls remain on screen")
		await _capture("battle-golem-%d.png" % dimensions.x)
		ui.workspace_button.pressed.emit()
		await _settle()
		check(ui.workspace_panel.visible and ui.battle.phase == "battle", str(dimensions) + " board may be reopened during battle")
		ui._restore_before_battle()
		await _settle()
		check(ui.workspace_panel.visible and ui.run.phase == "prepare" and ui.run.get_combat_config() == before, str(dimensions) + " restore opens the unchanged preparation")
	ui.queue_free()
	await process_frame
	print("Mage layout: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
