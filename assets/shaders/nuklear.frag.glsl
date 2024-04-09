#version 450 core

precision mediump float;

layout(binding = 0) uniform sampler2D Texture;

struct VertexOutput {
    vec2 Frag_UV;
    vec4 Frag_Color;
};

layout(location = 0) in VertexOutput In;

layout(location = 0) out vec4 Out_Color;

void main() {
    Out_Color = In.Frag_Color * texture(Texture, In.Frag_UV);
}
