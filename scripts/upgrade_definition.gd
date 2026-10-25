class_name UpgradeDefinition
extends Resource

## Data-only description of one level-up choice.
## Instances live in res://data/upgrades/*.tres and are discovered by the run
## director at startup, so adding an upgrade never touches gameplay code.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## How many times this upgrade may be picked in a single run.
@export var max_applications: int = 5
@export var effects: Array[StatEffect] = []
