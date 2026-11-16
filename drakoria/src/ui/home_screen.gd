extends ScreenBase
## Accueil : un bouton Jouer dominant ; le titre et les textes sont séparés des images.


func build() -> void:
	root.add_child(UI.spacer(true))
	root.add_child(UI.label("Drakoria", 44, UI.TURQUOISE, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(UI.label("Gardens of Dragons", 20, UI.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(UI.label(UI.tr_key("home.tagline"), 18, UI.CORAL, HORIZONTAL_ALIGNMENT_CENTER))
	var stage := DragonStage.new()
	stage.custom_minimum_size = Vector2(0, 420)
	stage.display_scale = 2.2
	var shown := ""
	for c in ["nacre", "braise", "brindille"]:
		if shown == "" and Progression.companion_unlocked(c):
			shown = c
	if shown != "":
		stage.animator.setup(shown)
		stage.tapped.connect(stage.animator.interact)
	root.add_child(stage)
	var n := Progression.next_level()
	var done := Progression.cleared_count() >= Progression.playable_levels()
	var play := UI.button(UI.tr_key("home.play_done") if done else UI.tr_key("home.play", {"n": n}), "play", "primary",
		func(): main.go("map") if done else main.go("puzzle", {"index": n}))
	play.set_min(Vector2(0, 240))
	root.add_child(play)
	if Progression.daily_available():
		root.add_child(UI.button(UI.tr_key("home.daily"), "gift", "card", func():
			if Progression.claim_daily():
				main.show_dialog(UI.tr_key("home.daily_title"), UI.tr_key("home.daily_body", {"n": Progression.state["hints"]}),
					[{"text": UI.tr_key("common.ok"), "style": "primary", "cb": func(): main.refresh()}])))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	for item in [["map", "home.map"], ["restoration", "home.garden", "garden"], ["collection", "home.collection"], ["shop", "home.shop"], ["settings", "home.settings"]]:
		var target: String = item[0]
		var b := UI.button(UI.tr_key(item[1]), item[2] if item.size() > 2 else target, "secondary", func(): main.go(target))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	root.add_child(grid)
	root.add_child(UI.label(UI.tr_key("home.proto"), 11, UI.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(UI.spacer(true))


func on_back() -> void:
	pass
