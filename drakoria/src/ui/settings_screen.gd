extends ScreenBase
## Paramètres : musique, effets et vibrations indépendants ; mouvements
## réduits ; taille du texte ; langue ; sous-titres d'aide.


func build() -> void:
	header(UI.tr_key("settings.title"))
	var body := scroll_body()
	_toggle(body, "settings.music", "music_on")
	_slider(body, "settings.music_volume", "music_volume")
	_toggle(body, "settings.sfx", "sfx_on")
	_slider(body, "settings.sfx_volume", "sfx_volume")
	_toggle(body, "settings.vibration", "vibration_on")
	_toggle(body, "settings.reduced_motion", "reduced_motion", "settings.reduced_motion_help")
	_toggle(body, "settings.captions", "help_captions")
	_choice(body, "settings.text_size", "text_scale", [[1.0, "settings.text.normal"], [1.15, "settings.text.large"], [1.3, "settings.text.xlarge"]])
	_choice(body, "settings.language", "language", [["auto", "settings.lang.auto"], ["fr", "settings.lang.fr"], ["en", "settings.lang.en"]])
	body.add_child(UI.button(UI.tr_key("settings.reset"), "", "secondary", func():
		main.show_dialog(UI.tr_key("settings.reset"), UI.tr_key("settings.reset_body"), [
			{"text": UI.tr_key("settings.reset_yes"), "style": "accent", "cb": func(): Progression.reset_all()},
			{"text": UI.tr_key("common.cancel"), "style": "primary"},
		])))
	body.add_child(UI.label(UI.tr_key("settings.about"), 12, UI.INK_SOFT))


func _row(body: VBoxContainer, key: String, help_key := "") -> HBoxContainer:
	var card := UI.card()
	var h := UI.hbox(24)
	card.add_child(h)
	var v := UI.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(UI.label(UI.tr_key(key), 16, UI.INK))
	if help_key != "":
		v.add_child(UI.label(UI.tr_key(help_key), 12, UI.INK_SOFT))
	h.add_child(v)
	body.add_child(card)
	return h


func _toggle(body: VBoxContainer, key: String, setting: String, help_key := "") -> void:
	var h := _row(body, key, help_key)
	var b := UI.button("…", "", "secondary", func():
		Settings.set_value(setting, not Settings.get_value(setting))
		AudioService.play_ui("ui_toggle"))
	var refresh := func():
		var on: bool = Settings.get_value(setting)
		# État donné par le texte, pas seulement par la couleur.
		b.set_label(UI.tr_key("common.on") if on else UI.tr_key("common.off"))
		b.configure_colors(UI.TURQUOISE if on else UI.STONE, Color.WHITE if on else UI.INK)
	b.set_min(Vector2(240, UI.MIN_TOUCH))
	b.pressed.connect(refresh)
	h.add_child(b)
	refresh.call()


func _slider(body: VBoxContainer, key: String, setting: String) -> void:
	var h := _row(body, key)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = Settings.get_value(setting)
	s.custom_minimum_size = Vector2(420, UI.MIN_TOUCH)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(v): Settings.set_value(setting, float(v)))
	s.drag_ended.connect(func(_c):
		if setting == "sfx_volume":
			AudioService.play_sfx("sfx_connect"))
	h.add_child(s)


func _choice(body: VBoxContainer, key: String, setting: String, options: Array) -> void:
	var card := UI.card()
	var v := UI.vbox(18)
	card.add_child(v)
	v.add_child(UI.label(UI.tr_key(key), 16, UI.INK))
	var h := UI.hbox(18)
	for o in options:
		var value = o[0]
		var selected: bool = Settings.get_value(setting) == value
		var b := UI.button(UI.tr_key(o[1]), "check" if selected else "", "selected" if selected else "secondary", func():
			Settings.set_value(setting, value)
			if setting != "text_scale" and setting != "language":
				main.refresh())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
	v.add_child(h)
	body.add_child(card)
