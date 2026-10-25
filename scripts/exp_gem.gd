extends Area2D

## Pooled EXP pickup. Sits in place with a gentle bob until the player's
## collection area touches it, then flies at the player with acceleration
## (the "magnet"), and finally pays out through the event bus.
##
## Uses an Area2D instead of a physics body: gems never collide with the
## world, so they are far cheaper to move by the hundreds.

enum State { IDLE, MAGNET }

const MAGNET_ACCELERATION := 1500.0
const MAGNET_MAX_SPEED := 500.0
const COLLECT_DISTANCE := 12.0
const BOB_AMPLITUDE := 1.5
const BOB_SPEED := 3.0

var exp_value := 1

var _state := State.IDLE
var _player: Node2D
var _velocity := Vector2.ZERO
var _bob_phase := 0.0
var _pulse_phase := 0.0
var _pool: ObjectPool


## Called by the gem system when a dropped gem enters play.
func setup(value: int, position_: Vector2, pool: ObjectPool) -> void:
	exp_value = maxi(1, value)
	_pool = pool
	global_position = position_
	_state = State.IDLE
	_velocity = Vector2.ZERO
	_bob_phase = randf() * TAU
	$Polygon2D.scale = Vector2.ONE


## Called by the player's collection area.
func start_magnet(player: Node2D) -> void:
	if _state == State.MAGNET:
		return
	_player = player
	_state = State.MAGNET


func _physics_process(delta: float) -> void:
	match _state:
		State.IDLE:
			_bob_phase += delta * BOB_SPEED
			$Polygon2D.position.y = sin(_bob_phase) * BOB_AMPLITUDE
		State.MAGNET:
			if _player == null or not is_instance_valid(_player):
				return
			var to_player := _player.global_position - global_position
			var distance := to_player.length()
			if distance <= COLLECT_DISTANCE:
				_collect()
				return
			_velocity = (_velocity + to_player.normalized() * MAGNET_ACCELERATION * delta).limit_length(MAGNET_MAX_SPEED)
			global_position += _velocity * delta
			_pulse_phase += delta * 12.0
			$Polygon2D.scale = Vector2.ONE * (1.0 + 0.15 * sin(_pulse_phase))


func _collect() -> void:
	GameEvents.exp_collected.emit(exp_value)
	if _pool != null:
		_pool.release(self)


## ObjectPool lifecycle: handed out by the gem system.
func on_acquire() -> void:
	visible = true
	set_physics_process(true)


## ObjectPool lifecycle: returned to the pool.
func on_release() -> void:
	visible = false
	set_physics_process(false)
	_state = State.IDLE
	_player = null
	_velocity = Vector2.ZERO
	_pulse_phase = 0.0
	$Polygon2D.scale = Vector2.ONE
