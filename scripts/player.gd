extends CharacterBody2D

## The player. Movement/attack behavior is unchanged from the original
## project; stats now come from the PlayerStats child (data-driven upgrades
## mutate it), enemy contact damage comes from the touching enemy's
## definition, and death is announced on the GameEvents bus instead of
## reloading the scene directly (each game mode decides what death means).
##
## Attacking: one shared _start_attack() drives both the manual attack
## (E / touch button) and the automatic swing whenever an enemy is inside
## the reach. Attack animations are one-shot and own the attack state, so
## the player can keep moving while swinging without the walk animation
## cutting the swing short.

const ATTACK_ANIMS: Array[StringName] = [&"front_attack", &"back_attack", &"side_attack"]

var enemy_in_attack_range = false
var enemy_in_danger_range = false
var enemy_attack_cooldown = true
var health = 100
var player_alive = true

var attack_in_progress = false

var current_dir = "down"

var _touching_enemy: Node2D = null
# How many enemies currently overlap the reach; a single bool would clear
# whenever ANY of them exits, stuttering auto-attack and contact damage in
# a horde.
var _enemies_in_reach := 0
# Enemies close enough to hurt the player (danger zone, smaller than the
# swing reach so a well-timed swing lands before the enemy closes in).
var _enemies_in_danger := 0
var _base_attack_wait := 0.5
var _base_deal_attack_wait := 0.5

var is_invulnerable := false
var invulnerability_timer := 0.0
var temp_speed_multiplier := 1.0
var speed_boost_timer := 0.0

@onready var stats: PlayerStats = $PlayerStats
var weapon_manager: WeaponManager = null


func _ready():

	if not is_in_group("player"):
		add_to_group("player")

	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		$CanvasLayer/attack_button.visible = false
		$CanvasLayer/attack_button.set_process(false)
		$CanvasLayer/attack_button.set_process_input(false)
		$CanvasLayer/touch_controls.visible = false
		$CanvasLayer/touch_controls.set_process(false)
		$CanvasLayer/touch_controls.set_process_input(false)
	$AnimatedSprite2D.play("front_idle")
	init_camera()

	_base_attack_wait = $attack_cooldown.wait_time
	_base_deal_attack_wait = $deal_attack_cooldown.wait_time
	health = stats.get_stat(&"max_health")
	stats.stats_recalculated.connect(_on_stats_recalculated)
	$collect_area.area_entered.connect(_on_collect_area_area_entered)
	for anim in ATTACK_ANIMS:
		# Attack animations are authored looping; make them one-shot so the
		# swing finishes cleanly and hands control back to walk/idle.
		$AnimatedSprite2D.sprite_frames.set_animation_loop(anim, false)
	$AnimatedSprite2D.animation_finished.connect(_on_attack_animation_finished)
	$danger_area.body_entered.connect(_on_danger_area_body_entered)
	$danger_area.body_exited.connect(_on_danger_area_body_exited)

	weapon_manager = get_node_or_null("WeaponManager")
	if weapon_manager == null:
		weapon_manager = WeaponManager.new()
		weapon_manager.name = "WeaponManager"
		add_child(weapon_manager)


func init_camera():
	# The survival map is infinite and has no "ground" sibling; only clamp
	# the camera in legacy hand-made scenes.
	var ground = get_parent().get_node_or_null("ground")
	if ground == null:
		return
	var tilemap_rect = ground.get_used_rect()
	var tilemap_cell_size = ground.tile_set.tile_size
	$Camera2D.limit_left = tilemap_rect.position.x * tilemap_cell_size.x
	$Camera2D.limit_right = tilemap_rect.end.x * tilemap_cell_size.x
	$Camera2D.limit_bottom = tilemap_rect.end.y * tilemap_cell_size.y
	$Camera2D.limit_top = tilemap_rect.position.y * tilemap_cell_size.y

