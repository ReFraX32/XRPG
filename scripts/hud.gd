extends CanvasLayer

## Modern, polished in-game HUD with smooth lerped meters,
## digital clock display, kill/enemy badges, player health bar,
## and a built-in escape pause menu.

var _director: RunDirector
var _player: Node2D

@onready var _exp_bar: ProgressBar = %ExpBar
@onready var _level_label: Label = %LevelLabel
@onready var _time_label: Label = %TimeLabel
@onready var _kills_label: Label = %KillsLabel
@onready var _enemies_label: Label = %EnemiesLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _exp_val_label: Label = %ExpValueLabel

@onready var _pause_overlay: ColorRect = %PauseOverlay
@onready var _resume_btn: Button = %ResumeBtn
@onready var _restart_btn: Button = %RestartBtn
@onready var _menu_btn: Button = %MenuBtn

var _target_exp: float = 0.0
var _current_exp_display: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_styles()
	
	_pause_overlay.visible = false
	_resume_btn.pressed.connect(_on_resume_pressed)
	_restart_btn.pressed.connect(_on_restart_pressed)
	_menu_btn.pressed.connect(_on_menu_pressed)


func setup(director: RunDirector) -> void:
	_director = director
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if _director != null and not _director.game_over:
			# If level up UI is currently open, don't override its pause
			var level_up: CanvasLayer = _director.get_node_or_null("%LevelUpUI")
			if level_up != null and "is_open" in level_up and level_up.is_open:
				return
			_toggle_pause()


func _toggle_pause() -> void:
	var new_paused := not get_tree().paused
	get_tree().paused = new_paused
	_pause_overlay.visible = new_paused
	if new_paused:
		_resume_btn.grab_focus()


func _on_resume_pressed() -> void:
	get_tree().paused = false
	_pause_overlay.visible = false


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _process(delta: float) -> void:
	if _director == null:
		return
	var difficulty := _director.difficulty
	var max_exp: float = float(difficulty.exp_for_level(_director.level))
	_exp_bar.max_value = max_exp
	_target_exp = float(_director.exp_current)
	_current_exp_display = lerpf(_current_exp_display, _target_exp, clampf(delta * 12.0, 0.0, 1.0))
	_exp_bar.value = _current_exp_display
	
	_level_label.text = "LV %d" % _director.level
	_time_label.text = _format_time(_director.run_time)
	_kills_label.text = "💀 %d" % _director.kills
	if _director.spawner != null:
		_enemies_label.text = "👾 %d" % _director.spawner.total_alive()
	_exp_val_label.text = "%d / %d EXP" % [_director.exp_current, int(max_exp)]
	
	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			_player = players[0]
			
	if _player != null and is_instance_valid(_player):
		var current_hp: float = _player.health
		var max_hp: float = 100.0
		if "stats" in _player and _player.stats != null:
			max_hp = _player.stats.get_stat(&"max_health")
		_hp_bar.max_value = max_hp
		_hp_bar.value = current_hp
		_hp_label.text = "❤ %d / %d" % [maxi(0, roundi(current_hp)), roundi(max_hp)]


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [floori(total / 60.0), total % 60]


func _setup_styles() -> void:
	# Top bar panel
	var top_panel: PanelContainer = %TopPanel
	var top_box := StyleBoxFlat.new()
	top_box.bg_color = Color(0.06, 0.08, 0.12, 0.88)
	top_box.border_color = Color(0.2, 0.28, 0.42, 0.8)
	top_box.set_border_width_all(1)
	top_box.set_corner_radius_all(10)
	top_box.shadow_color = Color(0, 0, 0, 0.5)
	top_box.shadow_size = 8
	top_panel.add_theme_stylebox_override("panel", top_box)
	
	# Badges (Level, Timer, Kills, Enemies)
	var badge_boxes: Array[PanelContainer] = [%LevelBadge, %TimerPanel, %KillsBadge, %EnemiesBadge]
	for p in badge_boxes:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.04, 0.07, 0.75)
		sb.border_color = Color(0.25, 0.32, 0.45, 0.6)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		p.add_theme_stylebox_override("panel", sb)
		
	# EXP bar
	var exp_bg := StyleBoxFlat.new()
	exp_bg.bg_color = Color(0.04, 0.05, 0.08, 0.9)
	var exp_fill := StyleBoxFlat.new()
	exp_fill.bg_color = Color(0.18, 0.72, 1.0, 0.95)
	exp_fill.set_corner_radius_all(3)
	_exp_bar.add_theme_stylebox_override("background", exp_bg)
	_exp_bar.add_theme_stylebox_override("fill", exp_fill)

	# HP bar
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.12, 0.04, 0.04, 0.85)
	hp_bg.set_corner_radius_all(4)
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.9, 0.2, 0.25, 0.95)
	hp_fill.set_corner_radius_all(4)
	_hp_bar.add_theme_stylebox_override("background", hp_bg)
	_hp_bar.add_theme_stylebox_override("fill", hp_fill)

	# Pause Menu Panel
	var pause_panel: PanelContainer = %PausePanel
	var p_box := StyleBoxFlat.new()
	p_box.bg_color = Color(0.07, 0.09, 0.14, 0.96)
	p_box.border_color = Color(0.35, 0.42, 0.6, 0.9)
	p_box.set_border_width_all(2)
	p_box.set_corner_radius_all(12)
	p_box.shadow_color = Color(0, 0, 0, 0.7)
	p_box.shadow_size = 24
	pause_panel.add_theme_stylebox_override("panel", p_box)
