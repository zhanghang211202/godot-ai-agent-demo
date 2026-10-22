extends SceneTree
## Reproducible native-art export; does not overwrite any v0.2 artwork.
## Godot --headless --path . --script res://scripts/visuals/export_art_v03.gd

const Art = preload("res://scripts/visuals/pixel_art_v03.gd")
const Forest = preload("res://scripts/ui/forest_stage.gd")
const OUTPUT := "res://assets/art/v03"
var failures := 0
var entries: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for directory in ["characters","items/icons","items/inventory","previews","environments/forest"]:
		DirAccess.make_dir_recursive_absolute(OUTPUT.path_join(directory))
	for kind in ["hero","slime"]:
		var sheet := Image.create(256,256,false,Image.FORMAT_RGBA8)
		sheet.fill(Color.TRANSPARENT)
		var clips := {}
		for row in range(4):
			var clip: String = ["idle","attack","hurt","defeat"][row]
			var definition: Dictionary = Art.CLIPS[clip]
			var indices: Array[int] = []
			for frame in range(int(definition["frames"])):
				var image: Image = Art.character_frame(kind,clip,frame)
				sheet.blit_rect(image,Rect2i(0,0,64,64),Vector2i(frame*64,row*64))
				indices.append(row*4+frame)
			clips[clip] = {"frames":indices,"frame_seconds":definition["seconds"],"loop":definition["loop"]}
		var entry := _save("character.%s" % kind,"characters/%s_sheet.png" % kind,sheet)
		entry.merge({"frame_size":[64,64],"pivot":[32,58],"facing":"right" if kind == "hero" else "left","clips":clips})
	for kind in ["sword","shield","whetstone"]:
		var item: Image = Art.inventory_image(kind)
		var footprint: Vector2i = Art.FOOTPRINTS[kind]
		var entry := _save("item.%s.inventory" % kind,"items/inventory/%s.png" % kind,item)
		entry.merge({"footprint":[footprint.x,footprint.y],"rotation_policy":"whole_image_90_degrees","pivot":[item.get_width()/2,item.get_height()/2]})
		_save("item.%s.icon" % kind,"items/icons/%s.png" % kind,Art.icon(kind).get_image())
	var forest_entry := _save("environment.forest", "environments/forest/stage.png", Forest.texture().get_image())
	forest_entry.merge({"kind":"environment", "source_path":"res://scripts/ui/forest_stage.gd", "ground_y":126, "layering":"flattened_native_layers_with_runtime_side_extension"}, true)
	# Review sheet: source-authored sprites at exactly 3x, with all 14 frames
	# visible. This is an asset contact sheet, not a runtime screenshot.
	var contact := Image.create(768,1536,false,Image.FORMAT_RGBA8)
	contact.fill(Color("18282a"))
	for kind_index in range(2):
		var kind: String = ["hero","slime"][kind_index]
		for clip_index in range(4):
			var clip: String = ["idle","attack","hurt","defeat"][clip_index]
			for frame in range(int(Art.CLIPS[clip]["frames"])):
				var image: Image = Art.character_frame(kind,clip,frame)
				image.resize(192,192,Image.INTERPOLATE_NEAREST)
				contact.blend_rect(image,Rect2i(0,0,192,192),Vector2i(frame*192,(kind_index*4+clip_index)*192))
	# Save the contact sheet separately from runtime asset entries.
	if contact.save_png(OUTPUT.path_join("previews/animation_contact.png")) != OK:
		failures += 1
	var preview := Image.create(512,256,false,Image.FORMAT_RGBA8)
	preview.fill(Color("18282a"))
	var x := 16
	for kind in ["hero","slime"]:
		var image: Image = Art.character_frame(kind,"idle",0)
		image.resize(128,128,Image.INTERPOLATE_NEAREST)
		preview.blend_rect(image,Rect2i(0,0,128,128),Vector2i(x,8))
		x += 144
	x = 24
	for kind in ["sword","shield","whetstone"]:
		var image: Image = Art.inventory_image(kind)
		preview.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(x,148))
		x += 100
	if preview.save_png(OUTPUT.path_join("previews/sample_contact.png")) != OK:
		failures += 1
	var fallbacks: Array[Dictionary] = []
	for kind in Art.FOOTPRINTS:
		if kind not in ["sword","shield","whetstone"]:
			var footprint: Vector2i = Art.FOOTPRINTS[kind]
			fallbacks.append({"id":"item.%s.inventory" % kind,"status":"legacy_placeholder","footprint":[footprint.x,footprint.y],"source_size":[footprint.x*32,footprint.y*32],"method":"legacy_32px_icon_centered_on_transparent_footprint_without_stretch","source_path":"res://scripts/visuals/pixel_art.gd"})
	for kind in ["wolf","goblin","boss","tree"]:
		fallbacks.append({"id":"character.%s" % kind,"status":"legacy_placeholder","source_size":[96,96],"pivot":[48,88],"method":"legacy_static_texture","source_path":"res://scripts/visuals/pixel_art.gd"})
	var manifest := {
		"schema_version":1,"milestone":"v0.3-M1-art-sample","status":"integrated_in_runtime_art_sample",
		"palette_id":"ember_forest_v1_sample","source_path":"res://scripts/visuals/pixel_art_v03.gd",
		"author":"Emberpack project / Codex","method":"original_native_code_pixel_art",
		"source_url":null,"prompt_record":null,"license":"project_original_no_third_party_art",
		"allowed_scales":[2,3],"filter":"nearest","assets":entries,"fallbacks":fallbacks,
		"limitations":["New art covers hero/slime, sword/shield/whetstone and the forest stage; other items and enemies remain placeholders.","No weapon-specific character equipment layers.","Source contact sheets are not runtime game screenshots.","New animation does not add or modify combat mechanics.","Forest painting layers are flattened, without parallax."],
		"preview":{"sample":"previews/sample_contact.png","animation":"previews/animation_contact.png","kind":"asset_contact_sheet_not_runtime"},
	}
	var file := FileAccess.open(OUTPUT.path_join("manifest.json"),FileAccess.WRITE)
	if file == null:
		push_error("Cannot write art manifest")
		failures += 1
	else:
		file.store_string(JSON.stringify(manifest,"\t")+"\n")
	print("EmberArtV03 export: %d assets, %d failures" % [entries.size(),failures])
	quit(1 if failures else 0)


func _save(id: String, relative: String, image: Image) -> Dictionary:
	var path := OUTPUT.path_join(relative)
	if image.save_png(path) != OK:
		push_error("Cannot export %s" % path)
		failures += 1
	var entry := {
		"id":id,"kind":"character_sheet" if id.begins_with("character.") else ("inventory" if id.ends_with(".inventory") else "icon"),
		"version":"v0.3-M1","status":"integrated_in_runtime_art_sample",
		"path":path,"source_path":"res://scripts/visuals/pixel_art_v03.gd",
		"source_size":[image.get_width(),image.get_height()],"sha256":FileAccess.get_sha256(path),
		"method":"original_native_code_pixel_art","author":"Emberpack project / Codex",
		"palette_id":"ember_forest_v1_sample","allowed_scales":[2,3],"filter":"nearest",
		"license":"project_original_no_third_party_art","source_url":null,"prompt_record":null,
	}
	entries.append(entry)
	return entry
