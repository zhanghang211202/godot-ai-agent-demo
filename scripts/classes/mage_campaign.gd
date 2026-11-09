extends RefCounted
## Separate five-battle prototype. Arcane residue is represented internally by
## ClassRun.gold but never enters the existing checkpoint format.

const Encounters = preload("res://scripts/classes/mage_encounters.gd")
const Catalog = preload("res://scripts/classes/class_catalog.gd")
const CURRENT_RULES_VERSION := 2
const REWARDS := [4, 4, 5, 6, 0]

static func encounter(stage: int) -> String:
	return Encounters.CAMPAIGN_IDS[stage] if stage >= 0 and stage < Encounters.CAMPAIGN_IDS.size() else ""

static func initial_sources(version: int = CURRENT_RULES_VERSION) -> Array[Dictionary]:
	var sources: Array[Dictionary] = Catalog.initial_sources("mage")
	if version >= 2:
		for source: Dictionary in sources:
			source.remaining = 1
	sources.append_array(shop_sources())
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
