extends Node
## Suite de tests headless :
##   DRAKORIA_SAVE_ROOT=user://test_tmp/ godot --headless --path . res://tests/test_runner.tscn
## Écrit un résumé JSON dans user://test_tmp/report.json et sort avec 0/1.

var passed := 0
var failed := 0
var lines: Array = []
var section := ""
var metrics: Dictionary = {}


func check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		lines.append("ECHEC [%s] %s" % [section, what])
		printerr("ECHEC [%s] %s" % [section, what])


func begin(name: String) -> void:
	section = name
	print("— " + name)


func _ready() -> void:
	if not SaveStore.root.contains("test"):
		printerr("Refus : définir DRAKORIA_SAVE_ROOT vers un dossier de test.")
		get_tree().quit(2)
		return
	Settings.persist = false
	Ads.auto_result = true
	Purchases.auto_result = true
	SaveStore.erase("progress")
	Progression.reset_all()
	test_levels()
	test_model_rules()
	test_undo_sequences()
	test_save_reload()
	test_hints()
	test_progression()
	test_commerce()
	test_i18n_and_assets()
	await test_animation_router()
	await test_gesture_and_screens()
	var report := {"passed": passed, "failed": failed, "failures": lines, "metrics": metrics,
		"engine": Engine.get_version_info()["string"]}
	var f := FileAccess.open(SaveStore.root + "report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("\nRésultat : %d vérifications réussies, %d échecs" % [passed, failed])
	print("METRICS " + JSON.stringify(metrics))
	get_tree().quit(1 if failed > 0 else 0)


func model_for(i: int) -> PuzzleModel:
	var m := PuzzleModel.new()
	m.load_level(LevelLoader.load_level(i))
	return m


# ---------------------------------------------------------------- niveaux

func test_levels() -> void:
	begin("50 niveaux : schéma, solveur, solution de référence")
	var canon := {}
	var handmade := 0
	var by_diff := {}
	var t0 := Time.get_ticks_msec()
	for i in range(1, LevelLoader.PLAYABLE_COUNT + 1):
		var raw = JSON.parse_string(FileAccess.get_file_as_string(LevelLoader.path_for(i)))
		check(typeof(raw) == TYPE_DICTIONARY, "niveau %d lisible" % i)
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		check(LevelLoader.schema_error(raw) == "", "niveau %d schéma (%s)" % [i, LevelLoader.schema_error(raw)])
		check(int(raw["index"]) == i and raw["id"] == "level_%03d" % i, "niveau %d identifiant" % i)
		var m := PuzzleModel.new()
		m.load_level(raw)
		# Solveur indépendant de la solution stockée.
		var an := Solver.analyze(m, 4, 400000)
		check(an["solvable"], "niveau %d solvable (%s)" % [i, an["status"]])
		for a in raw["activators"]:
			check(an["requires_activation"].get(a["id"], false), "niveau %d : %s nécessaire" % [i, a["id"]])
			check(i >= Progression.companion_first_level(a["companion"]),
				"niveau %d : compagnon %s déjà débloqué" % [i, a["companion"]])
			check(not Progression.config["companions"][a["companion"]]["paid"], "compagnon gratuit")
		# La solution de référence stockée est rejouée geste par geste.
		var ref := LevelLoader.reference_paths(raw)
		for pid in raw["reference_solution"]["order"]:
			check(m.apply_path(int(pid), ref[int(pid)]), "niveau %d : canal %d de référence traçable" % [i, pid])
		check(m.completed and m.validate() == "", "niveau %d : référence => victoire (%s)" % [i, m.validate()])
		var key: String = load("res://tools/build_levels.gd").canonical(raw)
		check(not canon.has(key), "niveau %d : pas une symétrie du niveau %s" % [i, canon.get(key, "")])
		canon[key] = i
		if raw["origin"] == "handmade":
			handmade += 1
		var diff: String = raw["solver"]["measured_difficulty"]
		by_diff[diff] = int(by_diff.get(diff, 0)) + 1
	check(handmade >= 10, "au moins dix grilles faites à la main (%d)" % handmade)
	for comp in ["brindille", "braise", "nacre"]:
		var lvl := LevelLoader.load_level(Progression.companion_first_level(comp))
		check(lvl.get("origin") == "handmade" and lvl["activators"].size() == 1 and lvl["activators"][0]["companion"] == comp,
			"tranche verticale : une grille faite main pour " + comp)
	metrics["levels_validated"] = canon.size()
	metrics["levels_handmade"] = handmade
	metrics["measured_difficulty"] = by_diff
	metrics["solver_all_levels_ms"] = Time.get_ticks_msec() - t0


# ---------------------------------------------------------------- règles

func test_model_rules() -> void:
	begin("règles déterministes")
	var m := model_for(11)  # A(0,0)->a(4,0) eau/Brindille ; B(1,1)->b(2,4) ; vide en (2,2)
	check(not m.begin_draft(Vector2i(2, 1)), "une case vide ne démarre pas de canal")
	check(not m.begin_draft(Vector2i(4, 0)), "une destination ne démarre pas de canal")
	check(m.begin_draft(Vector2i(1, 1)), "départ depuis la source")
	check(m.extend_draft(Vector2i(2, 2)) == "refused:not_adjacent", "pas de diagonale")
	check(m.extend_draft(Vector2i(2, 1)) == "added", "segment orthogonal")
	var before := m.draft.duplicate()
	check(m.extend_draft(Vector2i(2, 2)) == "refused:blocked", "vide infranchissable avant le pont")
	check(m.draft == before, "un refus laisse l'état inchangé")
	check(m.extend_draft(Vector2i(1, 1)) == "removed", "revenir sur la case précédente retire un segment")
	m.extend_draft(Vector2i(1, 0))
	check(m.extend_draft(Vector2i(0, 0)) == "refused:foreign_endpoint", "pas de passage sur la source d'une autre paire")
	check(not m.end_draft(), "relâcher hors destination annule")
	check(m.paths.is_empty() and not m.can_undo(), "tracé annulé : aucun changement, aucune entrée d'annulation")
	# Auto-intersection
	m.begin_draft(Vector2i(1, 1))
	for c in [Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 0), Vector2i(2, 0)]:
		m.extend_draft(c)
	check(m.extend_draft(Vector2i(2, 1)) == "refused:self", "pas d'auto-intersection")
	m.end_draft()
	# Activation
	var path_a := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
	m.drain_events()
	check(m.apply_path(1, path_a), "paire eau connectée")
	var ev := m.drain_events().map(func(e): return e["type"])
	check(ev.has("pair_connected") and ev.has("activator_fired"), "événements émis par le modèle")
	check(ev.find("activator_fired") > ev.find("pair_connected"), "interaction résolue après validation")
	check(m.terrain_at(Vector2i(2, 2)) == PuzzleModel.T_BRIDGE, "le pont pousse sur la case cible")
	# Croisement refusé
	m.begin_draft(Vector2i(1, 1))
	check(m.extend_draft(Vector2i(1, 0)) == "refused:occupied", "rencontrer un autre canal refuse le segment")
	m.end_draft()
	# Le pont persiste si le canal activateur est effacé ; pas de 2e déclenchement.
	m.remove_path(1)
	check(m.terrain_at(Vector2i(2, 2)) == PuzzleModel.T_BRIDGE and not m.paths.has(1), "le terrain persiste après effacement")
	m.drain_events()
	m.apply_path(1, path_a)
	check(not m.drain_events().map(func(e): return e["type"]).has("activator_fired"), "un activateur ne se déclenche qu'une fois")
	# Reprise d'un canal par un segment
	m.begin_draft(Vector2i(2, 0))
	check(m.draft.size() == 3 and not m.paths.has(1), "toucher un segment reprend le canal et efface la suite")
	m.extend_draft(Vector2i(3, 0)); m.extend_draft(Vector2i(4, 0))
	check(m.extend_draft(Vector2i(4, 1)) == "refused:terminated", "une destination termine le chemin")
	check(m.end_draft(), "revalidation")
	check(not m.completed, "pas de victoire tant qu'une paire manque")
	check(m.apply_path(2, [Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4)]), "canal par le pont")
	check(m.completed, "victoire : toutes les paires connectées simultanément")
	check(not m.begin_draft(Vector2i(0, 0)), "plateau figé après la victoire")
	# Annuler jusqu'au début restaure terrain et compteurs
	while m.undo():
		pass
	check(m.terrain == m.initial_terrain and m.paths.is_empty() and m.fired.is_empty() and m.moves == 0 and not m.completed,
		"annuler restaure l'état complet (terrain, activateurs, compteurs)")
	# abort_draft
	m.apply_path(1, path_a)
	var snap := m.snapshot()
	m.begin_draft(Vector2i(2, 0))
	m.abort_draft()
	check(m.committed_equals(snap), "interruption système : état d'avant le geste")
	m.restart()
	check(m.terrain == m.initial_terrain and m.paths.is_empty() and not m.can_undo(), "recommencer restaure l'état initial")


