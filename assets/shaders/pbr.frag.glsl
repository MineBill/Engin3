#version 450 core

#define MAX_SPOTLIGHTS  10
#define MAX_POInTLIGHTS 10
const float PI = 3.14159265359;

#include "common.glsl"
#include "lighting.glsl"

struct VertexOutput {
    vec3 frag_color;
    vec2 frag_uv;
    vec3 frag_pos;
    vec3 normal;

    vec3 tangent_light_dir;
    vec3 tangent_view_pos;
    vec3 tangent_frag_pos;

    vec4 pos_light_space[4];
};

layout(location = 0) in VertexOutput In;

layout(location = 0) out vec4 o_Color;
layout(location = 1) out vec4 o_BrightColor;

#ifdef EDITOR
layout(location = 2) out int o_ID;
#endif

float SampleShadow(float index, vec2 coords, float compare) {
    return step(compare, texture(shadow_map, vec3(coords, index)).r);
}

float SampleShadowLinear(float index, vec2 coords, float compare, vec2 texel_size) {
    vec2 pp = coords / texel_size + vec2(0.5);
    vec2 fraction = fract(pp);
    vec2 texel = (pp - fraction) * texel_size;

    float a = SampleShadow(index, texel, compare);
    float b = SampleShadow(index, texel + vec2(1.0, 0.0) * texel_size, compare);
    float c = SampleShadow(index, texel + vec2(0.0, 1.0) * texel_size, compare);
    float d = SampleShadow(index, texel + vec2(1.0, 1.0) * texel_size, compare);

    float aa = mix(a, c, fraction.y);
    float bb = mix(b, d, fraction.y);

    return mix(aa, bb, fraction.x);
}

float ShadowCalculation() {
    float shadow = 0.0;
    float index = 0;

    if (1.0 - gl_FragCoord.z < u_LightData.shadow_split_distances.x) {
        index = 3;
    } else if (1.0 - gl_FragCoord.z < u_LightData.shadow_split_distances.y) {
        index = 2;
    } else if (1.0 - gl_FragCoord.z < u_LightData.shadow_split_distances.z) {
        index = 1;
    }

    vec4 fragPosLightSpace = In.pos_light_space[int(index)];
    vec3 shadowCoords = (fragPosLightSpace.xyz / fragPosLightSpace.w);
    shadowCoords = shadowCoords * 0.5 + 0.5;

    if (shadowCoords.z > 1.0)
        return 1.0;
    float bias = max((1.0/4096.0) * (1.0 - dot(In.normal, normalize(u_LightData.directional.direction.xyz))), 0.003);
    // vec2 texel_size = 1.0 / textureSize(shadow_map, 0).xy;
    ivec3 textureSize = textureSize(shadow_map, 0); // Get the size of the texture at level 0
    vec2 texel_size = vec2(1.0) / vec2(textureSize.xy);

    const float SAMPLES = 3;
    const float SAMPLES_START = (SAMPLES - 1) / 2;
    const float SAMPLES_SQUARED = SAMPLES * SAMPLES;
    for (float x = -SAMPLES_START; x <= SAMPLES_START; x++) {
        for (float y = -SAMPLES_START; y <= SAMPLES_START; y++) {
            shadow += SampleShadowLinear(index, shadowCoords.xy + vec2(x, y) * texel_size, shadowCoords.z - bias, texel_size);
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
    // vec3 N = normalize(In.normal);
    vec3 N = texture(normal_map, In.frag_uv).rgb;
    N = normalize(N * 2.0 - 1);
    // vec3 V = normalize(u_SceneData.view_position.xyz - In.frag_pos);
    vec3 V = normalize(In.tangent_view_pos.xyz - In.tangent_frag_pos);

    vec3 L = normalize(In.tangent_light_dir);
    vec3 H = normalize(V + L);

    vec3 radiance = u_LightData.directional.color.rgb;

    vec3 F0 = vec3(0.04);
    vec3 albedo = texture(albedo_map, In.frag_uv).rgb;
    F0 = mix(F0, u_MaterialData.albedo_color.rgb * albedo, u_MaterialData.metallic);

    vec3 F = FrenselSchlick(max(dot(H, V), 0.0), F0);
    float NDF = DistributionGGX(N, H, u_MaterialData.roughness);
    float G = GeometrySmith(N, V, L, u_MaterialData.roughness);

    vec3 numerator = NDF * G * F;
    float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
    vec3 specular = numerator / denominator;

    vec3 ks = F;
    vec3 kd = vec3(1.0) - ks;
    kd *= 1.0 - u_MaterialData.metallic;

    vec3 I = In.frag_pos - u_SceneData.view_position.xyz;
    vec3 R = reflect(I, normalize(In.normal));
    vec3 reflection = texture(reflection_map, R).rgb;

    float NdotL = max(dot(N, L), 0.0);

    float shadow = ShadowCalculation();

    vec3 ambient = u_SceneData.ambient_color.rgb * albedo * u_MaterialData.albedo_color.rgb * 0.1;

    return ambient + (kd * u_MaterialData.albedo_color.rgb * albedo / PI + specular + reflection * u_MaterialData.metallic * ks) * radiance * NdotL * shadow;
}

vec3 do_point_light(PointLight light) {
    return vec3(0.0, 0.0, 0.0);
}

void main() {

    vec3 Lo = vec3(0.0);

    Lo += do_directional_light();

    /* for (int i = 0; i < u_LightData.num_point_lights; i++) {
        Lo += do_point_light(u_LightData.pointlights[i]);
    } */

    o_Color = vec4(Lo, 1.0);

    float brightness = dot(o_Color.rgb, vec3(0.2126, 0.7152, 0.0722));
    if (brightness > 1.0) {
        o_BrightColor = vec4(o_Color.rgb, 1.0);
    } else {
        o_BrightColor = vec4(0.0, 0.0, 0.0, 1.0);
    }

#ifdef EDITOR
    o_ID = u_PerObjectData.entity_id;
#endif
}
