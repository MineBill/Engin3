#version 460 core

layout(location = 0) out vec4 out_color;

layout(location = 0) in VS_IN {
    vec4 color;
    float thickness;
} IN;

void main() {
    out_color = IN.color;
}
