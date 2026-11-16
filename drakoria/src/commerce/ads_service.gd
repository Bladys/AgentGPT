extends Node
## AdsService — interface + implémentation factice. Aucune publicité réelle,
## aucun SDK. Une vidéo récompensée n'accorde rien si elle échoue.

signal mock_rewarded_prompt(placement: String)   # l'UI affiche « Démonstration »
signal rewarded_finished(placement: String, txn_id: String, completed: bool)
signal audio_takeover(active: bool)

const SHOW_MOCK_INTERSTITIALS := false  # prototype : la décision est seulement journalisée

var policy := InterstitialPolicy.new()
var auto_result = null   # tests : true/false pour résoudre sans interface
var _pending := ""
var _counter := 0


func now_s() -> float:
	return Time.get_ticks_msec() / 1000.0


func rewarded_available(_placement: String) -> bool:
	return _pending == ""


func request_rewarded(placement: String) -> void:
	## Toujours sur action volontaire du joueur, après explication explicite.
	if _pending != "":
		return
	_pending = placement
	Analytics.track("ad_request", {"format": "rewarded", "placement": placement, "mock": true})
	if auto_result != null:
		resolve_mock(bool(auto_result))
	else:
		mock_rewarded_prompt.emit(placement)


func resolve_mock(completed: bool) -> void:
	if _pending == "":
		return
	var placement := _pending
	_pending = ""
	var txn := ""
	if completed:
		audio_takeover.emit(true)
		Analytics.track("ad_impression", {"format": "rewarded", "placement": placement, "mock": true})
		_counter += 1
		txn = "mockad:%s:%s:%d" % [Analytics.session_id, placement, _counter]
		Analytics.track("ad_complete", {"format": "rewarded", "placement": placement, "mock": true})
		policy.on_rewarded_shown(now_s())
		audio_takeover.emit(false)
	else:
		Analytics.track("ad_fail", {"format": "rewarded", "placement": placement, "mock": true})
	rewarded_finished.emit(placement, txn, completed)


func maybe_interstitial(level_index: int, context: String) -> bool:
	## Renvoie true si un interstitiel serait affiché à cet instant.
	var ok := policy.can_show(now_s(), level_index, context, Purchases.owns("remove_interstitials"))
	if ok:
		policy.on_interstitial_shown(now_s())
		Analytics.track("ad_request", {"format": "interstitial", "mock": true, "displayed": SHOW_MOCK_INTERSTITIALS})
	return ok
