class_name BarrelPickup
extends RiverPickup
## Barril de suministros flotante en el río. Al abrirlo en la bodega otorga oro y XP.

const ITEM_ID: StringName = &"barrel"


func _init() -> void:
	item_id = ITEM_ID
	item_name = "Barril"
	icon_color = Color(0.68, 0.44, 0.20)


func _build_visual(parent: Node3D) -> void:
	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.45, 0.28, 0.15)
	mat_wood.roughness = 0.85

	var mat_iron := StandardMaterial3D.new()
	mat_iron.albedo_color = Color(0.18, 0.18, 0.20)
	mat_iron.metallic = 0.7
	mat_iron.roughness = 0.4

	# Cuerpo principal del barril (tumbado parcialmente en el agua)
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.42
	cyl.height = 1.15
	body.mesh = cyl
	body.material_override = mat_wood
	body.rotation_degrees = Vector3(15.0, 0.0, 75.0)
	body.position.y = 0.1
	parent.add_child(body)

	# Aros metálicos decorativos
	for offset: float in [-0.32, 0.32]:
		var hoop := MeshInstance3D.new()
		var hoop_mesh := CylinderMesh.new()
		hoop_mesh.top_radius = 0.435
		hoop_mesh.bottom_radius = 0.435
		hoop_mesh.height = 0.08
		hoop.mesh = hoop_mesh
		hoop.material_override = mat_iron
		hoop.position.y = offset
		body.add_child(hoop)


## Lógica al abrir el barril desde el inventario (clic derecho).
static func use_from_cargo(cargo: BoatCargo, slot_index: int, item: Dictionary) -> void:
	var title: String = str(item.get("name", "Barril"))
	cargo.remove_item_at(slot_index)

	var reward: int = randi_range(0, 10)
	if reward > 0:
		cargo.add_gold(reward)
	cargo.item_opened.emit(title, reward)

	if cargo.progression != null:
		cargo.progression.add_xp(randi_range(1, 5), "Barril abierto")
