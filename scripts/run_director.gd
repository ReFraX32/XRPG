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

@onready var _stats: PlayerStats = %player.get_node("PlayerStats")
@onready var _hud: CanvasLayer = %HUD
@onready var _level_up_ui: CanvasLayer = %LevelUpUI
@onready var _game_over_ui: CanvasLayer = %GameOverUI


func _ready() -> void:
	_load_upgrades()
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


## Discovers UpgradeDefinition resources dropped into data/upgrades, so new
## upgrades ship as data files without touching this script.
func _load_upgrades() -> void:
	upgrades.clear()
	var dir := DirAccess.open(UPGRADES_DIRECTORY)
	if dir == null:
		push_warning("No data/upgrades directory found; level-ups will have no choices")
		return
	for file in dir.get_files():
		# Exported builds append .remap to resources; strip it back off.
		var filename: String = file.trim_suffix(".remap")
		if not filename.ends_with(".tres"):
			continue
		var resource := load(UPGRADES_DIRECTORY.path_join(filename))
		if resource is UpgradeDefinition:
			upgrades.append(resource)


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
		# Entire pool maxed out: nothing to offer, quietly consume the queue.
		pending_level_ups = 0
		return
	get_tree().paused = true
	_level_up_ui.open(options)


func _roll_options(count: int) -> Array:
	var eligible: Array = []
	for upgrade in upgrades:
		if _stats.get_upgrade_count(upgrade.id) < upgrade.max_applications:
			eligible.append(upgrade)
	eligible.shuffle()
	return eligible.slice(0, mini(count, eligible.size()))


func _on_upgrade_selected(upgrade: UpgradeDefinition) -> void:
	if _stats.apply_upgrade(upgrade):
		GameEvents.upgrade_applied.emit(upgrade)
	pending_level_ups -= 1
	if pending_level_ups > 0:
		var options := _roll_options(3)
		if not options.is_empty():
			_level_up_ui.open(options)
			return
		pending_level_ups = 0
	_level_up_ui.close()
	get_tree().paused = false


func _on_player_died() -> void:
	game_over = true
	pending_level_ups = 0
	if _level_up_ui.is_open:
		_level_up_ui.close()
	get_tree().paused = true
	_game_over_ui.open(level, kills, run_time)
