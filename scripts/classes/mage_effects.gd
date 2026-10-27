extends RefCounted
## Read-only spell choreography: upcoming timing -> flight, real hit -> impact.
## No random clock, delayed damage, collision, extra combat event or save state.

const Art = preload("res://scripts/classes/mage_spell_art.gd")
const LIFE := 0.74
const WINDUP := 0.64
const FLIGHT := 0.24
const COLORS := {"spark": Color("bc9cff"), "flame_glyph": Color("ff964e"), "tide_lances": Color("70d9fa"), "enemy": Color("81e2ff")}
const DURATIONS := {"spark": 0.48, "flame_glyph": LIFE, "tide_lances": 0.64, "enemy": 0.48}
const MAX_EFFECTS := 8
const MAX_CASTS := 6

static func visible_effects(numbers: Array) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	for index in range(numbers.size() - 1, -1, -1):
		var number: Dictionary = numbers[index]
		var kind := str(number.get("kind", ""))
		var age := float(number.get("age", LIFE))
		var duration := float(DURATIONS.get(kind, LIFE))
		if not COLORS.has(kind) or age < 0 or age >= duration or int(number.get("amount", 0)) <= 0:
			continue
		effects.append({"kind": kind, "target": str(number.target), "progress": age / duration,
			"age": age, "phase": "impact" if age < 0.18 else "residue", "hits": int(number.hits)})
		if effects.size() == MAX_EFFECTS:
			break
	return effects

static func visible_casts(actions: Array, timing: Dictionary) -> Array[Dictionary]:
	var casts: Array[Dictionary] = []
	for action: Dictionary in actions:
		var kind := str(action.get("kind", ""))
		var uid := int(action.get("uid", -1))
		if kind == "enemy" or not COLORS.has(kind) or not timing.get("sources", {}).has(uid):
			continue
		var remaining := float(timing.sources[uid].remaining) - float(timing.get("substep", 0.0))
		if remaining <= 0 or remaining > WINDUP:
			continue
		casts.append({"kind": kind, "target": "enemy", "source_uid": uid, "remaining": remaining,
			"progress": 1.0 - remaining / WINDUP, "phase": "flight" if remaining <= FLIGHT else "gather",
			"planned_hits": int(action.get("hits", 1))})
	var incoming := float(timing.get("enemy_remaining", 999)) - float(timing.get("substep", 0.0))
	if incoming > 0 and incoming <= WINDUP:
		casts.append({"kind": "enemy", "target": "hero", "source_uid": 0, "remaining": incoming,
			"progress": 1.0 - incoming / WINDUP, "phase": "flight" if incoming <= FLIGHT else "gather", "planned_hits": 1})
	# Keep imminent attacks when many legal sources charge together.
	casts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.remaining < b.remaining)
	if casts.size() > MAX_CASTS:
		casts.resize(MAX_CASTS)
	return casts

static func draw_ground(canvas: CanvasItem, casts: Array, effects: Array, hero: Vector2, enemy: Vector2) -> void:
	for cast: Dictionary in casts:
		var at := enemy if cast.target == "hero" else hero
		var alpha := 0.18 + float(cast.progress) * 0.30
		seal(canvas, at - Vector2(0, 11), Vector2(43, 10), float(cast.progress) * 0.6, Color(COLORS[cast.kind], alpha), 8)
	for effect: Dictionary in effects:
		if effect.kind == "flame_glyph":
			var progress := float(effect.progress)
			seal(canvas, enemy - Vector2(0, 12 + progress * 12), Vector2(26 + progress * 64, 7 + progress * 16), 0, Color("ef8e48", (1.0 - progress) * 0.7), 12)

