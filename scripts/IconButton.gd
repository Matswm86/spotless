class_name IconButton
extends Control

## Round white button with a vector icon. Emits `pressed`, plus `held(bool)` for press-and-hold.

signal pressed
signal held(down: bool)

var kind := "restart"
var caption := ""
var _press := 0.0
const INK := Color(0.2, 0.3, 0.36)


func _init() -> void:
	custom_minimum_size = Vector2(120, 140)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = 1.0
			pressed.emit()
			held.emit(true)
		else:
			held.emit(false)
			var tw := create_tween()
			tw.tween_property(self, "_press", 0.0, 0.18)
		queue_redraw()
		accept_event()


func _process(_delta: float) -> void:
	if _press > 0.0:
		queue_redraw()


func _draw() -> void:
	var c := Vector2(size.x * 0.5, 56)
	var rad := 50.0 * (1.0 - 0.08 * _press)
	draw_circle(c + Vector2(0, 5), rad, Color(0, 0, 0, 0.12))
	draw_circle(c, rad, Color(1, 1, 1, 0.92))
	var ink := INK
	match kind:
		"restart":
			draw_arc(c, 22, PI * 0.35, PI * 1.95, 28, ink, 7.0, true)
			var tip := c + Vector2(22, -4)
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-12, -6), tip + Vector2(12, -6), tip + Vector2(0, 10)]), ink)
		"eye":
			var pts := PackedVector2Array()
			for k in 25:
				var a := PI * k / 24.0
				pts.append(c + Vector2(-cos(a) * 30, -sin(a) * 17))
			for k in 25:
				var a := PI * k / 24.0
				pts.append(c + Vector2(cos(a) * 30, sin(a) * 17))
			draw_polyline(pts, ink, 5.0, true)
			draw_circle(c, 10, ink)
		"sound_on", "sound_off":
			var sp := PackedVector2Array([c + Vector2(-26, -10), c + Vector2(-14, -10), c + Vector2(2, -24), c + Vector2(2, 24), c + Vector2(-14, 10), c + Vector2(-26, 10)])
			draw_colored_polygon(sp, ink)
			if kind == "sound_on":
				draw_arc(c + Vector2(4, 0), 14, -0.9, 0.9, 12, ink, 5.0, true)
				draw_arc(c + Vector2(4, 0), 26, -0.9, 0.9, 16, ink, 5.0, true)
			else:
				draw_line(c + Vector2(10, -12), c + Vector2(30, 12), ink, 6.0)
				draw_line(c + Vector2(30, -12), c + Vector2(10, 12), ink, 6.0)
		"music_on", "music_off":
			draw_line(c + Vector2(-8, 16), c + Vector2(-8, -20), ink, 6.0)
			draw_line(c + Vector2(16, 10), c + Vector2(16, -26), ink, 6.0)
			draw_line(c + Vector2(-8, -20), c + Vector2(16, -26), ink, 8.0)
			draw_circle(c + Vector2(-15, 17), 9, ink)
			draw_circle(c + Vector2(9, 11), 9, ink)
			if kind == "music_off":
				draw_line(c + Vector2(-26, -26), c + Vector2(26, 26), Color(0.85, 0.3, 0.25), 6.0)
	if caption != "":
		var font := get_theme_default_font()
		var fs := 26
		var w := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(c.x - w * 0.5 + 1, 132 + 2), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.8))
		draw_string(font, Vector2(c.x - w * 0.5, 132), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
