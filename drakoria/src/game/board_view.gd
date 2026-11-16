class_name BoardView
extends Control
## Affichage du plateau. Lecture seule sur le modèle. Chaque paire est
## identifiable par symbole d'énergie, numéro, motif ET couleur. Les états
## sélectionné / interdit / terminé se distinguent aussi par la forme
## (contour épais, croix, coche).

signal board_input(event: InputEvent)

const C_STONE := Color("d9cfb8")
const C_STONE_DARK := Color("b9ad93")
const C_CELL := Color("f4eedd")
const C_CELL_ALT := Color("ece4cf")
const C_ROCK := Color("8d8676")
const C_INK := Color("2b2b33")
const C_GOLD := Color("c9a24a")
const ENERGY := {"water": Color("1fa7b8"), "heat": Color("e8623a"), "light": Color("e9b93a")}

var model: PuzzleModel
var hint_path: Array = []        # préfixe révélé (cases)
var hint_pair := 0
var remove_pair := 0             # canal que l'indice propose de retirer
var _held: Dictionary = {}       # cell -> terrain affiché en attendant power_release
var _forbidden: Dictionary = {}  # cell -> instant d'expiration (ms)
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func set_model(m: PuzzleModel) -> void:
	model = m
	_held.clear()
	_forbidden.clear()
	hint_path = []
	hint_pair = 0
	remove_pair = 0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		board_input.emit(event)
		accept_event()


# ---------------------------------------------------------------- géométrie

func cell_size() -> float:
	if model == null:
		return 1.0
	return minf(size.x / model.width, size.y / model.height)


func _origin() -> Vector2:
	var cs := cell_size()
	return (size - Vector2(cs * model.width, cs * model.height)) / 2.0


func cell_at(pos: Vector2) -> Vector2i:
	if model == null:
		return Vector2i(-1, -1)
	var p := (pos - _origin()) / cell_size()
	if p.x < 0 or p.y < 0 or p.x >= model.width or p.y >= model.height:
		return Vector2i(-1, -1)
	return Vector2i(int(p.x), int(p.y))


func cell_center(c: Vector2i) -> Vector2:
	return _origin() + (Vector2(c) + Vector2(0.5, 0.5)) * cell_size()


# ---------------------------------------------------------------- état visuel transitoire

func hold_terrain(cell: Vector2i, shown: int) -> void:
	_held[cell] = shown


func release_terrain(cell: Vector2i) -> void:
	_held.erase(cell)
	queue_redraw()


func release_all_terrain() -> void:
	_held.clear()
	queue_redraw()


func flash_forbidden(cell: Vector2i) -> void:
	if model == null or not model.in_bounds(cell):
		return
	_forbidden[cell] = Time.get_ticks_msec() + 320
	queue_redraw()
	get_tree().create_timer(0.34).timeout.connect(queue_redraw)


# ---------------------------------------------------------------- dessin

func _draw() -> void:
	if model == null:
		return
	var cs := cell_size()
	var o := _origin()
	var full := Rect2(o - Vector2(10, 10), Vector2(cs * model.width + 20, cs * model.height + 20))
	draw_style_box(_box(C_STONE_DARK, 28), full.grow(6))
	draw_style_box(_box(C_STONE, 24), full)
	for y in model.height:
		for x in model.width:
			var c := Vector2i(x, y)
			var r := Rect2(o + Vector2(x, y) * cs, Vector2(cs, cs)).grow(-cs * 0.035)
			var t: int = _held.get(c, model.terrain_at(c))
			_draw_cell(r, t, (x + y) % 2 == 0, c)
	for pid in model.paths:
		_draw_path(model.paths[pid], model.pair_by_id[pid], "done", pid == remove_pair)
	if model.draft_pair != 0:
		_draw_path(model.draft, model.pair_by_id[model.draft_pair], "selected", false)
	if hint_path.size() >= 2:
		_draw_hint()
	for pr in model.pairs:
		_draw_endpoint(pr, true)
		_draw_endpoint(pr, false)
	var now := Time.get_ticks_msec()
	for c in _forbidden.keys():
		if _forbidden[c] < now:
			_forbidden.erase(c)
			continue
		var p := cell_center(c)
		var k := cs * 0.22
		draw_line(p - Vector2(k, k), p + Vector2(k, k), C_INK, cs * 0.09, true)
		draw_line(p - Vector2(k, -k), p + Vector2(k, -k), C_INK, cs * 0.09, true)


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


