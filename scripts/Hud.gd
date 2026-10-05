class_name Hud
extends CanvasLayer

## Screen overlay: level title, progress bar, the row of stages, colour swatches for the
## paint stage, the before/after button and the "Spotless!" card.

signal next_pressed
signal restart_pressed
signal swatch_chosen(c: Color)
signal before_held(down: bool)

const ACCENT := Color(0.2, 0.7, 0.66)
const INK := Color(0.2, 0.3, 0.36)
const FONT := preload("res://assets/fonts/Fredoka.ttf")

var root: Control
var level_label: Label
var title_label: Label
var bar_bg: Panel
var bar_fill: Panel
var pct_label: Label
var chips: HBoxContainer
var hint: Label
var swatches: HBoxContainer
var before_btn: IconButton
var sound_btn: IconButton
var music_btn: IconButton
var win_panel: Control
var win_title: Label
var win_sub: Label
var _stage_names: Array = []
var _stage_i := 0
var _shown := 0.0
var _target := 0.0


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = FONT
	root.theme = th
	add_child(root)

	var top := _panel(Rect2(40, 60, 1000, 290), Color(1, 1, 1, 0.9), 44)
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-500, 60)
	root.add_child(top)
	level_label = _label("Level 1", 36, Color(0.45, 0.55, 0.6))
	level_label.position = Vector2(44, 22)
	top.add_child(level_label)
	title_label = _label("", 60, INK)
	title_label.position = Vector2(44, 58)
	top.add_child(title_label)
	pct_label = _label("0%", 44, ACCENT.darkened(0.2))
	pct_label.position = Vector2(700, 70)
	pct_label.size = Vector2(256, 60)
	pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(pct_label)
	bar_bg = _panel(Rect2(44, 150, 912, 34), Color(0.88, 0.92, 0.93), 17)
	top.add_child(bar_bg)
	bar_fill = _panel(Rect2(0, 0, 34, 34), ACCENT, 17)
	bar_bg.add_child(bar_fill)
	chips = HBoxContainer.new()
	chips.position = Vector2(44, 208)
	chips.size = Vector2(912, 60)
	chips.add_theme_constant_override("separation", 14)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(chips)

	sound_btn = IconButton.new()
	sound_btn.kind = "sound_on" if Game.sound_on else "sound_off"
	sound_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sound_btn.position = Vector2(-150, 370)
	sound_btn.pressed.connect(_toggle_sound)
	root.add_child(sound_btn)
	music_btn = IconButton.new()
	music_btn.kind = "music_on" if Game.music_on else "music_off"
	music_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	music_btn.position = Vector2(-150, 510)
	music_btn.pressed.connect(_toggle_music)
	root.add_child(music_btn)
	sound_btn.visible = not Game.in_shell()
	music_btn.visible = not Game.in_shell()
	var restart := IconButton.new()
	restart.kind = "restart"
	restart.set_anchors_preset(Control.PRESET_TOP_LEFT)
	restart.position = Vector2(30, 370)
	restart.pressed.connect(func(): restart_pressed.emit())
	root.add_child(restart)

	before_btn = IconButton.new()
	before_btn.kind = "eye"
	before_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	before_btn.position = Vector2(30, -200)
	before_btn.held.connect(func(d): before_held.emit(d))
	root.add_child(before_btn)

	hint = _label("", 42, INK)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-400, -350)
	hint.size = Vector2(800, 96)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(1, 1, 1, 0.88)
	hsb.set_corner_radius_all(48)
	hsb.anti_aliasing = true
	hint.add_theme_stylebox_override("normal", hsb)
	root.add_child(hint)

	swatches = HBoxContainer.new()
	swatches.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	swatches.position = Vector2(-330, -210)
	swatches.size = Vector2(660, 130)
	swatches.alignment = BoxContainer.ALIGNMENT_CENTER
	swatches.add_theme_constant_override("separation", 30)
	swatches.visible = false
	root.add_child(swatches)

	_build_win()


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
	var card := _panel(Rect2(0, 0, 820, 420), Color(1, 1, 1, 0.95), 56)
	card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	card.position = Vector2(-410, -560)
	win_panel.add_child(card)
	win_title = _label("Spotless!", 96, ACCENT.darkened(0.15))
	win_title.position = Vector2(0, 30)
	win_title.size = Vector2(820, 120)
	win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(win_title)
	win_sub = _label("", 40, Color(0.45, 0.55, 0.6))
	win_sub.position = Vector2(0, 150)
	win_sub.size = Vector2(820, 60)
	win_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(win_sub)
	var next := Button.new()
	next.text = "Next"
	next.add_theme_font_size_override("font_size", 60)
	next.position = Vector2(210, 250)
	next.size = Vector2(400, 130)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = ACCENT if st != "pressed" else ACCENT.darkened(0.15)
		sb.set_corner_radius_all(65)
		sb.anti_aliasing = true
		next.add_theme_stylebox_override(st, sb)
	next.add_theme_color_override("font_color", Color.WHITE)
	next.add_theme_color_override("font_hover_color", Color.WHITE)
	next.add_theme_color_override("font_pressed_color", Color.WHITE)
	next.add_theme_color_override("font_focus_color", Color.WHITE)
	next.pressed.connect(func():
		Sfx.play("tap")
		next_pressed.emit())
	card.add_child(next)


func set_level(index: int, name: String, stage_names: Array) -> void:
	level_label.text = "Level %d" % (index + 1)
	title_label.text = name
	_stage_names = stage_names
	win_panel.visible = false
	swatches.visible = false
	set_stage(0)
	set_progress(0.0, true)


func set_stage(i: int) -> void:
	_stage_i = i
	for c in chips.get_children():
		c.queue_free()
	for k in _stage_names.size():
		var done := k < i
		var cur := k == i
		var chip := _panel(Rect2(0, 0, 0, 56), ACCENT if cur else (Color(0.86, 0.95, 0.93) if done else Color(0.93, 0.94, 0.95)), 28)
		chip.custom_minimum_size = Vector2(maxf(150, 912.0 / _stage_names.size() - 14), 56)
		var l := _label(String(_stage_names[k]), 34, Color.WHITE if cur else (ACCENT.darkened(0.25) if done else Color(0.55, 0.62, 0.66)))
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_child(l)
		chips.add_child(chip)


func set_progress(p: float, instant := false) -> void:
	_target = clampf(p, 0.0, 1.0)
	if instant:
		_shown = _target


func show_hint(t: String) -> void:
	hint.text = t
	hint.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(hint, "modulate:a", 1.0, 0.4)


func hide_hint() -> void:
	if hint.modulate.a > 0.0:
		var tw := create_tween()
		tw.tween_property(hint, "modulate:a", 0.0, 0.5)


func show_swatches(colors: Array, chosen: Color) -> void:
	for c in swatches.get_children():
		c.queue_free()
	for col in colors:
		var b := Swatch.new()
		b.color = col
		b.selected = col == chosen
		b.pressed.connect(func():
			for s in swatches.get_children():
				(s as Swatch).selected = s == b
				s.queue_redraw()
			Sfx.play("tap")
			swatch_chosen.emit(col))
		swatches.add_child(b)
	swatches.visible = true


func hide_swatches() -> void:
	swatches.visible = false


func show_win(sub: String) -> void:
	win_sub.text = sub
	win_panel.visible = true
	win_panel.modulate.a = 0.0
	win_panel.scale = Vector2.ONE
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
