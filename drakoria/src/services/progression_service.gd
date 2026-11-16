extends Node
## Progression, graines, indices et registre de transactions dédupliquées.
## Toute modification est sauvegardée de manière atomique et versionnée.

signal changed

var config: Dictionary = {}
var state: Dictionary = {}
var persist := true


func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	state = _fresh()
	var loaded: Dictionary = SaveService.load_progress() if persist else {}
	for k in loaded:
		if state.has(k) and typeof(state[k]) == typeof(loaded[k]):
			state[k] = loaded[k]
	_sanitize()


func _fresh() -> Dictionary:
	return {
		"version": SaveService.VERSION, "cleared": [], "seeds": 0, "garden_steps": 0,
		"milestones_seen": 0, "hints": int(config["hints"]["starting"]), "last_daily": "",
		"transactions": {}, "owned": [], "in_progress": {}, "tutorial_done": false,
		"wins_total": 0, "celebrated": [],
	}


func _sanitize() -> void:
	var ok := []
	for v in state["cleared"]:
		var i := int(v)
		if i >= 1 and i <= total_levels() and not ok.has(i):
			ok.append(i)
	ok.sort()
	# Progression linéaire : aucun niveau réussi au-delà du premier trou.
	var linear := []
	for i in ok:
		if i == linear.size() + 1:
			linear.append(i)
	state["cleared"] = linear
	state["seeds"] = maxi(0, int(state["seeds"]))
	state["hints"] = maxi(0, int(state["hints"]))
	state["garden_steps"] = clampi(int(state["garden_steps"]), 0, int(config["garden"]["steps_per_island"]) * 6)


func save() -> void:
	if persist:
		SaveService.save_progress(state)
	changed.emit()


func reset_all() -> void:
	state = _fresh()
	save()


# ---------------------------------------------------------------- niveaux

func total_levels() -> int:
	return int(config["islands"].size()) * int(config["levels_per_island"])


func playable_levels() -> int:
	return int(config["playable_levels"])


func cleared_count() -> int:
	return state["cleared"].size()


func is_cleared(index: int) -> bool:
	return state["cleared"].has(index) or state["cleared"].has(float(index))


func is_unlocked(index: int) -> bool:
	return index >= 1 and index <= playable_levels() and index <= cleared_count() + 1


func next_level() -> int:
	return mini(cleared_count() + 1, playable_levels())


func island_unlocked(island: int) -> bool:
	return island == 1 or cleared_count() >= (island - 1) * int(config["levels_per_island"])


func companion_unlocked(name: String) -> bool:
	return cleared_count() >= int(config["companions"][name]["unlock_after_level"])


func companion_first_level(name: String) -> int:
	return int(config["companions"][name]["unlock_after_level"]) + 1


func is_tutorial_level(index: int) -> bool:
	return index <= int(config["tutorial_levels"])


func complete_level(index: int) -> Dictionary:
	## Appelé quand le MODÈLE a déclaré la victoire. La graine de première
	## réussite n'est accordée qu'une seule fois ; rejouer est gratuit.
	var res := {"first": false, "seeds": 0, "milestone": 0, "companion": "", "island_done": false}
	state["wins_total"] = int(state["wins_total"]) + 1
	state["in_progress"] = {}
	if not is_unlocked(index) or is_cleared(index):
		save()
		return res
	state["cleared"].append(index)
	res["first"] = true
	if grant("first_clear:level_%03d" % index, "seeds", int(config["seeds_per_first_clear"]), false):
		res["seeds"] = int(config["seeds_per_first_clear"])
	var n := cleared_count()
	if n % int(config["milestone_every"]) == 0:
		res["milestone"] = n / int(config["milestone_every"])
	for c in config["companions"]:
		if int(config["companions"][c]["unlock_after_level"]) == n:
			res["companion"] = c
	res["island_done"] = n % int(config["levels_per_island"]) == 0
	if index == int(config["tutorial_levels"]):
		state["tutorial_done"] = true
	save()
	return res


# ---------------------------------------------------------------- récompenses

func grant(txn_id: String, kind: String, amount: int, do_save := true) -> bool:
	## Récompense idempotente : un identifiant de transaction ne paie qu'une fois.
	if txn_id == "" or state["transactions"].has(txn_id) or amount <= 0:
		return false
	if kind != "seeds" and kind != "hints":
		return false
	state["transactions"][txn_id] = kind
	state[kind] = int(state[kind]) + amount
	if do_save:
		save()
	return true


func record_purchase(txn_id: String, product_id: String) -> bool:
	if txn_id == "" or state["transactions"].has(txn_id):
		return false
	state["transactions"][txn_id] = "purchase:" + product_id
	if not state["owned"].has(product_id):
		state["owned"].append(product_id)
	save()
	return true


func owns(product_id: String) -> bool:
	return state["owned"].has(product_id)


# ---------------------------------------------------------------- indices

func hint_is_free(index: int) -> bool:
	return is_tutorial_level(index)


func can_use_hint(index: int) -> bool:
	return hint_is_free(index) or int(state["hints"]) > 0


func consume_hint(index: int) -> bool:
	if hint_is_free(index):
		return true
	if int(state["hints"]) <= 0:
		return false
	state["hints"] = int(state["hints"]) - 1
	save()
	return true


func daily_available(today := "") -> bool:
	if today == "":
		today = Time.get_date_string_from_system()
	return state["last_daily"] != today


func claim_daily(today := "") -> bool:
	if today == "":
		today = Time.get_date_string_from_system()
	if not daily_available(today):
		return false
	state["last_daily"] = today
	return grant("daily:" + today, "hints", int(config["hints"]["daily"]))


# ---------------------------------------------------------------- jardin

func garden_capacity() -> int:
	## Les étapes de jardin ne dépassent jamais les réussites : les graines
	## doublées décorent plus vite, elles n'ouvrent aucun contenu de jeu.
	return mini(cleared_count() + int(config["garden"]["bonus_plots"]),
		int(config["garden"]["steps_per_island"]) + int(config["garden"]["bonus_plots"]))


func can_restore() -> bool:
	return int(state["seeds"]) > 0 and int(state["garden_steps"]) < garden_capacity()


func restore_step() -> bool:
	if not can_restore():
		return false
	state["seeds"] = int(state["seeds"]) - 1
	state["garden_steps"] = int(state["garden_steps"]) + 1
	save()
	return true


func milestones_reached() -> int:
	return cleared_count() / int(config["milestone_every"])


# ---------------------------------------------------------------- partie en cours

func store_in_progress(index: int, model_state: Dictionary) -> void:
	state["in_progress"] = {"index": index, "model": model_state}
	if persist:
		SaveService.save_progress(state)


func take_in_progress(index: int) -> Dictionary:
	var ip: Dictionary = state["in_progress"]
	if int(ip.get("index", -1)) == index and typeof(ip.get("model")) == TYPE_DICTIONARY:
		return ip["model"]
	return {}
