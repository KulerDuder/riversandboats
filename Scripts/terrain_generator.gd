@tool
class_name TerrainGenerator
extends Node3D
## Genera un terreno con una red de ríos interconectados.
## Funciona en el editor: cambia la semilla o cualquier parámetro y se regenera.

const RiverSDFBuilderScript := preload("res://Scripts/river_sdf_builder.gd")
const RiverPopulatorScript := preload("res://Scripts/river_populator.gd")
const RiverVegetationScript := preload("res://Scripts/river_vegetation.gd")
const TerrainMinimapBakerScript := preload("res://Scripts/terrain_minimap_baker.gd")

@export_tool_button("Regenerar terreno", "Reload") var regenerate_button: Callable = generate
@export_tool_button("Semilla aleatoria", "RandomNumberGenerator") var random_seed_button: Callable = _randomize_seed

@export var auto_generate: bool = true

@export_group("Semilla")
@export var map_seed: int = 1:
	set(value):
		map_seed = value
		_request_regen()

@export_group("Mapa")
@export_range(64, 320, 8) var grid_cells: int = 192:
	set(value):
		grid_cells = value
		_request_regen()
@export_range(1.0, 6.0, 0.25) var cell_size: float = 2.0:
	set(value):
		cell_size = value
		_request_regen()
@export_range(3, 20, 1) var border_cells: int = 8:
	set(value):
		border_cells = value
		_request_regen()

@export_group("Ríos")
@export_range(1.5, 10.0, 0.1) var river_half_width: float = 3.0:
	set(value):
		river_half_width = value
		_request_regen()
@export_range(0.002, 0.04, 0.001) var river_frequency: float = 0.010:
	set(value):
		river_frequency = value
		_request_regen()
@export_range(0.0, 80.0, 1.0) var meander: float = 25.0:
	set(value):
		meander = value
		_request_regen()
@export_range(0.0, 1.0, 0.05) var tributary_scale: float = 0.8:
	set(value):
		tributary_scale = value
		_request_regen()

@export_group("Relieve")
@export_range(1.0, 30.0, 0.5) var land_height: float = 6.0:
	set(value):
		land_height = value
		_request_regen()
@export_range(0.5, 6.0, 0.1) var river_depth: float = 2.0:
	set(value):
		river_depth = value
		_request_regen()
@export_range(1.0, 15.0, 0.5) var bank_width: float = 5.0:
	set(value):
		bank_width = value
		_request_regen()
@export_range(0.005, 0.1, 0.005) var relief_frequency: float = 0.025:
	set(value):
		relief_frequency = value
		_request_regen()

@export_group("Puestos y Edificios")
@export_range(0, 50, 1) var building_count: int = 14:
	set(value):
		building_count = value
		_request_regen()
@export var buildings_seed: int = 777:
	set(value):
		buildings_seed = value
		_request_regen()

@export_group("Vegetación")
@export_range(0, 1200, 20) var tree_count: int = 420:
	set(value):
		tree_count = value
		_request_regen()
@export_range(0, 2500, 50) var reed_count: int = 950:
	set(value):
		reed_count = value
		_request_regen()
@export_range(0, 1500, 25) var lily_count: int = 480:
	set(value):
		lily_count = value
		_request_regen()
@export var vegetation_seed: int = 555:
	set(value):
		vegetation_seed = value
		_request_regen()

@export_group("Objetos y Peligros del Río")
@export_range(0, 60, 1) var barrel_count: int = 18:
	set(value):
		barrel_count = value
		_request_regen()
@export var pickups_seed: int = 404:
	set(value):
		pickups_seed = value
		_request_regen()
@export_range(0, 50, 1) var mine_count: int = 12:
	set(value):
		mine_count = value
		_request_regen()
@export var mines_seed: int = 909:
	set(value):
		mines_seed = value
		_request_regen()
@export_range(0, 40, 1) var horror_fish_count: int = 14:
	set(value):
		horror_fish_count = value
		_request_regen()
@export var horror_fish_seed: int = 666:
	set(value):
		horror_fish_seed = value
		_request_regen()

const WATER_MARGIN := 0.15

signal terrain_generated

