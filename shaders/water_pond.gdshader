shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Stylized koi pond water. Two octaves of moving sin-noise for ripples,
// a fresnel rim that brightens grazing angles, and a subtle gold-tint
// emission layered for the 'lit by lanterns' look. Cheap enough to run
// on Forward+ M-series without a real depth-pass refraction.

uniform vec4 shallow_color : source_color = vec4(0.55, 0.78, 0.82, 0.85);
uniform vec4 deep_color    : source_color = vec4(0.10, 0.20, 0.30, 1.00);
uniform vec4 fresnel_color : source_color = vec4(1.00, 0.85, 0.55, 1.00);
uniform float fresnel_power : hint_range(0.5, 8.0) = 4.0;
uniform float wave_speed   : hint_range(0.0, 4.0) = 0.6;
uniform float wave_strength : hint_range(0.0, 0.4) = 0.06;
uniform float depth_falloff : hint_range(0.0, 5.0) = 1.4;

// Tile size for the noise
uniform float scale_a : hint_range(0.5, 8.0) = 2.5;
uniform float scale_b : hint_range(0.5, 8.0) = 5.5;

// Cheap value-noise via sin
float wave(vec2 uv, float t) {
	float a = sin(uv.x * scale_a + t * 1.4) * 0.5;
	float b = sin(uv.y * scale_a * 1.3 + t * 1.0) * 0.5;
	float c = sin((uv.x + uv.y) * scale_b + t * 1.7) * 0.25;
	float d = sin((uv.x - uv.y) * scale_b * 1.1 + t * 0.9) * 0.25;
	return (a + b + c + d) * 0.25 + 0.5;
}

void vertex() {
	// Subtle vertical displacement so the surface actually undulates
	float w = wave(VERTEX.xz * 0.15, TIME * wave_speed);
	VERTEX.y += (w - 0.5) * wave_strength;
}

void fragment() {
	// Animated normal perturbation
	float t = TIME * wave_speed;
	vec2 uv = UV * 4.0;
	float n = wave(uv, t);
	float n_dx = wave(uv + vec2(0.01, 0), t) - n;
	float n_dy = wave(uv + vec2(0, 0.01), t) - n;
	NORMAL = normalize(NORMAL + vec3(n_dx, 0, n_dy) * 1.5);

	// Color depth gradient by view angle (deeper at center, shallow at edges)
	float vdotn = max(dot(NORMAL, VIEW), 0.0);
	float depth_t = pow(vdotn, depth_falloff);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, depth_t);

	// Fresnel rim (golden where grazing)
	float fresnel = pow(1.0 - vdotn, fresnel_power);
	col += fresnel_color.rgb * fresnel * 0.6;

	ALBEDO = col;
	ALPHA = mix(deep_color.a, shallow_color.a, depth_t);
	METALLIC = 0.15;
	ROUGHNESS = 0.05;  // very mirror-like
	SPECULAR = 0.85;
}
