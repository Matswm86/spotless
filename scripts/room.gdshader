shader_type spatial;
render_mode diffuse_burley;

// Procedural surfaces for the backdrops: 0 plain, 1 tiles, 2 striped wallpaper, 3 planks,
// 4 concrete, 5 grass, 6 asphalt, 7 bricks, 8 marble.
uniform int pattern = 0;
uniform vec4 col_a : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform vec4 col_b : source_color = vec4(0.7, 0.7, 0.7, 1.0);
uniform vec2 uv_scale = vec2(4.0, 4.0);
uniform float edge_shade = 0.0;
uniform float rough = 0.8;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

float line(float v, float w) {
	float f = abs(fract(v) - 0.5);
	return smoothstep(0.5 - w, 0.5 - w * 0.5, f);
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec4 n = texture(noise_tex, uv * 0.13);
	vec4 n2 = texture(noise_tex, uv * 0.9);
	vec3 c = col_a.rgb;
	float r = rough;
	if (pattern == 1) {
		float g = max(line(uv.x, 0.03), line(uv.y, 0.03));
		vec2 cell = floor(uv);
		float v = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
		c = col_a.rgb * (0.95 + 0.08 * v) * (0.97 + 0.06 * n2.b);
		c = mix(c, col_b.rgb, g);
		r = mix(0.15, 0.9, g);
	} else if (pattern == 2) {
		float s = step(0.5, fract(uv.x));
		float thin = line(uv.x * 2.0 + 0.5, 0.02);
		c = mix(col_a.rgb, col_b.rgb, s * 0.55);
		c = mix(c, col_b.rgb * 0.85, thin * 0.6);
		c *= 0.96 + 0.06 * n.g;
	} else if (pattern == 3) {
		float row = floor(uv.y);
		float off = fract(sin(row * 37.1) * 911.3) * 4.0;
		float seam = max(line(uv.y, 0.025), line((uv.x + off) / 4.0, 0.006));
		float grain = texture(noise_tex, vec2(uv.x * 0.08, uv.y * 1.3 + row * 0.37)).g;
		float tone = fract(sin(row * 13.7 + floor((uv.x + off) / 4.0) * 7.3) * 431.7);
		c = mix(col_a.rgb, col_b.rgb, 0.35 * tone + 0.5 * smoothstep(0.35, 0.7, grain));
		c *= 1.0 - 0.45 * seam;
		r = 0.45 + 0.3 * seam;
	} else if (pattern == 4) {
		c = mix(col_a.rgb, col_b.rgb, smoothstep(0.3, 0.8, n.r) * 0.6 + n2.b * 0.3);
		float j = max(line(uv.x * 0.25, 0.004), line(uv.y * 0.25, 0.004));
		c *= 1.0 - 0.35 * j;
	} else if (pattern == 5) {
		c = mix(col_a.rgb, col_b.rgb, smoothstep(0.25, 0.75, n.g) * 0.7 + n2.b * 0.3);
		r = 0.95;
	} else if (pattern == 6) {
		c = mix(col_a.rgb, col_b.rgb, n2.b * 0.6 + n.r * 0.3);
		r = 0.9;
	} else if (pattern == 7) {
		float row = floor(uv.y);
		float bx = uv.x * 0.5 + (mod(row, 2.0) * 0.5);
		float g = max(line(uv.y, 0.06), line(bx, 0.03));
		float tone = fract(sin(dot(vec2(floor(bx), row), vec2(17.3, 91.7))) * 4375.5);
		c = mix(col_a.rgb, col_b.rgb, tone * 0.6) * (0.9 + 0.15 * n2.b);
		c = mix(c, vec3(0.82, 0.8, 0.76), g);
	} else if (pattern == 8) {
		float vein = smoothstep(0.47, 0.5, abs(sin(uv.x * 2.0 + n.r * 9.0 + n.g * 5.0)) * 0.5);
		c = mix(col_a.rgb, col_b.rgb, (1.0 - vein) * 0.5);
		r = 0.12;
	} else {
		c *= 0.97 + 0.06 * n.g;
	}
	// Darken the lower edge of walls a little (fake contact shadow with the floor).
	c *= 1.0 - edge_shade * (1.0 - smoothstep(0.0, 0.18, 1.0 - UV.y));
	ALBEDO = c;
	ROUGHNESS = r;
}
