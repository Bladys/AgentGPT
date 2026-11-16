class_name InterstitialPolicy
extends RefCounted
## Règles d'affichage des interstitiels (hypothèses initiales à tester).
## Classe pure : l'horloge est injectée pour les tests.

const MIN_LEVEL := 15
const WINS_BETWEEN := 4
const MIN_SECONDS := 180.0

var wins_since_last := 0
var last_shown_s := -1.0e9
var last_rewarded_s := -1.0e9
var rewarded_just_shown := false


func on_win() -> void:
	wins_since_last += 1


func on_rewarded_shown(now_s: float) -> void:
	last_rewarded_s = now_s
	rewarded_just_shown = true


func can_show(now_s: float, level_index: int, context: String, no_ads_owned: bool) -> bool:
	## context : "after_win" est le seul emplacement autorisé. Jamais pendant un
	## puzzle, après un abandon/échec, ni juste après une vidéo récompensée.
	if no_ads_owned or context != "after_win":
		return false
	if level_index < MIN_LEVEL:
		return false
	if rewarded_just_shown:
		return false
	if wins_since_last < WINS_BETWEEN:
		return false
	if now_s - last_shown_s < MIN_SECONDS:
		return false
	return true


func on_interstitial_shown(now_s: float) -> void:
	last_shown_s = now_s
	wins_since_last = 0


func on_screen_left() -> void:
	## L'écran de réussite suivant une récompensée est passé.
	rewarded_just_shown = false
