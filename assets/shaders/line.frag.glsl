#version 450 core

layout(location = 0) out vec4 out_color;

struct VertexOutput {
    vec4 color;
    float thickness;
};

layout(location = 0) in VertexOutput In;

void main() {
    out_color = In.color;
}
