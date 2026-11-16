extends ScreenBase
## Écran de puzzle : numéro, objectif court, plateau, annuler / recommencer /
## indice et pause. Le modèle décide ; l'écran rejoue ses événements.

var index := 1
var model: PuzzleModel
var board: BoardView
var gesture: GestureController
var router: AnimationEventRouter
var vfx: VFXService
var stage: DragonStage
var reference: Dictionary = {}
var _caption: Label
var _hint_btn: UIButton
var _undo_btn: UIButton
var _progress: Label
var _won := false
var _win_tween: Tween
var _start_ms := 0


func build() -> void:
	index = int(args.get("index", 1))
	var level := LevelLoader.load_level(index)
	if level.is_empty() or not Progression.is_unlocked(index):
		main.call_deferred("go", "map", {}, true)
		return
	model = PuzzleModel.new()
	model.load_level(level)
	reference = LevelLoader.reference_paths(level)
	var saved := Progression.take_in_progress(index)
	if not saved.is_empty():
		model.from_dict(saved)   # tout état incohérent retombe sur l'état initial
	if model.completed:
		model.restart(false)
	_start_ms = Time.get_ticks_msec()

	var top := UI.hbox(24)
	top.add_child(UI.button(UI.tr_key("puzzle.pause"), "pause", "secondary", open_pause))
	var titles := UI.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UI.label(UI.tr_key("puzzle.level", {"n": index}), 22, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	_progress = UI.label("", 14, UI.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	titles.add_child(_progress)
	top.add_child(titles)
	stage = DragonStage.new()
	stage.custom_minimum_size = Vector2(UI.MIN_TOUCH, UI.MIN_TOUCH)
	stage.display_scale = 0.85
	var comp = level.get("required_companion")
	if comp != null:
		stage.animator.setup(str(comp))   # seul le compagnon du niveau est chargé
	top.add_child(stage)
	root.add_child(top)

	var aspect := AspectRatioContainer.new()
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board = BoardView.new()
	aspect.add_child(board)
	root.add_child(aspect)
	board.set_model(model)

	_caption = UI.label("", 15, UI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_caption.custom_minimum_size = Vector2(0, 150)
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(_caption)

	var bar := UI.hbox(24)
	_undo_btn = UI.button(UI.tr_key("puzzle.undo"), "undo", "tile", request_undo)
	var restart_btn := UI.button(UI.tr_key("puzzle.restart"), "restart", "tile", request_restart)
	_hint_btn = UI.button("", "hint", "tile", request_hint)
	for b in [_undo_btn, restart_btn, _hint_btn]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_min(Vector2(0, 174))
		bar.add_child(b)
	root.add_child(bar)

	vfx = VFXService.new()
	vfx.z_index = 5
	add_child(vfx)
	gesture = GestureController.new()
	add_child(gesture)
	gesture.bind(model, board)
	gesture.model_touched.connect(on_model_touched)
	board.board_input.connect(gesture.handle_input)
	router = AnimationEventRouter.new()
	add_child(router)
	router.bind(board, vfx, stage.animator)

	if index == 1 and not Progression.state["tutorial_done"]:
		Analytics.track("tutorial_start")
	Analytics.track("level_start", {"level": index, "resumed": not saved.is_empty()})
	_refresh_hud()


func _objective() -> String:
	var key := "tutorial.%d" % index
	if Settings.get_value("help_captions") and I18n.keys("en").has(key):
		return UI.tr_key(key)
	return UI.tr_key("puzzle.objective", {"n": model.pairs.size()})


func _refresh_hud() -> void:
	_progress.text = UI.tr_key("puzzle.progress", {"done": model.connected_count(), "total": model.pairs.size()})
	_undo_btn.disabled = not model.can_undo() or _won
	_hint_btn.set_label(UI.tr_key("puzzle.hint_free") if Progression.hint_is_free(index)
		else UI.tr_key("puzzle.hint", {"n": Progression.state["hints"]}))
	if not _won and board.remove_pair == 0:
		_caption.text = _objective()


# ---------------------------------------------------------------- événements du modèle

func on_model_touched() -> void:
	var events := model.drain_events()
	if events.is_empty():
		return
	var persist := false
	var victory := false
	for e in events:
		match e["type"]:
			"pair_connected":
				persist = true
				if e["pair"] == board.hint_pair:
					board.hint_pair = 0
					board.hint_path = []
			"pair_released", "draft_cancelled", "state_restored":
				persist = true
			"level_completed":
				victory = true
	if board.remove_pair != 0 and not model.paths.has(board.remove_pair):
		board.remove_pair = 0
	router.handle(events)
	if victory:
		_on_victory()
	elif persist and model.draft_pair == 0:
		Progression.store_in_progress(index, model.to_dict())
	_refresh_hud()


func _on_victory() -> void:
	## La victoire vient du modèle. La récompense est accordée ici, tout de
	## suite et une seule fois — jamais depuis un callback d'animation.
	if _won:
		return
	_won = true
	gesture.enabled = false
	var result: Dictionary = Progression.complete_level(index)
	Analytics.track("level_complete", {"level": index, "moves": model.moves, "first": result["first"],
		"duration_s": (Time.get_ticks_msec() - _start_ms) / 1000})
	if index == int(Progression.config["tutorial_levels"]) and result["first"]:
		Analytics.track("tutorial_complete")
	Ads.policy.on_win()
	_caption.text = UI.tr_key("puzzle.solved")
	var delay := 0.25 if Settings.reduced_motion() else 1.3
	_win_tween = create_tween()
	_win_tween.tween_interval(delay)
	_win_tween.tween_callback(func(): main.go("win", {"index": index, "result": result}))


# ---------------------------------------------------------------- actions

func request_undo() -> void:
	if _won or gesture.is_tracing():
		return
	if model.undo():
		Analytics.track("undo", {"level": index})
		on_model_touched()


func request_restart() -> void:
	if _won:
		return
	gesture.cancel()
	model.restart()
	board.hint_path = []
	board.hint_pair = 0
	board.remove_pair = 0
	Analytics.track("restart", {"level": index})
	on_model_touched()


func request_hint() -> void:
	if _won or gesture.is_tracing():
		return
	if not Progression.can_use_hint(index):
		_offer_hints()
		return
	var h := Solver.hint(model, reference)
	if h["kind"] == "segment":
		var path: Array = h["path"]
		var reveal := 2
		if h["pair"] == board.hint_pair and board.hint_path.size() < path.size() \
				and path.slice(0, board.hint_path.size()) == board.hint_path:
			reveal = board.hint_path.size() + 1
		if not Progression.consume_hint(index):
			return
		board.hint_pair = h["pair"]
		board.hint_path = path.slice(0, reveal)
		board.remove_pair = 0
		_caption.text = UI.tr_key("puzzle.hint_temp" if h["temporary"] else "puzzle.hint_shown", {"n": model.pair_by_id[h["pair"]]["number"]})
		Analytics.track("hint_used", {"level": index, "pair": h["pair"]})
	elif h["kind"] == "remove":
		# Proposition seulement : aucun indice dépensé, rien n'est retiré d'office.
		var pid: int = h["pair"]
		board.remove_pair = pid
		Analytics.track("hint_remove_proposed", {"level": index, "pair": pid})
		_caption.text = UI.tr_key("puzzle.hint_remove", {"n": model.pair_by_id[pid]["number"]})
		main.show_dialog(UI.tr_key("puzzle.hint_remove_title"), UI.tr_key("puzzle.hint_remove", {"n": model.pair_by_id[pid]["number"]}), [
			{"text": UI.tr_key("puzzle.remove_yes"), "style": "primary", "cb": func():
				model.remove_path(pid)
				on_model_touched()},
			{"text": UI.tr_key("puzzle.remove_no"), "cb": func():
				board.remove_pair = 0
				board.queue_redraw()
				_refresh_hud()},
		])
	board.queue_redraw()
	_hint_btn.set_label(UI.tr_key("puzzle.hint_free") if Progression.hint_is_free(index)
		else UI.tr_key("puzzle.hint", {"n": Progression.state["hints"]}))


func _offer_hints() -> void:
	var buttons: Array = []
	if Progression.daily_available():
		buttons.append({"text": UI.tr_key("home.daily"), "icon": "gift", "style": "primary", "cb": func():
			Progression.claim_daily()
			_refresh_hud()})
	buttons.append({"text": UI.tr_key("hints.watch"), "icon": "video", "cb": func():
		var cb := func(placement: String, txn: String, completed: bool):
			if placement == "hint" and completed:
				Progression.grant(txn, "hints", int(Progression.config["hints"]["rewarded_ad"]))
			_caption.text = UI.tr_key("hints.granted" if completed else "ads.failed")
			_refresh_hud()
		Ads.rewarded_finished.connect(cb, CONNECT_ONE_SHOT)
		Ads.request_rewarded("hint")})
	buttons.append({"text": UI.tr_key("common.close")})
	main.show_dialog(UI.tr_key("hints.none_title"), UI.tr_key("hints.none_body"), buttons)


func open_pause() -> void:
	gesture.cancel()
	main.show_dialog(UI.tr_key("puzzle.pause"), UI.tr_key("puzzle.pause_body"), [
		{"text": UI.tr_key("puzzle.resume"), "icon": "play", "style": "primary"},
		{"text": UI.tr_key("puzzle.restart"), "icon": "restart", "cb": request_restart},
		{"text": UI.tr_key("home.map"), "icon": "map", "cb": func(): main.go("map")},
	])


func on_back() -> void:
	open_pause()


func on_pause() -> void:
	## Arrière-plan : tracé abandonné, état validé écrit, callbacks annulés.
	if gesture and not _won:
		gesture.cancel()
		Progression.store_in_progress(index, model.to_dict())


func on_exit() -> void:
	if _win_tween:
		_win_tween.kill()
	if model == null:
		return
	gesture.cancel()
	router.cancel_all()
	if not _won:
		Progression.store_in_progress(index, model.to_dict())
		Analytics.track("level_abandon", {"level": index, "moves": model.moves, "connected": model.connected_count()})
