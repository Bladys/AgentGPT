class_name VFXService
extends Node2D
## Émetteurs préchargés et réutilisés ; plafond global de particules ;
## au plus `max_big_effects` gros effets simultanés ; mode mouvements réduits
## sans particules. Aucune allocation par case.

var catalog: Dictionary = {}
var cap := 160
var max_big := 2
var _pool: Array[CPUParticles2D] = []
var _busy_until: Array[float] = []
var _budget: Array[int] = []
var _big: Array[bool] = []
var _atlas: Array[AnimatedSprite2D] = []
var _clock := 0.0
var skipped := 0
var played: Array = []


func _ready() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/effects.json"))
	catalog = d["effects"]
	cap = int(d["global_particle_cap"])
	max_big = int(d["max_big_effects"])
	for i in int(d["pool_size"]):
		var p := CPUParticles2D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.9
		p.direction = Vector2(0, -1)
		p.spread = 180.0
		p.gravity = Vector2(0, 220)
		p.initial_velocity_min = 80.0
		p.initial_velocity_max = 220.0
		p.scale_amount_min = 5.0
		p.scale_amount_max = 11.0
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		p.color_ramp = g
		add_child(p)
		_pool.append(p)
		_busy_until.append(0.0)
		_budget.append(0)
		_big.append(false)
	for i in max_big:
		var s := AnimatedSprite2D.new()
		s.visible = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		s.animation_finished.connect(func(): s.visible = false)
		add_child(s)
		_atlas.append(s)


func _process(delta: float) -> void:
	_clock += minf(delta, 0.1)


func active_particles() -> int:
	var n := 0
	for i in _pool.size():
		if _busy_until[i] > _clock:
			n += _budget[i]
	return n


func active_big() -> int:
	var n := 0
	for i in _pool.size():
		if _busy_until[i] > _clock and _big[i]:
			n += 1
	return n


func play(effect: String, at: Vector2, color := Color.WHITE) -> bool:
	## `at` en coordonnées locales du service. Renvoie false si l'effet est omis.
	var def: Dictionary = catalog.get(effect, {})
	if def.is_empty() or Settings.reduced_motion():
		return false
	var amount := int(def["particles"])
	if amount <= 0:
		return false
	var big := bool(def["big"])
	if active_particles() + amount > cap or (big and active_big() >= max_big):
		skipped += 1
		return false
	var slot := -1
	for i in _pool.size():
		if _busy_until[i] <= _clock:
			slot = i
			break
	if slot == -1:
		skipped += 1
		return false
	played.append(effect)
	if played.size() > 64:
		played.pop_front()
	var dur := float(def["duration"])
	_busy_until[slot] = _clock + dur
	_budget[slot] = amount
	_big[slot] = big
	var frames := AssetRegistry.load_or_null(str(def.get("atlas", ""))) as SpriteFrames if big else null
	if frames != null:
		var s := _atlas[0]
		for cand in _atlas:
			if not cand.visible:
				s = cand
				break
		s.sprite_frames = frames
		s.position = at
		s.visible = true
		s.play(frames.get_animation_names()[0])
		return true
	var p := _pool[slot]
	p.position = at
	p.amount = amount
	p.lifetime = dur
	p.color = color
	p.restart()
	return true


func stop_all() -> void:
	for i in _pool.size():
		_pool[i].emitting = false
		_busy_until[i] = 0.0
	for s in _atlas:
		s.stop()
		s.visible = false
