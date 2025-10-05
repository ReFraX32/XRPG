extends CharacterBody2D

var speed = 40
var player_chase = false
var player = null

var health = 100
var player_in_attack_zone = false
var can_take_damage = true

var spawn_position
var respawn_time = 2.0

func _ready():
	spawn_position = global_position

	if not is_in_group("enemy"):
		add_to_group("enemy")

func _physics_process(_delta):
	deal_with_damage()
	update_health()

	if player_chase and player:
		position += (player.position - position) / speed
		$AnimatedSprite2D.play("walk")
		$AnimatedSprite2D.flip_h = (player.position.x - position.x) < 0
	else:
		$AnimatedSprite2D.play("idle")

func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player = body
		player_chase = true

func _on_detection_area_body_exited(body):
	if body == player:
		player = null
		player_chase = false

func _on_enemy_hitbox_body_entered(body):
	if body.is_in_group("player"):
		player_in_attack_zone = true

func _on_enemy_hitbox_body_exited(body):
	if body.is_in_group("player"):
		player_in_attack_zone = false

func deal_with_damage():
	if player_in_attack_zone and global.player_current_attack:
		if can_take_damage:
			$take_damage_cooldown.start()
			can_take_damage = false
			health -= 20
			if health <= 0:
				die()

func _on_take_damage_cooldown_timeout():
	can_take_damage = true

func update_health():
	var healthbar = $healthbar
	healthbar.value = health
	healthbar.visible = health < 100

func die():
	visible = false
	set_process(false)
	set_physics_process(false)

	player = null
	player_chase = false
	player_in_attack_zone = false

	$CollisionShape2D.disabled = true
	$detection_area/CollisionShape2D.disabled = true
	$enemy_hitbox/CollisionShape2D.disabled = true

	await get_tree().create_timer(respawn_time).timeout
	respawn()

func respawn():
	global_position = spawn_position
	health = 100
	can_take_damage = true
	visible = true

	await get_tree().process_frame

	$CollisionShape2D.disabled = false
	$detection_area/CollisionShape2D.disabled = false
	$enemy_hitbox/CollisionShape2D.disabled = false

	set_process(true)
	set_physics_process(true)
