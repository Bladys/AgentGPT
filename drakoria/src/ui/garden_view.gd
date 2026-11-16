class_name GardenView
extends Control
## Jardin provisoire dessiné : une parcelle par étape restaurée. Le fond
## peint de l'île (bg_island_N) le remplacera ; la logique ne change pas.

var steps := 0
var capacity := 0
var total := 60
var milestones := 0


func _init() -> void:
	custom_minimum_size = Vector2(0, 620)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var cols := 10
	var rows := int(ceil(float(total) / cols))
	var cs := minf(size.x / cols, size.y / rows)
	var o := Vector2((size.x - cs * cols) / 2.0, 0)
	for i in total:
		var c := o + Vector2(i % cols, i / cols) * cs + Vector2(cs, cs) / 2.0
		var r := cs * 0.42
		if i < steps:
			draw_circle(c, r, Color("9ccf8a"))
			for k in 5:
				draw_circle(c + Vector2.from_angle(TAU * k / 5.0 + i) * r * 0.5, r * 0.3, Color("e8623a") if i % 3 else Color("e9b93a"))
			draw_circle(c, r * 0.22, Color("fbf6e6"))
		elif i < capacity:
			draw_circle(c, r, Color("cdbf9f"))
			draw_arc(c, r, 0, TAU, 24, UI.INK, 3.0, true)   # parcelle prête : cercle cerné
		else:
			draw_circle(c, r * 0.6, Color("d9cfb8"))        # parcelle encore endormie : petit point
