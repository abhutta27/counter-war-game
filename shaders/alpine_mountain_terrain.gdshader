shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Alpine Mountain PBR Shader - Broad Massif, Weathered Crag & Snow Drift Model
// Balances prominent dark rock ribs with wind-drifted alpine snow and deep valley shadows.

uniform vec3 snow_color : source_color = vec3(0.95, 0.96, 0.98);
uniform vec3 snow_shadow_color : source_color = vec3(0.65, 0.76, 0.88);
uniform vec3 dark_rock_color : source_color = vec3(0.12, 0.14, 0.18);
uniform vec3 mid_rock_color : source_color = vec3(0.22, 0.25, 0.30);
uniform vec3 cliff_strata_color : source_color = vec3(0.08, 0.09, 0.11);

uniform float slope_threshold : hint_range(0.1, 0.9) = 0.58; // Exposes more rock on steep flanks
uniform float slope_sharpness : hint_range(0.01, 0.5) = 0.18;
uniform float snow_roughness : hint_range(0.1, 1.0) = 0.80;
uniform float rock_roughness : hint_range(0.1, 1.0) = 0.94;
uniform float snowline_altitude : hint_range(-50.0, 100.0) = -5.0;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

// Fast procedural 3D noise
float hash(vec3 p) {
    p = fract(p * 0.3183099 + vec3(0.1, 0.1, 0.1));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3d(vec3 x) {
    vec3 p = floor(x);
    vec3 w = fract(x);
    vec3 u = w * w * (3.0 - 2.0 * w);
    return mix(mix(mix(hash(p + vec3(0.0, 0.0, 0.0)), hash(p + vec3(1.0, 0.0, 0.0)), u.x),
                   mix(hash(p + vec3(0.0, 1.0, 0.0)), hash(p + vec3(1.0, 1.0, 0.0)), u.x), u.y),
               mix(mix(hash(p + vec3(0.0, 0.0, 1.0)), hash(p + vec3(1.0, 0.0, 1.0)), u.x),
                   mix(hash(p + vec3(0.0, 1.0, 1.0)), hash(p + vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z);
}

float fractal_noise(vec3 p) {
    float n = 0.0;
    n += 0.5000 * noise3d(p * 1.0);
    n += 0.2500 * noise3d(p * 2.0);
    n += 0.1250 * noise3d(p * 4.0);
    return n;
}

void vertex() {
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    vec3 norm = normalize(v_world_normal);

    // Multi-frequency noise for natural terrain roughness
    float macro_noise = fractal_noise(v_world_pos * 0.04);
    float mid_noise = fractal_noise(v_world_pos * 0.18);
    float detail_noise = fractal_noise(v_world_pos * 0.65);

    // Geological rock stratification (horizontal shear layers)
    float strata = sin(v_world_pos.y * 0.8 + macro_noise * 4.0) * 0.5 + 0.5;
    vec3 rock_albedo = mix(dark_rock_color, mid_rock_color, strata * 0.8);
    rock_albedo = mix(rock_albedo, cliff_strata_color, step(0.82, sin(v_world_pos.y * 1.8 + detail_noise * 3.0)) * 0.5);

    // Micro surface roughness for craggy rock faces
    vec3 rock_bump = vec3((detail_noise - 0.5) * 0.35, 0.0, (mid_noise - 0.5) * 0.35);

    // Slope calculation with organic ledge feathering
    // Surfaces steeper than ~45 degrees shed snow, exposing crags
    float effective_slope = norm.y + (macro_noise - 0.5) * 0.40 + (detail_noise - 0.5) * 0.20;

    // Altitude modulation
    float altitude_bonus = clamp((v_world_pos.y - snowline_altitude) * 0.004, -0.10, 0.25);
    effective_slope += altitude_bonus;

    float snow_mask = smoothstep(slope_threshold - slope_sharpness, slope_threshold + slope_sharpness, effective_slope);

    // Wind-drift ripples on snow
    float snow_drift = sin(v_world_pos.x * 0.6 + v_world_pos.z * 0.4 + mid_noise * 3.0) * 0.06;
    vec3 snow_albedo = mix(snow_shadow_color, snow_color, 0.85 + snow_drift);

    // Apply micro rock bump on steep faces
    vec3 final_normal = normalize(norm + rock_bump * (1.0 - snow_mask));
    NORMAL = (VIEW_MATRIX * vec4(final_normal, 0.0)).xyz;

    // Composite Final PBR Material
    ALBEDO = mix(rock_albedo, snow_albedo, snow_mask);
    ROUGHNESS = mix(rock_roughness, snow_roughness, snow_mask);
    METALLIC = mix(0.04, 0.01, snow_mask);
    SPECULAR = mix(0.20, 0.50, snow_mask);

    // Crystalline winter snow rim effect in sunlight
    RIM = mix(0.05, 0.55, snow_mask);
    RIM_TINT = 0.40;
}
