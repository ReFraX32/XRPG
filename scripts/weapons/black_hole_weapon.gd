class_name BlackHoleWeapon
extends Weapon

## Black Hole Weapon: Absolute crowd control and devastating burst damage.
## Creates singularities that vacuum enemies and collapse violently.
## Scales with wider suction + faster cadence (Epic), secondary mini-holes (Legendary),
## and absorbed entity multiplier for cosmic wipe (Mythic).

const SINGULARITY_SCRIPT := preload("res://scripts/weapons/black_hole_singularity.gd")

var _timer: float = 0.0


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	_timer -= delta
	if _timer <= 0.0:
		_timer = get_cooldown()
		_spawn_singularity()


func _spawn_singularity() -> void:
	var spawn_pos := _find_best_spawn_position()
	var dmg_data := roll_damage_with_crit()

	var radius := get_range_radius() * 1.3
	var duration := 2.8

	# Epic+: Faster frequency, larger radius
	if rarity_tier != WeaponRarity.Tier.COMMON:
		radius *= 1.35
		duration = 2.2

	var sing: BlackHoleSingularity = SINGULARITY_SCRIPT.new()
	get_parent().add_child(sing)
	sing.setup(spawn_pos, rarity_tier, dmg_data["damage"] * 3.5, radius, duration, false)
	sing.collapsed.connect(_on_singularity_collapsed)


func _on_singularity_collapsed(pos: Vector2, _absorbed: int) -> void:
	# Legendary: Spawn 3 mini-black holes around the collapse epicenter
	if rarity_tier == WeaponRarity.Tier.LEGENDARY or rarity_tier == WeaponRarity.Tier.MYTHIC:
		var mini_count := 3
		var mini_radius := get_range_radius() * 0.7
		var mini_dmg := get_damage() * 1.5

		for i in mini_count:
			var angle := (TAU / float(mini_count)) * i + randf_range(-0.2, 0.2)
			var offset := Vector2(cos(angle), sin(angle)) * randf_range(45.0, 75.0)
			var mini_sing: BlackHoleSingularity = SINGULARITY_SCRIPT.new()
			get_parent().add_child(mini_sing)
			mini_sing.setup(pos + offset, rarity_tier, mini_dmg, mini_radius, 1.4, true)


func _find_best_spawn_position() -> Vector2:
	# Aim toward highest cluster of enemies or closest enemy
	var enemies := get_tree().get_nodes_in_group("enemy")
	var best_pos := player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * 60.0
	var closest_dist := INF

	for node in enemies:
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist := player.global_position.distance_to(enemy.global_position)
		if dist < closest_dist and dist > 30.0:
			closest_dist = dist
			best_pos = enemy.global_position

	return best_pos
