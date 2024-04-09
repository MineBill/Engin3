#version 450

#include "common.glsl"

layout(set = 0, binding = 0) uniform Uniform_Block {
    View_Data view_data;
    Scene_Data scene_data;
};

layout(set = 1, binding = 0) uniform Material_Block {
    Material material;
};

layout(set = 1, binding = 1) uniform sampler2D albedo_map;
layout(set = 1, binding = 2) uniform sampler2D normal_map;
layout(set = 0, binding = 1) uniform sampler2D shadow_map;

layout(location = 0) in VS_OUT {
    vec3 fragColor;
    vec2 fragTexCoord;
    vec3 fragNormal;
    vec3 fragPos;

    vec4 pos_light_space;
} OUT;

layout(location = 0) out vec4 outColor;

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
    // NOTE(minebill): This can also be done by setting a border and texture clamp (for x,y).
    if (shadowCoords.z > 1.0  || shadowCoords.x > 1.0 || shadowCoords.x < 0.0)
        return 1.0;
    shadowCoords.y *= -1;
    float bias = max((1.0/2048.0) * (1.0 - dot(OUT.fragNormal, normalize(scene_data.main_light.direction.xyz))), 0.005);
    
    /* if(texture(shadow_map, shadowCoords.xy).r < shadowCoords.z - bias) {
        shadow = 0.0;
    } */

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


void main() {
    vec3 tex = vec3(texture(albedo_map, OUT.fragTexCoord));

    vec3 ambient = scene_data.ambient_color.rgb * scene_data.ambient_color.a * tex;
    vec3 norm = normalize(OUT.fragNormal);
    vec3 lightDir = -normalize(scene_data.main_light.direction.xyz);
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diff * scene_data.main_light.color.xyz * tex;

    vec3 view_dir = normalize(scene_data.view_position.xyz - OUT.fragPos);
    vec3 reflected_light = reflect(-lightDir, norm);
    float spec = pow(max(dot(view_dir, reflected_light), 0.0), 32) * material.roughness;
    vec3 specular = spec * scene_data.main_light.color.xyz;

    float shadow = ShadowCalculation(OUT.pos_light_space);
    vec3 result = (ambient + (shadow) * (diffuse + specular)) * vec3(material.albedo_color);
    outColor = vec4(result, 1.0);
    // outColor.rgb = pow(outColor.rgb, vec3(1/2.2));
    // outColor = vec4(1, 0, 0, 1);
}
