extends Control

## Main menu screen for XRPG Survivors.
## Provides game launch, Weapon/Rarity codex, Bestiary modal,
## Controls guide, and Quit options with responsive button animations.

@onready var _play_btn: Button = %PlayBtn
@onready var _weapons_btn: Button = %WeaponsBtn
@onready var _bestiary_btn: Button = %BestiaryBtn
@onready var _controls_btn: Button = %ControlsBtn
@onready var _quit_btn: Button = %QuitBtn

@onready var _weapons_modal: Control = %WeaponsModal
@onready var _bestiary_modal: Control = %BestiaryModal
@onready var _controls_modal: Control = %ControlsModal

@onready var _close_weapons_btn: Button = %CloseWeaponsBtn
@onready var _close_bestiary_btn: Button = %CloseBestiaryBtn
@onready var _close_controls_btn: Button = %CloseControlsBtn

@onready var _title_label: Label = %TitleLabel

var _time: float = 0.0


func _ready() -> void:
	_setup_styles()
	_connect_signals()
	_setup_weapon_cards()
	_setup_bestiary_cards()
	
	_play_btn.grab_focus()


func _process(delta: float) -> void:
	_time += delta
	# Subtle floating oscillation for title
	if _title_label != null:
		_title_label.position.y = 48.0 + sin(_time * 2.2) * 4.0


func _connect_signals() -> void:
	_play_btn.pressed.connect(_on_play_pressed)
	_weapons_btn.pressed.connect(_on_weapons_pressed)
	_bestiary_btn.pressed.connect(_on_bestiary_pressed)
	_controls_btn.pressed.connect(_on_controls_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)

	_close_weapons_btn.pressed.connect(func() -> void: _close_modal(_weapons_modal))
	_close_bestiary_btn.pressed.connect(func() -> void: _close_modal(_bestiary_modal))
	_close_controls_btn.pressed.connect(func() -> void: _close_modal(_controls_modal))

	var main_buttons: Array[Button] = [_play_btn, _weapons_btn, _bestiary_btn, _controls_btn, _quit_btn]
	for btn in main_buttons:
		btn.mouse_entered.connect(_on_button_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_button_hover.bind(btn, false))