func _draw_cell(r: Rect2, t: int, alt: bool, c: Vector2i) -> void:
	var cs := r.size.x
	var rad := int(cs * 0.16)
	var ctr := r.get_center()
	match t:
		PuzzleModel.T_OBSTACLE:
			draw_style_box(_box(C_ROCK, int(cs * 0.3)), r.grow(-cs * 0.04))
			draw_circle(ctr + Vector2(-cs * 0.14, -cs * 0.12), cs * 0.13, C_ROCK.lightened(0.18))
			draw_circle(ctr + Vector2(cs * 0.16, cs * 0.14), cs * 0.09, C_ROCK.darkened(0.15))
		PuzzleModel.T_GAP:
			draw_style_box(_box(Color("3d4654"), rad), r)
			for i in 3:
				var yy := r.position.y + cs * (0.3 + 0.2 * i)
				draw_line(Vector2(r.position.x + cs * 0.2, yy), Vector2(r.end.x - cs * 0.2, yy), Color("59657a"), 3.0)
			_terrain_badge(c, "brindille")
		PuzzleModel.T_ICE:
			draw_style_box(_box(Color("bfe6f5"), rad), r)
			var k := cs * 0.3
			draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -k), ctr + Vector2(k * 0.7, 0), ctr + Vector2(0, k), ctr + Vector2(-k * 0.7, 0)]), Color("eaf8ff"))
			draw_polyline(PackedVector2Array([ctr + Vector2(0, -k), ctr + Vector2(k * 0.7, 0), ctr + Vector2(0, k), ctr + Vector2(-k * 0.7, 0), ctr + Vector2(0, -k)]), Color("6fb4d2"), 3.0, true)
			_terrain_badge(c, "braise")
		PuzzleModel.T_CURRENT:
			draw_style_box(_box(Color("2f86c9"), rad), r)
			for i in 3:
				var yy := r.position.y + cs * (0.3 + 0.2 * i)
				var pts := PackedVector2Array()
				for j in 9:
					pts.append(Vector2(r.position.x + cs * (0.15 + 0.0875 * j), yy + sin(j * 1.6) * cs * 0.04))
				draw_polyline(pts, Color("d7efff"), 3.0, true)
			_terrain_badge(c, "nacre")
		_:
			draw_style_box(_box(C_CELL if alt else C_CELL_ALT, rad), r)
			if t == PuzzleModel.T_BRIDGE:
				draw_style_box(_box(Color("b98a52"), rad), r.grow(-cs * 0.06))
				for i in 3:
					var xx := r.position.x + cs * (0.28 + 0.22 * i)
					draw_line(Vector2(xx, r.position.y + cs * 0.1), Vector2(xx, r.end.y - cs * 0.1), Color("7c5a33"), 3.0)
			elif t == PuzzleModel.T_MELTED:
				draw_circle(ctr, cs * 0.3, Color("cfeaf2"))
				draw_arc(ctr, cs * 0.3, 0, TAU, 24, Color("8ccadd"), 3.0, true)
			elif t == PuzzleModel.T_FROZEN:
				draw_style_box(_box(Color("dff3fb"), rad), r.grow(-cs * 0.06))
				for a in 3:
					var dir := Vector2.from_angle(a * PI / 3.0) * cs * 0.26
					draw_line(ctr - dir, ctr + dir, Color("6fb4d2"), 3.0, true)


func _terrain_badge(c: Vector2i, companion: String) -> void:
	## Petit repère du compagnon capable de transformer la case.
	var cs := cell_size()
	var p := cell_center(c) + Vector2(cs * 0.28, -cs * 0.28)
	draw_circle(p, cs * 0.13, DragonAnimator.COLORS[companion])
	draw_arc(p, cs * 0.13, 0, TAU, 20, C_INK, 2.0, true)


func _draw_path(cells: Array, pr: Dictionary, state: String, flagged: bool) -> void:
	if cells.size() < 2:
		if state == "selected" and cells.size() == 1:
			draw_arc(cell_center(cells[0]), cell_size() * 0.44, 0, TAU, 32, C_INK, 5.0, true)
		return
	var cs := cell_size()
	var pts := PackedVector2Array()
	for c in cells:
		pts.append(cell_center(c))
	var col: Color = ENERGY[pr["energy"]]
	var wd := cs * 0.34
	if state == "selected":
		draw_polyline(pts, C_INK, wd + cs * 0.12, true)   # contour épais = sélection
		_caps(pts, C_INK, (wd + cs * 0.12) / 2.0)
		draw_polyline(pts, Color.WHITE, wd + cs * 0.05, true)
		_caps(pts, Color.WHITE, (wd + cs * 0.05) / 2.0)
	else:
		draw_polyline(pts, col.darkened(0.35), wd + cs * 0.06, true)
		_caps(pts, col.darkened(0.35), (wd + cs * 0.06) / 2.0)
	draw_polyline(pts, col, wd, true)
	_caps(pts, col, wd / 2.0)
	_draw_pattern(pts, pr["pattern"], cs)
	if state == "selected":
		draw_arc(pts[pts.size() - 1], cs * 0.3, 0, TAU, 32, C_INK, 5.0, true)
	if flagged:
		for p in pts:
			draw_arc(p, cs * 0.2, 0, TAU, 16, C_INK, 4.0, true)
			draw_line(p - Vector2(cs * 0.1, 0), p + Vector2(cs * 0.1, 0), C_INK, 4.0)


func _caps(pts: PackedVector2Array, col: Color, radius: float) -> void:
	for p in pts:
		draw_circle(p, radius, col)


