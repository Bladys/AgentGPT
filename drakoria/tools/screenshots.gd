extends Node
## Captures d'écran de contrôle (nécessite un affichage, p. ex. xvfb) :
##   DRAKORIA_SAVE_ROOT=user://shots_tmp/ xvfb-run -a godot --path . --rendering-driver opengl3 \
##     --resolution 540x960 res://tools/screenshots.tscn -- <dossier_sortie> [fr|en]

var out := "user://shots/"
var main: Node


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	Settings.persist = false
	Settings.set_value("language", a[1] if a.size() > 1 else "fr")
	DirAccess.make_dir_recursive_absolute(out)
	Progression.reset_all()
	main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await shot("home", "01_home_new")
	main.go("puzzle", {"index": 1}, true)
	await shot("", "02_puzzle_level1")
	for i in range(1, 31):
		Progression.complete_level(i)
	Progression.state["garden_steps"] = 17
	Progression.state["seeds"] = 13
	await shot("home", "03_home_progress")
	await shot("map", "04_map")
	main.go("puzzle", {"index": 11}, true)
	await wait(4)
	var ps = main.current
	ps.model.begin_draft(Vector2i(1, 1))
	ps.model.extend_draft(Vector2i(2, 1))
	ps.model.extend_draft(Vector2i(2, 2))
	ps.on_model_touched()
	await shot("", "05_puzzle_bridge_blocked")
	ps.model.end_draft()
	ps.model.apply_path(1, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)])
	ps.on_model_touched()
	await get_tree().create_timer(1.0).timeout
	ps.request_hint()
	await shot("", "06_puzzle_bridge_grown_hint")
	for lvl in [21, 31]:
		main.go("puzzle", {"index": lvl}, true)
		await shot("", "07_puzzle_level%d" % lvl)
	Progression.state["cleared"] = range(1, 50)
	main.go("puzzle", {"index": 50}, true)
	await wait(4)
	ps = main.current
	var ref := LevelLoader.reference_paths(ps.model.level)
	var order: Array = ps.model.level["reference_solution"]["order"]
	for k in order.size() - 1:
		ps.model.apply_path(int(order[k]), ref[int(order[k])])
	ps.on_model_touched()
	await get_tree().create_timer(1.2).timeout
	await shot("", "08_puzzle_level50_8x8")
	main.go("win", {"index": 12, "result": {"first": true, "seeds": 1, "milestone": 0, "companion": ""}}, true)
	await shot("", "09_win")
	await shot("restoration", "10_restoration")
	await shot("collection", "11_collection")
	await shot("shop", "12_shop")
	Purchases.request_purchase("remove_interstitials")
	await shot("", "13_shop_demo_dialog")
	main.close_dialog()
	await shot("settings", "14_settings")
	Settings.set_value("text_scale", 1.3)
	await wait(3)
	main.go("puzzle", {"index": 5}, true)
	await shot("", "15_puzzle_xlarge_text")
	get_tree().quit()


func wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(screen: String, name: String) -> void:
	if screen != "":
		main.go(screen, {}, true)
	await wait(6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("capture ", name)