func _on_button_hover(btn: Button, is_hover: bool) -> void:
	btn.pivot_offset = btn.size * 0.5
	var target_scale: Vector2 = Vector2(1.05, 1.05) if is_hover else Vector2.ONE
	var tw := create_tween()
	tw.tween_property(btn, "scale", target_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/survival.tscn")


func _on_weapons_pressed() -> void:
	_open_modal(_weapons_modal)


func _on_bestiary_pressed() -> void:
	_open_modal(_bestiary_modal)


func _on_controls_pressed() -> void:
	_open_modal(_controls_modal)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _open_modal(modal: Control) -> void:
	modal.visible = true
	modal.modulate.a = 0.0
	var panel: Control = modal.get_node_or_null("Center/Panel")
	if panel != null:
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2(0.92, 0.92)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(modal, "modulate:a", 1.0, 0.15)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		modal.modulate.a = 1.0


func _close_modal(modal: Control) -> void:
	var tw := create_tween()
	tw.tween_property(modal, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func() -> void: modal.visible = false)


func _setup_styles() -> void:
	# Play Button Special Style
	var play_box := StyleBoxFlat.new()
	play_box.bg_color = Color(0.12, 0.45, 0.32, 0.95)
	play_box.border_color = Color(0.3, 0.95, 0.65, 1.0)
	play_box.set_border_width_all(2)
	play_box.set_corner_radius_all(10)
	play_box.shadow_color = Color(0.2, 0.8, 0.5, 0.4)
	play_box.shadow_size = 12
	_play_btn.add_theme_stylebox_override("normal", play_box)

	var play_hover := play_box.duplicate()
	play_hover.bg_color = Color(0.16, 0.60, 0.42, 1.0)
	play_hover.shadow_size = 18
	_play_btn.add_theme_stylebox_override("hover", play_hover)
	_play_btn.add_theme_stylebox_override("focus", play_hover)

	# Regular Buttons Style
	var reg_buttons: Array[Button] = [_weapons_btn, _bestiary_btn, _controls_btn, _quit_btn]
	for btn in reg_buttons:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.10, 0.16, 0.9)
		sb.border_color = Color(0.28, 0.35, 0.52, 0.8)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(8)
		sb.shadow_color = Color(0, 0, 0, 0.4)
		sb.shadow_size = 6
		btn.add_theme_stylebox_override("normal", sb)

		var sb_hover := sb.duplicate()
		sb_hover.bg_color = Color(0.14, 0.18, 0.28, 0.98)
		sb_hover.border_color = Color(0.45, 0.65, 0.95, 1.0)
		sb_hover.shadow_color = Color(0.2, 0.4, 0.8, 0.3)
		sb_hover.shadow_size = 10
		btn.add_theme_stylebox_override("hover", sb_hover)
		btn.add_theme_stylebox_override("focus", sb_hover)

	# Modal panels styling
	var modal_panels: Array[PanelContainer] = [
		_weapons_modal.get_node("Center/Panel"),
		_bestiary_modal.get_node("Center/Panel"),
		_controls_modal.get_node("Center/Panel"),
	]
	for p in modal_panels:
		var mp_sb := StyleBoxFlat.new()
		mp_sb.bg_color = Color(0.06, 0.07, 0.11, 0.98)
		mp_sb.border_color = Color(0.32, 0.38, 0.55, 0.85)
		mp_sb.set_border_width_all(2)
		mp_sb.set_corner_radius_all(14)
		mp_sb.shadow_color = Color(0, 0, 0, 0.7)
		mp_sb.shadow_size = 24
		p.add_theme_stylebox_override("panel", mp_sb)

	# Close modal buttons styling
	var close_buttons: Array[Button] = [_close_weapons_btn, _close_bestiary_btn, _close_controls_btn]
	for c_btn in close_buttons:
		var cb_sb := StyleBoxFlat.new()
		cb_sb.bg_color = Color(0.18, 0.22, 0.32, 0.9)
		cb_sb.border_color = Color(0.4, 0.5, 0.7, 0.8)
		cb_sb.set_border_width_all(1)
		cb_sb.set_corner_radius_all(6)
		c_btn.add_theme_stylebox_override("normal", cb_sb)
		var cb_hover := cb_sb.duplicate()
		cb_hover.bg_color = Color(0.25, 0.32, 0.45, 1.0)
		c_btn.add_theme_stylebox_override("hover", cb_hover)
		c_btn.add_theme_stylebox_override("focus", cb_hover)


func _setup_weapon_cards() -> void:
	var container: Container = %WeaponCardsContainer
	if container == null or container.get_child_count() > 0:
		return

	var weapons_data := [
		{
			"name": "AURA RADIANTE",
			"cat": "Área & Ralentización",
			"icon": "res://art/weapons/aura_icon.png",
			"color": Color(0.3, 0.85, 1.0),
			"desc": "Campo estático que daña a todo en su radio.\n• Épica: Ralentiza 20%.\n• Legendaria: Onda de choque expansiva cada 5s.\n• Mítica: Detonación en cadena al morir."
		},
		{
			"name": "DADOS DEL DESTINO",
			"cat": "Suerte & Burst",
			"icon": "res://art/weapons/dice_icon.png",
			"color": Color(1.0, 0.45, 0.35),
			"desc": "Lanza dados con daño aleatorio (1 a 6).\n• Épica: Rango 3 a 6 + boost de vel.\n• Legendaria: Cada 6 aumenta prob. de crítico.\n• Mítica: 3 dados simultáneos (18 = pantalla limpia)."
		},
		{
			"name": "AEGIS SAGRADO",
			"cat": "Defensa & Contragolpe",
			"icon": "res://art/weapons/aegis_icon.png",
			"color": Color(1.0, 0.82, 0.25),
			"desc": "Escudos protectores orbitantes.\n• Épica: 3 cargas + empuje.\n• Legendaria: Regenera vida al romperse.\n• Mítica: Escudos continuos en movimiento + explosión masiva."
		},
		{
			"name": "AGUJEROS NEGROS",
			"cat": "Singularidad & Colapso",
			"icon": "res://art/weapons/black_hole_icon.png",
			"color": Color(0.85, 0.4, 1.0),
			"desc": "Atrae a los enemigos y colapsa violentamente.\n• Épica: Mayor radio y frecuencia.\n• Legendaria: Deja mini agujeros secundarios.\n• Mítica: Absorbe proyectiles para super detonación."
		}
	]

	for data in weapons_data:
		var card := _create_info_card(data["name"], data["cat"], data["icon"], data["color"], data["desc"])
		container.add_child(card)


