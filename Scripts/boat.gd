class_name Boat
extends Node3D
## Barquito controlable con WASD. Se construye enteramente por código.

signal fuel_changed(current_fuel: float, max_fuel: float)
signal fuel_depleted

@export var max_speed := 12.0
@export var max_reverse := 4.0
@export var acceleration := 6.0
@export var water_drag := 1.5
@export var turn_speed := 1.6
@export var initial_cargo_slots := 8

@export var max_fuel := 100.0
@export var fuel_burn_rate := 1.8  # Unidades por segundo a máxima potencia

var speed := 0.0
var fuel := 100.0
var terrain: TerrainGenerator
var progression: PlayerProgression
var cargo: BoatCargo

const HULL_PROBES: Array[Vector3] = [
	Vector3(0.0, 0.0, -2.3),
	Vector3(0.6, 0.0, -1.4), Vector3(-0.6, 0.0, -1.4),
	Vector3(0.7, 0.0, 0.0), Vector3(-0.7, 0.0, 0.0),
	Vector3(0.6, 0.0, 1.1), Vector3(-0.6, 0.0, 1.1),
	Vector3(0.0, 0.0, 1.3),
]

var _visual: Node3D
var _bow_lamp: OmniLight3D
var _time := 0.0
var _roll := 0.0


func _init() -> void:
	progression = PlayerProgression.new()
	cargo = BoatCargo.new(initial_cargo_slots, progression)
	cargo.fuel_used.connect(_on_fuel_can_used)


func _ready() -> void:
	cargo.capacity = initial_cargo_slots
	fuel = max_fuel
	_setup_input()
	_build_boat()
	fuel_changed.emit(fuel, max_fuel)


func get_bow_lamp() -> OmniLight3D:
	return _bow_lamp


func _physics_process(delta: float) -> void:
	_time += delta

	var throttle := Input.get_axis("boat_back", "boat_forward")
	var steer := Input.get_axis("boat_right", "boat_left")

	if fuel > 0.0 and (throttle != 0.0 or absf(speed) > 0.2):
		var effort := maxf(absf(throttle), absf(speed) / max_speed * 0.45)
		consume_fuel(effort * fuel_burn_rate * delta)

	if throttle != 0.0:
		speed += throttle * acceleration * delta
	else:
		speed = move_toward(speed, 0.0, water_drag * delta)
	speed = clampf(speed, -max_reverse, max_speed)

	var steer_factor := clampf(speed / 4.0, -1.0, 1.0)

	var new_basis := global_basis.rotated(Vector3.UP, steer * turn_speed * steer_factor * delta).orthonormalized()
	if _hull_in_water(global_position, new_basis):
		global_basis = new_basis

	var motion := -global_basis.z * speed * delta
	if _hull_in_water(global_position + motion, global_basis):
		global_position += motion
	else:
		var moved := false
		for slide: Vector3 in [Vector3(motion.x, 0.0, 0.0), Vector3(0.0, 0.0, motion.z)]:
			if _hull_in_water(global_position + slide, global_basis):
				global_position += slide
				moved = true
				break
		speed = move_toward(speed, 0.0, (10.0 if moved else 40.0) * delta)

	_animate_visual(steer * steer_factor, delta)


func add_fuel(amount: float) -> void:
	fuel = clampf(fuel + amount, 0.0, max_fuel)
	fuel_changed.emit(fuel, max_fuel)


func consume_fuel(amount: float) -> void:
	if amount <= 0.0 or fuel <= 0.0:
		return
	fuel = maxf(0.0, fuel - amount)
	fuel_changed.emit(fuel, max_fuel)
	if fuel <= 0.0:
		fuel_depleted.emit()


func refill_fuel() -> void:
	fuel = max_fuel
	fuel_changed.emit(fuel, max_fuel)


func _on_fuel_can_used(_item_name: String, fuel_restored: float) -> void:
	add_fuel(fuel_restored)


func _hull_in_water(pos: Vector3, basis_: Basis) -> bool:
	if terrain == null:
		return true
	for p in HULL_PROBES:
		if not terrain.is_water_at(pos + basis_ * p):
			return false
	return true


func _animate_visual(steer_amount: float, delta: float) -> void:
	_roll = lerpf(_roll, -steer_amount * 0.25, 4.0 * delta)
	_visual.rotation.z = _roll + sin(_time * 1.3) * 0.03
	_visual.rotation.x = (speed / max_speed) * 0.06 + sin(_time * 1.1) * 0.02
	_visual.position.y = sin(_time * 1.6) * 0.08


# ---------------------------------------------------------------- Construcción

func _build_boat() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var wood := _mat(Color(0.55, 0.33, 0.16), 0.52)
	var white := _mat(Color(0.95, 0.95, 0.92), 0.32)
	var red := _mat(Color(0.8, 0.12, 0.1), 0.26)

	_add_box(Vector3(1.4, 0.5, 2.4), Vector3(0, 0.25, 0), wood)

	var bow := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(1.4, 1.2, 0.5)
	bow.mesh = prism
	bow.material_override = wood
	bow.rotation_degrees.x = -90.0
	bow.position = Vector3(0, 0.25, -1.8)
	_visual.add_child(bow)

	_add_box(Vector3(1.42, 0.08, 2.42), Vector3(0, 0.46, 0), red)
	_add_box(Vector3(0.9, 0.6, 0.9), Vector3(0, 0.8, 0.3), white)
	_add_box(Vector3(1.0, 0.06, 1.0), Vector3(0, 1.13, 0.3), red)
	_add_box(Vector3(0.06, 1.2, 0.06), Vector3(0, 1.7, -0.5), wood)
	_add_box(Vector3(0.45, 0.25, 0.02), Vector3(0.24, 2.15, -0.5), red)

	# Farol nocturno en la proa
	_bow_lamp = OmniLight3D.new()
	_bow_lamp.name = "BowLamp"
	_bow_lamp.position = Vector3(0.0, 1.15, -1.6)
	_bow_lamp.light_color = Color(1.0, 0.82, 0.48)
	_bow_lamp.light_energy = 0.0
	_bow_lamp.omni_range = 18.0
	_bow_lamp.omni_attenuation = 1.4
	_bow_lamp.visible = false
	_visual.add_child(_bow_lamp)


func _add_box(size: Vector3, pos: Vector3, material: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	_visual.add_child(mi)


func _mat(color: Color, roughness_val: float = 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness_val
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return m


# ---------------------------------------------------------------------- Input

func _setup_input() -> void:
	_add_key_action("boat_forward", KEY_W)
	_add_key_action("boat_back", KEY_S)
	_add_key_action("boat_left", KEY_A)
	_add_key_action("boat_right", KEY_D)


func _add_key_action(action: StringName, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)
