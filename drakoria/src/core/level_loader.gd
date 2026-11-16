class_name LevelLoader
extends RefCounted
## Charge et valide le schéma des grilles jouables (data/levels).

const SCHEMA := "drakoria.level/1"
const PLAYABLE_COUNT := 50


static func path_for(index: int) -> String:
	return "res://data/levels/level_%03d.json" % index


static func load_level(index: int) -> Dictionary:
	var p := path_for(index)
	if not FileAccess.file_exists(p):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(p))
	if typeof(data) != TYPE_DICTIONARY or schema_error(data) != "":
		return {}
	return data


static func reference_paths(level: Dictionary) -> Dictionary:
	var out := {}
	var ref: Dictionary = level.get("reference_solution", {}).get("paths", {})
	for k in ref:
		var cells := []
		for c in ref[k]:
			cells.append(Vector2i(int(c[0]), int(c[1])))
		out[int(k)] = cells
	return out


static func schema_error(d: Dictionary) -> String:
	for k in ["id", "version", "width", "height", "pairs", "obstacles", "activators",
			"objectives", "reference_solution", "solver"]:
		if not d.has(k):
			return "missing:" + k
	if d.get("schema", "") != SCHEMA:
		return "schema"
	var w := int(d["width"])
	var h := int(d["height"])
	if w != h or w < 4 or w > 8:
		return "size"
	var n: int = d["pairs"].size()
	if n < 2 or n > 5:
		return "pair_count"
	var cells := {}
	for p in d["pairs"]:
		if not (p.get("energy", "") in ["water", "heat", "light"]):
			return "energy"
		if str(p.get("pattern", "")) == "" or not p.has("number"):
			return "pair_identity"
		for key in ["source", "dest"]:
			var c := Vector2i(int(p[key][0]), int(p[key][1]))
			if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h or cells.has(c):
				return "endpoint"
			cells[c] = true
	for o in d["obstacles"]:
		var c := Vector2i(int(o[0]), int(o[1]))
		if cells.has(c):
			return "obstacle_overlap"
		cells[c] = true
	var terrain := {}
	for t in d.get("terrain", []):
		var c := Vector2i(int(t["pos"][0]), int(t["pos"][1]))
		if cells.has(c):
			return "terrain_overlap"
		cells[c] = true
		terrain[c] = t["type"]
	for a in d["activators"]:
		var rule = RuleResolver.COMPANION_RULE.get(a.get("companion", ""))
		if rule == null or a.get("from") != rule["from"] or a.get("to") != rule["to"]:
			return "activator_rule"
		var tc := Vector2i(int(a["target"][0]), int(a["target"][1]))
		if terrain.get(tc, "") != a["from"]:
			return "activator_target"
		var ok := false
		for p in d["pairs"]:
			if int(p["id"]) == int(a["pair"]):
				ok = p["energy"] == RuleResolver.COMPANION_ENERGY[a["companion"]] \
					and int(p["dest"][0]) == int(a["altar"][0]) and int(p["dest"][1]) == int(a["altar"][1])
		if not ok:
			return "activator_pair"
	# Tout terrain spécial bloquant doit avoir un activateur (sinon c'est un obstacle déguisé).
	for c in terrain:
		var has := false
		for a in d["activators"]:
			has = has or Vector2i(int(a["target"][0]), int(a["target"][1])) == c
		if not has:
			return "orphan_terrain"
	return ""
