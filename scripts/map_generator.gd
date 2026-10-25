class_name MapGenerator
extends Node2D

## Streams an infinite, deterministic tile world around the player.
##
## The map is divided into square chunks (config.chunk_size tiles per side).
## Chunks near the player are built and painted into shared TileMapLayers;
## chunks that fall out of range have their cells erased. Each chunk derives
## its RNG seed from (world_seed, chunk coords), so generation is fully
## deterministic and revisited terrain regenerates identically.
##
## Kept strictly separate from the enemy spawner: the spawner only pulls
## is_walkable() queries from here and knows nothing about tiles.

## TileSet source ids inside survival_tileset.tres.
const SRC_PLAINS := 0
const SRC_GRASS := 1
const SRC_OBJECTS := 2
const SRC_DECOR := 3

## Dirt-patch blob tiles (3x3 set + isolated dot) in the plains source.
const DIRT_CENTER := Vector2i(2, 1)
const DIRT_EDGE_TOP := Vector2i(2, 0)
const DIRT_EDGE_BOTTOM := Vector2i(2, 2)
const DIRT_EDGE_LEFT := Vector2i(1, 1)
const DIRT_EDGE_RIGHT := Vector2i(3, 1)
const DIRT_CORNER_TOP_LEFT := Vector2i(1, 0)
const DIRT_CORNER_TOP_RIGHT := Vector2i(3, 0)
const DIRT_CORNER_BOTTOM_LEFT := Vector2i(1, 2)
const DIRT_CORNER_BOTTOM_RIGHT := Vector2i(3, 2)
const DIRT_ISOLATED := Vector2i(0, 3)

## Small decor details, one row on grass (decor source row 0) and one on dirt.
const GRASS_DETAILS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
const DIRT_DETAILS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]

## Occupancy values stored per cell in a chunk.
const CELL_FREE := 0
const CELL_BLOCKED := 1

## Emitted while the initial chunk area is still building (loading screen).
signal initial_build_progress(progress: float)
## Emitted once the initial chunk area around the spawn point is complete.
signal initial_build_finished

@export var config: MapGenerationConfig

@onready var _ground: TileMapLayer = $ground
@onready var _detail: TileMapLayer = $detail
@onready var _props: TileMapLayer = $props

var _chunks := {}  # Vector2i -> PackedByteArray occupancy (chunk_size^2)
var _build_queue: Array[Vector2i] = []
var _player: Node2D
var _last_player_chunk := Vector2i(9999, 9999)
# Initial-area build tracking (drives the loading screen).
var _initial_total := 0
var _initial_done := false


func _ready() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0]
		_update_streaming()


func _physics_process(_delta: float) -> void:
	if config == null:
		return
	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		_player = players[0] if not players.is_empty() else null
		if _player == null:
			return
	_update_streaming()


func is_initial_build_done() -> bool:
	return _initial_done


## 0..1 progress of the initial chunk area build (1.0 when done).
func initial_progress() -> float:
	if _initial_done or _initial_total == 0:
		return 1.0
	return clampf(1.0 - float(_build_queue.size()) / float(_initial_total), 0.0, 1.0)


func _update_streaming() -> void:
	var chunk_margin: int = config.render_margin_chunks
	var player_chunk := cell_to_chunk(_ground.local_to_map(_player.global_position))
	if player_chunk != _last_player_chunk:
		_last_player_chunk = player_chunk
		_enqueue_needed(player_chunk, chunk_margin)
		_unload_far(player_chunk, chunk_margin + 1)
		if _initial_total == 0:
			_initial_total = _build_queue.size()

	var budget := config.chunks_built_per_frame
	if not _initial_done:
		budget = config.initial_build_chunks_per_frame
	while not _build_queue.is_empty() and budget > 0:
		var chunk: Vector2i = _build_queue.pop_front()
		if not _chunks.has(chunk):
			_generate_chunk(chunk)
		budget -= 1

	if not _initial_done and _initial_total > 0:
		initial_build_progress.emit(initial_progress())
		if _build_queue.is_empty():
			_initial_done = true
			initial_build_finished.emit()


