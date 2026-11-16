extends ScreenBase
## Restauration : chaque graine restaure une étape du jardin ; une
## restauration principale toutes les dix premières réussites.

var _garden: GardenView
var _seeds: Label
var _plant: UIButton
var _stage: DragonStage
var _vfx: VFXService


func build() -> void:
	header(UI.tr_key("garden.title"))
	_seeds = UI.label("", 18, UI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_seeds)
	var body := scroll_body()
	_garden = GardenView.new()
	_garden.total = int(Progression.config["garden"]["steps_per_island"]) + int(Progression.config["garden"]["bonus_plots"])
	body.add_child(_garden)
	var card := UI.card()
	var v := UI.vbox(12)
	card.add_child(v)
	v.add_child(UI.label(UI.tr_key("garden.milestones"), 17, UI.INK))
	var names: Array = Progression.config["milestones"]
	for i in names.size():
		var reached := Progression.milestones_reached() > i
		var h := UI.hbox(18)
		var ic := UIIcon.new()
		ic.kind = "check" if reached else "lock"
		ic.color = UI.GREEN if reached else UI.INK_SOFT
		h.add_child(ic)
		h.add_child(UI.label(UI.tr_key("garden.m.%s" % names[i]) + " — " + (UI.tr_key("garden.restored") if reached
			else UI.tr_key("garden.after", {"n": (i + 1) * int(Progression.config["milestone_every"])})), 14, UI.INK))
		v.add_child(h)
	body.add_child(card)
	_stage = DragonStage.new()
	_stage.custom_minimum_size = Vector2(0, 260)
	_stage.display_scale = 1.3
	if Progression.companion_unlocked("brindille"):
		_stage.animator.setup("brindille")
	body.add_child(_stage)
	_plant = UI.button(UI.tr_key("garden.plant"), "seed", "primary", _on_plant)
	root.add_child(_plant)
	_vfx = VFXService.new()
	add_child(_vfx)
	# Restauration principale non encore fêtée.
	if Progression.milestones_reached() > int(Progression.state["milestones_seen"]):
		Progression.state["milestones_seen"] = Progression.milestones_reached()
		Progression.save()
		_celebrate.call_deferred()
	_update()


func _update() -> void:
	_garden.steps = int(Progression.state["garden_steps"])
	_garden.capacity = Progression.garden_capacity()
	_garden.queue_redraw()
	_seeds.text = UI.tr_key("garden.seeds", {"n": Progression.state["seeds"], "steps": Progression.state["garden_steps"]})
	_plant.disabled = not Progression.can_restore()
	_plant.set_label(UI.tr_key("garden.plant") if Progression.can_restore() or int(Progression.state["seeds"]) == 0 else UI.tr_key("garden.full"))


func _on_plant() -> void:
	if Progression.restore_step():   # le modèle de progression décide ; le visuel accompagne
		Analytics.track("garden_restore", {"step": Progression.state["garden_steps"]})
		_celebrate()
	_update()


func _celebrate() -> void:
	AudioService.play_sfx("sfx_restore")
	_vfx.play("restore", Vector2(size.x * 0.08, size.y * 0.3), Color("9ccf8a"))   # en bordure, jamais sur un bouton
	if _stage.animator.companion != "":
		_stage.animator.play("celebrate")


func on_exit() -> void:
	_stage.animator.cancel()
	_vfx.stop_all()
