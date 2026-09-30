class_name Rooms
extends RefCounted

## Diorama backdrops. Each room is a floor, a back wall (or sky) and a few props, built
## around the origin where the object stands. Returns the room node; env settings are
## read from Rooms.sky_for(theme).

const SHADER := preload("res://scripts/room.gdshader")
const NOISE := preload("res://assets/tex/noise.png")

const OUTDOOR := ["road", "garden"]


static func surface(size: Vector2, pattern: int, a: Color, b: Color, scale: Vector2, rough := 0.8, edge := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("pattern", pattern)
	m.set_shader_parameter("col_a", a)
	m.set_shader_parameter("col_b", b)
	m.set_shader_parameter("uv_scale", scale)
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("edge_shade", edge)
	m.set_shader_parameter("noise_tex", NOISE)
	mi.material_override = m
	return mi


static func floor_(root: Node3D, pattern: int, a: Color, b: Color, tile: float, size := 16.0) -> void:
	var f := surface(Vector2(size, size), pattern, a, b, Vector2(size / tile, size / tile), 0.6)
	root.add_child(f)


static func wall(root: Node3D, z: float, pattern: int, a: Color, b: Color, tile: Vector2, height := 7.0, width := 16.0) -> MeshInstance3D:
	var w := surface(Vector2(width, height), pattern, a, b, Vector2(width / tile.x, height / tile.y), 0.8, 0.35)
	w.rotation_degrees = Vector3(90, 0, 0)
	w.position = Vector3(0, height * 0.5, z)
	root.add_child(w)
	return w


static func model(root: Node3D, path: String, pos: Vector3, scl: float, rot_y := 0.0) -> Node3D:
	var n: Node3D = load("res://assets/models/%s.glb" % path).instantiate()
	n.position = pos
	n.scale = Vector3.ONE * scl
	n.rotation_degrees.y = rot_y
	root.add_child(n)
	return n


static func box(root: Node3D, size: Vector3, pos: Vector3, col: Color, rough := 0.6) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Shapes.rounded_box(size, minf(0.04, size.y * 0.3))
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	mi.material_override = m
	mi.position = pos
	root.add_child(mi)
	return mi


static func window(root: Node3D, pos: Vector3, size: Vector2, frame: Color) -> void:
	var glass := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	glass.mesh = q
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.72, 0.87, 0.98)
	gm.emission_enabled = true
	gm.emission = Color(0.75, 0.88, 1.0)
	gm.emission_energy_multiplier = 0.9
	glass.material_override = gm
	glass.position = pos
	root.add_child(glass)
	var t := 0.09
	box(root, Vector3(size.x + t * 2, t, 0.12), pos + Vector3(0, size.y * 0.5, 0), frame)
	box(root, Vector3(size.x + t * 2, t * 1.4, 0.2), pos + Vector3(0, -size.y * 0.5, 0.05), frame)
	box(root, Vector3(t, size.y, 0.12), pos + Vector3(-size.x * 0.5, 0, 0), frame)
	box(root, Vector3(t, size.y, 0.12), pos + Vector3(size.x * 0.5, 0, 0), frame)
	box(root, Vector3(t * 0.6, size.y, 0.08), pos, frame)


static func frame_picture(root: Node3D, pos: Vector3, size: Vector2, frame: Color, art: Color) -> void:
	box(root, Vector3(size.x + 0.12, size.y + 0.12, 0.05), pos, frame)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("pattern", 5)
	m.set_shader_parameter("col_a", art)
	m.set_shader_parameter("col_b", art.lightened(0.35))
	m.set_shader_parameter("uv_scale", Vector2(2, 2))
	m.set_shader_parameter("noise_tex", NOISE)
	mi.material_override = m
	mi.position = pos + Vector3(0, 0, 0.03)
	root.add_child(mi)


