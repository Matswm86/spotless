extends Node3D

## Runs one makeover level at a time: builds the room and the object, frames the camera,
## turns finger drags into brush stamps on the object's CleanMask, tracks progress per
## stage and plays the finish.

const DIRT_SHADER := preload("res://scripts/dirt.gdshader")
const NOISE := preload("res://assets/tex/noise.png")
const FINGER_OFFSET := 150.0
const THRESH := 0.85
const WIN_LINES := ["Good as new", "Sparkling clean", "Like brand new", "Beautiful work", "So satisfying", "Fresh and shiny"]

var cam: Camera3D
var env: Environment
var sun: DirectionalLight3D
var fill_light: OmniLight3D
var hud: Hud

var level: Dictionary
var level_index := 0
var world_root: Node3D
var holder: Node3D
var pivot: Node3D
var parts: Array[MeshInstance3D] = []
var mats: Array[ShaderMaterial] = []
var part_dirt: Array[bool] = []
var part_grime: Array[bool] = []
var part_paint: Array[bool] = []
var mask: CleanMask
var mask_xf: Transform3D
var mask_origin := Vector3.ZERO
var mask_x := Vector3.RIGHT
var mask_y := Vector3.UP
var mask_z := Vector3.BACK
var mask_u0 := 0.0
var mask_vtop := 0.0
var mask_s := 1.0
var obj_aabb: AABB
var obj_center := Vector3.ZERO
var noise_img: Image
var noise_offset := Vector2.ZERO

var relevant: Dictionary = {}
var stage_i := 0
var stage: Dictionary = {}
var state := "idle"
var tool: ToolRig
var paint_color := Color.WHITE
var floors := Vector4(0, 0, 0, 0)
var foam_max := 1.0
var polish_floor := 0.0

var touching := false
var touch_pos := Vector2.ZERO
var last_uv := Vector2.ZERO
var has_last := false
var progress := 0.0
var _progress_timer := 0.0
## Seconds of brushing without progress; a stage that is nearly done finishes itself.
var _stall := 0.0
var _best := 0.0
var _hint_hidden := false

var trash: Array[Node3D] = []
var bin: Node3D
var _spin_speed := 0.0
var _auto_pos := Vector2(-1, -1)


func _ready() -> void:
	noise_img = NOISE.get_image()
	if noise_img.is_compressed():
		noise_img.decompress()
	cam = Camera3D.new()
	cam.fov = 34.0
	add_child(cam)
	cam.current = true
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)
	fill_light = OmniLight3D.new()
	fill_light.omni_range = 30.0
	fill_light.light_energy = 0.5
	add_child(fill_light)
	hud = Hud.new()
	add_child(hud)
	hud.next_pressed.connect(_on_next)
	hud.restart_pressed.connect(func(): load_level(level_index))
	hud.swatch_chosen.connect(_set_paint)
	hud.before_held.connect(_show_before)
	load_level(Game.level)


# ---------------------------------------------------------------- level build

