extends SceneTree

## One-time dev tool: generates every data resource the survival mode needs
## (tileset, difficulty curve, map config, enemy definitions, upgrades) as
## .tres files under res://data/. Run with:
##   godot --headless -s tools/generate_survival_data.gd
##
## Re-running overwrites hand tuning in those files, so only use it to
## (re)bootstrap the defaults. After that, balance by editing the .tres.

const EnemyDefScript := preload("res://scripts/enemy_definition.gd")
const UpgradeDefScript := preload("res://scripts/upgrade_definition.gd")
const StatEffectScript := preload("res://scripts/stat_effect.gd")
const DifficultyScript := preload("res://scripts/difficulty_config.gd")
const MapConfigScript := preload("res://scripts/map_generation_config.gd")
const PropSpawnScript := preload("res://scripts/prop_spawn.gd")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/tileset")
	DirAccess.make_dir_recursive_absolute("res://data/difficulty")
	DirAccess.make_dir_recursive_absolute("res://data/map")
	DirAccess.make_dir_recursive_absolute("res://data/enemies")
	DirAccess.make_dir_recursive_absolute("res://data/upgrades")
	_save_tileset()
	_save_difficulty()
	_save_map_config()
	_save_enemies()
	_save_upgrades()
	print("generate_survival_data: done")
	quit(0)


func _save(path: String, resource: Resource) -> void:
	var err := ResourceSaver.save(resource, path)
	if err != OK:
		push_error("Failed to save %s: %s" % [path, err])
	else:
		print("saved ", path)


# --- Tileset ---------------------------------------------------------------

## Tile atlas coordinates for the plains source, matching the tiles the
## legacy world scene already uses (free-tier assets only).
const PLAINS_TILES := [
	Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0),
	Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1),
	Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2),
	Vector2i(0, 3),
	Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4),
	Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5),
	Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6),
]

## Props with the collision polygons and y-sort origins copied verbatim from
## the legacy world tileset, so generated props behave exactly like hand
## placed ones.
var PROP_PHYSICS := {
	Vector2i(0, 5): {"size": Vector2i(3, 4), "y_sort": 20, "polygon": PackedVector2Array([Vector2(-10.8334, 13.3825), Vector2(7.00988, 14.0198), Vector2(11.7893, 19.7551), Vector2(7.96577, 25.4905), Vector2(-4.77946, 25.8091), Vector2(-10.8334, 21.0296)])},
	Vector2i(6, 7): {"size": Vector2i(2, 2), "y_sort": 10, "polygon": PackedVector2Array([Vector2(-15.6129, 2.86768), Vector2(13.7011, 1.27452), Vector2(11.7893, 13.7011), Vector2(-14.3384, 13.7011)])},
	Vector2i(8, 6): {"size": Vector2i(2, 3), "y_sort": 17, "polygon": PackedVector2Array([Vector2(-5.09809, 17.2061), Vector2(5.57562, 16.9067), Vector2(5.41672, 21.9855), Vector2(-5.2159, 21.9428)])},
	Vector2i(10, 7): {"size": Vector2i(2, 2), "y_sort": 5, "polygon": PackedVector2Array([Vector2(-12.4266, -1.27452), Vector2(11.1521, -0.637262), Vector2(8, 8), Vector2(-8, 8)])},
	Vector2i(0, 0): {"size": Vector2i(1, 1), "y_sort": 4, "polygon": PackedVector2Array([Vector2(-8, 1.31983), Vector2(8, 1.59315), Vector2(1.89118, 5.04315), Vector2(-2.06311, 5.04315)])},
	Vector2i(0, 1): {"size": Vector2i(1, 1), "y_sort": 5, "polygon": PackedVector2Array([Vector2(-8, 0.31863), Vector2(8, 0.63726), Vector2(4.77946, 8), Vector2(-4.77946, 4.46083)])},
	Vector2i(5, 0): {"size": Vector2i(1, 1), "y_sort": 5, "polygon": PackedVector2Array([Vector2(-6.09153, 2.23356), Vector2(6.59916, 1.82746), Vector2(6.19306, 5.78696), Vector2(-5.78696, 5.68543)])},
}

const DECOR_TILES := [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
]


