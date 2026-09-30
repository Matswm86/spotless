class_name Trash
extends RefCounted

## Small rubbish props for the "Tidy up" stage.

const KINDS := ["paper", "can", "peel", "bottle", "core", "bag"]


static func _m(c: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func make(kind: String) -> Node3D:
	var r := Node3D.new()
	match kind:
		"paper":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 0.9
			s.radial_segments = 7
			s.rings = 4
			var mi := MeshInstance3D.new()
			mi.mesh = s
			mi.material_override = _m(Color(0.93, 0.92, 0.86), 0.95)
			mi.rotation = Vector3(randf() * 3, randf() * 3, 0)
			mi.position.y = 0.4
			r.add_child(mi)
		"can":
			var mi := MeshInstance3D.new()
			mi.mesh = Objects.cyl(0.3, 0.3, 0.9, 20)
			mi.material_override = _m([Color(0.85, 0.15, 0.15), Color(0.2, 0.45, 0.85), Color(0.2, 0.7, 0.35)].pick_random(), 0.3, 0.6)
			mi.rotation_degrees = Vector3(90, randf() * 180, 0)
			mi.position.y = 0.3
			r.add_child(mi)
			var top := MeshInstance3D.new()
			top.mesh = Objects.cyl(0.26, 0.3, 0.06, 20)
			top.material_override = _m(Color(0.85, 0.85, 0.87), 0.2, 1.0)
			top.position = Vector3(0, 0.48, 0)
			mi.add_child(top)
		"peel":
			for k in 3:
				var mi := MeshInstance3D.new()
				var c := CapsuleMesh.new()
				c.radius = 0.14
				c.height = 0.9
				mi.mesh = c
				mi.material_override = _m(Color(0.98, 0.82, 0.2), 0.6)
				mi.rotation_degrees = Vector3(70, k * 120.0, 0)
				mi.position = Vector3(cos(k * TAU / 3.0) * 0.25, 0.15, sin(k * TAU / 3.0) * 0.25)
				r.add_child(mi)
		"bottle":
			var mi := MeshInstance3D.new()
			mi.mesh = Objects.cyl(0.25, 0.25, 0.9, 20)
			var m := _m(Color(0.3, 0.7, 0.45, 0.75), 0.1)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mi.material_override = m
			mi.rotation_degrees = Vector3(90, randf() * 180, 0)
			mi.position.y = 0.25
			r.add_child(mi)
			var neck := MeshInstance3D.new()
			neck.mesh = Objects.cyl(0.1, 0.22, 0.35, 16)
			neck.material_override = m
			neck.position = Vector3(0, 0.6, 0)
			mi.add_child(neck)
		"core":
			for y in [0.0, 0.45]:
				var mi := MeshInstance3D.new()
				mi.mesh = Objects.sphere(0.28, 16)
				mi.material_override = _m(Color(0.95, 0.9, 0.7), 0.8)
				mi.position.y = 0.28 + y
				r.add_child(mi)
			var mid := MeshInstance3D.new()
			mid.mesh = Objects.cyl(0.14, 0.14, 0.4, 12)
			mid.material_override = _m(Color(0.93, 0.88, 0.66), 0.8)
			mid.position.y = 0.5
			r.add_child(mid)
		_:
			var mi := MeshInstance3D.new()
			mi.mesh = Shapes.rounded_box(Vector3(0.8, 0.3, 0.55), 0.12)
			mi.material_override = _m([Color(0.95, 0.6, 0.15), Color(0.3, 0.6, 0.9)].pick_random(), 0.35, 0.3)
			mi.rotation_degrees.y = randf() * 180
			mi.position.y = 0.15
			r.add_child(mi)
	return r
