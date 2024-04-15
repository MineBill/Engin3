#version 450 core

#include "common.glsl"

#define SSAO_KERNEL_SIZE 64

layout(std140, binding = SSAO_BINDING_INDEX) uniform SSAOData {
    vec4 params;
    vec3 kernel[SSAO_KERNEL_SIZE];

    /* float radius;
    float bias; */
} u_SSAOData;

layout(binding = 0) uniform sampler2D s_Position;
layout(binding = 1) uniform sampler2D s_Normal;
layout(binding = 2) uniform sampler2D s_Noise;

struct VertexOutput {
    vec2 uv;
};

layout(location = 0) in VertexOutput In;
layout(location = 0) out float o_Color;

void main() {
    const float scale = 4.0;
    const vec2 noise_scale = vec2(u_ViewData.screen_size.x / scale, u_ViewData.screen_size.y / scale);

    vec3 frag_pos = texture(s_Position, In.uv).xyz;
    vec3 normal = texture(s_Normal, In.uv).rgb;
    vec3 random = texture(s_Noise, In.uv * noise_scale).xyz;

    vec3 tangent = normalize(random - normal * dot(random, normal));
    vec3 bitangent = cross(normal, tangent);
    mat3 TBN = mat3(tangent, bitangent, normal);

    float occlusion = 0.0;
    for (int i = 0; i < SSAO_KERNEL_SIZE; i++) {
        vec3 sample_pos = TBN * u_SSAOData.kernel[i];
        sample_pos = frag_pos + sample_pos * u_SSAOData.params.x;
        // sample_pos += frag_pos * radius;

        vec4 offset = vec4(sample_pos, 1.0);
        offset = u_ViewData.projection * offset;
        offset.xyz /= offset.w;
        offset.xyz = offset.xyz * 0.5 + 0.5;

        float sample_depth = texture(s_Position, offset.xy).z;

        float range = smoothstep(0.0, 1.0, u_SSAOData.params.x / abs(frag_pos.z - sample_depth));
        occlusion += (sample_depth >= sample_pos.z + u_SSAOData.params.y ? 1.0 : 0.0) * range;
    }

    occlusion = 1.0 - (occlusion / SSAO_KERNEL_SIZE);
    o_Color = occlusion;
}
