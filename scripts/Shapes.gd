class_name Shapes
extends RefCounted

## Procedural meshes: rounded boxes and extruded outlines.


static var _box_cache: Dictionary = {}


## Box with rounded edges: a subdivided cube whose vertices are pushed onto an inset box plus radius.
static func rounded_box(size: Vector3, radius: float, seg: int = 4) -> ArrayMesh:
	var key := "%s|%s|%d" % [size, radius, seg]
	if _box_cache.has(key):
		return _box_cache[key]
	var h := size * 0.5
	var r := minf(radius, minf(h.x, minf(h.y, h.z)) * 0.95)
	var inner := h - Vector3.ONE * r
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := seg * 2 + 1
	var faces := [
		[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.BACK, Vector3.LEFT, Vector3.UP], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP],
	]
	for f in faces:
		var nrm: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var grid := []
		for j in n + 1:
			var row := []
			for i in n + 1:
				# Cluster samples near the edges so the rounding is smooth.
				var a := _edge_t(float(i) / n) * 2.0 - 1.0
				var b := _edge_t(float(j) / n) * 2.0 - 1.0
				var p := Vector3(nrm.x * h.x, nrm.y * h.y, nrm.z * h.z)
				p += Vector3(u.x * h.x, u.y * h.y, u.z * h.z) * a + Vector3(v.x * h.x, v.y * h.y, v.z * h.z) * b
				var c := p.clamp(-inner, inner)
				var d := (p - c)
				var dn := d.normalized() if d.length() > 0.00001 else nrm
				row.append([c + dn * r, dn, Vector2(float(i) / n, float(j) / n)])
			grid.append(row)
		for j in n:
			for i in n:
				var q := [grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]]
				for idx in [0, 2, 1, 0, 3, 2]:
					st.set_normal(q[idx][1])
					st.set_uv(q[idx][2])
					st.add_vertex(q[idx][0])
	var mesh := st.commit()
	_box_cache[key] = mesh
	return mesh


static func _edge_t(t: float) -> float:
	# Smoothstep-like remap that packs vertices toward 0 and 1.
	return 0.5 - 0.5 * cos(t * PI)



## Flat outline (counter-clockwise, XY plane) extruded along Z, front face at +depth/2.
static func prism(points: PackedVector2Array, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := depth * 0.5
	var tris := Geometry2D.triangulate_polygon(points)
	var lo := points[0]
	var hi := points[0]
	for p in points:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var span := hi - lo
	for side in [1.0, -1.0]:
		st.set_normal(Vector3(0, 0, side))
		for t in range(0, tris.size(), 3):
			var order := [0, 1, 2] if side > 0.0 else [0, 2, 1]
			for o in order:
				var p := points[tris[t + o]]
				st.set_uv((p - lo) / span)
				st.add_vertex(Vector3(p.x, p.y, h * side))
	var n := points.size()
	for i in n:
		var a := points[i]
		var b := points[(i + 1) % n]
		var e := (b - a).normalized()
		var nrm := Vector3(e.y, -e.x, 0)
		var quad := [Vector3(a.x, a.y, h), Vector3(b.x, b.y, h), Vector3(b.x, b.y, -h), Vector3(a.x, a.y, -h)]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(nrm)
			st.set_uv(Vector2(float(i) / n, 0.0))
			st.add_vertex(quad[idx])
	st.generate_tangents()
	return st.commit()


## Polygon with rounded corners (corner arcs of the given radius).
static func rounded_polygon(corners: PackedVector2Array, radius: float, seg: int = 6) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := corners.size()
	for i in n:
		var p := corners[i]
		var a := (corners[(i - 1 + n) % n] - p).normalized()
		var b := (corners[(i + 1) % n] - p).normalized()
		var half := a.angle_to(b) * 0.5
		var dist := radius / absf(tan(half))
		var center := p + (a + b).normalized() * (radius / absf(sin(half)))
		var s := center + (p + a * dist - center)
		var e := center + (p + b * dist - center)
		var a0 := (s - center).angle()
		var sweep := wrapf((e - center).angle() - a0, -PI, PI)
		for k in seg + 1:
			out.append(center + Vector2.from_angle(a0 + sweep * float(k) / seg) * radius)
	return out
