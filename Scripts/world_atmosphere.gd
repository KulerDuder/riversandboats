class_name WorldAtmosphere
extends Node3D
## Gestiona la atmósfera 3D, iluminación global (AgX/SDFGI/SSIL/SSR),
## luz solar y actualización de parámetros de shaders del mundo.

var sky_mat: ProceduralSkyMaterial
var env: Environment
var sun: DirectionalLight3D

var terrain: TerrainGenerator
var boat: Boat
var weather: WeatherSystem


func _ready() -> void:
	_build_environment()


func _process(_delta: float) -> void:
	_update_shader_uniforms()


func _build_environment() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.48, 0.86)
	sky_mat.sky_horizon_color = Color(0.76, 0.85, 0.92)
	sky_mat.ground_horizon_color = Color(0.72, 0.80, 0.86)
	sky_mat.ground_bottom_color = Color(0.18, 0.34, 0.48)
	sky_mat.sun_angle_max = 28.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_white = 5.5

	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = true
	env.sdfgi_bounce_feedback = 0.72
	env.sdfgi_energy = 1.15
	env.sdfgi_min_cell_size = 1.25
	env.sdfgi_cascade0_distance = 40.0

	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.9
	env.ssao_power = 1.6

	env.ssil_enabled = true
	env.ssil_radius = 5.0
	env.ssil_intensity = 1.35
	env.ssil_sharpness = 0.92

	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.35

	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.35
	env.glow_strength = 0.92
	env.glow_bloom = 0.12
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.76, 0.85, 0.92)
	env.fog_sun_scatter = 0.35
	env.fog_density = 0.0022

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.003
	env.volumetric_fog_anisotropy = 0.62
	env.volumetric_fog_length = 180.0

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.32
	sun.shadow_enabled = true
	sun.shadow_blur = 1.8
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 220.0
	add_child(sun)


func _update_shader_uniforms() -> void:
	if not is_instance_valid(terrain):
		return

	var rain_val: float = weather.rain_intensity if is_instance_valid(weather) else 0.0

	var water_mat := terrain.get_water_material()
	if water_mat != null:
		if is_instance_valid(boat):
			var fwd := -boat.global_basis.z
			water_mat.set_shader_parameter("boat_pos", boat.global_position)
			water_mat.set_shader_parameter("boat_dir", Vector2(fwd.x, fwd.z))
			water_mat.set_shader_parameter("boat_speed", boat.speed)
		water_mat.set_shader_parameter("rain_intensity", rain_val)

	var terrain_mat := terrain.get_terrain_material()
	if terrain_mat != null:
		terrain_mat.set_shader_parameter("rain_wetness", rain_val)
