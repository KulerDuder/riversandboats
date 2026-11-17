class_name BoatCargo
extends RefCounted
## Gestiona el inventario de carga del barco, el oro, la apertura de barriles,
## el consumo de bidones de combustible y la entrega de paquetes de misión.

signal inventory_changed(items: Array[Dictionary], capacity: int)
signal gold_changed(new_amount: int)
signal item_opened(item_name: String, gold_gained: int)
signal fuel_used(item_name: String, fuel_restored: float)
signal package_delivered(package_name: String, target_town: String, gold_gained: int, xp_gained: int)

const FUEL_CAN_PRICE: int = 8
const FUEL_CAN_RESTORE: float = 45.0

var capacity: int = 8
var items: Array[Dictionary] = []
var gold: int = 0
var _progression: PlayerProgression


func _init(initial_capacity: int = 8, p_progression: PlayerProgression = null) -> void:
	capacity = initial_capacity
	_progression = p_progression


func is_full() -> bool:
	return items.size() >= capacity


func clear() -> void:
	items.clear()
	inventory_changed.emit(items, capacity)


func reset_gold() -> void:
	gold = 0
	gold_changed.emit(gold)


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)


# ------------------------------------------------------------------ Añadir objetos

func try_collect_item(raw_item: Variant = null) -> bool:
	if is_full():
		return false

	var item_dict: Dictionary
	if raw_item is Dictionary and not raw_item.is_empty():
		item_dict = raw_item.duplicate()
		if not item_dict.has("name"):
			item_dict["name"] = "Barril de río"
		if not item_dict.has("type"):
			item_dict["type"] = "barrel"
		if not item_dict.has("openable"):
			item_dict["openable"] = true
	else:
		item_dict = {
			"name": "Barril de río",
			"type": "barrel",
			"openable": true,
			"description": "Clic derecho para abrir (0-10 oro)",
		}

	var added: bool = add_item(item_dict)
	if added and is_instance_valid(_progression) and _progression.has_method("add_xp"):
		_progression.add_xp(randi_range(1, 5), "Barril recogido")
	return added


func add_item(item: Dictionary) -> bool:
	if is_full():
		return false
	items.append(item)
	inventory_changed.emit(items, capacity)
	return true


func add_barrel() -> bool:
	return add_item({
		"name": "Barril de río",
		"type": "barrel",
		"openable": true,
		"description": "Clic derecho para abrir (0-10 oro)",
	})


func add_fuel_can() -> bool:
	return add_item({
		"name": "Bidón de combustible",
		"type": "fuel",
		"openable": true,
		"restore": FUEL_CAN_RESTORE,
		"description": "Clic derecho para repostar (+%.0f%%)" % FUEL_CAN_RESTORE,
	})


func buy_fuel_can() -> bool:
	if gold < FUEL_CAN_PRICE or is_full():
		return false
	gold -= FUEL_CAN_PRICE
	gold_changed.emit(gold)
	return add_fuel_can()


# ------------------------------------------------------------------ Uso con clic derecho

func open_item_at(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= items.size():
		return

	var item: Dictionary = items[slot_index]
	var item_type: String = str(item.get("type", ""))
	var item_name: String = str(item.get("name", ""))

	if item_type == "barrel" or item_name == "Barril de río":
		items.remove_at(slot_index)
		var gold_found: int = randi_range(0, 10)
		var xp_found: int = randi_range(1, 5)
		if gold_found > 0:
			gold += gold_found
			gold_changed.emit(gold)
		if is_instance_valid(_progression) and _progression.has_method("add_xp"):
			_progression.add_xp(xp_found, "Barril abierto")
		item_opened.emit(item_name, gold_found)
		inventory_changed.emit(items, capacity)

	elif item_type == "fuel" or item_name == "Bidón de combustible":
		items.remove_at(slot_index)
		var restored: float = float(item.get("restore", FUEL_CAN_RESTORE))
		fuel_used.emit(item_name, restored)
		inventory_changed.emit(items, capacity)


# ------------------------------------------------------------------ Misiones y Paquetes

func accept_mission(mission: Dictionary) -> bool:
	if is_full():
		return false

	var pkg_name: String = str(mission.get("package_name", "Paquete de encargo"))
	var target_town: String = str(mission.get("target_town", ""))
	var target_pos: Vector3 = mission.get("target_pos", Vector3.ZERO)
	var dist: float = float(mission.get("distance", 0.0))

	return add_item({
		"name": pkg_name,
		"type": "package",
		"openable": false,
		"mission_id": str(mission.get("mission_id", "")),
		"origin_town": str(mission.get("origin_town", "")),
		"target_town": target_town,
		"target_pos": target_pos,
		"distance": dist,
		"description": "Entregar en %s" % target_town,
	})


func count_packages_for_town(town_name: String) -> int:
	var count: int = 0
	for item: Dictionary in items:
		if str(item.get("type", "")) == "package" and str(item.get("target_town", "")) == town_name:
			count += 1
	return count


func get_active_mission_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for item: Dictionary in items:
		if str(item.get("type", "")) == "package":
			var t_town: String = str(item.get("target_town", ""))
			var t_pos: Vector3 = item.get("target_pos", Vector3.ZERO)
			targets.append({
				"town_name": t_town,
				"target_town": t_town,
				"position": t_pos,
				"target_pos": t_pos,
				"package_name": str(item.get("name", "Paquete")),
			})
	return targets


func get_active_package_destinations() -> Array[Dictionary]:
	return get_active_mission_targets()


func deliver_packages_to_town(town_name: String) -> int:
	var delivered_count: int = 0
	for i: int in range(items.size() - 1, -1, -1):
		var item: Dictionary = items[i]
		if str(item.get("type", "")) == "package" and str(item.get("target_town", "")) == town_name:
			var pkg_name: String = str(item.get("name", "Paquete"))
			items.remove_at(i)

			var reward_gold: int = randi_range(0, 10)
			var reward_xp: int = randi_range(1, 5)

			if reward_gold > 0:
				gold += reward_gold
				gold_changed.emit(gold)
			if is_instance_valid(_progression) and _progression.has_method("add_xp"):
				_progression.add_xp(reward_xp, "Entrega en %s" % town_name)

			package_delivered.emit(pkg_name, town_name, reward_gold, reward_xp)
			delivered_count += 1

	if delivered_count > 0:
		inventory_changed.emit(items, capacity)

	return delivered_count
