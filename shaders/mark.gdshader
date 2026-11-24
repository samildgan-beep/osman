// Duvar çiziği / darbe izi: yüzeye yapışık ince levha, dokusu kodla üretilir.
// Kesit görünümünde bina gibi gizlenir.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;

global uniform float cut_height;
uniform vec4 mark_color : source_color = vec4(0.18, 0.15, 0.13, 0.75);
uniform float kind = 0.0;      // 0 = çizik (uzun çizgiler), 1 = darbe izi (yuvarlak)
uniform float seed = 0.0;

varying vec3 world_pos;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (world_pos.y > cut_height) {
		discard;
	}
	vec2 uv = UV * 2.0 - 1.0;
	float a = 0.0;
	if (kind < 0.5) {
		// Birkaç paralel ince çizgi, uçlara doğru incelir
		float fade = 1.0 - smoothstep(0.6, 1.0, abs(uv.x));
		for (int i = 0; i < 4; i++) {
			float fi = float(i);
			float y0 = (hash(seed + fi * 3.1) * 2.0 - 1.0) * 0.7;
			float w = 0.06 + hash(seed + fi * 7.7) * 0.08;
			float line = 1.0 - smoothstep(0.0, w, abs(uv.y - y0 - uv.x * 0.08));
			a = max(a, line * (0.5 + 0.5 * hash(seed + fi)));
		}
		a *= fade;
	} else {
		// Yuvarlak çökme izi + çatlak ışınları
		float r = length(uv);
		a = (1.0 - smoothstep(0.35, 0.75, r)) * 0.8;
		float ang = atan(uv.y, uv.x);
		float rays = pow(abs(sin(ang * 3.0 + seed)), 30.0) * (1.0 - smoothstep(0.3, 1.0, r));
		a = max(a, rays);
	}
	ALBEDO = mark_color.rgb;
	ALPHA = a * mark_color.a;
	ROUGHNESS = 1.0;
}
