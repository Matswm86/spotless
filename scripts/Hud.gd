class_name Hud
extends CanvasLayer

## Screen overlay: level number, progress bar, the row of stage icons, colour swatches
## for the paint stage, the before/after button and the win card. No words, so a child
## who cannot read can play.
##
## Touch layout at 1080 px wide (MWM Play child rules):
## - every tappable target is at least IconButton.HIT (216 px = 12.7 mm at 430 dpi)
##   and acts on release;
## - the top-left HOME_CORNER square stays empty for the MWM Play home button;
## - nothing tappable in the bottom WRIST strip;
## - top-row items move below a phone's camera cutout; their touch areas still run
##   to the top edge.

signal next_pressed
signal restart_pressed
signal swatch_chosen(c: Color)
signal before_held(down: bool)

const ACCENT := Color(0.2, 0.7, 0.66)
const INK := Color(0.2, 0.3, 0.36)
const FONT := preload("res://assets/fonts/Fredoka.ttf")
const HIT := IconButton.HIT
## Top-left square kept free of UI (MWM Play home button, 216 px hit + 16 px gap).
const HOME_CORNER := 232.0
## Bottom strip with no targets (16 mm = 256 px).
const WRIST := 256.0
## Top of the info card; a camera cutout deeper than this pushes the top row down.
const TOP_ROW_CLEAR := 20.0
const CARD_H := 184.0

var root: Control
var top: Panel
var level_disc: Panel
var level_label: Label
var bar_bg: Panel
var bar_fill: Panel
var pct_label: Label
var chips: Array[StageChip] = []
var hint: IconButton
var swatches: Array[Swatch] = []
var restart_btn: IconButton
var before_btn: IconButton
var sound_btn: IconButton
var music_btn: IconButton
var win_panel: Control
var win_card: Panel
var win_star: IconButton
var next_btn: IconButton
## Test hook: a fake top safe-area inset in window px; < 0 = ask the display.
var fake_safe_top := -1.0
var _stage_keys: Array = []
var _stage_i := 0
var _shown := 0.0
var _target := 0.0
var _hint_t := 0.0


## Small stage marker: tool icon on a pill. Done = light with a tick badge, current =
## filled and taller, upcoming = grey; shape and tick tell them apart, not only colour.
class StageChip:
	extends Control
	var key := ""
	var state := 0  # 0 upcoming, 1 current, 2 done

	func _draw() -> void:
		var inset := 0.0 if state == 1 else 8.0
		var r := Rect2(0, inset, size.x, size.y - inset * 2.0)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(r.size.y * 0.5))
		sb.anti_aliasing = true
		var ink := Color(0.55, 0.62, 0.66)
		match state:
			1:
				sb.bg_color = ACCENT.darkened(0.1)
				ink = Color.WHITE
			2:
				sb.bg_color = Color(0.86, 0.95, 0.93)
				ink = ACCENT.darkened(0.35)
			_:
				sb.bg_color = Color(0.93, 0.94, 0.95)
		draw_style_box(sb, r)
		var k := minf(r.size.y, 56.0) / 64.0
		draw_set_transform(size * 0.5, 0.0, Vector2(k, k))
		IconButton.draw_icon(self, key, ink, sb.bg_color)
		draw_set_transform(Vector2.ZERO)
		if state == 2:
			var c := Vector2(size.x - 14, 14)
			draw_circle(c, 14, ACCENT.darkened(0.35))
			draw_set_transform(c, 0.0, Vector2(0.4, 0.4))
			IconButton.draw_icon(self, "check", Color.WHITE, Color.WHITE)
			draw_set_transform(Vector2.ZERO)


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = FONT
	root.theme = th
	add_child(root)

	top = _panel(Rect2(0, 0, 600, CARD_H), Color(1, 1, 1, 0.9), 44)
	root.add_child(top)
	level_disc = _panel(Rect2(18, 16, 76, 76), ACCENT.darkened(0.1), 38)
	top.add_child(level_disc)
	level_label = _label("1", 46, Color.WHITE)
	level_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_disc.add_child(level_label)
	bar_bg = _panel(Rect2(112, 38, 340, 34), Color(0.88, 0.92, 0.93), 17)
	top.add_child(bar_bg)
	bar_fill = _panel(Rect2(0, 0, 34, 34), ACCENT, 17)
	bar_bg.add_child(bar_fill)
	pct_label = _label("0%", 40, ACCENT.darkened(0.2))
	pct_label.size = Vector2(120, 60)
	pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(pct_label)

	restart_btn = _button("restart")
	restart_btn.pressed.connect(func(): restart_pressed.emit())
	sound_btn = _button("sound_on" if Game.sound_on else "sound_off")
	sound_btn.pressed.connect(_toggle_sound)
	music_btn = _button("music_on" if Game.music_on else "music_off")
	music_btn.pressed.connect(_toggle_music)
	sound_btn.visible = not Game.in_shell()
	music_btn.visible = not Game.in_shell()
	before_btn = _button("eye")
	before_btn.held.connect(func(d): before_held.emit(d))

	hint = IconButton.new()
	hint.kind = "drag"
	hint.disc_radius = 78.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.modulate.a = 0.0
	root.add_child(hint)

	_build_win()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _button(k: String) -> IconButton:
	var b := IconButton.new()
	b.kind = k
	root.add_child(b)
	return b


