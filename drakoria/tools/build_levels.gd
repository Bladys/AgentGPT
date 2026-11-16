extends SceneTree
## Construit data/levels/level_001..050.json.
##   godot --headless --path . -s tools/build_levels.gd -- [from] [to]
## Les grilles faites à la main sont décrites en ASCII ci-dessous ; les autres
## sont des CANDIDATS aléatoires. Rien n'est écrit sans validation du solveur.

const PATTERNS := ["solid", "dots", "dashes", "chevrons", "rings"]
const ROLES := ["learning", "learning", "learning", "variation", "variation",
	"consolidation", "consolidation", "breather", "challenge", "challenge"]
const ROLE_TARGET := {"learning": 0.75, "variation": 0.5, "consolidation": 0.35, "breather": 0.7, "challenge": 0.12}

# Légende : A-E source, a-e destination, # obstacle, ~ vide, * glace, = courant
const HANDMADE := {
	1: {"rows": ["A..a", "....", "....", "B..b"], "energy": "ww"},
	2: {"rows": ["A.B.", ".#..", ".a..", "...b"], "energy": "ww"},
	3: {"rows": ["A...B", ".....", ".C#c.", ".....", "a...b"], "energy": "wwh"},
	4: {"rows": ["A.B.C", ".....", "..b..", ".c...", "a...."], "energy": "whh"},
	5: {"rows": ["A.C..", ".#.#.", ".a.b.", ".#.#.", "B...c"], "energy": "whl"},
	10: {"rows": ["A...B", ".b.c.", ".C.#.", ".....", "a.D.d"], "energy": "whlw"},
	11: {"rows": ["A...a", ".B...", "##~##", ".....", "..b.."], "energy": "wh",
		"activators": [{"companion": "brindille", "pair": 1, "target": [2, 2]}]},
	21: {"rows": ["A....a", ".C....", "###*##", "......", ".c.B.b", "......"], "energy": "hwl",
		"activators": [{"companion": "braise", "pair": 1, "target": [3, 2]}]},
	31: {"rows": ["A.B...", ".###=#", ".#....", ".#.b..", ".#C.c.", "a#...."], "energy": "lwh",
		"activators": [{"companion": "nacre", "pair": 1, "target": [4, 1]}]},
	41: {"rows": ["A.....a", ".B.....", "####~##", "C....b.", "###*###", "D......", "d...c.."], "energy": "whlw",
		"activators": [{"companion": "brindille", "pair": 1, "target": [4, 2]},
			{"companion": "braise", "pair": 2, "target": [3, 4]}]},
}
const ENERGY_CODE := {"w": "water", "h": "heat", "l": "light"}
const UNLOCK := {"brindille": 11, "braise": 21, "nacre": 31}

