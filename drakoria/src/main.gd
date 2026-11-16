extends Control
## Racine : navigation entre écrans (fondu 200 ms), marges d'encoche,
## dialogues « Démonstration », pause en arrière-plan.

const SCREENS := {
	"home": "res://src/ui/home_screen.gd", "map": "res://src/ui/map_screen.gd",
	"puzzle": "res://src/ui/puzzle_screen.gd", "win": "res://src/ui/win_screen.gd",
	"restoration": "res://src/ui/restoration_screen.gd", "collection": "res://src/ui/collection_screen.gd",
	"shop": "res://src/ui/shop_screen.gd", "settings": "res://src/ui/settings_screen.gd",
}
const FADE := 0.1  # sortie + entrée = 200 ms

var current: ScreenBase
var current_name := ""
var current_args: Dictionary = {}
var _host: MarginContainer
var _overlay: Control
var _dialog: Control
var _busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_host = MarginContainer.new()
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_host)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	Ads.mock_rewarded_prompt.connect(_mock_ad)
	Purchases.mock_purchase_prompt.connect(_mock_purchase)
	Settings.changed.connect(func(k): if k == "text_scale" or k == "language": call_deferred("refresh"))
	if get_parent() == get_tree().root:
		go("home", {}, true)


func _apply_safe_area() -> void:
	## Marges d'encoche converties en unités du canevas.
	var m := {"left": 24.0, "top": 24.0, "right": 24.0, "bottom": 24.0}
	var win := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	var vp := get_viewport_rect().size
	if OS.has_feature("mobile") and win.x > 0 and win.y > 0 and safe.size.x > 0:
		var k := vp.x / win.x
		m["left"] += safe.position.x * k
		m["top"] += safe.position.y * k
		m["right"] += maxf(0.0, win.x - safe.end.x) * k
		m["bottom"] += maxf(0.0, win.y - safe.end.y) * k
	for side in m:
		_host.add_theme_constant_override("margin_" + side, int(m[side]))


func refresh() -> void:
	if current_name != "" and current_name != "puzzle":
		go(current_name, current_args, true)


func go(name: String, args: Dictionary = {}, instant := false) -> void:
	if not SCREENS.has(name) or _busy:
		return
	close_dialog()
	var fade := not instant and not Settings.reduced_motion() and current != null
	if fade:
		_busy = true
		var t := create_tween()
		t.tween_property(current, "modulate:a", 0.0, FADE)
		await t.finished
		_busy = false
	if current:
		current.on_exit()
		current.queue_free()
		_host.remove_child(current)
	current = load(SCREENS[name]).new()
	current.main = self
	current.args = args
	current_name = name
	current_args = args
	_host.add_child(current)
	if fade:
		current.modulate.a = 0.0
		create_tween().tween_property(current, "modulate:a", 1.0, FADE)
	if name == "puzzle":
		AudioService.play_music("music_island_1")
		AudioService.play_ambience("amb_island_1")
	else:
		AudioService.play_music("music_menu")


# ---------------------------------------------------------------- dialogues

func show_dialog(title: String, body: String, buttons: Array, demo_key := "") -> void:
	close_dialog()
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog = ColorRect.new()
	_dialog.color = Color(0.1, 0.1, 0.14, 0.6)
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(_dialog)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog.add_child(center)
	var card := UI.card()
	card.custom_minimum_size = Vector2(minf(900.0, get_viewport_rect().size.x - 90.0), 0)
	center.add_child(card)
	var v := UI.vbox(30)
	card.add_child(v)
	if demo_key != "":
		v.add_child(UI.demo_banner(demo_key))
	v.add_child(UI.label(title, 22, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	if body != "":
		v.add_child(UI.label(body, 16, UI.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	for b in buttons:
		var cb: Callable = b.get("cb", Callable())
		v.add_child(UI.button(b["text"], b.get("icon", ""), b.get("style", "secondary"), func():
			close_dialog()
			if cb.is_valid():
				cb.call()))
	if not Settings.reduced_motion():
		card.pivot_offset = card.custom_minimum_size / 2.0
		card.scale = Vector2(0.9, 0.9)
		create_tween().tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close_dialog() -> void:
	if _dialog:
		_dialog.queue_free()
		_dialog = null
	if _overlay:
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func has_dialog() -> bool:
	return _dialog != null


func _mock_ad(_placement: String) -> void:
	show_dialog(I18n.t("ads.mock.title"), I18n.t("ads.mock.body"), [
		{"text": I18n.t("ads.mock.complete"), "style": "primary", "cb": func(): Ads.resolve_mock(true)},
		{"text": I18n.t("ads.mock.fail"), "cb": func(): Ads.resolve_mock(false)},
	], "ads.mock.banner")


func _mock_purchase(product: Dictionary) -> void:
	show_dialog(I18n.t(product["name_key"]), I18n.t("shop.mock.body", {"price": Purchases.localized_price(product["id"])}), [
		{"text": I18n.t("shop.mock.confirm"), "style": "primary", "cb": func(): Purchases.resolve_mock(true)},
		{"text": I18n.t("common.cancel"), "cb": func(): Purchases.resolve_mock(false)},
	], "shop.demo")


# ---------------------------------------------------------------- cycle de vie

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if current:
			current.on_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if has_dialog():
			close_dialog()
		elif current_name == "home":
			get_tree().quit()
		elif current:
			current.on_back()