func _save_tileset() -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(16, 16)
	tileset.add_physics_layer()

	var plains := _make_atlas("res://art/tilesets/plains.png")
	for coords in PLAINS_TILES:
		plains.create_tile(coords)
	tileset.add_source(plains, 0)

	var grass := _make_atlas("res://art/tilesets/grass.png")
	grass.create_tile(Vector2i.ZERO)
	tileset.add_source(grass, 1)

	# The source must join the TileSet before physics polygons are set:
	# TileData only learns about physics layers through the TileSet.
	var objects := _make_atlas("res://art/objects/objects.png")
	tileset.add_source(objects, 2)
	for coords in PROP_PHYSICS:
		var info: Dictionary = PROP_PHYSICS[coords]
		objects.create_tile(coords, info.size)
		var tile_data := objects.get_tile_data(coords, 0)
		tile_data.y_sort_origin = info.y_sort
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, info.polygon)

	var decor := _make_atlas("res://art/tilesets/decor_16x16.png")
	for coords in DECOR_TILES:
		decor.create_tile(coords)
	tileset.add_source(decor, 3)

	_save("res://data/tileset/survival_tileset.tres", tileset)


func _make_atlas(texture_path: String) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = load(texture_path)
	source.texture_region_size = Vector2i(16, 16)
	return source


# --- Difficulty ------------------------------------------------------------

func _save_difficulty() -> void:
	var config: Resource = DifficultyScript.new()
	_save("res://data/difficulty/standard.tres", config)


# --- Map config ------------------------------------------------------------

func _save_map_config() -> void:
	var config: Resource = MapConfigScript.new()
	var props := [
		PropSpawnScript.new(Vector2i(0, 5), Vector2i(3, 4), 2.0),  # big tree
		PropSpawnScript.new(Vector2i(6, 7), Vector2i(2, 2), 2.0),  # rock
		PropSpawnScript.new(Vector2i(8, 6), Vector2i(2, 3), 3.0),  # bushes
		PropSpawnScript.new(Vector2i(10, 7), Vector2i(2, 2), 2.0), # rock 2
		PropSpawnScript.new(Vector2i(0, 0), Vector2i(1, 1), 2.0),  # stone
		PropSpawnScript.new(Vector2i(0, 1), Vector2i(1, 1), 2.0),  # stone 2
		PropSpawnScript.new(Vector2i(5, 0), Vector2i(1, 1), 2.0),  # stump
	]
	for prop in props:
		config.props.append(prop)
	_save("res://data/map/fields.tres", config)


# --- Enemies ---------------------------------------------------------------

func _save_enemies() -> void:
	var defs := [
		["slime_blue", "Slime", 20.0, 40.0, 10.0, 1, 1.0, Color.WHITE, 0.0, 10.0],
		["slime_green", "Swift Slime", 12.0, 65.0, 8.0, 2, 0.85, Color(0.55, 1.0, 0.5), 60.0, 6.0],
		["slime_red", "Brute Slime", 45.0, 35.0, 14.0, 3, 1.25, Color(1.0, 0.45, 0.4), 120.0, 5.0],
		["slime_royal", "Royal Slime", 140.0, 30.0, 20.0, 10, 1.7, Color(0.75, 0.4, 1.0), 240.0, 2.0],
	]
	for d in defs:
		var def: Resource = EnemyDefScript.new()
		def.id = StringName(d[0])
		def.display_name = d[1]
		def.max_health = d[2]
		def.move_speed = d[3]
		def.contact_damage = d[4]
		def.exp_value = d[5]
		def.scale = d[6]
		def.tint = d[7]
		def.unlock_time = d[8]
		def.weight = d[9]
		_save("res://data/enemies/%s.tres" % d[0], def)


# --- Upgrades --------------------------------------------------------------

func _save_upgrades() -> void:
	var upgrades := [
		["damage_mult", "Sharp Edge", "Your strikes hit 25% harder.", 8, [[&"damage", 1, 1.25]]],
		["damage_add", "Brutality", "+8 flat damage per swing.", 5, [[&"damage", 0, 8.0]]],
		["attack_speed", "Quick Hands", "Attack 20% faster.", 8, [[&"attack_speed", 1, 1.2]]],
		["max_health", "Vitality", "+25 max health (and heal for it).", 8, [[&"max_health", 0, 25.0]]],
		["move_speed", "Swift Boots", "Move 12% faster.", 6, [[&"move_speed", 1, 1.12]]],
		["pickup_radius", "Magnetism", "EXP gems fly to you from 30% farther.", 6, [[&"pickup_radius", 1, 1.3]]],
		["health_regen", "Regeneration", "Recover 2 extra health per second.", 5, [[&"health_regen", 0, 2.0]]],
		["exp_gain", "Wisdom", "Gain 20% more EXP from gems.", 5, [[&"exp_gain", 1, 1.2]]],
	]
	for u in upgrades:
		var def: Resource = UpgradeDefScript.new()
		def.id = StringName(u[0])
		def.display_name = u[1]
		def.description = u[2]
		def.max_applications = u[3]
		for e in u[4]:
			def.effects.append(StatEffectScript.new(e[0], e[1], e[2]))
		_save("res://data/upgrades/%s.tres" % u[0], def)
