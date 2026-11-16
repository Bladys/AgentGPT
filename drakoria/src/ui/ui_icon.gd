class_name UIIcon
extends Control
## Icônes dessinées (toujours accompagnées d'une étiquette texte).

var kind := "":
	set(v):
		kind = v
		queue_redraw()
var color := UI.INK:
	set(v):
		color = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(54, 54)


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.42
	var w := maxf(r * 0.2, 4.0)
	match kind:
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r), c + Vector2(r, 0), c + Vector2(-r * 0.6, r)]), color)
		"pause":
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r), Vector2(r * 0.5, r * 2)), color)
			draw_rect(Rect2(c + Vector2(r * 0.2, -r), Vector2(r * 0.5, r * 2)), color)
		"undo":
			draw_arc(c, r * 0.8, -PI * 0.5, PI, 20, color, w, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.15, -r * 1.25), c + Vector2(-r * 0.15, -r * 0.35), c + Vector2(-r * 0.85, -r * 0.8)]), color)
		"restart":
			draw_arc(c, r * 0.8, 0.3, TAU - 0.5, 24, color, w, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.35, -r * 0.75), c + Vector2(r * 1.2, -r * 0.55), c + Vector2(r * 0.75, r * 0.05)]), color)
		"hint":
			draw_circle(c + Vector2(0, -r * 0.2), r * 0.62, color)
			draw_rect(Rect2(c + Vector2(-r * 0.3, r * 0.5), Vector2(r * 0.6, r * 0.42)), color)
		"map":
			draw_polyline(PackedVector2Array([c + Vector2(-r, -r * 0.6), c + Vector2(-r * 0.33, -r * 0.9), c + Vector2(r * 0.33, -r * 0.6), c + Vector2(r, -r * 0.9), c + Vector2(r, r * 0.6), c + Vector2(r * 0.33, r * 0.9), c + Vector2(-r * 0.33, r * 0.6), c + Vector2(-r, r * 0.9), c + Vector2(-r, -r * 0.6)]), color, w, true)
		"collection":
			draw_circle(c + Vector2(0, r * 0.2), r * 0.7, color)
			draw_circle(c + Vector2(0, -r * 0.55), r * 0.45, color)
		"shop":
			draw_rect(Rect2(c + Vector2(-r * 0.85, -r * 0.3), Vector2(r * 1.7, r * 1.2)), color)
			draw_arc(c + Vector2(0, -r * 0.3), r * 0.5, PI, TAU, 16, color, w, true)
		"settings":
			draw_arc(c, r * 0.55, 0, TAU, 24, color, w * 1.2, true)
			for i in 8:
				var d := Vector2.from_angle(TAU * i / 8.0)
				draw_line(c + d * r * 0.7, c + d * r, color, w, true)
		"back":
			draw_polyline(PackedVector2Array([c + Vector2(r * 0.4, -r * 0.8), c + Vector2(-r * 0.5, 0), c + Vector2(r * 0.4, r * 0.8)]), color, w * 1.2, true)
		"lock":
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.1), Vector2(r * 1.4, r * 1.1)), color)
			draw_arc(c + Vector2(0, -r * 0.1), r * 0.48, PI, TAU, 16, color, w, true)
		"check":
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.8, 0), c + Vector2(-r * 0.2, r * 0.6), c + Vector2(r * 0.9, -r * 0.6)]), color, w * 1.3, true)
		"seed":
			draw_circle(c + Vector2(0, r * 0.25), r * 0.6, color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.2), c + Vector2(r * 0.7, -r), c + Vector2(r * 0.1, -r * 0.95)]), color)
		"garden":
			draw_line(c + Vector2(0, r), c + Vector2(0, -r * 0.1), color, w, true)
			for i in 5:
				draw_circle(c + Vector2(0, -r * 0.4) + Vector2.from_angle(TAU * i / 5.0) * r * 0.42, r * 0.28, color)
		"gift":
			draw_rect(Rect2(c + Vector2(-r * 0.8, -r * 0.2), Vector2(r * 1.6, r * 1.1)), color)
			draw_rect(Rect2(c + Vector2(-r * 0.95, -r * 0.6), Vector2(r * 1.9, r * 0.4)), color)
		"info":
			draw_arc(c, r * 0.9, 0, TAU, 24, color, w, true)
			draw_line(c + Vector2(0, -r * 0.1), c + Vector2(0, r * 0.5), color, w, true)
			draw_circle(c + Vector2(0, -r * 0.45), w * 0.6, color)
		"video":
			draw_rect(Rect2(c + Vector2(-r, -r * 0.65), Vector2(r * 2, r * 1.3)), color, false, w)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.3, -r * 0.35), c + Vector2(r * 0.4, 0), c + Vector2(-r * 0.3, r * 0.35)]), color)
		"next":
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.4, -r * 0.8), c + Vector2(r * 0.5, 0), c + Vector2(-r * 0.4, r * 0.8)]), color, w * 1.2, true)
