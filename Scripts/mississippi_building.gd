class_name MississippiBuilding
extends Node3D
## Edificio fluvial procedural ambientado en el río Mississippi / bayou.
## Gestiona su zona de influencia, faroles dinámicos y los encargos procedurales de transporte.

signal player_entered_zone(building: MississippiBuilding)
signal player_exited_zone(building: MississippiBuilding)

const PACKAGE_TYPES: Array[String] = [
	"Cajón de especias criollas",
	"Saco de café de Nueva Orleans",
	"Correo urgente del Mississippi",
	"Caja de repuestos de vapor",
	"Fardo de algodón del delta",
	"Barrilillo de melaza dulce",
	"Instrumental de navegación",
	"Medicinas para el bayou",
]

@export var building_type: int = 0
@export var building_seed: int = 0
@export var town_name: String = "Nouvelle-Orléans"
@export var influence_radius: float = 15.0

var boat: Boat
var available_missions: Array[Dictionary] = []

var _visual: Node3D
var _ring: WaterRingIndicator
var _player_inside: bool = false
var _lights: Array[OmniLight3D] = []
var _emissive_mats: Array[StandardMaterial3D] = []
var _night_factor: float = 0.0
var _flicker_phase: float = 0.0


func _ready() -> void:
	_flicker_phase = randf() * TAU
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var built_data: Dictionary = MississippiBuildingBuilder.build(_visual, building_type, building_seed)
	_lights = built_data.get("lights", []) as Array[OmniLight3D]
	_emissive_mats = built_data.get("emissive_mats", []) as Array[StandardMaterial3D]

	_ring = WaterRingIndicator.new()
	_ring.name = "InfluenceRing"
	_ring.radius = influence_radius
	add_child(_ring)
	_apply_lighting_state(0.0)


func _process(delta: float) -> void:
	_flicker_phase += delta * 5.5

	if is_instance_valid(boat):
		var dx: float = boat.global_position.x - global_position.x
		var dz: float = boat.global_position.z - global_position.z
		var inside_now: bool = (dx * dx + dz * dz) <= (influence_radius * influence_radius)

		if inside_now and not _player_inside:
			_player_inside = true
			if _ring != null:
				_ring.is_highlighted = true
			player_entered_zone.emit(self)
		elif not inside_now and _player_inside:
			_player_inside = false
			if _ring != null:
				_ring.is_highlighted = false
			player_exited_zone.emit(self)

	_apply_lighting_state(_flicker_phase)


func set_night_lighting(factor: float) -> void:
	_night_factor = clampf(factor, 0.0, 1.0)


func _apply_lighting_state(phase: float) -> void:
	var dock_bonus: float = 0.25 if _player_inside else 0.0
	var effective: float = clampf(_night_factor + dock_bonus, 0.0, 1.15)
	var flicker: float = 1.0 + sin(phase) * 0.06 + cos(phase * 1.7) * 0.04

	var active: bool = effective > 0.03
	var energy: float = effective * 2.8 * flicker
	var emission_val: float = effective * 2.4 * flicker

	for light: OmniLight3D in _lights:
		if is_instance_valid(light):
			light.visible = active
			light.light_energy = energy

	for mat: StandardMaterial3D in _emissive_mats:
		if mat != null:
			mat.emission_energy_multiplier = emission_val


func is_player_inside() -> bool:
	return _player_inside


func generate_missions(all_buildings: Array[MississippiBuilding], rng: RandomNumberGenerator) -> void:
	available_missions.clear()
	var other_ports: Array[MississippiBuilding] = []
	for b: MississippiBuilding in all_buildings:
		if b != self:
			other_ports.append(b)

	if other_ports.is_empty():
		return

	for i: int in other_ports.size():
		var swap_idx: int = rng.randi_range(i, other_ports.size() - 1)
		var tmp: MississippiBuilding = other_ports[i]
		other_ports[i] = other_ports[swap_idx]
		other_ports[swap_idx] = tmp

	var mission_count: int = mini(rng.randi_range(2, 3), other_ports.size())
	for i: int in mission_count:
		var dest: MississippiBuilding = other_ports[i]
		var pkg_name: String = PACKAGE_TYPES[rng.randi() % PACKAGE_TYPES.size()]
		var dist: float = global_position.distance_to(dest.global_position)

		available_missions.append({
			"mission_id": "%s_%s_%d" % [town_name, dest.town_name, rng.randi()],
			"package_name": pkg_name,
			"origin_town": town_name,
			"target_town": dest.town_name,
			"target_pos": dest.global_position,
			"distance": dist,
		})


func remove_mission(mission: Dictionary) -> void:
	available_missions.erase(mission)
