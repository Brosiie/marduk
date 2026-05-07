shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// Boss attack telegraph decal. Renders different shapes on a flat ground
// quad based on shape_id. Used by boss_base.gd to show the player where
// an incoming attack will land BEFORE it hits, with a pulse that
// intensifies as the strike approaches.
//
// shape_id values mirror BossAttackPattern.Shape:
//   0 = SINGLE_TARGET   -> small circle at boss feet
//   1 = FORWARD_CONE    -> wedge (uses arc_degrees uniform)
//   2 = AOE_AROUND_BOSS -> filled circle
//   3 = AOE_GROUND      -> filled circle at marked spot
//   4 = LINE            -> long thin strip
//   5 = PROJECTILE      -> small circle (origin marker)
//   6 = ARENA_WIDE      -> ring at the far edge

uniform int shape_id : hint_range(0, 6) = 0;
uniform vec4 telegraph_color : source_color = vec4(1.0, 0.2, 0.2, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;  // 0..1 windup
uniform float arc_radians : hint_range(0.0, 6.283) = 1.047;  // half-angle for cone
uniform float pulse_speed : hint_range(0.5, 12.0) = 8.0;

void fragment() {
	// Quad UV is 0..1; recenter to -0.5..0.5
	vec2 uv = UV - vec2(0.5);
	float d = length(uv);
	float alpha = 0.0;
	float border_thickness = 0.025;

	if (shape_id == 0 || shape_id == 5) {
		// Small circle (single-target / projectile origin): half-radius
		float r = 0.25;
		float fill = step(d, r) * 0.4;
		float border = smoothstep(r - border_thickness, r, d) * (1.0 - step(r, d));
		alpha = max(fill, border);
	} else if (shape_id == 1) {
		// Forward cone: angle within arc_radians of +X (uv.x positive direction)
		float angle = atan(uv.y, uv.x);
		float half_arc = arc_radians;
		if (abs(angle) < half_arc && d < 0.5) {
			float fill = 0.4;
			float border = smoothstep(0.5 - border_thickness, 0.5, d);
			alpha = max(fill, border);
		}
	} else if (shape_id == 2 || shape_id == 3) {
		// Filled circle (AOE around boss / AOE ground)
		float r = 0.5;
		float fill = step(d, r) * 0.4;
		float border = smoothstep(r - border_thickness, r, d) * (1.0 - step(r + border_thickness, d));
		alpha = max(fill, border);
	} else if (shape_id == 4) {
		// Line: thin strip across UV
		if (abs(uv.y) < 0.08 && abs(uv.x) < 0.5) {
			float fill = 0.4;
			float border = smoothstep(0.075, 0.08, abs(uv.y));
			alpha = max(fill, border);
		}
	} else if (shape_id == 6) {
		// Arena ring (band near the outer edge)
		float ring_inner = 0.42;
		float ring_outer = 0.5;
		alpha = smoothstep(ring_inner - border_thickness, ring_inner, d) *
		        (1.0 - smoothstep(ring_outer, ring_outer + border_thickness, d)) * 0.6;
	}

	// Pulse intensifies as windup progresses: low at start, harsh at strike.
	float pulse = 0.4 + 0.6 * abs(sin(TIME * pulse_speed));
	float urgency = 0.4 + 0.6 * progress;
	ALBEDO = telegraph_color.rgb;
	ALPHA = telegraph_color.a * alpha * pulse * urgency;
}
