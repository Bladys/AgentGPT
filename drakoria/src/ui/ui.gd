class_name UI
extends RefCounted
## Petite boîte à outils d'interface. 1 unité logique = 3 px du canevas
## 1080×1920 (soit 360×640 unités). Cibles tactiles >= 48 unités.

const U := 3.0
const MIN_TOUCH := 48.0 * U

const BG := Color("efe6d2")
const INK := Color("2b2b33")
const INK_SOFT := Color("5b5a63")
const TURQUOISE := Color("14808e")
const CORAL := Color("c9502c")
const GOLD := Color("c9a24a")
const STONE := Color("d9cfb8")
const CARD := Color("fbf6e6")
const GREEN := Color("3b8f4a")


static func tr_key(key: String, args: Dictionary = {}) -> String:
	return I18n.t(key, args)


static func fs(units: float) -> int:
	return int(round(units * U * float(Settings.get_value("text_scale"))))


static func label(text: String, units := 16.0, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs(units))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func box(color: Color, radius := 36, border := Color.TRANSPARENT, border_w := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(30)
	sb.anti_aliasing = true
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	return sb


static func card(color := CARD) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, 36, STONE.darkened(0.12), 3))
	return p


static func vbox(sep := 24) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 24) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer(expand := true, min_px := 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(min_px, min_px)
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func button(text: String, icon := "", style := "secondary", on_press := Callable()) -> UIButton:
	var b := UIButton.new()
	b.configure(text, icon, style)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


static func demo_banner(key: String) -> PanelContainer:
	## Étiquette obligatoire de tout achat ou publicité simulés.
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Color("fff3c4"), 24, INK, 4))
	var h := hbox(18)
	var ic := UIIcon.new()
	ic.kind = "info"
	ic.custom_minimum_size = Vector2(60, 60)
	h.add_child(ic)
	h.add_child(label(I18n.t(key), 15, INK))
	p.add_child(h)
	return p
