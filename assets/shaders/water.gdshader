// 바다: 움직이는 물결 (정점 높이 + 색 섞기)
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 deep : source_color = vec4(0.12, 0.38, 0.6, 1.0);
uniform vec4 shallow : source_color = vec4(0.3, 0.65, 0.8, 1.0);

varying float h;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	h = sin(w.x * 0.35 + TIME * 1.2) * 0.5 + sin(w.z * 0.5 - TIME * 0.9) * 0.5;
	VERTEX.y += h * 0.18;
}

void fragment() {
	ALBEDO = mix(deep.rgb, shallow.rgb, h * 0.3 + 0.35);
	ROUGHNESS = 0.15;
	SPECULAR = 0.7;
}
