extends SceneTree
## Requires actual rendering: native GPU alpha readback, not headless dummy.

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(32, 8)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var image := Image.create_from_data(4, 1, false, Image.FORMAT_RGBA8,
		PackedByteArray([180, 60, 80, 64, 180, 60, 80, 128, 180, 60, 80, 254, 180, 60, 80, 255]))
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.scale = Vector2(8, 8)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = ImageTexture.create_from_image(image)
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/classes/class_actor.gdshader")
	sprite.material = material
	viewport.add_child(sprite)
	var records: Array[Dictionary] = []
	for enabled in [false, true]:
		material.set_shader_parameter("cutout_enabled", enabled)
		await process_frame
		await RenderingServer.frame_post_draw
		var result := viewport.get_texture().get_image()
		check(result != null and result.get_size() == Vector2i(32, 8), "Real GPU target is readable")
		var values: Array[float] = []
		for index in range(4):
			values.append(result.get_pixel(index * 8 + 4, 4).a)
		if enabled:
			check(values[0] == 0, "Low-alpha fringe is discarded by actual shader")
			check(values[1] > 0.99 and values[2] > 0.99 and values[3] > 0.99, "Kept pixels are opaque, including alpha128 and alpha254")
		else:
			check(absf(values[0] - 64.0 / 255) < 0.02 and absf(values[1] - 128.0 / 255) < 0.02, "Comparison mode preserves original partial alpha")
		records.append({"cutout_enabled": enabled, "readback_alpha": values})
	material.set_shader_parameter("actor_opacity", 0.5)
	await process_frame
	await RenderingServer.frame_post_draw
	check(absf(viewport.get_texture().get_image().get_pixel(28, 4).a - 0.5) < 0.02, "Terminal fade stays available after cutout")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tools/c1-feedback-review"))
	var report := FileAccess.open("res://.tools/c1-feedback-review/render-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "renderer": RenderingServer.get_video_adapter_name(), "samples": records}, "\t"))
	report.close()
	print("Class feedback GPU: %d checks, %d failures" % [checks, failures])
	viewport.queue_free()
	await process_frame
	quit(1 if failures else 0)
