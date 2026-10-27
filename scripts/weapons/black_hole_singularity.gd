class_name BlackHoleSingularity
extends Node2D

## Singular event horizon that draws enemies toward center, absorbs power, and collapses in a burst.

signal collapsed(pos: Vector2, absorbed_count: int)

const VORTEX_TEX := preload("res://art/weapons/black_hole_icon.png")

var duration: float = 2.8
var pull_radius: float = 90.0
var pull_force: float = 75.0
var burst_damage: float = 40.0
var tier: WeaponRarity.Tier = WeaponRarity.Tier.COMMON
var is_mini: bool = false

var _elapsed: float = 0.0
var _rotation_angle: float = 0.0
var _absorbed_power: int = 0
var _exploding: bool = false
var _explosion_radius: float = 0.0


func setup(pos: Vector2, p_tier: WeaponRarity.Tier, p_damage: float, p_radius: float, p_duration: float, p_is_mini: bool = false) -> void:
	global_position = pos
	tier = p_tier
	burst_damage = p_damage
	pull_radius = p_radius
	duration = p_duration
	is_mini = p_is_mini
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_rotation_angle = wrapf(_rotation_angle + delta * 6.0, 0.0, TAU)

	if not _exploding:
		_process_gravitational_pull(delta)
		if _elapsed >= duration:
			_collapse()
	else:
		_explosion_radius += delta * 350.0
		modulate.a -= delta * 2.5
		if modulate.a <= 0.0:
			queue_free()

	queue_redraw()


func _process_gravitational_pull(delta: float) -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	for node in enemies:
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= pull_radius:
			# Pull enemy toward singularity center
			if enemy.has_method("apply_pull"):
				enemy.apply_pull(global_position, pull_force, delta)
			# Minor continuous damage at center
			if dist <= 20.0 and enemy.has_method("take_damage"):
				enemy.take_damage(burst_damage * 0.05 * delta, true)
			# Mythic: Absorbs energy from caught enemies/entities
			if tier == WeaponRarity.Tier.MYTHIC and dist <= 35.0:
				_absorbed_power += 1

	# Mythic: Absorbs enemy projectiles if any are in the scene
	if tier == WeaponRarity.Tier.MYTHIC:
		for proj in get_tree().get_nodes_in_group("enemy_projectile"):
			var p := proj as Node2D
			if p != null and is_instance_valid(p) and global_position.distance_to(p.global_position) <= pull_radius:
				_absorbed_power += 5
				p.queue_free()


func _collapse() -> void:
	_exploding = true
	_explosion_radius = 10.0

	# Calculate final damage with absorbed power multiplier
	var final_dmg := burst_damage
	if tier == WeaponRarity.Tier.MYTHIC:
		final_dmg *= (1.0 + minf(_absorbed_power * 0.08, 3.5))

	var blast_radius := pull_radius * 1.2
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= blast_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(final_dmg, true)
			if enemy.has_method("apply_knockback"):
				var push := (enemy.global_position - global_position).normalized() * 320.0
				enemy.apply_knockback(push)

	collapsed.emit(global_position, _absorbed_power)


func _draw() -> void:
	var col := WeaponRarity.get_color(tier)
	var t := _elapsed / maxf(0.1, duration)

	if not _exploding:
		# 1. Gravitational Inflow Ripple Waves
		for r_step in 3:
			var ripple_t := fmod(t * 2.0 + (r_step / 3.0), 1.0)
			var cur_r := pull_radius * (1.0 - ripple_t)
			var ripple_a := ripple_t * 0.35
			draw_arc(Vector2.ZERO, cur_r, 0, TAU, 32, Color(col.r, col.g, col.b, ripple_a), 1.5)

		# 2. Spiral Accretion Disk Arms (3 arms)
		var arm_count := 3
		for i in arm_count:
			var base_angle := _rotation_angle + (TAU / float(arm_count)) * i
			var pts := PackedVector2Array()
			for step in 8:
				var s_frac := float(step) / 7.0
				var r := lerpf(16.0, pull_radius * 0.75, s_frac)
				var a := base_angle + s_frac * 2.2
				pts.append(Vector2(cos(a), sin(a)) * r)
			var arm_col := Color(col.r, col.g, col.b, 0.45)
			draw_polyline(pts, arm_col, 2.0)

		# 3. Rotating Cosmic Vortex Sprite & Event Horizon
		var horizon_radius := 14.0 if not is_mini else 8.0
		if VORTEX_TEX != null:
			var v_size := Vector2.ONE * (44.0 if not is_mini else 26.0)
			draw_set_transform(Vector2.ZERO, _rotation_angle, Vector2.ONE)
			draw_texture_rect(VORTEX_TEX, Rect2(-v_size * 0.5, v_size), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var photon_col := Color.WHITE.lerp(col, 0.35)
			draw_arc(Vector2.ZERO, horizon_radius + 2.5, 0, TAU, 32, photon_col, 2.5)
			draw_circle(Vector2.ZERO, horizon_radius, Color(0.02, 0.01, 0.04, 1.0))

		# 5. Mythic Absorbed Energy Corona
		if tier == WeaponRarity.Tier.MYTHIC and _absorbed_power > 0:
			var corona_pulse := sin(_rotation_angle * 4.0) * 3.0
			draw_arc(Vector2.ZERO, horizon_radius + 4.0 + corona_pulse, 0, TAU, 24, Color(1.0, 0.2, 0.5, 0.8), 2.0)
	else:
		# Supernova collapse wave with multi-layer colored rings
		var alpha := clampf(modulate.a, 0.0, 1.0)
		var flash_col := Color(col.r, col.g, col.b, alpha)
		draw_circle(Vector2.ZERO, _explosion_radius, Color(0.08, 0.02, 0.12, alpha * 0.45))
		draw_arc(Vector2.ZERO, _explosion_radius, 0, TAU, 48, flash_col, 4.5)
		draw_arc(Vector2.ZERO, maxf(0.0, _explosion_radius - 8.0), 0, TAU, 32, Color(1.0, 1.0, 1.0, alpha * 0.75), 2.0)
