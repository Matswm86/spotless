class_name Swatch
extends Control

## A round paint-colour button. The whole control (216 px) is the hit area; it picks
## on release inside. Colour is never the only cue: each slot also carries a shape
## (dot, triangle, square, diamond), so two similar colours still differ.

signal pressed

var color := Color.WHITE
var selected := false
## Slot in the level's paint list; picks the shape.
var slot := 0
var _held := false


func _init() -> void:
	custom_minimum_size = Vector2(IconButton.HIT, IconButton.HIT)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_held = true
		elif _held:
			_held = false
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
		queue_redraw()
		accept_event()


func _draw() -> void:
	var c := size * 0.5
	var k := 0.92 if _held else 1.0
	draw_circle(c + Vector2(0, 5), 68 * k, Color(0, 0, 0, 0.15))
	draw_circle(c, (74 if selected else 64) * k, Color.WHITE)
	draw_circle(c, (60 if selected else 54) * k, color)
	draw_circle(c + Vector2(-17, -19) * k, 11 * k, Color(1, 1, 1, 0.35))
	var ink := Color(1, 1, 1, 0.9) if color.get_luminance() < 0.6 else Color(0.08, 0.1, 0.14, 0.75)
	var r := 15.0 * k
	match slot % 4:
		0:
			draw_circle(c, r, ink)
		1:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.3), c + Vector2(r * 1.15, r * 0.7), c + Vector2(-r * 1.15, r * 0.7)]), ink)
		2:
			draw_rect(Rect2(c - Vector2(r, r) * 0.9, Vector2(r, r) * 1.8), ink)
		3:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.3), c + Vector2(r * 1.3, 0), c + Vector2(0, r * 1.3), c + Vector2(-r * 1.3, 0)]), ink)
	if selected:
		# Selected also shows as a ring of ticks around the disc, not only by size.
		for i in 8:
			var a := TAU * i / 8.0
			draw_line(c + Vector2(cos(a), sin(a)) * 82 * k, c + Vector2(cos(a), sin(a)) * 96 * k, Color(1, 1, 1, 0.95), 6.0)
