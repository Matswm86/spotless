class_name Objects
extends RefCounted

## Builds the objects that get cleaned. Every visible piece becomes a "part": a
## MeshInstance3D with one surface, tagged with meta "role" (fabric, wood, metal...),
## "color" and optionally "tex". Kenney models are split per surface so each material
## can get its own kind of dirt.

const MAT_ROLES := {
	"carpetWhite": "ceramic", "carpet": "fabric", "carpetDarker": "fabric",
	"wood": "wood", "woodDark": "wood", "metal": "appliance", "metalLight": "appliance",
	"metalMedium": "appliance", "metalDark": "metaldark", "_defaultMat": "ceramic",
	"colormap": "carpaint", "glass": "glass", "plant": "plant", "lamp": "plastic",
}


static func build(kind: String) -> Node3D:
	match kind:
		"trophy":
			return _trophy()
		"fan":
			return _fan()
		"sign":
			return _sign()
		"mailbox":
			return _mailbox()
		"kettle":
			return _kettle()
		"bike":
			return _scooter()
	var path := "res://assets/models/%s.glb" % kind
	return _from_glb(path)


static func _from_glb(path: String) -> Node3D:
	var root := Node3D.new()
	var src: Node3D = load(path).instantiate()
	var meshes: Array = []
	_collect(src, meshes)
	for mi: MeshInstance3D in meshes:
		var xf := _rel_xform(mi, src)
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(s))
			var m := mi.get_active_material(s)
			var part := MeshInstance3D.new()
			part.mesh = am
			part.transform = xf
			var mname := String(m.resource_name) if m else "_default"
			var role: String = MAT_ROLES.get(mname, "plastic")
			var col := Color.WHITE
			var tex: Texture2D = null
			if m is BaseMaterial3D:
				col = (m as BaseMaterial3D).albedo_color
				tex = (m as BaseMaterial3D).albedo_texture
			part.set_meta("role", role)
			part.set_meta("mat", mname)
			part.set_meta("color", col)
			if tex:
				part.set_meta("tex", tex)
			root.add_child(part)
	src.free()
	return root


