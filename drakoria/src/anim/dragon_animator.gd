class_name DragonAnimator
extends Node2D
## Propriétaire unique de la pose d'un compagnon.
## idle par défaut ; blink/react ponctuels ; cast à l'activation ; celebrate à
## la découverte/restauration ; sleep uniquement dans l'habitat au repos.
## Un clip non bouclé revient à idle. Une nouvelle action annule les callbacks
## de la précédente (jeton). Fondu de 160–200 ms lors d'une interruption.
## Seules les ressources du compagnon affiché sont chargées.

signal anim_event(event_name: String, token: int)
signal clip_finished(state: String, token: int)

const COLORS := {"brindille": Color("5fae5a"), "braise": Color("e8623a"), "nacre": Color("9fd8ee")}

var companion := ""
var current := ""
var token := 0
var in_habitat := false
var placeholder := true

var _front: AnimatedSprite2D
var _back: AnimatedSprite2D
var _frames: Dictionary = {}
var _elapsed := 0.0
var _duration := 0.0
var _looping := true
var _fired: Dictionary = {}
var _fade: Tween
var _blink_in := 4.0


func _ready() -> void:
	_back = _make_sprite()
	_front = _make_sprite()
	if companion != "" and current == "":
		play("sleep" if in_habitat else "idle")


func _make_sprite() -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	var pv: Array = AnimContract.data()["pivot"]["character"]
	s.centered = false
	s.offset = -Vector2(pv[0], pv[1])   # pivot fixe (128,226) : pieds ancrés
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.speed_scale = 1.0                 # durées de frame relatives à une vitesse de base 1
	s.visible = false
	add_child(s)
	return s


func setup(name: String, habitat := false) -> void:
	if name == companion and habitat == in_habitat:
		return
	companion = name
	in_habitat = habitat
	_frames.clear()
	current = ""
	if is_inside_tree():
		play("sleep" if habitat else "idle")


func play(state: String, force := false) -> int:
	## Renvoie le jeton de l'action. Ne relance pas un clip déjà en cours.
	if companion == "" or AnimContract.state(state).is_empty():
		return token
	if state == "sleep" and not in_habitat:
		state = "idle"
	if not force and state == current and (_looping or _elapsed < _duration):
		return token
	var interrupting := current != "" and current != "idle" and not _looping
	token += 1
	current = state
	_elapsed = 0.0
	_fired = {}
	var def := AnimContract.state(state)
	_looping = bool(def.get("loop", false))
	_duration = float(def.get("fallback_duration", 0.0))
	var frames := _load(state)
	placeholder = frames == null
	if frames != null:
		_swap(frames, interrupting)
		if not _looping:
			_duration = _clip_length(frames)
	queue_redraw()
	if Settings.reduced_motion():
		# Pose neutre : les événements partent tout de suite, sans mouvement.
		_front.stop()
		_front.frame = 0
		if not _looping:
			_elapsed = _duration
			_flush_events(token)
	return token


func interact() -> void:
	play("idle" if current == "sleep" else "react")
	if current == "idle" and in_habitat:
		in_habitat = false


func cancel() -> void:
	## Chargement de scène, publicité, annulation : plus aucun callback.
	token += 1
	current = ""
	if companion != "":
		play("idle")


func _load(state: String) -> SpriteFrames:
	if _frames.has(state):
		return _frames[state]
	var res := AssetRegistry.load_or_null("anim_%s_%s" % [companion, state])
	_frames[state] = res as SpriteFrames
	return _frames[state]


func _clip_length(frames: SpriteFrames) -> float:
	var anim := _anim_name(frames)
	var fps := frames.get_animation_speed(anim)
	var total := 0.0
	for i in frames.get_frame_count(anim):
		total += frames.get_frame_duration(anim, i)
	return total / maxf(fps, 0.001)


func _anim_name(frames: SpriteFrames) -> StringName:
	var names := frames.get_animation_names()
	return &"default" if names.has("default") else StringName(names[0])


func _swap(frames: SpriteFrames, crossfade: bool) -> void:
	if _fade:
		_fade.kill()
	var t := _back
	_back = _front
	_front = t
	move_child(_front, -1)
	_front.sprite_frames = frames
	_front.visible = true
	_front.play(_anim_name(frames))
	if crossfade and not Settings.reduced_motion() and _back.visible:
		_front.modulate.a = 0.0
		_fade = create_tween().set_parallel()
		_fade.tween_property(_front, "modulate:a", 1.0, AnimContract.crossfade_s())
		_fade.tween_property(_back, "modulate:a", 0.0, AnimContract.crossfade_s())
		_fade.chain().tween_callback(func(): _back.visible = false; _back.stop())
	else:
		_front.modulate.a = 1.0
		_back.visible = false
		_back.stop()


func _process(delta: float) -> void:
	if companion == "" or current == "":
		return
	delta = minf(delta, 0.1)  # pas de rattrapage accéléré au retour d'arrière-plan
	if _looping:
		if current == "idle" and not Settings.reduced_motion():
			_blink_in -= delta
			if _blink_in <= 0.0:
				_blink_in = randf_range(3.5, 7.0)
				play("blink")
		return
	_elapsed += delta
	_flush_events(token)
	if placeholder:
		queue_redraw()
	if _elapsed >= _duration:
		var done := current
		var tk := token
		current = ""
		play("idle")
		clip_finished.emit(done, tk)


func _flush_events(tk: int) -> void:
	for e in AnimContract.events(current):
		if not _fired.has(e["name"]) and _elapsed >= float(e["time"]):
			_fired[e["name"]] = true
			anim_event.emit(e["name"], tk)
			if tk != token:
				return


func _draw() -> void:
	## Silhouette provisoire tant que les atlas du pack ne sont pas intégrés.
	if not placeholder or companion == "":
		return
	var c: Color = COLORS.get(companion, Color.GRAY)
	var dark := c.darkened(0.35)
	var lift := 0.0
	var wing := 0.0
	if not Settings.reduced_motion() and _duration > 0.0:
		var p := clampf(_elapsed / _duration, 0.0, 1.0)
		if current == "celebrate":
			lift = -sin(p * PI) * 14.0   # seul le bond de victoire décale verticalement
		if current == "cast" or current == "celebrate":
			wing = sin(p * PI) * 16.0
	var o := Vector2(0, lift)
	draw_colored_polygon(PackedVector2Array([o + Vector2(-34, -70), o + Vector2(-78, -104 - wing), o + Vector2(-58, -52)]), dark)
	draw_colored_polygon(PackedVector2Array([o + Vector2(34, -70), o + Vector2(78, -104 - wing), o + Vector2(58, -52)]), dark)
	draw_circle(o + Vector2(0, -44), 44, c)
	draw_circle(o + Vector2(0, -100), 30, c)
	draw_circle(o + Vector2(0, -38), 26, c.lightened(0.35))
	var asleep := current == "sleep" or current == "blink"
	for sx in [-11, 11]:
		if asleep:
			draw_line(o + Vector2(sx - 5, -102), o + Vector2(sx + 5, -102), dark, 3.0)
		else:
			draw_circle(o + Vector2(sx, -104), 5, Color("2b2b33"))
	draw_colored_polygon(PackedVector2Array([o + Vector2(-8, -128), o + Vector2(0, -146), o + Vector2(8, -128)]), dark)
