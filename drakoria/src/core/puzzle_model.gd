class_name PuzzleModel
extends RefCounted
## Modèle déterministe d'un puzzle. Aucune dépendance à la scène, à l'animation
## ou au temps. Les vues rejouent `drain_events()` ; elles ne modifient jamais
## le modèle et ne déterminent jamais la victoire.

const STATE_VERSION := 1
const MAX_UNDO := 400

# Terrain
const T_FREE := 0
const T_OBSTACLE := 1
const T_GAP := 2       # vide infranchissable -> pont (Brindille)
const T_ICE := 3       # glace -> fondue (Braise)
const T_CURRENT := 4   # courant -> gelé (Nacre)
const T_BRIDGE := 5
const T_MELTED := 6
const T_FROZEN := 7

const TERRAIN_NAMES := {
	"free": T_FREE, "obstacle": T_OBSTACLE, "gap": T_GAP, "ice": T_ICE,
	"current": T_CURRENT, "bridge": T_BRIDGE, "melted": T_MELTED, "frozen": T_FROZEN,
}

var level: Dictionary = {}
var level_id := ""
var width := 0
var height := 0
var pairs: Array = []            # [{id, energy, pattern, number, source:Vector2i, dest:Vector2i}]
var pair_by_id: Dictionary = {}
var activators: Array = []       # [{id, companion, pair, target:Vector2i, from:int, to:int}]
var objectives: Array = []

var initial_terrain := PackedInt32Array()
var endpoint_owner := PackedInt32Array()  # id de paire sur source/destination, 0 sinon

# --- État validé (sauvegardable, annulable) ---
var terrain := PackedInt32Array()
var paths: Dictionary = {}       # pair_id -> Array[Vector2i] (uniquement des canaux validés)
var fired: Dictionary = {}       # activator_id -> true
var moves := 0                   # compteur de gestes ayant modifié l'état
var completed := false

# --- État transitoire ---
var draft_pair := 0
var draft: Array = []
var _gesture_snapshot: Dictionary = {}
var _undo: Array = []
var _events: Array = []


static func idx_of(p: Vector2i, w: int) -> int:
	return p.y * w + p.x


func idx(p: Vector2i) -> int:
	return p.y * width + p.x


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


static func to_v(a) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


static func passable_terrain(t: int) -> bool:
	return t == T_FREE or t == T_BRIDGE or t == T_MELTED or t == T_FROZEN


func load_level(data: Dictionary) -> void:
	level = data
	level_id = str(data.get("id", ""))
	width = int(data["width"])
	height = int(data["height"])
	pairs = []
	pair_by_id = {}
	initial_terrain = PackedInt32Array()
	initial_terrain.resize(width * height)
	endpoint_owner = PackedInt32Array()
	endpoint_owner.resize(width * height)
	for o in data.get("obstacles", []):
		initial_terrain[idx(to_v(o))] = T_OBSTACLE
	for t in data.get("terrain", []):
		initial_terrain[idx(to_v(t["pos"]))] = int(TERRAIN_NAMES[t["type"]])
	for p in data["pairs"]:
		var pr := {
			"id": int(p["id"]), "energy": str(p["energy"]), "pattern": str(p.get("pattern", "")),
			"number": int(p.get("number", p["id"])),
			"source": to_v(p["source"]), "dest": to_v(p["dest"]),
		}
		pairs.append(pr)
		pair_by_id[pr["id"]] = pr
		endpoint_owner[idx(pr["source"])] = pr["id"]
		endpoint_owner[idx(pr["dest"])] = pr["id"]
	activators = []
	for a in data.get("activators", []):
		activators.append({
			"id": str(a["id"]), "companion": str(a["companion"]), "pair": int(a["pair"]),
			"target": to_v(a["target"]),
			"from": int(TERRAIN_NAMES[a["from"]]), "to": int(TERRAIN_NAMES[a["to"]]),
		})
	objectives = data.get("objectives", ["connect_all"])
	restart(false)
	_undo.clear()
	_events.clear()


