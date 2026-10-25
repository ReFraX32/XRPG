class_name MapGenerationConfig
extends Resource

## All knobs of the procedural map. Deterministic: every chunk derives its
## RNG seed from (world_seed, chunk coords), so the same seed always builds
## the same world and chunks regenerate identically when revisited.

@export var world_seed: int = 20261024

@export_group("Chunks")
## Chunks are square, measured in tiles (16 tiles * 16 px = 256 px).
@export var chunk_size: int = 16
## Keep this many chunks of margin loaded around the player's chunk
## (view is ~18x10 tiles at 4x zoom, so 2 chunks of margin is safely off-screen).
@export var render_margin_chunks: int = 2
## Chunk construction is amortized: at most this many are generated per frame
## during steady-state streaming.
@export var chunks_built_per_frame: int = 1
## While the loading screen is up (initial area), build this many per frame
## so the world fills in fast without freezing a single frame.
@export var initial_build_chunks_per_frame: int = 6

@export_group("Terrain dressing")
## Dirt patches (walkable, decorative) attempted per chunk.
@export var dirt_patch_attempts: int = 2
@export var dirt_patch_radius_min: int = 1
@export var dirt_patch_radius_max: int = 3
## Chance per grass cell to carry a small decor detail (pebbles, flowers).
@export var detail_tile_chance: float = 0.045
## Chance per dirt cell to carry a dirt-matched decor detail.
@export var dirt_detail_tile_chance: float = 0.08

@export_group("Props")
## Prop placement attempts per chunk (attempts can be rejected by overlap).
@export var prop_attempts: int = 7
@export var props: Array[PropSpawn] = []