func load_level(index: int) -> void:
	level_index = index
	level = Levels.get_level(index)
	state = "loading"
	Sfx.stop_loops()
	if world_root:
		world_root.queue_free()
	if tool:
		tool.queue_free()
		tool = null
	trash.clear()
	bin = null
	parts.clear()
	mats.clear()
	part_dirt.clear()
	part_grime.clear()
	part_paint.clear()
	floors = Vector4(0, 0, 0, 0)
	foam_max = 1.0
	polish_floor = 0.0
	_spin_speed = 0.0
	world_root = Node3D.new()
	add_child(world_root)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = index * 7919 + 13
	noise_offset = Vector2(rnd.randf(), rnd.randf())

	# Object: rotate, normalise its size, stand it on the floor (or on a small table).
	holder = Node3D.new()
	pivot = Node3D.new()
	holder.add_child(pivot)
	var obj := Objects.build(level["obj"])
	pivot.add_child(obj)
	pivot.rotation_degrees.y = float(level.get("rot", 0.0))
	var bb := _aabb_of(holder, Transform3D.IDENTITY)
	var target: float = level.get("size", 2.0)
	var s := target / maxf(bb.size.x, bb.size.y)
	var base_y := 0.0
	var span := bb.size.x * s
	if level.get("stand", false):
		base_y = 0.95
		_build_stand(world_root, maxf(span * 1.3, 1.6), maxf(bb.size.z * s * 1.4, 1.1), base_y)
	holder.scale = Vector3.ONE * s
	var c := bb.get_center()
	holder.position = Vector3(-c.x * s, base_y - bb.position.y * s, -c.z * s)
	world_root.add_child(holder)
	obj_aabb = _aabb_of(holder, holder.transform)
	obj_center = obj_aabb.get_center()

	var theme: String = level["room"]
	var room := Rooms.build(theme, span)
	world_root.add_child(room)
	_setup_env(theme)
	_frame_camera()
	_setup_mask()
	_setup_parts(obj)
	var names := []
	for st in level["stages"]:
		names.append(Levels.STAGES[st]["name"])
	hud.set_level(index, level["name"], names)
	# Colliders need a physics frame before rays can hit them.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_scan_cells()
	start_stage(0)


func _aabb_of(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	for ch in n.get_children():
		if not ch is Node3D:
			continue
		var cx: Transform3D = xf * (ch as Node3D).transform
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh:
			var a: AABB = cx * (ch as MeshInstance3D).mesh.get_aabb()
			out = a if first else out.merge(a)
			first = false
		var sub := _aabb_of(ch, cx)
		if sub.size != Vector3.ZERO:
			out = sub if first else out.merge(sub)
			first = false
	return out


func _build_stand(root: Node3D, w: float, d: float, h: float) -> void:
	var top := MeshInstance3D.new()
	top.mesh = Shapes.rounded_box(Vector3(w, 0.1, d), 0.04)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.42, 0.26)
	m.roughness = 0.45
	top.material_override = m
	top.position = Vector3(0, h - 0.05, 0)
	root.add_child(top)
	var body := MeshInstance3D.new()
	body.mesh = Shapes.rounded_box(Vector3(w * 0.92, h - 0.1, d * 0.9), 0.03)
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(0.97, 0.95, 0.9)
	m2.roughness = 0.6
	body.material_override = m2
	body.position = Vector3(0, (h - 0.1) * 0.5, 0)
	root.add_child(body)
	for sx in [-0.25, 0.25]:
		var knob := MeshInstance3D.new()
		knob.mesh = Objects.sphere(0.035, 12)
		knob.material_override = m
		knob.position = Vector3(w * sx, h * 0.6, d * 0.45 + 0.02)
		root.add_child(knob)


func _setup_env(theme: String) -> void:
	if Rooms.is_outdoor(theme):
		var sky := Sky.new()
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = Color(0.36, 0.6, 0.9)
		sm.sky_horizon_color = Color(0.78, 0.88, 0.96)
		sm.ground_horizon_color = Color(0.7, 0.8, 0.7)
		sm.ground_bottom_color = Color(0.3, 0.4, 0.3)
		sky.sky_material = sm
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.9
		sun.light_color = Color(1.0, 0.97, 0.9)
		sun.light_energy = 1.35
		sun.rotation_degrees = Vector3(-48, -30, 0)
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.9, 0.88, 0.85)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.86, 0.87, 0.9)
		env.ambient_light_energy = 0.75
		sun.light_color = Color(1.0, 0.95, 0.86)
		sun.light_energy = 1.15
		sun.rotation_degrees = Vector3(-52, 32, 0)


func _frame_camera() -> void:
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / vp.y
	var v := deg_to_rad(cam.fov) * 0.5
	var h := atan(tan(v) * aspect)
	var sz := obj_aabb.size
	var dist := maxf(sz.y / (2.0 * tan(v) * 0.56), sz.x / (2.0 * tan(h) * 0.86)) + sz.z * 0.5
	var pitch := deg_to_rad(13.0)
	var look := obj_center + Vector3(0, dist * tan(v) * 0.07, 0)
	cam.position = look + Vector3(0, sin(pitch), cos(pitch)) * dist
	cam.look_at(look, Vector3.UP)
	fill_light.position = cam.position + Vector3(2.0, 1.5, -1.0)


