class_name RiverMonsterFish
extends Node3D
## Pez depredador estilo low-poly horror con grandes dientes y ojos brillantes.
## Patrulla los ríos de forma autónoma sin perseguir al jugador; al chocar contra
## el barco drena combustible y estalla en una explosión de vóxeles rojos.

signal bit_player(fuel_lost: float)

@export var swim_speed: float = 4.2
@export var turn_speed: float = 2.2
@export var fuel_damage: float = 16.0
@export var collision_radius: float = 1.65

var boat: Boat
var terrain: TerrainGenerator

var _visual: Node3D
var _tail_pivot: Node3D
var _jaw_pivot: Node3D
var _swim_phase: float = 0.0
var _wander_timer: float = 0.0
var _wander_steer: float = 0.0
var _consumed: bool = false


func _ready() -> void:
	_swim_phase = randf() * TAU
	_wander_timer = randf_range(1.5, 4.0)
	_build_horror_fish_mesh()


func _physics_process(delta: float) -> void:
	if _consumed:
		return

	_swim_phase += delta * (6.5 + swim_speed * 0.8)
	_animate_body()
	_navigate_river(delta)
	_check_boat_collision()


# ------------------------------------------------------------------ Navegación fluvial

func _navigate_river(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(2.0, 5.0)
		_wander_steer = randf_range(-0.45, 0.45)

	var steer: float = _wander_steer

	if is_instance_valid(terrain):
		var forward := -global_basis.z
		var right := global_basis.x
		var probe_dist: float = 5.5

		var ahead_pos: Vector3 = global_position + forward * probe_dist
		var left_pos: Vector3 = global_position + (forward * 0.8 - right * 0.6).normalized() * probe_dist
		var right_pos: Vector3 = global_position + (forward * 0.8 + right * 0.6).normalized() * probe_dist

		var local_ahead: Vector3 = terrain.to_local(ahead_pos)
		var local_left: Vector3 = terrain.to_local(left_pos)
		var local_right: Vector3 = terrain.to_local(right_pos)

		var sd_ahead: float = terrain.sample_sd(local_ahead.x, local_ahead.z)
		var sd_left: float = terrain.sample_sd(local_left.x, local_left.z)
		var sd_right: float = terrain.sample_sd(local_right.x, local_right.z)

		# Evitar orillas y aguas demasiado someras (sd > -0.85 es cerca de tierra)
		if sd_ahead > -0.85:
			steer = 1.35 if sd_left > sd_right else -1.35
		elif sd_left > -0.75:
			steer = 0.95
		elif sd_right > -0.75:
			steer = -0.95

	rotate_y(steer * turn_speed * delta)

	var step: Vector3 = -global_basis.z * swim_speed * delta
	var next_pos: Vector3 = global_position + step

	if not is_instance_valid(terrain) or terrain.is_water_at(next_pos):
		global_position = Vector3(next_pos.x, 0.0, next_pos.z)
	else:
		# Giro de emergencia si quedó encajonado en un meandro estrecho
		rotate_y(PI * 0.65)


func _animate_body() -> void:
	if _visual != null:
		_visual.position.y = 0.02 + sin(_swim_phase * 0.5) * 0.04
		_visual.rotation.z = sin(_swim_phase) * 0.08
	if _tail_pivot != null:
		_tail_pivot.rotation.y = sin(_swim_phase) * 0.42
	if _jaw_pivot != null:
		_jaw_pivot.rotation.x = deg_to_rad(14.0 + sin(_swim_phase * 1.4) * 7.0)


func _check_boat_collision() -> void:
	if not is_instance_valid(boat):
		return

	var dx: float = boat.global_position.x - global_position.x
	var dz: float = boat.global_position.z - global_position.z
	if (dx * dx + dz * dz) <= (collision_radius * collision_radius):
		_trigger_bite_and_explode()


# ------------------------------------------------------------------ Impacto y Vóxeles Rojos

func _trigger_bite_and_explode() -> void:
	_consumed = true
	if is_instance_valid(boat):
		boat.consume_fuel(fuel_damage)
	bit_player.emit(fuel_damage)
	_spawn_voxel_explosion()
	queue_free()


func _spawn_voxel_explosion() -> void:
	if not is_inside_tree():
		return
	var root_parent: Node = get_parent()
	if root_parent == null:
		return

	var spawn_pos: Vector3 = global_position + Vector3(0.0, 0.25, 0.0)
	var explosion_holder := _VoxelExplosionEffect.new()
	root_parent.add_child(explosion_holder)
	explosion_holder.global_position = spawn_pos


# ------------------------------------------------------------------ Construcción Low-Poly Horror

func _build_horror_fish_mesh() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var mat_skin := StandardMaterial3D.new()
	mat_skin.albedo_color = Color(0.07, 0.08, 0.10)
	mat_skin.roughness = 0.35
	mat_skin.metallic = 0.15

	var mat_belly := StandardMaterial3D.new()
	mat_belly.albedo_color = Color(0.24, 0.12, 0.14)
	mat_belly.roughness = 0.55

	var mat_tooth := StandardMaterial3D.new()
	mat_tooth.albedo_color = Color(0.94, 0.91, 0.82)
	mat_tooth.roughness = 0.25

	var mat_eye := StandardMaterial3D.new()
	mat_eye.albedo_color = Color(1.0, 0.08, 0.05)
	mat_eye.emission_enabled = true
	mat_eye.emission = Color(1.0, 0.05, 0.02)
	mat_eye.emission_energy_multiplier = 3.0

	# Torso angular low-poly
	_add_box(_visual, Vector3(0.56, 0.52, 1.35), Vector3(0.0, 0.05, 0.05), mat_skin, Vector3(0.0, 0.0, 45.0))
	_add_box(_visual, Vector3(0.46, 0.26, 1.25), Vector3(0.0, -0.10, 0.05), mat_belly)

	# Cráneo superior alargado
	_add_box(_visual, Vector3(0.52, 0.24, 0.85), Vector3(0.0, 0.16, -0.82), mat_skin, Vector3(-8.0, 0.0, 0.0))

	# Ojos brillantes rojo sangre
	_add_box(_visual, Vector3(0.11, 0.11, 0.11), Vector3(-0.25, 0.21, -0.78), mat_eye)
	_add_box(_visual, Vector3(0.11, 0.11, 0.11), Vector3(0.25, 0.21, -0.78), mat_eye)

	# Aleta dorsal dentada que sobresale del agua
	_add_prism(_visual, Vector3(0.07, 0.58, 0.65), Vector3(0.0, 0.44, 0.10), mat_skin, Vector3(-18.0, 0.0, 0.0))
	_add_prism(_visual, Vector3(0.06, 0.36, 0.40), Vector3(0.0, 0.34, 0.55), mat_skin, Vector3(-22.0, 0.0, 0.0))

	# Aletas pectorales afiladas
	_add_prism(_visual, Vector3(0.45, 0.06, 0.32), Vector3(-0.42, -0.04, -0.20), mat_skin, Vector3(0.0, 25.0, -18.0))
	_add_prism(_visual, Vector3(0.45, 0.06, 0.32), Vector3(0.42, -0.04, -0.20), mat_skin, Vector3(0.0, -25.0, 18.0))

	# Hileras de dientes superiores
	for i in 4:
		var z_t: float = -0.62 - float(i) * 0.17
		_add_prism(_visual, Vector3(0.06, 0.16, 0.06), Vector3(-0.18, 0.01, z_t), mat_tooth, Vector3(180.0, 0.0, 0.0))
		_add_prism(_visual, Vector3(0.06, 0.16, 0.06), Vector3(0.18, 0.01, z_t), mat_tooth, Vector3(180.0, 0.0, 0.0))

	# Mandíbula inferior articulada con dientes inferiores
	_jaw_pivot = Node3D.new()
	_jaw_pivot.position = Vector3(0.0, -0.04, -0.45)
	_visual.add_child(_jaw_pivot)
	_add_box(_jaw_pivot, Vector3(0.46, 0.16, 0.78), Vector3(0.0, -0.06, -0.36), mat_skin)

	for i in 4:
		var z_b: float = -0.16 - float(i) * 0.17
		_add_prism(_jaw_pivot, Vector3(0.055, 0.15, 0.055), Vector3(-0.15, 0.08, z_b), mat_tooth)
		_add_prism(_jaw_pivot, Vector3(0.055, 0.15, 0.055), Vector3(0.15, 0.08, z_b), mat_tooth)

	# Cola articulada
	_tail_pivot = Node3D.new()
	_tail_pivot.position = Vector3(0.0, 0.04, 0.72)
	_visual.add_child(_tail_pivot)
	_add_box(_tail_pivot, Vector3(0.24, 0.32, 0.55), Vector3(0.0, 0.0, 0.25), mat_skin)
	_add_prism(_tail_pivot, Vector3(0.07, 0.78, 0.52), Vector3(0.0, 0.05, 0.65), mat_skin, Vector3(-90.0, 0.0, 0.0))


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	if rot_deg != Vector3.ZERO:
		mi.rotation_degrees = rot_deg
	parent.add_child(mi)


func _add_prism(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	if rot_deg != Vector3.ZERO:
		mi.rotation_degrees = rot_deg
	parent.add_child(mi)


# ------------------------------------------------------------------ Efecto Explosión de Vóxeles Rojos

class _VoxelExplosionEffect extends Node3D:
	var _voxels: Array[Dictionary] = []
	var _mat: StandardMaterial3D
	var _lifetime: float = 1.25
	var _elapsed: float = 0.0

	func _ready() -> void:
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color(0.88, 0.06, 0.06)
		_mat.emission_enabled = true
		_mat.emission = Color(0.75, 0.04, 0.04)
		_mat.emission_energy_multiplier = 0.9
		_mat.roughness = 0.4

		var rng := RandomNumberGenerator.new()
		rng.randomize()

		for i in 28:
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			var s: float = rng.randf_range(0.12, 0.26)
			box.size = Vector3(s, s, s)
			mi.mesh = box
			mi.material_override = _mat
			add_child(mi)

			var angle: float = rng.randf_range(0.0, TAU)
			var horiz_speed: float = rng.randf_range(2.2, 7.5)
			var vel := Vector3(
				cos(angle) * horiz_speed,
				rng.randf_range(3.5, 8.5),
				sin(angle) * horiz_speed
			)
			var rot_vel := Vector3(
				rng.randf_range(-10.0, 10.0),
				rng.randf_range(-10.0, 10.0),
				rng.randf_range(-10.0, 10.0)
			)
			_voxels.append({"node": mi, "vel": vel, "rot": rot_vel, "base_scale": 1.0})

	func _process(delta: float) -> void:
		_elapsed += delta
		if _elapsed >= _lifetime:
			queue_free()
			return

		var t: float = _elapsed / _lifetime
		var scale_factor: float = clampf(1.0 - pow(t, 1.8), 0.01, 1.0)

		for v: Dictionary in _voxels:
			var node: MeshInstance3D = v["node"]
			var vel: Vector3 = v["vel"]
			var rot_vel: Vector3 = v["rot"]

			vel.y -= 16.0 * delta
			v["vel"] = vel
			node.position += vel * delta
			node.rotation += rot_vel * delta
			node.scale = Vector3.ONE * scale_factor
