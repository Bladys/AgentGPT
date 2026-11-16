extends Node
## Français ou anglais selon la langue du système (réglable dans Paramètres).

signal language_changed

var lang := "en"
var _tables: Dictionary = {}


func _ready() -> void:
	for l in ["fr", "en"]:
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/%s.json" % l))
		_tables[l] = d if typeof(d) == TYPE_DICTIONARY else {}
	apply()
	Settings.changed.connect(func(k): if k == "language": apply())


func apply() -> void:
	var pref: String = Settings.get_value("language")
	var l := pref if pref != "auto" else OS.get_locale_language()
	lang = "fr" if l == "fr" else "en"
	TranslationServer.set_locale(lang)
	language_changed.emit()


func t(key: String, args: Dictionary = {}) -> String:
	var s: String = _tables.get(lang, {}).get(key, _tables.get("en", {}).get(key, key))
	return s.format(args) if not args.is_empty() else s


func keys(l: String) -> Array:
	return _tables.get(l, {}).keys()
