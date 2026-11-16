class_name SaveStore
extends RefCounted
## Stockage JSON atomique : écriture dans un fichier temporaire, relecture de
## contrôle, rotation d'une copie de secours, puis renommage. Une coupure à
## n'importe quel instant laisse soit l'ancien fichier, soit le nouveau.

static var root := OS.get_environment("DRAKORIA_SAVE_ROOT") if OS.has_environment("DRAKORIA_SAVE_ROOT") else "user://"


static func _path(name: String) -> String:
	return root + name + ".json"


static func write(name: String, data: Dictionary) -> bool:
	var payload := JSON.stringify(data)
	var doc := JSON.stringify({"sha256": payload.sha256_text(), "payload": payload})
	DirAccess.make_dir_recursive_absolute(root)
	var path := _path(name)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(doc)
	f.flush()
	f.close()
	if _parse(FileAccess.get_file_as_string(tmp)).is_empty() and not data.is_empty():
		return false
	var dir := DirAccess.open(root)
	if dir == null:
		return false
	if FileAccess.file_exists(path) and not _parse(FileAccess.get_file_as_string(path)).is_empty():
		dir.copy(path, path + ".bak")
	return dir.rename(tmp, path) == OK


static func read(name: String) -> Dictionary:
	## Renvoie le document principal, sinon la copie de secours, sinon {}.
	for p in [_path(name), _path(name) + ".bak"]:
		if FileAccess.file_exists(p):
			var d := _parse(FileAccess.get_file_as_string(p))
			if not d.is_empty():
				return d
	return {}


static func _parse(text: String) -> Dictionary:
	var doc = _quiet(text)
	if typeof(doc) != TYPE_DICTIONARY or typeof(doc.get("payload")) != TYPE_STRING:
		return {}
	if str(doc.get("sha256", "")) != str(doc["payload"]).sha256_text():
		return {}
	var d = _quiet(doc["payload"])
	return d if typeof(d) == TYPE_DICTIONARY else {}


static func _quiet(text: String):
	var j := JSON.new()
	return j.data if j.parse(text) == OK else null


static func erase(name: String) -> void:
	var dir := DirAccess.open(root)
	if dir:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(_path(name) + suffix):
				dir.remove(_path(name) + suffix)