## True when `world_pos` sits on a cell no prop occupies. Unloaded chunks
## count as walkable; the spawn ring always lies inside the loaded margin.
func is_walkable(world_pos: Vector2) -> bool:
	var cell := _ground.local_to_map(world_pos)
	var chunk := cell_to_chunk(cell)
	var occupied: PackedByteArray = _chunks.get(chunk, PackedByteArray())
	if occupied.is_empty():
		return true
	var local := cell - chunk * config.chunk_size
	return occupied[local.y * config.chunk_size + local.x] == CELL_FREE


func cell_to_chunk(cell: Vector2i) -> Vector2i:
	var size := config.chunk_size
	return Vector2i(floori(float(cell.x) / size), floori(float(cell.y) / size))


func _enqueue_needed(center: Vector2i, margin: int) -> void:
	for dy in range(-margin, margin + 1):
		for dx in range(-margin, margin + 1):
			var chunk := center + Vector2i(dx, dy)
			if not _chunks.has(chunk) and not _build_queue.has(chunk):
				_build_queue.append(chunk)


func _unload_far(center: Vector2i, max_distance: int) -> void:
	var unloaded := 0
	for chunk: Vector2i in _chunks.keys():
		var offset := (chunk - center).abs()
		if maxf(offset.x, offset.y) > max_distance:
			_erase_chunk_cells(chunk)
			_chunks.erase(chunk)
			unloaded += 1
			if unloaded >= 2:
				return


func _erase_chunk_cells(chunk: Vector2i) -> void:
	var size := config.chunk_size
	var origin := chunk * size
	for y in size:
		for x in size:
			var cell := origin + Vector2i(x, y)
			_ground.erase_cell(cell)
			_detail.erase_cell(cell)
			_props.erase_cell(cell)


func _generate_chunk(chunk: Vector2i) -> void:
	var size := config.chunk_size
	var occupied := PackedByteArray()
	occupied.resize(size * size)
	_chunks[chunk] = occupied

	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(chunk)

	var dirt := _paint_dirt_patches(chunk, rng)
	_paint_details(chunk, rng, dirt)
	_place_props(chunk, rng, occupied)


func _chunk_seed(chunk: Vector2i) -> int:
	return hash([config.world_seed, chunk.x, chunk.y])


func _paint_dirt_patches(chunk: Vector2i, rng: RandomNumberGenerator) -> PackedByteArray:
	var size := config.chunk_size
	var dirt := PackedByteArray()
	dirt.resize(size * size)
	for i in config.dirt_patch_attempts:
		var radius := rng.randi_range(config.dirt_patch_radius_min, config.dirt_patch_radius_max)
		# Keep blobs fully inside the chunk so edges never get visually cut.
		var center := Vector2i(rng.randi_range(radius, size - 1 - radius), rng.randi_range(radius, size - 1 - radius))
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if dx * dx + dy * dy > radius * radius:
					continue
				var local := center + Vector2i(dx, dy)
				dirt[local.y * size + local.x] = 1

	var origin := chunk * size
	for y in size:
		for x in size:
			if dirt[y * size + x] == 0:
				_ground.set_cell(origin + Vector2i(x, y), SRC_GRASS, Vector2i.ZERO)
			else:
				var mask := _dirt_neighbor_mask(dirt, size, x, y)
				_ground.set_cell(origin + Vector2i(x, y), SRC_PLAINS, _dirt_tile_for_mask(mask))
	return dirt


