class_name RunDirector
extends Node

## Owns the survival loop's meta-state: run timer, kill counter, EXP
## accumulation, the level curve, and the level-up flow (pause the tree,
## offer three choices, apply, resume). Gameplay systems talk to it only
## through the GameEvents bus; UI talks to it directly, same scene.
##
## Multiple level-ups queued in one burst are honored one upgrade at a
## time: the UI re-rolls and stays open until the queue drains.

@export var difficulty: DifficultyConfig

var run_time := 0.0
var kills := 0
var level := 1
var exp_current := 0
var pending_level_ups := 0
var game_over := false
var spawner: EnemySpawner
var upgrades: Array[UpgradeDefinition] = []
var weapon_definitions: Array[WeaponDefinition] = []

@onready var _player: CharacterBody2D = %player
@onready var _stats: PlayerStats = %player.get_node("PlayerStats")
@onready var _hud: CanvasLayer = %HUD
@onready var _level_up_ui: CanvasLayer = %LevelUpUI
@onready var _game_over_ui: CanvasLayer = %GameOverUI


func _ready() -> void:
	_load_upgrades()
	_load_weapons()
	spawner = %EnemySpawner
	GameEvents.exp_collected.connect(_on_exp_collected)
	GameEvents.enemy_died.connect(_on_enemy_died)
	GameEvents.player_died.connect(_on_player_died)
	_level_up_ui.upgrade_selected.connect(_on_upgrade_selected)
	_hud.setup(self)


func _process(delta: float) -> void:
	# Root is PAUSABLE, so this naturally freezes while the level-up or
	# game-over overlay is up.
	if not game_over:
		run_time += delta


const UPGRADES_DIRECTORY := "res://data/upgrades"
const WEAPONS_DIRECTORY := "res://data/weapons"


## Discovers UpgradeDefinition resources dropped into data/upgrades.
func _load_upgrades() -> void:
	upgrades.clear()
	var dir := DirAccess.open(UPGRADES_DIRECTORY)
	if dir == null:
		push_warning("No data/upgrades directory found; level-ups will have no choices")
		return
	for file in dir.get_files():
		var filename: String = file.trim_suffix(".remap")
		if not filename.ends_with(".tres"):
			continue
		var resource := load(UPGRADES_DIRECTORY.path_join(filename))
		if resource is UpgradeDefinition:
			upgrades.append(resource)


## Discovers WeaponDefinition resources dropped into data/weapons.
func _load_weapons() -> void:
	weapon_definitions.clear()
	var dir := DirAccess.open(WEAPONS_DIRECTORY)
	if dir == null:
		return
	for file in dir.get_files():
		var filename: String = file.trim_suffix(".remap")
		if not filename.ends_with(".tres"):
			continue
		var resource := load(WEAPONS_DIRECTORY.path_join(filename))
		if resource is WeaponDefinition:
			weapon_definitions.append(resource)


func _on_enemy_died(_enemy: Node2D, _exp_value: int) -> void:
	kills += 1


func _on_exp_collected(amount: int) -> void:
	if game_over:
		return
	exp_current += roundi(amount * _stats.get_stat(&"exp_gain"))
	var leveled := false
	while exp_current >= difficulty.exp_for_level(level):
		exp_current -= difficulty.exp_for_level(level)
		level += 1
		pending_level_ups += 1
		leveled = true
	if leveled and not _level_up_ui.is_open:
		_open_level_up()


func _open_level_up() -> void:
	var options := _roll_options(3)
	if options.is_empty():
		pending_level_ups = 0
		return
	get_tree().paused = true
	_level_up_ui.open(options)


## Generates 3 random choices combining Weapons and Passives with weighted Rarities
func _roll_options(count: int) -> Array:
	var candidates: Array[WeaponUpgradeOption] = []
	var wm: WeaponManager = null
	if _player != null and "weapon_manager" in _player:
		wm = _player.weapon_manager

	# 1. Weapon Candidates
	for wdef in weapon_definitions:
		var has_it := wm != null and wm.has_weapon(wdef.id)
		var current_tier := WeaponRarity.Tier.COMMON
		if has_it:
			current_tier = wm.get_weapon(wdef.id).rarity_tier

		# Roll a tier
		var rolled_tier := WeaponRarity.roll_tier()
		if has_it:
			# If player already owns it, ensure the upgrade is at least current tier or higher
			if int(rolled_tier) < int(current_tier) and int(current_tier) < int(WeaponRarity.Tier.MYTHIC):
				rolled_tier = (current_tier + 1) as WeaponRarity.Tier
			candidates.append(WeaponUpgradeOption.create_for_weapon(wdef, rolled_tier, false))
		else:
			candidates.append(WeaponUpgradeOption.create_for_weapon(wdef, rolled_tier, true))

	# 2. Passive Upgrade Candidates
	for upg in upgrades:
		if _stats.get_upgrade_count(upg.id) < upg.max_applications:
			var rolled_tier := WeaponRarity.roll_tier()
			candidates.append(WeaponUpgradeOption.create_for_passive(upg, rolled_tier))

	candidates.shuffle()
	var selected: Array = []
	for i in mini(count, candidates.size()):
		selected.append(candidates[i])
	return selected


func _on_upgrade_selected(option: Variant) -> void:
	if option is WeaponUpgradeOption:
		if option.is_weapon:
			var wm: WeaponManager = null
			if _player != null and "weapon_manager" in _player:
				wm = _player.weapon_manager
			if wm != null:
				wm.add_or_upgrade_weapon(option.weapon_def, option.rarity_tier)
			# Weapon Mastery bonus to stats so every weapon enhances the player's core attributes
			_stats.add_permanent_stat(&"damage", 1.0 * option.multiplier)
			GameEvents.upgrade_applied.emit(option.weapon_def)
		else:
			if option.passive_upgrade != null:
				if _apply_scaled_passive(option.passive_upgrade, option.multiplier):
					GameEvents.upgrade_applied.emit(option.passive_upgrade)
	elif option is UpgradeDefinition:
		if _stats.apply_upgrade(option):
			GameEvents.upgrade_applied.emit(option)

	pending_level_ups -= 1
	if pending_level_ups > 0:
		var next_options := _roll_options(3)
		if not next_options.is_empty():
			_level_up_ui.open(next_options)
			return
		pending_level_ups = 0
	_level_up_ui.close()
	get_tree().paused = false


func _apply_scaled_passive(upgrade: UpgradeDefinition, multiplier: float) -> bool:
	if not _stats.apply_upgrade(upgrade):
		return false
	# If rarity tier multiplier > 1.0, grant the bonus stats
	if multiplier > 1.0:
		for effect in upgrade.effects:
			var extra := effect.value * (multiplier - 1.0)
			_stats.add_permanent_stat(effect.stat, extra)
	return true


func _on_player_died() -> void:
	game_over = true
	pending_level_ups = 0
	if _level_up_ui.is_open:
		_level_up_ui.close()
	get_tree().paused = true
	_game_over_ui.open(level, kills, run_time)
