extends ScreenBase
## Réussite. La graine a déjà été accordée par ProgressionService ; cet écran
## l'affiche. Le doublement par vidéo est facultatif, expliqué, et ne donne
## rien si la vidéo échoue.

var _seed_label: Label
var _status: Label
var _double_btn: UIButton
var _cb: Callable


func build() -> void:
	var index := int(args.get("index", 1))
	var result: Dictionary = args.get("result", {})
	Ads.maybe_interstitial(index, "after_win")   # prototype : décision journalisée, rien d'affiché
	root.add_child(UI.spacer(true))
	root.add_child(UI.label(UI.tr_key("win.title"), 34, UI.TURQUOISE, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(UI.label(UI.tr_key("puzzle.level", {"n": index}), 18, UI.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var card := UI.card()
	var v := UI.vbox(18)
	card.add_child(v)
	var ic := UIIcon.new()
	ic.kind = "seed"
	ic.color = UI.GREEN
	ic.custom_minimum_size = Vector2(150, 150)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var first: bool = result.get("first", false)
	_seed_label = UI.label(UI.tr_key("win.seed", {"n": result.get("seeds", 0)}) if first else UI.tr_key("win.replay_note"), 18, UI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_seed_label)
	v.add_child(UI.label(UI.tr_key("win.seeds_total", {"n": Progression.state["seeds"]}), 14, UI.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	if int(result.get("milestone", 0)) > 0:
		v.add_child(UI.label(UI.tr_key("win.milestone"), 16, UI.CORAL, HORIZONTAL_ALIGNMENT_CENTER))
	if str(result.get("companion", "")) != "":
		v.add_child(UI.label(UI.tr_key("win.companion", {"name": UI.tr_key("companion.%s.name" % result["companion"])}), 16, UI.CORAL, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(card)
	if first and not Settings.reduced_motion():
		# Apparition de la récompense : échelle amortie de 220 ms.
		card.scale = Vector2(0.8, 0.8)
		card.resized.connect(func(): card.pivot_offset = card.size / 2.0)
		create_tween().tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_status = UI.label("", 14, UI.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_status)
	var has_next := index < Progression.playable_levels()
	if has_next:
		root.add_child(UI.button(UI.tr_key("win.next"), "next", "primary", func(): main.go("puzzle", {"index": index + 1})))
	else:
		root.add_child(UI.label(UI.tr_key("win.slice_done"), 15, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	if Progression.can_restore() or int(result.get("milestone", 0)) > 0:
		root.add_child(UI.button(UI.tr_key("win.restore"), "garden", "primary" if not has_next else "secondary", func(): main.go("restoration")))
	if first and int(result.get("seeds", 0)) > 0:
		root.add_child(UI.label(UI.tr_key("win.double_explain"), 13, UI.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
		_double_btn = UI.button(UI.tr_key("win.double"), "video", "card", func(): _double(index))
		root.add_child(_double_btn)
	var row := UI.hbox(24)
	for item in [["win.replay", "restart", func(): main.go("puzzle", {"index": index})], ["home.map", "map", func(): main.go("map")]]:
		var b := UI.button(UI.tr_key(item[0]), item[1], "secondary", item[2])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	root.add_child(row)
	root.add_child(UI.spacer(true))


func _double(index: int) -> void:
	var placement := "double_seed:level_%03d" % index
	_cb = func(pl: String, txn: String, completed: bool):
		if pl != placement:
			return
		if completed and Progression.grant(txn, "seeds", 1):
			_status.text = UI.tr_key("win.doubled", {"n": Progression.state["seeds"]})
			_double_btn.disabled = true
		elif not completed:
			_status.text = UI.tr_key("ads.failed")
	Ads.rewarded_finished.connect(_cb, CONNECT_ONE_SHOT)
	Ads.request_rewarded(placement)


func on_exit() -> void:
	Ads.policy.on_screen_left()
	if _cb.is_valid() and Ads.rewarded_finished.is_connected(_cb):
		Ads.rewarded_finished.disconnect(_cb)


func on_back() -> void:
	main.go("map")
