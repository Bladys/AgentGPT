extends ScreenBase
## Carte : six îles, cinq quartiers de dix niveaux. Seules les grilles
## validées par le solveur sont proposées ; les autres îles sont annoncées
## comme « en préparation », jamais comme prêtes.


func build() -> void:
	header(UI.tr_key("map.title"))
	root.add_child(UI.label(UI.tr_key("map.count", {"done": Progression.cleared_count(), "total": Progression.playable_levels()}), 15, UI.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var body := scroll_body()
	body.add_child(UI.label(UI.tr_key("island.1"), 22, UI.TURQUOISE))
	var per: int = Progression.config["levels_per_island"] / Progression.config["districts_per_island"]
	for d in int(Progression.config["districts_per_island"]):
		var card := UI.card()
		var v := UI.vbox(18)
		card.add_child(v)
		v.add_child(UI.label(UI.tr_key("map.district", {"n": d + 1}), 16, UI.INK))
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 18)
		grid.add_theme_constant_override("v_separation", 18)
		for k in per:
			var idx := d * per + k + 1
			grid.add_child(_level_button(idx))
		v.add_child(grid)
		body.add_child(card)
	for i in range(2, 7):
		var card := UI.card(UI.STONE)
		var h := UI.hbox(24)
		var ic := UIIcon.new()
		ic.kind = "lock"
		ic.custom_minimum_size = Vector2(72, 72)
		h.add_child(ic)
		var v := UI.vbox(6)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label(UI.tr_key("island.%d" % i), 18, UI.INK))
		v.add_child(UI.label(UI.tr_key("map.locked_island" if i == 2 else "map.future_island"), 13, UI.INK_SOFT))
		h.add_child(v)
		card.add_child(h)
		body.add_child(card)


func _level_button(idx: int) -> UIButton:
	var cleared := Progression.is_cleared(idx)
	var open := Progression.is_unlocked(idx)
	var is_next := open and not cleared
	# État lisible sans la couleur : coche, flèche ou cadenas + numéro.
	var b := UI.button(str(idx), "check" if cleared else ("play" if is_next else "lock"), "selected_tile" if is_next else "tile")
	if is_next:
		b.configure_colors(UI.TURQUOISE, Color.WHITE)
	elif cleared:
		b.configure_colors(UI.CARD, UI.GREEN)
	b.disabled = not open
	b.set_min(Vector2(162, 162))
	b.pressed.connect(func(): main.go("puzzle", {"index": idx}))
	return b
