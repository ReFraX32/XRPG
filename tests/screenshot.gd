extends Node

## Visual verification helper (dev only): boots the survival scene, simulates
## exploration and combat, and saves screenshots to tests/ for inspection.
## Run with a rendering context (NOT --headless):
##   godot res://tests/screenshot.tscn

var _survival: Node


func _ready() -> void:
	_survival = load("res://scenes/survival.tscn").instantiate()
	add_child(_survival)
	await RenderingServer.frame_post_draw
	await _shot("0_loading")
	# Force-show the mobile touch UI on desktop to verify its layout.
	var ui_player: Node2D = _survival.get_node("%player")
	ui_player.get_node("CanvasLayer/attack_button").visible = true
	ui_player.get_node("CanvasLayer/touch_controls").visible = true
	await get_tree().create_timer(1.0).timeout
	# Simulate a touch on the joystick area so the WHEN_TOUCHED joystick shows.
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(150, 550)
	Input.parse_input_event(touch)
	await get_tree().create_timer(0.3).timeout
	await _shot("1_spawn")

	# Simulate exploration: teleport far and let chunks stream in.
	var player: Node2D = _survival.get_node("%player")
	player.global_position += Vector2(700, 500)
	await get_tree().create_timer(1.0).timeout
	await _shot("2_explored")

	# Regression check: moving UP (negative Y) used to hide the player
	# behind the terrain layers.
	player.global_position = Vector2(150, -600)
	await get_tree().create_timer(1.0).timeout
	await _shot("2b_upward")

	# Simulate combat: wait for a live enemy, pull it close, let it attack.
	var spawner: Node = _survival.get_node("%EnemySpawner")
	for attempt in 12:
		if _alive_enemies(spawner) > 0:
			break
		await get_tree().create_timer(0.5).timeout
	var pulled := 0
	for pool in spawner._pools.values():
		for enemy in pool.get_children():
			if enemy.visible and not enemy._dying and pulled < 6:
				enemy.global_position = player.global_position + Vector2(60 + pulled * 18, -30 + (pulled % 3) * 22)
				pulled += 1
	await get_tree().create_timer(1.5).timeout
	Input.action_press("attack")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("attack")
	await get_tree().create_timer(0.5).timeout
	await _shot("3_combat")

	# Force a level-up burst to capture the choice overlay.
	var director: RunDirector = _survival as RunDirector
	director._on_exp_collected(500)
	await get_tree().process_frame
	await _shot("4_levelup")
	var level_up_ui: CanvasLayer = _survival.get_node("%LevelUpUI")
	if level_up_ui.is_open:
		level_up_ui._on_option_pressed(0)
	get_tree().paused = false
	get_tree().quit(0)


func _alive_enemies(spawner: Node) -> int:
	var count := 0
	for pool in spawner._pools.values():
		for enemy in pool.get_children():
			if enemy.visible and not enemy._dying:
				count += 1
	return count


func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tests/shot_%s.png" % name_)
	print("saved shot_", name_)
