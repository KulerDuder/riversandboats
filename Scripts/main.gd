extends Node3D
## Escena principal. Adjunta este script al nodo raíz (Node3D).
## Añade como hijo un nodo TerrainGenerator (si no lo hay, se crea uno).

const MinimapScript := preload("res://Scripts/minimap.gd")
const InventoryUIScript := preload("res://Scripts/inventory_ui.gd")
const MissionUIScript := preload("res://Scripts/mission_ui.gd")
const DayNightCycleScript := preload("res://Scripts/day_night_cycle.gd")
const WeatherSystemScript := preload("res://Scripts/weather_system.gd")

var atmosphere: WorldAtmosphere
var boat: Boat
var camera: CameraRig
var terrain: TerrainGenerator
var minimap: Minimap
var inventory_ui: InventoryUI
var mission_ui: MissionUI
var day_night: DayNightCycle
var weather: WeatherSystem

@export_group("Cámara")
@export var cam_distance: float = 9.0
@export var cam_height: float = 4.5
@export var cam_smooth: float = 4.0

@export_group("Ciclo Día y Noche")
@export var day_duration_seconds: float = 180.0
@export_range(0.0, 24.0, 0.1) var start_hour: float = 8.5

var _active_building: MississippiBuilding = null


func _ready() -> void:
	atmosphere = WorldAtmosphere.new()
	atmosphere.name = "WorldAtmosphere"
	add_child(atmosphere)

	terrain = _find_or_create_terrain()

	boat = Boat.new()
	boat.name = "Boat"
	boat.terrain = terrain
	add_child(boat)
	boat.global_position = terrain.get_spawn_position()
	boat.rotation.y = terrain.get_spawn_yaw()

	camera = CameraRig.new()
	camera.name = "CameraRig"
	camera.cam_distance = cam_distance
	camera.cam_height = cam_height
	camera.cam_smooth = cam_smooth
	camera.target = boat
	add_child(camera)

	minimap = MinimapScript.new()
	minimap.name = "Minimap"
	minimap.setup(boat, terrain)
	add_child(minimap)

	inventory_ui = InventoryUIScript.new()
	inventory_ui.name = "InventoryUI"
	add_child(inventory_ui)

	mission_ui = MissionUIScript.new()
	mission_ui.name = "MissionUI"
	add_child(mission_ui)

	weather = WeatherSystemScript.new()
	weather.name = "WeatherSystem"
	add_child(weather)
	weather.weather_changed.connect(inventory_ui.update_weather)
	weather.setup(atmosphere.env, atmosphere.sun, atmosphere.sky_mat, boat)

	day_night = DayNightCycleScript.new()
	day_night.name = "DayNightCycle"
	day_night.day_duration_seconds = day_duration_seconds
	day_night.start_hour = start_hour
	add_child(day_night)
	day_night.time_updated.connect(inventory_ui.update_clock)
	day_night.setup(atmosphere.sun, atmosphere.env, atmosphere.sky_mat, boat.get_bow_lamp(), weather)

	atmosphere.terrain = terrain
	atmosphere.boat = boat
	atmosphere.weather = weather

	_connect_gameplay_signals()
	_sync_initial_ui()
	_bind_world_entities()


func _connect_gameplay_signals() -> void:
	boat.fuel_changed.connect(inventory_ui.update_fuel)
	boat.fuel_depleted.connect(_on_boat_fuel_depleted)
	boat.cargo.inventory_changed.connect(inventory_ui.update_inventory)
	boat.cargo.inventory_changed.connect(_on_boat_inventory_changed)
	boat.cargo.gold_changed.connect(inventory_ui.update_gold)
	boat.cargo.gold_changed.connect(_on_boat_gold_changed)
	boat.cargo.item_opened.connect(inventory_ui.show_item_opened_feedback)
	boat.cargo.fuel_used.connect(inventory_ui.show_fuel_used_feedback)
	boat.cargo.package_delivered.connect(inventory_ui.show_package_delivered_feedback)

	boat.progression.xp_gained.connect(inventory_ui.show_xp_gained_feedback)
	boat.progression.leveled_up.connect(inventory_ui.show_level_up_feedback)

	inventory_ui.slot_right_clicked.connect(boat.cargo.open_item_at)
	mission_ui.mission_accepted.connect(_on_mission_accepted)
	mission_ui.deliver_requested.connect(_on_deliver_requested)
	mission_ui.buy_fuel_requested.connect(_on_buy_fuel_requested)


func _sync_initial_ui() -> void:
	inventory_ui.update_inventory(boat.cargo.items, boat.cargo.capacity)
	inventory_ui.update_gold(boat.cargo.gold)
	inventory_ui.update_fuel(boat.fuel, boat.max_fuel)
	inventory_ui.update_progression(boat.progression.level, boat.progression.current_xp, boat.progression.xp_to_next_level)


func _on_boat_fuel_depleted() -> void:
	if not is_instance_valid(boat) or not is_instance_valid(terrain):
		return

	boat.global_position = terrain.get_spawn_position()
	boat.rotation.y = terrain.get_spawn_yaw()
	boat.speed = 0.0
	boat.refill_fuel()
	boat.cargo.reset_gold()

	_active_building = null
	if is_instance_valid(mission_ui):
		mission_ui.close_menu()
	if is_instance_valid(inventory_ui):
		inventory_ui.set_current_town("")
		inventory_ui.show_emergency_alert(
			"Te has quedado sin combustible. Unos malvados marineros te han robado el oro.",
			5.5
		)
	camera.snap_to_target()


