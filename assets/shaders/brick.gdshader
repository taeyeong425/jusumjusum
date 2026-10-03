// 레고 같은 플라스틱 + 윗면 스터드(동그란 돌기)를 그림으로. 돌기 지오메트리 없이 픽셀에서만.
// 스터드 간격은 월드 단위로 고정 — 크게 키운 덩어리엔 스터드가 더 많다 (진짜 브릭처럼).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec3 emission : source_color = vec3(0.0);
uniform float studs = 1.0;
uniform float pitch = 0.25;
uniform float gloss = 0.3;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
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
	ALBEDO = col;
	ROUGHNESS = gloss;
	SPECULAR = 0.6;
	EMISSION = emission;
}
