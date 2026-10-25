extends CanvasLayer

## Level-up overlay: exactly three randomized upgrade choices. Lives on
## PROCESS_MODE_WHEN_PAUSED, so gameplay is fully frozen while it is open
## and its input can never collide with the player's.
##
## Selection works by mouse, gamepad/keyboard focus (arrows + accept), and
## the 1/2/3 hotkeys.

signal upgrade_selected(upgrade: UpgradeDefinition)

const HOTKEYS := [KEY_1, KEY_2, KEY_3]

var is_open := false
var _options: Array = []

@onready var _buttons: Array[Button] = [%Option1, %Option2, %Option3]


func _ready() -> void:
	visible = false
	for i in _buttons.size():
		_buttons[i].pressed.connect(_on_option_pressed.bind(i))


func open(options: Array) -> void:
	_options = options
	is_open = true
	visible = true
	for i in _buttons.size():
		var button := _buttons[i]
		if i < options.size():
			_fill_option(button, options[i])
			button.visible = true
		else:
			button.visible = false
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func close() -> void:
	is_open = false
	visible = false
	_options = []


func _fill_option(button: Button, upgrade: UpgradeDefinition) -> void:
	button.text = "%s\n\n%s" % [upgrade.display_name, upgrade.description]


func _on_option_pressed(index: int) -> void:
	if not is_open or index >= _options.size():
		return
	upgrade_selected.emit(_options[index])


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		var index := HOTKEYS.find(key)
		if index != -1:
			_on_option_pressed(index)
