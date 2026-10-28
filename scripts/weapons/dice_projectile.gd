class_name DiceProjectile
extends Node2D

## Visual and physical dice projectile. Bounces towards target, shows face, deals damage.

signal landed(roll: int, hit_position: Vector2)

const DICE_TEX := preload("res://art/weapons/dice_icon.png")

var velocity: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var roll_value: int = 1
var is_crit: bool = false
var damage: float = 10.0
var tier: WeaponRarity.Tier = WeaponRarity.Tier.COMMON

var _air_time: float = 0.45
var _elapsed: float = 0.0
var _landed: bool = false
var _rotation_speed: float = 15.0
var _scale_anim: float = 1.0


func setup(from: Vector2, to: Vector2, p_roll: int, p_damage: float, p_tier: WeaponRarity.Tier, p_crit: bool) -> void:
	global_position = from
	target_pos = to
	roll_value = p_roll
	damage = p_damage
	tier = p_tier
	is_crit = p_crit
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var dist := from.distance_to(to)
	velocity = (to - from).normalized() * (dist / _air_time)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if not _landed:
		rotation += _rotation_speed * delta
		global_position += velocity * delta
		# Arc height simulation
		var t := _elapsed / _air_time
		var arc := sin(t * PI) * 18.0
		position.y -= arc * delta * 4.0

		if _elapsed >= _air_time:
			_landed = true
			rotation = 0.0
			_on_land()
	else:
		# Fade out after showing result
		_scale_anim += delta * 0.8
		modulate.a -= delta * 2.0
		if modulate.a <= 0.0:
			queue_free()
	queue_redraw()


func _on_land() -> void:
	landed.emit(roll_value, global_position)
	var blast_radius := 42.0

	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) <= blast_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, true)
			if enemy.has_method("apply_knockback"):
				var push := (enemy.global_position - global_position).normalized() * (roll_value * 25.0)
				enemy.apply_knockback(push)


func _draw() -> void:
	var border_col := WeaponRarity.get_color(tier)
	var size := Vector2(20, 20) * _scale_anim
	var half := size / 2.0

	# 1. Ground Drop Shadow & Rolling Sprite (when in flight)
	if not _landed:
		var shadow_size := Vector2(16, 7) * (1.0 - (_elapsed / _air_time) * 0.3)
		_draw_shadow_ellipse(Vector2(0, 14), shadow_size.x, shadow_size.y, Color(0.0, 0.0, 0.0, 0.35))
		draw_circle(Vector2.ZERO, 13.0, Color(1.0, 0.65, 0.15, 0.35))
		if DICE_TEX != null:
			var t_size := Vector2(26, 26)
			draw_texture_rect(DICE_TEX, Rect2(-t_size * 0.5, t_size), false)
			return

	# 2. Golden Flame Halo on Landing
	draw_circle(Vector2.ZERO, 15.0 * _scale_anim, Color(1.0, 0.65, 0.15, 0.35))
	draw_circle(Vector2.ZERO, 12.0 * _scale_anim, Color(border_col.r, border_col.g, border_col.b, 0.25))

	# 3. Main Ivory / Ice-Blue Pixel Die Body
	var body_rect := Rect2(-half, size)
	draw_rect(body_rect, Color(0.85, 0.91, 0.96, 0.98), true)

	# 4. 3D Shading & Crisp Dark Pixel Outline
	draw_line(Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Color.WHITE, 2.0)
	draw_line(Vector2(-half.x, -half.y), Vector2(-half.x, half.y), Color.WHITE, 2.0)
	draw_line(Vector2(-half.x, half.y), Vector2(half.x, half.y), Color(0.55, 0.65, 0.78, 1.0), 2.0)
	draw_line(Vector2(half.x, -half.y), Vector2(half.x, half.y), Color(0.55, 0.65, 0.78, 1.0), 2.0)
	draw_rect(body_rect, Color(0.08, 0.08, 0.12, 1.0), false, 2.0)
	draw_rect(Rect2(-half - Vector2(1.5, 1.5), size + Vector2(3, 3)), border_col, false, 1.5)

	# 5. Pips (Dots)
	var dot_col := Color(0.18, 0.15, 0.32, 1.0)
	var r := 2.1 * _scale_anim
	var o := 5.2 * _scale_anim

	match roll_value:
		1:
			_draw_pip(Vector2.ZERO, r * 1.4, Color(0.95, 0.15, 0.22, 1.0))
		2:
			_draw_pip(Vector2(-o, -o), r, dot_col)
			_draw_pip(Vector2(o, o), r, dot_col)
		3:
			_draw_pip(Vector2(-o, -o), r, dot_col)
			_draw_pip(Vector2.ZERO, r, dot_col)
			_draw_pip(Vector2(o, o), r, dot_col)
		4:
			_draw_pip(Vector2(-o, -o), r, dot_col)
			_draw_pip(Vector2(o, -o), r, dot_col)
			_draw_pip(Vector2(-o, o), r, dot_col)
			_draw_pip(Vector2(o, o), r, dot_col)
		5:
			_draw_pip(Vector2(-o, -o), r, dot_col)
			_draw_pip(Vector2(o, -o), r, dot_col)
			_draw_pip(Vector2.ZERO, r, Color(0.95, 0.15, 0.22, 1.0))
			_draw_pip(Vector2(-o, o), r, dot_col)
			_draw_pip(Vector2(o, o), r, dot_col)
		6:
			var six_col := Color(0.95, 0.15, 0.22, 1.0)
			_draw_pip(Vector2(-o, -o), r, six_col)
			_draw_pip(Vector2(o, -o), r, six_col)
			_draw_pip(Vector2(-o, 0), r, six_col)
			_draw_pip(Vector2(o, 0), r, six_col)
			_draw_pip(Vector2(-o, o), r, six_col)
			_draw_pip(Vector2(o, o), r, six_col)

	# 6. Landing Impact Wave
	if _landed:
		var impact_r := 38.0 * (_scale_anim - 1.0)
		var impact_a := clampf(modulate.a, 0.0, 1.0)
		draw_arc(Vector2.ZERO, impact_r, 0, TAU, 28, Color(border_col.r, border_col.g, border_col.b, impact_a * 0.8), 2.5)


func _draw_pip(pos: Vector2, radius: float, col: Color) -> void:
	draw_circle(pos, radius, col)
	draw_circle(pos, radius * 0.4, Color.WHITE)


func _draw_shadow_ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := (TAU / 16.0) * i
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
