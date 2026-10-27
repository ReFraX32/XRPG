extends CharacterBody2D

## Horde enemy. One shared scene (the animated slime) serves every enemy
## variant: the spawner injects an EnemyDefinition plus difficulty scaling
## through setup() and recycles bodies through an ObjectPool.
##
## Also keeps the legacy unpooled behavior (hand-placed enemies in the old
## world scene respawn at their spawn point instead of being recycled).

const DEFAULT_DAMAGE_TAKEN := 20.0  # fallback when the attacker has no stat block

var max_health := 100.0
var health := 100.0
var move_speed := 40.0
var contact_damage := 10.0
var exp_value := 1
var definition: EnemyDefinition

var _player: Node2D
var _pool: ObjectPool
var _pooled := false
var _dying := false
# Physics frame at the moment of death; drives the spawner's pause-aware
# corpse-recycle safety net (wall clock would keep counting through pauses,
# recycling corpses whose death animation is merely frozen).
var _death_frame := 0
var _can_take_damage := true
var _player_in_attack_zone := false
# Legacy-only: chase flag driven by the detection area.
var _chasing := false

var _knockback_velocity: Vector2 = Vector2.ZERO
var _slow_factor: float = 0.0
var _slow_timer: float = 0.0

static var _ghost_frames: SpriteFrames = null
static var _bat_frames: SpriteFrames = null
var _slime_frames: SpriteFrames = null

# Monster abilities & animations state
var _float_time: float = 0.0
var _ethereal_timer: float = 0.0
var _is_ethereal: bool = false
var _ethereal_duration: float = 0.0

var _wave_time: float = 0.0
var _is_telegraphing: bool = false
var _is_diving: bool = false
var _dive_duration: float = 0.0
var _dive_direction: Vector2 = Vector2.ZERO
var _dive_cooldown: float = 0.0


static func _get_ghost_frames() -> SpriteFrames:
	if _ghost_frames != null:
		return _ghost_frames
	var tex: Texture2D = load("res://art/characters/ghost.png")
	var frames := SpriteFrames.new()
	var f0 := AtlasTexture.new()
	f0.atlas = tex
	f0.region = Rect2(0, 0, 36, 36)
	var f1 := AtlasTexture.new()
	f1.atlas = tex
	f1.region = Rect2(36, 0, 36, 36)
	
	frames.add_animation(&"idle")
	frames.set_animation_loop(&"idle", true)
	frames.set_animation_speed(&"idle", 3.0)
	frames.add_frame(&"idle", f0)
	frames.add_frame(&"idle", f1)
	
	frames.add_animation(&"walk")
	frames.set_animation_loop(&"walk", true)
	frames.set_animation_speed(&"walk", 5.0)
	frames.add_frame(&"walk", f0)
	frames.add_frame(&"walk", f1)
	
	frames.add_animation(&"death")
	frames.set_animation_loop(&"death", false)
	frames.set_animation_speed(&"death", 6.0)
	frames.add_frame(&"death", f0)
	frames.add_frame(&"death", f1)
	
	_ghost_frames = frames
	return _ghost_frames


static func _get_bat_frames() -> SpriteFrames:
	if _bat_frames != null:
		return _bat_frames
	var tex: Texture2D = load("res://art/characters/bat.png")
	var frames := SpriteFrames.new()
	var f0 := AtlasTexture.new()
	f0.atlas = tex
	f0.region = Rect2(0, 0, 40, 26)
	var f1 := AtlasTexture.new()
	f1.atlas = tex
	f1.region = Rect2(40, 0, 40, 26)
	
	frames.add_animation(&"idle")
	frames.set_animation_loop(&"idle", true)
	frames.set_animation_speed(&"idle", 4.0)
	frames.add_frame(&"idle", f0)
	frames.add_frame(&"idle", f1)
	
	frames.add_animation(&"walk")
	frames.set_animation_loop(&"walk", true)
	frames.set_animation_speed(&"walk", 7.0)
	frames.add_frame(&"walk", f0)
	frames.add_frame(&"walk", f1)
	
	frames.add_animation(&"death")
	frames.set_animation_loop(&"death", false)
	frames.set_animation_speed(&"death", 8.0)
	frames.add_frame(&"death", f0)
	frames.add_frame(&"death", f1)
	
	_bat_frames = frames
	return _bat_frames


func _ready() -> void:
	if not is_in_group("enemy"):
		add_to_group("enemy")
	_slime_frames = $AnimatedSprite2D.sprite_frames
	$AnimatedSprite2D.sprite_frames.set_animation_loop(&"death", false)