# ---------------------------------------------------------------- annulation

func random_gesture(m: PuzzleModel, rng: RandomNumberGenerator) -> void:
	var starts: Array = []
	for pr in m.pairs:
		starts.append(pr["source"])
	for pid in m.paths:
		starts.append_array(m.paths[pid])
	var roll := rng.randf()
	if roll < 0.06:
		m.begin_draft(Vector2i(rng.randi_range(-1, m.width), rng.randi_range(-1, m.height)))
	else:
		m.begin_draft(starts[rng.randi_range(0, starts.size() - 1)])
	if m.draft_pair == 0:
		return
	var dest: Vector2i = m.pair_by_id[m.draft_pair]["dest"]
	for s in rng.randi_range(0, 24):
		var tip: Vector2i = m.draft[m.draft.size() - 1]
		var c := tip + Solver.DIRS[rng.randi_range(0, 3)]
		if rng.randf() < 0.55:  # biais vers la destination pour valider souvent
			var d := dest - tip
			c = tip + (Vector2i(signi(d.x), 0) if (absi(d.x) > absi(d.y) or (d.y == 0)) else Vector2i(0, signi(d.y)))
		if rng.randf() < 0.04:
			c = Vector2i(rng.randi_range(-2, 9), rng.randi_range(-2, 9))
		m.extend_draft(c)
	if rng.randf() < 0.05:
		m.abort_draft()
	else:
		m.end_draft()


