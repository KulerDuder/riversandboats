class_name WaterRingIndicator
extends MeshInstance3D
## Anillo procedural sobre la superficie del agua con pulso suave de opacidad.
## Reutilizable para puertos, boyas, zonas de pesca o eventos en el río.

@export var radius: float = 15.0
@export var thickness: float = 0.28
@export var segments: int = 72
@export var ring_color: Color = Color(1.0, 1.0, 1.0, 0.45)
@export var water_y_offset: float = 0.08

var is_highlighted: bool = false

var _mat: StandardMaterial3D
var _time: float = 0.0


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_mesh()
	global_position.y = water_y_offset


func _process(delta: float) -> void:
	_time += delta
	if _mat != null:
		var base_alpha: float = 0.72 if is_highlighted else ring_color.a
		_mat.albedo_color.a = base_alpha + sin(_time * 2.4) * 0.08


func set_radius(new_radius: float) -> void:
	radius = new_radius
	if is_inside_tree():
		_build_mesh()


func _build_mesh() -> void:
	var inner_r: float = maxf(1.0, radius - thickness * 0.5)
	var outer_r: float = radius + thickness * 0.5

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	for i: int in range(segments + 1):
		var angle: float = (TAU * float(i)) / float(segments)
		var c: float = cos(angle)
		var s: float = sin(angle)

		verts.append(Vector3(c * inner_r, 0.0, s * inner_r))
		normals.append(Vector3.UP)

		verts.append(Vector3(c * outer_r, 0.0, s * outer_r))
		normals.append(Vector3.UP)

	for i: int in segments:
		var a: int = i * 2
		var b: int = a + 1
		var c: int = a + 2
		var d: int = a + 3

		indices.append(a)
		indices.append(b)
		indices.append(c)

		indices.append(b)
		indices.append(d)
		indices.append(c)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var ring_mesh := ArrayMesh.new()
	ring_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = ring_mesh

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = ring_color
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.no_depth_test = false
	material_override = _mat