static func draw_cast(canvas: CanvasItem, cast: Dictionary, from: Vector2, to: Vector2) -> void:
	var kind: String = cast.kind
	var remaining: float = cast.remaining
	var progress: float = cast.progress
	var color: Color = COLORS[kind]
	var gathering := clampf(progress * 1.8, 0, 1)
	# Rings sit around the orb/core, rather than masking a face with a full flash.
	seal(canvas, from, Vector2.ONE * (25 - gathering * 7), progress * 2.2, Color(color, gathering * 0.85), 6)
	for index in range(7):
		var angle := index * TAU / 7 + progress * 1.1
		var point := from + Vector2.from_angle(angle) * (46 - gathering * 30)
		diamond(canvas, point, 2, Color(color, gathering * 0.85))
	star(canvas, from, 5 + gathering * 5, Color("fff2d5", gathering * 0.9))
	if remaining > FLIGHT:
		return
	var flight := clampf(1.0 - remaining / FLIGHT, 0, 1)
	var count := clampi(int(cast.planned_hits), 1, 3) if kind == "tide_lances" else 1
	for index in range(count):
		var offset := (index - (count - 1) * 0.5) * 22
		var tip := trajectory(from, to + Vector2(0, offset), flight, kind, index)
		trail(canvas, from, to + Vector2(0, offset), flight, kind, index, color)
		if kind == "flame_glyph":
			pixel_sprite(canvas, "flame", tip, 2, 1.0, int(progress * 24))
		elif kind == "tide_lances":
			pixel_sprite(canvas, "lance", tip - Vector2(34, 0), 2, 1.0)
		elif kind == "spark":
			pixel_sprite(canvas, "comet", tip - Vector2(22, 0), 2, 1.0)
			star(canvas, tip, 10, Color("fff3ff"))
		else:
			diamond(canvas, tip, 12, Color("245a99"))
			diamond(canvas, tip, 8, color)
			star(canvas, tip, 10, Color("eeffff"))

static func trajectory(from: Vector2, to: Vector2, progress: float, kind: String, index: int) -> Vector2:
	var bend := -42.0 if kind == "spark" else -24.0 if kind == "flame_glyph" else (index - 1) * 19.0 if kind == "tide_lances" else -18.0
	return snap(from.lerp(to, progress) + Vector2(0, sin(progress * PI) * bend))

static func trail(canvas: CanvasItem, from: Vector2, to: Vector2, progress: float, kind: String, index: int, color: Color) -> void:
	for segment in range(13):
		var offset := float(segment) / 13
		var value := maxf(0, progress - offset * 0.58)
		if is_zero_approx(value):
			continue
		var at := trajectory(from, to, value, kind, index)
		var previous := trajectory(from, to, maxf(0, value - 0.05), kind, index)
		if at.distance_squared_to(previous) < 4:
			continue
		var normal := (at - previous).normalized().orthogonal()
		var extent := 5.0 * (1.0 - offset) + 1
		var edge := normal * extent
		canvas.draw_line(previous, at, Color(color.darkened(0.5), (1.0 - offset) * 0.36), extent * 2 + 5, false)
		canvas.draw_colored_polygon(PackedVector2Array([snap(previous + edge * 0.8), snap(at + edge), snap(at - edge), snap(previous - edge * 0.8)]), Color(color, (1.0 - offset) * 0.72))
		if segment < 8:
			canvas.draw_line(previous, at, Color("eff8ff", (1.0 - offset) * 0.85), 2, false)
		if segment % 4 == 0:
			diamond(canvas, at + normal * (9 + offset * 5), 2, Color(color, 0.6 * (1.0 - offset)))

static func draw_effect(canvas: CanvasItem, effect: Dictionary, hero: Vector2, enemy: Vector2) -> void:
	var kind: String = effect.kind
	var progress: float = effect.progress
	var at := hero if str(effect.target) == "hero" else enemy
	var color: Color = COLORS[kind]
	var fade := 1.0 - progress
	if progress < 0.24:
		var sign_x := -1 if effect.target == "hero" else 1
		canvas.draw_line(snap(at - Vector2(sign_x * 90, 0)), snap(at), Color(color, (1.0 - progress / 0.24) * 0.6), 3, false)
	if kind == "flame_glyph":
		flame_impact(canvas, at, progress)
	elif kind == "tide_lances":
		# Impacts use the emitted segments, including a lethal one-hit truncation.
		for index in range(clampi(int(effect.hits), 1, 3)):
			var offset := (index - (int(effect.hits) - 1) * 0.5) * 22
			var center := at + Vector2(0, offset)
			var lance_alpha := clampf(1.0 - progress * 3, 0, 1)
			pixel_sprite(canvas, "lance", center - Vector2(22 + progress * 22, 0), 2, lance_alpha)
			star(canvas, center, (1.0 - progress) * 18 + 3, Color("edffff", fade))
			seal(canvas, center, Vector2(14 + progress * 34, 8 + progress * 24), index * 0.7, Color(color, fade * 0.8), 6)
			for shard_index in range(6):
				var angle := shard_index * TAU / 6 + index * 0.6
				var point := center + Vector2.from_angle(angle) * (12 + progress * 58)
				point.y += progress * progress * 23
				pixel_sprite(canvas, "shard", point, 1, fade)
	else:
		var radius := 14 + progress * 48
		seal(canvas, at, Vector2.ONE * radius, progress * 0.4, Color(color, fade * 0.8), 8)
		star(canvas, at, maxf(3, 29 * (1.0 - progress * 2)), Color("f7f0ff", fade))
		for index in range(10):
			var angle := index * TAU / 10 + (0.2 if kind == "spark" else 0.6)
			var direction := Vector2.from_angle(angle)
			var point := at + direction * (12 + progress * 64)
			canvas.draw_line(snap(point - direction * 8 * fade), snap(point), Color(color, fade), 2, false)
			diamond(canvas, point, 3, Color(color, fade))
		if kind == "spark":
			for index in range(3):
				star(canvas, at + Vector2((index - 1) * 26, -progress * 40 - 18 - index * 7), 5 * fade, Color(color, fade))
	# A short, local hot core. It never washes out the whole stage or HUD.
	if progress < 0.18:
		star(canvas, at, 20 * (1.0 - progress / 0.18), Color("fff4cf", 0.8))

