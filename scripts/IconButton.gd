class_name IconButton
extends Control

## Round white button with a vector icon and no text, so a child who cannot read can
## use it. The whole control rect is the hit area (at least HIT x HIT); the disc is
## drawn smaller inside it. Touch-down only shows feedback and starts `held(true)`;
## `pressed` fires on release inside the rect, so a resting palm or a finger sliding
## off does nothing.

signal pressed
signal held(down: bool)

## Hit area side in px: 12.7 mm at 430 dpi (216 / 16.93 px per mm).
const HIT := 216.0
const INK := Color(0.2, 0.3, 0.36)

var kind := "restart"
## Drawn disc radius; the hit area is the whole control.
var disc_radius := 62.0
## Filled disc colour with a white icon; transparent keeps the white disc.
var accent := Color(0, 0, 0, 0)
## Draw only the icon, no disc (decorations such as the win star).
var bare := false
## Extra hit area above the disc (px): a top-row button pushed below a camera
## cutout keeps its touch area running to the screen edge.
var top_pad := 0.0
var _held := false
var _press := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(HIT, HIT)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_held = true
			held.emit(true)
		elif _held:
			_held = false
			held.emit(false)
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
		_set_press(1.0 if _held else 0.0)
		accept_event()
	elif event is InputEventMouseMotion and _held:
		_set_press(1.0 if Rect2(Vector2.ZERO, size).has_point(event.position) else 0.0)


func _set_press(v: float) -> void:
	if _press != v:
		_press = v
		queue_redraw()


func disc_center() -> Vector2:
	return Vector2(size.x * 0.5, top_pad + (size.y - top_pad) * 0.5)


func _draw() -> void:
	var c := disc_center()
	var rad := disc_radius * (1.0 - 0.08 * _press)
	var ink := INK
	if not bare:
		draw_circle(c + Vector2(0, 5), rad, Color(0, 0, 0, 0.12))
		if accent.a > 0.0:
			draw_circle(c, rad, accent.darkened(0.15) if _press > 0.0 else accent)
			ink = Color.WHITE
		else:
			draw_circle(c, rad, Color(0.9, 0.95, 0.95, 0.95) if _press > 0.0 else Color(1, 1, 1, 0.92))
	# Icons are drawn in a 100 px design box around the centre, then scaled.
	var k := rad / 50.0
	draw_set_transform(c, 0.0, Vector2(k, k))
	draw_icon(self, kind, ink, Color.WHITE if accent.a == 0.0 else accent)
	draw_set_transform(Vector2.ZERO)


## Draws one icon centred on the origin in a 100 px box. `bg` is the colour under
## the icon, used for cut-outs (sponge holes).
static func draw_icon(ci: CanvasItem, what: String, ink: Color, bg: Color) -> void:
	match what:
		"restart":
			ci.draw_arc(Vector2.ZERO, 22, PI * 0.35, PI * 1.95, 28, ink, 7.0, true)
			var tip := Vector2(22, -4)
			_tri(ci, tip + Vector2(-12, -6), tip + Vector2(12, -6), tip + Vector2(0, 10), ink)
		"eye":
			var pts := PackedVector2Array()
			for k in 25:
				var a := PI * k / 24.0
				pts.append(Vector2(-cos(a) * 30, -sin(a) * 17))
			for k in 25:
				var a := PI * k / 24.0
				pts.append(Vector2(cos(a) * 30, sin(a) * 17))
			ci.draw_polyline(pts, ink, 5.0, true)
			ci.draw_circle(Vector2.ZERO, 10, ink)
		"sound_on", "sound_off":
			var sp := PackedVector2Array([Vector2(-26, -10), Vector2(-14, -10), Vector2(2, -24), Vector2(2, 24), Vector2(-14, 10), Vector2(-26, 10)])
			ci.draw_colored_polygon(sp, ink)
			if what == "sound_on":
				ci.draw_arc(Vector2(4, 0), 14, -0.9, 0.9, 12, ink, 5.0, true)
				ci.draw_arc(Vector2(4, 0), 26, -0.9, 0.9, 16, ink, 5.0, true)
			else:
				ci.draw_line(Vector2(10, -12), Vector2(30, 12), ink, 6.0)
				ci.draw_line(Vector2(30, -12), Vector2(10, 12), ink, 6.0)
		"music_on", "music_off":
			ci.draw_line(Vector2(-8, 16), Vector2(-8, -20), ink, 6.0)
			ci.draw_line(Vector2(16, 10), Vector2(16, -26), ink, 6.0)
			ci.draw_line(Vector2(-8, -20), Vector2(16, -26), ink, 8.0)
			ci.draw_circle(Vector2(-15, 17), 9, ink)
			ci.draw_circle(Vector2(9, 11), 9, ink)
			if what == "music_off":
				ci.draw_line(Vector2(-26, -26), Vector2(26, 26), Color(0.85, 0.3, 0.25), 6.0)
		"next":
			ci.draw_line(Vector2(-26, 0), Vector2(6, 0), ink, 14.0)
			_tri(ci, Vector2(0, -26), Vector2(30, 0), Vector2(0, 26), ink)
		"star":
			var st := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + PI * i / 5.0
				st.append(Vector2(cos(a), sin(a)) * (40.0 if i % 2 == 0 else 17.0))
			ci.draw_colored_polygon(st, Color(1.0, 0.8, 0.25))
			ci.draw_polyline(st + PackedVector2Array([st[0]]), Color(0.85, 0.6, 0.1), 3.0, true)
		"check":
			ci.draw_polyline(PackedVector2Array([Vector2(-22, 2), Vector2(-6, 18), Vector2(24, -16)]), ink, 10.0, true)
		"tap":
			# Fingertip with ripples: "touch here".
			ci.draw_circle(Vector2.ZERO, 11, ink)
			ci.draw_arc(Vector2.ZERO, 23, 0, TAU, 32, ink, 5.0, true)
			ci.draw_arc(Vector2.ZERO, 35, 0, TAU, 40, Color(ink, ink.a * 0.45), 4.0, true)
		"drag":
			# Fingertip with a ring, sliding along an arrow.
			ci.draw_circle(Vector2(-24, 0), 10, ink)
			ci.draw_arc(Vector2(-24, 0), 20, 0, TAU, 28, Color(ink, ink.a * 0.5), 4.0, true)
			ci.draw_line(Vector2(-8, 0), Vector2(22, 0), ink, 7.0)
			_tri(ci, Vector2(18, -13), Vector2(36, 0), Vector2(18, 13), ink)
		_:
			_draw_tool(ci, what, ink, bg)


