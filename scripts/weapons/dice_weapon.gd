class_name DiceWeapon
extends Weapon

## Dice Weapon: Risk and progressive scaling weapon.
## Throws animated dice dealing damage based on rolled faces (1..6).
## Scales with speed buffs (Epic), permanent crit increase (Legendary),
## and 3-dice jackpot screen wipe + invulnerability (Mythic).

const PROJECTILE_SCRIPT := preload("res://scripts/weapons/dice_projectile.gd")

var _timer: float = 0.0
var _mythic_throw_count: int = 0


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	_timer -= delta
	if _timer <= 0.0:
		_timer = get_cooldown()
		_throw_dice()


func _throw_dice() -> void:
	var enemies := _get_nearby_enemies(get_range_radius() * 2.5)
	var spawn_pos := player.global_position

	if rarity_tier == WeaponRarity.Tier.MYTHIC:
		_throw_mythic_triple_dice(spawn_pos, enemies)
	else:
		_throw_single_die(spawn_pos, enemies)


func _roll_value() -> int:
	match rarity_tier:
		WeaponRarity.Tier.COMMON:
			return randi_range(1, 6)
		WeaponRarity.Tier.EPIC:
			return randi_range(3, 6)
		WeaponRarity.Tier.LEGENDARY:
			# High rolls, heavily weighted toward 6
			return 6 if randf() < 0.65 else 5
		WeaponRarity.Tier.MYTHIC:
			return randi_range(4, 6)
	return randi_range(1, 6)


func _throw_single_die(from: Vector2, enemies: Array[Node2D]) -> void:
	var target_pos := _choose_target_position(from, enemies)
	var roll := _roll_value()
	var dmg_data := roll_damage_with_crit()
	var total_dmg: float = dmg_data["damage"] * (roll / 3.0)

	var proj: DiceProjectile = PROJECTILE_SCRIPT.new()
	get_parent().add_child(proj)
	proj.setup(from, target_pos, roll, total_dmg, rarity_tier, dmg_data["is_crit"])
	proj.landed.connect(_on_die_landed)


func _throw_mythic_triple_dice(from: Vector2, enemies: Array[Node2D]) -> void:
	_mythic_throw_count += 1
	var rolls: Array[int] = []

	# Pity / high-luck mechanic: guaranteed triple 6 every 4th throw or 25% random chance
	var is_jackpot := (_mythic_throw_count % 4 == 0) or (randf() < 0.25)
	if is_jackpot:
		rolls = [6, 6, 6]
	else:
		rolls = [_roll_value(), _roll_value(), _roll_value()]

	var sum_rolls := rolls[0] + rolls[1] + rolls[2]
	var dmg_data := roll_damage_with_crit()

	for i in 3:
		var offset_angle := (TAU / 3.0) * i + randf_range(-0.3, 0.3)
		var target_pos := _choose_target_position(from, enemies) + Vector2.RIGHT.rotated(offset_angle) * 35.0
		var roll := rolls[i]
		var total_dmg: float = dmg_data["damage"] * (roll / 2.5)

		var proj: DiceProjectile = PROJECTILE_SCRIPT.new()
		get_parent().add_child(proj)
		proj.setup(from, target_pos, roll, total_dmg, rarity_tier, dmg_data["is_crit"])

	if sum_rolls == 18:
		_trigger_jackpot()


func _on_die_landed(roll: int, _pos: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return

	# Epic: Roll of 6 grants temporary movement speed
	if rarity_tier == WeaponRarity.Tier.EPIC and roll == 6:
		if player.has_method("grant_speed_boost"):
			player.grant_speed_boost(1.35, 2.5)

	# Legendary: Each 6 permanently raises critical strike chance for the build
	if (rarity_tier == WeaponRarity.Tier.LEGENDARY or rarity_tier == WeaponRarity.Tier.MYTHIC) and roll == 6:
		if stats != null and stats.has_method("add_permanent_stat"):
			stats.add_permanent_stat(&"crit_chance", 0.01)


func _trigger_jackpot() -> void:
	# Mythic 18: Invulnerability + Screen Wipe
	if player != null and is_instance_valid(player) and player.has_method("grant_invulnerability"):
		player.grant_invulnerability(3.0)

	var enemies := get_tree().get_nodes_in_group("enemy")
	for node in enemies:
		var enemy := node as Node2D
		if enemy != null and is_instance_valid(enemy):
			if enemy.has_method("take_damage"):
				enemy.take_damage(9999.0, true)


func _choose_target_position(from: Vector2, enemies: Array[Node2D]) -> Vector2:
	if not enemies.is_empty():
		var chosen: Node2D = enemies.pick_random()
		if chosen != null and is_instance_valid(chosen):
			return chosen.global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
	# Fallback if no enemies
	var random_dir := Vector2.RIGHT.rotated(randf() * TAU)
	return from + random_dir * randf_range(40, 100)


func _get_nearby_enemies(max_dist: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if player == null:
		return result
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if player.global_position.distance_to(enemy.global_position) <= max_dist:
			result.append(enemy)
	return result
