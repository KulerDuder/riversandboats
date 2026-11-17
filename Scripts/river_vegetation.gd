class_name RiverVegetation
extends RefCounted
## Genera vegetación procedural del río Mississippi / bayou mediante MultiMeshInstance3D:
## cipreses calvos en tierra firme, juncos en las orillas y nenúfares en aguas tranquilas,
## respetando zonas de exclusión alrededor de los puestos y muelles.

const BUILDING_EXCLUSION_TREES: float = 14.5
const BUILDING_EXCLUSION_REEDS: float = 12.5
const BUILDING_EXCLUSION_LILIES: float = 16.0
const SPAWN_EXCLUSION: float = 14.0


static func populate(
	parent: Node3D,
	terrain: TerrainGenerator,
	tree_count_val: Variant = 420,
	reed_count_val: Variant = 950,
	lily_count_val: Variant = 480,
	veg_seed_val: Variant = 555
) -> void:
	if parent == null or terrain == null:
		return

	var tree_count: int = int(tree_count_val) if tree_count_val != null else 420
	var reed_count: int = int(reed_count_val) if reed_count_val != null else 950
	var lily_count: int = int(lily_count_val) if lily_count_val != null else 480
	var veg_seed: int = int(veg_seed_val) if veg_seed_val != null else 555

	for child: Node in parent.get_children():
		child.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = veg_seed

	var world_size: float = terrain.get_world_size()
	var half: float = world_size * 0.5
	var margin: float = float(terrain.border_cells + 2) * terrain.cell_size
	var min_coord: float = -half + margin
	var max_coord: float = half - margin
	if min_coord >= max_coord:
		return

	var building_positions: Array[Vector3] = terrain.get_building_positions()
	var spawn_pos: Vector3 = terrain.get_spawn_position()

	_spawn_cypress_trees(parent, terrain, rng, tree_count, min_coord, max_coord, building_positions)
	_spawn_shore_reeds(parent, terrain, rng, reed_count, min_coord, max_coord, building_positions, spawn_pos)
	_spawn_water_lilies(parent, terrain, rng, lily_count, min_coord, max_coord, building_positions, spawn_pos)


# ------------------------------------------------------------------ Cipreses del Bayou

static func _spawn_cypress_trees(
	parent: Node3D,
	terrain: TerrainGenerator,
	rng: RandomNumberGenerator,
	target_count: int,
	min_c: float,
	max_c: float,
	buildings: Array[Vector3]
) -> void:
	if target_count <= 0:
		return

	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var attempts: int = target_count * 18

	for _i in attempts:
		if transforms.size() >= target_count:
			break
		var lx: float = rng.randf_range(min_c, max_c)
		var lz: float = rng.randf_range(min_c, max_c)
		var sd: float = terrain.sample_sd(lx, lz)
		if sd < 1.35:
			continue

		var h: float = terrain.sample_height(lx, lz)
		if h < 0.35:
			continue

		var world_p: Vector3 = terrain.to_global(Vector3(lx, h, lz))
		if _is_near_any(world_p, buildings, BUILDING_EXCLUSION_TREES):
			continue

		var scale_xz: float = rng.randf_range(0.75, 1.35)
		var scale_y: float = rng.randf_range(0.80, 1.45)
		var rot_y: float = rng.randf_range(0.0, TAU)
		var tilt_x: float = rng.randf_range(-0.05, 0.05)
		var tilt_z: float = rng.randf_range(-0.05, 0.05)

		var basis := Basis.from_euler(Vector3(tilt_x, rot_y, tilt_z)).scaled(Vector3(scale_xz, scale_y, scale_xz))
		transforms.append(Transform3D(basis, Vector3(lx, h - 0.15, lz)))

		var tint_var: float = rng.randf_range(-0.08, 0.08)
		colors.append(Color(
			clampf(0.95 + tint_var, 0.75, 1.15),
			clampf(1.0 + tint_var * 0.7, 0.80, 1.15),
			clampf(0.92 - tint_var * 0.5, 0.75, 1.10)
		))

	if transforms.is_empty():
		return

	var trunk_mmi := _create_multimesh_instance(
		"CypressTrunks",
		_build_trunk_mesh(),
		_create_bark_material(),
		transforms,
		colors,
		true
	)
	parent.add_child(trunk_mmi)

	var canopy_mmi := _create_multimesh_instance(
		"CypressCanopies",
		_build_canopy_mesh(),
		_create_foliage_material(),
		transforms,
		colors,
		true
	)
	parent.add_child(canopy_mmi)