func _setup_mask() -> void:
	mask = CleanMask.new()
	var b := cam.global_transform.basis
	mask_x = b.x.normalized()
	mask_y = b.y.normalized()
	mask_z = b.z.normalized()
	mask_origin = obj_center
	var umin := INF
	var umax := -INF
	var vmin := INF
	var vmax := -INF
	for i in 8:
		var p := obj_aabb.get_endpoint(i) - mask_origin
		umin = minf(umin, p.dot(mask_x))
		umax = maxf(umax, p.dot(mask_x))
		vmin = minf(vmin, p.dot(mask_y))
		vmax = maxf(vmax, p.dot(mask_y))
	mask_s = maxf(umax - umin, vmax - vmin) * 1.06
	mask_u0 = (umin + umax) * 0.5 - mask_s * 0.5
	mask_vtop = (vmin + vmax) * 0.5 + mask_s * 0.5
	var s := mask_s
	var basis := Basis(mask_x / s, -mask_y / s, mask_z / s).transposed()
	var o := mask_origin
	mask_xf = Transform3D(basis, Vector3(-o.dot(mask_x) / s - mask_u0 / s, mask_vtop / s + o.dot(mask_y) / s, -o.dot(mask_z) / s))


func _world_to_uv(p: Vector3) -> Vector3:
	return mask_xf * p


func _uv_to_world(uv: Vector2) -> Vector3:
	return mask_origin + mask_x * (mask_u0 + uv.x * mask_s) + mask_y * (mask_vtop - uv.y * mask_s)


func _setup_parts(obj: Node3D) -> void:
	var stages: Array = level["stages"]
	var ops := {}
	for st in stages:
		ops[Levels.STAGES[st]["op"]] = true
	var has_dirt_stage := ops.has(CleanMask.Op.DIRT) or ops.has(CleanMask.Op.RINSE)
	var has_grime_stage := ops.has(CleanMask.Op.GRIME) or ops.has(CleanMask.Op.RINSE)
	var dirt: Array = Levels.DIRT[level.get("dirt", "mud")]
	var grime: Array = Levels.GRIME[level.get("grime", "moss")]
	var grime_roles: Array = level.get("grime_roles", [])
	var paint_roles: Array = level.get("paint_roles", [])
	var paints: Array = level.get("paints", [Color.WHITE])
	paint_color = paints[0]
	var list: Array = []
	_collect_meshes(obj, list)
	for mi: MeshInstance3D in list:
		var role: String = mi.get_meta("role", "plastic")
		var rp: Array = Levels.ROLES.get(role, [0.3, 0.7, 0.0])
		var m := ShaderMaterial.new()
		m.shader = DIRT_SHADER
		m.set_shader_parameter("mask_tex", mask.tex)
		m.set_shader_parameter("mask2_tex", mask.tex2)
		m.set_shader_parameter("noise_tex", NOISE)
		m.set_shader_parameter("mask_xform", mask_xf)
		m.set_shader_parameter("noise_offset", noise_offset)
		m.set_shader_parameter("base_color", mi.get_meta("color", Color.WHITE))
		if mi.has_meta("tex"):
			m.set_shader_parameter("albedo_tex", mi.get_meta("tex"))
			m.set_shader_parameter("use_albedo_tex", 1.0)
		m.set_shader_parameter("rough_clean", rp[0])
		m.set_shader_parameter("rough_dull", rp[1])
		m.set_shader_parameter("metallic_clean", rp[2])
		var is_dirt := has_dirt_stage and role != "glass"
		var is_grime := has_grime_stage and role in grime_roles
		var is_paint := role in paint_roles
		m.set_shader_parameter("has_mud", 1.0 if is_dirt else 0.0)
		m.set_shader_parameter("grime_amount", 1.0 if is_grime else 0.0)
		m.set_shader_parameter("paintable", 1.0 if is_paint else 0.0)
		m.set_shader_parameter("paint_color", paint_color)
		m.set_shader_parameter("mud_a", dirt[0])
		m.set_shader_parameter("mud_b", dirt[1])
		m.set_shader_parameter("grime_a", grime[0])
		m.set_shader_parameter("grime_b", grime[1])
		m.set_shader_parameter("grime_rough", grime[2])
		m.set_shader_parameter("fade", 0.35 if role in ["glass", "rubber"] else 0.75)
		mi.material_override = m
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = mi.mesh.create_trimesh_shape()
		body.add_child(cs)
		body.set_meta("part", parts.size())
		mi.add_child(body)
		parts.append(mi)
		mats.append(m)
		part_dirt.append(is_dirt)
		part_grime.append(is_grime)
		part_paint.append(is_paint)
	_push_floors()


