#version 450 core

struct VertexOutput {
    vec2 uv;
};

layout(location = 0) in VertexOutput In;

layout(binding = 0) uniform sampler2D scene_texture;
layout(binding = 1) uniform sampler2D bloom_texture;

layout(location = 0) out vec4 out_color;

void main() {
    const float gamma = 2.2;
    vec3 hdrColor = texture(scene_texture, In.uv).rgb;
    vec3 bloomColor = texture(bloom_texture, In.uv).rgb;
    hdrColor += bloomColor; // additive blending
    // tone mapping
    vec3 result = vec3(1.0) - exp(-hdrColor * 1.0);
    // also gamma correct while we're at it
    result = pow(result, vec3(1.0 / gamma));
    out_color = vec4(result, 1.0);
}