var _n: int = 0
var _sd := PackedFloat32Array()
var _heights := PackedFloat32Array()
var _minimap_texture: ImageTexture = null
var _spawn_node: Marker3D
var _terrain_mi: MeshInstance3D
var _water_mi: MeshInstance3D
var _buildings_node: Node3D
var _vegetation_node: Node3D
var _pickups_node: Node3D
var _mines_node: Node3D
var _horror_fish_node: Node3D
var _dirty: bool = false
var _dirty_time: int = 0
var _last_spawn_pos := Vector3.INF


func _ready() -> void:
	generate()


func _process(_delta: float) -> void:
	if _spawn_node and not _spawn_node.position.is_equal_approx(_last_spawn_pos):
		_last_spawn_pos = _spawn_node.position
		_request_regen()
	if _dirty and Time.get_ticks_msec() - _dirty_time > 250:
		_dirty = false
		generate()


# ------------------------------------------------------------------ API pública

func get_world_size() -> float:
	return (_n if _n > 0 else grid_cells) * cell_size


func get_grid_cells_count() -> int:
	return _n if _n > 0 else grid_cells


func get_water_material() -> ShaderMaterial:
	if _water_mi != null and _water_mi.material_override is ShaderMaterial:
		return _water_mi.material_override as ShaderMaterial
	return null


func get_terrain_material() -> ShaderMaterial:
	if _terrain_mi != null and _terrain_mi.material_override is ShaderMaterial:
		return _terrain_mi.material_override as ShaderMaterial
	return null


func get_minimap_texture() -> ImageTexture:
	if _minimap_texture == null:
		if _sd.is_empty():
			generate()
		var n: int = get_grid_cells_count()
		_minimap_texture = TerrainMinimapBakerScript.bake_texture(_sd, n, border_cells, river_half_width, WATER_MARGIN)
	return _minimap_texture


func generate_minimap_image() -> Image:
	var n: int = get_grid_cells_count()
	return TerrainMinimapBakerScript.bake_image(_sd, n, border_cells, river_half_width, WATER_MARGIN)


func is_water_at(world_pos: Vector3) -> bool:
	var l := to_local(world_pos)
	return sample_sd(l.x, l.z) < -WATER_MARGIN


func get_spawn_position() -> Vector3:
	var p := _spawn_node.global_position
	return Vector3(p.x, 0.0, p.z)


func get_spawn_yaw() -> float:
	var origin := get_spawn_position()
	var best_yaw := 0.0
	var best_len := -1.0
	for k in 16:
		var yaw := TAU * k / 16.0
		var dir := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var length := 0.0
		while length < 80.0 and is_water_at(origin + dir * length):
			length += 2.0
		if length > best_len:
			best_len = length
			best_yaw = yaw
	return best_yaw