func _collect_meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect_meshes(c, out)


## Cast one ray per mask cell (straight along the camera axis) to learn which part is
## visible there and whether dirt or grime is drawn on it, so progress matches the screen.
func _scan_cells() -> void:
	var space := get_world_3d().direct_space_state
	var all := PackedInt32Array()
	var dirt := PackedInt32Array()
	var grime := PackedInt32Array()
	var grime_any := PackedInt32Array()
	var paint := PackedInt32Array()
	var nw := noise_img.get_width()
	var nh := noise_img.get_height()
	var g := CleanMask.GRID
	for gy in g:
		for gx in g:
			var uv := Vector2((gx + 0.5) / g, (gy + 0.5) / g)
			var p := _uv_to_world(uv)
			var q := PhysicsRayQueryParameters3D.create(p + mask_z * 40.0, p - mask_z * 40.0)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				continue
			var col: Object = hit["collider"]
			if not col.has_meta("part"):
				continue
			var pi: int = col.get_meta("part")
			var cell := gy * g + gx
			mask.cell_part[cell] = pi
			all.append(cell)
			var mp := _world_to_uv(hit["position"])
			# Same noise lookup as the shader, to know if dirt/grime is visible here.
			var nuv := Vector2(mp.x, mp.y) * 2.2 + noise_offset + Vector2(mp.z * 0.31, mp.z * 0.17)
			var n := noise_img.get_pixel(posmod(int(nuv.x * nw), nw), posmod(int(nuv.y * nh), nh))
			if part_dirt[pi] and smoothstep(0.08, 0.3, n.g * 0.8 + n.b * 0.4) > 0.5:
				dirt.append(cell)
			if part_grime[pi]:
				grime_any.append(cell)
				if smoothstep(0.34, 0.58, n.r * 0.65 + n.g * 0.55) > 0.35:
					grime.append(cell)
			if part_paint[pi]:
				paint.append(cell)
	relevant.clear()
	relevant[CleanMask.Op.DIRT] = dirt if dirt.size() > 20 else all
	relevant[CleanMask.Op.GRIME] = grime if grime.size() > 20 else (grime_any if grime_any.size() > 20 else all)
	relevant[CleanMask.Op.FOAM] = grime_any if grime_any.size() > 20 else all
	relevant[CleanMask.Op.RINSE] = relevant[CleanMask.Op.FOAM]
	relevant[CleanMask.Op.PAINT] = paint if paint.size() > 20 else all
	relevant[CleanMask.Op.POLISH] = all


func _push_floors() -> void:
	for m in mats:
		m.set_shader_parameter("floors", floors)
		m.set_shader_parameter("foam_max", foam_max)
		m.set_shader_parameter("polish_floor", polish_floor)


# ---------------------------------------------------------------- stages

