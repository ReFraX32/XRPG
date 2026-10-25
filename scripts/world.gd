extends Node

## Legacy hand-made world. The player now announces death on the event bus;
## this scene keeps its original behavior (reload on death) by listening.


func _ready():
	GameEvents.player_died.connect(_on_player_died)


func _on_player_died():
	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()
