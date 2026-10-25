class_name EnemyDefinition
extends Resource

## Data-only description of one enemy type. The spawner owns one object pool
## per definition; stats are injected into a shared enemy scene on spawn,
## so new enemy variants (tint/scale/stat changes) require no new scenes.

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_health: float = 20.0
@export var move_speed: float = 40.0
## Damage dealt to the player per contact tick.
@export var contact_damage: float = 10.0
@export var exp_value: int = 1
## Visual variety on the shared enemy scene (slime sheet).
@export var scale: float = 1.0
@export var tint: Color = Color.WHITE
## Seconds of run time before the spawner may pick this type.
@export var unlock_time: float = 0.0
## Relative chance of being picked while unlocked.
@export var weight: float = 1.0
