class_name UIButton
extends Button
## Bouton avec icône + étiquette, cible >= 48 unités, compression de 90 ms
## et retour de 160 ms. La réponse au toucher reste immédiate.

var _content: BoxContainer
var _tween: Tween
var _label: Label
var _icon: UIIcon
var _min_override := Vector2.ZERO


func configure(text_value: String, icon_kind: String, style: String) -> void:
	focus_mode = Control.FOCUS_NONE
	var fg := UI.INK
	var bg := UI.STONE
	var units := 15.0
	match style:
		"primary":
			bg = UI.TURQUOISE; fg = Color.WHITE; units = 22.0
		"accent":
			bg = UI.CORAL; fg = Color.WHITE
		"card":
			bg = UI.CARD
		"selected":
			bg = UI.INK; fg = Color.WHITE
		"tile", "selected_tile":
			units = 13.0
	var normal := UI.box(bg, 40, bg.darkened(0.25), 4)
	normal.set_content_margin_all(0)
	var pressed_sb := normal.duplicate()
	pressed_sb.bg_color = bg.darkened(0.12)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(bg, 0.45)
	disabled.border_color = Color(bg.darkened(0.25), 0.45)
	for s in ["normal", "hover", "focus"]:
		add_theme_stylebox_override(s, normal)
	add_theme_stylebox_override("pressed", pressed_sb)
	add_theme_stylebox_override("disabled", disabled)
	_content = VBoxContainer.new() if style == "tile" or style == "selected_tile" else HBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 14)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_content)
	if icon_kind != "":
		_icon = UIIcon.new()
		_icon.kind = icon_kind
		_icon.color = fg
		var k := 78.0 if style == "primary" else 54.0
		_icon.custom_minimum_size = Vector2(k, k)
		_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_content.add_child(_icon)
	if text_value != "" or icon_kind != "":
		_label = Label.new()
		_label.visible = text_value != ""
		_label.text = text_value
		_label.add_theme_font_size_override("font_size", UI.fs(units))
		_label.add_theme_color_override("font_color", fg)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(_label)
	button_down.connect(_down)
	button_up.connect(_up)
	pressed.connect(func(): AudioService.play_ui("ui_tap"))
	_fit()


func configure_colors(bg: Color, fg: Color) -> void:
	var normal := UI.box(bg, 40, bg.darkened(0.25), 4)
	normal.set_content_margin_all(0)
	for st in ["normal", "hover", "focus", "pressed"]:
		add_theme_stylebox_override(st, normal)
	if _label: _label.add_theme_color_override("font_color", fg)
	if _icon: _icon.color = fg


func set_label(t: String) -> void:
	if _label:
		_label.text = t
		_label.visible = t != ""
		_fit()


func set_min(v: Vector2) -> void:
	_min_override = v
	_fit()


func _fit() -> void:
	## Button ignore _get_minimum_size côté script : la taille minimale est
	## donc fixée explicitement (contenu, cible tactile de 48 unités, demande).
	var m := Vector2(UI.MIN_TOUCH, UI.MIN_TOUCH)
	if _content:
		var c := _content.get_combined_minimum_size() + Vector2(60, 36)
		m = Vector2(maxf(m.x, c.x), maxf(m.y, c.y))
	custom_minimum_size = Vector2(maxf(m.x, _min_override.x), maxf(m.y, _min_override.y))


func _down() -> void:
	if Settings.reduced_motion():
		return
	pivot_offset = size / 2.0
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2(0.94, 0.94), 0.09)


func _up() -> void:
	if Settings.reduced_motion():
		scale = Vector2.ONE
		return
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
