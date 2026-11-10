extends RefCounted
## Separate five-battle prototype. Arcane residue is represented internally by
## ClassRun.gold but never enters the existing checkpoint format.

const Encounters = preload("res://scripts/classes/mage_encounters.gd")
const Catalog = preload("res://scripts/classes/class_catalog.gd")
const CURRENT_RULES_VERSION := 3
const REWARDS := [4, 4, 5, 6, 0]
const EXTENDED_REWARDS := [4, 4, 5, 4, 6, 5, 0]

static func encounters(version: int) -> Array:
	return Encounters.EXTENDED_CAMPAIGN_IDS if version >= 3 else Encounters.CAMPAIGN_IDS

static func rewards(version: int) -> Array:
	return EXTENDED_REWARDS if version >= 3 else REWARDS

static func stage_count(version: int) -> int:
	return encounters(version).size()

# The one-argument form remains the original five-stage API for older
# callers. The campaign UI always passes its checkpoint's explicit version.
static func encounter(stage: int, version: int = 2) -> String:
	var ids := encounters(version)
	return ids[stage] if stage >= 0 and stage < ids.size() else ""

static func initial_sources(version: int = CURRENT_RULES_VERSION) -> Array[Dictionary]:
	var sources: Array[Dictionary] = Catalog.initial_sources("mage")
	if version >= 2:
		for source: Dictionary in sources:
			source.remaining = 1
	sources.append_array(shop_sources())
	if version >= 3:
		for index in range(3, sources.size()):
			sources[index].remaining = 2 if index < 6 else 3
	return sources

static func shop_sources() -> Array[Dictionary]:
	return [
		{"id": "condense_focus", "kind": "arcane_focus", "remaining": 1, "cost": 4},
		{"id": "condense_ward", "kind": "mage_ward", "remaining": 1, "cost": 4},
		{"id": "condense_spark", "kind": "spark", "remaining": 1, "cost": 3},
		{"id": "condense_fire", "kind": "fire_mote", "remaining": 2, "cost": 2},
		{"id": "condense_water", "kind": "water_mote", "remaining": 2, "cost": 2},
		{"id": "condense_wind", "kind": "wind_mote", "remaining": 2, "cost": 2},
	]
