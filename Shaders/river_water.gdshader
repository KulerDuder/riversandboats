shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

group_uniforms Colores;
uniform vec3 shallow_color : source_color = vec3(0.14, 0.42, 0.46);
uniform vec3 deep_color : source_color = vec3(0.03, 0.16, 0.28);
uniform vec3 foam_color : source_color = vec3(0.92, 0.96, 0.98);
uniform float depth_fade_distance : hint_range(0.2, 10.0) = 2.6;
uniform float foam_distance : hint_range(0.05, 2.0) = 0.42;

group_uniforms Oleaje;
uniform float wave_scale : hint_range(0.05, 2.0) = 0.35;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.28;
uniform float wave_strength : hint_range(0.0, 0.25) = 0.042;
uniform float water_roughness : hint_range(0.01, 0.5) = 0.035;

group_uniforms Interaccion_y_Clima;
uniform vec3 boat_pos = vec3(0.0, 0.0, 0.0);
uniform vec2 boat_dir = vec2(0.0, -1.0);
uniform float boat_speed = 0.0;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;

varying vec3 world_pos;

// Hash rápido sin texturas para anillos de lluvia
vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// Ondas multicapa direccionales
float wave_height(vec2 p, float t) {
	float w1 = sin(p.x * 1.1 + p.y * 0.7 + t * 1.3);
	float w2 = cos(p.x * 0.8 - p.y * 1.2 + t * 1.1);
	float w3 = sin(p.x * 2.1 - p.y * 1.7 - t * 1.7) * 0.5;
	float w4 = cos(p.x * 1.6 + p.y * 2.3 + t * 0.9) * 0.5;
	float w5 = sin(p.x * 4.3 + p.y * 3.9 - t * 2.4) * 0.22;
	return (w1 + w2 + w3 + w4 + w5) * 0.23;
}

// Perturbación y altura de anillos de gotas de lluvia sobre el agua
vec3 rain_ripples(vec2 pos_xz, float time, float intensity) {
	if (intensity <= 0.01) {
		return vec3(0.0);
	}
	vec2 uv = pos_xz * 1.65;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);

	vec2 total_grad = vec2(0.0);
	float total_ring = 0.0;

	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 id = cell + neighbor;
			vec2 rnd = hash22(id);

			// Filtrar densidad según intensidad de lluvia
			if (rnd.x > intensity) {
				continue;
			}

			float t = fract(time * 1.35 + rnd.y);
			vec2 center = neighbor + 0.15 + 0.7 * hash22(id + 17.3);
			vec2 diff = f - center;
			float dist = length(diff);
			float radius = t * 0.75;
			float band = dist - radius;

			float env = exp(-abs(band) * 26.0) * (1.0 - t) * smoothstep(0.0, 0.08, t);
			float wave = sin(band * 48.0) * env;
			vec2 dir = dist > 0.0001 ? diff / dist : vec2(0.0);

			total_grad += dir * wave;
			total_ring += max(0.0, wave);
		}
	}
	return vec3(total_grad * 0.22 * intensity, total_ring * intensity);
}