## Build the backdrop. `span` is the object's width, so props sit just outside it.
static func build(theme: String, span: float) -> Node3D:
	var r := Node3D.new()
	var back := -maxf(1.6, span * 0.75)
	var side := maxf(1.5, span * 0.62 + 0.5)
	match theme:
		"bathroom":
			floor_(r, 1, Color(0.93, 0.92, 0.88), Color(0.7, 0.7, 0.68), 0.6)
			wall(r, back, 1, Color(0.78, 0.9, 0.93), Color(0.94, 0.96, 0.96), Vector2(0.45, 0.45))
			box(r, Vector3(16, 0.08, 0.06), Vector3(0, 1.3, back + 0.03), Color(0.35, 0.62, 0.7))
			model(r, "furniture/bathroomMirror", Vector3(-side - 0.2, 1.55, back + 0.01), 1.6)
			model(r, "furniture/plantSmall1", Vector3(side + 0.1, 0, back + 0.5), 2.2)
			model(r, "furniture/bathroomCabinet", Vector3(side + 1.1, 0, back + 0.25), 1.6, 0)
		"living":
			floor_(r, 3, Color(0.78, 0.55, 0.34), Color(0.62, 0.4, 0.22), 0.28)
			wall(r, back, 2, Color(0.96, 0.87, 0.72), Color(0.9, 0.73, 0.55), Vector2(0.6, 7.0))
			box(r, Vector3(16, 0.16, 0.05), Vector3(0, 0.08, back + 0.03), Color(0.98, 0.96, 0.92))
			window(r, Vector3(side + 0.4, 2.3, back + 0.02), Vector2(1.3, 1.5), Color(0.98, 0.97, 0.94))
			frame_picture(r, Vector3(-side - 0.1, 2.4, back + 0.03), Vector2(0.9, 0.7), Color(0.4, 0.26, 0.16), Color(0.45, 0.62, 0.72))
			model(r, "furniture/pottedPlant", Vector3(-side - 0.1, 0, back + 0.6), 2.0)
			model(r, "furniture/lampSquareFloor", Vector3(side + 0.2, 0, back + 0.5), 1.8)
			model(r, "furniture/rugRounded", Vector3(-1.0, 0.005, -0.2), 3.0)
		"shelf":
			floor_(r, 3, Color(0.7, 0.48, 0.3), Color(0.55, 0.36, 0.2), 0.28)
			wall(r, back, 2, Color(0.86, 0.9, 0.84), Color(0.74, 0.82, 0.72), Vector2(0.5, 7.0))
			frame_picture(r, Vector3(-side, 2.6, back + 0.03), Vector2(0.8, 1.0), Color(0.85, 0.7, 0.35), Color(0.8, 0.55, 0.4))
			window(r, Vector3(side + 0.3, 2.4, back + 0.02), Vector2(1.1, 1.4), Color(0.98, 0.97, 0.94))
			model(r, "furniture/plantSmall1", Vector3(side, 0, back + 0.6), 2.0)
		"kitchen":
			floor_(r, 1, Color(0.9, 0.87, 0.8), Color(0.62, 0.58, 0.52), 0.5)
			wall(r, back, 1, Color(0.98, 0.97, 0.93), Color(0.8, 0.78, 0.74), Vector2(0.3, 0.15))
			for sx in [-1.0, 1.0]:
				for k in 3:
					model(r, "furniture/kitchenCabinet", Vector3(sx * (side + 0.35 + k * 1.2), 0, back + 0.02), 1.5, 0)
			window(r, Vector3(0, 3.0, back + 0.02), Vector2(1.4, 0.9), Color(0.98, 0.97, 0.94))
			model(r, "furniture/toaster", Vector3(side + 0.8, 1.35, back + 0.4), 1.4)
			model(r, "furniture/kitchenCoffeeMachine", Vector3(-side - 1.3, 1.35, back + 0.45), 1.4)
		"garage":
			floor_(r, 4, Color(0.62, 0.62, 0.6), Color(0.48, 0.48, 0.47), 0.5)
			wall(r, back, 7, Color(0.72, 0.4, 0.3), Color(0.6, 0.32, 0.24), Vector2(0.5, 0.2))
			box(r, Vector3(3.0, 1.6, 0.05), Vector3(-side - 0.8, 2.2, back + 0.03), Color(0.85, 0.75, 0.55))
			for k in 5:
				box(r, Vector3(0.12, 0.5 + (k % 2) * 0.2, 0.05), Vector3(-side - 1.9 + k * 0.45, 2.3, back + 0.08), Color(0.3, 0.32, 0.36))
			box(r, Vector3(2.4, 0.08, 0.5), Vector3(side + 1.6, 1.4, back + 0.25), Color(0.4, 0.42, 0.45))
			model(r, "furniture/trashcan", Vector3(side + 0.5, 0, back + 0.6), 1.8)
		"road":
			floor_(r, 5, Color(0.45, 0.66, 0.3), Color(0.36, 0.56, 0.24), 1.0, 40.0)
			var road := surface(Vector2(40, 3.2), 6, Color(0.36, 0.36, 0.38), Color(0.28, 0.28, 0.3), Vector2(20, 2))
			road.position = Vector3(0, 0.01, -3.2)
			r.add_child(road)
			var walk := surface(Vector2(40, 1.2), 4, Color(0.78, 0.76, 0.72), Color(0.66, 0.64, 0.6), Vector2(40, 1.2))
			walk.position = Vector3(0, 0.02, -0.9)
			r.add_child(walk)
			for i in 12:
				box(r, Vector3(0.9, 0.02, 0.12), Vector3(-10 + i * 2.0, 0.02, -3.2), Color(0.96, 0.96, 0.9))
			_hills(r)
		"garden":
			floor_(r, 5, Color(0.45, 0.68, 0.3), Color(0.35, 0.56, 0.22), 1.0, 40.0)
			var path := surface(Vector2(1.6, 20), 4, Color(0.8, 0.72, 0.6), Color(0.68, 0.6, 0.48), Vector2(2, 25))
			path.position = Vector3(side + 0.6, 0.01, -6)
			r.add_child(path)
			for i in 14:
				var x := -9.0 + i * 1.35
				box(r, Vector3(0.14, 1.0, 0.08), Vector3(x, 0.5, back - 0.4), Color(0.97, 0.96, 0.92))
			box(r, Vector3(20, 0.1, 0.06), Vector3(0, 0.8, back - 0.37), Color(0.97, 0.96, 0.92))
			box(r, Vector3(20, 0.1, 0.06), Vector3(0, 0.35, back - 0.37), Color(0.97, 0.96, 0.92))
			_hills(r)
	return r


