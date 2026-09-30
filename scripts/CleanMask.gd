class_name CleanMask
extends RefCounted

## The paintable state of one object. Tools stamp soft circles into two byte buffers
## (RGBA: dirt removed, grime removed, paint, foam; R: polish) that are uploaded to the
## dirt shader. Progress is measured on a coarse grid of cells that lie on the object.

const RES := 192
const GRID := 64
const CELL := RES / GRID
const DONE := 190

enum Op { DIRT, GRIME, PAINT, FOAM, RINSE, POLISH }

var buf := PackedByteArray()
var buf2 := PackedByteArray()
var img: Image
var img2: Image
var tex: ImageTexture
var tex2: ImageTexture
var dirty := false
## Per grid cell: index of the front-most object part, or -1 for empty space.
var cell_part := PackedInt32Array()
var _kernels: Dictionary = {}


func _init() -> void:
	buf.resize(RES * RES * 4)
	buf.fill(0)
	buf2.resize(RES * RES)
	buf2.fill(0)
	img = Image.create_from_data(RES, RES, false, Image.FORMAT_RGBA8, buf)
	img2 = Image.create_from_data(RES, RES, false, Image.FORMAT_R8, buf2)
	tex = ImageTexture.create_from_image(img)
	tex2 = ImageTexture.create_from_image(img2)
	cell_part.resize(GRID * GRID)
	cell_part.fill(-1)


func upload() -> void:
	if not dirty:
		return
	dirty = false
	img.set_data(RES, RES, false, Image.FORMAT_RGBA8, buf)
	tex.update(img)
	img2.set_data(RES, RES, false, Image.FORMAT_R8, buf2)
	tex2.update(img2)


func _kernel(r: int) -> PackedFloat32Array:
	if _kernels.has(r):
		return _kernels[r]
	var k := PackedFloat32Array()
	var size := r * 2 + 1
	k.resize(size * size)
	for y in size:
		for x in size:
			var d := Vector2(x - r, y - r).length() / float(r)
			var w := clampf(1.0 - d, 0.0, 1.0)
			k[y * size + x] = w * w * (3.0 - 2.0 * w)
	_kernels[r] = k
	return k


## Stamp a soft brush at mask coordinate uv (0..1). Returns true if anything changed.
func stamp(uv: Vector2, radius: float, strength: float, op: int) -> bool:
	var r := maxi(2, int(radius * RES))
	var k := _kernel(r)
	var size := r * 2 + 1
	var cx := int(uv.x * RES)
	var cy := int(uv.y * RES)
	var amt := strength * 255.0
	var changed := false
	for ky in size:
		var y := cy + ky - r
		if y < 0 or y >= RES:
			continue
		for kx in size:
			var x := cx + kx - r
			if x < 0 or x >= RES:
				continue
			var w: float = k[ky * size + kx]
			if w <= 0.0:
				continue
			var add := int(w * amt) + 1
			var p := y * RES + x
			var i := p * 4
			match op:
				Op.DIRT:
					if buf[i] < 255:
						buf[i] = mini(255, buf[i] + add)
						changed = true
				Op.GRIME:
					if buf[i + 1] < 255:
						buf[i + 1] = mini(255, buf[i + 1] + add)
						changed = true
				Op.PAINT:
					if buf[i + 2] < 255:
						buf[i + 2] = mini(255, buf[i + 2] + add)
						changed = true
				Op.FOAM:
					if buf[i + 3] < 255:
						buf[i + 3] = mini(255, buf[i + 3] + add)
						changed = true
				Op.RINSE:
					if buf[i + 3] > 0 or buf[i + 1] < 255:
						buf[i + 3] = maxi(0, buf[i + 3] - add)
						# Grime only lets go once the foam above it has been washed away.
						if buf[i + 3] < 120:
							buf[i + 1] = mini(255, buf[i + 1] + add)
						buf[i] = mini(255, buf[i] + add)
						changed = true
				Op.POLISH:
					if buf2[p] < 255:
						buf2[p] = mini(255, buf2[p] + add)
						changed = true
	if changed:
		dirty = true
	return changed


## Fraction of the given cells whose channel is finished.
func progress(cells: PackedInt32Array, op: int) -> float:
	if cells.is_empty():
		return 1.0
	var done := 0
	for c in cells:
		var gx := c % GRID
		var gy := c / GRID
		var p := (gy * CELL + CELL / 2) * RES + gx * CELL + CELL / 2
		var i := p * 4
		match op:
			Op.DIRT:
				if buf[i] >= DONE:
					done += 1
			Op.GRIME:
				if buf[i + 1] >= DONE:
					done += 1
			Op.PAINT:
				if buf[i + 2] >= DONE:
					done += 1
			Op.FOAM:
				if buf[i + 3] >= DONE:
					done += 1
			Op.RINSE:
				if buf[i + 3] <= 255 - DONE and buf[i + 1] >= DONE:
					done += 1
			Op.POLISH:
				if buf2[p] >= DONE:
					done += 1
	return float(done) / cells.size()


## Fill a whole channel (used when a stage completes, so no stray spots remain).
func fill(op: int) -> void:
	match op:
		Op.DIRT:
			for i in range(0, buf.size(), 4):
				buf[i] = 255
		Op.GRIME:
			for i in range(1, buf.size(), 4):
				buf[i] = 255
		Op.PAINT:
			for i in range(2, buf.size(), 4):
				buf[i] = 255
		Op.FOAM:
			for i in range(3, buf.size(), 4):
				buf[i] = 255
		Op.RINSE:
			for i in range(0, buf.size(), 4):
				buf[i] = 255
				buf[i + 1] = 255
				buf[i + 3] = 0
		Op.POLISH:
			buf2.fill(255)
	dirty = true