static func _collect(n: Node, out: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


static func _rel_xform(n: Node3D, top: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur and cur != top:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


static func part(parent: Node3D, mesh: Mesh, role: String, col: Color, pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.set_meta("role", role)
	mi.set_meta("color", col)
	parent.add_child(mi)
	return mi


static func cyl(top: float, bottom: float, h: float, seg: int = 40) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 2
	return c


static func sphere(r: float, seg: int = 40) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s


static func torus(inner: float, outer: float, seg: int = 48) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = seg
	t.ring_segments = 14
	return t


static func _trophy() -> Node3D:
	var r := Node3D.new()
	var gold := Color(1.0, 0.78, 0.3)
	part(r, Shapes.rounded_box(Vector3(1.0, 0.28, 0.7), 0.05), "wood", Color(0.45, 0.25, 0.14), Vector3(0, 0.14, 0))
	part(r, Shapes.rounded_box(Vector3(0.74, 0.32, 0.52), 0.04), "stone", Color(0.12, 0.13, 0.15), Vector3(0, 0.44, 0))
	part(r, Shapes.rounded_box(Vector3(0.42, 0.12, 0.02), 0.01), "metal", gold, Vector3(0, 0.44, 0.265))
	part(r, cyl(0.1, 0.22, 0.14), "metal", gold, Vector3(0, 0.67, 0))
	part(r, cyl(0.055, 0.07, 0.36), "metal", gold, Vector3(0, 0.9, 0))
	part(r, sphere(0.1), "metal", gold, Vector3(0, 1.08, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	part(r, cyl(0.5, 0.14, 0.7, 48), "metal", gold, Vector3(0, 1.47, 0))
	part(r, torus(0.46, 0.53), "metal", gold, Vector3(0, 1.82, 0))
	for sx in [-1.0, 1.0]:
		part(r, torus(0.17, 0.225), "metal", gold, Vector3(0.47 * sx, 1.46, 0), Vector3(90, 0, 0))
	return r


static func _fan() -> Node3D:
	var r := Node3D.new()
	var teal := Color(0.2, 0.62, 0.6)
	var orange := Color(1.0, 0.45, 0.2)
	var chrome := Color(0.85, 0.86, 0.88)
	part(r, cyl(0.36, 0.44, 0.12), "plastic", teal, Vector3(0, 0.06, 0.05))
	part(r, cyl(0.06, 0.08, 0.72), "plastic", teal, Vector3(0, 0.48, 0))
	part(r, sphere(0.2), "plastic", teal, Vector3(0, 0.95, -0.12), Vector3.ZERO, Vector3(1, 1, 1.5))
	part(r, sphere(0.09), "plastic", teal, Vector3(0, 0.95, 0.2), Vector3.ZERO, Vector3(1, 1, 0.6))
	for i in 4:
		var a := i * 90.0 + 20.0
		var b := part(r, sphere(0.2), "plastic", orange, Vector3(0, 0.95, 0.16), Vector3(0, 0, a), Vector3(1.35, 0.55, 0.12))
		b.position += Vector3(cos(deg_to_rad(a)), sin(deg_to_rad(a)), 0) * 0.25
	var ring := torus(0.6, 0.64, 64)
	part(r, ring, "chrome", chrome, Vector3(0, 0.95, 0.1), Vector3(90, 0, 0))
	for i in 16:
		var a := i * TAU / 16.0
		var s := part(r, cyl(0.009, 0.009, 0.58, 6), "chrome", chrome, Vector3(0, 0.95, 0.28), Vector3(0, 0, rad_to_deg(a)))
		s.position += Vector3(-sin(a), cos(a), 0) * 0.3
	part(r, cyl(0.12, 0.12, 0.03), "chrome", chrome, Vector3(0, 0.95, 0.3), Vector3(90, 0, 0))
	return r


static func _sign() -> Node3D:
	var r := Node3D.new()
	var red := Color(0.86, 0.12, 0.1)
	var steel := Color(0.72, 0.74, 0.76)
	part(r, cyl(0.055, 0.055, 2.6, 24), "metal", steel, Vector3(0, 1.3, -0.08))
	part(r, cyl(0.12, 0.14, 0.08, 24), "metal", steel, Vector3(0, 0.04, -0.08))
	var tri := PackedVector2Array([Vector2(0, 0.8), Vector2(-0.8, -0.58), Vector2(0.8, -0.58)])
	var outer := Shapes.rounded_polygon(tri, 0.1)
	outer.reverse()
	part(r, Shapes.prism(outer, 0.05), "signpaint", red, Vector3(0, 2.5, 0))
	var inner := PackedVector2Array()
	for p in outer:
		inner.append(p * 0.72 + Vector2(0, -0.05))
	part(r, Shapes.prism(inner, 0.02), "sign", Color(0.97, 0.97, 0.95), Vector3(0, 2.5, 0.03))
	var black := Color(0.08, 0.08, 0.1)
	part(r, sphere(0.055, 16), "sign", black, Vector3(0.02, 2.6, 0.045), Vector3.ZERO, Vector3(1, 1, 0.2))
	part(r, Shapes.rounded_box(Vector3(0.08, 0.2, 0.01), 0.03), "sign", black, Vector3(0, 2.44, 0.045), Vector3(0, 0, -10))
	part(r, Shapes.rounded_box(Vector3(0.05, 0.2, 0.01), 0.02), "sign", black, Vector3(-0.06, 2.28, 0.045), Vector3(0, 0, -25))
	part(r, Shapes.rounded_box(Vector3(0.05, 0.2, 0.01), 0.02), "sign", black, Vector3(0.05, 2.28, 0.045), Vector3(0, 0, 20))
	part(r, Shapes.rounded_box(Vector3(0.04, 0.16, 0.01), 0.02), "sign", black, Vector3(0.08, 2.46, 0.045), Vector3(0, 0, 40))
	return r


static func _mailbox() -> Node3D:
	var r := Node3D.new()
	part(r, Shapes.rounded_box(Vector3(0.14, 1.2, 0.14), 0.02), "wood", Color(0.5, 0.33, 0.2), Vector3(0, 0.6, 0))
	part(r, Shapes.rounded_box(Vector3(0.5, 0.06, 0.95), 0.02), "wood", Color(0.5, 0.33, 0.2), Vector3(0, 1.2, 0))
	var prof := PackedVector2Array()
	for k in 17:
		var a := PI * float(k) / 16.0
		prof.append(Vector2(cos(a) * 0.22, 0.25 + sin(a) * 0.22))
	prof.append(Vector2(-0.22, 0.0))
	prof.append(Vector2(0.22, 0.0))
	prof.reverse()
	var body := Shapes.prism(prof, 0.9)
	part(r, body, "boxpaint", Color(0.18, 0.4, 0.75), Vector3(0, 1.23, 0))
	part(r, Shapes.prism(prof, 0.03), "boxpaint", Color(0.18, 0.4, 0.75), Vector3(0, 1.23, 0.46), Vector3.ZERO, Vector3(1.04, 1.03, 1))
	part(r, Shapes.rounded_box(Vector3(0.12, 0.05, 0.04), 0.015), "chrome", Color(0.85, 0.85, 0.86), Vector3(0, 1.64, 0.49))
	part(r, Shapes.rounded_box(Vector3(0.03, 0.4, 0.04), 0.01), "metal", Color(0.85, 0.15, 0.12), Vector3(0.25, 1.55, 0.1))
	part(r, Shapes.rounded_box(Vector3(0.03, 0.14, 0.2), 0.01), "metal", Color(0.85, 0.15, 0.12), Vector3(0.25, 1.7, 0.18))
	return r


static func _kettle() -> Node3D:
	var r := Node3D.new()
	var body := Color(0.9, 0.3, 0.25)
	part(r, cyl(0.52, 0.56, 0.1), "metal", Color(0.2, 0.2, 0.22), Vector3(0, 0.05, 0))
	part(r, sphere(0.55), "kettlepaint", body, Vector3(0, 0.55, 0), Vector3.ZERO, Vector3(1, 0.85, 1))
	part(r, cyl(0.2, 0.26, 0.14), "kettlepaint", body, Vector3(0, 1.0, 0))
	part(r, sphere(0.07, 20), "rubber", Color(0.12, 0.12, 0.13), Vector3(0, 1.1, 0))
	var sp := part(r, cyl(0.05, 0.1, 0.55), "kettlepaint", body, Vector3(0.6, 0.62, 0), Vector3(0, 0, -50))
	sp.position.y += 0.05
	part(r, torus(0.34, 0.4), "rubber", Color(0.12, 0.12, 0.13), Vector3(0, 1.05, 0), Vector3(90, 0, 0), Vector3(1, 0.6, 1))
	return r


static func _scooter() -> Node3D:
	var r := Node3D.new()
	var frame := Color(0.25, 0.7, 0.85)
	for x in [-0.75, 0.75]:
		part(r, torus(0.2, 0.3), "rubber", Color(0.1, 0.1, 0.11), Vector3(x, 0.3, 0), Vector3(90, 0, 0))
		part(r, cyl(0.2, 0.2, 0.06), "chrome", Color(0.8, 0.8, 0.82), Vector3(x, 0.3, 0), Vector3(90, 0, 0))
	part(r, Shapes.rounded_box(Vector3(1.3, 0.1, 0.34), 0.04), "framepaint", frame, Vector3(-0.05, 0.42, 0))
	part(r, cyl(0.045, 0.045, 1.2), "framepaint", frame, Vector3(0.7, 0.95, 0), Vector3(0, 0, 12))
	part(r, cyl(0.035, 0.035, 0.7), "rubber", Color(0.12, 0.12, 0.13), Vector3(0.83, 1.55, 0), Vector3(90, 0, 0))
	part(r, Shapes.rounded_box(Vector3(0.36, 0.06, 0.24), 0.03), "rubber", Color(0.12, 0.12, 0.13), Vector3(-0.35, 0.49, 0))
	return r