## Called by the spawner on every pooled spawn. Fully resets visual and
## gameplay state, since pooled bodies are reused across variants.
func setup(p_definition: EnemyDefinition, p_player: Node2D, p_pool: ObjectPool,
		health_scale: float, speed_scale: float, exp_scale: float) -> void:
	definition = p_definition
	_player = p_player
	_pool = p_pool
	_pooled = p_pool != null
	_dying = false
	_can_take_damage = true
	_player_in_attack_zone = false
	_chasing = true
	_knockback_velocity = Vector2.ZERO
	_slow_factor = 0.0
	_slow_timer = 0.0

	max_health = maxf(1.0, p_definition.max_health * health_scale)
	health = max_health
	move_speed = p_definition.move_speed * speed_scale
	contact_damage = p_definition.contact_damage
	exp_value = maxi(1, roundi(p_definition.exp_value * exp_scale))

	scale = Vector2.ONE * p_definition.scale
	$AnimatedSprite2D.modulate = p_definition.tint
	$AnimatedSprite2D.position = Vector2.ZERO
	$AnimatedSprite2D.rotation = 0.0
	$healthbar.max_value = max_health
	# Horde enemies always know where the player is; detection stays unused.
	$detection_area.monitoring = false

	_float_time = randf() * TAU
	_ethereal_timer = randf_range(1.0, 3.0)
	_is_ethereal = false
	_ethereal_duration = 0.0

	_wave_time = randf() * TAU
	_is_telegraphing = false
	_is_diving = false
	_dive_duration = 0.0
	_dive_direction = Vector2.ZERO
	_dive_cooldown = randf_range(2.0, 4.0)

	if p_definition.id == &"ghost":
		$AnimatedSprite2D.sprite_frames = _get_ghost_frames()
	elif p_definition.id == &"bat":
		$AnimatedSprite2D.sprite_frames = _get_bat_frames()
	else:
		$AnimatedSprite2D.sprite_frames = _slime_frames

	$AnimatedSprite2D.play(&"walk")


func _physics_process(delta: float) -> void:
	if _dying:
		return
	deal_with_damage()
	update_health()
	
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_factor = 0.0
	
	var is_ghost: bool = definition != null and definition.id == &"ghost"
	var is_bat: bool = definition != null and definition.id == &"bat"
	
	# Ghost ability: levitation float & ethereal phasing
	if is_ghost:
		_float_time += delta
		$AnimatedSprite2D.position.y = sin(_float_time * 4.5) * 4.0
		_ethereal_timer += delta
		if not _is_ethereal and _ethereal_timer >= 4.5:
			_is_ethereal = true
			_ethereal_duration = 1.8
			_ethereal_timer = 0.0
		if _is_ethereal:
			_ethereal_duration -= delta
			$AnimatedSprite2D.modulate = Color(0.7, 0.9, 1.0, 0.4)
			_slow_factor = 0.0
			if _ethereal_duration <= 0.0:
				_is_ethereal = false
				$AnimatedSprite2D.modulate = definition.tint
	
	# Bat ability: wave-flight, dive-bomb telegraph & swoop
	if is_bat:
		_wave_time += delta
		_dive_cooldown -= delta
		if not _is_telegraphing and not _is_diving and _dive_cooldown <= 0.0:
			if _player != null and is_instance_valid(_player):
				var d: float = global_position.distance_to(_player.global_position)
				if d < 220.0 and d > 35.0:
					_is_telegraphing = true
					_dive_duration = 0.35
					$AnimatedSprite2D.modulate = Color(1.8, 0.3, 0.3, 1.0)
		elif _is_telegraphing:
			_dive_duration -= delta
			velocity = _knockback_velocity
			move_and_slide()
			_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			if _dive_duration <= 0.0:
				_is_telegraphing = false
				_is_diving = true
				_dive_duration = 0.5
				$AnimatedSprite2D.modulate = definition.tint
				if _player != null and is_instance_valid(_player):
					_dive_direction = (_player.global_position - global_position).normalized()
				else:
					_dive_direction = Vector2.DOWN
			return
		elif _is_diving:
			_dive_duration -= delta
			var dive_speed: float = move_speed * 2.6
			velocity = _dive_direction * dive_speed + _knockback_velocity
			move_and_slide()
			$AnimatedSprite2D.flip_h = _dive_direction.x < 0.0
			$AnimatedSprite2D.play(&"walk")
			_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			if _dive_duration <= 0.0:
				_is_diving = false
				_dive_cooldown = 3.5
			return
	
	var effective_speed: float = move_speed * (1.0 - clampf(_slow_factor, 0.0, 0.9))
	if is_ghost and _is_ethereal:
		effective_speed *= 1.45
	
	if _chasing and _player != null and is_instance_valid(_player):
		var to_player := _player.global_position - global_position
		var dir := to_player.normalized()
		var move_vel := dir * effective_speed
		if is_bat:
			var perp := Vector2(-dir.y, dir.x)
			move_vel += perp * (sin(_wave_time * 8.0) * 32.0)
		
		velocity = move_vel + _knockback_velocity
		move_and_slide()
		$AnimatedSprite2D.flip_h = to_player.x < 0.0
		$AnimatedSprite2D.play(&"walk")
	else:
		velocity = _knockback_velocity
		move_and_slide()
		$AnimatedSprite2D.play(&"idle")
	
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 600.0 * delta)


