shader_type spatial;
render_mode cull_disabled;

// Stylized wind: vertex Y displacement based on world position + TIME,
// with anchor weighting via vertex Y so the bottom of grass / trees /
// banners stays planted while the top sways.
//
// Use cases:
//   grass tufts:     amplitude=0.06, frequency=2.0, anchor=0.0
//   tree foliage:    amplitude=0.18, frequency=0.8, anchor=0.4 (trunk firm)
//   banners/flags:   amplitude=0.45, frequency=1.6, anchor=0.0
//
// The bigger amplitude on banners is fine because cloth in the breeze
// reads as floppier than tree branches.

uniform vec4 albedo : source_color = vec4(0.5, 0.7, 0.3, 1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform bool use_texture = false;
uniform float amplitude : hint_range(0.0, 1.0) = 0.10;
uniform float frequency : hint_range(0.1, 5.0) = 1.5;
uniform float anchor : hint_range(0.0, 2.0) = 0.0;
uniform float wind_strength : hint_range(0.0, 2.0) = 1.0;
uniform vec3 wind_dir = vec3(1.0, 0.0, 0.3);

void vertex() {
	// World-space position so neighbouring instances sway in phase
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Phase offset by world XZ so the field looks like a ripple, not
	// every blade flapping in lockstep
	float phase = wpos.x * 0.5 + wpos.z * 0.5;
	float t = TIME * frequency + phase;
	// Gust shape: sin + a faster sin gives natural-feeling chop
	float gust = sin(t) * 0.7 + sin(t * 2.3) * 0.3;
	// Anchor: vertices below `anchor` (model-local Y) don't sway. Above,
	// linear ramp until 1m, then full sway. Keeps grass roots and tree
	// trunks planted.
	float v_y = max(0.0, VERTEX.y - anchor);
	float anchored = clamp(v_y, 0.0, 1.0);
	// Apply displacement along wind_dir on XZ; tiny lift on Y so foliage
	// breathes vertically too
	vec3 sway = normalize(vec3(wind_dir.x, 0.0, wind_dir.z)) * gust * amplitude * anchored * wind_strength;
	sway.y = abs(gust) * amplitude * 0.2 * anchored * wind_strength;
	VERTEX += sway;
}

void fragment() {
	if (use_texture) {
		vec4 sampled = texture(albedo_texture, UV);
		ALBEDO = sampled.rgb * albedo.rgb;
		ALPHA = sampled.a * albedo.a;
	} else {
		ALBEDO = albedo.rgb;
		ALPHA = albedo.a;
	}
	ROUGHNESS = 0.85;
}
