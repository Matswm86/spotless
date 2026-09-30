extends Node

## Dev-only: a bot plays levels by sweeping the tool across the object, taking
## screenshots along the way. Run under Xvfb with CAPTURE_DIR set.
## CAPTURE_LEVELS="0,3,6" limits which levels are played (default: all).

var out_dir: String = OS.get_environment("CAPTURE_DIR")
var main: Node


func _ready() -> void:
	var sel := OS.get_environment("CAPTURE_LEVELS")
	var levels: Array = []
	if sel == "":
		for i in Levels.count():
			levels.append(i)
	else:
		for s in sel.split(","):
			levels.append(int(s))
	Game.level = levels[0]
	Game.sound_on = false
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	var t0 := Time.get_ticks_msec()
	for li in levels:
		if li != levels[0]:
			main.load_level(li)
		while main.state != "play":
			await get_tree().process_frame
		await _frames(10)
		await _shot("L%02d_a_start" % li)
		for si in main.level["stages"].size():
			var mid_taken := false
			var start := Time.get_ticks_msec()
			while main.state == "play" and main.stage_i == si:
				if main.stage.get("key", "") == "trash":
					for t in main.trash.duplicate():
						main._tap_trash(main.cam.unproject_position(t.global_position))
						await _frames(8)
					await _frames(30)
					continue
				await _sweep()
				if not mid_taken and main.progress > 0.35:
					mid_taken = true
					await _shot("L%02d_b_%d_%s" % [li, si, main.stage["key"]])
				if Time.get_ticks_msec() - start > 60000:
					print("TIMEOUT level %d stage %d progress %.2f" % [li, si, main.progress])
					main._finish_stage()
					break
			while main.state == "finishing":
				await get_tree().process_frame
			print("level %d stage %d done after %.1fs" % [li, si, (Time.get_ticks_msec() - start) / 1000.0])
		await _frames(90)
		await _shot("L%02d_c_done" % li)
	print("ALL DONE in %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	get_tree().quit()


## One zigzag pass over the object's on-screen box.
func _sweep() -> void:
	var r := Rect2()
	var first := true
	for i in 8:
		var sp: Vector2 = main.cam.unproject_position(main.obj_aabb.get_endpoint(i))
		if first:
			r = Rect2(sp, Vector2.ZERO)
			first = false
		else:
			r = r.expand(sp)
	var rows := 11
	var off := Vector2(0, main.FINGER_OFFSET)
	for row in rows:
		var y := r.position.y + r.size.y * (row + 0.5) / rows
		var steps := 10
		for k in steps + 1:
			var f := float(k) / steps
			if row % 2 == 1:
				f = 1.0 - f
			var p := Vector2(r.position.x + r.size.x * f, y) + off
			main.auto_touch(p, true)
			await get_tree().process_frame
			if main.state != "play":
				main.auto_touch(p, false)
				return
	main.auto_touch(Vector2.ZERO, false)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(540, 960, Image.INTERPOLATE_LANCZOS)
	img.save_jpg(out_dir + "/" + name + ".jpg", 0.85)
