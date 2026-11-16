class_name Solver
extends RefCounted
## Solveur de référence : dépendances d'activation, recherche de solutions,
## mesures de difficulté et indices. Partagé par le jeu, le générateur de
## candidats et les tests.
##
## Les solutions recherchées sont « tendues » : un canal ne longe jamais
## lui-même. Toute solution avec détour peut être raccourcie en solution
## tendue utilisant un sous-ensemble de ses cases ; la solvabilité est donc
## préservée et le nombre de solutions devient une mesure exploitable.

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

var w := 0
var h := 0
var _occ := PackedInt32Array()   # -1 bloqué, 0 libre, pid occupé, 100+pid destination libre
var _order: Array = []
var _src: Dictionary = {}
var _dst: Dictionary = {}
var _cur: Dictionary = {}        # pid -> Array[int] chemin en cours (indices)
var _solutions: Array = []
var _max_solutions := 1
var _budget := 0
var nodes := 0
var _label := PackedInt32Array()
var _stack := PackedInt32Array()


# ------------------------------------------------------------------ API haut niveau

static func final_terrain(model: PuzzleModel, base: PackedInt32Array, fired_ids: Dictionary) -> PackedInt32Array:
	var t := base.duplicate()
	for a in model.activators:
		if fired_ids.has(a["id"]):
			t[model.idx(a["target"])] = a["to"]
	return t


static func activation_closure(model: PuzzleModel, start_fired: Dictionary = {}) -> Dictionary:
	## Ensemble des activateurs déclenchables, les autres canaux étant effaçables.
	var f := start_fired.duplicate()
	var changed := true
	while changed:
		changed = false
		for a in model.activators:
			if f.has(a["id"]):
				continue
			var t := final_terrain(model, model.initial_terrain, f)
			if not shortest_path(model, t, a["pair"], {}).is_empty():
				f[a["id"]] = true
				changed = true
	return f


static func shortest_path(model: PuzzleModel, t: PackedInt32Array, pid: int, blocked: Dictionary) -> Array:
	## Plus court chemin (BFS déterministe) pour une paire ; [] si aucun.
	var pr: Dictionary = model.pair_by_id[pid]
	var s: Vector2i = pr["source"]
	var d: Vector2i = pr["dest"]
	var prev := {s: s}
	var queue: Array[Vector2i] = [s]
	var qi := 0
	while qi < queue.size():
		var c := queue[qi]
		qi += 1
		if c == d:
			var path := [d]
			while path[0] != s:
				path.push_front(prev[path[0]])
			return path
		for dir in DIRS:
			var n := c + dir
			if not model.in_bounds(n) or prev.has(n) or blocked.has(n):
				continue
			var i := model.idx(n)
			if not PuzzleModel.passable_terrain(t[i]):
				continue
			var o := model.endpoint_owner[i]
			if o != 0 and (o != pid or n == s):
				continue
			prev[n] = c
			queue.append(n)
	return []


static func solve(model: PuzzleModel, t: PackedInt32Array, fixed: Dictionary,
		max_solutions := 1, budget := 200000) -> Dictionary:
	## Cherche des canaux pour toutes les paires non fixées sur le terrain t.
	## status : "solved", "unsolvable" (preuve exhaustive) ou "budget".
	var s := Solver.new()
	return s._run(model, t, fixed, max_solutions, budget)


static func drawing_order(model: PuzzleModel, sol: Dictionary, t0: PackedInt32Array,
		fired0: Dictionary, already: Dictionary) -> Array:
	## Ordre de tracé des paires de `sol` absentes de `already`, tel que chaque
	## canal ne traverse que des cases praticables au moment du tracé.
	## [] si aucun ordre n'existe sans canal temporaire (ou si rien à tracer).
	var t := t0.duplicate()
	var fired := fired0.duplicate()
	var todo: Array = []
	for pr in model.pairs:
		if not already.has(pr["id"]):
			todo.append(pr["id"])
	var order: Array = []
	while not todo.is_empty():
		var picked := 0
		for pid in todo:
			var ok := true
			for c in sol[pid]:
				if not PuzzleModel.passable_terrain(t[model.idx(c)]):
					ok = false
					break
			if ok:
				picked = pid
				break
		if picked == 0:
			return []
		order.append(picked)
		todo.erase(picked)
		var a := model.activator_for_pair(picked)
		if not a.is_empty() and not fired.has(a["id"]):
			fired[a["id"]] = true
			t[model.idx(a["target"])] = a["to"]
	return order


