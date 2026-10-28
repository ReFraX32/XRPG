class_name WeaponDefinition
extends Resource

## Data definition for a weapon in the roguelike system.
## Stores base stats and rarity-dependent mechanics description.

@export var id: StringName = &""
@export var display_name: String = ""
@export var category: String = ""
@export var icon: Texture2D = null
@export_multiline var base_description: String = ""
@export var base_damage: float = 10.0
@export var base_range: float = 70.0
@export var base_cooldown: float = 1.0

# Descriptions for specific rarity perks
@export_multiline var common_perk: String = "Estadísticas base estándar (x1.0)."
@export_multiline var epic_perk: String = ""
@export_multiline var legendary_perk: String = ""
@export_multiline var mythic_perk: String = ""


func get_perk_description(tier: WeaponRarity.Tier) -> String:
	match tier:
		WeaponRarity.Tier.COMMON:
			return common_perk
		WeaponRarity.Tier.EPIC:
			return epic_perk
		WeaponRarity.Tier.LEGENDARY:
			return legendary_perk
		WeaponRarity.Tier.MYTHIC:
			return mythic_perk
	return ""


func get_formatted_description(tier: WeaponRarity.Tier) -> String:
	var perk := get_perk_description(tier)
	return "%s\n▸ %s" % [base_description, perk]