// Cáusticas procedurales para el lecho arenoso poco profundo
float caustics_pattern(vec2 p, float t) {
	vec2 uv1 = p * 0.85 + vec2(t * 0.18, -t * 0.14);
	vec2 uv2 = p * 1.15 + vec2(-t * 0.15, t * 0.21);
	float c1 = abs(sin(uv1.x * 3.1 + sin(uv1.y * 2.7 + t)) + cos(uv1.y * 3.3));
	float c2 = abs(sin(uv2.x * 2.9 - cos(uv2.y * 3.1 - t)) + cos(uv2.y * 2.6));
	float c = 1.0 - min(c1, c2) * 0.5;
	return pow(clamp(c, 0.0, 1.0), 4.0);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv_world = world_pos.xz * wave_scale;
	float t = TIME * wave_speed;

	// 1. Normal analítica del oleaje
	float eps = 0.07;
	float h0 = wave_height(uv_world, t);
	float hx = wave_height(uv_world + vec2(eps, 0.0), t);
	float hz = wave_height(uv_world + vec2(0.0, eps), t);

	// 2. Anillos de gotas de lluvia
	vec3 rain_data = rain_ripples(world_pos.xz, TIME, rain_intensity);

	vec3 wave_normal_world = normalize(vec3(
		(h0 - hx) * wave_strength / eps + rain_data.x,
		1.0,
		(h0 - hz) * wave_strength / eps + rain_data.y
	));

	// Pasar normal al espacio de vista para iluminación y SSR
	NORMAL = normalize((VIEW_MATRIX * vec4(wave_normal_world, 0.0)).xyz);

	// 3. Profundidad real bajo el agua
	float depth_raw = texture(depth_tex, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 view_geom = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_geom.xyz /= view_geom.w;
	float water_depth = max(0.0, VERTEX.z - view_geom.z);

	float depth_factor = 1.0 - exp(-water_depth / depth_fade_distance);

	// 4. Refracción del fondo + cáusticas en zonas poco profundas
	vec2 refract_offset = wave_normal_world.xz * 0.022 * clamp(water_depth, 0.0, 1.0);
	vec3 seabed_color = texture(screen_tex, clamp(SCREEN_UV + refract_offset, vec2(0.001), vec2(0.999))).rgb;

	float caustics = caustics_pattern(world_pos.xz, TIME) * (1.0 - depth_factor) * (1.0 - rain_intensity * 0.6);
	seabed_color += vec3(0.32, 0.42, 0.36) * caustics * 0.45;

	vec3 water_tint = mix(shallow_color, deep_color, depth_factor);
	float opacity = clamp(0.32 + depth_factor * 0.65, 0.0, 0.96);
	vec3 base_albedo = mix(seabed_color * shallow_color * 1.45, water_tint, opacity);

	// 5. Espuma en las orillas y pilotes de los muelles
	float foam_mask = 1.0 - smoothstep(0.02, foam_distance, water_depth);
	float foam_ripple = sin(water_depth * 26.0 - TIME * 2.4 + h0 * 4.0) * 0.5 + 0.5;
	float shore_foam = foam_mask * smoothstep(0.25, 0.85, foam_ripple + foam_mask * 0.45);

	// 6. Estela dinámica detrás del barco
	float wake_foam = 0.0;
	float speed_norm = clamp(abs(boat_speed) / 10.0, 0.0, 1.0);
	if (speed_norm > 0.03) {
		vec2 fwd = normalize(boat_dir);
		vec2 right = vec2(-fwd.y, fwd.x);
		vec2 rel = world_pos.xz - boat_pos.xz;

		float along = dot(rel, -fwd); // Positivo hacia atrás de la popa
		float side = abs(dot(rel, right));

		float wake_len = mix(3.0, 15.0, speed_norm);
		if (along > -1.2 && along < wake_len) {
			float progress = clamp((along + 1.2) / wake_len, 0.0, 1.0);
			float v_width = 0.55 + progress * mix(1.4, 3.6, speed_norm);

			// Brazos en V de la estela + turbulencia central de hélice
			float arm_dist = abs(side - v_width * 0.72);
			float v_arms = smoothstep(0.65, 0.05, arm_dist);
			float center_wash = smoothstep(v_width * 0.55, 0.0, side) * (1.0 - progress * 0.7);

			float noise_tex = sin(world_pos.x * 4.5 + TIME * 5.0) * cos(world_pos.z * 4.5 - TIME * 4.2) * 0.5 + 0.5;
			float fade = (1.0 - progress) * smoothstep(-1.2, 0.4, along);
			wake_foam = clamp((v_arms * 0.85 + center_wash * 0.7) * (0.55 + 0.45 * noise_tex) * fade * speed_norm, 0.0, 1.0);
		}
	}

	float total_foam = clamp(shore_foam + wake_foam + rain_data.z * 0.35, 0.0, 1.0);
	ALBEDO = mix(base_albedo, foam_color, total_foam * 0.85);

	// 7. Modelo dieléctrico limpio (METALLIC = 0) para que SSR refleje cielo, edificios y luces
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	METALLIC = 0.0;
	ROUGHNESS = mix(water_roughness, 0.42, total_foam);
	SPECULAR = mix(0.55, 1.0, fresnel);
}