static func analyze(model: PuzzleModel, max_solutions := 12, budget := 400000) -> Dictionary:
	## Analyse complète d'un niveau depuis son état initial.
	var res := {"solvable": false, "status": "", "nodes": 0, "taut_solutions": 0,
		"taut_solutions_capped": false, "reference": {}, "order": [],
		"requires_activation": {}, "greedy_success_ratio": 1.0, "fill_ratio": 0.0}
	var closure := activation_closure(model)
	if closure.size() != model.activators.size():
		res["status"] = "activation_unreachable"
		return res
	var tf := final_terrain(model, model.initial_terrain, closure)
	var r := solve(model, tf, {}, max_solutions, budget)
	res["nodes"] = r["nodes"]
	res["status"] = r["status"]
	if r["solutions"].is_empty():
		return res
	res["taut_solutions"] = r["solutions"].size()
	res["taut_solutions_capped"] = not r["exhausted"]
	for sol in r["solutions"]:
		var order := drawing_order(model, sol, model.initial_terrain, {}, {})
		if not order.is_empty():
			res["reference"] = sol
			res["order"] = order
			break
	if res["reference"].is_empty():
		res["status"] = "no_ordered_solution"
		return res
	res["solvable"] = true
	res["status"] = "solved"
	for a in model.activators:
		var tb := tf.duplicate()
		tb[model.idx(a["target"])] = a["from"]
		var rb := solve(model, tb, {}, 1, budget)
		res["requires_activation"][a["id"]] = rb["status"] == "unsolvable"
	res["greedy_success_ratio"] = greedy_ratio(model, tf)
	var used := 0
	var free := 0
	for pid in res["reference"]:
		used += res["reference"][pid].size()
	for v in tf:
		if PuzzleModel.passable_terrain(v):
			free += 1
	res["fill_ratio"] = float(used) / float(maxi(free, 1))
	return res


static func greedy_ratio(model: PuzzleModel, t: PackedInt32Array) -> float:
	## Part des ordres de paires pour lesquels « toujours le plus court chemin »
	## résout la grille. 1.0 = trivial ; proche de 0 = demande de la réflexion.
	var ids: Array = []
	for pr in model.pairs:
		ids.append(pr["id"])
	var perms: Array = []
	_permute(ids, 0, perms)
	var ok := 0
	for perm in perms:
		var blocked := {}
		var good := true
		for pid in perm:
			var p := shortest_path(model, t, pid, blocked)
			if p.is_empty():
				good = false
				break
			for c in p:
				blocked[c] = true
		if good:
			ok += 1
	return float(ok) / float(perms.size())


static func _permute(a: Array, k: int, out: Array) -> void:
	if k == a.size():
		out.append(a.duplicate())
		return
	for i in range(k, a.size()):
		var tmp = a[k]; a[k] = a[i]; a[i] = tmp
		_permute(a, k + 1, out)
		tmp = a[k]; a[k] = a[i]; a[i] = tmp


# ------------------------------------------------------------------ indices

static func hint(model: PuzzleModel, reference: Dictionary, budget := 40000) -> Dictionary:
	## Indice compatible avec l'état validé actuel.
	## {kind:"segment", pair, path, temporary} | {kind:"remove", pair} | {kind:"none"}
	if model.completed:
		return {"kind": "none"}
	var committed: Dictionary = model.paths
	var closure := activation_closure(model, model.fired)
	var tf := final_terrain(model, model.initial_terrain, closure)
	var taken := {}
	for pid in committed:
		for c in committed[pid]:
			taken[c] = pid
	# 1. Voie rapide : la solution de référence reste compatible.
	var sol := {}
	var compatible := not reference.is_empty()
	var conflict := 0
	if compatible:
		for pr in model.pairs:
			var pid: int = pr["id"]
			if committed.has(pid):
				sol[pid] = committed[pid]
				continue
			sol[pid] = reference[pid]
			for c in reference[pid]:
				if taken.has(c):
					compatible = false
					conflict = taken[c]
	# 2. Sinon, recherche d'une solution prolongeant les canaux validés.
	var searched := "skipped"
	if not compatible:
		var r := solve(model, tf, committed, 6, budget)
		searched = r["status"]
		sol = {}
		for cand in r["solutions"]:
			if sol.is_empty():
				sol = cand
			if not drawing_order(model, cand, model.terrain, model.fired, committed).is_empty():
				sol = cand
				break
	if not sol.is_empty():
		var order := drawing_order(model, sol, model.terrain, model.fired, committed)
		if not order.is_empty():
			return {"kind": "segment", "pair": order[0], "path": sol[order[0]], "temporary": false}
		# Dépendance cyclique : un canal temporaire doit d'abord activer un pouvoir.
		for a in model.activators:
			if model.fired.has(a["id"]) or committed.has(a["pair"]):
				continue
			var p := shortest_path(model, model.terrain, a["pair"], taken)
			if not p.is_empty():
				return {"kind": "segment", "pair": a["pair"], "path": p, "temporary": true}
	# 3. Aucun prolongement : proposer de retirer un canal bloquant.
	if committed.is_empty():
		return {"kind": "none"}
	var ids: Array = committed.keys()
	ids.reverse()  # le plus récent d'abord
	if searched == "unsolvable":
		for pid in ids:
			var rest := committed.duplicate()
			rest.erase(pid)
			if not solve(model, tf, rest, 1, budget / 2)["solutions"].is_empty():
				return {"kind": "remove", "pair": pid}
	if conflict != 0:
		return {"kind": "remove", "pair": conflict}
	return {"kind": "remove", "pair": ids[0]}


