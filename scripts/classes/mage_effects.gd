extends RefCounted
## Original code-drawn spell impacts. Read event feedback; never resolve damage.

const LIFE := 0.36
const COLORS := {"spark": Color("bc9cff"), "flame_glyph": Color("ff964e"), "tide_lances": Color("70d9fa"), "enemy": Color("81e2ff")}

static func visible_effects(numbers: Array) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	for index in range(numbers.size() - 1, -1, -1):
		var number: Dictionary = numbers[index]
		var kind := str(number.get("kind", ""))
		if not COLORS.has(kind) or float(number.get("age", LIFE)) >= LIFE or int(number.get("amount", 0)) <= 0:
			continue
		effects.append({"kind": kind, "target": str(number.target), "progress": clampf(float(number.age) / LIFE, 0, 1), "hits": int(number.hits)})
		if effects.size() == 8:
			break
	return effects

static func draw_effect(canvas: CanvasItem, effect: Dictionary, hero: Vector2, enemy: Vector2) -> void:
	var kind: String = effect.kind
	var progress: float = effect.progress
	var from := enemy if str(effect.target) == "hero" else hero
	var to := hero if str(effect.target) == "hero" else enemy
	var tint: Color = COLORS[kind]
	tint.a = 1.0 - progress
	if kind == "tide_lances":
		# Draw only the actual emitted segments, including a lethal truncated cast.
		for index in range(mini(3, int(effect.hits))):
			var offset := Vector2(0, (index - (int(effect.hits) - 1) * 0.5) * 18)
			var tip := snap(to + offset)
			var shaft := Vector2(46, 9)
			canvas.draw_line(snap(from + offset), tip, Color(tint, tint.a * 0.5), 2, false)
			canvas.draw_colored_polygon(PackedVector2Array([tip + Vector2(12, 0), tip - Vector2(shaft.x, -shaft.y), tip - Vector2(30, 0), tip - shaft]), tint)
			canvas.draw_line(tip - Vector2(30, 0), tip + Vector2(10, 0), Color(0.88, 1, 1, tint.a), 3, false)
	elif kind == "flame_glyph":
		var radius := 12 + progress * 40
		for index in range(12):
			var direction := Vector2.from_angle(index * TAU / 12)
			var point := snap(to + direction * radius)
			canvas.draw_rect(Rect2(point - Vector2.ONE * 3, Vector2(6, 6)), tint)
		star(canvas, to, 19 * (1.0 - progress) + 4, Color(1, 0.86, 0.48, tint.a))
		canvas.draw_line(snap(from.lerp(to, 0.4 + progress * 0.6)), snap(to), Color(tint, tint.a * 0.6), 4, false)
	else:
		canvas.draw_line(snap(from.lerp(to, progress)), snap(to), tint, 3, false)
		star(canvas, to, 11 * (1.0 - progress) + 3, tint)
		for index in range(6):
			var point := snap(to + Vector2.from_angle(index * TAU / 6) * (9 + progress * 25))
			canvas.draw_rect(Rect2(point, Vector2(4, 4)), Color(tint, tint.a * 0.8))

static func star(canvas: CanvasItem, point: Vector2, radius: float, color: Color) -> void:
	var extent := maxf(2, floorf(radius / 2) * 2)
	var center := snap(point)
	canvas.draw_rect(Rect2(center - Vector2(extent, 2), Vector2(extent * 2, 4)), color)
	canvas.draw_rect(Rect2(center - Vector2(2, extent), Vector2(4, extent * 2)), color)
	canvas.draw_rect(Rect2(center - Vector2(4, 4), Vector2(8, 8)), Color(1, 0.98, 0.89, color.a))

static func snap(point: Vector2) -> Vector2:
	return Vector2(roundf(point.x / 2) * 2, roundf(point.y / 2) * 2)
