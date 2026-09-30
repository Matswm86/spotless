class_name Swatch
extends Control

## A round paint-colour button.

signal pressed

var color := Color.WHITE
var selected := false


func _init() -> void:
	custom_minimum_size = Vector2(130, 130)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit()
		accept_event()


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c + Vector2(0, 5), 56, Color(0, 0, 0, 0.15))
	draw_circle(c, 58 if selected else 52, Color.WHITE)
	draw_circle(c, 46 if selected else 44, color)
	draw_circle(c + Vector2(-14, -16), 10, Color(1, 1, 1, 0.35))