func _on_terrain_generated() -> void:
	if is_instance_valid(boat) and is_instance_valid(terrain):
		boat.global_position = terrain.get_spawn_position()
		boat.rotation.y = terrain.get_spawn_yaw()
		boat.speed = 0.0
		boat.refill_fuel()
		boat.cargo.clear()
		_active_building = null
		if is_instance_valid(inventory_ui):
			inventory_ui.set_current_town("")
		if is_instance_valid(mission_ui):
			mission_ui.close_menu()
		_bind_world_entities()
		camera.snap_to_target()


func _bind_world_entities() -> void:
	if not is_instance_valid(terrain) or not is_instance_valid(boat):
		return

	terrain.assign_boat_to_pickups(boat)
	terrain.assign_boat_to_mines(boat)
	terrain.assign_boat_to_horror_fish(boat)

	var mines_node: Node = terrain.get_node_or_null("Mines")
	if mines_node != null:
		for child: Node in mines_node.get_children():
			if child is NavalMine:
				var m: NavalMine = child as NavalMine
				if not m.detonated.is_connected(_on_mine_detonated):
					m.detonated.connect(_on_mine_detonated)

	var fish_node: Node = terrain.get_node_or_null("HorrorFish")
	if fish_node != null:
		for child: Node in fish_node.get_children():
			if child is RiverMonsterFish:
				var f: RiverMonsterFish = child as RiverMonsterFish
				if not f.bit_player.is_connected(_on_horror_fish_bit):
					f.bit_player.connect(_on_horror_fish_bit)

	var buildings_list: Array[MississippiBuilding] = []
	var buildings_node: Node = terrain.get_node_or_null("Buildings")
	if buildings_node != null:
		for child: Node in buildings_node.get_children():
			if child is MississippiBuilding:
				var b: MississippiBuilding = child as MississippiBuilding
				b.boat = boat
				buildings_list.append(b)
				if not b.player_entered_zone.is_connected(_on_building_zone_entered):
					b.player_entered_zone.connect(_on_building_zone_entered)
				if not b.player_exited_zone.is_connected(_on_building_zone_exited):
					b.player_exited_zone.connect(_on_building_zone_exited)

	if is_instance_valid(day_night):
		day_night.set_buildings(buildings_list)


func _on_mine_detonated(fuel_lost: float) -> void:
	if is_instance_valid(boat) and boat.fuel > 0.0 and is_instance_valid(inventory_ui):
		inventory_ui.show_emergency_alert(
			"💥 ¡Has chocado con una mina marina! (-%.0f%% combustible)" % fuel_lost,
			3.0
		)


func _on_horror_fish_bit(fuel_lost: float) -> void:
	if is_instance_valid(boat) and boat.fuel > 0.0 and is_instance_valid(inventory_ui):
		inventory_ui.show_emergency_alert(
			"🦷 ¡Un pez monstruoso ha mordido el casco! (-%.0f%% combustible)" % fuel_lost,
			3.0
		)


func _on_building_zone_entered(building: MississippiBuilding) -> void:
	_active_building = building
	if is_instance_valid(inventory_ui):
		inventory_ui.set_current_town(building.town_name)
	if is_instance_valid(mission_ui) and is_instance_valid(boat):
		var pending: int = boat.cargo.count_packages_for_town(building.town_name)
		mission_ui.open_for_building(building, pending, boat.cargo.is_full(), boat.cargo.gold)


func _on_building_zone_exited(building: MississippiBuilding) -> void:
	if _active_building == building:
		_active_building = null
		if is_instance_valid(inventory_ui):
			inventory_ui.set_current_town("")
		if is_instance_valid(mission_ui):
			mission_ui.close_menu()


func _on_mission_accepted(mission: Dictionary) -> void:
	if _active_building == null or not is_instance_valid(boat):
		return
	if boat.cargo.accept_mission(mission):
		_active_building.remove_mission(mission)
		_refresh_active_mission_ui()


func _on_deliver_requested(building: MississippiBuilding) -> void:
	if building == null or not is_instance_valid(boat):
		return
	boat.cargo.deliver_packages_to_town(building.town_name)
	_refresh_active_mission_ui()


func _on_buy_fuel_requested() -> void:
	if _active_building == null or not is_instance_valid(boat):
		return
	if boat.cargo.buy_fuel_can():
		_refresh_active_mission_ui()


func _on_boat_inventory_changed(_items: Array[Dictionary], _capacity: int) -> void:
	_refresh_active_mission_ui()


func _on_boat_gold_changed(_new_amount: int) -> void:
	_refresh_active_mission_ui()


func _refresh_active_mission_ui() -> void:
	if _active_building != null and is_instance_valid(mission_ui) and is_instance_valid(boat):
		var pending: int = boat.cargo.count_packages_for_town(_active_building.town_name)
		mission_ui.refresh_content(pending, boat.cargo.is_full(), boat.cargo.gold)


func _find_or_create_terrain() -> TerrainGenerator:
	for child in get_children():
		if child is TerrainGenerator:
			child.terrain_generated.connect(_on_terrain_generated)
			return child
	var t := TerrainGenerator.new()
	t.name = "Terrain"
	t.terrain_generated.connect(_on_terrain_generated)
	add_child(t)
	return t
