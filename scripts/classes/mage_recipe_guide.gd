extends RefCounted
## Read-only guidance for the normal acquire/move/merge transactions.

const Catalog = preload("res://scripts/classes/class_catalog.gd")

static func availability(run: RefCounted, recipe: Dictionary) -> Dictionary:
	var counts := {}
	var required := {}
	var owned := {}
	for kind in [str(recipe.first), str(recipe.second)]:
		counts[kind] = 0
		owned[kind] = 0
		required[kind] = int(required.get(kind, 0)) + 1
	for item: Dictionary in run.items:
		if counts.has(item.kind):
			counts[item.kind] += 1
			owned[item.kind] += 1
	for source: Dictionary in run.sources:
		if counts.has(source.kind) and run.gold >= int(source.cost):
			counts[source.kind] += int(source.remaining)
	var missing: Array[String] = []
	var total_cost := 0
	for kind in required:
		if int(counts[kind]) < int(required[kind]):
			missing.append(kind)
		var need := maxi(0, int(required[kind]) - int(owned[kind]))
		var supplies: Array[Dictionary] = []
		for source: Dictionary in run.sources:
			if source.kind == kind and int(source.remaining) > 0:
				supplies.append(source)
		supplies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.cost) < int(b.cost))
		for source: Dictionary in supplies:
			var amount := mini(need, int(source.remaining))
			total_cost += amount * int(source.cost)
			need -= amount
			if need <= 0: break
	var insufficient_funds: bool = total_cost > int(run.gold)
	return {"counts": counts, "missing": missing, "required_cost": total_cost, "insufficient_funds": insufficient_funds, "available": missing.is_empty() and not insufficient_funds}

static func target_hints(run: RefCounted, held: Dictionary) -> Dictionary:
	var hints := {}
	if run.phase != "prepare" or held.is_empty():
		return hints
	var origin := str(held.get("origin", ""))
	var incoming := ""
	if origin == "source":
		var index := int(held.get("index", -1))
		if index < 0 or index >= run.sources.size():
			return hints
		incoming = str(run.sources[index].kind)
	elif origin == "bag":
		incoming = str(run.item_by_uid(int(held.get("uid", -1))).get("kind", ""))
	if incoming.is_empty():
		return hints
	for item: Dictionary in run.items:
		if origin == "bag" and int(item.uid) == int(held.get("uid", -1)):
			continue
		var product: String = run.get_merge_result({"kind": incoming}, item)
		if product.is_empty():
			continue
		var preview: Dictionary = run.preview_placement(held, item.pos)
		hints[int(item.uid)] = {"ok": bool(preview.ok), "product": product, "message": str(preview.message)}
	return hints

static func choose(run: RefCounted, recipe: Dictionary) -> Dictionary:
	if run.phase != "prepare" or run.class_id != "mage":
		return {"ok": false, "missing": [], "reason": "レシピは魔術師の準備中に選べます。"}
	var available := availability(run, recipe)
	if not available.available:
		return {"ok": false, "missing": available.missing}
	var normal_owned: Array[Dictionary] = []
	var normal_source: Array[Dictionary] = []
	var rotated_owned: Array[Dictionary] = []
	var rotated_source: Array[Dictionary] = []
	var blocked: Array[Dictionary] = []
	for target: Dictionary in run.items:
		var other := ""
		if str(target.kind) == str(recipe.first):
			other = str(recipe.second)
		elif str(target.kind) == str(recipe.second):
			other = str(recipe.first)
		else:
			continue
		var candidates: Array[Dictionary] = []
		# Already-owned ingredients are preferred: they consume no new source.
		for item: Dictionary in run.items:
			if item.kind == other and int(item.uid) != int(target.uid):
				candidates.append({"origin": "bag", "uid": int(item.uid), "rotated": bool(item.rotated)})
		for index in range(run.sources.size()):
			var source: Dictionary = run.sources[index]
			if source.kind == other and int(source.remaining) > 0 and run.gold >= int(source.cost):
				candidates.append({"origin": "source", "index": index, "rotated": false})
		for candidate: Dictionary in candidates:
			var preview: Dictionary = run.preview_placement(candidate, target.pos)
			var choice := {"ok": true, "held": candidate.duplicate(true), "target_uid": int(target.uid), "product": str(recipe.result), "preview": preview, "needs_placement": false}
			if preview.ok:
				if candidate.origin == "bag": normal_owned.append(choice)
				else: normal_source.append(choice)
			else:
				blocked.append(choice)
				var alternate := candidate.duplicate(true)
				alternate.rotated = not bool(candidate.rotated)
				var alternative: Dictionary = run.preview_placement(alternate, target.pos)
				if alternative.ok:
					var rotated_choice := {"ok": true, "held": alternate, "target_uid": int(target.uid), "product": str(recipe.result), "preview": alternative, "needs_placement": false, "auto_rotated": true}
					if candidate.origin == "bag": rotated_owned.append(rotated_choice)
					else: rotated_source.append(rotated_choice)
	if not normal_owned.is_empty(): return normal_owned[0]
	if not rotated_owned.is_empty(): return rotated_owned[0]
	if not normal_source.is_empty(): return normal_source[0]
	if not rotated_source.is_empty(): return rotated_source[0]
	if not blocked.is_empty(): return blocked[0]
	# Both ingredients are still in source stock. Select one for normal placement.
	for kind in [str(recipe.first), str(recipe.second)]:
		for index in range(run.sources.size()):
			var source: Dictionary = run.sources[index]
			if source.kind == kind and int(source.remaining) > 0 and run.gold >= int(source.cost):
				return {"ok": true, "held": {"origin": "source", "index": index, "rotated": false}, "target_uid": -1, "product": str(recipe.result), "needs_placement": true, "first_kind": kind,
					"next_kind": str(recipe.second) if kind == str(recipe.first) else str(recipe.first)}
	return {"ok": false, "missing": available.missing}