func sample_sd(lx: float, lz: float) -> float:
	if _sd.is_empty():
		return 1000.0
	var half := _n * cell_size * 0.5
	var gx := (lx + half) / cell_size
	var gz := (lz + half) / cell_size
	if gx < 0.0 or gz < 0.0 or gx >= _n or gz >= _n:
		return 1000.0
	var i0 := int(gx)
	var j0 := int(gz)
	var fx := gx - i0
	var fz := gz - j0
	var v := _n + 1
	var a := _sd[j0 * v + i0]
	var b := _sd[j0 * v + i0 + 1]
	var c := _sd[(j0 + 1) * v + i0]
	var d := _sd[(j0 + 1) * v + i0 + 1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


func sample_height(lx: float, lz: float) -> float:
	if _heights.is_empty():
		return 0.0
	var half: float = float(_n) * cell_size * 0.5
	var gx: float = (lx + half) / cell_size
	var gz: float = (lz + half) / cell_size
	if gx < 0.0 or gz < 0.0 or gx >= _n or gz >= _n:
		return -3.0
	var i0: int = int(gx)
	var j0: int = int(gz)
	var fx: float = gx - float(i0)
	var fz: float = gz - float(j0)
	var v: int = _n + 1
	var a: float = _heights[j0 * v + i0]
	var b: float = _heights[j0 * v + i0 + 1]
	var c: float = _heights[(j0 + 1) * v + i0]
	var d: float = _heights[(j0 + 1) * v + i0 + 1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


func get_height_at(world_pos: Vector3) -> float:
	var l: Vector3 = to_local(world_pos)
	return sample_height(l.x, l.z)


func get_building_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	if _buildings_node != null:
		for child: Node in _buildings_node.get_children():
			if child is Node3D:
				positions.append(child.global_position)
	return positions


func assign_boat_to_pickups(p_boat: Boat) -> void:
	if _pickups_node == null:
		return
	for child: Node in _pickups_node.get_children():
		if child is RiverPickup:
			child.boat = p_boat


func assign_boat_to_mines(p_boat: Boat) -> void:
	if _mines_node == null:
		return
	for child: Node in _mines_node.get_children():
		if child is NavalMine:
			child.boat = p_boat


func assign_boat_to_horror_fish(p_boat: Boat) -> void:
	if _horror_fish_node == null:
		return
	for child: Node in _horror_fish_node.get_children():
		if child is RiverMonsterFish:
			child.boat = p_boat


# ------------------------------------------------------------------ Generación

func generate() -> void:
	var t0 := Time.get_ticks_msec()
	_ensure_nodes()
	_n = grid_cells
	var v := _n + 1

	_sd = RiverSDFBuilderScript.build_sdf(
		_n, border_cells, map_seed, river_frequency,
		river_half_width, meander, tributary_scale, _spawn_to_grid()
	)
	_snap_spawn(v)

	_heights = RiverSDFBuilderScript.build_heights(
		_sd, _n, border_cells, map_seed, relief_frequency,
		bank_width, land_height, river_depth
	)
	_build_mesh(v)

	RiverPopulatorScript.populate_buildings(_buildings_node, self, building_count, map_seed + (buildings_seed if buildings_seed != null else 777))
	RiverVegetationScript.populate(_vegetation_node, self, tree_count, reed_count, lily_count, map_seed + (vegetation_seed if vegetation_seed != null else 555))
	RiverPopulatorScript.populate_pickups(_pickups_node, self, barrel_count, map_seed + (pickups_seed if pickups_seed != null else 404))
	RiverPopulatorScript.populate_mines(_mines_node, self, mine_count, map_seed + (mines_seed if mines_seed != null else 909))
	RiverPopulatorScript.populate_horror_fish(_horror_fish_node, self, horror_fish_count, map_seed + (horror_fish_seed if horror_fish_seed != null else 666))

	_minimap_texture = null
	terrain_generated.emit()

	print("Terreno generado (semilla %d) en %d ms" % [map_seed, Time.get_ticks_msec() - t0])


# ----------------------------------------------------------------------- Spawn

func _spawn_to_grid() -> Vector2:
	var half := _n * cell_size * 0.5
	var p := _spawn_node.position
	return Vector2((p.x + half) / cell_size, (p.z + half) / cell_size)


func _snap_spawn(v: int) -> void:
	var p := _spawn_node.position
	if sample_sd(p.x, p.z) < -1.5:
		_last_spawn_pos = _spawn_node.position
		return
	var g := _spawn_to_grid()
	for threshold in [-2.0, -1.5, -1.0, -0.5]:
		var best := -1
		var best_d := INF
		for k in v * v:
			if _sd[k] < threshold:
				var d := Vector2(k % v, k / v).distance_squared_to(g)
				if d < best_d:
					best_d = d
					best = k
		if best >= 0:
			var half := _n * cell_size * 0.5
			_spawn_node.position = Vector3((best % v) * cell_size - half, 0.0, (best / v) * cell_size - half)
			print("SpawnPoint movido al río más cercano.")
			break
	_last_spawn_pos = _spawn_node.position


# ------------------------------------------------------------------------ Malla

func _build_mesh(v: int) -> void:
	var n := _n
	var half := n * cell_size * 0.5

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(v * v)
	normals.resize(v * v)
	colors.resize(v * v)

	for j in v:
		for i in v:
			var k := j * v + i
			var h := _heights[k]
			verts[k] = Vector3(i * cell_size - half, h, j * cell_size - half)
			var hl := _heights[k - 1] if i > 0 else h
			var hr := _heights[k + 1] if i < v - 1 else h
			var hd := _heights[k - v] if j > 0 else h
			var hu := _heights[k + v] if j < v - 1 else h
			var normal := Vector3(hl - hr, 2.0 * cell_size, hd - hu).normalized()
			normals[k] = normal
			colors[k] = _color_for(h, normal.y)

	var indices := PackedInt32Array()
	indices.resize(n * n * 6)
	var w := 0
	for j in n:
		for i in n:
			var a := j * v + i
			var b := a + 1
			var c := a + v
			var d := c + 1
			indices[w] = a
			indices[w + 1] = b
			indices[w + 2] = c
			indices[w + 3] = b
			indices[w + 4] = d
			indices[w + 5] = c
			w += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	_terrain_mi.mesh = mesh
	var terrain_shader := load("res://Shaders/river_terrain.gdshader") as Shader
	if terrain_shader != null:
		var tm := ShaderMaterial.new()
		tm.shader = terrain_shader
		_terrain_mi.material_override = tm
	else:
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.95
		_terrain_mi.material_override = mat


func _color_for(h: float, normal_y: float) -> Color:
	var col: Color
	if h < -0.2:
		col = Color(0.35, 0.3, 0.2)
	elif h < 0.6:
		col = Color(0.76, 0.7, 0.5)
	else:
		col = Color(0.25, 0.5, 0.18).lerp(Color(0.5, 0.55, 0.28), clampf(h / land_height, 0.0, 1.0))
	var rock := smoothstep(0.12, 0.35, 1.0 - normal_y)
	return col.lerp(Color(0.45, 0.42, 0.40), rock)


# ------------------------------------------------------------------------ Nodos

func _ensure_nodes() -> void:
	var scene_root: Node = get_tree().edited_scene_root if Engine.is_editor_hint() else null

	_spawn_node = get_node_or_null("SpawnPoint") as Marker3D
	if _spawn_node == null:
		_spawn_node = Marker3D.new()
		_spawn_node.name = "SpawnPoint"
		_spawn_node.gizmo_extents = 4.0
		add_child(_spawn_node)
		if scene_root:
			_spawn_node.owner = scene_root
	if Engine.is_editor_hint() and _spawn_node.get_node_or_null("Preview") == null:
		var preview := MeshInstance3D.new()
		preview.name = "Preview"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.4
		cyl.bottom_radius = 0.4
		cyl.height = 8.0
		preview.mesh = cyl
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(1.0, 0.2, 0.1)
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		preview.material_override = pm
		preview.position.y = 4.0
		_spawn_node.add_child(preview)

	_terrain_mi = get_node_or_null("TerrainMesh") as MeshInstance3D
	if _terrain_mi == null:
		_terrain_mi = MeshInstance3D.new()
		_terrain_mi.name = "TerrainMesh"
		add_child(_terrain_mi)

	_water_mi = get_node_or_null("Water") as MeshInstance3D
	if _water_mi == null:
		_water_mi = MeshInstance3D.new()
		_water_mi.name = "Water"
		var plane := PlaneMesh.new()
		plane.size = Vector2(4000, 4000)
		plane.subdivide_width = 128
		plane.subdivide_depth = 128
		_water_mi.mesh = plane
		_water_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_water_mi)

	var water_shader := load("res://Shaders/river_water.gdshader") as Shader
	if water_shader != null:
		var wm := ShaderMaterial.new()
		wm.shader = water_shader
		_water_mi.material_override = wm
	elif _water_mi.material_override == null:
		var fallback_wm := StandardMaterial3D.new()
		fallback_wm.albedo_color = Color(0.05, 0.3, 0.55)
		fallback_wm.metallic = 0.0
		fallback_wm.roughness = 0.05
		_water_mi.material_override = fallback_wm

	_buildings_node = get_node_or_null("Buildings") as Node3D
	if _buildings_node == null:
		_buildings_node = Node3D.new()
		_buildings_node.name = "Buildings"
		add_child(_buildings_node)

	_vegetation_node = get_node_or_null("Vegetation") as Node3D
	if _vegetation_node == null:
		_vegetation_node = Node3D.new()
		_vegetation_node.name = "Vegetation"
		add_child(_vegetation_node)

	_pickups_node = get_node_or_null("Pickups") as Node3D
	if _pickups_node == null:
		_pickups_node = Node3D.new()
		_pickups_node.name = "Pickups"
		add_child(_pickups_node)

	_mines_node = get_node_or_null("Mines") as Node3D
	if _mines_node == null:
		_mines_node = Node3D.new()
		_mines_node.name = "Mines"
		add_child(_mines_node)

	_horror_fish_node = get_node_or_null("HorrorFish") as Node3D
	if _horror_fish_node == null:
		_horror_fish_node = Node3D.new()
		_horror_fish_node.name = "HorrorFish"
		add_child(_horror_fish_node)


func _request_regen() -> void:
	if not auto_generate or not is_node_ready():
		return
	_dirty = true
	_dirty_time = Time.get_ticks_msec()


func _randomize_seed() -> void:
	map_seed = randi() % 100000
