// 레고 같은 플라스틱 + 윗면 스터드(동그란 돌기)를 그림으로. 돌기 지오메트리 없이 픽셀에서만.
// 스터드 간격은 월드 단위로 고정 — 크게 키운 덩어리엔 스터드가 더 많다 (진짜 브릭처럼).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec3 emission : source_color = vec3(0.0);
uniform float studs = 1.0;
uniform float pitch = 0.25;
uniform float gloss = 0.3;
uniform int finish = 0;    // 마감: 0 플라스틱 · 1 대리석 · 2 청동 · 3 나무 · 4 금 (조립 · 전시)

// 보물찾기: 캐릭터 앞을 가리는 벽 · 가구에 구멍을 뚫어 늘 보이게 (화면에서 캐릭터 주변 원)
global uniform vec3 seethru_pos;
global uniform float seethru_on;

varying vec3 wpos;
varying vec3 wnorm;
varying vec3 lpos;

float hsh(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float vnoise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hsh(i), hsh(i + vec3(1,0,0)), f.x), mix(hsh(i + vec3(0,1,0)), hsh(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hsh(i + vec3(0,0,1)), hsh(i + vec3(1,0,1)), f.x), mix(hsh(i + vec3(0,1,1)), hsh(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize(mat3(MODEL_MATRIX) * NORMAL);
	lpos = VERTEX;
}

void fragment() {
	if (seethru_on > 0.5) {
		vec4 pv = VIEW_MATRIX * vec4(seethru_pos, 1.0);
		vec4 pp = PROJECTION_MATRIX * pv;
		vec4 fp = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
		float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
		vec2 dd = (fp.xy / fp.w - pp.xy / pp.w) * vec2(aspect, 1.0);
		float r = length(dd);
		if (-VERTEX.z < -pv.z - 1.2) {
			float edge = smoothstep(0.16, 0.26, r);
			float n = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
			if (n > edge) {
				discard;
			}
		}
	}
	vec3 col = albedo.rgb;
	vec3 ay = normalize(MODEL_MATRIX[1].xyz);
	float up = dot(normalize(wnorm), ay);
	if (studs > 0.5 && up > 0.97) {
		vec3 ax = normalize(MODEL_MATRIX[0].xyz);
		vec3 az = normalize(MODEL_MATRIX[2].xyz);
		vec3 rel = wpos - MODEL_MATRIX[3].xyz;
		vec2 uv = vec2(dot(rel, ax), dot(rel, az)) / pitch;
		vec2 f = fract(uv) - 0.5;
		float d = length(f);
		float aa = max(fwidth(d) * 1.2, 0.01);
		float r = 0.31;
		// 멀어서 한 칸이 몇 픽셀 안 되면 흐리게 (반짝임 방지)
		float fade = 1.0 - smoothstep(0.18, 0.4, max(fwidth(uv.x), fwidth(uv.y)));
		float stud = 1.0 - smoothstep(r - aa, r + aa, d);
		// 오른쪽 아래로 떨어지는 그림자 · 돌기 윗면 밝게 · 가장자리 링
		float sh = (1.0 - smoothstep(r - aa, r + 0.06 + aa, length(f - vec2(0.07, 0.09)))) * (1.0 - stud);
		float rim = smoothstep(r - 0.09, r - 0.03, d) * stud;
		float hi = (1.0 - smoothstep(0.0, r * 0.9, length(f + vec2(0.08, 0.1)))) * stud;
		col = mix(col, col * 0.62, sh * 0.85 * fade);
		col = mix(col, col * 1.08 + vec3(0.025), stud * fade);
		col = mix(col, col * 0.8, rim * fade);
		col = mix(col, col + vec3(0.12), hi * 0.6 * fade);
	}
	// 실사 느낌: 표면의 미세한 얼룩 · 결 (페인트 · 플라스틱이 완전 단색이 아니게)
	float nz = vnoise(wpos * 1.7) * 0.6 + vnoise(wpos * 7.0) * 0.4;
	col *= 0.93 + 0.1 * nz;
	ALBEDO = col;
	ROUGHNESS = gloss + (nz - 0.5) * 0.15;
	if (finish == 1) {
		float v = vnoise(lpos * 9.0) * 0.6 + vnoise(lpos * 25.0) * 0.4;
		float vein = smoothstep(0.06, 0.0, abs(sin((lpos.x + lpos.y * 0.7 + lpos.z * 0.3) * 14.0 + v * 8.0)));
		vec3 base = vec3(0.93, 0.92, 0.89) * mix(vec3(1.0), albedo.rgb, 0.22);
		ALBEDO = mix(base, base * 0.55, vein * 0.7);
		ROUGHNESS = 0.18;
	} else if (finish == 2) {
		ALBEDO = mix(vec3(0.55, 0.36, 0.18), albedo.rgb * 0.5, 0.15) * (0.8 + 0.3 * nz);
		METALLIC = 0.85;
		ROUGHNESS = 0.32;
	} else if (finish == 3) {
		float rings = sin(length(lpos.xz) * 70.0 + vnoise(lpos * 6.0) * 6.0) * 0.5 + 0.5;
		ALBEDO = mix(vec3(0.58, 0.38, 0.21), vec3(0.42, 0.26, 0.13), rings) * mix(vec3(1.0), albedo.rgb, 0.18);
		ROUGHNESS = 0.6;
	} else if (finish == 4) {
		ALBEDO = vec3(0.95, 0.74, 0.3) * (0.85 + 0.2 * nz);
		METALLIC = 1.0;
		ROUGHNESS = 0.22;
	}
	SPECULAR = 0.6;
	EMISSION = emission;
}
