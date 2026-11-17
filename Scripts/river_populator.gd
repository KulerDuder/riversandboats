class_name RiverPopulator
extends RefCounted
## Distribuye proceduralmente edificios ribereños, barriles, minas marinas
## y peces depredadores a lo largo de la red de ríos.

const TOWN_NAMES: Array[String] = [
	"Nouvelle-Orléans",
	"Bâton-Rouge",
	"Bayou Lafourche",
	"Saint-Martinville",
	"Pointe Coupée",
	"Fort Maurepas",
	"Isle aux Chênes",
	"Terrebonne",
	"Natchitoches",
	"Bayou Plaquemine",
	"Port Hudson",
	"Belle Chasse",
	"Vieux Bayou",
	"Chêne Blanc",
	"Grand Isle",
	"Côte Joyeuse",
	"Bayou Teche",
	"Saint-Charles",
	"Pontchartrain",
	"Calcasieu",
]


static func populate_buildings(parent: Node3D, terrain: TerrainGenerator, count: int, seed_val: int) -> void:
	for child: Node in parent.get_children():
		child.queue_free()

	if count <= 0:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var world_size: float = terrain.get_world_size()
	var half: float = world_size * 0.5
	var margin: float = float(terrain.border_cells + 4) * terrain.cell_size
	var min_coord: float = -half + margin
	var max_coord: float = half - margin

	if min_coord >= max_coord:
		return

	var placed_positions: Array[Vector3] = []
	var created_buildings: Array[MississippiBuilding] = []
	var min_dist: float = 28.0
	var attempts: int = count * 80

	var available_names: Array[String] = TOWN_NAMES.duplicate()
	for i: int in available_names.size():
		var swap_idx: int = rng.randi_range(i, available_names.size() - 1)
		var tmp: String = available_names[i]
		available_names[i] = available_names[swap_idx]
		available_names[swap_idx] = tmp

	for _attempt: int in attempts:
		if created_buildings.size() >= count:
			break

		var lx: float = rng.randf_range(min_coord, max_coord)
		var lz: float = rng.randf_range(min_coord, max_coord)

		var sd: float = terrain.sample_sd(lx, lz)
		if sd < 0.25 or sd > 2.2:
			continue

		var h: float = terrain.sample_height(lx, lz)
		if h < 0.05 or h > 2.6:
			continue

		var too_close: bool = false
		var candidate_pos := Vector3(lx, 0.0, lz)
		for p: Vector3 in placed_positions:
			if p.distance_squared_to(candidate_pos) < min_dist * min_dist:
				too_close = true
				break
		if too_close:
			continue

		var grad_x: float = terrain.sample_sd(lx + 1.5, lz) - terrain.sample_sd(lx - 1.5, lz)
		var grad_z: float = terrain.sample_sd(lx, lz + 1.5) - terrain.sample_sd(lx, lz - 1.5)
		var to_water := Vector2(-grad_x, -grad_z)
		if to_water.length_squared() < 0.0001:
			continue
		to_water = to_water.normalized()

		var building := MississippiBuilding.new()
		building.name = "MississippiBuilding_%d" % created_buildings.size()
		building.building_type = rng.randi() % 4
		building.building_seed = rng.randi()
		building.town_name = _pick_town_name(available_names, created_buildings.size())
		parent.add_child(building)

		var water_edge_x: float = lx + to_water.x * sd
		var water_edge_z: float = lz + to_water.y * sd

		building.position = Vector3(water_edge_x, 0.0, water_edge_z)
		building.rotation.y = atan2(-to_water.x, -to_water.y)

		placed_positions.append(candidate_pos)
		created_buildings.append(building)

	for b: MississippiBuilding in created_buildings:
		b.generate_missions(created_buildings, rng)


static func populate_pickups(parent: Node3D, terrain: TerrainGenerator, count: int, seed_val: int) -> void:
	for child: Node in parent.get_children():
		child.queue_free()

	if count <= 0:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var world_size: float = terrain.get_world_size()
	var half: float = world_size * 0.5
	var margin: float = float(terrain.border_cells + 3) * terrain.cell_size
	var min_coord: float = -half + margin
	var max_coord: float = half - margin

	if min_coord >= max_coord:
		return

	var placed_positions: Array[Vector3] = []
	var spawn_pos: Vector3 = terrain.get_spawn_position()
	var min_dist: float = 14.0
	var attempts: int = count * 60

	for _attempt: int in attempts:
		if placed_positions.size() >= count:
			break

		var lx: float = rng.randf_range(min_coord, max_coord)
		var lz: float = rng.randf_range(min_coord, max_coord)

		var sd: float = terrain.sample_sd(lx, lz)
		if sd > -1.2:
			continue

		var candidate_world: Vector3 = terrain.to_global(Vector3(lx, 0.0, lz))
		if candidate_world.distance_squared_to(spawn_pos) < 12.0 * 12.0:
			continue

		var too_close: bool = false
		for p: Vector3 in placed_positions:
			if p.distance_squared_to(candidate_world) < min_dist * min_dist:
				too_close = true
				break
		if too_close:
			continue

		var barrel := RiverPickup.new()
		barrel.name = "RiverBarrel_%d" % placed_positions.size()
		parent.add_child(barrel)
		barrel.global_position = candidate_world
		barrel.rotation.y = rng.randf_range(0.0, TAU)

		placed_positions.append(candidate_world)


