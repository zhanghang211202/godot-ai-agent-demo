extends RefCounted
## The existing permanent mitigation, visualized as a mage's reactive ward.
## Only actual blocked incoming damage can reveal a shield. No shield HP pool.

const LIFE := 0.46

static func visible_shields(numbers: Array) -> Array[Dictionary]:
	var shields: Array[Dictionary] = []
	for index in range(numbers.size() - 1, -1, -1):
		var number: Dictionary = numbers[index]
		var age := float(number.get("age", LIFE))
		if number.get("target") != "hero" or int(number.get("armor", 0)) <= 0 or age < 0 or age >= LIFE:
			continue
		shields.append({"progress": age / LIFE, "absorbed": int(number.armor), "hits": int(number.hits)})
		if shields.size() == 3:
			break
	return shields

static func geometry(hero: Rect2) -> Dictionary:
	return {"center": hero.get_center() + Vector2(0, 5), "radius": Vector2(maxf(78, hero.size.x * 0.49), hero.size.y * 0.51)}

static func draw_back(canvas: CanvasItem, shields: Array, hero: Rect2) -> void:
	if shields.is_empty():
		return
	var shield: Dictionary = shields[0]
	var shape := geometry(hero)
	var points := ring(shape.center, shape.radius, 0, TAU, 32)
	canvas.draw_colored_polygon(points, Color("567bc4", (1.0 - float(shield.progress)) * 0.12))
	canvas.draw_polyline(ring(shape.center, Vector2(shape.radius) * 0.94, 0, TAU, 32), Color("8fbfff", (1.0 - float(shield.progress)) * 0.24), 2, false)

static func draw_front(canvas: CanvasItem, shields: Array, hero: Rect2) -> void:
	for shield: Dictionary in shields:
		var progress := float(shield.progress)
		var fade := 1.0 - progress
		var shape := geometry(hero)
		var radius: Vector2 = shape.radius
		var center: Vector2 = shape.center
		canvas.draw_polyline(ring(center, radius, 0, TAU, 32), Color("9cc6ff", fade * 0.7), 2, false)
		# Brighter frontal arc catches the incoming spell, leaving the face clear.
		canvas.draw_polyline(ring(center, radius, -0.78, 0.78, 12), Color("ddf5ff", fade), 4, false)
		for hit in range(mini(4, int(shield.hits))):
			var point := center + Vector2(radius.x * 0.94, (hit - (int(shield.hits) - 1) * 0.5) * 22)
			var ripple := 7 + progress * 34
			canvas.draw_polyline(ring(point, Vector2(ripple * 0.42, ripple), 0, TAU, 10), Color("c5eaff", fade), 2, false)
		for index in range(7):
			var angle := -0.72 + index * 0.24
			var at := center + Vector2(cos(angle), sin(angle)) * radius
			var points := ring(at, Vector2.ONE * 6, PI / 6, TAU + PI / 6, 6)
			canvas.draw_polyline(points, Color("c2d9ff", fade * 0.8), 2, false)
			var particle := snap(at + Vector2(14 + progress * 32, sin(index * 2.4) * progress * 20))
			canvas.draw_rect(Rect2(particle, Vector2(4, 4)), Color("c5ecff", fade))

static func ring(center: Vector2, radius: Vector2, start: float, end: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments + 1):
		var angle := lerpf(start, end, float(index) / segments)
		points.append(snap(center + Vector2(cos(angle), sin(angle)) * radius))
	return points

static func snap(point: Vector2) -> Vector2:
	return Vector2(roundf(point.x / 2) * 2, roundf(point.y / 2) * 2)
