class_name NavalMine
extends Node3D
## Mina marina estilo dibujos animados (esfera negra con pinchos).
## Explota al entrar en contacto con el barco y resta un buen trozo de combustible.

signal detonated(fuel_lost: float)

@export var trigger_radius: float = 2.4
@export var fuel_damage: float = 25.0

var boat: Boat

var _visual: Node3D
var _bob_offset: float = 0.0
var _time: float = 0.0
var _exploded: bool = false


func _ready() -> void:
	_bob_offset = randf() * TAU
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_build_visual(_visual)


func _process(delta: float) -> void:
	if _exploded:
		return

	_time += delta
	# Balanceo pesado y lento en el agua
	if _visual != null:
		_visual.position.y = sin(_time * 1.7 + _bob_offset) * 0.06
		_visual.rotation.z = sin(_time * 1.1 + _bob_offset) * 0.09
		_visual.rotation.x = cos(_time * 0.9 + _bob_offset) * 0.08
		_visual.rotation.y += 0.12 * delta

	if is_instance_valid(boat):
		var dx: float = boat.global_position.x - global_position.x
		var dz: float = boat.global_position.z - global_position.z
		if (dx * dx + dz * dz) <= trigger_radius * trigger_radius:
			_trigger_explosion()


func _trigger_explosion() -> void:
	_exploded = true
	if _visual != null:
		_visual.visible = false

	detonated.emit(fuel_damage)
	if is_instance_valid(boat):
		boat.consume_fuel(fuel_damage)

	_spawn_explosion_vfx()


func _spawn_explosion_vfx() -> void:
	# Bola de fuego + onda expansiva que crecen y desaparecen antes de liberar el nodo
	var fire := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	fire.mesh = sphere

	var fire_mat := StandardMaterial3D.new()
	fire_mat.albedo_color = Color(1.0, 0.45, 0.08, 0.95)
	fire_mat.emission_enabled = true
	fire_mat.emission = Color(1.0, 0.35, 0.05)
	fire_mat.emission_energy_multiplier = 3.0
	fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire.material_override = fire_mat
	fire.position.y = 0.4
	add_child(fire)

	var smoke := MeshInstance3D.new()
	var smoke_sphere := SphereMesh.new()
	smoke_sphere.radius = 0.8
	smoke_sphere.height = 1.6
	smoke.mesh = smoke_sphere

	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.albedo_color = Color(0.15, 0.15, 0.17, 0.85)
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.material_override = smoke_mat
	smoke.position.y = 0.7
	add_child(smoke)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fire, "scale", Vector3.ONE * 4.2, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(fire_mat, "albedo_color:a", 0.0, 0.35)
	tween.tween_property(smoke, "scale", Vector3.ONE * 5.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(smoke, "position:y", 2.4, 0.55)
	tween.tween_property(smoke_mat, "albedo_color:a", 0.0, 0.55)
	tween.chain().tween_callback(queue_free)


func _build_visual(parent: Node3D) -> void:
	var mat_iron := StandardMaterial3D.new()
	mat_iron.albedo_color = Color(0.11, 0.12, 0.14)
	mat_iron.metallic = 0.75
	mat_iron.roughness = 0.45

	var mat_spike := StandardMaterial3D.new()
	mat_spike.albedo_color = Color(0.24, 0.25, 0.28)
	mat_spike.metallic = 0.85
	mat_spike.roughness = 0.35

	var mat_tip := StandardMaterial3D.new()
	mat_tip.albedo_color = Color(0.85, 0.18, 0.14)
	mat_tip.emission_enabled = true
	mat_tip.emission = Color(0.75, 0.12, 0.08)
	mat_tip.emission_energy_multiplier = 0.8

	# Esfera principal semisumergida
	var radius: float = 0.72
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 20
	sphere.rings = 12
	body.mesh = sphere
	body.material_override = mat_iron
	body.position.y = 0.18
	parent.add_child(body)

	# Anillo ecuatorial remachado estilo caricatura
	var band := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius + 0.03
	cyl.bottom_radius = radius + 0.03
	cyl.height = 0.12
	band.mesh = cyl
	band.material_override = mat_spike
	body.add_child(band)

	# Pinchos / espoletas radiales en la mitad superior y ecuador
	var spike_dirs: Array[Vector3] = [
		Vector3.UP,
		# Anillo superior inclinado (5 pinchos)
		Vector3(0.0, 0.72, 0.69).normalized(),
		Vector3(0.66, 0.72, 0.21).normalized(),
		Vector3(0.41, 0.72, -0.56).normalized(),
		Vector3(-0.41, 0.72, -0.56).normalized(),
		Vector3(-0.66, 0.72, 0.21).normalized(),
		# Anillo ecuatorial (8 pinchos)
		Vector3(1.0, 0.08, 0.0).normalized(),
		Vector3(0.71, 0.08, 0.71).normalized(),
		Vector3(0.0, 0.08, 1.0).normalized(),
		Vector3(-0.71, 0.08, 0.71).normalized(),
		Vector3(-1.0, 0.08, 0.0).normalized(),
		Vector3(-0.71, 0.08, -0.71).normalized(),
		Vector3(0.0, 0.08, -1.0).normalized(),
		Vector3(0.71, 0.08, -0.71).normalized(),
	]

	var spike_len: float = 0.36
	for dir: Vector3 in spike_dirs:
		var spike_holder := Node3D.new()
		spike_holder.position = dir * radius
		# Orientar el eje +Y local hacia `dir`
		var up_ref := Vector3.FORWARD if absf(dir.y) > 0.95 else Vector3.UP
		spike_holder.basis = Basis.looking_at(-dir, up_ref)
		spike_holder.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		body.add_child(spike_holder)

		# Palito / cuello del pincho
		var rod := MeshInstance3D.new()
		var rod_mesh := CylinderMesh.new()
		rod_mesh.top_radius = 0.045
		rod_mesh.bottom_radius = 0.065
		rod_mesh.height = spike_len
		rod.mesh = rod_mesh
		rod.material_override = mat_spike
		rod.position.y = spike_len * 0.5
		spike_holder.add_child(rod)

		# Punta roja de detonación en el extremo del palito
		var tip := MeshInstance3D.new()
		var tip_mesh := SphereMesh.new()
		tip_mesh.radius = 0.065
		tip_mesh.height = 0.13
		tip.mesh = tip_mesh
		tip.material_override = mat_tip
		tip.position.y = spike_len
		spike_holder.add_child(tip)
