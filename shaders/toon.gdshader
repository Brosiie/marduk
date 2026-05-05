shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

// Stylized cel-shading for the soft anime / mild pixel-fantasy vibe.
// Light is quantized into bands. Rim adds a soft outline glow on silhouettes.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, hint_default_white;
uniform float bands : hint_range(2.0, 8.0) = 3.0;
uniform float ambient : hint_range(0.0, 1.0) = 0.35;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.7;
uniform float rim_power : hint_range(1.0, 8.0) = 3.0;
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.7, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.45, 0.4, 0.55, 1.0);

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = (albedo * tex).rgb;
}

void light() {
	float NdotL = max(dot(NORMAL, LIGHT), 0.0);
	float banded = floor(NdotL * bands) / bands;
	vec3 lit = mix(shadow_tint.rgb * ALBEDO, ALBEDO * LIGHT_COLOR.rgb, banded);
	DIFFUSE_LIGHT += lit * ATTENUATION + ALBEDO * ambient;

	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), rim_power);
	DIFFUSE_LIGHT += rim * rim_strength * rim_color.rgb * NdotL;
}
