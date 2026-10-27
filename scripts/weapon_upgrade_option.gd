class_name WeaponUpgradeOption
extends RefCounted

## Represents an upgrade or weapon option displayed in the level-up selection UI.

var is_weapon: bool = true
var weapon_def: WeaponDefinition = null
var passive_upgrade: UpgradeDefinition = null
var rarity_tier: WeaponRarity.Tier = WeaponRarity.Tier.COMMON
var display_name: String = ""
var category: String = ""
var description: String = ""
var multiplier: float = 1.0
var rarity_name: String = "Común"
var rarity_color: Color = Color.WHITE
var is_new_weapon: bool = true
var icon: Texture2D = null


static func create_for_weapon(def: WeaponDefinition, tier: WeaponRarity.Tier, is_new: bool) -> WeaponUpgradeOption:
	var opt := WeaponUpgradeOption.new()
	opt.is_weapon = true
	opt.weapon_def = def
	opt.icon = def.icon
	opt.rarity_tier = tier
	opt.multiplier = WeaponRarity.get_multiplier(tier)
	opt.rarity_name = WeaponRarity.get_tier_name(tier)
	opt.rarity_color = WeaponRarity.get_color(tier)
	opt.is_new_weapon = is_new

	opt.display_name = def.display_name
	opt.category = ("NUEVA ARMA • " if is_new else "MEJORA • ") + def.category
	opt.description = def.get_formatted_description(tier)
	return opt


static func create_for_passive(def: UpgradeDefinition, tier: WeaponRarity.Tier) -> WeaponUpgradeOption:
	var opt := WeaponUpgradeOption.new()
	opt.is_weapon = false
	opt.passive_upgrade = def
	opt.rarity_tier = tier
	opt.multiplier = WeaponRarity.get_multiplier(tier)
	opt.rarity_name = WeaponRarity.get_tier_name(tier)
	opt.rarity_color = WeaponRarity.get_color(tier)
	opt.is_new_weapon = false

	opt.display_name = def.display_name
	opt.category = "MEJORA PASIVA"
	opt.description = "%s\n▸ Efecto x%.1f" % [def.description, opt.multiplier]
	return opt
