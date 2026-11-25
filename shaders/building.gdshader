// Bina gölgelendiricisi: köşe renginin alfa kanalındaki malzeme kimliğine göre
// kodla doku üretir (tuğla, ahşap, fayans, mermer, metal, duvar kâğıdı, halı, cam,
// asfalt, çim, kaldırım). Üstten/iç görünümde cut_height üstünü gizler.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

global uniform float cut_height;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;
uniform float grain_amount : hint_range(0.0, 0.3) = 0.06;

varying vec3 world_pos;
varying vec3 world_nrm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (world_pos.y > cut_height) {
		discard;
	}
	vec3 base = COLOR.rgb;
	int m = int(COLOR.a * 16.0);
	vec3 an = abs(world_nrm);
	bool horiz = an.y > an.x && an.y > an.z;
	// Basit üçlü düzlem izdüşümü: yatay yüzeyde xz, duvarda yatay eksen + y
	vec2 uv = horiz ? world_pos.xz : (an.x > an.z ? world_pos.zy : world_pos.xy);
	vec3 col = base;
	float rough = roughness_value;
	float metal = 0.0;
	vec3 emit = vec3(0.0);

	if (m == 1) {
		// Tuğla (0.24 x 0.075 m, şaşırtmalı)
		vec2 b = vec2(uv.x / 0.25, uv.y / 0.08);
		float row = floor(b.y);
		b.x += mod(row, 2.0) * 0.5;
		vec2 f = fract(b);
		float mortar = max(step(f.x, 0.05), step(f.y, 0.12));
		float v = hash(floor(b)) * 0.28 - 0.14;
		vec3 brick = base * (1.0 + v) * (0.9 + 0.2 * noise(uv * 30.0));
		col = mix(brick, vec3(0.78, 0.75, 0.7), mortar);
		rough = 0.95;
	} else if (m == 2) {
		// Ahşap: tahtalar ve damar
		vec2 w = horiz ? uv : vec2(uv.x, uv.y);
		float plank = floor(w.y / 0.14);
		float off = hash(vec2(plank, 3.0)) * 3.0;
		float seam = step(fract(w.y / 0.14), 0.04) + step(fract((w.x + off) / 1.2), 0.008);
		float grain = sin((w.x + off) * 40.0 + fbm(vec2(w.x * 2.0, w.y * 25.0) + off) * 8.0) * 0.5 + 0.5;
		col = base * (0.82 + 0.25 * grain) * (0.92 + 0.16 * hash(vec2(plank, 7.0)));
		col = mix(col, col * 0.55, clamp(seam, 0.0, 1.0));
		rough = 0.55;
	} else if (m == 3) {
		// Fayans: 0.4 m kareler, derz ve dama tonu
		vec2 t = uv / 0.4;
		vec2 f = fract(t);
		float grout = max(step(f.x, 0.04), step(f.y, 0.04));
		float checker = mod(floor(t.x) + floor(t.y), 2.0);
		col = base * (0.92 + checker * 0.12) * (0.96 + 0.08 * noise(uv * 8.0));
		col = mix(col, base * 0.45, grout);
		rough = 0.25;
	} else if (m == 4) {
		// Mermer: damarlı taş
		float n = fbm(uv * 2.5);
		float vein = abs(sin((uv.x + uv.y) * 4.0 + n * 9.0));
		vein = pow(1.0 - vein, 10.0);
		col = mix(base * (0.95 + 0.1 * n), base * 0.55, vein * 0.7);
		rough = 0.22;
	} else if (m == 5) {
		// Metal (korkuluk, pirinç çubuk)
		col = base * (0.9 + 0.1 * noise(uv * 40.0));
		metal = 0.85;
		rough = 0.32;
	} else if (m == 6) {
		// Duvar kâğıdı: dikey çizgili desen
		float s = step(0.5, fract(uv.x / 0.18));
		float dots = step(0.82, noise(uv * 22.0));
		col = base * (0.94 + s * 0.08) + dots * 0.03;
		rough = 0.9;
	} else if (m == 7) {
		// Halı: lifli doku ve kenar şeridi
		float fiber = noise(uv * 90.0) * 0.5 + noise(uv * 35.0) * 0.5;
		col = base * (0.8 + 0.3 * fiber);
		rough = 1.0;
	} else if (m == 8) {
		// Cam: gökyüzü yansıması gibi parlak
		float sky = clamp(world_nrm.y * 0.5 + 0.6 + (fract(uv.y * 0.7) * 0.2), 0.0, 1.0);
		col = mix(base * 0.6, vec3(0.75, 0.88, 1.0), sky * 0.6);
		emit = col * 0.25;
		rough = 0.05;
		metal = 0.3;
	} else if (m == 9) {
		// Asfalt: benekli
		float sp = noise(uv * 60.0);
		col = base * (0.85 + 0.3 * sp) + step(0.93, hash(floor(uv * 80.0))) * 0.06;
		rough = 0.95;
	} else if (m == 10) {
		// Çim: renk lekeleri
		float n = fbm(uv * 1.3);
		col = base * (0.75 + 0.5 * n) + vec3(0.02, 0.05, 0.0) * noise(uv * 40.0);
		rough = 1.0;
	} else if (m == 11) {
		// Kaldırım taşı: 0.5 x 0.25 m, şaşırtmalı
		vec2 b = vec2(uv.x / 0.5, uv.y / 0.25);
		b.x += mod(floor(b.y), 2.0) * 0.5;
		vec2 f = fract(b);
		float gap = max(step(f.x, 0.03), step(f.y, 0.06));
		col = base * (0.88 + 0.2 * hash(floor(b))) * (0.95 + 0.1 * noise(uv * 20.0));
		col = mix(col, base * 0.5, gap);
		rough = 0.9;
	} else if (m == 12) {
		// Boya: hafif parlak düz yüzey
		col = base * (0.97 + 0.06 * noise(uv * 4.0));
		rough = 0.45;
	} else if (m == 14) {
		// Mozaik (terrazzo): cilalı zemin içinde renkli taş kırıntıları
		vec2 cell = floor(uv * 55.0);
		float h = hash(cell);
		vec3 chip = mix(vec3(0.32, 0.28, 0.25), vec3(0.96, 0.94, 0.89), hash(cell + 3.1));
		chip = mix(chip, vec3(0.6, 0.28, 0.2), step(0.92, hash(cell + 7.7)));
		vec2 cell2 = floor(uv * 23.0);
		float big = step(0.86, hash(cell2 + 1.7));
		col = base * (0.93 + 0.08 * noise(uv * 6.0));
		col = mix(col, chip, step(0.6, h) * 0.7);
		col = mix(col, vec3(0.45, 0.42, 0.4), big * 0.35);
		rough = 0.28;
	} else if (m == 13) {
		// Kumaş
		col = base * (0.88 + 0.2 * noise(uv * 50.0));
		rough = 1.0;
	} else {
		// Sıva
		col = base * (0.95 + 0.1 * fbm(uv * 3.0));
		rough = 0.9;
	}
	// Genel kir/eskime
	col *= 1.0 - grain_amount + grain_amount * 2.0 * noise(uv * 0.9);
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emit;
}