## One icon per cleaning stage (Levels.STAGES keys).
static func _draw_tool(ci: CanvasItem, what: String, ink: Color, bg: Color) -> void:
	match what:
		"trash":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-21, -12), Vector2(21, -12), Vector2(16, 32), Vector2(-16, 32)]), ink)
			ci.draw_line(Vector2(-28, -20), Vector2(28, -20), ink, 7.0)
			ci.draw_rect(Rect2(-8, -31, 16, 9), ink, false, 5.0)
			for x in [-8.0, 0.0, 8.0]:
				ci.draw_line(Vector2(x, -4), Vector2(x * 0.8, 24), bg, 3.0)
		"spray":
			_drop(ci, Vector2(0, 2), 17.0, ink)
			_drop(ci, Vector2(-26, 14), 8.0, ink)
			_drop(ci, Vector2(26, 14), 8.0, ink)
		"rinse":
			_drop(ci, Vector2(-10, 4), 16.0, ink)
			ci.draw_arc(Vector2(20, 16), 10, 0, TAU, 20, ink, 4.0, true)
			ci.draw_arc(Vector2(22, -14), 7, 0, TAU, 16, ink, 4.0, true)
		"vacuum":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-28, 14), Vector2(28, 14), Vector2(22, 26), Vector2(-22, 26)]), ink)
			ci.draw_line(Vector2(0, 14), Vector2(0, -12), ink, 8.0)
			ci.draw_arc(Vector2(14, -12), 14, PI, PI * 1.6, 12, ink, 8.0, true)
			for p in [Vector2(-16, 36), Vector2(0, 38), Vector2(16, 36)]:
				ci.draw_circle(p, 3.5, ink)
		"foam":
			for b in [Vector3(-14, 8, 16), Vector3(14, 10, 13), Vector3(2, -16, 12)]:
				ci.draw_arc(Vector2(b.x, b.y), b.z, 0, TAU, 28, ink, 5.0, true)
				ci.draw_circle(Vector2(b.x - b.z * 0.35, b.y - b.z * 0.35), b.z * 0.2, ink)
		"scrub":
			var sb := StyleBoxFlat.new()
			sb.bg_color = ink
			sb.set_corner_radius_all(10)
			ci.draw_style_box(sb, Rect2(-30, -18, 60, 36))
			for p in [Vector2(-16, -6), Vector2(4, -8), Vector2(18, 4), Vector2(-6, 8)]:
				ci.draw_circle(p, 4.0, bg)
		"grind":
			ci.draw_arc(Vector2(-6, 4), 22, 0, TAU, 32, ink, 7.0, true)
			ci.draw_circle(Vector2(-6, 4), 6, ink)
			for a in [-0.9, -0.5, -0.1]:
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(Vector2(-6, 4) + d * 30, Vector2(-6, 4) + d * 42, ink, 4.0)
		"paint":
			ci.draw_rect(Rect2(-18, -8, 26, 40), ink)
			ci.draw_rect(Rect2(-12, -18, 14, 10), ink)
			ci.draw_line(Vector2(2, -15), Vector2(10, -15), ink, 5.0)
			for p in [Vector2(20, -22), Vector2(28, -12), Vector2(30, -28), Vector2(22, -6)]:
				ci.draw_circle(p, 3.5, ink)
		"polish":
			_sparkle(ci, Vector2(-6, 6), 30.0, 8.0, ink)
			_sparkle(ci, Vector2(24, -22), 13.0, 4.0, ink)


static func _drop(ci: CanvasItem, c: Vector2, r: float, ink: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r * 1.7)])
	for i in 17:
		var a := -PI / 6.0 + (PI + PI / 3.0) * i / 16.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, ink)


static func _sparkle(ci: CanvasItem, c: Vector2, r: float, w: float, ink: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(w, -w), c + Vector2(r, 0), c + Vector2(w, w), c + Vector2(0, r), c + Vector2(-w, w), c + Vector2(-r, 0), c + Vector2(-w, -w)]), ink)


static func _tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, ink: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([a, b, c]), ink)
