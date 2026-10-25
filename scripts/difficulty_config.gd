class_name DifficultyConfig
extends Resource

## Every number that shapes how a survival run escalates, plus the leveling
## curve. Tuning a run means editing this resource, not the spawner.

@export_group("Spawn cadence")
## Seconds between spawn batches at the start of the run.
@export var spawn_interval_start: float = 1.6
## Lower bound for the spawn interval, however long the run lasts.
@export var spawn_interval_min: float = 0.25
## Interval removed from spawn_interval_start per elapsed minute.
@export var spawn_interval_decay_per_minute: float = 0.35

@export_group("Spawn volume")
@export var batch_size_start: int = 1
## Extra enemies per batch for every elapsed minute.
@export var batch_size_add_per_minute: float = 0.5
@export var batch_size_max: int = 8
## Hard ceiling on live enemies regardless of player performance.
@export var max_alive_start: int = 40
@export var max_alive_add_per_minute: float = 12.0
@export var max_alive_max: int = 220
## Safety valve: at most this many enemies instantiated in one spawn tick,
## so a burst never causes a frame spike.
@export var max_spawns_per_tick: int = 6

@export_group("Enemy scaling")
## Health multiplier gained per elapsed minute (linear).
@export var health_scale_per_minute: float = 0.10
@export var speed_scale_per_minute: float = 0.015
@export var speed_scale_max: float = 1.6
@export var exp_scale_per_minute: float = 0.05

@export_group("Spawning geometry")
## Enemies appear on a ring around the player, between these radii
## (project view is ~144 px half-width at 4x zoom, so both are off-screen).
@export var spawn_radius_min: float = 260.0
@export var spawn_radius_max: float = 340.0
## Enemies farther than this from the player are silently recycled.
@export var despawn_radius: float = 520.0

@export_group("Leveling")
## EXP needed to go from level n to n+1 = exp_base * exp_growth^(n-1).
@export var exp_base: float = 5.0
@export var exp_growth: float = 1.35


func spawn_interval_at(minutes: float) -> float:
	return maxf(spawn_interval_min, spawn_interval_start - spawn_interval_decay_per_minute * minutes)


func batch_size_at(minutes: float) -> int:
	return clampi(batch_size_start + int(batch_size_add_per_minute * minutes), 1, batch_size_max)


func max_alive_at(minutes: float) -> int:
	return clampi(max_alive_start + int(max_alive_add_per_minute * minutes), 1, max_alive_max)


func health_scale_at(minutes: float) -> float:
	return 1.0 + health_scale_per_minute * minutes


func speed_scale_at(minutes: float) -> float:
	return minf(1.0 + speed_scale_per_minute * minutes, speed_scale_max)


func exp_scale_at(minutes: float) -> float:
	return 1.0 + exp_scale_per_minute * minutes


func exp_for_level(level: int) -> int:
	return maxi(1, roundi(exp_base * pow(exp_growth, level - 1)))
