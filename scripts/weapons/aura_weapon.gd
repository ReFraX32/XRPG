class_name AuraWeapon
extends Weapon

## Aura Weapon: Circular DoT field around the player.
## Scales with slow (Epic), expanding shockwave (Legendary), and corpse explosion (Mythic).

var _tick_timer: float = 0.0
var _shockwave_timer: float = 5.0
var _visual_pulse: float = 0.0
var _shockwave_radius: float = 0.0
var _shockwave_anim: bool = false

@onready var _enemies_in_aura: Array[Node2D] = []


func _ready() -> void:
	z_index = -1 # Render underneath characters


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	global_position = player.global_position
	var current_radius := get_range_radius()

	# Pulse animation for visuals
	_visual_pulse = wrapf(_visual_pulse + delta * 2.5, 0.0, TAU)
	queue_redraw()

	# Find enemies in range
	_enemies_in_aura.clear()
	var enemies := get_tree().get_nodes_in_group("enemy")
	for node in enemies:
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if "health" in enemy and enemy.health <= 0:
			continue
		if global_position.distance_to(enemy.global_position) <= current_radius:
			_enemies_in_aura.append(enemy)

	# DoT Ticks (cadence 0.25s)
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = 0.25
		_apply_aura_tick()

	# Legendary Shockwave every 5 seconds
	if rarity_tier == WeaponRarity.Tier.LEGENDARY or rarity_tier == WeaponRarity.Tier.MYTHIC:
		_shockwave_timer -= delta
		if _shockwave_timer <= 0.0:
			_shockwave_timer = 5.0
			_trigger_shockwave()

	# Shockwave visual animation update
	if _shockwave_anim:
		_shockwave_radius += delta * (current_radius * 2.5)
		if _shockwave_radius > current_radius * 1.5:
			_shockwave_anim = false


func _apply_aura_tick() -> void:
	if _enemies_in_aura.is_empty():
		return

	var dmg_data := roll_damage_with_crit()
	var dmg: float = dmg_data["damage"] * 0.25 # DoT fraction per tick

	for enemy in _enemies_in_aura:
		if enemy == null or not is_instance_valid(enemy):
			continue

		# Epic+: Apply 20% slow
		if rarity_tier != WeaponRarity.Tier.COMMON:
			if enemy.has_method("apply_slow"):
				enemy.apply_slow(0.20, 0.4)

		if enemy.has_method("take_damage"):
			enemy.take_damage(dmg, true)


func _trigger_shockwave() -> void:
	_shockwave_anim = true
	_shockwave_radius = 0.0
	var radius := get_range_radius() * 1.3
	var shock_dmg := get_damage() * 1.8

	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= radius:
			var dir := (enemy.global_position - global_position).normalized()
			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback(dir * 280.0)
			if enemy.has_method("take_damage"):
				enemy.take_damage(shock_dmg, true)


## Mythic: Enemies eliminated within the aura explode dealing area damage
func on_enemy_killed(enemy: Node2D, _exp_val: int) -> void:
	if rarity_tier != WeaponRarity.Tier.MYTHIC:
		return
	if enemy == null or not is_instance_valid(enemy):
		return

	var current_radius := get_range_radius()
	if global_position.distance_to(enemy.global_position) <= current_radius + 20.0:
		_create_corpse_explosion(enemy.global_position)


func _create_corpse_explosion(pos: Vector2) -> void:
	var blast_radius := 60.0
	var blast_dmg := get_damage() * 2.5

	for node in get_tree().get_nodes_in_group("enemy"):
		var e := node as Node2D
		if e == null or not is_instance_valid(e):
			continue
		if pos.distance_to(e.global_position) <= blast_radius:
			if e.has_method("take_damage"):
				e.take_damage(blast_dmg, true)
			if e.has_method("apply_knockback"):
				var push := (e.global_position - pos).normalized() * 200.0
				e.apply_knockback(push)


func _draw() -> void:
	var rarity_col := WeaponRarity.get_color(rarity_tier)
	var col := Color(0.15, 0.72, 1.0, 1.0).lerp(rarity_col, 0.45)
	var base_r := get_range_radius()
	var pulse_r := base_r + sin(_visual_pulse) * 2.5

	# 1. Electric blue dome with multi-layered glow
	draw_circle(Vector2.ZERO, pulse_r, Color(0.05, 0.55, 0.98, 0.12))
	draw_circle(Vector2.ZERO, pulse_r * 0.72, Color(col.r, col.g, col.b, 0.14))
	draw_circle(Vector2.ZERO, pulse_r * 0.38, Color(0.75, 0.95, 1.0, 0.22))

	# 2. Inner counter-rotating energy ring
	var inner_r := pulse_r * 0.65
	draw_arc(Vector2.ZERO, inner_r, -_visual_pulse, -_visual_pulse + TAU, 32, Color(col.r, col.g, col.b, 0.4), 1.5)

	# 3. Crisp dark rim + luminous outer ring (matching pixel-art sphere style)
	draw_arc(Vector2.ZERO, pulse_r + 1.5, 0, TAU, 48, Color(0.02, 0.12, 0.28, 0.75), 2.5)
	draw_arc(Vector2.ZERO, pulse_r, 0, TAU, 48, Color(col.r, col.g, col.b, 0.85), 2.0)

	# 4. Radiating energy rays & sparks around the sphere circumference
	var ray_count := 12
	for i in ray_count:
		var angle := _visual_pulse * 0.4 + (TAU / float(ray_count)) * i
		var dir := Vector2(cos(angle), sin(angle))
		var ray_len := 5.0 + sin(_visual_pulse * 2.0 + i * 1.3) * 3.0
		var start_p := dir * (pulse_r + 2.0)
		var end_p := dir * (pulse_r + 2.0 + ray_len)
		draw_line(start_p, end_p, Color(0.4, 0.88, 1.0, 0.8), 1.8)
		draw_circle(end_p, 1.5, Color.WHITE)

	# 5. Shockwave ring (Legendary+)
	if _shockwave_anim:
		var progress := _shockwave_radius / (base_r * 1.5)
		var sw_alpha := clampf(1.0 - progress, 0.0, 1.0)
		var sw_col := Color(col.r, col.g, col.b, sw_alpha)
		draw_arc(Vector2.ZERO, _shockwave_radius, 0, TAU, 48, sw_col, 3.5)
		draw_arc(Vector2.ZERO, maxf(0.0, _shockwave_radius - 4.0), 0, TAU, 32, Color(1.0, 1.0, 1.0, sw_alpha * 0.7), 1.5)
