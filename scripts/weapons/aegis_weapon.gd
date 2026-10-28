class_name AegisWeapon
extends Weapon

## Aegis Weapon: Orbiting defensive shields that absorb impacts and retaliate with thorns.
## Scales with 3 charges + knockback (Epic), healing on break/recharge (Legendary),
## and infinite shields while moving + massive retaliation explosion (Mythic).

const SHIELD_TEX := preload("res://art/weapons/aegis_icon.png")

var current_charges: int = 2
var max_charges: int = 2
var recharge_time: float = 7.0
var _recharge_timer: float = 0.0
var _orbit_angle: float = 0.0
var _orbit_radius: float = 30.0

# Visual explosion trigger
var _blast_anim_radius: float = 0.0
var _blast_anim_active: bool = false


func _ready() -> void:
	z_index = 1 # Draw above player
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _on_rarity_changed() -> void:
	match rarity_tier:
		WeaponRarity.Tier.COMMON:
			max_charges = 2
			recharge_time = 7.5
		WeaponRarity.Tier.EPIC:
			max_charges = 3
			recharge_time = 5.5
		WeaponRarity.Tier.LEGENDARY:
			max_charges = 3
			recharge_time = 4.5
		WeaponRarity.Tier.MYTHIC:
			max_charges = 4
			recharge_time = 3.0
	current_charges = max_charges


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	global_position = player.global_position
	_orbit_angle = wrapf(_orbit_angle + delta * 2.5, 0.0, TAU)

	# Recharge logic when charges are depleted
	if current_charges < max_charges:
		_recharge_timer += delta
		if _recharge_timer >= recharge_time:
			_recharge_timer = 0.0
			current_charges += 1
			if current_charges == max_charges:
				_on_fully_recharged()

	if _blast_anim_active:
		_blast_anim_radius += delta * 300.0
		if _blast_anim_radius > 120.0:
			_blast_anim_active = false

	queue_redraw()


func try_intercept_damage(_damage: float, touching_enemy: Node2D) -> bool:
	if player == null or not is_instance_valid(player):
		return false

	var is_moving := player.velocity.length_squared() > 25.0

	# Mythic: Infinite shields while moving
	if rarity_tier == WeaponRarity.Tier.MYTHIC and is_moving:
		_trigger_mythic_counter_explosion()
		return true

	# Standard / Epic / Legendary: Absorb if we have charges
	if current_charges > 0:
		current_charges -= 1
		_recharge_timer = 0.0
		_trigger_thorns_retaliation(touching_enemy)

		# Legendary: Regenerate health on shield break
		if rarity_tier == WeaponRarity.Tier.LEGENDARY or rarity_tier == WeaponRarity.Tier.MYTHIC:
			if player.has_method("heal") and stats != null:
				var heal_amount: float = stats.get_stat(&"max_health") * 0.06
				player.heal(heal_amount)

		return true

	return false


func _trigger_thorns_retaliation(target_enemy: Node2D) -> void:
	var thorns_dmg := get_damage() * 1.5
	var blast_range := 65.0

	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= blast_range:
			if enemy.has_method("take_damage"):
				enemy.take_damage(thorns_dmg, true)
			# Epic+: Knockback enemies back
			if rarity_tier != WeaponRarity.Tier.COMMON:
				if enemy.has_method("apply_knockback"):
					var dir := (enemy.global_position - global_position).normalized()
					enemy.apply_knockback(dir * 250.0)

	if target_enemy != null and is_instance_valid(target_enemy):
		if target_enemy.has_method("take_damage"):
			target_enemy.take_damage(thorns_dmg, true)


func _trigger_mythic_counter_explosion() -> void:
	_blast_anim_active = true
	_blast_anim_radius = 0.0
	var blast_range := 125.0
	var blast_dmg := get_damage() * 3.8

	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= blast_range:
			if enemy.has_method("take_damage"):
				enemy.take_damage(blast_dmg, true)
			if enemy.has_method("apply_knockback"):
				var dir := (enemy.global_position - global_position).normalized()
				enemy.apply_knockback(dir * 380.0)


func _on_fully_recharged() -> void:
	# Legendary: Heal player on full recharge
	if rarity_tier == WeaponRarity.Tier.LEGENDARY or rarity_tier == WeaponRarity.Tier.MYTHIC:
		if player != null and player.has_method("heal") and stats != null:
			var heal_amount: float = stats.get_stat(&"max_health") * 0.08
			player.heal(heal_amount)


func _draw() -> void:
	var col := WeaponRarity.get_color(rarity_tier)
	var active_orbs := current_charges

	# In Mythic while moving, indicate infinite shields and kinetic barrier
	if rarity_tier == WeaponRarity.Tier.MYTHIC and player != null and player.velocity.length_squared() > 25.0:
		active_orbs = max_charges
		# Glowing kinetic storm ring
		draw_arc(Vector2.ZERO, _orbit_radius, 0, TAU, 48, Color(col.r, col.g, col.b, 0.5), 2.5)
		draw_arc(Vector2.ZERO, _orbit_radius + sin(_orbit_angle * 3.0) * 2.0, 0, TAU, 32, Color(1.0, 1.0, 1.0, 0.6), 1.5)
	else:
		# Subtle faint orbit path
		draw_arc(Vector2.ZERO, _orbit_radius, 0, TAU, 32, Color(col.r, col.g, col.b, 0.15), 1.0)

	# Draw orbiting stylized heraldic shields
	for i in active_orbs:
		var angle := _orbit_angle + (TAU / maxf(1.0, float(max_charges))) * i
		var pos := Vector2(cos(angle), sin(angle)) * _orbit_radius

		# Energy trail behind shield
		var trail_angle := angle - 0.3
		var trail_pos := Vector2(cos(trail_angle), sin(trail_angle)) * _orbit_radius
		draw_line(trail_pos, pos, Color(col.r, col.g, col.b, 0.4), 2.5)

		_draw_shield_shape(pos, angle, col)

	# Retaliation / Mythic explosion visual
	if _blast_anim_active:
		var alpha := clampf(1.0 - (_blast_anim_radius / 125.0), 0.0, 1.0)
		var blast_col := Color(col.r, col.g, col.b, alpha)
		draw_circle(Vector2.ZERO, _blast_anim_radius, Color(col.r, col.g, col.b, alpha * 0.25))
		draw_arc(Vector2.ZERO, _blast_anim_radius, 0, TAU, 48, blast_col, 4.0)
		draw_arc(Vector2.ZERO, maxf(0.0, _blast_anim_radius - 6.0), 0, TAU, 32, Color(1.0, 1.0, 1.0, alpha * 0.6), 2.0)


func _draw_shield_shape(pos: Vector2, _rot: float, col: Color) -> void:
	# Glowing aura behind the shield sprite
	draw_circle(pos, 10.0, Color(col.r, col.g, col.b, 0.28))
	draw_circle(pos, 7.0, Color(1.0, 0.9, 0.4, 0.35))
	if SHIELD_TEX != null:
		var s_size := Vector2(15.0, 18.0)
		draw_texture_rect(SHIELD_TEX, Rect2(pos - s_size * 0.5, s_size), false)
	else:
		draw_circle(pos, 5.0, col)
