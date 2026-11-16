class_name AssetRegistry
extends RefCounted
## Identifiants d'assets stables -> chemins. Le jeu ne référence jamais un
## chemin en dur : il demande un ID et accepte l'absence (repli procédural)
## tant que le pack art/animation n'est pas intégré.

static var _m: Dictionary = {}


static func manifest() -> Dictionary:
	if _m.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_manifest.json"))
		_m = d if typeof(d) == TYPE_DICTIONARY else {"assets": {}}
	return _m


static func entry(id: String) -> Dictionary:
	return manifest()["assets"].get(id, {})


static func path(id: String) -> String:
	return str(entry(id).get("path", ""))


static func available(id: String) -> bool:
	var p := path(id)
	return p != "" and ResourceLoader.exists(p)


static func load_or_null(id: String) -> Resource:
	return load(path(id)) if available(id) else null
