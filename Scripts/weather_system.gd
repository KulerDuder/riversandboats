class_name WeatherSystem
extends Node3D
## Gestiona fenómenos meteorológicos dinámicos (lluvia y niebla volumétrica)
## combinándolos en distintos grados y sincronizándolos con el ciclo día/noche.

signal weather_changed(weather_name: String, rain_level: float, fog_level: float)

## Tiempo mínimo y máximo (en segundos) antes de elegir una nueva combinación de clima.
@export var min_change_interval: float = 35.0
@export var max_change_interval: float = 75.0
## Velocidad de transición entre estados climáticos.
@export var transition_speed: float = 0.08

var rain_intensity: float = 0.0
var fog_intensity: float = 0.0

var _target_rain: float = 0.0
var _target_fog: float = 0.0
var _change_timer: float = 20.0

var _env: Environment
var _sun: DirectionalLight3D
var _sky_mat: ProceduralSkyMaterial
var _follow_target: Node3D
var _rain_particles: GPUParticles3D
var _last_weather_label: String = ""


func setup(p_env: Environment, p_sun: DirectionalLight3D, p_sky_mat: ProceduralSkyMaterial, p_target: Node3D) -> void:
	_env = p_env
	_sun = p_sun
	_sky_mat = p_sky_mat
	_follow_target = p_target

	_configure_volumetric_fog()
	_build_rain_particles()
	_pick_initial_weather()


func _process(delta: float) -> void:
	if is_instance_valid(_follow_target):
		global_position = Vector3(_follow_target.global_position.x, 0.0, _follow_target.global_position.z)

	_change_timer -= delta
	if _change_timer <= 0.0:
		_pick_next_weather()

	rain_intensity = move_toward(rain_intensity, _target_rain, transition_speed * delta)
	fog_intensity = move_toward(fog_intensity, _target_fog, transition_speed * delta)

	_update_rain_visuals()
	_emit_weather_if_changed()


## Permite forzar un clima concreto (útil para pruebas o eventos).
func set_weather_targets(rain: float, fog: float, instant: bool = false) -> void:
	_target_rain = clampf(rain, 0.0, 1.0)
	_target_fog = clampf(fog, 0.0, 1.0)
	if instant:
		rain_intensity = _target_rain
		fog_intensity = _target_fog
		_update_rain_visuals()


func get_overcast_factor() -> float:
	# Cuánto se encapota el cielo por la suma de lluvia y niebla
	return clampf(maxf(rain_intensity * 0.85, fog_intensity * 0.65), 0.0, 0.92)


func get_weather_label() -> String:
	var has_rain: bool = rain_intensity >= 0.18
	var has_fog: bool = fog_intensity >= 0.22

	if not has_rain and not has_fog:
		return "Despejado"
	elif has_rain and not has_fog:
		return "Tormenta" if rain_intensity >= 0.65 else "Llovizna"
	elif not has_rain and has_fog:
		return "Niebla densa" if fog_intensity >= 0.65 else "Bruma"
	else:
		if rain_intensity >= 0.6 and fog_intensity >= 0.6:
			return "Tempestad cerrada"
		return "Lluvia y niebla"


func apply_atmosphere_modifiers(base_sky_top: Color, base_sky_horizon: Color, base_sun_energy: float, day_factor: float) -> void:
	if _env == null or _sky_mat == null:
		return

	var overcast: float = get_overcast_factor()

	# Cielo encapotado gris-azulado adaptado a si es de día o de noche
	var overcast_day := Color(0.42, 0.47, 0.52)
	var overcast_night := Color(0.03, 0.05, 0.08)
	var cloud_tint := overcast_night.lerp(overcast_day, day_factor)

	var final_top := base_sky_top.lerp(cloud_tint.darkened(0.12), overcast)
	var final_horizon := base_sky_horizon.lerp(cloud_tint, overcast)

	_sky_mat.sky_top_color = final_top
	_sky_mat.sky_horizon_color = final_horizon
	_sky_mat.ground_horizon_color = final_horizon.darkened(0.08)

	# Niebla volumétrica + niebla exponencial de respaldo en horizonte lejano
	_env.fog_light_color = final_horizon
	_env.fog_density = lerpf(0.0018, 0.014, fog_intensity)

	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = lerpf(0.0025, 0.058, pow(fog_intensity, 1.25))
	_env.volumetric_fog_albedo = final_horizon.lightened(0.08)
	_env.volumetric_fog_emission = final_horizon * lerpf(0.04, 0.14, day_factor)
	_env.volumetric_fog_emission_energy = lerpf(0.25, 0.65, fog_intensity)

	# Atenuar la luz directa del sol cuando hay nubes o niebla espesa
	if _sun != null:
		_sun.light_energy = base_sun_energy * lerpf(1.0, 0.32, overcast)


