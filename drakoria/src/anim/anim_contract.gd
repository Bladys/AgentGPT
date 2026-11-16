class_name AnimContract
extends RefCounted
## Paramètres et noms d'événements du contrat d'animation v3. Le manifeste du
## pack (res://ANIMATION_MANIFEST.json) prime sur la copie provisoire.

static var _d: Dictionary = {}


static func data() -> Dictionary:
	if _d.is_empty():
		var base = JSON.parse_string(FileAccess.get_file_as_string("res://data/animation_manifest.json"))
		_d = base
		if FileAccess.file_exists("res://ANIMATION_MANIFEST.json"):
			var pack = JSON.parse_string(FileAccess.get_file_as_string("res://ANIMATION_MANIFEST.json"))
			if typeof(pack) == TYPE_DICTIONARY:
				_d["pack"] = pack
	return _d


static func state(name: String) -> Dictionary:
	return data()["states"].get(name, {})


static func events(name: String) -> Array:
	return state(name).get("events", [])


static func crossfade_s() -> float:
	return clampf(float(data().get("crossfade_ms", 180)) / 1000.0, 0.16, 0.2)
