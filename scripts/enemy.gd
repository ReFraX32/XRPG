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


func _ready() -> void:
	if not is_in_group("enemy"):
		add_to_group("enemy")
	# The death animation is authored as looping; make it one-shot so the
	# recycle callback can wait for it.
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

	max_health = maxf(1.0, p_definition.max_health * health_scale)
	health = max_health
	move_speed = p_definition.move_speed * speed_scale
	contact_damage = p_definition.contact_damage
	exp_value = maxi(1, roundi(p_definition.exp_value * exp_scale))

	scale = Vector2.ONE * p_definition.scale
	$AnimatedSprite2D.modulate = p_definition.tint
	$healthbar.max_value = max_health
	# Horde enemies always know where the player is; detection stays unused.
	$detection_area.monitoring = false
	$AnimatedSprite2D.play(&"walk")


func _physics_process(_delta: float) -> void:
	if _dying:
		return
	deal_with_damage()
	update_health()
	if _chasing and _player != null and is_instance_valid(_player):
		var to_player := _player.global_position - global_position
		velocity = to_player.normalized() * move_speed
		move_and_slide()
		$AnimatedSprite2D.flip_h = to_player.x < 0.0
		$AnimatedSprite2D.play(&"walk")
	else:
		velocity = Vector2.ZERO
		$AnimatedSprite2D.play(&"idle")


func take_damage(amount: float) -> void:
	if _dying or not _can_take_damage:
		return
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
	$CollisionShape2D.set_deferred("disabled", true)
	$enemy_hitbox/CollisionShape2D.set_deferred("disabled", true)
	$detection_area/CollisionShape2D.set_deferred("disabled", true)
