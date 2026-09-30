class_name ToolRig
extends Node3D

## A cleaning tool that follows the finger. The rig's origin sits on the contact point and
## its axes match the camera (-Z points into the object), so every model part is placed
## in screen-like coordinates. Particles show water, foam, dust, sparks, paint or sparkles.

var kind := ""
var active := false
var paint_color := Color.WHITE
var _spin: Node3D
var _wobble: Node3D
var _jet: MeshInstance3D
var _fx: Array[CPUParticles3D] = []
var _burst: CPUParticles3D
var _t := 0.0
var _move := 0.0
var _last_pos := Vector3.ZERO

static var _soft: Texture2D


static func soft_tex() -> Texture2D:
	if _soft:
		return _soft
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.8))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	_soft = t
	return t


static func mat(c: Color, rough := 0.5, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func setup(k: String) -> ToolRig:
	kind = k
	_wobble = Node3D.new()
	add_child(_wobble)
	match k:
		"washer":
			_gun(Color(0.98, 0.78, 0.15), Color(0.2, 0.2, 0.22))
			_jet_to(Vector3(0.28, -0.3, 0.75), Color(0.8, 0.92, 1.0, 0.55))
			_stream(Vector3(0.28, -0.3, 0.75), Color(0.85, 0.95, 1.0, 0.7), 0.035, 90)
			_splash(Color(0.85, 0.93, 1.0, 0.75), 0.05, 40)
		"foamer":
			_gun(Color(0.25, 0.7, 0.4), Color(0.95, 0.95, 0.95))
			_stream(Vector3(0.28, -0.3, 0.75), Color(1, 1, 1, 0.95), 0.08, 60)
			_splash(Color(1, 1, 1, 0.9), 0.07, 24)
		"painter":
			_gun(Color(0.3, 0.3, 0.33), Color(0.85, 0.85, 0.87))
			var cup := MeshInstance3D.new()
			cup.mesh = Objects.cyl(0.07, 0.06, 0.16, 24)
			cup.material_override = mat(Color(0.85, 0.85, 0.87), 0.3, 0.8)
			cup.position = Vector3(0.28, -0.12, 0.92)
			_wobble.add_child(cup)
			_stream(Vector3(0.28, -0.3, 0.75), Color(1, 1, 1, 0.55), 0.1, 70, true)
		"vacuum":
			_vacuum()
			_dust()
		"sponge":
			var s := MeshInstance3D.new()
			s.mesh = Shapes.rounded_box(Vector3(0.36, 0.22, 0.14), 0.05)
			s.material_override = mat(Color(1.0, 0.85, 0.25), 0.9)
			s.position = Vector3(0, 0, 0.1)
			_wobble.add_child(s)
			var pad := MeshInstance3D.new()
			pad.mesh = Shapes.rounded_box(Vector3(0.36, 0.22, 0.05), 0.02)
			pad.material_override = mat(Color(0.2, 0.65, 0.35), 0.95)
			pad.position = Vector3(0, 0, 0.02)
			_wobble.add_child(pad)
			_bubbles()
		"grinder":
			_grinder()
			_sparks()
		"polisher":
			_polisher()
			_glitter()
	for p in _fx:
		p.emitting = false
	return self


func _gun(body: Color, barrel: Color) -> void:
	var root := Node3D.new()
	root.position = Vector3(0.28, -0.3, 0.75)
	_wobble.add_child(root)
	# The barrel points from the nozzle toward the contact point.
	root.basis = Basis.looking_at(-root.position, Vector3.UP)
	var b := MeshInstance3D.new()
	b.mesh = Objects.cyl(0.025, 0.03, 0.5, 16)
	b.material_override = mat(barrel, 0.3, 0.7)
	b.rotation_degrees = Vector3(90, 0, 0)
	b.position = Vector3(0, 0, 0.22)
	root.add_child(b)
	var tip := MeshInstance3D.new()
	tip.mesh = Objects.cyl(0.04, 0.03, 0.06, 16)
	tip.material_override = mat(Color(0.15, 0.15, 0.16), 0.4, 0.5)
	tip.rotation_degrees = Vector3(90, 0, 0)
	tip.position = Vector3(0, 0, -0.02)
	root.add_child(tip)
	var bd := MeshInstance3D.new()
	bd.mesh = Shapes.rounded_box(Vector3(0.12, 0.16, 0.3), 0.05)
	bd.material_override = mat(body, 0.45)
	bd.position = Vector3(0, 0.02, 0.55)
	root.add_child(bd)
	var grip := MeshInstance3D.new()
	grip.mesh = Shapes.rounded_box(Vector3(0.09, 0.26, 0.1), 0.04)
	grip.material_override = mat(Color(0.15, 0.15, 0.16), 0.8)
	grip.position = Vector3(0, -0.16, 0.65)
	grip.rotation_degrees = Vector3(-15, 0, 0)
	root.add_child(grip)


func _vacuum() -> void:
	var root := Node3D.new()
	root.position = Vector3(0.0, 0.0, 0.05)
	_wobble.add_child(root)
	var nozzle := MeshInstance3D.new()
	nozzle.mesh = Shapes.rounded_box(Vector3(0.34, 0.08, 0.1), 0.03)
	nozzle.material_override = mat(Color(0.2, 0.2, 0.22), 0.6)
	root.add_child(nozzle)
	var tube := MeshInstance3D.new()
	tube.mesh = Objects.cyl(0.045, 0.045, 0.6, 16)
	tube.material_override = mat(Color(0.75, 0.76, 0.78), 0.3, 0.8)
	tube.position = Vector3(0.12, -0.25, 0.22)
	tube.rotation_degrees = Vector3(55, 0, 25)
	root.add_child(tube)
	var body := MeshInstance3D.new()
	body.mesh = Shapes.rounded_box(Vector3(0.2, 0.34, 0.2), 0.08)
	body.material_override = mat(Color(0.9, 0.3, 0.25), 0.4)
	body.position = Vector3(0.25, -0.55, 0.5)
	body.rotation_degrees = Vector3(35, 0, 20)
	root.add_child(body)


func _grinder() -> void:
	_spin = Node3D.new()
	_spin.position = Vector3(0, 0, 0.04)
	_wobble.add_child(_spin)
	var disc := MeshInstance3D.new()
	disc.mesh = Objects.cyl(0.2, 0.2, 0.02, 40)
	disc.material_override = mat(Color(0.55, 0.55, 0.58), 0.4, 0.8)
	disc.rotation_degrees = Vector3(90, 0, 0)
	_spin.add_child(disc)
	var mark := MeshInstance3D.new()
	mark.mesh = Shapes.rounded_box(Vector3(0.3, 0.03, 0.005), 0.005)
	mark.material_override = mat(Color(0.2, 0.2, 0.22), 0.6)
	mark.position = Vector3(0, 0, 0.012)
	_spin.add_child(mark)
	var guard := MeshInstance3D.new()
	guard.mesh = Objects.cyl(0.22, 0.22, 0.05, 40)
	guard.material_override = mat(Color(0.3, 0.3, 0.32), 0.5, 0.6)
	guard.rotation_degrees = Vector3(90, 0, 0)
	guard.position = Vector3(0.05, 0.05, 0.08)
	guard.scale = Vector3(1, 1, 0.9)
	_wobble.add_child(guard)
	var head := MeshInstance3D.new()
	head.mesh = Objects.cyl(0.07, 0.08, 0.2, 20)
	head.material_override = mat(Color(0.35, 0.35, 0.37), 0.4, 0.6)
	head.rotation_degrees = Vector3(90, 0, 0)
	head.position = Vector3(0, 0, 0.17)
	_wobble.add_child(head)
	var body := MeshInstance3D.new()
	body.mesh = Objects.cyl(0.08, 0.09, 0.6, 20)
	body.material_override = mat(Color(0.95, 0.55, 0.15), 0.45)
	body.rotation_degrees = Vector3(0, 0, -60)
	body.position = Vector3(0.3, -0.18, 0.26)
	_wobble.add_child(body)


func _polisher() -> void:
	_spin = Node3D.new()
	_spin.position = Vector3(0, 0, 0.05)
	_wobble.add_child(_spin)
	var pad := MeshInstance3D.new()
	pad.mesh = Objects.cyl(0.2, 0.19, 0.08, 40)
	pad.material_override = mat(Color(0.35, 0.6, 0.95), 0.95)
	pad.rotation_degrees = Vector3(90, 0, 0)
	_spin.add_child(pad)
	var dot := MeshInstance3D.new()
	dot.mesh = Objects.cyl(0.05, 0.05, 0.09, 12)
	dot.material_override = mat(Color(0.95, 0.95, 0.97), 0.8)
	dot.rotation_degrees = Vector3(90, 0, 0)
	dot.position = Vector3(0.1, 0, 0.005)
	_spin.add_child(dot)
	var plate := MeshInstance3D.new()
	plate.mesh = Objects.cyl(0.17, 0.2, 0.06, 40)
	plate.material_override = mat(Color(0.95, 0.95, 0.96), 0.4)
	plate.rotation_degrees = Vector3(90, 0, 0)
	plate.position = Vector3(0, 0, 0.12)
	_wobble.add_child(plate)
	var handle := MeshInstance3D.new()
	handle.mesh = Shapes.rounded_box(Vector3(0.14, 0.36, 0.14), 0.06)
	handle.material_override = mat(Color(0.95, 0.4, 0.3), 0.45)
	handle.position = Vector3(0.12, -0.18, 0.28)
	handle.rotation_degrees = Vector3(-30, 0, 25)
	_wobble.add_child(handle)


func _jet_to(from: Vector3, c: Color) -> void:
	_jet = MeshInstance3D.new()
	var len := from.length()
	var cm := Objects.cyl(0.012, 0.02, len, 12)
	_jet.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_jet.material_override = m
	var holder := Node3D.new()
	holder.position = from * 0.5
	_wobble.add_child(holder)
	holder.basis = Basis.looking_at(-holder.position, Vector3.UP)
	_jet.rotation_degrees = Vector3(90, 0, 0)
	holder.add_child(_jet)
	_jet.visible = false


func _particles(amount: int, size: float, c: Color, additive := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_tex()
	q.material = m
	p.mesh = q
	p.color = c
	p.local_coords = false
	_wobble.add_child(p)
	_fx.append(p)
	return p


func _stream(from: Vector3, c: Color, size: float, amount: int, tinted := false) -> void:
	var p := _particles(amount, size, c)
	p.position = from
	p.direction = -from.normalized()
	p.spread = 5.0 if not tinted else 11.0
	p.initial_velocity_min = 3.4
	p.initial_velocity_max = 3.8
	p.gravity = Vector3.ZERO
	p.lifetime = from.length() / 3.6
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 1.6 if tinted else 1.0))
	p.scale_amount_curve = curve
	if tinted:
		p.set_meta("tinted", true)