static func flame_impact(canvas: CanvasItem, at: Vector2, progress: float) -> void:
	var fade := 1.0 - progress
	# Dark outer tongues, amber body and cream cores come from the tiny mask.
	for index in range(5):
		var angle := -PI + index * PI / 4
		var point := at + Vector2(cos(angle) * (15 + progress * 49), sin(angle) * (12 + progress * 28) - progress * 20)
		pixel_sprite(canvas, "flame", point, 2 if index % 2 == 0 else 1, fade * 0.9, int(progress * 16) + index)
	pixel_sprite(canvas, "flame", at - Vector2(0, 9 + progress * 30), 3 if progress < 0.36 else 2, fade, int(progress * 20))
	seal(canvas, at, Vector2.ONE * (20 + progress * 60), 0.15, Color("ffbc62", fade * 0.8), 12)
	for index in range(18):
		var angle := index * 2.39996
		var speed := 26 + (index % 5) * 13
		var point := at + Vector2.from_angle(angle) * (14 + progress * speed)
		point.y += progress * progress * 35 - progress * 25
		diamond(canvas, point, 2 if index % 3 else 4, Color("ffd67d" if index % 2 else "eb683e", fade))
	# Sparse ascending cinders remain after the bright body contracts.
	if progress > 0.35:
		for index in range(6):
			var point := at + Vector2((index - 2.5) * 17, -progress * 76 + (index % 3) * 12)
			diamond(canvas, point, 5, Color("644b70", fade * 0.5))
			diamond(canvas, point - Vector2(0, 4), 2, Color("ffc86a", fade))

static func seal(canvas: CanvasItem, point: Vector2, radius: Vector2, rotation: float, color: Color, segments: int) -> void:
	var points := PackedVector2Array()
	for index in range(segments + 1):
		var angle := index * TAU / segments + rotation
		points.append(snap(point + Vector2(cos(angle), sin(angle)) * radius))
	canvas.draw_polyline(points, color, 2, false)
	for index in range(segments):
		if index % 2 == 0:
			diamond(canvas, points[index], 3, color)

static func pixel_sprite(canvas: CanvasItem, kind: String, point: Vector2, scale: int, alpha: float, frame: int = 0) -> void:
	if alpha <= 0:
		return
	var texture := Art.texture(kind, frame)
	var extent := texture.get_size() * scale
	canvas.draw_texture_rect(texture, Rect2(snap(point - extent * 0.5), extent), false, Color(1, 1, 1, alpha))

static func diamond(canvas: CanvasItem, point: Vector2, radius: float, color: Color) -> void:
	var extent := maxf(2, floorf(radius / 2) * 2)
	var center := snap(point)
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-extent, 0), center + Vector2(0, -extent), center + Vector2(extent, 0), center + Vector2(0, extent)]), color)

static func star(canvas: CanvasItem, point: Vector2, radius: float, color: Color) -> void:
	var extent := maxf(2, floorf(radius / 2) * 2)
	var center := snap(point)
	canvas.draw_rect(Rect2(center - Vector2(extent, 2), Vector2(extent * 2, 4)), color)
	canvas.draw_rect(Rect2(center - Vector2(2, extent), Vector2(4, extent * 2)), color)
	diamond(canvas, center, minf(extent, 6), Color(1, 0.98, 0.89, color.a))

static func snap(point: Vector2) -> Vector2:
	return Vector2(roundf(point.x / 2) * 2, roundf(point.y / 2) * 2)
