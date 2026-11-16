class_name DragonStage
extends Control
## Cadre d'affichage d'un compagnon : centre le pivot (pieds) en bas du cadre.

signal tapped

var animator: DragonAnimator
var display_scale := 1.0


func _init() -> void:
	animator = DragonAnimator.new()
	add_child(animator)
	resized.connect(_place)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _place() -> void:
	animator.position = Vector2(size.x / 2.0, size.y - 12.0)
	animator.scale = Vector2(display_scale, display_scale)


func _ready() -> void:
	_place()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		tapped.emit()
