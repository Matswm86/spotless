shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Layered makeover material. The mask is painted by the player's tools and projected
// onto the object from the camera's point of view (mask_xform maps world -> mask space).
// mask_tex: R = loose dirt removed, G = grime removed, B = new paint, A = foam.
// mask2_tex: R = polish.

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform sampler2D mask2_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float use_albedo_tex = 0.0;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 paint_color : source_color = vec4(1.0);
uniform float paintable = 0.0;
uniform float has_mud = 1.0;
uniform vec4 mud_a : source_color = vec4(0.36, 0.27, 0.18, 1.0);
uniform vec4 mud_b : source_color = vec4(0.22, 0.16, 0.10, 1.0);
uniform float grime_amount = 1.0;
uniform vec4 grime_a : source_color = vec4(0.45, 0.52, 0.18, 1.0);
uniform vec4 grime_b : source_color = vec4(0.25, 0.32, 0.12, 1.0);
uniform float grime_rough = 0.9;
uniform float metallic_clean = 0.0;
uniform float rough_clean = 0.35;
uniform float rough_dull = 0.8;
uniform float fade = 0.75;
uniform mat4 mask_xform;
uniform vec4 floors = vec4(0.0);
uniform float foam_max = 1.0;
uniform float polish_floor = 0.0;
uniform float show_before = 0.0;
uniform float noise_scale = 2.2;
uniform vec2 noise_offset = vec2(0.0);

varying vec3 mpos;

void vertex() {
	vec4 w = MODEL_MATRIX * vec4(VERTEX, 1.0);
	mpos = (mask_xform * w).xyz;
}

float band(float v, float edge, float w) {
	return smoothstep(edge - w, edge + w, v);
}

void fragment() {
	vec2 muv = mpos.xy;
	vec4 m = texture(mask_tex, muv);
	float pol = texture(mask2_tex, muv).r;
	m.rgb = max(m.rgb, floors.rgb);
	m.a = min(max(m.a, floors.a), foam_max);
	pol = max(pol, polish_floor);
	if (show_before > 0.5) {
		m = vec4(0.0);
		pol = 0.0;
	}
	vec2 nuv = muv * noise_scale + noise_offset + vec2(mpos.z * 0.31, mpos.z * 0.17);
	vec4 n = texture(noise_tex, nuv);
	vec4 n2 = texture(noise_tex, nuv * 3.3 + vec2(0.31, 0.77));

	vec3 base = base_color.rgb;
	if (use_albedo_tex > 0.5) {
		base *= texture(albedo_tex, UV).rgb;
	}
	// New paint follows the brush with a slightly ragged edge.
	float pe = band(m.b, 0.28 + n2.b * 0.3, 0.05) * paintable;
	base = mix(base, paint_color.rgb, pe);

	// Before polishing, everything looks faded, yellowed and matte.
	float dull = 1.0 - pol;
	float lum = dot(base, vec3(0.3, 0.59, 0.11));
	vec3 faded = mix(base, vec3(lum), 0.35) * 0.8 + vec3(0.035, 0.028, 0.0);
	vec3 alb = mix(base, faded, dull * fade);
	float rough = mix(rough_clean, rough_dull, dull);
	float metal = metallic_clean * (0.55 + 0.45 * pol);

	// Grime (moss, rust, grease, stains): patchy, removed by scrubbing, grinding or rinsing.
	float gcov = smoothstep(0.34, 0.58, n.r * 0.65 + n.g * 0.55) * grime_amount;
	float gleft = 1.0 - m.g;
	float gedge = 0.22 + n2.g * 0.5;
	float gvis = gcov * band(gleft, gedge, 0.04);
	float grim = gcov * (1.0 - gvis) * (1.0 - clamp(abs(gleft - gedge + 0.08) / 0.08, 0.0, 1.0));
	vec3 gcol = mix(grime_a.rgb, grime_b.rgb, smoothstep(0.25, 0.75, n2.r * 0.6 + n.g * 0.4));
	gcol *= 0.9 + 0.2 * n.b;
	alb = mix(alb, gcol, gvis);
	alb *= 1.0 - 0.3 * grim;
	rough = mix(rough, grime_rough, gvis);
	metal *= 1.0 - gvis;

	// Loose dirt (mud, dust): almost full cover, blasted off by water or vacuum.
	float mcov = has_mud * smoothstep(0.08, 0.3, n.g * 0.8 + n.b * 0.4);
	float mleft = 1.0 - m.r;
	float medge = 0.2 + n2.b * 0.55;
	float mvis = mcov * band(mleft, medge, 0.035);
	float mrim = mcov * (1.0 - mvis) * (1.0 - clamp(abs(mleft - medge + 0.07) / 0.07, 0.0, 1.0));
	vec3 mcol = mix(mud_a.rgb, mud_b.rgb, smoothstep(0.3, 0.8, n.r * 0.6 + n2.g * 0.4));
	mcol *= 0.9 + 0.2 * n2.b;
	alb = mix(alb, mcol, mvis);
	alb *= 1.0 - 0.35 * mrim;
	rough = mix(rough, 0.97, mvis);
	metal *= 1.0 - mvis;

	// Soap foam sits on top of everything.
	vec4 nb = texture(noise_tex, muv * noise_scale * 2.4 + noise_offset);
	float fedge = 0.12 + n.a * 0.3;
	float fvis = band(m.a, fedge, 0.05);
	float bub = nb.a;
	vec3 fcol = vec3(0.97, 0.98, 1.0) * (0.72 + 0.28 * smoothstep(0.1, 0.9, bub));
	alb = mix(alb, fcol, fvis);
	rough = mix(rough, 0.25, fvis);
	metal *= 1.0 - fvis;

	// Crusty relief for dirt, grime and foam, from screen-space derivatives (no tangents needed).
	float hgt = mvis * (0.6 + 0.4 * n2.b) * 0.7 + gvis * (0.5 + 0.5 * n2.r) * 0.5 + fvis * bub * 0.8;
	vec3 bump = vec3(dFdx(hgt), -dFdy(hgt), 0.0);
	NORMAL = normalize(NORMAL - bump * 14.0);
	// Keep pure white from blowing out so shading stays readable.
	alb = min(alb, vec3(0.9));
	ALBEDO = alb;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = mix(0.5, 0.7, pol);
	// Tiny glints once an area is polished.
	float glint = smoothstep(0.93, 1.0, n2.b) * pol * (1.0 - mvis) * (1.0 - gvis) * (1.0 - fvis);
	glint *= 0.5 + 0.5 * sin(TIME * 2.5 + n.r * 40.0);
	EMISSION = vec3(1.0, 0.97, 0.9) * glint * 0.6;
}