static func populate_mines(parent: Node3D, terrain: TerrainGenerator, count: int, seed_val: int) -> void:
	for child: Node in parent.get_children():
		child.queue_free()

	if count <= 0:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var world_size: float = terrain.get_world_size()
	var half: float = world_size * 0.5
	var margin: float = float(terrain.border_cells + 3) * terrain.cell_size
	var min_coord: float = -half + margin
	var max_coord: float = half - margin

	if min_coord >= max_coord:
		return

	var placed_positions: Array[Vector3] = []
	var spawn_pos: Vector3 = terrain.get_spawn_position()
	var building_positions: Array[Vector3] = terrain.get_building_positions()
	var min_dist: float = 22.0
	var attempts: int = count * 60

	for _attempt: int in attempts:
		if placed_positions.size() >= count:
			break

		var lx: float = rng.randf_range(min_coord, max_coord)
		var lz: float = rng.randf_range(min_coord, max_coord)

		var sd: float = terrain.sample_sd(lx, lz)
		if sd > -1.4:
			continue

		var candidate_world: Vector3 = terrain.to_global(Vector3(lx, 0.0, lz))
		if candidate_world.distance_squared_to(spawn_pos) < 20.0 * 20.0:
			continue

		var near_dock: bool = false
		for b_pos: Vector3 in building_positions:
			if b_pos.distance_squared_to(candidate_world) < 16.0 * 16.0:
				near_dock = true
				break
		if near_dock:
			continue

		var too_close: bool = false
		for p: Vector3 in placed_positions:
			if p.distance_squared_to(candidate_world) < min_dist * min_dist:
				too_close = true
				break
		if too_close:
			continue

		var mine := NavalMine.new()
		mine.name = "NavalMine_%d" % placed_positions.size()
		parent.add_child(mine)
		mine.global_position = candidate_world
		mine.rotation.y = rng.randf_range(0.0, TAU)

		placed_positions.append(candidate_world)


static func populate_horror_fish(parent: Node3D, terrain: TerrainGenerator, count_val: Variant, seed_val: int) -> void:
	for child: Node in parent.get_children():
		child.queue_free()

	var count: int = int(count_val) if count_val != null else 14
	if count <= 0:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var world_size: float = terrain.get_world_size()
	var half: float = world_size * 0.5
	var margin: float = float(terrain.border_cells + 3) * terrain.cell_size
	var min_coord: float = -half + margin
	var max_coord: float = half - margin

	if min_coord >= max_coord:
		return

	var placed_positions: Array[Vector3] = []
	var spawn_pos: Vector3 = terrain.get_spawn_position()
	var min_dist: float = 18.0
	var attempts: int = count * 60

	for _attempt: int in attempts:
		if placed_positions.size() >= count:
			break

		var lx: float = rng.randf_range(min_coord, max_coord)
		var lz: float = rng.randf_range(min_coord, max_coord)

		var sd: float = terrain.sample_sd(lx, lz)
		if sd > -1.35:
			continue

		var candidate_world: Vector3 = terrain.to_global(Vector3(lx, 0.0, lz))
		if candidate_world.distance_squared_to(spawn_pos) < 18.0 * 18.0:
			continue

		var too_close: bool = false
		for p: Vector3 in placed_positions:
			if p.distance_squared_to(candidate_world) < min_dist * min_dist:
				too_close = true
				break
		if too_close:
			continue

		var fish := RiverMonsterFish.new()
		fish.name = "RiverMonsterFish_%d" % placed_positions.size()
		fish.terrain = terrain
		fish.swim_speed = rng.randf_range(3.2, 5.2)
		parent.add_child(fish)
		fish.global_position = candidate_world
		fish.rotation.y = rng.randf_range(0.0, TAU)

		placed_positions.append(candidate_world)


static func _pick_town_name(shuffled_names: Array[String], index: int) -> String:
	if index < shuffled_names.size():
		return shuffled_names[index]
	var base: String = shuffled_names[index % shuffled_names.size()]
	var suffix_num: int = (index / shuffled_names.size()) + 1
	return "%s %d" % [base, suffix_num]
