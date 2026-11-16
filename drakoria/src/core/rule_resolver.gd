class_name RuleResolver
extends RefCounted
## Résolution des interactions. Appelé uniquement après validation d'un canal.
## Les règles de chaque activateur viennent des données du niveau.

const COMPANION_ENERGY := {"brindille": "water", "braise": "heat", "nacre": "light"}
const COMPANION_RULE := {
	"brindille": {"from": "gap", "to": "bridge"},
	"braise": {"from": "ice", "to": "melted"},
	"nacre": {"from": "current", "to": "frozen"},
}


static func resolve_connection(model: PuzzleModel, pair_id: int) -> void:
	for a in model.activators:
		if a["pair"] != pair_id or model.fired.has(a["id"]):
			continue  # un activateur ne se déclenche qu'une fois par niveau
		var i := model.idx(a["target"])
		if model.terrain[i] != a["from"]:
			continue
		model.fired[a["id"]] = true
		model.terrain[i] = a["to"]
		model._emit("activator_fired", {
			"activator": a["id"], "companion": a["companion"], "pair": pair_id,
			"altar": model.pair_by_id[pair_id]["dest"], "target": a["target"],
			"from": a["from"], "to": a["to"],
		})


static func objectives_met(model: PuzzleModel) -> bool:
	for o in model.objectives:
		var s := str(o)
		if s == "connect_all":
			if model.paths.size() != model.pairs.size():
				return false
		elif s.begins_with("activate:"):
			if not model.fired.has(s.substr(9)):
				return false
		else:
			return false  # objectif inconnu : jamais de victoire implicite
	return true