func _splash(c: Color, size: float, amount: int) -> void:
	var p := _particles(amount, size, c)
	p.position = Vector3(0, 0, 0.03)
	p.direction = Vector3(0, 0.3, 1)
	p.spread = 70.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0, -6, 0)
	p.lifetime = 0.45
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2


func _dust() -> void:
	var p := _particles(50, 0.05, Color(0.6, 0.58, 0.54, 0.8))
	p.position = Vector3(0, 0, 0.02)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.28
	p.direction = Vector3(0, 0, 1)
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.1
	p.radial_accel_min = -6.0
	p.radial_accel_max = -4.0
	p.gravity = Vector3.ZERO
	p.lifetime = 0.35
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.1


func _bubbles() -> void:
	var p := _particles(30, 0.06, Color(1, 1, 1, 0.8))
	p.position = Vector3(0, 0, 0.05)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.16
	p.direction = Vector3(0, 1, 0.4)
	p.spread = 40.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.35
	p.gravity = Vector3(0, 0.3, 0)
	p.lifetime = 0.9
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.3


func _sparks() -> void:
	var p := _particles(70, 0.035, Color(1.0, 0.7, 0.25, 1.0), true)
	p.position = Vector3(0, -0.15, 0.06)
	p.direction = Vector3(-0.6, -0.4, 0.7)
	p.spread = 30.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -9, 0)
	p.lifetime = 0.4
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.6, 1))
	g.set_color(1, Color(1.0, 0.35, 0.05, 0))
	p.color_ramp = g
	var dust := _particles(24, 0.07, Color(0.55, 0.3, 0.15, 0.6))
	dust.position = Vector3(0, 0, 0.05)
	dust.direction = Vector3(0, 0.5, 1)
	dust.spread = 60.0
	dust.initial_velocity_min = 0.3
	dust.initial_velocity_max = 0.8
	dust.gravity = Vector3(0, -1.5, 0)
	dust.lifetime = 0.6