func test_undo_sequences() -> void:
	begin("annulation : 1 000 séquences aléatoires")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261116
	var gestures := 0
	var connections := 0
	var activations := 0
	var bad_undo := 0
	var bad_invariant := 0
	var bad_full := 0
	var wins := 0
	for s in 1000:
		var m := model_for(1 + (s % LevelLoader.PLAYABLE_COUNT))
		var history: Array = [m.snapshot()]
		for g in rng.randi_range(4, 30):
			if m.completed:
				wins += 1
				break
			var act := rng.randf()
			if act < 0.2 and m.can_undo():
				m.undo()
				history.pop_back()
				if not m.committed_equals(history[history.size() - 1]):
					bad_undo += 1
			else:
				var before := m.snapshot()
				random_gesture(m, rng)
				gestures += 1
				if not m.committed_equals(before):
					history.append(m.snapshot())
			if m.validate() != "":
				bad_invariant += 1
		connections += m.paths.size()
		activations += m.fired.size()
		# Défaire tout : chaque étape doit retrouver exactement l'état précédent.
		while m.can_undo():
			m.undo()
			history.pop_back()
			if history.is_empty() or not m.committed_equals(history[history.size() - 1]):
				bad_undo += 1
				break
		if m.terrain != m.initial_terrain or not m.paths.is_empty() or not m.fired.is_empty() or m.moves != 0 or m.completed:
			bad_full += 1
	check(bad_undo == 0, "chaque annulation restaure l'état exact du geste précédent (%d écarts)" % bad_undo)
	check(bad_invariant == 0, "invariants respectés après chaque geste (%d écarts)" % bad_invariant)
	check(bad_full == 0, "annuler jusqu'au bout = état initial (%d écarts)" % bad_full)
	check(connections > 500 and activations > 20, "les séquences exercent connexions (%d) et activations (%d)" % [connections, activations])
	metrics["undo_sequences"] = 1000
	metrics["undo_gestures"] = gestures
	metrics["undo_final_connections"] = connections
	metrics["undo_final_activations"] = activations
	metrics["undo_random_wins"] = wins


# ---------------------------------------------------------------- sauvegarde