func _physics_process(delta):
	if not player_alive:
		return

	if invulnerability_timer > 0.0:
		invulnerability_timer -= delta
		if invulnerability_timer <= 0.0:
			is_invulnerable = false
			modulate = Color.WHITE

	if speed_boost_timer > 0.0:
		speed_boost_timer -= delta
		if speed_boost_timer <= 0.0:
			temp_speed_multiplier = 1.0

	player_movement(delta)
	enemy_attack()
	_update_attacks()
	update_health()

	if health <= 0:
		die()

func player_movement(_delta):
	var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_vector * (stats.get_stat(&"move_speed") * temp_speed_multiplier)

	# Direction for animations
	if input_vector.length() > 0:
		current_dir = _direction_to(input_vector)
		play_anim(1)
	else:
		play_anim(0)

	move_and_slide()


func play_anim(movement):
	# The attack animation owns the sprite until it finishes; movement still
	# applies (velocity above), only the animation is held.
	if attack_in_progress:
		return
	var dir = current_dir
	var anim = $AnimatedSprite2D

	if dir == "right":
		anim.flip_h = false
		if movement == 1:
			anim.play("side_walk")
		elif movement == 0:
			anim.play("side_idle")
	elif dir == "left":
		anim.flip_h = true
		if movement == 1:
			anim.play("side_walk")
		elif movement == 0:
			anim.play("side_idle")
	elif dir == "down":
		anim.flip_h = false
		if movement == 1:
			anim.play("front_walk")
		elif movement == 0:
			anim.play("front_idle")
	elif dir == "up":
		anim.flip_h = false
		if movement == 1:
			anim.play("back_walk")
		elif movement == 0:
			anim.play("back_idle")


## Runs every physics frame: manual input always wins, otherwise swing on
## our own whenever an enemy stands inside the reach.
func _update_attacks():
	if Input.is_action_just_pressed("attack"):
		_start_attack(current_dir)
	elif enemy_in_attack_range and not attack_in_progress:
		_start_attack(_auto_attack_direction())


## Single entry point for both manual and automatic swings.
func _start_attack(dir):
	if attack_in_progress:
		return
	attack_in_progress = true
	current_dir = dir
	global.player_current_attack = true
	if dir == "left":
		$AnimatedSprite2D.flip_h = true
		$AnimatedSprite2D.play(&"side_attack")
	elif dir == "right":
		$AnimatedSprite2D.flip_h = false
		$AnimatedSprite2D.play(&"side_attack")
	elif dir == "up":
		$AnimatedSprite2D.play(&"back_attack")
	else:
		$AnimatedSprite2D.play(&"front_attack")
	$deal_attack_cooldown.start()