# ---------------------------------------------------------------- requêtes

func terrain_at(p: Vector2i) -> int:
	return terrain[idx(p)]


func is_pair_connected(pair_id: int) -> bool:
	return paths.has(pair_id)


func connected_count() -> int:
	return paths.size()


func occupant(p: Vector2i) -> int:
	## Paire dont le canal validé occupe la case (0 si aucune).
	for pid in paths:
		if p in paths[pid]:
			return pid
	return 0


func activator_for_pair(pair_id: int) -> Dictionary:
	for a in activators:
		if a["pair"] == pair_id:
			return a
	return {}


func can_undo() -> bool:
	return not _undo.is_empty()


func drain_events() -> Array:
	var e := _events
	_events = []
	return e


func drain_last_refusal() -> void:
	## Retire le dernier refus de la file (essai d'axe alternatif du contrôleur).
	if not _events.is_empty() and _events[_events.size() - 1]["type"] == "segment_refused":
		_events.pop_back()


func _emit(type: String, payload: Dictionary = {}) -> void:
	payload["type"] = type
	_events.append(payload)


# ---------------------------------------------------------------- gestes

func begin_draft(cell: Vector2i) -> bool:
	## Toucher une source ou un segment d'un canal validé pour le reprendre.
	if draft_pair != 0 or completed or not in_bounds(cell):
		return false
	var pid := 0
	var start: Array = []
	var owner := endpoint_owner[idx(cell)]
	if owner != 0 and pair_by_id[owner]["source"] == cell:
		pid = owner
		start = [cell]
	else:
		pid = occupant(cell)
		if pid == 0:
			return false
		var path: Array = paths[pid]
		start = path.slice(0, path.find(cell) + 1)
	_gesture_snapshot = _snapshot()
	draft_pair = pid
	draft = start
	if paths.has(pid):
		# Le canal est repris : la connexion n'est plus validée tant que le
		# doigt n'est pas relâché sur la destination.
		paths.erase(pid)
		_emit("pair_released", {"pair": pid})
	_emit("draft_started", {"pair": pid, "cell": cell, "length": draft.size()})
	return true


func extend_draft(cell: Vector2i) -> String:
	## Renvoie "added", "removed", "noop" ou "refused:<raison>". Un refus laisse
	## l'état strictement inchangé.
	if draft_pair == 0:
		return "noop"
	var tip: Vector2i = draft[draft.size() - 1]
	if cell == tip:
		return "noop"
	if not in_bounds(cell):
		return "refused:bounds"
	if absi(cell.x - tip.x) + absi(cell.y - tip.y) != 1:
		return "refused:not_adjacent"
	if draft.size() >= 2 and draft[draft.size() - 2] == cell:
		draft.pop_back()
		_emit("segment_removed", {"pair": draft_pair, "cell": tip})
		return "removed"
	var pr: Dictionary = pair_by_id[draft_pair]
	var reason := ""
	if tip == pr["dest"]:
		reason = "terminated"
	elif cell in draft:
		reason = "self"
	elif not passable_terrain(terrain[idx(cell)]):
		reason = "blocked"
	elif endpoint_owner[idx(cell)] != 0 and endpoint_owner[idx(cell)] != draft_pair:
		reason = "foreign_endpoint"
	elif occupant(cell) != 0:
		reason = "occupied"
	if reason != "":
		_emit("segment_refused", {"pair": draft_pair, "cell": cell, "reason": reason})
		return "refused:" + reason
	draft.append(cell)
	_emit("segment_added", {"pair": draft_pair, "cell": cell, "length": draft.size()})
	return "added"