func test_save_reload() -> void:
	begin("fermeture / réouverture")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var mismatches := 0
	var invalid := 0
	for s in 300:
		var idx := 1 + (s % LevelLoader.PLAYABLE_COUNT)
		var m := model_for(idx)
		for g in rng.randi_range(1, 14):
			if m.completed:
				break
			random_gesture(m, rng)
		# Fermeture au milieu d'un tracé : seul l'état validé est écrit.
		var mid := rng.randf() < 0.3 and not m.completed
		var expect := m.snapshot()
		if mid:
			m.begin_draft(m.pairs[0]["source"])
			m.extend_draft(m.pairs[0]["source"] + Vector2i(1, 0))
		var json := JSON.stringify(m.to_dict())
		var m2 := model_for(idx)
		if not m2.from_dict(JSON.parse_string(json)) or not m2.committed_equals(expect):
			mismatches += 1
		if m2.validate() != "" or m2.draft_pair != 0:
			invalid += 1
		# L'annulation survit au rechargement.
		while m2.can_undo():
			m2.undo()
			if m2.validate() != "":
				invalid += 1
	check(mismatches == 0, "état rechargé identique (%d écarts)" % mismatches)
	check(invalid == 0, "aucun état impossible après réouverture (%d)" % invalid)
	# États corrompus ou incohérents : rejetés, retour à l'état initial.
	var m := model_for(11)
	m.apply_path(1, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)])
	var good := m.to_dict()
	var tampered: Array = []
	var t1: Dictionary = good.duplicate(true); t1["state"]["fired"] = []; tampered.append(t1)                 # pont sans activation
	var t2: Dictionary = good.duplicate(true); t2["state"]["paths"]["2"] = [[1, 1], [1, 0]]; tampered.append(t2)  # canal incomplet
	var t3: Dictionary = good.duplicate(true); t3["state"]["paths"]["1"] = [[0, 0], [4, 0]]; tampered.append(t3)  # saut
	var t4: Dictionary = good.duplicate(true); t4["state"]["completed"] = true; tampered.append(t4)             # victoire forgée
	var t5: Dictionary = good.duplicate(true); t5["level"] = "level_012"; tampered.append(t5)
	var t6: Dictionary = good.duplicate(true); t6["state"]["terrain"] = [1, 2, 3]; tampered.append(t6)
	var t7: Dictionary = good.duplicate(true); t7["state_version"] = 99; tampered.append(t7)
	var t8: Dictionary = good.duplicate(true); t8["state"]["paths"]["2"] = [[1, 1], [2, 1], [2, 2], [2, 3], [2, 4]]; t8["state"]["terrain"][12] = 2; t8["state"]["fired"] = []; tampered.append(t8)
	for i in tampered.size():
		var mt := model_for(11)
		var ok := mt.from_dict(tampered[i])
		check(not ok and mt.validate() == "" and mt.paths.is_empty() and mt.terrain == mt.initial_terrain,
			"état altéré n°%d rejeté, plateau initial sain" % (i + 1))
	# Stockage atomique
	check(SaveStore.write("atomic_test", {"a": 1}), "écriture atomique")
	check(SaveStore.write("atomic_test", {"a": 2}), "seconde écriture (copie de secours)")
	check(int(SaveStore.read("atomic_test")["a"]) == 2, "relecture")
	var f := FileAccess.open(SaveStore.root + "atomic_test.json", FileAccess.WRITE)
	f.store_string("{\"sha256\":\"x\",\"payload\":\"{tronqu")
	f.close()
	check(int(SaveStore.read("atomic_test").get("a", 0)) == 1, "fichier corrompu : repli sur la copie de secours")
	var f2 := FileAccess.open(SaveStore.root + "atomic_test.json.tmp", FileAccess.WRITE)
	f2.store_string("partiel")
	f2.close()
	check(int(SaveStore.read("atomic_test").get("a", 0)) == 1, "fichier temporaire orphelin ignoré")
	check(SaveService.migrate({"version": 1, "cleared": [1]}).has("transactions"), "migration v1 -> v2")
	check(SaveService.migrate({"version": 99}).is_empty(), "version future refusée")
	SaveStore.erase("atomic_test")


# ---------------------------------------------------------------- indices

func test_hints() -> void:
	begin("indices")
	var solved := 0
	var t0 := Time.get_ticks_msec()
	var worst := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(1, LevelLoader.PLAYABLE_COUNT + 1):
		var m := model_for(i)
		var ref := LevelLoader.reference_paths(m.level)
		# Départ volontairement gêné par quelques gestes aléatoires.
		for g in 3:
			random_gesture(m, rng)
		var steps := 0
		while not m.completed and steps < 60:
			steps += 1
			var t := Time.get_ticks_msec()
			var h := Solver.hint(m, ref)
			worst = maxi(worst, Time.get_ticks_msec() - t)
			if h["kind"] == "segment":
				if not m.apply_path(h["pair"], h["path"]):
					break
			elif h["kind"] == "remove":
				var seeds_before: int = Progression.state["seeds"]
				m.remove_path(h["pair"])
				check(Progression.state["seeds"] == seeds_before, "aucune dépense automatique")
			else:
				break
		if m.completed:
			solved += 1
		else:
			check(false, "niveau %d : les indices mènent à la solution" % i)
	check(solved == LevelLoader.PLAYABLE_COUNT, "suivre les indices résout les 50 niveaux depuis un état gêné (%d)" % solved)
	metrics["hint_worst_ms"] = worst
	metrics["hint_total_ms"] = Time.get_ticks_msec() - t0


# ---------------------------------------------------------------- progression

