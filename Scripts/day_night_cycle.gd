class_name DayNightCycle
extends Node
## Controla el ciclo de día y noche, rotando el sol y transicionando suavemente
## el cielo, la niebla, la iluminación y los faroles de los muelles.

signal time_updated(hour: int, minute: int, phase_name: String, is_night: bool)

@export var day_duration_seconds: float = 180.0
@export_range(0.0, 24.0, 0.1) var start_hour: float = 8.5

var time_of_day: float = 8.5

var _sun: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _boat_lamp: OmniLight3D
var _weather: WeatherSystem
var _buildings: Array[MississippiBuilding] = []
var _last_emitted_minute: int = -1


func setup(
	p_sun: DirectionalLight3D,
	p_env: Environment,
	p_sky_mat: ProceduralSkyMaterial,
	p_boat_lamp: OmniLight3D = null,
	p_weather: WeatherSystem = null
) -> void:
	_sun = p_sun
	_env = p_env
	_sky_mat = p_sky_mat
	_boat_lamp = p_boat_lamp
	_weather = p_weather
	time_of_day = fposmod(start_hour, 24.0)
	_apply_atmosphere()


func set_buildings(buildings: Array[MississippiBuilding]) -> void:
	_buildings = buildings
	_apply_atmosphere()


func _process(delta: float) -> void:
	if day_duration_seconds <= 0.0:
		return

	var hours_per_second: float = 24.0 / day_duration_seconds
	time_of_day = fposmod(time_of_day + delta * hours_per_second, 24.0)
	_apply_atmosphere()


func is_night_time() -> bool:
	return time_of_day < 5.75 or time_of_day >= 19.25


func get_phase_name() -> String:
	if time_of_day >= 5.5 and time_of_day < 8.0:
		return "Amanecer"
	elif time_of_day >= 8.0 and time_of_day < 17.5:
		return "Día"
	elif time_of_day >= 17.5 and time_of_day < 20.0:
		return "Atardecer"
	else:
		return "Noche"


func _apply_atmosphere() -> void:
	if _sun == null or _env == null or _sky_mat == null:
		return

	var sun_angle_deg: float = ((time_of_day - 6.0) / 24.0) * 360.0
	var sun_rad: float = deg_to_rad(sun_angle_deg)
	var sun_height: float = sin(sun_rad)

	_sun.rotation_degrees = Vector3(-sun_angle_deg, -32.0, 0.0)

	var day_factor: float = smoothstep(-0.18, 0.25, sun_height)
	var horizon_factor: float = 1.0 - clampf(absf(sun_height) / 0.32, 0.0, 1.0)
	horizon_factor = pow(horizon_factor, 1.4)

	var day_sky_top := Color(0.22, 0.48, 0.86)
	var night_sky_top := Color(0.02, 0.04, 0.11)
	var sky_top := night_sky_top.lerp(day_sky_top, day_factor)

	var day_sky_horizon := Color(0.76, 0.85, 0.92)
	var night_sky_horizon := Color(0.05, 0.09, 0.18)
	var golden_horizon := Color(0.96, 0.52, 0.26)
	var sky_horizon := night_sky_horizon.lerp(day_sky_horizon, day_factor).lerp(golden_horizon, horizon_factor * 0.72)

	var day_ground := Color(0.18, 0.34, 0.48)
	var night_ground := Color(0.02, 0.04, 0.08)
	var ground_bottom := night_ground.lerp(day_ground, day_factor)

	_sky_mat.sky_top_color = sky_top
	_sky_mat.sky_horizon_color = sky_horizon
	_sky_mat.ground_horizon_color = sky_horizon.darkened(0.08)
	_sky_mat.ground_bottom_color = ground_bottom

	_env.ambient_light_sky_contribution = lerpf(0.42, 0.78, day_factor)
	_env.fog_sun_scatter = lerpf(0.08, 0.65, horizon_factor) * day_factor

	var base_sun_energy: float
	if sun_height >= -0.05:
		var noon_light := Color(1.0, 0.96, 0.88)
		var sunset_light := Color(1.0, 0.56, 0.28)
		_sun.light_color = noon_light.lerp(sunset_light, horizon_factor)
		base_sun_energy = lerpf(0.0, 1.30, smoothstep(-0.05, 0.22, sun_height))
		_sun.light_energy = base_sun_energy
		_sun.shadow_enabled = base_sun_energy > 0.08
	else:
		_sun.rotation_degrees = Vector3(-55.0, 140.0, 0.0)
		_sun.light_color = Color(0.32, 0.48, 0.78)
		base_sun_energy = lerpf(0.0, 0.24, smoothstep(-0.05, -0.35, sun_height))
		_sun.light_energy = base_sun_energy
		_sun.shadow_enabled = true

	if is_instance_valid(_weather):
		_weather.apply_atmosphere_modifiers(sky_top, sky_horizon, base_sun_energy, day_factor)
	else:
		_env.fog_light_color = sky_horizon

	# Factor de encendido artificial (noche + niebla espesa)
	var night_blend: float = 1.0 - smoothstep(-0.12, 0.14, sun_height)
	var fog_boost: float = _weather.fog_intensity * 0.65 if is_instance_valid(_weather) else 0.0
	var lamp_factor: float = clampf(maxf(night_blend, fog_boost), 0.0, 1.0)

	if is_instance_valid(_boat_lamp):
		_boat_lamp.light_energy = lamp_factor * 4.5
		_boat_lamp.visible = lamp_factor > 0.02

	for b: MississippiBuilding in _buildings:
		if is_instance_valid(b):
			b.set_night_lighting(lamp_factor)

	var total_minutes: int = int(floor(time_of_day * 60.0)) % 1440
	if total_minutes != _last_emitted_minute:
		_last_emitted_minute = total_minutes
		var h: int = total_minutes / 60
		var m: int = total_minutes % 60
		time_updated.emit(h, m, get_phase_name(), is_night_time())
