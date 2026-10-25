extends CanvasLayer

## Shown while the map generator builds the initial chunk area; tracks its
## progress and fades out the moment generation completes. Because it lives
## in the survival scene, it also covers the reload spike when the player
## retries after dying.

@export var map_generator_path: NodePath

var _map: MapGenerator
var _dots := 0
var _finished := false

@onready var _root: ColorRect = %Root
@onready var _label: Label = %LoadLabel
@onready var _progress_bar: ProgressBar = %LoadBar


func _ready() -> void:
	_map = get_node_or_null(map_generator_path) as MapGenerator
	if _map != null:
		_map.initial_build_finished.connect(_on_build_finished)
		if _map.is_initial_build_done():
			_finish()
	else:
		# No map to wait for (defensive): don't block the game.
		_finish()


func _process(_delta: float) -> void:
	_dots = (_dots + 1) % 4
	_label.text = "LOADING" + ".".repeat(_dots)
	if _map != null:
		_progress_bar.value = _map.initial_progress()


## True once the initial build finished and the fade-out ran or started.
func has_finished_load() -> bool:
	return _finished


func _on_build_finished() -> void:
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	var tween := create_tween()
	tween.tween_property(_root, "modulate", Color(1, 1, 1, 0), 0.35)
	tween.tween_callback(hide)
