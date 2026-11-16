class_name GestureController
extends Node
## Convertit le toucher en appels au modèle. Un seul doigt trace. La précision
## gestuelle n'est jamais une difficulté : les cases sautées par un mouvement
## rapide sont comblées orthogonalement.

signal model_touched   # le modèle a (peut-être) émis des événements

var model: PuzzleModel
var board: BoardView
var enabled := true
var _finger := -1
var _last_target := Vector2i(-1, -1)


func bind(m: PuzzleModel, b: BoardView) -> void:
	model = m
	board = b


func is_tracing() -> bool:
	return _finger != -1


func handle_input(event: InputEvent) -> void:
	## Positions en coordonnées locales du plateau.
	if model == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _finger == -1 and enabled:
			press(event.index, event.position)
		elif not event.pressed and event.index == _finger:
			release()
	elif event is InputEventScreenDrag and event.index == _finger:
		drag(event.position)


func press(finger: int, pos: Vector2) -> void:
	var cell := board.cell_at(pos)
	if cell.x < 0:
		return
	if model.begin_draft(cell):
		_finger = finger
		_last_target = cell
		model_touched.emit()


func drag(pos: Vector2) -> void:
	if _finger == -1 or model.draft_pair == 0:
		return
	var target := board.cell_at(pos)
	if target.x < 0:
		_last_target = Vector2i(-1, -1)
		return  # hors plateau : l'ajout de segments est suspendu
	if target == _last_target:
		return
	_last_target = target
	# Retour sur une case déjà tracée : on retire les segments un à un.
	while target in model.draft and model.draft[model.draft.size() - 1] != target:
		model.extend_draft(model.draft[model.draft.size() - 2])
	var guard := 0
	while guard < 16:
		guard += 1
		var tip: Vector2i = model.draft[model.draft.size() - 1]
		if tip == target:
			break
		var d := target - tip
		var step := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
		var r := model.extend_draft(tip + step)
		if r.begins_with("refused") and d.x != 0 and d.y != 0:
			# Essai sur l'autre axe avant d'abandonner.
			var alt := Vector2i(0, signi(d.y)) if step.x != 0 else Vector2i(signi(d.x), 0)
			model.drain_last_refusal()
			r = model.extend_draft(tip + alt)
		if r != "added" and r != "removed":
			break
	model_touched.emit()


func release() -> void:
	if _finger == -1:
		return
	_finger = -1
	model.end_draft()
	model_touched.emit()


func cancel() -> void:
	## Pause, arrière-plan, changement d'écran : le tracé non validé est abandonné.
	if _finger == -1:
		return
	_finger = -1
	model.abort_draft()
	model_touched.emit()
