class_name Weapon
extends Node2D

## Base class for all modular weapons in the roguelike system.
## Handles rarity scaling, cooldown timers, and interaction with the player and enemies.

signal weapon_fired

@export var weapon_id: StringName = &""
@export var base_damage: float = 10.0
@export var base_range: float = 70.0
@export var base_cooldown: float = 1.0

var rarity_tier: WeaponRarity.Tier = WeaponRarity.Tier.COMMON
var level: int = 1
var player: CharacterBody2D = null
var stats: PlayerStats = null

var _cooldown_timer: float = 0.0


func setup(p_player: CharacterBody2D, p_tier: WeaponRarity.Tier = WeaponRarity.Tier.COMMON) -> void:
	player = p_player
	if player != null and "stats" in player:
		stats = player.stats
	set_rarity(p_tier)
	_on_setup_completed()


func set_rarity(p_tier: WeaponRarity.Tier) -> void:
	rarity_tier = p_tier
	_on_rarity_changed()


func _on_setup_completed() -> void:
	pass


func _on_rarity_changed() -> void:
	pass


func get_multiplier() -> float:
	return WeaponRarity.get_multiplier(rarity_tier)


func get_damage() -> float:
	var stat_scale := 1.0
	if stats != null:
		stat_scale = stats.get_stat(&"damage") / 20.0
	return base_damage * get_multiplier() * maxf(stat_scale, 0.1)


func get_range_radius() -> float:
	# Scales moderately with rarity multiplier
	var mult := get_multiplier()
	return base_range * (1.0 + (mult - 1.0) * 0.35)


func get_cooldown() -> float:
	var attack_speed := 1.0
	if stats != null:
		attack_speed = stats.get_stat(&"attack_speed")
	# Higher rarity slightly improves attack cadence as well
	var cadence_bonus := 1.0 + (get_multiplier() - 1.0) * 0.2
	return maxf(0.08, base_cooldown / (cadence_bonus * maxf(attack_speed, 0.1)))


func is_crit_hit() -> bool:
	if stats == null:
		return false
	var crit_rate := stats.get_stat(&"crit_chance")
	return randf() < crit_rate


func roll_damage_with_crit() -> Dictionary:
	var dmg := get_damage()
	var crit := is_crit_hit()
	if crit:
		dmg *= 2.0
	return {"damage": dmg, "is_crit": crit}


## Intercept damage before player takes it. Weapons like Aegis override this.
func try_intercept_damage(_damage: float, _enemy: Node2D) -> bool:
	return false


## Called when an enemy dies in the world. Weapons like Aura Mythic override this.
func on_enemy_killed(_enemy: Node2D, _exp_val: int) -> void:
	pass
