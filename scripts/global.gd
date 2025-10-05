extends Node

var player_current_attack = false

var current_scene = "world"
var transition_scene = false

var player_exit_cliffside_posx = 6
var player_exit_cliffside_posy = 29
var player_start_posx = 71
var player_start_posy = 57

var game_first_loadin = true

func finish_changescenes():
	if transition_scene:
		transition_scene = false
		if current_scene == "world":
			current_scene = "cliffside"
		else:
			current_scene = "world"
