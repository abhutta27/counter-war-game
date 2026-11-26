shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Textures
uniform sampler2D rock_diffuse : source_color, filter_linear_mipmap;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap;
uniform sampler2D rock_roughness : hint_default_white, filter_linear_mipmap;

uniform sampler2D snow_diffuse : source_color, filter_linear_mipmap;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap;
uniform sampler2D snow_roughness : hint_default_white, filter_linear_mipmap;

// Terrain parameters
uniform float uv_scale : hint_range(0.01, 1.0) = 0.08;
uniform float snow_height_threshold : hint_range(0.0, 50.0) = 10.0;
uniform float snow_blend_softness : hint_range(0.1, 10.0) = 3.5;
uniform float slope_snow_cutoff : hint_range(0.0, 1.0) = 0.65;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv_xz = v_world_pos.xz * uv_scale;
	vec2 uv_xy = v_world_pos.xy * uv_scale;
	vec2 uv_zy = v_world_pos.zy * uv_scale;

	vec3 blend_weights = abs(v_world_normal);
	blend_weights = normalize(max(blend_weights, 0.00001));
	float b_sum = blend_weights.x + blend_weights.y + blend_weights.z;
	blend_weights /= b_sum;

	// Triplanar sampling for Rock
	vec4 rock_col = texture(rock_diffuse, uv_xz) * blend_weights.y +
	                texture(rock_diffuse, uv_xy) * blend_weights.z +
	                texture(rock_diffuse, uv_zy) * blend_weights.x;
	float rock_rough = (texture(rock_roughness, uv_xz).r * blend_weights.y +
	                    texture(rock_roughness, uv_xy).r * blend_weights.z +
	                    texture(rock_roughness, uv_zy).r * blend_weights.x);

	// Triplanar sampling for Snow
	vec4 snow_col = texture(snow_diffuse, uv_xz) * blend_weights.y +
	                texture(snow_diffuse, uv_xy) * blend_weights.z +
	                texture(snow_diffuse, uv_zy) * blend_weights.x;
	float snow_rough = (texture(snow_roughness, uv_xz).r * blend_weights.y +
	                    texture(snow_roughness, uv_xy).r * blend_weights.z +
	                    texture(snow_roughness, uv_zy).r * blend_weights.x);

	// Calculate snow mask based on upward normal slope and world Y elevation
	float slope_factor = smoothstep(slope_snow_cutoff, slope_snow_cutoff + 0.25, v_world_normal.y);
	float height_factor = smoothstep(snow_height_threshold - snow_blend_softness, snow_height_threshold + snow_blend_softness, v_world_pos.y);
	float snow_amount = clamp(slope_factor * height_factor, 0.0, 1.0);

	// Blend rock and snow
	vec3 final_albedo = mix(rock_col.rgb, snow_col.rgb, snow_amount);
	float final_roughness = mix(rock_rough, snow_rough, snow_amount);

	ALBEDO = final_albedo;
	ROUGHNESS = final_roughness;
	SPECULAR = 0.25;
}
