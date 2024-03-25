#version 450

#include "common.glsl"
#include "lighting.glsl"

layout(location = 0) out vec4 out_color;

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

vec3 do_directional_light(Directional_Light light) {
    vec3 tex = vec3(texture(albedo_map, IN.frag_uv));

    vec3 N = normalize(texture(normal_map, IN.frag_uv).rgb * 2.0 - 1.0);
    vec3 L = normalize(IN.tangent_light_dir);
    vec3 V = normalize(IN.tangent_view_pos - IN.tangent_frag_pos);

    vec3 I = IN.frag_pos - scene_data.view_position.xyz;
    vec3 R = reflect(I, normalize(IN.normal));
    vec4 reflection = texture(reflection_map, R);

    vec3 ambient = scene_data.ambient_color.rgb * tex * 0.1;
    vec3 diffuse = max(dot(N, L), 0.0) * light.color.rgb * tex;
    vec3 specular = pow(max(dot(normalize(L+V), N), 0.0), 128) * tex * (1 - material.roughness);
    diffuse *= max(vec3(1, 1, 1), reflection.xyz * (1 - material.roughness));

    float shadow = ShadowCalculation(IN.pos_light_space);
    // float shadow = 1.0;

    return (ambient + shadow * (specular + diffuse)) * material.albedo_color.rgb;
}

vec3 do_point_light(PointLight light) {
    vec3 tex = vec3(texture(albedo_map, IN.frag_uv));

    // vec3 N = normalize(texture(normal_map, IN.frag_uv).rgb * 2.0 - 1.0);
    vec3 N = normalize(IN.normal);
    vec3 L = normalize(light.position - IN.frag_pos);
    // vec3 V = normalize(IN.tangent_view_pos - IN.tangent_frag_pos);
    vec3 V = normalize(scene_data.view_position.xyz - IN.frag_pos);

    float distance = length(light.position - IN.frag_pos);
    float attenuation = 1.0 / (light.constant + light.linear * distance + 
                 light.quadratic * (distance * distance));

    vec3 ambient = scene_data.ambient_color.rgb * tex * 0.1;
    vec3 diffuse = max(dot(N, L), 0.0) * light.color.rgb * tex;
    vec3 specular = pow(max(dot(reflect(-L, N), V), 0.0), 32) * light.color.rgb * tex * (1 - material.roughness);

    diffuse *= attenuation;
    specular *= attenuation;

    // float shadow = ShadowCalculation(IN.pos_light_space);
    float shadow = 1.0;

    return (shadow * (specular + diffuse)) * material.albedo_color.rgb;
    // return vec3(1, 1, 1) * -10;
}

void main() {
    vec3 result = do_directional_light(lights.directional);

    // int num_point_lights = 0;
    for (int i = 0; i < num_point_lights; i++) {
        result += do_point_light(lights.pointlights[i]);
    }

    out_color = vec4(result, 1.0);
}
