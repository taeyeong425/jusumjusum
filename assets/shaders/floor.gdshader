// 바닥: 나무 판자 · 체크 타일 · 대리석 · 카펫. 월드 좌표 기준이라 이음새 없이 이어진다.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform int style = 0;            // 0 판자 · 1 타일 · 2 대리석 · 3 카펫
uniform vec4 col_a : source_color = vec4(0.7, 0.5, 0.3, 1.0);
uniform vec4 col_b : source_color = vec4(0.6, 0.42, 0.25, 1.0);
uniform float scale = 1.0;
uniform float gloss = 0.5;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wpos.xz / scale;
	vec3 c = col_a.rgb;
	float rough = gloss;
	if (style == 0) {
		// 판자: 폭 0.4, 줄마다 길이 방향으로 어긋난 이음새
		float row = floor(p.y / 0.4);
		float off = hash(vec2(row, 3.0)) * 3.0;
		float seg = floor((p.x + off) / 2.4);
		float t = hash(vec2(row, seg));
		c = mix(col_a.rgb, col_b.rgb, t);
		float grain = noise(vec2((p.x + off) * 1.5, p.y * 30.0));
		c *= 0.9 + 0.12 * grain;
		float ey = abs(fract(p.y / 0.4) - 0.5) * 2.0;
		float ex = abs(fract((p.x + off) / 2.4) - 0.5) * 2.0;
		float aa = fwidth(p.y / 0.4) * 2.0;
		float seam = max(smoothstep(1.0 - 0.06 - aa, 1.0 - aa * 0.5, ey), smoothstep(1.0 - 0.012 - aa, 1.0, ex));
		c *= 1.0 - 0.35 * seam;
	} else if (style == 1) {
		// 체크 타일 0.6
		vec2 q = floor(p / 0.6);
		float k = mod(q.x + q.y, 2.0);
		c = mix(col_a.rgb, col_b.rgb, k);
		vec2 f = abs(fract(p / 0.6) - 0.5) * 2.0;
		float aa = fwidth(p.x / 0.6) * 2.0;
		float grout = smoothstep(1.0 - 0.05 - aa, 1.0, max(f.x, f.y));
		c = mix(c, c * 0.75, grout);
	} else if (style == 2) {
		// 대리석: 큰 타일 + 물결 무늬
		vec2 q = floor(p / 1.2);
		float n = noise(p * 1.3) * 0.6 + noise(p * 4.0) * 0.3;
		float vein = smoothstep(0.02, 0.0, abs(sin((p.x + p.y) * 2.0 + n * 6.0)) - 0.97 + 0.97) ;
		c = mix(col_a.rgb, col_b.rgb, n * 0.5 + hash(q) * 0.25);
		c = mix(c, c * 0.8, vein * 0.4);
		vec2 f = abs(fract(p / 1.2) - 0.5) * 2.0;
		float aa = fwidth(p.x / 1.2) * 2.0;
		c *= 1.0 - 0.18 * smoothstep(1.0 - 0.02 - aa, 1.0, max(f.x, f.y));
		rough = gloss * 0.6;
	} else {
		// 카펫: 고운 결 + 무늬 테두리
		float n = noise(p * 25.0);
		c = col_a.rgb * (0.92 + 0.12 * n);
		rough = 0.95;
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = 0.4;
}
