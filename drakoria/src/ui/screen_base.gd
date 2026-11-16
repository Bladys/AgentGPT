class_name ScreenBase
extends Control
## Base des écrans. `build()` construit l'interface ; `on_exit()` annule tout
## callback en cours ; `on_back()` gère le retour Android.

var main: Node
var args: Dictionary = {}
var root: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root = UI.vbox(30)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	build()


func build() -> void:
	pass


func on_exit() -> void:
	pass


func on_pause() -> void:
	pass


func on_back() -> void:
	main.go("home")


func header(title: String, back_to := "home") -> void:
	var h := UI.hbox(24)
	h.add_child(UI.button(UI.tr_key("common.back"), "back", "secondary", func(): main.go(back_to)))
	var l := UI.label(title, 24, UI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var ghost := UI.spacer(false, UI.MIN_TOUCH)
	h.add_child(ghost)
	root.add_child(h)


func scroll_body() -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := UI.vbox(27)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	root.add_child(sc)
	return v