func start_stage(i: int) -> void:
	stage_i = i
	var key: String = level["stages"][i]
	stage = Levels.STAGES[key].duplicate()
	stage["key"] = key
	progress = 0.0
	_best = 0.0
	_stall = 0.0
	has_last = false
	_hint_hidden = false
	hud.set_stage(i)
	hud.set_progress(0.0, true)
	hud.show_hint(stage["hint"])
	hud.hide_swatches()
	if tool:
		tool.queue_free()
		tool = null
	if key == "trash":
		_spawn_trash()
	else:
		tool = ToolRig.new().setup(stage["tool"])
		world_root.add_child(tool)
		tool.global_basis = cam.global_basis
		tool.scale = Vector3.ONE * _tool_scale()
		_park_tool()
		if key == "paint":
			hud.show_swatches(level.get("paints", [Color.WHITE]), paint_color)
			tool.set_paint(paint_color)
	state = "play"


func _tool_scale() -> float:
	return (cam.global_position - obj_center).length() * 0.2


func _park_tool() -> void:
	var vp := get_viewport().get_visible_rect().size
	var pt := Vector2(vp.x * 0.78, vp.y * 0.72)
	tool.global_position = _screen_to_depth(pt)


func _screen_to_depth(pt: Vector2) -> Vector3:
	var o := cam.project_ray_origin(pt)
	var d := cam.project_ray_normal(pt)
	var plane := Plane(mask_z, obj_center + mask_z * obj_aabb.size.z * 0.5)
	var hit = plane.intersects_ray(o, d)
	return hit if hit != null else o + d * 5.0


func _set_paint(c: Color) -> void:
	paint_color = c
	for m in mats:
		m.set_shader_parameter("paint_color", c)
	if tool:
		tool.set_paint(c)


func _show_before(down: bool) -> void:
	for m in mats:
		m.set_shader_parameter("show_before", 1.0 if down else 0.0)


func _finish_stage() -> void:
	state = "finishing"
	touching = false
	if tool:
		tool.set_active(false)
	Sfx.stop_loops()
	Sfx.play("stage")
	hud.set_progress(1.0)
	hud.hide_hint()
	hud.hide_swatches()
	var op: int = stage["op"]
	var tw := create_tween()
	tw.tween_method(_fill_channel.bind(op), 0.0, 1.0, 0.6)
	await tw.finished
	if op >= 0:
		mask.fill(op)
	if op == CleanMask.Op.POLISH:
		Sfx.play("sparkle")
	await get_tree().create_timer(0.45).timeout
	if state != "finishing":
		return
	if stage_i + 1 < level["stages"].size():
		start_stage(stage_i + 1)
	else:
		_complete()


func _fill_channel(t: float, op: int) -> void:
	match op:
		CleanMask.Op.DIRT:
			floors.x = t
		CleanMask.Op.GRIME:
			floors.y = t
		CleanMask.Op.PAINT:
			floors.z = t
		CleanMask.Op.FOAM:
			floors.w = t
		CleanMask.Op.RINSE:
			floors.x = maxf(floors.x, t)
			floors.y = maxf(floors.y, t)
			foam_max = 1.0 - t
			floors.w = minf(floors.w, foam_max)
		CleanMask.Op.POLISH:
			polish_floor = t
	_push_floors()


func _complete() -> void:
	state = "complete"
	if tool:
		var tw := create_tween()
		tw.tween_property(tool, "scale", Vector3.ONE * 0.01, 0.3)
		tw.tween_callback(tool.queue_free)
		tool = null
	var tw2 := create_tween()
	tw2.tween_method(func(t: float):
		polish_floor = maxf(polish_floor, t)
		_push_floors(), 0.0, 1.0, 0.8)
	Sfx.play("win")
	_confetti()
	_spin_speed = 0.0
	var tw3 := create_tween()
	tw3.tween_property(self, "_spin_speed", 0.6, 1.2)
	Game.level = level_index + 1
	Game.save_game()
	hud.show_win(WIN_LINES[level_index % WIN_LINES.size()])


func _on_next() -> void:
	load_level(Game.level)