# ------------------------------------------------------------------ Juncos de Orilla

static func _spawn_shore_reeds(
	parent: Node3D,
	terrain: TerrainGenerator,
	rng: RandomNumberGenerator,
	target_count: int,
	min_c: float,
	max_c: float,
	buildings: Array[Vector3],
	spawn_pos: Vector3
) -> void:
	if target_count <= 0:
		return

	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var attempts: int = target_count * 26

	for _i in attempts:
		if transforms.size() >= target_count:
			break
		var lx: float = rng.randf_range(min_c, max_c)
		var lz: float = rng.randf_range(min_c, max_c)
		var sd: float = terrain.sample_sd(lx, lz)
		if sd < -1.35 or sd > 0.65:
			continue

		var world_p: Vector3 = terrain.to_global(Vector3(lx, 0.0, lz))
		if _is_near_any(world_p, buildings, BUILDING_EXCLUSION_REEDS):
			continue
		if world_p.distance_squared_to(spawn_pos) < SPAWN_EXCLUSION * SPAWN_EXCLUSION:
			continue

		var ground_h: float = terrain.sample_height(lx, lz)
		var base_y: float = maxf(ground_h, -0.35)
		var sc: float = rng.randf_range(0.75, 1.40)
		var basis := Basis.from_euler(Vector3(0.0, rng.randf_range(0.0, TAU), 0.0)).scaled(Vector3(sc, sc * rng.randf_range(0.85, 1.25), sc))
		transforms.append(Transform3D(basis, Vector3(lx, base_y, lz)))

		var g_shift: float = rng.randf_range(-0.10, 0.12)
		colors.append(Color(
			clampf(0.34 + g_shift * 0.8, 0.20, 0.55),
			clampf(0.52 + g_shift, 0.35, 0.72),
			clampf(0.20 + g_shift * 0.3, 0.12, 0.35)
		))

	if transforms.is_empty():
		return

	var reeds_mmi := _create_multimesh_instance(
		"ShoreReeds",
		_build_reed_clump_mesh(),
		_create_reed_material(),
		transforms,
		colors,
		false
	)
	parent.add_child(reeds_mmi)


# ------------------------------------------------------------------ Nenúfares Flotantes

static func _spawn_water_lilies(
	parent: Node3D,
	terrain: TerrainGenerator,
	rng: RandomNumberGenerator,
	target_count: int,
	min_c: float,
	max_c: float,
	buildings: Array[Vector3],
	spawn_pos: Vector3
) -> void:
	if target_count <= 0:
		return

	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var attempts: int = target_count * 24

	for _i in attempts:
		if transforms.size() >= target_count:
			break
		var lx: float = rng.randf_range(min_c, max_c)
		var lz: float = rng.randf_range(min_c, max_c)
		var sd: float = terrain.sample_sd(lx, lz)
		if sd > -0.95 or sd < -3.8:
			continue

		var world_p: Vector3 = terrain.to_global(Vector3(lx, 0.0, lz))
		if _is_near_any(world_p, buildings, BUILDING_EXCLUSION_LILIES):
			continue
		if world_p.distance_squared_to(spawn_pos) < SPAWN_EXCLUSION * SPAWN_EXCLUSION:
			continue

		var sc: float = rng.randf_range(0.65, 1.35)
		var basis := Basis.from_euler(Vector3(0.0, rng.randf_range(0.0, TAU), 0.0)).scaled(Vector3(sc, 1.0, sc))
		transforms.append(Transform3D(basis, Vector3(lx, 0.025, lz)))

		var v: float = rng.randf_range(0.85, 1.15)
		colors.append(Color(0.18 * v, 0.44 * v, 0.20 * v))

	if transforms.is_empty():
		return

	var lilies_mmi := _create_multimesh_instance(
		"WaterLilies",
		_build_lily_pad_mesh(),
		_create_lily_material(),
		transforms,
		colors,
		false
	)
	parent.add_child(lilies_mmi)


# ------------------------------------------------------------------ Utilidades MultiMesh

static func _is_near_any(pos: Vector3, points: Array[Vector3], radius: float) -> bool:
	var r2: float = radius * radius
	for p: Vector3 in points:
		var dx: float = pos.x - p.x
		var dz: float = pos.z - p.z
		if (dx * dx + dz * dz) <= r2:
			return true
	return false


static func _create_multimesh_instance(
	node_name: String,
	mesh: Mesh,
	material: Material,
	transforms: Array[Transform3D],
	colors: Array[Color],
	cast_shadows: bool
) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()

	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if cast_shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	return mmi


