class_name WeaponManager
extends Node2D

## Manages active weapons equipped by the player, delegating level-ups, rarity upgrades,
## damage interception, and event propagation.

signal weapon_equipped(weapon_id: StringName, tier: WeaponRarity.Tier)
signal weapon_upgraded(weapon_id: StringName, tier: WeaponRarity.Tier)

var player: CharacterBody2D = null
var active_weapons: Dictionary = {} # id -> Weapon instance

# Preloaded weapon scripts
const WEAPON_SCRIPTS := {
	&"aura": preload("res://scripts/weapons/aura_weapon.gd"),
	&"dice": preload("res://scripts/weapons/dice_weapon.gd"),
	&"aegis": preload("res://scripts/weapons/aegis_weapon.gd"),
	&"black_hole": preload("res://scripts/weapons/black_hole_weapon.gd"),
}


func _ready() -> void:
	if player == null:
		player = get_parent() as CharacterBody2D
	GameEvents.enemy_died.connect(_on_enemy_died)


func has_weapon(id: StringName) -> bool:
	return active_weapons.has(id)


func get_weapon(id: StringName) -> Weapon:
	return active_weapons.get(id, null)


func add_or_upgrade_weapon(def: WeaponDefinition, tier: WeaponRarity.Tier) -> Weapon:
	if player == null:
		player = get_parent() as CharacterBody2D

	var id := def.id
	if active_weapons.has(id):
		# Upgrade existing weapon
		var weapon: Weapon = active_weapons[id]
		# Only upgrade tier if new tier is equal or higher
		if int(tier) >= int(weapon.rarity_tier):
			weapon.set_rarity(tier)
		weapon.level += 1
		weapon_upgraded.emit(id, weapon.rarity_tier)
		return weapon

	# Instantiate new weapon
	if not WEAPON_SCRIPTS.has(id):
		push_error("Weapon script not registered for: %s" % id)
		return null

	var script: GDScript = WEAPON_SCRIPTS[id]
	var weapon: Weapon = script.new()
	weapon.name = str(id)
	weapon.weapon_id = id
	weapon.base_damage = def.base_damage
	weapon.base_range = def.base_range
	weapon.base_cooldown = def.base_cooldown
	add_child(weapon)
	weapon.setup(player, tier)
	active_weapons[id] = weapon
	weapon_equipped.emit(id, tier)
	return weapon


func try_intercept_damage(amount: float, enemy: Node2D) -> bool:
	for weapon in active_weapons.values():
		if weapon.try_intercept_damage(amount, enemy):
			return true
	return false


func _on_enemy_died(enemy: Node2D, exp_val: int) -> void:
	for weapon in active_weapons.values():
		if weapon != null and is_instance_valid(weapon):
			weapon.on_enemy_killed(enemy, exp_val)