func _configure_volumetric_fog() -> void:
	if _env == null:
		return
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.003
	_env.volumetric_fog_anisotropy = 0.55
	_env.volumetric_fog_length = 180.0
	_env.volumetric_fog_detail_spread = 2.0
	_env.volumetric_fog_sky_affect = 0.85


func _build_rain_particles() -> void:
	_rain_particles = GPUParticles3D.new()
	_rain_particles.name = "RainParticles"
	_rain_particles.position = Vector3(0.0, 14.0, 0.0)
	_rain_particles.amount = 2200
	_rain_particles.lifetime = 1.15
	_rain_particles.preprocess = 1.0
	_rain_particles.visibility_aabb = AABB(Vector3(-35.0, -18.0, -35.0), Vector3(70.0, 24.0, 70.0))
	_rain_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain_particles.emitting = false

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(28.0, 1.5, 28.0)
	pmat.direction = Vector3(0.14, -1.0, 0.08).normalized()
	pmat.spread = 3.5
	pmat.initial_velocity_min = 20.0
	pmat.initial_velocity_max = 26.0
	pmat.gravity = Vector3(0.0, -9.8, 0.0)
	_rain_particles.process_material = pmat

	# Gota estirada estilo trazo de lluvia
	var drop_mesh := BoxMesh.new()
	drop_mesh.size = Vector3(0.022, 0.55, 0.022)

	var drop_mat := StandardMaterial3D.new()
	drop_mat.albedo_color = Color(0.76, 0.86, 0.96, 0.42)
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	drop_mesh.material = drop_mat

	_rain_particles.draw_pass_1 = drop_mesh
	add_child(_rain_particles)


func _update_rain_visuals() -> void:
	if _rain_particles == null:
		return
	if rain_intensity <= 0.02:
		_rain_particles.emitting = false
	else:
		_rain_particles.emitting = true
		_rain_particles.amount_ratio = clampf(rain_intensity, 0.05, 1.0)


func _pick_initial_weather() -> void:
	# Empezar con una bruma muy ligera matinal sobre el río
	set_weather_targets(0.0, 0.18, true)
	_change_timer = randf_range(min_change_interval * 0.6, max_change_interval * 0.8)


func _pick_next_weather() -> void:
	_change_timer = randf_range(min_change_interval, max_change_interval)

	# Elegir entre combinaciones variadas (despejado, solo niebla, solo lluvia o mezcla)
	var roll: float = randf()
	if roll < 0.28:
		# Despejado / bruma mínima
		_target_rain = 0.0
		_target_fog = randf_range(0.0, 0.14)
	elif roll < 0.52:
		# Banco de niebla sin lluvia (desde bruma media a niebla cerrada)
		_target_rain = 0.0
		_target_fog = randf_range(0.35, 0.95)
	elif roll < 0.74:
		# Lluvia sin apenas niebla (llovizna o chaparrón limpio)
		_target_rain = randf_range(0.28, 0.85)
		_target_fog = randf_range(0.05, 0.22)
	else:
		# Mezcla de lluvia y niebla en distintos grados
		_target_rain = randf_range(0.25, 1.0)
		_target_fog = randf_range(0.30, 1.0)


func _emit_weather_if_changed() -> void:
	var label: String = get_weather_label()
	if label != _last_weather_label:
		_last_weather_label = label
		weather_changed.emit(label, rain_intensity, fog_intensity)
