class_name PropSpawn
extends Resource

## One kind of scatterable prop on the generated map, pointing at a tile in
## the shared survival TileSet. Multi-tile props (trees, rocks) occupy every
## cell they cover, which also marks those cells unwalkable for spawns.

@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var size_in_atlas: Vector2i = Vector2i.ONE
@export var weight: float = 1.0


func _init(p_atlas: Vector2i = Vector2i.ZERO, p_size: Vector2i = Vector2i.ONE, p_weight: float = 1.0) -> void:
	atlas_coords = p_atlas
	size_in_atlas = p_size
	weight = p_weight