func end_draft() -> bool:
	## Relâcher le doigt. Valide si la pointe est sur la destination de la paire,
	## sinon annule le tracé non validé. Renvoie true si connexion validée.
	if draft_pair == 0:
		return false
	var pid := draft_pair
	var pr: Dictionary = pair_by_id[pid]
	var tip: Vector2i = draft[draft.size() - 1]
	var connected: bool = tip == pr["dest"]
	var d := draft
	draft_pair = 0
	draft = []
	if connected:
		paths[pid] = d
		_emit("pair_connected", {"pair": pid, "energy": pr["energy"], "cell": tip, "path": d.duplicate()})
		RuleResolver.resolve_connection(self, pid)
	else:
		_emit("draft_cancelled", {"pair": pid})
	_finish_gesture()
	if connected:
		_check_victory()
	return connected


func abort_draft() -> void:
	## Interruption système (pause, changement de scène) : restaure l'état
	## d'avant le geste, sans entrée d'annulation.
	if draft_pair == 0:
		return
	var pid := draft_pair
	draft_pair = 0
	draft = []
	_restore(_gesture_snapshot)
	_gesture_snapshot = {}
	_emit("draft_cancelled", {"pair": pid})
	_emit("state_restored", {"cause": "abort"})


func _finish_gesture() -> void:
	var changed := not _same_committed(_gesture_snapshot)
	if changed:
		moves += 1
		_undo.append(_gesture_snapshot)
		if _undo.size() > MAX_UNDO:
			_undo.pop_front()
	_gesture_snapshot = {}


func apply_path(pair_id: int, cells: Array) -> bool:
	## Trace un canal complet via l'API de geste (solveur, tests, indice).
	if cells.is_empty() or not begin_draft(cells[0]):
		return false
	for i in range(1, cells.size()):
		if extend_draft(cells[i]) != "added":
			break
	return end_draft() and paths.has(pair_id) and paths[pair_id] == cells


func remove_path(pair_id: int) -> bool:
	## Retire un canal validé (équivalent à toucher la source puis relâcher).
	if not paths.has(pair_id):
		return false
	begin_draft(pair_by_id[pair_id]["source"])
	end_draft()
	return true


# ---------------------------------------------------------------- annuler / recommencer

func undo() -> bool:
	if draft_pair != 0 or _undo.is_empty():
		return false
	_restore(_undo.pop_back())
	_emit("state_restored", {"cause": "undo"})
	return true


func restart(emit := true) -> void:
	draft_pair = 0
	draft = []
	_gesture_snapshot = {}
	terrain = initial_terrain.duplicate()
	paths = {}
	fired = {}
	moves = 0
	completed = false
	_undo.clear()
	if emit:
		_emit("state_restored", {"cause": "restart"})


func _snapshot() -> Dictionary:
	var p := {}
	for pid in paths:
		p[pid] = paths[pid].duplicate()
	return {"terrain": terrain.duplicate(), "paths": p, "fired": fired.duplicate(),
		"moves": moves, "completed": completed}


func _restore(s: Dictionary) -> void:
	terrain = s["terrain"].duplicate()
	paths = {}
	for pid in s["paths"]:
		paths[pid] = s["paths"][pid].duplicate()
	fired = s["fired"].duplicate()
	moves = s["moves"]
	completed = s["completed"]


func _same_committed(s: Dictionary) -> bool:
	return s["terrain"] == terrain and s["paths"] == paths and s["fired"] == fired


func committed_equals(other: Dictionary) -> bool:
	return _same_committed(other) and other["moves"] == moves and other["completed"] == completed


func snapshot() -> Dictionary:
	return _snapshot()


# ---------------------------------------------------------------- victoire

func _check_victory() -> void:
	if completed:
		return
	if RuleResolver.objectives_met(self):
		completed = true
		_emit("level_completed", {"level": level_id, "moves": moves})


# ---------------------------------------------------------------- persistance

func to_dict() -> Dictionary:
	## État validé uniquement : un tracé en cours n'est jamais sauvegardé.
	var s := _gesture_snapshot if draft_pair != 0 else _snapshot()
	return {
		"state_version": STATE_VERSION, "level": level_id,
		"level_version": int(level.get("version", 1)),
		"state": _encode(s),
		"undo": _undo.slice(maxi(0, _undo.size() - 60)).map(_encode),
	}