func test_progression() -> void:
	begin("progression et récompenses")
	Progression.reset_all()
	check(Progression.is_unlocked(1) and not Progression.is_unlocked(2), "seul le niveau 1 est ouvert")
	var r: Dictionary = Progression.complete_level(1)
	check(r["first"] and r["seeds"] == 1 and Progression.state["seeds"] == 1, "graine de première réussite")
	r = Progression.complete_level(1)
	check(not r["first"] and r["seeds"] == 0 and Progression.state["seeds"] == 1, "rejouer n'accorde pas de nouvelle graine")
	check(Progression.complete_level(7)["first"] == false and not Progression.is_cleared(7), "niveau verrouillé non validable")
	check(not Progression.grant("first_clear:level_001", "seeds", 5), "transaction dédupliquée")
	check(not Progression.companion_unlocked("brindille"), "Brindille verrouillée au départ")
	for i in range(2, 11):
		r = Progression.complete_level(i)
	check(r["milestone"] == 1 and r["companion"] == "brindille", "10e réussite : restauration principale + Brindille")
	check(Progression.companion_unlocked("brindille") and not Progression.companion_unlocked("braise"), "déblocage au niveau prévu")
	check(Progression.state["seeds"] == 10, "une graine par première réussite")
	check(Progression.restore_step() and Progression.state["seeds"] == 9 and Progression.state["garden_steps"] == 1, "restaurer consomme une graine")
	# Indices
	check(Progression.hint_is_free(3) and Progression.consume_hint(3) and Progression.state["hints"] == 3, "indices gratuits pendant le tutoriel")
	check(Progression.consume_hint(20) and Progression.state["hints"] == 2, "indice consommé hors tutoriel")
	check(Progression.claim_daily("2026-11-16") and not Progression.claim_daily("2026-11-16"), "récompense quotidienne une fois par jour")
	check(Progression.claim_daily("2026-11-17"), "nouvelle récompense le lendemain")
	# Persistance
	var seeds: int = Progression.state["seeds"]
	var loaded: Dictionary = SaveService.load_progress()
	check(int(loaded.get("seeds", -1)) == seeds and loaded["cleared"].size() == 10, "progression écrite sur disque")
	# Île suivante après le niveau 50
	for i in range(11, 50):
		Progression.complete_level(i)
	check(not Progression.island_unlocked(2), "île 2 verrouillée avant le niveau 50")
	r = Progression.complete_level(50)
	check(r["island_done"] and Progression.island_unlocked(2), "île 2 déverrouillée par le niveau 50")
	check(not Progression.is_unlocked(51), "aucun niveau jouable au-delà des grilles validées")
	check(Progression.playable_levels() == LevelLoader.PLAYABLE_COUNT, "catalogue annoncé = grilles validées")
	# Sauvegarde incohérente assainie
	Progression.state["cleared"] = [1, 2, 5, 900, 2]
	Progression._sanitize()
	check(Progression.state["cleared"] == [1, 2], "progression incohérente ramenée à un état possible")
	Progression.reset_all()


# ---------------------------------------------------------------- commerce