func _panel(r: Rect2, c: Color, radius: int) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if c.a > 0.5 and c.v > 0.9:
		sb.shadow_color = Color(0, 0, 0, 0.12)
		sb.shadow_size = 18
		sb.shadow_offset = Vector2(0, 6)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(t: String, fs: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_win() -> void:
	win_panel = Control.new()
	win_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_panel.visible = false
	root.add_child(win_panel)
	win_card = _panel(Rect2(0, 0, 760, 380), Color(1, 1, 1, 0.95), 56)
	win_panel.add_child(win_card)
	# A star for the finished job, then one big arrow to the next object.
	win_star = IconButton.new()
	win_star.kind = "star"
	win_star.bare = true
	win_star.disc_radius = 120.0
	win_star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_star.position = Vector2(40, 30)
	win_star.size = Vector2(320, 320)
	win_card.add_child(win_star)
	next_btn = IconButton.new()
	next_btn.kind = "next"
	next_btn.accent = ACCENT.darkened(0.2)
	next_btn.disc_radius = 130.0
	next_btn.position = Vector2(400, 30)
	next_btn.size = Vector2(320, 320)
	next_btn.pressed.connect(func():
		Sfx.play("tap")
		next_pressed.emit())
	win_card.add_child(next_btn)


## Places everything for the current screen size and camera cutout.
func _layout() -> void:
	var vs := root.get_viewport_rect().size
	var dy := maxf(0.0, safe_top_inset() - TOP_ROW_CLEAR)
	# Info card between the home corner and the restart button.
	top.position = Vector2(HOME_CORNER + 16.0, TOP_ROW_CLEAR + dy)
	top.size = Vector2(vs.x - HOME_CORNER - 16.0 - HIT - 16.0, CARD_H)
	bar_bg.size.x = top.size.x - 112.0 - 140.0
	pct_label.position = Vector2(top.size.x - 136.0, 24)
	_layout_chips()
	# Top-right restart: touch area runs to the top and right screen edges.
	restart_btn.position = Vector2(vs.x - HIT, 0)
	restart_btn.size = Vector2(HIT, HIT + dy)
	restart_btn.top_pad = dy
	# Second row: eye below the home corner on the left edge, sound and music on the right.
	before_btn.position = Vector2(0, HOME_CORNER + dy)
	sound_btn.position = Vector2(vs.x - HIT * 2.0, HIT + dy)
	music_btn.position = Vector2(vs.x - HIT, HIT + dy)
	# Paint swatches sit just above the wrist strip.
	var n := swatches.size()
	for i in n:
		swatches[i].position = Vector2(vs.x * 0.5 + (i - n * 0.5) * HIT, vs.y - WRIST - HIT)
	var hint_y := vs.y - WRIST - HIT - (HIT if n > 0 else 0.0)
	hint.size = Vector2(HIT, HIT)
	hint.position = Vector2((vs.x - HIT) * 0.5, hint_y)
	win_card.position = Vector2((vs.x - win_card.size.x) * 0.5, vs.y - WRIST - 24.0 - win_card.size.y)
	for b in [restart_btn, before_btn, sound_btn, music_btn]:
		b.queue_redraw()


func _layout_chips() -> void:
	var n := chips.size()
	if n == 0:
		return
	var gap := 10.0
	var w := (top.size.x - 36.0 - gap * (n - 1)) / n
	for i in n:
		chips[i].position = Vector2(18.0 + i * (w + gap), 104)
		chips[i].size = Vector2(w, 68)


## Depth of the top screen cutout in viewport px (0 on desktop and on phones without
## a cutout in the drawn area). Uses the display safe area on phones, or fake_safe_top
## in tests.
func safe_top_inset() -> float:
	var top_px := fake_safe_top
	if top_px < 0.0:
		if not OS.has_feature("mobile"):
			return 0.0
		top_px = float(DisplayServer.get_display_safe_area().position.y)
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	return maxf(0.0, top_px * root.get_viewport_rect().size.y / float(win.y))


## Re-reads the cutout (call after changing fake_safe_top).
func apply_safe_area() -> void:
	_layout()


## True where a game target (rubbish) must not sit: under or next to a HUD button,
## or in the wrist strip.
func blocks(p: Vector2, margin: float) -> bool:
	if p.y > root.get_viewport_rect().size.y - WRIST - margin:
		return true
	for b: Control in [restart_btn, before_btn, sound_btn, music_btn]:
		if b.visible and b.get_global_rect().grow(margin).has_point(p):
			return true
	return false


## Top of the wrist strip in viewport px.
func wrist_top() -> float:
	return root.get_viewport_rect().size.y - WRIST


func set_level(index: int, _name: String, stage_keys: Array) -> void:
	level_label.text = str(index + 1)
	_stage_keys = stage_keys
	win_panel.visible = false
	hide_swatches()
	for c in chips:
		c.queue_free()
	chips.clear()
	for k in stage_keys:
		var chip := StageChip.new()
		chip.key = String(k)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(chip)
		chips.append(chip)
	_layout_chips()
	set_stage(0)
	set_progress(0.0, true)


func set_stage(i: int) -> void:
	_stage_i = i
	for k in chips.size():
		chips[k].state = 2 if k < i else (1 if k == i else 0)
		chips[k].queue_redraw()


func set_progress(p: float, instant := false) -> void:
	_target = clampf(p, 0.0, 1.0)
	if instant:
		_shown = _target


## Shows a wordless hint for the current stage: a tapping finger for the rubbish,
## a sliding finger for every tool. The text is not shown (non-readers).
func show_hint(_t: String) -> void:
	var key: String = _stage_keys[_stage_i] if _stage_i < _stage_keys.size() else ""
	hint.kind = "tap" if key == "trash" else "drag"
	hint.queue_redraw()
	_hint_t = 0.0
	hint.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(hint, "modulate:a", 1.0, 0.4)


func hide_hint() -> void:
	if hint.modulate.a > 0.0:
		var tw := create_tween()
		tw.tween_property(hint, "modulate:a", 0.0, 0.5)


func show_swatches(colors: Array, chosen: Color) -> void:
	hide_swatches()
	for i in colors.size():
		var col: Color = colors[i]
		var b := Swatch.new()
		b.color = col
		b.slot = i
		b.selected = col == chosen
		b.pressed.connect(func():
			for s in swatches:
				s.selected = s == b
				s.queue_redraw()
			Sfx.play("tap")
			swatch_chosen.emit(col))
		root.add_child(b)
		swatches.append(b)
	_layout()


func hide_swatches() -> void:
	for s in swatches:
		s.queue_free()
	swatches.clear()
	_layout()


## `_sub` (a line of English praise) is not shown: the card is a star and an arrow.
func show_win(_sub: String) -> void:
	win_panel.visible = true
	win_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(win_panel, "modulate:a", 1.0, 0.5)
	hide_hint()


func _toggle_sound() -> void:
	Game.sound_on = not Game.sound_on
	sound_btn.kind = "sound_on" if Game.sound_on else "sound_off"
	sound_btn.queue_redraw()
	Sfx.apply_settings()
	Game.save_game()


func _toggle_music() -> void:
	Game.music_on = not Game.music_on
	music_btn.kind = "music_on" if Game.music_on else "music_off"
	music_btn.queue_redraw()
	Sfx.apply_settings()
	Game.save_game()


func _process(delta: float) -> void:
	_shown = move_toward(_shown, _target, delta * 1.5)
	var w := bar_bg.size.x
	bar_fill.size.x = maxf(34.0, w * _shown)
	bar_fill.visible = _shown > 0.005
	pct_label.text = "%d%%" % int(round(_shown * 100.0))
	if hint.modulate.a > 0.0:
		# The hint finger slides (tools) or pulses (rubbish) so it reads as a gesture.
		_hint_t += delta
		var base_x := (root.get_viewport_rect().size.x - HIT) * 0.5
		if hint.kind == "drag":
			hint.position.x = base_x + sin(_hint_t * 2.4) * 70.0
			hint.scale = Vector2.ONE
		else:
			hint.position.x = base_x
			hint.pivot_offset = hint.size * 0.5
			hint.scale = Vector2.ONE * (1.0 + 0.08 * sin(_hint_t * 4.0))
