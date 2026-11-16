extends Node
## AnalyticsService — implémentation factice locale : aucune collecte réseau.
## Un SDK réel remplacera `_send` après vérification de ses règles actuelles
## et des obligations applicables (consentement, marchés visés).

const EVENTS := [
	"tutorial_start", "tutorial_complete",
	"level_start", "level_complete", "level_abandon",
	"undo", "restart", "hint_used", "hint_remove_proposed",
	"session_start", "session_end", "garden_restore",
	"ad_request", "ad_impression", "ad_complete", "ad_fail",
	"purchase_confirmed", "purchase_restored",
]
const MAX_BUFFER := 500

var buffer: Array = []
var counts: Dictionary = {}
var session_id := ""
var _session_start_ms := 0


func _ready() -> void:
	session_id = "%x%x" % [Time.get_unix_time_from_system(), randi()]
	_session_start_ms = Time.get_ticks_msec()
	track("session_start")


func track(event: String, props: Dictionary = {}) -> bool:
	if not EVENTS.has(event):
		push_warning("Analytics: événement inconnu « %s »" % event)
		return false
	var e := {"event": event, "t_ms": Time.get_ticks_msec(), "session": session_id, "props": props}
	buffer.append(e)
	if buffer.size() > MAX_BUFFER:
		buffer.pop_front()
	counts[event] = int(counts.get(event, 0)) + 1
	_send(e)
	return true


func _send(_e: Dictionary) -> void:
	pass  # Prototype : rien ne quitte l'appareil.


func end_session() -> void:
	track("session_end", {"duration_s": (Time.get_ticks_msec() - _session_start_ms) / 1000})


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		end_session()