func test_commerce() -> void:
	begin("services commerciaux factices")
	var p := InterstitialPolicy.new()
	for i in 4: p.on_win()
	check(not p.can_show(1000.0, 14, "after_win", false), "pas d'interstitiel avant le niveau 15")
	check(p.can_show(1000.0, 15, "after_win", false), "autorisé après 4 réussites dès le niveau 15")
	check(not p.can_show(1000.0, 20, "in_puzzle", false), "jamais pendant un puzzle")
	check(not p.can_show(1000.0, 20, "after_abandon", false), "jamais après un abandon")
	check(not p.can_show(1000.0, 20, "after_win", true), "achat : plus d'interstitiel")
	p.on_interstitial_shown(1000.0)
	for i in 4: p.on_win()
	check(not p.can_show(1100.0, 20, "after_win", false), "au moins 180 s entre deux")
	check(p.can_show(1181.0, 20, "after_win", false), "autorisé après 180 s")
	p.on_rewarded_shown(1181.0)
	check(not p.can_show(1181.0, 20, "after_win", false), "pas immédiatement après une récompensée")
	p.on_screen_left()
	check(p.can_show(1190.0, 20, "after_win", false), "de nouveau possible ensuite")
	var q := InterstitialPolicy.new()
	for i in 3: q.on_win()
	check(not q.can_show(9999.0, 30, "after_win", false), "au plus un après quatre réussites")
	# Récompensée : rien si la vidéo échoue ; déduplication par transaction.
	var got: Array = []
	var cb := func(pl, txn, done): got.append([pl, txn, done])
	Ads.rewarded_finished.connect(cb)
	var hints: int = Progression.state["hints"]
	Ads.auto_result = false
	Ads.request_rewarded("hint")
	check(got[-1][2] == false and got[-1][1] == "", "vidéo échouée : aucune transaction")
	check(not Progression.grant(got[-1][1], "hints", 1) and Progression.state["hints"] == hints, "pas de récompense factice")
	Ads.auto_result = true
	Ads.request_rewarded("hint")
	check(got[-1][2] and Progression.grant(got[-1][1], "hints", 1), "vidéo terminée : récompense")
	check(not Progression.grant(got[-1][1], "hints", 1) and Progression.state["hints"] == hints + 1, "même transaction : une seule récompense")
	check(int(Analytics.counts.get("ad_fail", 0)) >= 1 and int(Analytics.counts.get("ad_complete", 0)) >= 1, "mesures publicitaires")
	Ads.rewarded_finished.disconnect(cb)
	# Achats simulés
	var before := int(Analytics.counts.get("purchase_confirmed", 0))
	Purchases.auto_result = false
	Purchases.request_purchase("remove_interstitials")
	check(not Purchases.owns("remove_interstitials") and int(Analytics.counts.get("purchase_confirmed", 0)) == before,
		"achat non confirmé : rien d'enregistré")
	Purchases.auto_result = true
	Purchases.request_purchase("remove_interstitials")
	check(Purchases.owns("remove_interstitials") and int(Analytics.counts.get("purchase_confirmed", 0)) == before + 1, "achat confirmé enregistré une fois")
	Purchases.request_purchase("remove_interstitials")
	check(int(Analytics.counts.get("purchase_confirmed", 0)) == before + 1, "pas de double achat")
	check(Analytics.buffer[-1]["props"].get("simulated", false) and Analytics.buffer[-1]["props"]["revenue"] == 0, "aucun revenu enregistré en démonstration")
	check(not Analytics.track("evenement_invente"), "événement hors catalogue refusé")
	for prod in Purchases.products:
		check(prod["kind"] == "non_consumable", "ni abonnement ni monnaie")
	Progression.reset_all()


# ---------------------------------------------------------------- textes et assets

func test_i18n_and_assets() -> void:
	begin("textes FR/EN et manifeste d'assets")
	var fr: Array = I18n.keys("fr")
	var en: Array = I18n.keys("en")
	check(fr.size() > 40, "catalogue français chargé (%d)" % fr.size())
	for k in fr:
		check(en.has(k), "clé anglaise manquante : " + k)
	for k in en:
		check(fr.has(k), "clé française manquante : " + k)
	# Toutes les clés utilisées dans les sources existent.
	var used := {}
	var re := RegEx.new()
	re.compile("(?:I18n\\.t|UI\\.tr_key)\\(\"([a-z0-9_.]+)\"")
	_scan("res://src", re, used)
	for k in used:
		check(fr.has(k), "clé utilisée mais absente : " + k)
	metrics["i18n_keys"] = fr.size()
	var man := AssetRegistry.manifest()
	var pending := 0
	for id in man["assets"]:
		var e: Dictionary = man["assets"][id]
		if e["status"] == "present":
			check(ResourceLoader.exists(e["path"]), "asset présent introuvable : " + id)
		else:
			pending += 1
	metrics["assets_pending_pack"] = pending
	metrics["assets_total"] = man["assets"].size()
	# Chaque référence d'asset des niveaux et du catalogue VFX a un ID au manifeste.
	for i in range(1, LevelLoader.PLAYABLE_COUNT + 1):
		var pres: Dictionary = LevelLoader.load_level(i)["presentation"]
		for id in [pres["background"], pres["music"], pres["ambience"]] + pres["props"]:
			check(man["assets"].has(id), "niveau %d : ID d'asset inconnu %s" % [i, id])
		check(man["tints"].has(pres["tint"]), "teinte connue")
	var fx = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/effects.json"))
	var total := 0
	for name in fx["effects"]:
		var e: Dictionary = fx["effects"][name]
		for k in ["trigger", "duration", "particles", "anchor", "reduced"]:
			check(e.has(k), "VFX %s : champ %s" % [name, k])
		check(man["assets"].has(e["sfx"]), "VFX %s : son au manifeste" % name)
		check(int(e["particles"]) <= int(fx["global_particle_cap"]), "budget sous le plafond")
		total += 1
	check(total == 10, "dix effets catalogués")


func _scan(dir: String, re: RegEx, used: Dictionary) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			for m in re.search_all(FileAccess.get_file_as_string(dir + "/" + f)):
				used[m.get_string(1)] = true
	for d in DirAccess.get_directories_at(dir):
		_scan(dir + "/" + d, re, used)