var rng := RandomNumberGenerator.new()
var seen_canon := {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var from := int(args[0]) if args.size() > 0 else 1
	var to := int(args[1]) if args.size() > 1 else 50
	DirAccess.make_dir_recursive_absolute("res://data/levels")
	# Les formes déjà utilisées (toutes les grilles existantes) sont exclues.
	for i in range(1, 51):
		if i >= from and i <= to:
			continue
		var existing := LevelLoader.load_level(i)
		if not existing.is_empty():
			seen_canon[canonical(existing)] = i
	var failures := 0
	for i in range(from, to + 1):
		var lvl: Dictionary
		if HANDMADE.has(i):
			lvl = from_ascii(i, HANDMADE[i])
		else:
			lvl = generate(i)
		if lvl.is_empty():
			printerr("ECHEC niveau %d" % i)
			failures += 1
			continue
		seen_canon[canonical(lvl)] = i
		var f := FileAccess.open("res://data/levels/level_%03d.json" % i, FileAccess.WRITE)
		f.store_string(JSON.stringify(lvl, "  ", false) + "\n")
		f.close()
		var s: Dictionary = lvl["solver"]
		print("niveau %03d %dx%d paires=%d origine=%s glouton=%.2f tendues=%d%s noeuds=%d" % [
			i, lvl["width"], lvl["height"], lvl["pairs"].size(), lvl["origin"],
			s["greedy_success_ratio"], s["taut_solutions"], "+" if s["taut_solutions_capped"] else "", s["nodes"]])
	quit(1 if failures > 0 else 0)


func plan(i: int) -> Dictionary:
	var q := (i - 1) / 10
	var role: String = ROLES[(i - 1) % 10]
	var hard := role == "challenge" or role == "consolidation"
	var size: int = [[4, 5], [5, 6], [6, 6], [6, 7], [7, 8]][q][1 if hard else 0]
	if i <= 2: size = 4
	var pairs := clampi(2 + q / 2 + (1 if hard else 0) + (1 if size >= 6 else 0), 2, 5)
	var comps: Array = []
	var pool: Array = []
	for c in ["brindille", "braise", "nacre"]:
		if i >= UNLOCK[c]:
			pool.append(c)
	if not pool.is_empty() and role != "breather":
		# Le compagnon le plus récent domine son quartier ; le dernier quartier combine.
		comps.append(pool[pool.size() - 1] if (i % 3 != 0 or pool.size() == 1) else pool[(i / 3) % pool.size()])
		if q == 4 and hard:
			for c in pool:
				if not comps.has(c) and comps.size() < (3 if i == 50 else 2):
					comps.append(c)
	var energies := ["water"]
	if i >= 3: energies.append("heat")
	if i >= 5: energies.append("light")
	return {"size": size, "pairs": maxi(pairs, comps.size() + 1), "role": role, "companions": comps, "energies": energies}


# ------------------------------------------------------------------ ASCII

func from_ascii(i: int, spec: Dictionary) -> Dictionary:
	var rows: Array = spec["rows"]
	var src := {}
	var dst := {}
	var obstacles := []
	var terrain := []
	for y in rows.size():
		for x in rows[y].length():
			var ch: String = rows[y][x]
			if ch == "#": obstacles.append([x, y])
			elif ch == "~": terrain.append({"pos": [x, y], "type": "gap"})
			elif ch == "*": terrain.append({"pos": [x, y], "type": "ice"})
			elif ch == "=": terrain.append({"pos": [x, y], "type": "current"})
			elif ch >= "A" and ch <= "E": src[ch.unicode_at(0) - 64] = [x, y]
			elif ch >= "a" and ch <= "e": dst[ch.unicode_at(0) - 96] = [x, y]
	var pairs := []
	for id in range(1, src.size() + 1):
		pairs.append({"id": id, "number": id, "energy": ENERGY_CODE[spec["energy"][id - 1]],
			"pattern": PATTERNS[id - 1], "source": src[id], "dest": dst[id]})
	var acts := []
	for a in spec.get("activators", []):
		var rule: Dictionary = RuleResolver.COMPANION_RULE[a["companion"]]
		acts.append({"id": "act_%d" % (acts.size() + 1), "companion": a["companion"], "pair": a["pair"],
			"altar": dst[a["pair"]], "target": a["target"], "from": rule["from"], "to": rule["to"]})
	return finalize(i, rows[0].length(), rows.size(), pairs, obstacles, terrain, acts, "handmade")


# ------------------------------------------------------------------ candidats

func generate(i: int) -> Dictionary:
	var pl := plan(i)
	rng.seed = 7919 * i + 104729
	var best := {}
	var best_score := 1e9
	var tries := 0
	var valid := 0
	while tries < 6000 and valid < 40:
		tries += 1
		var cand := candidate(i, pl)
		if cand.is_empty():
			continue
		var canon := canonical(cand)
		if seen_canon.has(canon):
			continue
		var s: Dictionary = cand["solver"]
		valid += 1
		var score := absf(s["greedy_success_ratio"] - ROLE_TARGET[pl["role"]]) * 10.0
		score += (0.15 if s["taut_solutions_capped"] else 0.0) + s["taut_solutions"] * 0.02
		score -= s["fill_ratio"]
		if score < best_score:
			best_score = score
			best = cand
	return best


func candidate(i: int, pl: Dictionary) -> Dictionary:
	var n: int = pl["size"]
	var k: int = pl["pairs"]
	var grid := {}
	var walks := []
	for p in k:
		var wk := random_walk(n, grid, rng.randi_range(n - 1, n * 2 + 2))
		if wk.size() < 3:
			return {}
		if absi(wk[0].x - wk[-1].x) + absi(wk[0].y - wk[-1].y) < 2:
			return {}
		for c in wk:
			grid[c] = p + 1
		walks.append(wk)
	var obstacles := []
	var p_obs := rng.randf_range(0.1, 0.55)
	for y in n:
		for x in n:
			if not grid.has(Vector2i(x, y)) and rng.randf() < p_obs:
				obstacles.append([x, y])
	# Activateurs : la cible se trouve sur le canal d'une paire tracée plus tard.
	var comps: Array = pl["companions"]
	var ids := range(1, k + 1)
	shuffle(ids)
	var acts := []
	var terrain := []
	var energy := {}
	for ci in comps.size():
		var comp: String = comps[ci]
		var ap: int = ids[ci]
		var later: Array = ids.slice(ci + 1)
		var tp: int = later[rng.randi_range(0, later.size() - 1)]
		var wk: Array = walks[tp - 1]
		if wk.size() < 3:
			return {}
		var tc: Vector2i = wk[rng.randi_range(1, wk.size() - 2)]
		var rule: Dictionary = RuleResolver.COMPANION_RULE[comp]
		terrain.append({"pos": [tc.x, tc.y], "type": rule["from"]})
		var dest: Vector2i = walks[ap - 1][-1]
		acts.append({"id": "act_%d" % (ci + 1), "companion": comp, "pair": ap,
			"altar": [dest.x, dest.y], "target": [tc.x, tc.y], "from": rule["from"], "to": rule["to"]})
		energy[ap] = RuleResolver.COMPANION_ENERGY[comp]
	var pairs := []
	for id in range(1, k + 1):
		var wk: Array = walks[id - 1]
		var e: String = energy.get(id, pl["energies"][rng.randi_range(0, pl["energies"].size() - 1)])
		pairs.append({"id": id, "number": id, "energy": e, "pattern": PATTERNS[id - 1],
			"source": [wk[0].x, wk[0].y], "dest": [wk[-1].x, wk[-1].y]})
	return finalize(i, n, n, pairs, obstacles, terrain, acts, "generated_candidate")


func random_walk(n: int, grid: Dictionary, want: int) -> Array:
	var free := []
	for y in n:
		for x in n:
			if not grid.has(Vector2i(x, y)):
				free.append(Vector2i(x, y))
	if free.is_empty():
		return []
	var cur: Vector2i = free[rng.randi_range(0, free.size() - 1)]
	var path := [cur]
	while path.size() < want:
		var opts := []
		for d in Solver.DIRS:
			var c: Vector2i = cur + d
			if c.x < 0 or c.y < 0 or c.x >= n or c.y >= n or grid.has(c) or c in path:
				continue
			var touch := 0
			for d2 in Solver.DIRS:
				if (c + d2) in path:
					touch += 1
			if touch == 1:
				opts.append(c)
		if opts.is_empty():
			break
		cur = opts[rng.randi_range(0, opts.size() - 1)]
		path.append(cur)
	return path


func shuffle(a: Array) -> void:
	for j in range(a.size() - 1, 0, -1):
		var r := rng.randi_range(0, j)
		var t = a[j]; a[j] = a[r]; a[r] = t


# ------------------------------------------------------------------ validation

func finalize(i: int, w: int, h: int, pairs: Array, obstacles: Array, terrain: Array, acts: Array, origin: String) -> Dictionary:
	var pl := plan(i)
	var req = null
	for a in acts:
		if req == null or UNLOCK[a["companion"]] > UNLOCK[req]:
			req = a["companion"]
	var lvl := {
		"version": 1, "schema": "drakoria.level/1", "id": "level_%03d" % i, "index": i,
		"island": 1, "district": (i - 1) / 10 + 1, "role": pl["role"], "origin": origin,
		"human_playtested": false,
		"width": w, "height": h, "pairs": pairs, "obstacles": obstacles, "terrain": terrain,
		"activators": acts, "objectives": ["connect_all"], "required_companion": req,
		"presentation": {
			"background": "bg_island_1", "tint": "tint_district_%d" % ((i - 1) / 10 + 1),
			"props": ["prop_set_%d" % ((i - 1) % 4 + 1)], "music": "music_island_1",
			"ambience": "amb_island_1",
		},
	}
	var model := PuzzleModel.new()
	model.load_level(lvl)
	var an := Solver.analyze(model, 12, 150000 if origin != "handmade" else 2000000)
	if not an["solvable"]:
		if origin == "handmade":
			printerr("  fait main %d insoluble : %s" % [i, an["status"]])
		return {}
	for a in acts:
		if not an["requires_activation"][a["id"]]:
			if origin == "handmade":
				printerr("  fait main %d : activateur %s non nécessaire" % [i, a["id"]])
			return {}
	# La solution de référence est rejouée par l'API de geste du modèle.
	var ref := {}
	for pid in an["order"]:
		if not model.apply_path(pid, an["reference"][pid]):
			return {}
		var cells := []
		for c in an["reference"][pid]:
			cells.append([c.x, c.y])
		ref[str(pid)] = cells
	if not model.completed or model.validate() != "":
		return {}
	lvl["reference_solution"] = {"order": an["order"], "paths": ref}
	lvl["solver"] = {
		"solver_version": 1, "solvable": true, "nodes": an["nodes"],
		"taut_solutions": an["taut_solutions"], "taut_solutions_capped": an["taut_solutions_capped"],
		"unique_taut_solution": an["taut_solutions"] == 1 and not an["taut_solutions_capped"],
		"activators_required": an["requires_activation"],
		"greedy_success_ratio": snappedf(an["greedy_success_ratio"], 0.001),
		"fill_ratio": snappedf(an["fill_ratio"], 0.001),
		"measured_difficulty": difficulty(an),
	}
	return lvl


static func difficulty(an: Dictionary) -> String:
	var g: float = an["greedy_success_ratio"]
	if g >= 0.65: return "easy"
	if g >= 0.3: return "medium"
	return "hard"


static func canonical(lvl: Dictionary) -> String:
	## Forme canonique sous les 8 symétries du carré, énergies ignorées.
	var w: int = lvl["width"]
	var h: int = lvl["height"]
	var best := ""
	for sym in 8:
		var parts := []
		for p in lvl["pairs"]:
			var a := _sym(p["source"], w, h, sym)
			var b := _sym(p["dest"], w, h, sym)
			var lo := mini(a, b)
			parts.append("p%d-%d" % [lo, maxi(a, b)])
		for o in lvl["obstacles"]:
			parts.append("o%d" % _sym(o, w, h, sym))
		for t in lvl["terrain"]:
			parts.append("t%d" % _sym(t["pos"], w, h, sym))
		parts.sort()
		var s := "%dx%d|" % [w, h] + ",".join(parts)
		if best == "" or s < best:
			best = s
	return best


static func _sym(c, w: int, h: int, sym: int) -> int:
	var x := int(c[0])
	var y := int(c[1])
	if sym & 1: x = w - 1 - x
	if sym & 2: y = h - 1 - y
	if sym & 4:
		var t := x; x = y; y = t
	return y * 64 + x
