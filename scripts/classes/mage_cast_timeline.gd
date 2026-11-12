extends Node
## Presentation only. Predictions select a pose; only real events start recovery.

const Effects = preload("res://scripts/classes/mage_effects.gd")
const RELEASE_AT := Effects.WINDUP - Effects.FLIGHT
const IMPACT_AT := Effects.WINDUP
const END_AT := 1.06
@export var pose := 0
@onready var player: AnimationPlayer = $AnimationPlayer
var mode := "idle"
var clip := "mage-cast"
var variants_enabled := true
var _last_hit_time := -1.0

func _clip_for(_kind: String) -> String:
	if variants_enabled:
		# The mage campaign uses one consistent four-pose staff illustration
		# for every spell; the source kind still controls combat and effects.
		return "mage-swing"
	return "mage-cast"

func reset() -> void:
	player.stop()
	pose = 0
	mode = "idle"
	clip = "mage-cast"
	_last_hit_time = -1.0

func show_event(event: Dictionary) -> void:
	if str(event.get("type", "")) not in ["spell", "spell_burst", "spell_multi"] or str(event.get("target", "")) != "enemy":
		return
	var time := float(event.get("time", -1.0))
	# A simultaneous volley or a multi-hit source shares one follow-through.
	if time >= 0 and is_equal_approx(time, _last_hit_time):
		return
	_last_hit_time = time
	if mode == "idle":
		clip = _clip_for(str(event.get("source_kind", "")))
	mode = "recovery"
	_seek(IMPACT_AT)

func advance(delta: float, paused: bool, speed: float) -> void:
	if paused or delta <= 0.0 or speed <= 0.0 or mode != "recovery":
		return
	player.advance(delta * speed)
	if not player.is_playing():
		pose = 0
		mode = "idle"

func sync_prediction(casts: Array) -> void:
	var next: Dictionary = {}
	for cast: Dictionary in casts:
		if str(cast.get("target", "")) == "enemy" and not bool(cast.get("summon", false)):
			next = cast
			break
	if next.is_empty():
		if mode == "prediction":
			reset()
		return
	var remaining := clampf(float(next.remaining), 0.0, Effects.WINDUP)
	# Release has priority over a previous recovery. A gather does not interrupt
	# follow-through, which prevents very close sources flickering between poses.
	if remaining <= Effects.FLIGHT:
		mode = "prediction"
		clip = _clip_for(str(next.get("kind", "")))
		_seek(clampf(Effects.WINDUP - remaining, RELEASE_AT + 0.0001, IMPACT_AT - 0.0001))
	elif mode != "recovery":
		mode = "prediction"
		clip = _clip_for(str(next.get("kind", "")))
		_seek(clampf(Effects.WINDUP - remaining, 0.0, RELEASE_AT - 0.0001))

func finish_battle() -> void:
	if mode == "prediction":
		reset()

func _seek(time: float) -> void:
	# Discrete tracks do not reliably replay an earlier key when seeking
	# backwards from recovery. Start at zero and cross the keys in order.
	player.stop()
	player.play("swing" if clip == "mage-swing" else "gesture" if clip == "mage-gesture" else "cast")
	player.seek(0.0, true)
	player.advance(clampf(time, 0.0, END_AT))
