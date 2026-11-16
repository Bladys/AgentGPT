extends Node
## Façade de sauvegarde versionnée pour la progression.

const FILE := "progress"
const VERSION := 2


func load_progress() -> Dictionary:
	var d := SaveStore.read(FILE)
	if d.is_empty():
		return {}
	return migrate(d)


func save_progress(state: Dictionary) -> bool:
	state["version"] = VERSION
	return SaveStore.write(FILE, state)


static func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 0))
	if v > VERSION or v < 1:
		return {}  # version inconnue : on ne devine pas, on repart d'un état sain
	if v == 1:
		# v1 -> v2 : ajout du registre de transactions et des achats.
		if not d.has("transactions"): d["transactions"] = {}
		if not d.has("owned"): d["owned"] = []
		v = 2
	d["version"] = v
	return d
