extends ScreenBase
## Collection : un seul compagnon chargé à la fois (pas tous les atlas).

var _selected := "brindille"
var _detail: VBoxContainer
var _tabs: HBoxContainer


func build() -> void:
	header(UI.tr_key("collection.title"))
	_selected = str(args.get("companion", "brindille"))
	_tabs = UI.hbox(18)
	root.add_child(_tabs)
	_detail = UI.vbox(24)
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_detail)
	_show()


func _show() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	for c in _detail.get_children():
		c.queue_free()
	for name in ["brindille", "braise", "nacre"]:
		var b := UI.button(UI.tr_key("companion.%s.name" % name), "", "selected" if name == _selected else "secondary", func():
			_selected = name
			_show())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tabs.add_child(b)
	var unlocked := Progression.companion_unlocked(_selected)
	var card := UI.card()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(18)
	card.add_child(v)
	if unlocked:
		var stage := DragonStage.new()
		stage.custom_minimum_size = Vector2(0, 560)
		stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stage.display_scale = 2.6
		stage.animator.setup(_selected, true)   # habitat au repos : sleep
		stage.tapped.connect(stage.animator.interact)
		v.add_child(stage)
		v.add_child(UI.label(UI.tr_key("collection.tap"), 13, UI.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		var ic := UIIcon.new()
		ic.kind = "lock"
		ic.color = UI.INK_SOFT
		ic.custom_minimum_size = Vector2(0, 360)
		ic.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(ic)
	v.add_child(UI.label(UI.tr_key("companion.%s.name" % _selected) + " — " + UI.tr_key("companion.%s.kind" % _selected), 20, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(UI.tr_key("companion.%s.power" % _selected), 15, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var status := UI.tr_key("collection.awake") if unlocked else UI.tr_key("collection.locked", {"n": int(Progression.config["companions"][_selected]["unlock_after_level"])})
	v.add_child(UI.label(status, 15, UI.GREEN if unlocked else UI.CORAL, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(UI.tr_key("collection.free"), 13, UI.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	_detail.add_child(card)