func apply_knockback(force: Vector2) -> void:
	if _dying:
		return
	_knockback_velocity += force


func apply_slow(factor: float, duration: float) -> void:
	if _dying:
		return
	_slow_factor = maxf(_slow_factor, factor)
	_slow_timer = maxf(_slow_timer, duration)


func apply_pull(target_pos: Vector2, pull_force: float, delta: float) -> void:
	if _dying:
		return
	var dir := (target_pos - global_position).normalized()
	_knockback_velocity += dir * (pull_force * delta * 60.0)


func take_damage(amount: float, ignore_cooldown: bool = false) -> void:
	if _dying:
		return
	if not ignore_cooldown and not _can_take_damage:
		return
	if not ignore_cooldown:
		_can_take_damage = false
		$take_damage_cooldown.start()
	health -= amount
	if health <= 0.0:
		die()


func deal_with_damage() -> void:
	if not global.player_current_attack:
		return
	var amount := DEFAULT_DAMAGE_TAKEN
	var in_reach := _player_in_attack_zone
	if _player != null and is_instance_valid(_player):
		if "stats" in _player:
			amount = _player.stats.get_stat(&"damage")
		# The swing reaches beyond body-contact range; the player decides
		# where its reach ends so melee can outrange the enemy's attack.
		if _player.has_method("is_within_attack_reach"):
			in_reach = _player.is_within_attack_reach(global_position)
	if in_reach:
		take_damage(amount)


func die() -> void:
	if _dying:
		return
	_dying = true
	_death_frame = Engine.get_physics_frames()
	velocity = Vector2.ZERO

	GameEvents.enemy_died.emit(self, exp_value)

	$CollisionShape2D.set_deferred("disabled", true)
	$enemy_hitbox/CollisionShape2D.set_deferred("disabled", true)
	$detection_area/CollisionShape2D.set_deferred("disabled", true)

	# Idempotent: a corpse recycled by the safety net mid-animation keeps
	# its pending one-shot connection, and a later death must not connect
	# it twice.
	if not $AnimatedSprite2D.animation_finished.is_connected(_on_death_animation_finished):
		$AnimatedSprite2D.animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)
	$AnimatedSprite2D.play(&"death")


func _on_death_animation_finished() -> void:
	# The safety net may have recycled this corpse while the animation was
	# frozen (paused); don't release twice.
	if not _dying:
		return
	if _pooled and _pool != null:
		_pool.release(self)
	else:
		$respawn_timer.start()


func update_health() -> void:
	var healthbar := $healthbar
	healthbar.value = health
	healthbar.visible = health < max_health


func _on_detection_area_body_entered(body: Node2D) -> void:
	if _pooled:
		return
	if body.is_in_group("player"):
		_player = body
		_chasing = true
	_knockback_velocity = Vector2.ZERO
	_slow_factor = 0.0
	_slow_timer = 0.0


func _on_detection_area_body_exited(body: Node2D) -> void:
	if _pooled:
		return
	if body == _player:
		_player = null
		_chasing = false


func _on_enemy_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_attack_zone = true


func _on_enemy_hitbox_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_attack_zone = false


func _on_take_damage_cooldown_timeout() -> void:
	if _dying:
		return
	_can_take_damage = true


func _on_respawn_timer_timeout() -> void:
	_respawn()


## Legacy unpooled respawn: stand back up at the original spot.
func _respawn() -> void:
	_dying = false
	_can_take_damage = true
	_player_in_attack_zone = false
	health = max_health
	$CollisionShape2D.set_deferred("disabled", false)
	$enemy_hitbox/CollisionShape2D.set_deferred("disabled", false)
	$detection_area/CollisionShape2D.set_deferred("disabled", false)
	$AnimatedSprite2D.play(&"idle")


## ObjectPool lifecycle: handed out for a new spawn (setup() follows).
func on_acquire() -> void:
	visible = true
	set_physics_process(true)
	# Parked bodies had every shape disabled; bring them all back.
	$CollisionShape2D.set_deferred("disabled", false)
	$enemy_hitbox/CollisionShape2D.set_deferred("disabled", false)
	$detection_area/CollisionShape2D.set_deferred("disabled", false)


## ObjectPool lifecycle: returned to the pool.
func on_release() -> void:
	visible = false
	set_physics_process(false)
	_dying = false
	_chasing = false
	_player_in_attack_zone = false
	_player = null
	_is_telegraphing = false
	_is_diving = false
	_is_ethereal = false
	$AnimatedSprite2D.position = Vector2.ZERO
	$AnimatedSprite2D.modulate = Color.WHITE
	$CollisionShape2D.set_deferred("disabled", true)
	$enemy_hitbox/CollisionShape2D.set_deferred("disabled", true)
	$detection_area/CollisionShape2D.set_deferred("disabled", true)
