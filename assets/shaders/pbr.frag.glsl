#version 460 core

#define MAX_SPOTLIGHTS  10
#define MAX_POINTLIGHTS 10
const float PI = 3.14159265359;

#include "common.glsl"
#include "lighting.glsl"
#include "editor.glsl"
// #include "shadow.glsl"

layout(location = 0) in VS_IN {
    vec3 frag_color;
    vec2 frag_uv;
    vec3 frag_pos;
    vec3 normal;

    vec3 tangent_light_dir;
    vec3 tangent_view_pos;
    vec3 tangent_frag_pos;

    vec4 pos_light_space;
} IN;

layout(location = 0) out vec4 out_color;

#ifdef EDITOR_H
layout(location = 1) out int out_id;
#endif

float SampleShadow(sampler2D map, vec2 coords, float compare) {
    return step(compare, texture(map, coords).r);
}

float SampleShadowLinear(sampler2D map, vec2 coords, float compare, vec2 texel_size) {
    vec2 pp = coords / texel_size + vec2(0.5);
    vec2 fraction = fract(pp);
    vec2 texel = (pp - fraction) * texel_size;

    float a = SampleShadow(map, texel, compare);
    float b = SampleShadow(map, texel + vec2(1.0, 0.0) * texel_size, compare);
    float c = SampleShadow(map, texel + vec2(0.0, 1.0) * texel_size, compare);
    float d = SampleShadow(map, texel + vec2(1.0, 1.0) * texel_size, compare);

    float aa = mix(a, c, fraction.y);
    float bb = mix(b, d, fraction.y);

    return mix(aa, bb, fraction.x);
}

float ShadowCalculation(vec4 fragPosLightSpace) {
    float shadow = 0.0;
    vec3 shadowCoords = (fragPosLightSpace.xyz / fragPosLightSpace.w);
    shadowCoords = shadowCoords * 0.5 + 0.5;

    if (shadowCoords.z > 1.0)
        return 1.0;
    float bias = max((1.0/4096.0) * (1.0 - dot(IN.normal, normalize(lights.directional.direction.xyz))), 0.003);
    vec2 texel_size = 1.0 / textureSize(shadow_map, 0);

    const float SAMPLES = 3;
    const float SAMPLES_START = (SAMPLES - 1) / 2;
    const float SAMPLES_SQUARED = SAMPLES * SAMPLES;
    for (float x = -SAMPLES_START; x <= SAMPLES_START; x++) {
        for (float y = -SAMPLES_START; y <= SAMPLES_START; y++) {
            shadow += SampleShadowLinear(shadow_map, shadowCoords.xy + vec2(x, y) * texel_size, shadowCoords.z - bias, texel_size);
        }
    }

    return shadow / SAMPLES_SQUARED;
}

// f0:  Surface reflection at zero iradiance, when looking at the fragment directly.
//      Usually hardcoded as vec3(0.04) for non-metallic surfaces.
//      For metals, it's the 'tint'.
vec3 FrenselSchlick(float cos_theta, vec3 f0) {
    return f0 + (1 - f0) * pow(clamp(1 - cos_theta, 0.0, 1.0), 5.0);
}

float DistributionGGX(vec3 N, vec3 H, float roughness) {
    float a      = roughness*roughness;
    float a2     = a*a;
    float NdotH  = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;

    float num   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return num / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;

    float num   = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return num / denom;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2  = GeometrySchlickGGX(NdotV, roughness);
    float ggx1  = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

vec3 do_directional_light() {
    // vec3 N = normalize(IN.normal);
    vec3 N = texture(normal_map, IN.frag_uv).rgb;
    N = normalize(N * 2.0 - 1);
    // vec3 V = normalize(scene_data.view_position.xyz - IN.frag_pos);
    vec3 V = normalize(IN.tangent_view_pos.xyz - IN.tangent_frag_pos);

    vec3 L = normalize(IN.tangent_light_dir);
    vec3 H = normalize(V + L);

    vec3 radiance = lights.directional.color.rgb;

    vec3 F0 = vec3(0.04);
    vec3 albedo = texture(albedo_map, IN.frag_uv).rgb;
    F0 = mix(F0, material.albedo_color.rgb * albedo, material.metallic);

    vec3 F = FrenselSchlick(max(dot(H, V), 0.0), F0);
    float NDF = DistributionGGX(N, H, material.roughness);
    float G = GeometrySmith(N, V, L, material.roughness);

    vec3 numerator = NDF * G * F;
    float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
    vec3 specular = numerator / denominator;

    vec3 ks = F;
    vec3 kd = vec3(1.0) - ks;
    kd *= 1.0 - material.metallic;

    vec3 I = IN.frag_pos - scene_data.view_position.xyz;
    vec3 R = reflect(I, normalize(IN.normal));
    vec3 reflection = texture(reflection_map, R).rgb;

    float NdotL = max(dot(N, L), 0.0);

    float shadow = ShadowCalculation(IN.pos_light_space);

    return (kd * material.albedo_color.rgb * albedo / PI + specular + reflection * material.metallic * ks) * radiance * NdotL * shadow;
}

vec3 do_point_light(PointLight light) {
    return vec3(0.0, 0.0, 0.0);
}

void main() {

    vec3 Lo = vec3(0.0);

    Lo += do_directional_light();

    for (int i = 0; i < num_point_lights; i++) {
        Lo += do_point_light(lights.pointlights[i]);
    }

    out_color = vec4(Lo, 1.0);

#ifdef EDITOR_H
    out_id = gameobject_id;
#endif
}
