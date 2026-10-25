class_name PlayerStats
extends Node

## Player stat registry. Owns the base stat block and recomputes current
## values from the full list of applied upgrades whenever one is added.
## Recomputing instead of mutating in place means upgrades can never drift
## the stats into a broken state (add/remove/reorder are all idempotent).

## Fired after every recalculation; listeners re-read what they care about
## (timers, health bar max, pickup area shape).
signal stats_recalculated

const BASE_STATS := {
	&"max_health": 100.0,
	&"move_speed": 100.0,
	&"damage": 20.0,
	&"attack_speed": 1.0,   # multiplier on attack cadence
	&"pickup_radius": 60.0,
	&"health_regen": 4.0,   # hp per second
	&"exp_gain": 1.0,       # multiplier applied to collected gems
}

## UpgradeDefinition -> times picked, used to honor max_applications and to
## show current stacks in the level-up UI.
var upgrade_counts := {}

var _applied: Array[UpgradeDefinition] = []
var _values := {}


func _ready() -> void:
	recalculate()


func get_stat(stat: StringName) -> float:
	return _values.get(stat, 0.0)


func get_upgrade_count(id: StringName) -> int:
	return upgrade_counts.get(id, 0)


## Returns true if the upgrade was applied, false when already maxed out.
func apply_upgrade(upgrade: UpgradeDefinition) -> bool:
	if upgrade == null:
		return false
	if get_upgrade_count(upgrade.id) >= upgrade.max_applications:
		return false
	_applied.append(upgrade)
	upgrade_counts[upgrade.id] = get_upgrade_count(upgrade.id) + 1
	recalculate()
	return true


func recalculate() -> void:
	_values = BASE_STATS.duplicate()
	for upgrade in _applied:
		for effect in upgrade.effects:
			effect.apply_to(_values)
	stats_recalculated.emit()
