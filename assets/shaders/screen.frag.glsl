#version 460 core

struct VertexOutput {
    vec2 uv;
};

layout(location = 0) in VertexOutput In;

layout(binding = 0) uniform sampler2D screen_texture;
layout(binding = 2) uniform sampler2D s_SSAO;

layout(location = 0) out vec4 out_color;

void main() {
    const float gamma = 2.2;
    vec3 hdr_color = texture(screen_texture, In.uv).rgb;

    const float exposure = 2.0;
    vec3 mapped = vec3(1.0) - exp(-hdr_color * exposure);
    // vec3 mapped = hdr_color / (hdr_color + vec3(1.0));

    out_color.rgb = pow(mapped, vec3(1.0 / gamma));
    // out_color.rgb = texture(s_SSAO, In.uv).rrr;
    out_color.a = 1.0;
}
