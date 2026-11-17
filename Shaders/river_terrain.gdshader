shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

group_uniforms Superficie;
uniform float detail_scale : hint_range(0.1, 4.0) = 0.85;
uniform float bump_strength : hint_range(0.0, 1.0) = 0.28;
uniform float wet_shore_height : hint_range(0.05, 1.5) = 0.42;
uniform float rain_wetness : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

// Ruido gradiente / value noise rápido sin texturas
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amp = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 4; i++) {
		total += value_noise(p) * amp;
		p = rot * p * 2.04 + vec2(17.1, 31.4);
		amp *= 0.5;
	}
	return total;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv_macro = world_pos.xz * 0.14;
	vec2 uv_micro = world_pos.xz * detail_scale;

	// Ruido macro para manchas naturales y micro para grano de superficie
	float n_macro = fbm(uv_macro);
	float n_micro = fbm(uv_micro * 2.5);
	float grain = value_noise(world_pos.xz * 9.0);

	// 1. Perturbación de normal procedural mediante diferencias finitas
	float eps = 0.08;
	float h0 = fbm(uv_micro * 2.2) + grain * 0.25;
	float hx = fbm((world_pos.xz + vec2(eps, 0.0)) * detail_scale * 2.2) + value_noise((world_pos.xz + vec2(eps, 0.0)) * 9.0) * 0.25;
	float hz = fbm((world_pos.xz + vec2(0.0, eps)) * detail_scale * 2.2) + value_noise((world_pos.xz + vec2(0.0, eps)) * 9.0) * 0.25;

	// Mayor rugosidad geométrica en zonas rocosas/inclinadas
	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	float effective_bump = bump_strength * mix(0.65, 1.45, smoothstep(0.08, 0.35, slope));

	vec3 perturbed_world_normal = normalize(world_normal + vec3(
		(h0 - hx) * effective_bump / eps,
		0.0,
		(h0 - hz) * effective_bump / eps
	));
	NORMAL = normalize((VIEW_MATRIX * vec4(perturbed_world_normal, 0.0)).xyz);

	// 2. Color base desde vértices + variación orgánica multi-escala
	vec3 base_col = COLOR.rgb;
	vec3 moss_tint = vec3(0.18, 0.36, 0.14);
	vec3 dry_earth = vec3(0.46, 0.40, 0.28);
	vec3 rock_strata = vec3(0.36, 0.34, 0.32);

	// Añadir parches de musgo y tierra en zonas altas
	float land_mask = smoothstep(0.35, 1.2, world_pos.y);
	base_col = mix(base_col, moss_tint, smoothstep(0.55, 0.85, n_macro) * land_mask * (1.0 - slope) * 0.45);
	base_col = mix(base_col, dry_earth, smoothstep(0.55, 0.85, 1.0 - n_macro) * land_mask * 0.30);

	// Estratos en taludes rocosos
	float strata = sin(world_pos.y * 5.5 + n_macro * 4.0) * 0.5 + 0.5;
	base_col = mix(base_col, rock_strata, smoothstep(0.15, 0.40, slope) * strata * 0.45);

	// Detalle fino de grano en arena y hierba
	base_col *= mix(0.86, 1.14, n_micro * 0.7 + grain * 0.3);

	// 3. Franja húmeda en la orilla + humedad general por lluvia
	float shore_limit = wet_shore_height + rain_wetness * 0.45 + (n_macro - 0.5) * 0.14;
	float shore_wet = 1.0 - smoothstep(-0.05, shore_limit, world_pos.y);
	float total_wet = clamp(max(shore_wet, rain_wetness * 0.72), 0.0, 1.0);

	// La superficie mojada absorbe luz (más oscura y saturada) y refleja el entorno
	vec3 wet_col = base_col * vec3(0.48, 0.50, 0.54);
	ALBEDO = mix(base_col, wet_col, total_wet);

	METALLIC = 0.0;
	ROUGHNESS = mix(mix(0.92, 0.78, slope), 0.20, total_wet);
	SPECULAR = mix(0.35, 0.75, total_wet);
}