static func _hills(r: Node3D) -> void:
	var cols := [Color(0.42, 0.62, 0.36), Color(0.36, 0.56, 0.32), Color(0.5, 0.68, 0.4)]
	for i in 7:
		var mi := MeshInstance3D.new()
		mi.mesh = Objects.sphere(1.0, 24)
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[i % 3]
		m.roughness = 1.0
		mi.material_override = m
		mi.position = Vector3(-14 + i * 4.8, -1.2, -18 - (i % 2) * 3)
		mi.scale = Vector3(5.5, 3.2 + (i % 3) * 0.8, 3.0)
		r.add_child(mi)
	for i in 9:
		var t := MeshInstance3D.new()
		t.mesh = Objects.sphere(0.7, 16)
		var m2 := StandardMaterial3D.new()
		m2.albedo_color = Color(0.25, 0.48, 0.25).lerp(Color(0.4, 0.58, 0.3), (i % 3) / 2.0)
		t.material_override = m2
		t.position = Vector3(-12 + i * 3.1, 0.9, -11 - (i % 3) * 1.5)
		t.scale = Vector3(1, 1.3, 1)
		r.add_child(t)
		var trunk := MeshInstance3D.new()
		trunk.mesh = Objects.cyl(0.1, 0.12, 0.8, 8)
		var m3 := StandardMaterial3D.new()
		m3.albedo_color = Color(0.4, 0.28, 0.18)
		trunk.material_override = m3
		trunk.position = t.position - Vector3(0, 0.75, 0)
		r.add_child(trunk)


static func is_outdoor(theme: String) -> bool:
	return theme in OUTDOOR
