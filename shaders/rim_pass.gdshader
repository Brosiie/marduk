shader_type spatial;
render_mode blend_add, depth_draw_never, depth_test_disabled, unshaded, cull_back;

// Additive rim-light next_pass. Runs on top of a character's base
// material so the original albedo + lighting is untouched -- this
// pass only ADDS a soft halo on the edges where surface normals
// face away from the camera. Used to separate characters from the
// volumetric-fogged backgrounds.
//
// Driven by a uniform color so the player can shift it to class-
// buff palette (gold Ronin, blue Mage, red Demon, etc).

uniform vec4 rim_color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 2.4;
uniform float rim_strength : hint_range(0.0, 4.0) = 1.6;
uniform float pulse_speed : hint_range(0.0, 4.0) = 0.0;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// rim = 1 - facing-camera-ness, raised to a power. Higher power
	// makes the rim tighter to the silhouette edge.
	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), rim_power);
	float pulse = 1.0;
	if (pulse_speed > 0.0) {
		pulse = 1.0 - pulse_amount + pulse_amount * (0.5 + 0.5 * sin(TIME * pulse_speed));
	}
	ALBEDO = rim_color.rgb * rim * rim_strength * pulse;
}
