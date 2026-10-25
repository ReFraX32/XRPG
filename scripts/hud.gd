extends CanvasLayer

## In-game HUD. Pure presentation: polls the run director every frame and
## pushes nothing into gameplay. Kept separate from the director so UI
## changes can never break the progression logic.

var _director: RunDirector

@onready var _exp_bar: ProgressBar = %ExpBar
@onready var _level_label: Label = %LevelLabel
@onready var _time_label: Label = %TimeLabel
@onready var _kills_label: Label = %KillsLabel
@onready var _enemies_label: Label = %EnemiesLabel


## The run director injects itself after everyone is ready.
func setup(director: RunDirector) -> void:
	_director = director


func _process(_delta: float) -> void:
	if _director == null:
		return
	var difficulty := _director.difficulty
	_exp_bar.max_value = difficulty.exp_for_level(_director.level)
	_exp_bar.value = _director.exp_current
	_level_label.text = "LV %d" % _director.level
	_time_label.text = _format_time(_director.run_time)
	_kills_label.text = "Kills: %d" % _director.kills
	if _director.spawner != null:
		_enemies_label.text = "Enemies: %d" % _director.spawner.total_alive()


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [floori(total / 60.0), total % 60]
