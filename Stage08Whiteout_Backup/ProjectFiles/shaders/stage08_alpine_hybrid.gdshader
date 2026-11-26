shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D snow_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_arm : filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_arm : filter_linear_mipmap, repeat_enable;
uniform float texture_scale = 0.032;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 base_normal = normalize(world_normal);
	if (base_normal.y < 0.0) {
		base_normal = -base_normal;
	}

	// Triplanar blend weights for rock on steep vertical cliffs
	vec3 blend_weights = pow(abs(base_normal), vec3(4.0));
	blend_weights /= max(0.0001, blend_weights.x + blend_weights.y + blend_weights.z);

	vec2 terrain_uv = world_position.xz * texture_scale;
	vec3 rock_x = texture(rock_albedo, world_position.zy * texture_scale).rgb;
	vec3 rock_y = texture(rock_albedo, world_position.xz * texture_scale).rgb;
	vec3 rock_z = texture(rock_albedo, world_position.xy * texture_scale).rgb;
	vec3 rock_color_sample = rock_x * blend_weights.x + rock_y * blend_weights.y + rock_z * blend_weights.z;

	vec3 snow_color_sample = texture(snow_albedo, terrain_uv).rgb;

	// Slope-based exposure: steep cliffs (base_normal.y < 0.56) expose dark rugged rock
	float slope_exposure = smoothstep(0.46, 0.72, base_normal.y);
	float breakup = dot(snow_color_sample, vec3(0.299, 0.587, 0.114));
	float snow_mask = smoothstep(0.30, 0.70, slope_exposure + (breakup - 0.5) * 0.20);

	vec3 snow_n = texture(snow_normal, terrain_uv).xyz * 2.0 - 1.0;
	vec3 rock_n = texture(rock_normal, terrain_uv).xyz * 2.0 - 1.0;
	vec3 snow_pbr = texture(snow_arm, terrain_uv).rgb;
	vec3 rock_pbr = texture(rock_arm, terrain_uv).rgb;

	vec3 tangent = normalize(vec3(1.0, 0.0, 0.0) - base_normal * dot(base_normal, vec3(1.0, 0.0, 0.0)));
	vec3 bitangent = normalize(cross(tangent, base_normal));
	vec3 mapped_snow = normalize(tangent * snow_n.x + bitangent * snow_n.y + base_normal * snow_n.z);
	vec3 mapped_rock = normalize(tangent * rock_n.x + bitangent * rock_n.y + base_normal * rock_n.z);
	vec3 mapped_normal = normalize(mix(mapped_rock, mapped_snow, snow_mask));

	ALBEDO = mix(rock_color_sample * vec3(0.85, 0.88, 0.92), snow_color_sample * vec3(1.08, 1.10, 1.12), snow_mask);
	ROUGHNESS = mix(rock_pbr.g, snow_pbr.g, snow_mask);
	AO = mix(rock_pbr.r, snow_pbr.r, snow_mask);
	METALLIC = mix(rock_pbr.b, snow_pbr.b, snow_mask);
	AO_LIGHT_AFFECT = 0.45;
	SPECULAR = mix(0.20, 0.35, snow_mask);
	NORMAL = (VIEW_MATRIX * vec4(mapped_normal, 0.0)).xyz;
}