## Neighbor bits: 1=N, 2=E, 4=S, 8=W.
func _dirt_neighbor_mask(dirt: PackedByteArray, size: int, x: int, y: int) -> int:
	var mask := 0
	if y > 0 and dirt[(y - 1) * size + x] == 1:
		mask |= 1
	if x < size - 1 and dirt[y * size + x + 1] == 1:
		mask |= 2
	if y < size - 1 and dirt[(y + 1) * size + x] == 1:
		mask |= 4
	if x > 0 and dirt[y * size + x - 1] == 1:
		mask |= 8
	return mask


func _dirt_tile_for_mask(mask: int) -> Vector2i:
	match mask:
		15:
			return DIRT_CENTER
		14:
			return DIRT_EDGE_TOP
		11:
			return DIRT_EDGE_BOTTOM
		7:
			return DIRT_EDGE_LEFT
		13:
			return DIRT_EDGE_RIGHT
		6:
			return DIRT_CORNER_TOP_LEFT
		12:
			return DIRT_CORNER_TOP_RIGHT
		3:
			return DIRT_CORNER_BOTTOM_LEFT
		9:
			return DIRT_CORNER_BOTTOM_RIGHT
		0:
			return DIRT_ISOLATED
		_:
			# Ambiguous strips without a dedicated tile degrade to an edge.
			if mask & 1 == 0:
				return DIRT_EDGE_TOP
			if mask & 4 == 0:
				return DIRT_EDGE_BOTTOM
			if mask & 8 == 0:
				return DIRT_EDGE_LEFT
			return DIRT_EDGE_RIGHT


func _paint_details(chunk: Vector2i, rng: RandomNumberGenerator, dirt: PackedByteArray) -> void:
	var size := config.chunk_size
	var origin := chunk * size
	for y in size:
		for x in size:
			var roll := rng.randf()
			if dirt[y * size + x] == 1:
				if roll < config.dirt_detail_tile_chance:
					_detail.set_cell(origin + Vector2i(x, y), SRC_DECOR, DIRT_DETAILS[rng.randi_range(0, DIRT_DETAILS.size() - 1)])
			elif roll < config.detail_tile_chance:
				_detail.set_cell(origin + Vector2i(x, y), SRC_DECOR, GRASS_DETAILS[rng.randi_range(0, GRASS_DETAILS.size() - 1)])


func _place_props(chunk: Vector2i, rng: RandomNumberGenerator, occupied: PackedByteArray) -> void:
	var size := config.chunk_size
	var origin := chunk * size
	var total_weight := 0.0
	for prop in config.props:
		total_weight += prop.weight

	for i in config.prop_attempts:
		if total_weight <= 0.0:
			return
		var prop := _pick_prop(rng, total_weight)
		# Full prop footprint must stay inside the chunk so occupancy
		# bookkeeping never crosses chunk borders.
		var max_x := size - prop.size_in_atlas.x - 1
		var max_y := size - prop.size_in_atlas.y - 1
		if max_x < 1 or max_y < 1:
			continue
		var local := Vector2i(rng.randi_range(1, max_x), rng.randi_range(1, max_y))
		if not _footprint_free(occupied, size, local, prop.size_in_atlas):
			continue
		_props.set_cell(origin + local, SRC_OBJECTS, prop.atlas_coords)
		_mark_footprint(occupied, size, local, prop.size_in_atlas)


func _pick_prop(rng: RandomNumberGenerator, total_weight: float) -> PropSpawn:
	var roll := rng.randf() * total_weight
	for prop in config.props:
		roll -= prop.weight
		if roll <= 0.0:
			return prop
	return config.props[0]


func _footprint_free(occupied: PackedByteArray, size: int, local: Vector2i, extent: Vector2i) -> bool:
	for y in extent.y:
		for x in extent.x:
			var index := (local.y + y) * size + local.x + x
			if occupied[index] != CELL_FREE:
				return false
	return true


func _mark_footprint(occupied: PackedByteArray, size: int, local: Vector2i, extent: Vector2i) -> void:
	for y in extent.y:
		for x in extent.x:
			occupied[(local.y + y) * size + local.x + x] = CELL_BLOCKED
