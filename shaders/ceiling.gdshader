// Tavan gölgelendiricisi: bina içi kesit görünümünde tavanlar yarı saydam görünür,
// böylece alçak tavanlar fark edilir ama görüşü kapatmaz. Üst katların tavanları gizlenir.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled;

global uniform float ceil_cut_height;
uniform float alpha_value : hint_range(0.0, 1.0) = 0.28;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (world_pos.y > ceil_cut_height) {
		discard;
	}
	// Kenarlara doğru hafif çizgi deseni (tavan olduğu anlaşılsın)
	float stripe = step(0.92, fract((world_pos.x + world_pos.z) * 2.0));
	ALBEDO = mix(COLOR.rgb, vec3(1.0, 0.85, 0.4), stripe * 0.6);
	ALPHA = alpha_value + stripe * 0.15;
}