func _confetti() -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 90
	p.lifetime = 2.4
	p.explosiveness = 0.9
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.1) * _tool_scale() * 1.5
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.4
	q.material = m
	p.mesh = q
	p.direction = Vector3(0, 1, 0.3)
	p.spread = 50.0
	p.initial_velocity_min = 3.0 * _tool_scale()
	p.initial_velocity_max = 5.0 * _tool_scale()
	p.gravity = Vector3(0, -3.0 * _tool_scale(), 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	p.particle_flag_rotate_y = true
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray([Color(0.98, 0.45, 0.4), Color(1.0, 0.82, 0.3), Color(0.35, 0.8, 0.6), Color(0.35, 0.65, 0.95), Color(1.0, 0.6, 0.75)])
	p.color_initial_ramp = g
	world_root.add_child(p)
	p.global_position = obj_center - mask_y * obj_aabb.size.y * 0.3 + mask_z * obj_aabb.size.z
	p.emitting = true


# ---------------------------------------------------------------- trash

func _spawn_trash() -> void:
	var space := get_world_3d().direct_space_state
	var rnd := RandomNumberGenerator.new()
	rnd.seed = level_index * 31 + 7
	var want := 6
	var size := maxf(obj_aabb.size.x, obj_aabb.size.y)
	var tries := 0
	while trash.size() < want and tries < 80:
		tries += 1
		var x := rnd.randf_range(obj_aabb.position.x + 0.15 * obj_aabb.size.x, obj_aabb.end.x - 0.15 * obj_aabb.size.x)
		var z := rnd.randf_range(obj_aabb.position.z + 0.1 * obj_aabb.size.z, obj_aabb.end.z)
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, obj_aabb.end.y + 1.0, z), Vector3(x, obj_aabb.position.y - 1.0, z))
		var hit := space.intersect_ray(q)
		var pos: Vector3
		if hit.is_empty():
			if tries < 60:
				continue
			pos = Vector3(x, obj_aabb.position.y, obj_aabb.end.z + 0.2)
		else:
			pos = hit["position"]
		# Only keep spots the camera can see.
		var sp := cam.unproject_position(pos)
		var vp := get_viewport().get_visible_rect().size
		if sp.y < vp.y * 0.22 or sp.y > vp.y * 0.85 or sp.x < 60 or sp.x > vp.x - 60:
			continue
		var ok := true
		for t in trash:
			if t.global_position.distance_to(pos) < size * 0.12:
				ok = false
		if not ok:
			continue
		var item := Trash.make(Trash.KINDS[trash.size() % Trash.KINDS.size()])
		world_root.add_child(item)
		item.global_position = pos
		item.rotation.y = rnd.randf() * TAU
		item.scale = Vector3.ONE * size * 0.075
		trash.append(item)
	bin = Rooms.model(world_root, "furniture/trashcan", Vector3.ZERO, 1.0)
	var vp2 := get_viewport().get_visible_rect().size
	var o := cam.project_ray_origin(Vector2(vp2.x * 0.84, vp2.y * 0.8))
	var d := cam.project_ray_normal(Vector2(vp2.x * 0.84, vp2.y * 0.8))
	var fl := Plane(Vector3.UP, obj_aabb.position.y)
	var hp = fl.intersects_ray(o, d)
	bin.global_position = hp if hp != null else obj_center
	var bs := size * 0.55
	bin.scale = Vector3.ONE * 0.01
	create_tween().tween_property(bin, "scale", Vector3.ONE * bs, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if trash.is_empty():
		call_deferred("_finish_stage")


func _tap_trash(pt: Vector2) -> void:
	var best: Node3D = null
	var best_d := 150.0
	for t in trash:
		var sp := cam.unproject_position(t.global_position + Vector3.UP * t.scale.y * 0.3)
		var dd := sp.distance_to(pt)
		if dd < best_d:
			best_d = dd
			best = t
	if best == null:
		return
	trash.erase(best)
	Sfx.play("toss")
	var start := best.global_position
	var end := bin.global_position + Vector3.UP * bin.scale.y * 0.6
	var peak := maxf(start.y, end.y) + obj_aabb.size.y * 0.35
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var p := start.lerp(end, t)
		p.y = lerpf(lerpf(start.y, peak, t), lerpf(peak, end.y, t), t)
		best.global_position = p
		best.rotation.x = t * 6.0
		best.scale = Vector3.ONE * lerpf(1.0, 0.5, t) * maxf(obj_aabb.size.x, obj_aabb.size.y) * 0.075, 0.0, 1.0, 0.5)
	tw.tween_callback(best.queue_free)
	tw.tween_callback(func(): Sfx.play("pop", -6.0))
	var total := 6.0
	progress = 1.0 - trash.size() / total
	hud.set_progress(progress)
	if not _hint_hidden:
		_hint_hidden = true
		hud.hide_hint()
	if trash.is_empty():
		await tw.finished
		var tb := create_tween()
		tb.tween_property(bin, "scale", Vector3.ONE * 0.01, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tb.tween_callback(bin.queue_free)
		_finish_stage()


# ---------------------------------------------------------------- input + brushing

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		touching = event.pressed
		touch_pos = event.position
		has_last = false
		if event.pressed and state == "play" and stage.get("key", "") == "trash":
			_tap_trash(event.position)
	elif event is InputEventScreenDrag:
		if event.index == 0:
			touch_pos = event.position


## Test hook: drive the brush without real touches.
func auto_touch(pt: Vector2, down: bool) -> void:
	touching = down
	touch_pos = pt
	if not down:
		has_last = false


func _process(delta: float) -> void:
	if holder and _spin_speed > 0.0:
		# Turn the finished object on the spot, around its own centre.
		var c := Vector3(obj_center.x, 0.0, obj_center.z)
		var turn := Transform3D.IDENTITY.translated(-c).rotated(Vector3.UP, delta * _spin_speed).translated(c)
		holder.global_transform = turn * holder.global_transform
	if state != "play" or tool == null:
		if mask:
			mask.upload()
		return
	var key: String = stage.get("key", "")
	var op: int = stage.get("op", -1)
	if op < 0:
		return
	var working := false
	if touching:
		var pt := touch_pos - Vector2(0, FINGER_OFFSET)
		var o := cam.project_ray_origin(pt)
		var d := cam.project_ray_normal(pt)
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + d * 200.0))
		var target: Vector3
		if not hit.is_empty() and (hit["collider"] as Object).has_meta("part"):
			target = hit["position"]
			var uv3 := _world_to_uv(target)
			var uv := Vector2(uv3.x, uv3.y)
			working = true
			var r: float = stage["radius"]
			var power: float = stage["power"]
			if has_last:
				var dist := last_uv.distance_to(uv)
				var steps := int(dist / (r * 0.35))
				for k in steps:
					mask.stamp(last_uv.lerp(uv, float(k + 1) / (steps + 1)), r, power * 0.28, op)
			mask.stamp(uv, r, power * delta * 10.0, op)
			last_uv = uv
			has_last = true
			if not _hint_hidden:
				_hint_hidden = true
				hud.hide_hint()
		else:
			target = _screen_to_depth(pt)
			has_last = false
		tool.global_position = tool.global_position.lerp(target, clampf(delta * 30.0, 0.0, 1.0))
	tool.set_active(working)
	Sfx.loop(_loop_key(key), 0.9 if working else 0.0)
	mask.upload()
	_progress_timer += delta
	if _progress_timer > 0.12:
		_progress_timer = 0.0
		progress = mask.progress(relevant.get(op, PackedInt32Array()), op)
		hud.set_progress(progress / THRESH)
		if progress > _best + 0.004:
			_best = progress
			_stall = 0.0
		elif working:
			_stall += 0.12
		if progress >= THRESH or (progress >= 0.7 and _stall > 2.5):
			_finish_stage()


func _loop_key(key: String) -> String:
	match key:
		"spray", "rinse":
			return "spray"
		"foam":
			return "foam"
		"scrub":
			return "scrub"
		"grind":
			return "grind"
		"paint":
			return "paint"
		"polish":
			return "polish"
		"vacuum":
			return "vacuum"
	return ""