# ---------------------------------------------------------------- animation

func test_animation_router() -> void:
	begin("animation : événements, annulation, mouvements réduits")
	Settings.set_value("reduced_motion", false)
	var m := model_for(11)
	var board := BoardView.new()
	board.size = Vector2(600, 600)
	add_child(board)
	board.set_model(m)
	var vfx := VFXService.new()
	add_child(vfx)
	var dragon := DragonAnimator.new()
	add_child(dragon)
	dragon.setup("brindille")
	var router := AnimationEventRouter.new()
	add_child(router)
	router.bind(board, vfx, dragon)
	check(dragon.current == "idle", "idle par défaut")
	var tk := dragon.token
	dragon.play("idle")
	check(dragon.token == tk, "le même clip n'est pas relancé")
	dragon.play("sleep")
	check(dragon.current == "idle", "sleep réservé à l'habitat")
	var path_a := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
	m.apply_path(1, path_a)
	check(m.terrain_at(Vector2i(2, 2)) == PuzzleModel.T_BRIDGE, "le modèle est résolu avant toute animation")
	router.handle(m.drain_events())
	check(dragon.current == "cast" and router.release_count == 0, "cast lancé, VFX en attente de power_release")
	var t0 := Time.get_ticks_msec()
	while router.release_count == 0 and Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame
	var at := dragon._elapsed
	check(router.release_count == 1 and at >= 0.54 and at < 0.75, "power_release à 0,54 s (mesuré %.2f s)" % at)
	while dragon.current == "cast" and Time.get_ticks_msec() - t0 < 4000:
		await get_tree().process_frame
	check(dragon.current == "idle" and router.release_count == 1, "clip non bouclé -> idle ; VFX déclenché une seule fois")
	metrics["power_release_measured_s"] = snappedf(at, 0.01)
	# Annulation pendant l'anticipation : aucun callback tardif.
	m.undo()
	router.handle(m.drain_events())
	m.apply_path(1, path_a)
	router.handle(m.drain_events())
	check(dragon.current == "cast", "second lancement")
	m.undo()
	router.handle(m.drain_events())
	for i in 50:
		await get_tree().process_frame
	await get_tree().create_timer(0.7).timeout
	check(router.release_count == 1 and board._held.is_empty(), "annulation : callbacks visuels annulés proprement")
	# Mouvements réduits : état immédiat, pas de particules.
	Settings.set_value("reduced_motion", true)
	m.apply_path(1, path_a)
	router.handle(m.drain_events())
	check(board._held.is_empty() and vfx.active_particles() == 0, "mouvements réduits : changement d'état immédiat, zéro particule")
	check(not vfx.play("connect", Vector2.ZERO), "VFX supprimés en mode réduit")
	Settings.set_value("reduced_motion", false)
	# Plafond de particules et gros effets
	vfx.stop_all()
	var ok := 0
	for i in 12:
		if vfx.play("hatch", Vector2.ZERO):
			ok += 1
	check(ok <= vfx.max_big and vfx.active_particles() <= vfx.cap, "plafond : %d gros effets, %d particules" % [ok, vfx.active_particles()])
	for i in 40:
		vfx.play("trail", Vector2.ZERO)
	check(vfx.active_particles() <= vfx.cap, "plafond global respecté (%d/%d)" % [vfx.active_particles(), vfx.cap])
	# Sons de tracé limités
	AudioService.played_log.clear()
	AudioService.trace_begin()
	for n in range(2, 40):
		AudioService.trace_segment(n)
	check(AudioService.played_log.size() <= 1 + AudioService.TRACE_MAX_PER_GESTURE, "sons de tracé limités (%d)" % AudioService.played_log.size())
	# Audio : suspension / reprise
	Settings.set_value("music_on", false)
	AudioService.suspend("ad")
	check(AudioServer.is_bus_mute(0), "audio suspendu pendant une publicité")
	AudioService.suspend("background")
	AudioService.resume("ad")
	check(AudioServer.is_bus_mute(0), "toujours suspendu en arrière-plan")
	AudioService.resume("background")
	check(not AudioServer.is_bus_mute(0) and AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "préférences restaurées au retour")
	Settings.set_value("music_on", true)
	for b in AudioService.BUSES:
		check(AudioServer.get_bus_send(AudioServer.get_bus_index(b)) == &"Master", "bus %s -> Master" % b)
	for n in [board, vfx, dragon, router]:
		n.queue_free()


# ---------------------------------------------------------------- gestes et écrans

