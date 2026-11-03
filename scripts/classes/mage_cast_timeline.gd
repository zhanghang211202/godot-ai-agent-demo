extends Node
## Presentation only. Predictions select a pose; only real events start recovery.

const Effects = preload("res://scripts/classes/mage_effects.gd")
const RELEASE_AT := Effects.WINDUP - Effects.FLIGHT
const IMPACT_AT := Effects.WINDUP
const END_AT := 1.06
@export var pose := 0
@onready var player: AnimationPlayer = $AnimationPlayer
var mode := "idle"
var _last_hit_time := -1.0

func reset() -> void:
	player.stop()
	pose = 0
	mode = "idle"
	_last_hit_time = -1.0

func show_event(event: Dictionary) -> void:
	if str(event.get("type", "")) not in ["spell", "spell_burst", "spell_multi"] or str(event.get("target", "")) != "enemy":
		return
	var time := float(event.get("time", -1.0))
	# A simultaneous volley or a multi-hit source shares one follow-through.
	if time >= 0 and is_equal_approx(time, _last_hit_time):
		return
	_last_hit_time = time
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
		if str(cast.get("target", "")) == "enemy":
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
		_seek(clampf(Effects.WINDUP - remaining, RELEASE_AT + 0.0001, IMPACT_AT - 0.0001))
	elif mode != "recovery":
		mode = "prediction"
		_seek(clampf(Effects.WINDUP - remaining, 0.0, RELEASE_AT - 0.0001))

func finish_battle() -> void:
	if mode == "prediction":
		reset()

func _seek(time: float) -> void:
	# Discrete tracks do not reliably replay an earlier key when seeking
	# backwards from recovery. Start at zero and cross the keys in order.
	player.stop()
	player.play("cast")
	player.seek(0.0, true)
	player.advance(clampf(time, 0.0, END_AT))
