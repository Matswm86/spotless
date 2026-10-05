extends Node

## Dev-only (tests/ is not exported): checks the MWM Play child-touch rules with real
## touch events and saves full-size PNGs. Run under Xvfb with CAPTURE_DIR set and a
## fresh user dir (XDG_DATA_HOME).
##   CAPTURE_LEVEL  level index to play (default 2, armchair: rubbish ... paint)
##   CAPTURE_SHELL  1 = pretend to run inside MWM Play (Engine meta mwm_play_shell)
##   CAPTURE_INSET  fake top camera cutout in window px (default none)
## Prints "RULE ... PASS/FAIL" lines and "CHECK ..." lines for the touch behaviour.

const HOME := Rect2(0, 0, 232, 232)
const WRIST := 256.0

var out_dir: String = OS.get_environment("CAPTURE_DIR")
var main: Node
var fails := 0
var paint_checked := false


func _ready() -> void:
	if OS.get_environment("CAPTURE_SHELL") == "1":
		Engine.set_meta(&"mwm_play_shell", true)
	var li := int(OS.get_environment("CAPTURE_LEVEL")) if OS.get_environment("CAPTURE_LEVEL") != "" else 2
	Game.level = li
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	var inset := OS.get_environment("CAPTURE_INSET")
	if inset != "":
		main.hud.fake_safe_top = float(inset)
		main.hud.apply_safe_area()
	while main.state != "play":
		await get_tree().process_frame
	await _frames(30)
	print("CHECK shell=%s sound_btn.visible=%s music_btn.visible=%s bus0_muted=%s" % [Game.in_shell(), main.hud.sound_btn.visible, main.hud.music_btn.visible, AudioServer.is_bus_mute(0)])
	await _shot("1_start")
	_check_targets("start")
	for si in main.level["stages"].size():
		while main.state == "play" and main.stage_i == si:
			if main.stage["key"] == "trash":
				await _play_trash()
				continue
			if main.stage["key"] == "paint" and not paint_checked:
				paint_checked = true
				await _check_paint()
			await _sweep()
		while main.state == "finishing":
			await get_tree().process_frame
		print("stage %d (%s) done" % [si, main.level["stages"][si]])
	await _frames(90)
	await _shot("4_win")
	_check_targets("win")
	# Next acts on release inside: press, slide off, release = stay; then a real tap.
	var nb: Control = main.hud.next_btn
	var c := nb.get_global_rect().get_center()
	await _press(c)
	await _drag_to(c + Vector2(0, -400))
	await _release(c + Vector2(0, -400))
	print("CHECK next slide-off stays on win: %s" % _ok(main.state == "complete"))
	await _tap(c)
	await _frames(20)
	print("CHECK next tap loads level %d: %s" % [main.level_index, _ok(main.level_index == li + 1)])
	print("RESULT fails=%d" % fails)
	get_tree().quit()


func _ok(b: bool) -> String:
	if not b:
		fails += 1
	return "PASS" if b else "FAIL"


## Every visible tappable control: hit area >= 200 px, outside the home square,
## above the wrist strip.
func _check_targets(tag: String) -> void:
	var vs := get_viewport().get_visible_rect().size
	for n in main.hud.root.find_children("*", "Control", true, false):
		var c := n as Control
		if c.mouse_filter != Control.MOUSE_FILTER_STOP or not c.is_visible_in_tree():
			continue
		var r := c.get_global_rect()
		var big := r.size.x >= 200 and r.size.y >= 200
		var home_free := not r.intersects(HOME)
		var wrist_free := r.end.y <= vs.y - WRIST + 0.5
		var ok := big and home_free and wrist_free
		print("RULE %s %s %s rect=%s size>=200:%s home_free:%s wrist_free:%s %s" % [tag, c.get_class(), c.get("kind") if c.get("kind") != null else "swatch", r, big, home_free, wrist_free, _ok(ok)])


func _play_trash() -> void:
	await _shot("2_rubbish")
	var t: Node3D = main.trash[0]
	var p: Vector2 = main.cam.unproject_position(t.global_position)
	var n0: int = main.trash.size()
	await _press(p)
	await _frames(15)
	print("CHECK rubbish not taken on touch-down: %s" % _ok(main.trash.size() == n0))
	await _release(p)
	await _frames(5)
	print("CHECK rubbish taken on release: %s" % _ok(main.trash.size() == n0 - 1))
	for tt in main.trash.duplicate():
		var q: Vector2 = main.cam.unproject_position(tt.global_position)
		await _tap(q)
		await _frames(8)
	await _frames(30)


func _check_paint() -> void:
	var sw: Array = main.hud.swatches
	if sw.size() < 2:
		print("CHECK paint swatches shown: %s" % _ok(false))
		return
	await _shot("3_paint")
	_check_targets("paint")
	var before: Color = main.paint_color
	var c: Vector2 = (sw[1] as Control).get_global_rect().get_center()
	await _press(c)
	await _frames(10)
	print("CHECK swatch not picked on touch-down: %s" % _ok(main.paint_color == before))
	await _release(c)
	await _frames(5)
	print("CHECK swatch picked on release: %s" % _ok(main.paint_color == (sw[1] as Swatch).color))


## One zigzag pass over the object's on-screen box (brush via the test hook).
func _sweep() -> void:
	var r := Rect2()
	for i in 8:
		var sp: Vector2 = main.cam.unproject_position(main.obj_aabb.get_endpoint(i))
		r = Rect2(sp, Vector2.ZERO) if i == 0 else r.expand(sp)
	var off := Vector2(0, main.FINGER_OFFSET)
	for row in 11:
		var y := r.position.y + r.size.y * (row + 0.5) / 11.0
		for k in 11:
			var f := float(k) / 10.0
			if row % 2 == 1:
				f = 1.0 - f
			var p := Vector2(r.position.x + r.size.x * f, y) + off
			main.auto_touch(p, true)
			await get_tree().process_frame
			if main.state != "play":
				main.auto_touch(p, false)
				return
	main.auto_touch(Vector2.ZERO, false)


func _to_window(p: Vector2) -> Vector2:
	return get_window().get_final_transform() * p


func _press(p: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.pressed = true
	e.position = _to_window(p)
	Input.parse_input_event(e)
	await _frames(2)


func _drag_to(p: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.position = _to_window(p)
	Input.parse_input_event(e)
	await _frames(2)


func _release(p: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.pressed = false
	e.position = _to_window(p)
	Input.parse_input_event(e)
	await _frames(2)


func _tap(p: Vector2) -> void:
	await _press(p)
	await _release(p)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir + "/" + name + ".png")
