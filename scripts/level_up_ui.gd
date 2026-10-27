extends CanvasLayer

## Level-up overlay: three stylized RPG deck cards for weapons and passives.
## Lives on PROCESS_MODE_WHEN_PAUSED, so gameplay is frozen while open.

signal upgrade_selected(option: Variant)

const HOTKEYS := [KEY_1, KEY_2, KEY_3]

var is_open := false
var _options: Array = []

@onready var _buttons: Array[Button] = [%Option1, %Option2, %Option3]


func _ready() -> void:
	visible = false
	var main_panel: PanelContainer = get_node_or_null("Center/Panel")
	if main_panel != null:
		var bg_box := StyleBoxFlat.new()
		bg_box.bg_color = Color(0.05, 0.06, 0.09, 0.94)
		bg_box.border_color = Color(0.32, 0.35, 0.48, 0.85)
		bg_box.set_border_width_all(2)
		bg_box.set_corner_radius_all(16)
		bg_box.shadow_color = Color(0, 0, 0, 0.65)
		bg_box.shadow_size = 20
		main_panel.add_theme_stylebox_override("panel", bg_box)
	for i in _buttons.size():
		var btn := _buttons[i]
		btn.pressed.connect(_on_option_pressed.bind(i))
		btn.mouse_entered.connect(_on_card_mouse_entered.bind(btn))
		btn.mouse_exited.connect(_on_card_mouse_exited.bind(btn))
		_ensure_card_nodes(btn, i)