func _glitter() -> void:
	var p := _particles(20, 0.07, Color(1, 1, 0.9, 1), true)
	p.position = Vector3(0, 0, 0.08)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3(0, 0, 1)
	p.spread = 90.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.2
	p.gravity = Vector3.ZERO
	p.lifetime = 0.5
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.3, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve


func set_paint(c: Color) -> void:
	paint_color = c
	for p in _fx:
		if p.has_meta("tinted"):
			p.color = Color(c.r, c.g, c.b, 0.6)


func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	for p in _fx:
		p.emitting = on
	if _jet:
		_jet.visible = on


func _process(delta: float) -> void:
	_t += delta
	var moved := (global_position - _last_pos).length()
	_last_pos = global_position
	_move = lerpf(_move, clampf(moved / maxf(delta, 0.001) * 0.4, 0.0, 1.0), 0.2)
	if _spin:
		_spin.rotation.z += delta * (38.0 if active else 4.0)
	match kind:
		"sponge":
			_wobble.rotation.z = sin(_t * 14.0) * 0.18 * _move
			_wobble.position.z = 0.0 if active else 0.08
		"grinder", "polisher":
			var j := 0.006 if active else 0.0
			_wobble.position = Vector3(randf_range(-j, j), randf_range(-j, j), 0.0 if active else 0.06)
		"vacuum":
			_wobble.position.z = 0.0 if active else 0.06
		_:
			_wobble.position = Vector3(0, sin(_t * 3.0) * 0.01, 0.0 if active else 0.05)
