extends CanvasLayer

## Game-over overlay shown when the player dies. Freezes the tree so the
## horde stops chewing on the corpse, summarizes the run, and offers a
## clean restart or return to main menu. Runs on PROCESS_MODE_WHEN_PAUSED.

@onready var _panel: PanelContainer = %Panel
@onready var _summary_label: Label = %SummaryLabel
@onready var _retry_button: Button = %RetryButton
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	visible = false
	_setup_styles()
	_retry_button.pressed.connect(_on_retry_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)


func open(level: int, kills: int, run_time: float) -> void:
	var total := int(run_time)
	_summary_label.text = "Sobreviviste %02d:%02d\nNivel %d  —  %d bajas" % [
		floori(total / 60.0), total % 60, level, kills,
	]
	visible = true
	_retry_button.grab_focus()


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _setup_styles() -> void:
	var bg_box := StyleBoxFlat.new()
	bg_box.bg_color = Color(0.08, 0.04, 0.05, 0.96)
	bg_box.border_color = Color(0.7, 0.2, 0.22, 0.9)
	bg_box.set_border_width_all(2)
	bg_box.set_corner_radius_all(14)
	bg_box.shadow_color = Color(0.4, 0.05, 0.05, 0.6)
	bg_box.shadow_size = 28
	_panel.add_theme_stylebox_override("panel", bg_box)
