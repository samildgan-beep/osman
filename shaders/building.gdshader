// Bina gölgelendiricisi: köşe renklerini kullanır ve "üstten görünüm"de
// cut_height üstünde kalan duvar/tavanları gizler (Sims tarzı kesit).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

global uniform float cut_height;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;
uniform float grain_amount : hint_range(0.0, 0.2) = 0.035;

varying vec3 world_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (world_pos.y > cut_height) {
		discard;
	}
	// Hafif yüzey dokusu (tekdüze görünmesin diye)
	float g = hash(floor(world_pos * 12.0)) * 2.0 - 1.0;
	vec3 col = COLOR.rgb * (1.0 + g * grain_amount);
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
}
