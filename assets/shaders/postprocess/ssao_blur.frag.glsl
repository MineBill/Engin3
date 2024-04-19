#version 450 core

layout(location = 0) out float o_Color;
layout(binding = 0) uniform sampler2D s_SSAOTexture;

struct VertexOutput {
    vec2 uv;
};

layout(location = 0) in VertexOutput In;

void main() {
    vec2 texel_size = 1.0 / vec2(textureSize(s_SSAOTexture, 0));
    float result = 0.0;
    for (int x = -2; x < 2; x++) {
        for (int y = -2; y < 2; y++) {
            vec2 offset = vec2(float(x), float(y)) * texel_size;
            result += texture(s_SSAOTexture, In.uv + offset).r;
        }
    }
    // o_Color = texture(s_SSAOTexture, In.uv).r;
    o_Color = result / (4.0 * 4.0);
}
