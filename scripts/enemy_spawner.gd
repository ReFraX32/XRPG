class_name EnemySpawner
extends Node

## Infinite horde spawner. Every enemy definition gets its own ObjectPool;
## bodies are acquired, injected with stats, and recycled when they die or
## drift past the despawn radius. Difficulty scales with run time through
## the DifficultyConfig resource — the spawner itself holds no tuning numbers.
##
## Spawn batches are capped per tick and total live enemies are capped by
## the config, so worst-case cost per frame stays predictable.

@export var difficulty: DifficultyConfig
@export var definitions: Array[EnemyDefinition] = []
@export var enemy_scene: PackedScene

@onready var _map: MapGenerator = %MapGenerator
@onready var _container: Node2D = %EnemyContainer

var _player: Node2D
var _pools := {}  # StringName (definition id) -> ObjectPool
var _elapsed := 0.0
var _spawn_cooldown := 0.0
var _sweep_cooldown := 0.0


func _ready() -> void:
	var players := get_tree().get_nodes_in_group("player")
	_player = players[0] if not players.is_empty() else null
	for definition in definitions:
		var pool := ObjectPool.new()
		pool.name = "Pool_%s" % definition.id
		pool.scene = enemy_scene
		pool.max_size = difficulty.max_alive_max if difficulty != null else 300
		_container.add_child(pool)
		_pools[definition.id] = pool
	# First wave arrives one full interval in, giving the player a grace beat.
	_spawn_cooldown = difficulty.spawn_interval_at(0.0) if difficulty != null else 1.0


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		_player = players[0] if not players.is_empty() else null
		if _player == null:
			return
	_elapsed += delta
	_spawn_cooldown -= delta
	_sweep_cooldown -= delta
	if _spawn_cooldown <= 0.0:
		_spawn_cooldown += difficulty.spawn_interval_at(minutes())
		_spawn_batch()
	if _sweep_cooldown <= 0.0:
		_sweep_cooldown = 0.5
		_despawn_far_enemies()


func minutes() -> float:
	return _elapsed / 60.0


func total_alive() -> int:
	var total := 0
	for pool in _pools.values():
		total += pool.active_count
	return total


func _spawn_batch() -> void:
	var room := difficulty.max_alive_at(minutes()) - total_alive()
	if room <= 0:
		return
	var count := mini(difficulty.batch_size_at(minutes()), mini(room, difficulty.max_spawns_per_tick))
	for i in count:
		_spawn_one()


func _spawn_one() -> void:
	var definition := _pick_definition()
	if definition == null:
		return
	var spawn_position := _find_spawn_position()
	if spawn_position == Vector2.INF:
		return
	var pool: ObjectPool = _pools[definition.id]
	var enemy := pool.acquire()
	if enemy == null:
		return
	var m := minutes()
	enemy.setup(
		definition,
		_player,
		pool,
		difficulty.health_scale_at(m),
		difficulty.speed_scale_at(m),
		difficulty.exp_scale_at(m)
	)
	enemy.global_position = spawn_position


func _pick_definition() -> EnemyDefinition:
	var total_weight := 0.0
	for definition in definitions:
		if definition.unlock_time <= _elapsed:
			total_weight += definition.weight
	if total_weight <= 0.0:
		return null
	var roll := randf() * total_weight
	for definition in definitions:
		if definition.unlock_time > _elapsed:
			continue
		roll -= definition.weight
		if roll <= 0.0:
			return definition
	return definitions[0]


## Random point on a ring around the player, validated against the map so
## nothing spawns inside a tree or rock. Vector2.INF means "no valid spot".
func _find_spawn_position() -> Vector2:
	for attempt in 5:
		var angle := randf() * TAU
		var distance := randf_range(difficulty.spawn_radius_min, difficulty.spawn_radius_max)
		var candidate := _player.global_position + Vector2.from_angle(angle) * distance
		if _map.is_walkable(candidate):
			return candidate
	return Vector2.INF


## Off-screen culling: enemies that chased the player too far away stop
## existing (no rewards), keeping the active set tight around the action.
## Dying enemies are skipped — unless their death animation somehow never
## finished, in which case the corpse is force-recycled so it can never
## linger on screen looking alive.
func _despawn_far_enemies() -> void:
	var despawn_sq := difficulty.despawn_radius * difficulty.despawn_radius
	var player_position := _player.global_position
	for pool in _pools.values():
		for enemy in pool.get_children():
			if not enemy.visible:
				continue
			if enemy._dying:
				# 3 seconds of *unpaused* physics frames: wall clock would
				# recycle corpses whose death animation is merely frozen by
				# a level-up pause, breaking their animation callbacks.
				if Engine.get_physics_frames() - enemy._death_frame > Engine.physics_ticks_per_second * 3:
					pool.release(enemy)
				continue
			if enemy.global_position.distance_squared_to(player_position) > despawn_sq:
				pool.release(enemy)
