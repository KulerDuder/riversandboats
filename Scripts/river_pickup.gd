class_name RiverPickup
extends Node3D
## Clase base para cualquier objeto flotante recogible en el río.
## Hereda de esta clase para crear barriles, cajas, bidones, botellas, etc.

@export var item_id: StringName = &"pickup"
@export var item_name: String = "Objeto flotante"
@export var pickup_radius: float = 2.6
@export var icon_color: Color = Color(0.75, 0.75, 0.75)

var boat: Boat
var _visual: Node3D
var _bob_offset: float = 0.0
var _time: float = 0.0
var _collected: bool = false


func _ready() -> void:
	_bob_offset = randf() * TAU
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_build_visual(_visual)


func _process(delta: float) -> void:
	if _collected:
		return

	_time += delta
	# Balanceo suave sobre el agua
	if _visual != null:
		_visual.position.y = sin(_time * 2.2 + _bob_offset) * 0.08
		_visual.rotation.z = sin(_time * 1.5 + _bob_offset) * 0.14
		_visual.rotation.x = cos(_time * 1.3 + _bob_offset) * 0.12
		_visual.rotation.y += 0.25 * delta

	# Detección de recogida por proximidad plana (XZ)
	if is_instance_valid(boat):
		var dx: float = boat.global_position.x - global_position.x
		var dz: float = boat.global_position.z - global_position.z
		if (dx * dx + dz * dz) <= pickup_radius * pickup_radius:
			_try_collect()


func _try_collect() -> void:
	if boat.cargo.try_collect_item(get_item_data()):
		_collected = true
		queue_free()


## Devuelve los datos estructurados del objeto para el inventario.
func get_item_data() -> Dictionary:
	return {
		"id": item_id,
		"name": item_name,
		"color": icon_color,
	}


## Sobrescribe este método en cada subclase para construir su malla 3D procedural.
func _build_visual(_parent: Node3D) -> void:
	pass