func open(options: Array) -> void:
	_options = options
	is_open = true
	visible = true
	for i in _buttons.size():
		var button := _buttons[i]
		if i < options.size():
			_fill_option(button, options[i], i)
			button.visible = true
			button.pivot_offset = button.custom_minimum_size * 0.5
			button.scale = Vector2(0.88, 0.88)
			var tw := create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(button, "scale", Vector2.ONE, 0.2 + i * 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			button.visible = false
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func _on_card_mouse_entered(button: Button) -> void:
	button.pivot_offset = button.size * 0.5
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(button, "scale", Vector2(1.04, 1.04), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_card_mouse_exited(button: Button) -> void:
	button.pivot_offset = button.size * 0.5
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func close() -> void:
	is_open = false
	visible = false
	_options = []


func _ensure_card_nodes(button: Button, index: int) -> void:
	if button.has_node("CardRoot"):
		return
	button.text = ""
	button.icon = null
	button.custom_minimum_size = Vector2(235, 275)

	var margin := MarginContainer.new()
	margin.name = "CardRoot"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	button.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# 1. Rarity Header Badge
	var rarity_lbl := Label.new()
	rarity_lbl.name = "RarityLabel"
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rarity_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(rarity_lbl)

	# 2. Icon Frame Center
	var icon_center := CenterContainer.new()
	icon_center.name = "IconCenter"
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_center)

	var icon_frame := PanelContainer.new()
	icon_frame.name = "IconFrame"
	icon_frame.custom_minimum_size = Vector2(68, 68)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.add_child(icon_frame)

	var tex_rect := TextureRect.new()
	tex_rect.name = "IconTexture"
	tex_rect.custom_minimum_size = Vector2(54, 54)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(tex_rect)

	var passive_glyph := Label.new()
	passive_glyph.name = "PassiveGlyph"
	passive_glyph.text = "✦"
	passive_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	passive_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	passive_glyph.add_theme_font_size_override("font_size", 32)
	passive_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(passive_glyph)

	# 3. Title Label
	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.add_theme_font_size_override("font_size", 17)
	vbox.add_child(title_lbl)

	# 4. Category Tag
	var cat_lbl := Label.new()
	cat_lbl.name = "CategoryLabel"
	cat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cat_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(cat_lbl)

	# 5. Divider
	var sep := HSeparator.new()
	sep.name = "Divider"
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	# 6. Concise Description
	var desc_lbl := Label.new()
	desc_lbl.name = "DescLabel"
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(desc_lbl)

	# 7. Hotkey Footer
	var key_lbl := Label.new()
	key_lbl.name = "KeyLabel"
	key_lbl.text = "[ %d ]" % (index + 1)
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_lbl.add_theme_font_size_override("font_size", 11)
	key_lbl.add_theme_color_override("font_color", Color(0.55, 0.58, 0.68, 0.85))
	vbox.add_child(key_lbl)


func _fill_option(button: Button, option: Variant, index: int) -> void:
	_ensure_card_nodes(button, index)
	button.text = ""
	button.icon = null

	var vbox: VBoxContainer = button.get_node("CardRoot/VBox")
	var rarity_lbl: Label = vbox.get_node("RarityLabel")
	var icon_frame: PanelContainer = vbox.get_node("IconCenter/IconFrame")
	var tex_rect: TextureRect = icon_frame.get_node("IconTexture")
	var passive_glyph: Label = icon_frame.get_node("PassiveGlyph")
	var title_lbl: Label = vbox.get_node("TitleLabel")
	var cat_lbl: Label = vbox.get_node("CategoryLabel")
	var desc_lbl: Label = vbox.get_node("DescLabel")

	var r_col := Color(0.85, 0.85, 0.9, 1.0)

	if option is WeaponUpgradeOption:
		r_col = option.rarity_color
		rarity_lbl.text = "★ %s • x%.1f ★" % [option.rarity_name.to_upper(), option.multiplier]
		rarity_lbl.add_theme_color_override("font_color", r_col)

		title_lbl.text = option.display_name
		title_lbl.add_theme_color_override("font_color", Color.WHITE)

		cat_lbl.text = option.category
		cat_lbl.add_theme_color_override("font_color", r_col.lightened(0.35))

		desc_lbl.text = option.description
		desc_lbl.add_theme_color_override("font_color", Color(0.88, 0.90, 0.95, 1.0))

		if option.icon != null:
			tex_rect.texture = option.icon
			tex_rect.visible = true
			passive_glyph.visible = false
		else:
			tex_rect.texture = null
			tex_rect.visible = false
			passive_glyph.visible = true
			passive_glyph.add_theme_color_override("font_color", r_col)
	elif option is UpgradeDefinition:
		rarity_lbl.text = "★ MEJORA ★"
		rarity_lbl.add_theme_color_override("font_color", r_col)
		title_lbl.text = option.display_name
		cat_lbl.text = "PASIVA"
		desc_lbl.text = option.description
		tex_rect.visible = false
		passive_glyph.visible = true
		passive_glyph.add_theme_color_override("font_color", r_col)

	# Frame style around the weapon icon
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	frame_style.border_color = r_col
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(8)
	frame_style.content_margin_left = 6
	frame_style.content_margin_right = 6
	frame_style.content_margin_top = 6
	frame_style.content_margin_bottom = 6
	icon_frame.add_theme_stylebox_override("panel", frame_style)

	# Outer card style
	var card_box := StyleBoxFlat.new()
	card_box.bg_color = Color(0.09, 0.10, 0.15, 0.96)
	card_box.border_color = r_col
	card_box.set_border_width_all(3)
	card_box.set_corner_radius_all(12)
	card_box.shadow_color = Color(r_col.r, r_col.g, r_col.b, 0.22)
	card_box.shadow_size = 8

	var hover_box := card_box.duplicate()
	hover_box.bg_color = Color(0.14, 0.16, 0.24, 0.99)
	hover_box.border_color = r_col.lightened(0.3)
	hover_box.set_border_width_all(4)
	hover_box.shadow_color = Color(r_col.r, r_col.g, r_col.b, 0.45)
	hover_box.shadow_size = 12

	button.add_theme_stylebox_override("normal", card_box)
	button.add_theme_stylebox_override("hover", hover_box)
	button.add_theme_stylebox_override("focus", hover_box)


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