# ------------------------------------------------------------------ recherche

func _run(model: PuzzleModel, t: PackedInt32Array, fixed: Dictionary, max_solutions: int, budget: int) -> Dictionary:
	w = model.width
	h = model.height
	_max_solutions = max_solutions
	_budget = budget
	_occ.resize(w * h)
	_label.resize(w * h)
	for i in w * h:
		_occ[i] = 0 if PuzzleModel.passable_terrain(t[i]) else -1
	var todo: Array = []
	for pr in model.pairs:
		var pid: int = pr["id"]
		var si := model.idx(pr["source"])
		var di := model.idx(pr["dest"])
		if fixed.has(pid):
			for c in fixed[pid]:
				_occ[model.idx(c)] = -1
		else:
			_occ[si] = pid
			_occ[di] = 100 + pid
			_src[pid] = si
			_dst[pid] = di
			todo.append(pid)
	# Paires les plus contraintes d'abord.
	todo.sort_custom(func(a, b):
		var ka := _free_neighbors(_src[a]) + _free_neighbors(_dst[a])
		var kb := _free_neighbors(_src[b]) + _free_neighbors(_dst[b])
		return ka < kb if ka != kb else a < b)
	_order = todo
	var exhausted := true
	if _order.is_empty():
		_solutions.append({})
	elif _feasible(0, _src[_order[0]]):
		_cur[_order[0]] = [_src[_order[0]]]
		exhausted = _dfs(0, _src[_order[0]])
	var out: Array = []
	for s in _solutions:
		var full := {}
		for pid in fixed:
			full[pid] = fixed[pid]
		for pid in s:
			var cells := []
			for i in s[pid]:
				cells.append(Vector2i(i % w, i / w))
			full[pid] = cells
		out.append(full)
	var status := "solved"
	if out.is_empty():
		status = "unsolvable" if exhausted else "budget"
	return {"status": status, "solutions": out, "nodes": nodes, "exhausted": exhausted}


func _free_neighbors(i: int) -> int:
	var n := 0
	for j in _neighbors(i):
		if _occ[j] == 0:
			n += 1
	return n


func _neighbors(i: int) -> Array[int]:
	var out: Array[int] = []
	var x := i % w
	if x + 1 < w: out.append(i + 1)
	if i + w < w * h: out.append(i + w)
	if x > 0: out.append(i - 1)
	if i - w >= 0: out.append(i - w)
	return out


func _dfs(k: int, head: int) -> bool:
	## Renvoie false si la recherche a été interrompue (budget ou quota atteint).
	nodes += 1
	if nodes > _budget:
		return false
	var pid: int = _order[k]
	var dest: int = _dst[pid]
	var nb := _neighbors(head)
	if dest in nb:
		# Chemin tendu : adjacent à la destination => on termine.
		_cur[pid].append(dest)
		_occ[dest] = pid
		var cont := true
		if k + 1 == _order.size():
			var snap := {}
			for p in _cur:
				snap[p] = _cur[p].duplicate()
			_solutions.append(snap)
			cont = _solutions.size() < _max_solutions
		else:
			var nxt: int = _order[k + 1]
			_cur[nxt] = [_src[nxt]]
			cont = _dfs(k + 1, _src[nxt])
			_cur.erase(nxt)
		_occ[dest] = 100 + pid
		_cur[pid].pop_back()
		return cont
	for n in nb:
		if _occ[n] != 0:
			continue
		var touching := 0
		for m in _neighbors(n):
			if _occ[m] == pid:
				touching += 1
		if touching != 1:
			continue
		_occ[n] = pid
		_cur[pid].append(n)
		var cont := true
		if _feasible(k, n):
			cont = _dfs(k, n)
		_cur[pid].pop_back()
		_occ[n] = 0
		if not cont:
			return false
	return true


func _feasible(k: int, head: int) -> bool:
	## Chaque paire restante doit garder ses extrémités dans une même zone libre.
	_label.fill(0)
	var next_label := 0
	for kk in range(k, _order.size()):
		var pid: int = _order[kk]
		var a: int = head if kk == k else _src[pid]
		var b: int = _dst[pid]
		var na := _neighbors(a)
		if b in na:
			continue
		var ok := false
		for s in na:
			if _occ[s] != 0:
				continue
			if _label[s] == 0:
				next_label += 1
				_flood(s, next_label)
			for e in _neighbors(b):
				if _occ[e] == 0 and _label[e] == _label[s]:
					ok = true
					break
			if ok:
				break
		if not ok:
			return false
	return true


func _flood(start: int, lab: int) -> void:
	_stack.clear()
	_stack.append(start)
	_label[start] = lab
	while not _stack.is_empty():
		var c := _stack[_stack.size() - 1]
		_stack.remove_at(_stack.size() - 1)
		for n in _neighbors(c):
			if _occ[n] == 0 and _label[n] == 0:
				_label[n] = lab
				_stack.append(n)
