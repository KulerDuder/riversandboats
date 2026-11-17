class_name CameraRig
extends Camera3D
## Cámara cinematográfica con seguimiento suavizado, autofocus óptico (DOF),
## exposición adaptativa y respiración de FOV según la velocidad del objetivo.

@export var cam_distance: float = 9.0
@export var cam_height: float = 4.5
@export var cam_smooth: float = 4.0

@export_group("Óptica de Cámara (Cycles)")
@export var dof_enabled: bool = true
@export_range(0.0, 0.25, 0.005) var dof_blur_amount: float = 0.075
@export var auto_exposure_enabled: bool = true

var target: Node3D
var _cam_attrs: CameraAttributesPractical


func _ready() -> void:
	current = true
	fov = 70.0
	far = 1500.0
	_setup_optics()
	snap_to_target()


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	global_position = global_position.lerp(_desired_position(), cam_smooth * delta)
	look_at(target.global_position + Vector3.UP, Vector3.UP)
	_update_optics(delta)


func snap_to_target() -> void:
	if not is_instance_valid(target):
		return
	global_position = _desired_position()
	look_at(target.global_position + Vector3.UP, Vector3.UP)


func _desired_position() -> Vector3:
	return target.global_position + target.global_basis.z * cam_distance + Vector3.UP * cam_height


func _setup_optics() -> void:
	_cam_attrs = CameraAttributesPractical.new()
	_cam_attrs.exposure_sensitivity = 100.0
	_cam_attrs.exposure_multiplier = 1.05
	_cam_attrs.auto_exposure_enabled = auto_exposure_enabled
	_cam_attrs.auto_exposure_scale = 0.42
	_cam_attrs.auto_exposure_speed = 1.4
	_cam_attrs.auto_exposure_min_sensitivity = 65.0
	_cam_attrs.auto_exposure_max_sensitivity = 260.0

	_cam_attrs.dof_blur_far_enabled = dof_enabled
	_cam_attrs.dof_blur_far_distance = 24.0
	_cam_attrs.dof_blur_far_transition = 55.0
	_cam_attrs.dof_blur_near_enabled = dof_enabled
	_cam_attrs.dof_blur_near_distance = 3.2
	_cam_attrs.dof_blur_near_transition = 2.0
	_cam_attrs.dof_blur_amount = dof_blur_amount

	attributes = _cam_attrs


func _update_optics(delta: float) -> void:
	if _cam_attrs == null or not is_instance_valid(target):
		return

	_cam_attrs.auto_exposure_enabled = auto_exposure_enabled
	_cam_attrs.dof_blur_far_enabled = dof_enabled
	_cam_attrs.dof_blur_near_enabled = dof_enabled
	_cam_attrs.dof_blur_amount = dof_blur_amount

	var dist_to_target: float = global_position.distance_to(target.global_position)
	_cam_attrs.dof_blur_far_distance = dist_to_target + 16.0

	var speed_ratio: float = 0.0
	if target is Boat:
		var b: Boat = target as Boat
		speed_ratio = clampf(absf(b.speed) / maxf(b.max_speed, 0.1), 0.0, 1.0)

	var target_fov: float = lerpf(70.0, 74.5, speed_ratio)
	fov = lerpf(fov, target_fov, 3.0 * delta)