func _draw_pattern(pts: PackedVector2Array, pattern: String, cs: float) -> void:
	var ink := Color(1, 1, 1, 0.85)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var mid := (a + b) / 2.0
		var dir := (b - a).normalized()
		var n := Vector2(-dir.y, dir.x)
		match pattern:
			"dots":
				draw_circle(mid, cs * 0.055, ink)
			"dashes":
				draw_line(mid - dir * cs * 0.16, mid + dir * cs * 0.16, ink, cs * 0.05)
			"chevrons":
				draw_polyline(PackedVector2Array([mid - dir * cs * 0.07 + n * cs * 0.1, mid + dir * cs * 0.07, mid - dir * cs * 0.07 - n * cs * 0.1]), ink, cs * 0.04, true)
			"rings":
				draw_arc(mid, cs * 0.075, 0, TAU, 16, ink, cs * 0.03, true)
			_:
				pass  # "solid" : canal plein


func _draw_hint() -> void:
	var cs := cell_size()
	for i in hint_path.size() - 1:
		var a := cell_center(hint_path[i])
		var b := cell_center(hint_path[i + 1])
		draw_dashed_line(a, b, C_INK, cs * 0.12, cs * 0.16)
		draw_dashed_line(a, b, Color("fff3c4"), cs * 0.07, cs * 0.16)
	var tip := cell_center(hint_path[hint_path.size() - 1])
	var dir := (tip - cell_center(hint_path[hint_path.size() - 2])).normalized()
	var n := Vector2(-dir.y, dir.x)
	var k := cs * 0.2
	var tri := PackedVector2Array([tip + dir * k, tip - dir * k * 0.6 + n * k, tip - dir * k * 0.6 - n * k])
	draw_colored_polygon(tri, Color("fff3c4"))
	tri.append(tri[0])
	draw_polyline(tri, C_INK, 3.0, true)


func _draw_endpoint(pr: Dictionary, is_source: bool) -> void:
	var cs := cell_size()
	var p := cell_center(pr["source"] if is_source else pr["dest"])
	var col: Color = ENERGY[pr["energy"]]
	var done := model.paths.has(pr["id"])
	if is_source:
		# Source : vasque ronde.
		draw_circle(p, cs * 0.38, col.darkened(0.35))
		draw_circle(p, cs * 0.33, col)
	else:
		# Destination : œuf (ovale) sur son socle.
		var pts := PackedVector2Array()
		for i in 28:
			var a := TAU * i / 28.0
			var ry := cs * (0.4 if sin(a) < 0 else 0.34)
			pts.append(p + Vector2(cos(a) * cs * 0.3, sin(a) * ry + cs * 0.02))
		draw_colored_polygon(pts, Color("fbf6e6") if not done else col.lightened(0.55))
		pts.append(pts[0])
		draw_polyline(pts, col.darkened(0.2), cs * 0.06, true)
		if not model.activator_for_pair(pr["id"]).is_empty():
			# Autel d'un compagnon : couronne dorée crénelée.
			for i in 8:
				var a := TAU * i / 8.0
				draw_circle(p + Vector2.from_angle(a) * cs * 0.44, cs * 0.045, C_GOLD)
	_draw_symbol(pr["energy"], p + Vector2(0, -cs * 0.04), cs * 0.17, Color.WHITE if is_source else col.darkened(0.15))
	# Numéro de paire.
	var bp := p + Vector2(-cs * 0.3, cs * 0.3)
	draw_circle(bp, cs * 0.14, C_INK)
	var fs := int(cs * 0.2)
	draw_string(_font, bp + Vector2(-cs * 0.14, fs * 0.36), str(pr["number"]), HORIZONTAL_ALIGNMENT_CENTER, cs * 0.28, fs, Color.WHITE)
	if done and not is_source:
		# Coche = terminé (forme, pas seulement couleur).
		var cp := p + Vector2(cs * 0.3, cs * 0.3)
		draw_circle(cp, cs * 0.14, Color("3b8f4a"))
		draw_polyline(PackedVector2Array([cp + Vector2(-cs * 0.07, 0), cp + Vector2(-cs * 0.02, cs * 0.05), cp + Vector2(cs * 0.07, -cs * 0.05)]), Color.WHITE, cs * 0.04, true)


func _draw_symbol(energy: String, p: Vector2, r: float, col: Color) -> void:
	match energy:
		"water":  # goutte
			var pts := PackedVector2Array([p + Vector2(0, -r * 1.25)])
			for i in 13:
				var a := -PI * 0.15 + (PI * 1.3) * i / 12.0
				pts.append(p + Vector2(cos(a) * r * 0.8, r * 0.25 + sin(a) * r * 0.8))
			draw_colored_polygon(pts, col)
		"heat":  # flamme
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(0, -r * 1.3), p + Vector2(r * 0.45, -r * 0.4), p + Vector2(r * 0.85, -r * 0.7),
				p + Vector2(r * 0.8, r * 0.5), p + Vector2(r * 0.3, r), p + Vector2(-r * 0.3, r),
				p + Vector2(-r * 0.8, r * 0.5), p + Vector2(-r * 0.55, -r * 0.3)]), col)
		_:  # soleil
			draw_circle(p, r * 0.55, col)
			for i in 8:
				var d := Vector2.from_angle(TAU * i / 8.0)
				draw_line(p + d * r * 0.75, p + d * r * 1.2, col, r * 0.22, true)