# ------------------------------------------------------------------ Mallas Procedurales

static func _build_trunk_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rings := [
		{"y": 0.0, "r": 0.48},
		{"y": 1.1, "r": 0.26},
		{"y": 3.4, "r": 0.18},
		{"y": 5.6, "r": 0.08},
	]
	var sides: int = 7

	for seg in rings.size() - 1:
		var y0: float = rings[seg]["y"]
		var r0: float = rings[seg]["r"]
		var y1: float = rings[seg + 1]["y"]
		var r1: float = rings[seg + 1]["r"]

		for s in sides:
			var a0: float = TAU * float(s) / float(sides)
			var a1: float = TAU * float(s + 1) / float(sides)

			var p00 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
			var p10 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
			var p01 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
			var p11 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)

			_add_tri(st, p00, p01, p11)
			_add_tri(st, p00, p11, p10)

	st.generate_normals()
	return st.commit()


static func _build_canopy_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var tiers := [
		{"y_base": 2.4, "y_top": 5.2, "r": 2.15, "ox": 0.0, "oz": 0.0},
		{"y_base": 4.0, "y_top": 6.8, "r": 1.65, "ox": 0.14, "oz": -0.10},
		{"y_base": 5.5, "y_top": 8.2, "r": 1.05, "ox": -0.08, "oz": 0.12},
	]
	var sides: int = 8

	for t in tiers:
		var yb: float = t["y_base"]
		var yt: float = t["y_top"]
		var r: float = t["r"]
		var ox: float = t["ox"]
		var oz: float = t["oz"]
		var apex := Vector3(ox, yt, oz)
		var center_b := Vector3(ox, yb + 0.15, oz)

		for s in sides:
			var a0: float = TAU * float(s) / float(sides)
			var a1: float = TAU * float(s + 1) / float(sides)
			var r0: float = r * (0.90 if s % 2 == 0 else 1.08)
			var r1: float = r * (0.90 if (s + 1) % 2 == 0 else 1.08)

			var p0 := Vector3(ox + cos(a0) * r0, yb, oz + sin(a0) * r0)
			var p1 := Vector3(ox + cos(a1) * r1, yb, oz + sin(a1) * r1)

			_add_tri(st, p0, apex, p1)
			_add_tri(st, p0, p1, center_b)

	st.generate_normals()
	return st.commit()


static func _build_reed_clump_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var stalks: int = 6
	for k in stalks:
		var ang: float = TAU * float(k) / float(stalks) + 0.3
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var h: float = 1.05 + float(k % 3) * 0.28
		var lean: float = 0.28 + float(k % 2) * 0.16
		var base_offset: Vector3 = dir * 0.12

		var b_l: Vector3 = base_offset - side * 0.045
		var b_r: Vector3 = base_offset + side * 0.045
		var m_l: Vector3 = base_offset + dir * (lean * 0.35) + Vector3.UP * (h * 0.55) - side * 0.03
		var m_r: Vector3 = base_offset + dir * (lean * 0.35) + Vector3.UP * (h * 0.55) + side * 0.03
		var tip: Vector3 = base_offset + dir * lean + Vector3.UP * h

		_add_tri(st, b_l, m_l, m_r)
		_add_tri(st, b_l, m_r, b_r)
		_add_tri(st, m_l, tip, m_r)

	st.generate_normals()
	return st.commit()


static func _build_lily_pad_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var sectors: int = 9
	var r: float = 0.42
	var center := Vector3(0.0, 0.0, 0.0)

	for s in sectors - 1:
		var a0: float = TAU * float(s) / float(sectors)
		var a1: float = TAU * float(s + 1) / float(sectors)
		var p0 := Vector3(cos(a0) * r, 0.0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0.0, sin(a1) * r)
		_add_tri(st, center, p1, p0)

	st.generate_normals()
	return st.commit()


static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


# ------------------------------------------------------------------ Materiales

static func _create_bark_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.36, 0.25, 0.18)
	mat.roughness = 0.88
	return mat


static func _create_foliage_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.22, 0.44, 0.18)
	mat.roughness = 0.72
	mat.subsurf_scatter_enabled = true
	mat.subsurf_scatter_strength = 0.45
	return mat


static func _create_reed_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.65
	mat.subsurf_scatter_enabled = true
	mat.subsurf_scatter_strength = 0.35
	return mat


static func _create_lily_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.38
	mat.subsurf_scatter_enabled = true
	mat.subsurf_scatter_strength = 0.30
	return mat