func test_gesture_and_screens() -> void:
	begin("gestes tactiles et écrans")
	var m := model_for(11)
	var board := BoardView.new()
	board.size = Vector2(500, 500)
	add_child(board)
	board.set_model(m)
	var g := GestureController.new()
	add_child(g)
	g.bind(m, board)
	var cs := board.cell_size()
	var at := func(x: float, y: float) -> Vector2: return Vector2((x + 0.5) * cs, (y + 0.5) * cs)
	g.press(0, at.call(0, 0))
	g.drag(at.call(4, 0))  # glissé rapide : cases intermédiaires comblées
	check(m.draft.size() == 5, "mouvement rapide comblé orthogonalement")
	g.drag(Vector2(-50, -50))
	check(m.draft.size() == 5, "hors plateau : ajout suspendu")
	g.drag(at.call(2, 0))
	check(m.draft.size() == 3, "retour sur une case tracée")
	g.drag(at.call(4, 0))
	g.release()
	check(m.paths.has(1), "validation au relâchement sur la destination")
	g.press(0, at.call(1, 1))
	g.drag(at.call(2, 1))
	g.cancel()
	check(m.draft_pair == 0 and m.paths.size() == 1 and m.validate() == "", "pause pendant un tracé : état sain")
	# Petit écran : cases d'au moins 36 unités logiques sur 8x8 (360x640, 1 unité = 3 px)
	var unit := 3.0
	var board_px := 1080.0 - 2 * 24.0
	check(board_px / 8.0 / unit >= 36.0, "case 8x8 = %.1f unités (>= 36)" % (board_px / 8.0 / unit))
	metrics["cell_units_8x8"] = snappedf(board_px / 8.0 / unit, 0.1)
	board.queue_free()
	g.queue_free()
	if not ResourceLoader.exists("res://src/main.tscn"):
		return
	# Parcours de tous les écrans sans erreur de script, en FR et en EN.
	var main: Node = load("res://src/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	if not main.has_method("go"):
		main.queue_free()
		return
	for lang in ["fr", "en"]:
		Settings.set_value("language", lang)
		for screen in ["home", "map", "collection", "shop", "settings", "restoration"]:
			main.go(screen, {}, true)
			for fr in 4:
				await get_tree().process_frame
			check(main.current_name == screen, "écran %s (%s)" % [screen, lang])
			check(_min_button_ok(main), "boutons >= 48 unités sur %s" % screen)
	Settings.set_value("language", "auto")
	# Une partie complète pilotée par l'interface : niveau 1.
	Progression.reset_all()
	main.go("puzzle", {"index": 1}, true)
	await get_tree().process_frame
	await get_tree().process_frame
	var ps = main.current
	check(ps.model != null and ps.model.level_id == "level_001", "écran puzzle chargé")
	var ref := LevelLoader.reference_paths(ps.model.level)
	ps.model.apply_path(1, ref[1])
	ps.on_model_touched()
	ps.request_undo()
	check(ps.model.paths.is_empty(), "bouton annuler")
	ps.request_hint()
	check(ps.board.hint_path.size() == 2, "indice : prochain segment révélé")
	# Fermeture/réouverture en cours de partie
	ps.model.apply_path(1, ref[1])
	ps.on_model_touched()
	main.go("home", {}, true)
	await get_tree().process_frame
	main.go("puzzle", {"index": 1}, true)
	await get_tree().process_frame
	ps = main.current
	check(ps.model.paths.has(1) and ps.model.validate() == "", "partie en cours restaurée à la réouverture")
	ps.model.apply_path(2, ref[2])
	ps.on_model_touched()
	check(ps.model.completed and Progression.is_cleared(1) and Progression.state["seeds"] == 1, "victoire du modèle -> graine unique")
	check(int(Analytics.counts.get("level_complete", 0)) >= 1 and int(Analytics.counts.get("level_start", 0)) >= 1, "mesures de niveau")
	for i in 5:
		await get_tree().process_frame
	main.go("win", {"index": 1, "result": {"first": true, "seeds": 1, "milestone": 0, "companion": ""}}, true)
	await get_tree().process_frame
	check(main.current_name == "win", "écran de réussite")
	main.queue_free()
	Progression.reset_all()


func _min_button_ok(root: Node) -> bool:
	var ok := true
	for n in root.find_children("*", "BaseButton", true, false):
		var b := n as Control
		if b.is_visible_in_tree() and (b.size.x < 144.0 - 0.5 or b.size.y < 144.0 - 0.5):
			printerr("  bouton trop petit : %s %s" % [b.name, b.size])
			ok = false
	return ok
