extends CanvasLayer

## Game-over overlay shown when the player dies. Freezes the tree so the
## horde stops chewing on the corpse, summarizes the run, and offers a
## clean restart. Runs on PROCESS_MODE_WHEN_PAUSED.

@onready var _summary_label: Label = %SummaryLabel
@onready var _retry_button: Button = %RetryButton


func _ready() -> void:
	visible = false
	_retry_button.pressed.connect(_on_retry_pressed)


func open(level: int, kills: int, run_time: float) -> void:
	var total := int(run_time)
	_summary_label.text = "You survived %02d:%02d\nLevel %d  —  %d kills" % [
		floori(total / 60.0), total % 60, level, kills,
	]
	visible = true
	_retry_button.grab_focus()


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
