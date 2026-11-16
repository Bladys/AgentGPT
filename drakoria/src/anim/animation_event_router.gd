class_name AnimationEventRouter
extends Node
## Traduit les événements émis par le MODÈLE en animations, VFX et sons.
## Le modèle a déjà résolu les règles : rien ici n'accorde de récompense ni
## ne modifie l'état du puzzle. Chaque power_release déclenche une seule fois
## son VFX et son son ; une interruption annule proprement les callbacks.

signal visuals_settled

const ENERGY_COLORS := {"water": Color("1fa7b8"), "heat": Color("e8623a"), "light": Color("e9b93a")}

var board: BoardView
var vfx: VFXService
var dragon: DragonAnimator
var _pending: Dictionary = {}    # token -> {target, effect, companion}
var _celebrate_token := -1
var release_count := 0           # diagnostic / tests
var _last_error_ms := -1000


func bind(b: BoardView, v: VFXService, d: DragonAnimator) -> void:
	board = b
	vfx = v
	dragon = d
	if dragon:
		dragon.anim_event.connect(_on_anim_event)


func handle(events: Array) -> void:
	for e in events:
		match e["type"]:
			"draft_started":
				AudioService.trace_begin()
				_fx("channel_start", e["cell"], e["pair"])
			"segment_added":
				AudioService.trace_segment(int(e["length"]))
				_fx("trail", e["cell"], e["pair"])
			"segment_refused":
				if board:
					board.flash_forbidden(e["cell"])
				var now := Time.get_ticks_msec()
				if now - _last_error_ms > 350:
					_last_error_ms = now
					AudioService.play_sfx("sfx_soft_error")
			"pair_connected":
				AudioService.play_sfx("sfx_connect")
				_fx("connect", e["cell"], e["pair"])
				Settings.vibrate(20)
			"activator_fired":
				_start_power(e)
			"level_completed":
				_start_celebration()
			"state_restored":
				cancel_all()
	if board:
		board.queue_redraw()


func _fx(effect: String, cell: Vector2i, pair_id: int) -> void:
	if vfx == null or board == null:
		return
	var color: Color = ENERGY_COLORS.get(board.model.pair_by_id[pair_id]["energy"], Color.WHITE)
	vfx.play(effect, board.cell_center(cell) + board.global_position - vfx.global_position, color)


func _start_power(e: Dictionary) -> void:
	var effect: String = {"brindille": "bridge", "braise": "melt", "nacre": "freeze"}[e["companion"]]
	var info := {"target": e["target"], "effect": effect}
	if dragon == null or Settings.reduced_motion():
		_release(info, not Settings.reduced_motion())
		return
	if board:
		board.hold_terrain(e["target"], e["from"])  # l'affichage attend power_release
	if dragon.companion != e["companion"]:
		dragon.setup(e["companion"])
	# Une nouvelle action annule les callbacks visuels de la précédente.
	for tk in _pending.keys():
		_release(_pending[tk], false)
	_pending.clear()
	var tk := dragon.play("cast", true)
	_pending[tk] = info


func _start_celebration() -> void:
	AudioService.play_sfx("sfx_win")
	if dragon == null or dragon.companion == "" or Settings.reduced_motion():
		return
	for tk in _pending.keys():
		_release(_pending[tk], false)
	_pending.clear()
	_celebrate_token = dragon.play("celebrate", true)


func _on_anim_event(event_name: String, tk: int) -> void:
	if event_name == "power_release" and _pending.has(tk):
		var info: Dictionary = _pending[tk]
		_pending.erase(tk)
		_release(info, true)
		if _pending.is_empty():
			visuals_settled.emit()
	elif event_name == "celebrate_peak" and tk == _celebrate_token:
		_celebrate_token = -1
		if vfx and board:
			vfx.play("hatch", board.global_position + board.size / 2.0 - vfx.global_position, Color("f3d27a"))
		AudioService.play_sfx("sfx_hatch")


func _release(info: Dictionary, with_fx: bool) -> void:
	if board:
		board.release_terrain(info["target"])
	if with_fx:
		release_count += 1
		AudioService.play_sfx("sfx_" + info["effect"])
		if vfx and board:
			vfx.play(info["effect"], board.cell_center(info["target"]) + board.global_position - vfx.global_position, Color("f3e6c0"))


func cancel_all() -> void:
	## Annulation, redémarrage, pause, changement d'écran ou publicité.
	_pending.clear()
	_celebrate_token = -1
	if board:
		board.release_all_terrain()
	if dragon:
		dragon.cancel()
	if vfx:
		vfx.stop_all()