func from_dict(d: Dictionary) -> bool:
	## Recharge un état sauvegardé. Toute incohérence => état initial (false).
	if int(d.get("state_version", -1)) != STATE_VERSION or str(d.get("level", "")) != level_id \
			or int(d.get("level_version", -1)) != int(level.get("version", 1)):
		return false
	var s = _decode(d.get("state"))
	if s == null:
		return false
	var undo_list: Array = []
	for u in d.get("undo", []):
		var du = _decode(u)
		if du == null:
			return false
		undo_list.append(du)
	restart(false)
	_restore(s)
	if validate() != "":
		restart(false)
		return false
	_undo = undo_list
	for u in undo_list:
		var keep := _snapshot()
		_restore(u)
		var err := validate()
		_restore(keep)
		if err != "":
			_undo = []
			break
	return true


func _encode(s: Dictionary) -> Dictionary:
	var p := {}
	for pid in s["paths"]:
		var flat := []
		for c in s["paths"][pid]:
			flat.append([c.x, c.y])
		p[str(pid)] = flat
	return {"terrain": Array(s["terrain"]), "paths": p, "fired": s["fired"].keys(),
		"moves": s["moves"], "completed": s["completed"]}


func _decode(e):
	if typeof(e) != TYPE_DICTIONARY:
		return null
	for k in ["terrain", "paths", "fired", "moves", "completed"]:
		if not e.has(k):
			return null
	if typeof(e["terrain"]) != TYPE_ARRAY or e["terrain"].size() != width * height:
		return null
	var t := PackedInt32Array()
	for v in e["terrain"]:
		t.append(int(v))
	var p := {}
	if typeof(e["paths"]) != TYPE_DICTIONARY or typeof(e["fired"]) != TYPE_ARRAY:
		return null
	for k in e["paths"]:
		var cells := []
		if typeof(e["paths"][k]) != TYPE_ARRAY:
			return null
		for c in e["paths"][k]:
			if typeof(c) != TYPE_ARRAY or c.size() != 2:
				return null
			cells.append(Vector2i(int(c[0]), int(c[1])))
		p[int(k)] = cells
	var f := {}
	for a in e["fired"]:
		f[str(a)] = true
	return {"terrain": t, "paths": p, "fired": f, "moves": int(e["moves"]), "completed": bool(e["completed"])}


func validate() -> String:
	## Vérifie tous les invariants de l'état validé. "" si cohérent.
	if terrain.size() != width * height:
		return "terrain_size"
	var expected := initial_terrain.duplicate()
	for a in activators:
		if fired.has(a["id"]):
			expected[idx(a["target"])] = a["to"]
	for k in fired:
		var known := false
		for a in activators:
			known = known or a["id"] == k
		if not known:
			return "unknown_activator"
	if expected != terrain:
		return "terrain_mismatch"
	var used := {}
	for pid in paths:
		if not pair_by_id.has(pid):
			return "unknown_pair"
		var path: Array = paths[pid]
		var pr: Dictionary = pair_by_id[pid]
		if path.size() < 2 or path[0] != pr["source"] or path[path.size() - 1] != pr["dest"]:
			return "path_endpoints"
		for i in path.size():
			var c: Vector2i = path[i]
			if not in_bounds(c):
				return "path_bounds"
			if i > 0 and absi(c.x - path[i - 1].x) + absi(c.y - path[i - 1].y) != 1:
				return "path_not_orthogonal"
			if used.has(c):
				return "path_overlap"
			used[c] = true
			if not passable_terrain(terrain[idx(c)]):
				return "path_on_blocked"
			var o := endpoint_owner[idx(c)]
			if o != 0 and o != pid:
				return "path_on_foreign_endpoint"
			if c == pr["dest"] and i != path.size() - 1:
				return "path_through_dest"
		var act := activator_for_pair(pid)
		if not act.is_empty() and not fired.has(act["id"]):
			return "activator_not_fired"
	if completed != RuleResolver.objectives_met(self):
		return "completed_flag"
	return ""
