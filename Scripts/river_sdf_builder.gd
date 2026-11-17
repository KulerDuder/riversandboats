class_name RiverSDFBuilder
extends RefCounted
## Construye matemáticamente el campo de distancia con signo (SDF) de la red
## de ríos interconectados y el mapa de alturas del terreno.

const NEIGHBORS: Array[Vector2i] = [
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(0, -1),
	Vector2i(0, 1),
]


static func build_sdf(
	n: int,
	border_cells: int,
	map_seed: int,
	river_frequency: float,
	river_half_width: float,
	meander: float,
	tributary_scale: float,
	spawn_grid: Vector2
) -> PackedFloat32Array:
	var v: int = n + 1
	var net_a := _make_noise(map_seed, river_frequency)
	var net_b := _make_noise(map_seed + 101, river_frequency * 1.4)
	var warp := _make_noise(map_seed + 202, river_frequency * 0.6)

	var water := PackedByteArray()
	water.resize(v * v)
	var trib_hw: float = river_half_width * tributary_scale

	for j in v:
		for i in v:
			if mini(mini(i, j), mini(n - i, n - j)) < border_cells:
				continue
			var fx := float(i)
			var fy := float(j)
			var wn: float = warp.get_noise_2d(fx, fy)
			var ox: float = fx + wn * meander
			var oy: float = fy + warp.get_noise_2d(fx + 517.0, fy + 211.0) * meander
			var width_mul: float = 1.0 + wn * 0.6
			if _contour_distance(net_a, ox, oy) < river_half_width * width_mul:
				water[j * v + i] = 1
			elif tributary_scale > 0.0 and _contour_distance(net_b, ox, oy) < trib_hw * width_mul:
				water[j * v + i] = 1

	var start: int = _nearest_water(water, v, spawn_grid)
	if start < 0:
		push_warning("RiverSDFBuilder: no hay agua en el mapa. Prueba otra semilla o ríos más anchos.")

	var keep: PackedByteArray = _flood_fill(water, v, start)
	return _compute_signed_distance(keep, v)


static func build_heights(
	sd: PackedFloat32Array,
	n: int,
	border_cells: int,
	map_seed: int,
	relief_frequency: float,
	bank_width: float,
	land_height: float,
	river_depth: float
) -> PackedFloat32Array:
	var v: int = n + 1
	var relief := _make_noise(map_seed + 303, relief_frequency, true)
	var heights := PackedFloat32Array()
	heights.resize(v * v)

	for j in v:
		for i in v:
			var k: int = j * v + i
			var s: float = sd[k]
			var h: float
			if s >= 0.0:
				var bank: float = smoothstep(0.0, bank_width, s)
				var rl: float = relief.get_noise_2d(i, j) * 0.5 + 0.5
				h = bank * land_height * (0.4 + 1.2 * rl)
				var e: float = smoothstep(0.0, float(border_cells), float(mini(mini(i, j), mini(n - i, n - j))))
				h = h * e - (1.0 - e) * 3.0
			else:
				h = -river_depth * smoothstep(0.0, 3.0, -s)
			heights[k] = h

	return heights


# ------------------------------------------------------------------ Internos

static func _make_noise(noise_seed: int, freq: float, fbm: bool = false) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = noise_seed
	noise.frequency = freq
	if fbm:
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = 4
	else:
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	return noise


static func _contour_distance(noise: FastNoiseLite, x: float, y: float) -> float:
	var c: float = noise.get_noise_2d(x, y)
	var gx: float = noise.get_noise_2d(x + 1.0, y) - c
	var gy: float = noise.get_noise_2d(x, y + 1.0) - c
	return absf(c) / maxf(sqrt(gx * gx + gy * gy), 0.0005)


static func _nearest_water(mask: PackedByteArray, v: int, g: Vector2) -> int:
	var best: int = -1
	var best_d: float = INF
	for k in v * v:
		if mask[k] == 1:
			var d: float = Vector2(k % v, k / v).distance_squared_to(g)
			if d < best_d:
				best_d = d
				best = k
	return best


static func _flood_fill(mask: PackedByteArray, v: int, start: int) -> PackedByteArray:
	var keep := PackedByteArray()
	keep.resize(v * v)
	if start < 0:
		return keep
	var queue := PackedInt32Array([start])
	keep[start] = 1
	var head: int = 0
	while head < queue.size():
		var idx: int = queue[head]
		head += 1
		var x: int = idx % v
		var y: int = idx / v
		for off in NEIGHBORS:
			var nx: int = x + off.x
			var ny: int = y + off.y
			if nx < 0 or ny < 0 or nx >= v or ny >= v:
				continue
			var nidx: int = ny * v + nx
			if mask[nidx] == 1 and keep[nidx] == 0:
				keep[nidx] = 1
				queue.append(nidx)
	return keep


static func _compute_signed_distance(keep: PackedByteArray, v: int) -> PackedFloat32Array:
	var d_water: PackedFloat32Array = _distance_to(keep, v, 1)
	var d_land: PackedFloat32Array = _distance_to(keep, v, 0)
	var sd := PackedFloat32Array()
	sd.resize(v * v)
	for k in v * v:
		if keep[k] == 1:
			sd[k] = -(minf(d_land[k], 100.0) - 0.5)
		else:
			sd[k] = minf(d_water[k], 100.0) - 0.5
	sd = _blur(sd, v)
	sd = _blur(sd, v)
	return sd


static func _distance_to(mask: PackedByteArray, v: int, target: int) -> PackedFloat32Array:
	const D2 := 1.41421
	var d := PackedFloat32Array()
	d.resize(v * v)
	for k in v * v:
		d[k] = 0.0 if mask[k] == target else 1.0e6
	for j in v:
		for i in v:
			var k: int = j * v + i
			var best: float = d[k]
			if i > 0:
				best = minf(best, d[k - 1] + 1.0)
			if j > 0:
				best = minf(best, d[k - v] + 1.0)
				if i > 0:
					best = minf(best, d[k - v - 1] + D2)
				if i < v - 1:
					best = minf(best, d[k - v + 1] + D2)
			d[k] = best
	for j in range(v - 1, -1, -1):
		for i in range(v - 1, -1, -1):
			var k: int = j * v + i
			var best: float = d[k]
			if i < v - 1:
				best = minf(best, d[k + 1] + 1.0)
			if j < v - 1:
				best = minf(best, d[k + v] + 1.0)
				if i < v - 1:
					best = minf(best, d[k + v + 1] + D2)
				if i > 0:
					best = minf(best, d[k + v - 1] + D2)
			d[k] = best
	return d


static func _blur(src: PackedFloat32Array, v: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(src.size())
	var out := PackedFloat32Array()
	out.resize(src.size())
	for j in v:
		for i in v:
			var k: int = j * v + i
			var l: float = src[k - 1] if i > 0 else src[k]
			var r: float = src[k + 1] if i < v - 1 else src[k]
			tmp[k] = (l + 2.0 * src[k] + r) * 0.25
	for j in v:
		for i in v:
			var k: int = j * v + i
			var u: float = tmp[k - v] if j > 0 else tmp[k]
			var d: float = tmp[k + v] if j < v - 1 else tmp[k]
			out[k] = (u + 2.0 * tmp[k] + d) * 0.25
	return out
