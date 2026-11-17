class_name MississippiBuildingBuilder
extends RefCounted
## Construye la geometría 3D procedural de los edificios ribereños estilo Mississippi
## y devuelve los nodos de iluminación para controlarlos según el ciclo día/noche.

enum Type {
	TRADING_POST,    # Puesto comercial / almacén fluvial con porche amplio y letrero
	BAYOU_SHACK,     # Cabaña sobre pilotes de ciprés con pasarela hacia el agua
	FISHER_PIER,     # Embarcadero cubierto con muelle largo sobre el río
	RIVER_COTTAGE,   # Casita ribereña con porche corrido y chimenea
}


static func build(parent: Node3D, building_type: int, building_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = building_seed

	var lights: Array[OmniLight3D] = []
	var emissive_mats: Array[StandardMaterial3D] = []

	var mat_cypress := _create_material(Color(0.38, 0.32, 0.25), 0.9)
	var mat_bleached := _create_material(Color(0.58, 0.52, 0.44), 0.85)
	var mat_barn_red := _create_material(Color(0.50, 0.20, 0.16), 0.85)
	var mat_whitewash := _create_material(Color(0.76, 0.74, 0.68), 0.8)
	var mat_tin_roof := _create_material(Color(0.34, 0.36, 0.38), 0.6, 0.35)
	var mat_rust_tin := _create_material(Color(0.48, 0.28, 0.20), 0.75, 0.2)
	var mat_barrel := _create_material(Color(0.34, 0.24, 0.16), 0.85)
	var mat_dark_iron := _create_material(Color(0.18, 0.18, 0.20), 0.5, 0.7)

	# Material compartido para ventanas iluminadas del edificio
	var mat_window := StandardMaterial3D.new()
	mat_window.albedo_color = Color(0.16, 0.18, 0.22)
	mat_window.roughness = 0.25
	mat_window.emission_enabled = true
	mat_window.emission = Color(1.0, 0.76, 0.34)
	mat_window.emission_energy_multiplier = 0.0
	emissive_mats.append(mat_window)

	match building_type:
		Type.TRADING_POST:
			_build_trading_post(parent, rng, mat_barn_red, mat_cypress, mat_tin_roof, mat_barrel, mat_dark_iron, mat_window, lights, emissive_mats)
		Type.BAYOU_SHACK:
			_build_bayou_shack(parent, rng, mat_cypress, mat_bleached, mat_rust_tin, mat_barrel, mat_dark_iron, mat_window, lights, emissive_mats)
		Type.FISHER_PIER:
			_build_fisher_pier(parent, rng, mat_bleached, mat_cypress, mat_rust_tin, mat_barrel, mat_dark_iron, mat_window, lights, emissive_mats)
		Type.RIVER_COTTAGE:
			_build_river_cottage(parent, rng, mat_whitewash, mat_cypress, mat_tin_roof, mat_barrel, mat_dark_iron, mat_window, lights, emissive_mats)
		_:
			_build_trading_post(parent, rng, mat_barn_red, mat_cypress, mat_tin_roof, mat_barrel, mat_dark_iron, mat_window, lights, emissive_mats)

	return {
		"lights": lights,
		"emissive_mats": emissive_mats,
	}


# ---------------------------------------------------------------- Tipos de Edificio

static func _build_trading_post(parent: Node3D, rng: RandomNumberGenerator, mat_wall: Material, mat_wood: Material, mat_roof: Material, mat_barrel: Material, mat_metal: Material, mat_window: Material, lights: Array[OmniLight3D], emissive_mats: Array[StandardMaterial3D]) -> void:
	var width: float = rng.randf_range(5.2, 6.0)
	var length: float = rng.randf_range(5.8, 6.6)
	var height: float = 3.2

	_add_box(parent, Vector3(width, height, length), Vector3(0.0, height * 0.5 + 0.4, 2.2), mat_wall)
	_add_pilings(parent, Vector3(0.0, 0.0, 2.2), width - 0.4, length - 0.4, 1.8, mat_wood)
	_add_gable_roof(parent, Vector3(width + 0.6, 1.6, length + 0.4), Vector3(0.0, height + 1.2, 2.2), mat_roof)

	# Ventanas frontales hacia el porche/río
	var front_z: float = 2.2 - length * 0.5 - 0.02
	_add_window(parent, Vector2(0.85, 0.95), Vector3(-width * 0.28, 1.85, front_z), mat_window, mat_wood)
	_add_window(parent, Vector2(0.85, 0.95), Vector3(width * 0.28, 1.85, front_z), mat_window, mat_wood)

	var porch_len: float = 2.8
	_add_box(parent, Vector3(width, 0.25, porch_len), Vector3(0.0, 0.4, -0.6), mat_wood)
	_add_box(parent, Vector3(0.2, 2.4, 0.2), Vector3(-width * 0.45, 1.6, -1.8), mat_wood)
	_add_box(parent, Vector3(0.2, 2.4, 0.2), Vector3(-width * 0.15, 1.6, -1.8), mat_wood)
	_add_box(parent, Vector3(0.2, 2.4, 0.2), Vector3(width * 0.15, 1.6, -1.8), mat_wood)
	_add_box(parent, Vector3(0.2, 2.4, 0.2), Vector3(width * 0.45, 1.6, -1.8), mat_wood)
	_add_box(parent, Vector3(width + 0.2, 0.15, porch_len + 0.4), Vector3(0.0, 2.8, -0.6), mat_roof)
	_add_box(parent, Vector3(2.6, 0.5, 0.08), Vector3(0.0, 3.1, -1.9), mat_wood)

	var dock_w: float = 2.6
	var dock_len: float = 4.5
	_add_box(parent, Vector3(dock_w, 0.22, dock_len), Vector3(0.0, 0.35, -4.0), mat_wood)
	_add_dock_pilings(parent, Vector3(0.0, 0.0, -4.0), dock_w, dock_len, mat_wood)

	_add_barrel(parent, Vector3(-width * 0.35, 0.95, -0.8), mat_barrel)
	_add_barrel(parent, Vector3(-width * 0.22, 0.95, -0.7), mat_barrel)
	_add_crate(parent, Vector3(width * 0.32, 0.85, -0.8), 0.7, mat_wood)
	_add_chimney(parent, Vector3(width * 0.35, height + 1.8, 1.5), mat_metal)
	_add_lantern(parent, Vector3(0.0, 2.5, -1.8), lights, emissive_mats)
	_add_post_lantern(parent, Vector3(dock_w * 0.45, 0.45, -6.0), mat_wood, lights, emissive_mats)


static func _build_bayou_shack(parent: Node3D, rng: RandomNumberGenerator, mat_wall: Material, mat_wood: Material, mat_roof: Material, mat_barrel: Material, mat_metal: Material, mat_window: Material, lights: Array[OmniLight3D], emissive_mats: Array[StandardMaterial3D]) -> void:
	var width: float = rng.randf_range(4.2, 5.0)
	var length: float = rng.randf_range(4.4, 5.2)
	var stilt_height: float = 2.2
	var house_height: float = 2.6

	_add_box(parent, Vector3(width, house_height, length), Vector3(0.0, stilt_height + house_height * 0.5, 1.8), mat_wall)
	_add_tall_pilings(parent, Vector3(0.0, 0.0, 1.8), width - 0.4, length - 0.4, stilt_height + 1.5, mat_wood)
	_add_gable_roof(parent, Vector3(width + 0.6, 1.4, length + 0.4), Vector3(0.0, stilt_height + house_height + 0.7, 1.8), mat_roof)

	var front_z: float = 1.8 - length * 0.5 - 0.02
	_add_window(parent, Vector2(0.75, 0.85), Vector3(-width * 0.24, stilt_height + 1.35, front_z), mat_window, mat_wood)

	var deck_len: float = 2.4
	_add_box(parent, Vector3(width + 0.4, 0.22, deck_len), Vector3(0.0, stilt_height, -0.8), mat_wood)
	_add_box(parent, Vector3(1.2, 0.15, 3.2), Vector3(width * 0.3, stilt_height * 0.5, -2.8), mat_wood, Vector3(25.0, 0.0, 0.0))

	_add_box(parent, Vector3(2.2, 0.2, 3.2), Vector3(width * 0.3, 0.32, -4.8), mat_wood)
	_add_dock_pilings(parent, Vector3(width * 0.3, 0.0, -4.8), 2.2, 3.2, mat_wood)

	_add_chimney(parent, Vector3(-width * 0.3, stilt_height + house_height + 1.2, 1.2), mat_metal)
	_add_barrel(parent, Vector3(-width * 0.3, stilt_height + 0.55, -0.6), mat_barrel)
	_add_crate(parent, Vector3(-width * 0.15, stilt_height + 0.45, -0.6), 0.6, mat_wood)
	_add_lantern(parent, Vector3(width * 0.3, stilt_height + 1.4, -1.8), lights, emissive_mats)
	_add_post_lantern(parent, Vector3(width * 0.3 - 0.9, 0.42, -6.2), mat_wood, lights, emissive_mats)


static func _build_fisher_pier(parent: Node3D, _rng: RandomNumberGenerator, mat_wood: Material, mat_shed: Material, mat_roof: Material, mat_barrel: Material, _mat_metal: Material, mat_window: Material, lights: Array[OmniLight3D], emissive_mats: Array[StandardMaterial3D]) -> void:
	var pier_w: float = 4.2
	var pier_len: float = 8.5
	_add_box(parent, Vector3(pier_w, 0.25, pier_len), Vector3(0.0, 0.32, -2.5), mat_wood)
	_add_dock_pilings(parent, Vector3(0.0, 0.0, -2.5), pier_w, pier_len, mat_wood, 4)

	_add_box(parent, Vector3(3.6, 2.4, 2.8), Vector3(0.0, 1.5, 2.4), mat_shed)
	_add_gable_roof(parent, Vector3(4.0, 1.2, 3.0), Vector3(0.0, 3.2, 2.4), mat_roof)
	_add_window(parent, Vector2(0.75, 0.75), Vector3(0.0, 1.75, 0.98), mat_window, mat_wood)

	_add_box(parent, Vector3(0.2, 2.4, 0.2), Vector3(-pier_w * 0.42, 1.5, -1.0), mat_wood)
	_add_box(parent, Vector3(0.2, 2.4, 0.2), Vector3(pier_w * 0.42, 1.5, -1.0), mat_wood)
	_add_box(parent, Vector3(0.2, 2.4, 0.2), Vector3(-pier_w * 0.42, 1.5, -4.5), mat_wood)
	_add_box(parent, Vector3(0.2, 2.4, 0.2), Vector3(pier_w * 0.42, 1.5, -4.5), mat_wood)
	_add_gable_roof(parent, Vector3(pier_w + 0.4, 1.1, 4.2), Vector3(0.0, 3.2, -2.8), mat_roof)

	_add_barrel(parent, Vector3(-pier_w * 0.25, 0.85, -2.0), mat_barrel)
	_add_barrel(parent, Vector3(-pier_w * 0.25, 0.85, -2.8), mat_barrel)
	_add_crate(parent, Vector3(pier_w * 0.22, 0.75, -2.2), 0.75, mat_wood)
	_add_crate(parent, Vector3(pier_w * 0.22, 0.75, -3.2), 0.65, mat_wood)

	_add_box(parent, Vector3(0.2, 0.8, 0.2), Vector3(-pier_w * 0.45, 0.7, -6.5), mat_wood)
	_add_box(parent, Vector3(0.2, 0.8, 0.2), Vector3(pier_w * 0.45, 0.7, -6.5), mat_wood)

	_add_lantern(parent, Vector3(0.0, 2.6, -1.0), lights, emissive_mats)
	_add_lantern(parent, Vector3(0.0, 2.6, -4.5), lights, emissive_mats)


static func _build_river_cottage(parent: Node3D, rng: RandomNumberGenerator, mat_wall: Material, mat_wood: Material, mat_roof: Material, mat_barrel: Material, _mat_metal: Material, mat_window: Material, lights: Array[OmniLight3D], emissive_mats: Array[StandardMaterial3D]) -> void:
	var width: float = rng.randf_range(5.6, 6.4)
	var length: float = rng.randf_range(5.0, 5.8)
	var height: float = 3.0

	_add_box(parent, Vector3(width, height, length), Vector3(0.0, height * 0.5 + 0.35, 2.0), mat_wall)
	_add_pilings(parent, Vector3(0.0, 0.0, 2.0), width - 0.4, length - 0.4, 1.8, mat_wood)
	_add_gable_roof(parent, Vector3(width + 0.6, 1.6, length + 0.4), Vector3(0.0, height + 1.1, 2.0), mat_roof)
	_add_box(parent, Vector3(0.8, 4.4, 0.8), Vector3(width * 0.5 + 0.3, 2.2, 2.0), _create_material(Color(0.55, 0.25, 0.18), 0.9))

	var front_z: float = 2.0 - length * 0.5 - 0.02
	_add_window(parent, Vector2(0.85, 0.95), Vector3(-width * 0.26, 1.75, front_z), mat_window, mat_wood)
	_add_window(parent, Vector2(0.85, 0.95), Vector3(width * 0.26, 1.75, front_z), mat_window, mat_wood)

	var porch_len: float = 2.4
	_add_box(parent, Vector3(width, 0.2, porch_len), Vector3(0.0, 0.38, -0.6), mat_wood)
	_add_box(parent, Vector3(0.18, 2.2, 0.18), Vector3(-width * 0.42, 1.45, -1.6), mat_wood)
	_add_box(parent, Vector3(0.18, 2.2, 0.18), Vector3(-width * 0.14, 1.45, -1.6), mat_wood)
	_add_box(parent, Vector3(0.18, 2.2, 0.18), Vector3(width * 0.14, 1.45, -1.6), mat_wood)
	_add_box(parent, Vector3(0.18, 2.2, 0.18), Vector3(width * 0.42, 1.45, -1.6), mat_wood)
	_add_box(parent, Vector3(0.08, 0.8, porch_len), Vector3(-width * 0.48, 0.8, -0.6), mat_wood)
	_add_box(parent, Vector3(0.08, 0.8, porch_len), Vector3(width * 0.48, 0.8, -0.6), mat_wood)
	_add_box(parent, Vector3(width + 0.2, 0.12, porch_len + 0.3), Vector3(0.0, 2.5, -0.6), mat_roof)

	_add_box(parent, Vector3(2.4, 0.2, 3.6), Vector3(0.0, 0.32, -3.2), mat_wood)
	_add_dock_pilings(parent, Vector3(0.0, 0.0, -3.2), 2.4, 3.6, mat_wood)

	_add_barrel(parent, Vector3(-width * 0.32, 0.82, -0.8), mat_barrel)
	_add_lantern(parent, Vector3(0.0, 2.2, -1.6), lights, emissive_mats)
	_add_post_lantern(parent, Vector3(-1.05, 0.42, -4.8), mat_wood, lights, emissive_mats)


# ------------------------------------------------------------- Primitivas y Útiles

static func _add_box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	if rot_deg != Vector3.ZERO:
		mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func _add_window(parent: Node3D, size_xy: Vector2, pos: Vector3, mat_glass: Material, mat_frame: Material) -> void:
	# Marco exterior de madera + cristal emisivo cálido
	_add_box(parent, Vector3(size_xy.x + 0.14, size_xy.y + 0.14, 0.06), pos, mat_frame)
	_add_box(parent, Vector3(size_xy.x, size_xy.y, 0.08), pos + Vector3(0.0, 0.0, -0.01), mat_glass)


static func _add_gable_roof(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
	var mi := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = size
	mi.mesh = prism
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)


static func _add_pilings(parent: Node3D, center: Vector3, w: float, l: float, depth: float, material: Material) -> void:
	var xs: Array[float] = [-w * 0.5, w * 0.5]
	var zs: Array[float] = [-l * 0.5, l * 0.5]
	for x: float in xs:
		for z: float in zs:
			_add_box(parent, Vector3(0.32, depth, 0.32), center + Vector3(x, -depth * 0.3, z), material)


static func _add_tall_pilings(parent: Node3D, center: Vector3, w: float, l: float, height: float, material: Material) -> void:
	var xs: Array[float] = [-w * 0.5, 0.0, w * 0.5]
	var zs: Array[float] = [-l * 0.5, l * 0.5]
	for x: float in xs:
		for z: float in zs:
			_add_box(parent, Vector3(0.3, height, 0.3), center + Vector3(x, height * 0.5 - 1.2, z), material)


static func _add_dock_pilings(parent: Node3D, center: Vector3, w: float, l: float, material: Material, count: int = 2) -> void:
	var z_step: float = l / float(count)
	for i: int in count:
		var z: float = -l * 0.5 + z_step * float(i) + z_step * 0.5
		_add_box(parent, Vector3(0.22, 2.5, 0.22), center + Vector3(-w * 0.48, -0.8, z), material)
		_add_box(parent, Vector3(0.22, 2.5, 0.22), center + Vector3(w * 0.48, -0.8, z), material)


static func _add_barrel(parent: Node3D, pos: Vector3, material: Material) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.32
	cyl.bottom_radius = 0.32
	cyl.height = 0.85
	mi.mesh = cyl
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)


