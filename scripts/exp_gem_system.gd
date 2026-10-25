class_name ExpGemSystem
extends Node

## Owns the EXP gem pool and the drop rule: whenever any enemy announces its
## death on the event bus, a gem worth the enemy's scaled EXP appears where
## it fell. Knows nothing about enemies beyond the two signal arguments.

@export var gem_scene: PackedScene
## Hard ceiling on gems in play; the oldest kills simply drop no gem once
## the pool is exhausted, which keeps memory bounded in long runs.
@export var max_gems: int = 250

var _pool: ObjectPool


func _ready() -> void:
	_pool = ObjectPool.new()
	_pool.name = "GemPool"
	_pool.scene = gem_scene
	_pool.max_size = max_gems
	%GemContainer.add_child(_pool)
	GameEvents.enemy_died.connect(_on_enemy_died)


func _on_enemy_died(enemy: Node2D, exp_value: int) -> void:
	if exp_value <= 0:
		return
	var gem := _pool.acquire()
	if gem == null:
		return
	gem.setup(exp_value, enemy.global_position, _pool)
