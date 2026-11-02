extends Node2D
## Presentation-only hit reaction. Position belongs to this wrapper; the
## arena continues to own the child sprite's atlas region, scale and layout.

@onready var player: AnimationPlayer = $AnimationPlayer
var _last_hit_time := -1.0
var _seen_event_ids: Array[int] = []

func show_hit(event: Dictionary) -> bool:
	if str(event.get("type", "")) != "enemy_attack" or str(event.get("target", "")) != "hero":
		return false
	var event_id := int(event.get("event_id", -1))
	var time := float(event.get("time", -1.0))
	# Multiple hits in one engine step share one visible recoil. Replayed event
	# IDs must not restart it, but a later attack can interrupt and replay it.
	if event_id > 0 and event_id in _seen_event_ids:
		return false
	if event_id > 0:
		_seen_event_ids.append(event_id)
		if _seen_event_ids.size() > 64:
			_seen_event_ids.pop_front()
	if time >= 0 and is_equal_approx(time, _last_hit_time):
		return false
	_last_hit_time = time
	player.stop()
	position = Vector2.ZERO
	player.play("hit")
	player.advance(0.0)
	return true

func advance_motion(delta: float, paused: bool, speed: float) -> void:
	if paused or delta <= 0.0 or speed <= 0.0:
		return
	player.advance(delta * speed)

func reset_motion() -> void:
	player.stop()
	position = Vector2.ZERO
	_last_hit_time = -1.0
	_seen_event_ids.clear()