func _setup_bestiary_cards() -> void:
	var container: Container = %BestiaryCardsContainer
	if container == null or container.get_child_count() > 0:
		return

	var enemies_data := [
		{
			"name": "SLIMES DE LA LLANURA",
			"cat": "Horda Estándar",
			"icon": "res://art/characters/slime.png",
			"color": Color(0.35, 0.75, 1.0),
			"region": Rect2(0, 32, 32, 32),
			"desc": "La masa principal de la horda. Vienen en variantes azul, verde, roja y regia con velocidad y salud crecientes."
		},
		{
			"name": "ESPECTRO",
			"cat": "Volador Fantasmal",
			"icon": "res://art/characters/ghost.png",
			"color": Color(0.85, 0.95, 1.0),
			"region": Rect2(0, 0, 36, 36),
			"desc": "Levita sobre el terreno.\n★ HABILIDAD: Fase Etérea cada 4.5s; se vuelve translúcido, inmune a ralentización y corre un +45% más veloz."
		},
		{
			"name": "MURCIÉLAGO VAMPIRO",
			"cat": "Depredador Ágil",
			"icon": "res://art/characters/bat.png",
			"color": Color(0.95, 0.4, 0.8),
			"region": Rect2(0, 0, 40, 26),
			"desc": "Vuelo ondulante impredecible.\n★ HABILIDAD: Embestida Sónica; al acechar telegrafía en rojo y se abalanza en picada a 2.6x de velocidad."
		}
	]

	for data in enemies_data:
		var card := _create_info_card(
			data["name"], data["cat"], data["icon"], data["color"], data["desc"], data.get("region", Rect2())
		)
		container.add_child(card)


func _create_info_card(card_name: String, cat: String, icon_path: String, color: Color, desc: String, region: Rect2 = Rect2()) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(230, 280)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.13, 0.95)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(color.r, color.g, color.b, 0.25)
	sb.shadow_size = 8
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var cat_lbl := Label.new()
	cat_lbl.text = cat
	cat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_lbl.add_theme_font_size_override("font_size", 10)
	cat_lbl.add_theme_color_override("font_color", color)
	vbox.add_child(cat_lbl)

	var name_lbl := Label.new()
	name_lbl.text = card_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_lbl)

	var icon_center := CenterContainer.new()
	vbox.add_child(icon_center)

	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(56, 56)
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0.04, 0.05, 0.08, 0.9)
	isb.border_color = color.darkened(0.2)
	isb.set_border_width_all(1)
	isb.set_corner_radius_all(6)
	icon_panel.add_theme_stylebox_override("panel", isb)
	icon_center.add_child(icon_panel)

	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(44, 44)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var base_tex: Texture2D = load(icon_path)
	if base_tex != null:
		if region.size != Vector2.ZERO:
			var atlas := AtlasTexture.new()
			atlas.atlas = base_tex
			atlas.region = region
			tex_rect.texture = atlas
		else:
			tex_rect.texture = base_tex
	icon_panel.add_child(tex_rect)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95, 0.9))
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	return panel
