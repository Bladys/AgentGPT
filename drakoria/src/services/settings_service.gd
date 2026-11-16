extends Node
## Préférences utilisateur, persistées entre les sessions.
## Musique, effets et vibrations sont indépendants.

signal changed(key: String)

const FILE := "settings"
const VERSION := 1
const DEFAULTS := {
	"music_on": true, "sfx_on": true, "vibration_on": true,
	"music_volume": 0.8, "sfx_volume": 0.9,
	"reduced_motion": false, "text_scale": 1.0, "language": "auto",
	"help_captions": true,
}

var _v: Dictionary = DEFAULTS.duplicate()
var persist := true


func _ready() -> void:
	var d := SaveStore.read(FILE)
	if int(d.get("version", 0)) == VERSION:
		for k in DEFAULTS:
			if d.has(k) and typeof(d[k]) == typeof(DEFAULTS[k]):
				_v[k] = d[k]


func get_value(key: String):
	return _v[key]


func set_value(key: String, value) -> void:
	if not DEFAULTS.has(key) or _v[key] == value:
		return
	_v[key] = value
	if persist:
		var d := _v.duplicate()
		d["version"] = VERSION
		SaveStore.write(FILE, d)
	changed.emit(key)


func reduced_motion() -> bool:
	return _v["reduced_motion"]


func vibrate(ms: int) -> void:
	if _v["vibration_on"] and not _v["reduced_motion"]:
		Input.vibrate_handheld(ms)
