extends Node2D

func _process(delta):
	change_scene()

func _on_cliffside_exit_point_body_entered(body):
	if body.has_method("player"):
		global.transition_scene = true

func change_scene():
	if global.transition_scene:
		if global.current_scene == "cliffside":
			get_tree().change_scene_to_file("res://scenes/world.tscn")
			global.finish_changescenes()
 
