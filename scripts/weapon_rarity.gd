class_name WeaponRarity
extends RefCounted

## Manages weapon and upgrade rarity tiers, visual styling, stat scaling multipliers,
## and probability distributions for the level-up selection pool.

enum Tier {
	COMMON,     ## Blanco - x1.0
	EPIC,       ## Morado - x1.5 + efecto secundario menor
	LEGENDARY,  ## Naranja - x2.2 + efecto secundario mayor
	MYTHIC      ## Rojo/Arcoíris - x3.5 + pasiva que rompe las reglas
}

const MULTIPLIERS := {
	Tier.COMMON: 1.0,
	Tier.EPIC: 1.5,
	Tier.LEGENDARY: 2.2,
	Tier.MYTHIC: 3.5,
}

const COLORS := {
	Tier.COMMON: Color(0.92, 0.92, 0.95, 1.0),       # Blanco brillante
	Tier.EPIC: Color(0.68, 0.32, 0.96, 1.0),         # Morado
	Tier.LEGENDARY: Color(1.0, 0.55, 0.05, 1.0),     # Naranja
	Tier.MYTHIC: Color(1.0, 0.15, 0.35, 1.0),        # Rojo Carmesí / Mítico
}

const NAMES := {
	Tier.COMMON: "Común",
	Tier.EPIC: "Épica",
	Tier.LEGENDARY: "Legendaria",
	Tier.MYTHIC: "Mítica",
}

## Base roll weights (60% Común, 25% Épica, 12% Legendaria, 3% Mítica)
const BASE_WEIGHTS := {
	Tier.COMMON: 60.0,
	Tier.EPIC: 25.0,
	Tier.LEGENDARY: 12.0,
	Tier.MYTHIC: 3.0,
}


static func get_multiplier(tier: Tier) -> float:
	return MULTIPLIERS.get(tier, 1.0)


static func get_color(tier: Tier) -> Color:
	return COLORS.get(tier, Color.WHITE)


static func get_tier_name(tier: Tier) -> String:
	return NAMES.get(tier, "Común")


static func roll_tier(luck_factor: float = 1.0) -> Tier:
	var weights := BASE_WEIGHTS.duplicate()
	# Luck improves chances of Epic, Legendary and Mythic
	if luck_factor > 1.0:
		weights[Tier.EPIC] *= luck_factor
		weights[Tier.LEGENDARY] *= (luck_factor * 1.25)
		weights[Tier.MYTHIC] *= (luck_factor * 1.5)

	var total_weight: float = 0.0
	for w in weights.values():
		total_weight += w

	var roll := randf() * total_weight
	var cumulative: float = 0.0
	for tier in [Tier.COMMON, Tier.EPIC, Tier.LEGENDARY, Tier.MYTHIC]:
		cumulative += weights[tier]
		if roll <= cumulative:
			return tier
	return Tier.COMMON