static func _add_crate(parent: Node3D, pos: Vector3, size: float, material: Material) -> void:
	_add_box(parent, Vector3(size, size, size), pos, material)


static func _add_chimney(parent: Node3D, pos: Vector3, material: Material) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.12
	cyl.height = 1.4
	mi.mesh = cyl
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)


static func _add_post_lantern(parent: Node3D, base_pos: Vector3, mat_wood: Material, lights: Array[OmniLight3D], emissive_mats: Array[StandardMaterial3D]) -> void:
	# Poste de amarre en el extremo del muelle con farol sobre el agua
	_add_box(parent, Vector3(0.18, 1.5, 0.18), base_pos + Vector3(0.0, 0.75, 0.0), mat_wood)
	_add_lantern(parent, base_pos + Vector3(0.0, 1.62, 0.0), lights, emissive_mats)


static func _add_lantern(parent: Node3D, pos: Vector3, lights: Array[OmniLight3D], emissive_mats: Array[StandardMaterial3D]) -> void:
	var lantern_mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.22, 0.32, 0.22)
	lantern_mi.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.78, 0.32)
	mat.emission_energy_multiplier = 0.0
	lantern_mi.material_override = mat
	lantern_mi.position = pos
	parent.add_child(lantern_mi)
	emissive_mats.append(mat)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.74, 0.32)
	light.light_energy = 0.0
	light.omni_range = 14.0
	light.omni_attenuation = 1.35
	light.visible = false
	light.position = pos + Vector3(0.0, -0.12, 0.0)
	parent.add_child(light)
	lights.append(light)


static func _create_material(color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat
