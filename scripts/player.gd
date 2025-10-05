extends CharacterBody2D

var enemy_in_attack_range = false
var enemy_attack_cooldown = true
var health = 100
var player_alive = true

var attack_in_progress = false

const speed = 100
var current_dir = "down"

func _ready():
	
	if not is_in_group("player"):
		add_to_group("player")
	
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		$CanvasLayer/attack_button.visible = false
		$CanvasLayer/attack_button.set_process(false)
		$CanvasLayer/attack_button.set_process_input(false)
		$Control/touch_controls.visible = false
		$Control/touch_controls.set_process(false)
		$Control/touch_controls.set_process_input(false)
	$AnimatedSprite2D.play("front_idle")
	init_camera()


func init_camera():
	var tilemap_rect = get_parent().get_node("ground").get_used_rect()
	var tilemap_cell_size = get_parent().get_node("ground").tile_set.tile_size
	$Camera2D.limit_left = tilemap_rect.position.x * tilemap_cell_size.x
	$Camera2D.limit_right = tilemap_rect.end.x * tilemap_cell_size.x
	$Camera2D.limit_bottom = tilemap_rect.end.y * tilemap_cell_size.y
	$Camera2D.limit_top = tilemap_rect.position.y * tilemap_cell_size.y

func _physics_process(delta):
	player_movement(delta)
	enemy_attack()
	attack()
	update_health()
	
	if health <= 0:
		player_alive = false
		health = 0
		get_tree().reload_current_scene()

func player_movement(_delta):
	var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_vector * speed

	# Direction for animations
	if input_vector.length() > 0:
		if abs(input_vector.x) > abs(input_vector.y):
			current_dir = "right" if input_vector.x > 0 else "left"
		else:
			current_dir = "down" if input_vector.y > 0 else "up"
		play_anim(1)
	else:
		play_anim(0)

	move_and_slide()


func play_anim(movement):
	var dir = current_dir
	var anim = $AnimatedSprite2D
	
	if dir == "right":
		anim.flip_h = false
		if movement == 1:
			anim.play("side_walk")
		elif movement == 0:
			if not attack_in_progress:
				anim.play("side_idle")
	elif dir == "left":
		anim.flip_h = true
		if movement == 1:
			anim.play("side_walk")
		elif movement == 0:
			if not attack_in_progress:
				anim.play("side_idle")
	elif dir == "down":
		anim.flip_h = false
		if movement == 1:
			anim.play("front_walk")
		elif movement == 0:
			if not attack_in_progress:
				anim.play("front_idle")
	elif dir == "up":
		anim.flip_h = false
		if movement == 1:
			anim.play("back_walk")
		elif movement == 0:
			if not attack_in_progress:
				anim.play("back_idle")


func player():
	pass

func _on_player_hitbox_body_entered(body):
	if body.is_in_group("enemy"):
		enemy_in_attack_range = true


func _on_player_hitbox_body_exited(body):
	if body.is_in_group("enemy"):
		enemy_in_attack_range = false

func enemy_attack():
	if enemy_in_attack_range and enemy_attack_cooldown:
		health -= 10
		enemy_attack_cooldown = false
		$attack_cooldown.start()


func _on_attack_cooldown_timeout():
	enemy_attack_cooldown = true

func attack():
	var dir = current_dir
	
	if Input.is_action_just_pressed("attack"):
		global.player_current_attack = true
		attack_in_progress = true
		if dir == "right":
			$AnimatedSprite2D.flip_h = false
			$AnimatedSprite2D.play("side_attack")
			$deal_attack_cooldown.start()
		if dir == "left":
			$AnimatedSprite2D.flip_h = true
			$AnimatedSprite2D.play("side_attack")
			$deal_attack_cooldown.start()
		if dir == "down":
			$AnimatedSprite2D.play("front_attack")
			$deal_attack_cooldown.start()
		if dir == "up":
			$AnimatedSprite2D.play("back_attack")
			$deal_attack_cooldown.start()


func _on_deal_attack_cooldown_timeout():
	$deal_attack_cooldown.stop()
	global.player_current_attack = false
	attack_in_progress = false

func update_health():
	var healthbar = $healthbar
	healthbar.value = health
	if health >= 100:
		healthbar.visible = false
	else:
		healthbar.visible = true

func _on_regin_time_timeout():
	if health < 100:
		health += 20
	elif health > 100:
		health = 100
	if health <= 0:
		health = 0

func _on_attack_button_pressed():
	Input.action_press("attack")
	await get_tree().process_frame
	Input.action_release("attack")