## Swing toward the closest enemy inside the player's reach.
func _auto_attack_direction():
	var nearest_distance := INF
	var nearest_direction: String = current_dir
	for body in $player_hitbox.get_overlapping_bodies():
		if not body.is_in_group("enemy"):
			continue
		var distance := global_position.distance_squared_to(body.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_direction = _direction_to(body.global_position - global_position)
	return nearest_direction


func _direction_to(offset: Vector2) -> String:
	if absf(offset.x) > absf(offset.y):
		return "right" if offset.x > 0.0 else "left"
	return "down" if offset.y > 0.0 else "up"


## The swing animation finished: hand the sprite back to walk/idle. The
## damage window itself closes via deal_attack_cooldown.
func _on_attack_animation_finished():
	if not attack_in_progress:
		return
	attack_in_progress = false
	if player_alive:
		play_anim(0)


func player():
	pass

func _on_player_hitbox_body_entered(body):
	if body.is_in_group("enemy"):
		_enemies_in_reach += 1
		enemy_in_attack_range = true
		_touching_enemy = body


func _on_player_hitbox_body_exited(body):
	if body.is_in_group("enemy"):
		_enemies_in_reach = maxi(0, _enemies_in_reach - 1)
		enemy_in_attack_range = _enemies_in_reach > 0
		if body == _touching_enemy:
			_touching_enemy = null


func _on_danger_area_body_entered(body):
	if body.is_in_group("enemy"):
		_enemies_in_danger += 1
		enemy_in_danger_range = true


func _on_danger_area_body_exited(body):
	if body.is_in_group("enemy"):
		_enemies_in_danger = maxi(0, _enemies_in_danger - 1)
		enemy_in_danger_range = _enemies_in_danger > 0

func enemy_attack():
	# Contact damage only inside the small danger zone, NOT the full swing
	# reach: kiting keeps you safe while your swings still connect.
	if enemy_in_danger_range and enemy_attack_cooldown:
		if is_invulnerable:
			return
		var dmg := _contact_damage()
		# Aegis / Defensive weapon interception
		if weapon_manager != null and weapon_manager.try_intercept_damage(dmg, _touching_enemy):
			enemy_attack_cooldown = false
			$attack_cooldown.start()
			return
		health -= dmg
		enemy_attack_cooldown = false
		$attack_cooldown.start()


func grant_invulnerability(duration: float) -> void:
	is_invulnerable = true
	invulnerability_timer = maxf(invulnerability_timer, duration)
	modulate = Color(1.8, 1.8, 0.4, 1.0)


func grant_speed_boost(multiplier: float, duration: float) -> void:
	temp_speed_multiplier = maxf(temp_speed_multiplier, multiplier)
	speed_boost_timer = maxf(speed_boost_timer, duration)


func heal(amount: float) -> void:
	var max_hp = stats.get_stat(&"max_health")
	health = minf(health + amount, max_hp)
	update_health()


## Whether a world position is inside the melee swing reach. Enemies call
## this to know whether an active swing connects with them.
func is_within_attack_reach(point: Vector2) -> bool:
	var shape: CollisionShape2D = $player_hitbox/CollisionShape2D
	return shape.global_position.distance_to(point) <= shape.shape.radius


## Contact damage is defined per enemy type; fall back to the old flat 10
## for enemies without a definition (legacy scene).
func _contact_damage() -> float:
	if _touching_enemy != null and is_instance_valid(_touching_enemy) and "contact_damage" in _touching_enemy:
		return _touching_enemy.contact_damage
	return 10.0

func _on_attack_cooldown_timeout():
	enemy_attack_cooldown = true

func _on_deal_attack_cooldown_timeout():
	$deal_attack_cooldown.stop()
	# Only the damage window closes here; attack_in_progress is owned by
	# the swing animation and clears when it finishes.
	global.player_current_attack = false

func update_health():
	var healthbar = $healthbar
	healthbar.max_value = stats.get_stat(&"max_health")
	healthbar.value = health
	if health < stats.get_stat(&"max_health"):
		healthbar.visible = true
	else:
		healthbar.visible = false

func _on_regin_time_timeout():
	if not player_alive:
		return
	var max_health = stats.get_stat(&"max_health")
	if health < max_health:
		health = minf(health + stats.get_stat(&"health_regen"), max_health)

func _on_attack_button_pressed():
	Input.action_press("attack")
	await get_tree().process_frame
	Input.action_release("attack")


## Death is announced; the active game mode (run director / legacy world)
## decides what happens next.
func die():
	player_alive = false
	health = 0
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	$AnimatedSprite2D.play("death")
	GameEvents.player_died.emit()


## EXP gems fly to the player once they enter the collection radius.
func _on_collect_area_area_entered(area: Area2D) -> void:
	if area.has_method("start_magnet"):
		area.start_magnet(self)


## Keeps timers and the pickup area in sync with stat changes from upgrades.
func _on_stats_recalculated():
	var attack_speed := maxf(stats.get_stat(&"attack_speed"), 0.01)
	$attack_cooldown.wait_time = _base_attack_wait / attack_speed
	$deal_attack_cooldown.wait_time = _base_deal_attack_wait / attack_speed
	# Swing animations speed up with the attack_speed stat, so the auto and
	# manual attack cadence scales with it too.
	$AnimatedSprite2D.speed_scale = clampf(attack_speed, 0.5, 3.0)
	$collect_area/CollisionShape2D.shape.radius = stats.get_stat(&"pickup_radius")
