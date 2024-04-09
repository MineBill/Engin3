#version 450 core

struct VertexOutput {
    vec2 uv;
};

layout(location = 0) in VertexOutput In;

layout(binding = 1) uniform sampler2D image;

layout(location = 0) out vec4 out_color;

const float weight[5] = float[] (0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);

void main() {
    vec2 TexCoords = In.uv;
    vec2 tex_offset = 1.0 / textureSize(image, 0); // gets size of single texel
    vec3 result = texture(image, TexCoords).rgb * weight[0]; // current fragment's contribution
    for(int i = 1; i < 5; ++i)
    {
        result += texture(image, TexCoords + vec2(tex_offset.x * i, 0.0)).rgb * weight[i];
        result += texture(image, TexCoords - vec2(tex_offset.x * i, 0.0)).rgb * weight[i];
    }
    out_color = vec4(result, 1.0);
}
