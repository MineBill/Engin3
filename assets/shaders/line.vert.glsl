#version 450 core

#include "common.glsl"

layout(location = 0) in vec3 position;
layout(location = 1) in float thickness;
layout(location = 2) in vec4 color;

struct VertexOutput {
    vec4 color;
    float thickness;
};

layout(location = 0) out VertexOutput Out;

void main() {
    Out.color = color;
    Out.thickness = thickness;
    gl_Position = u_ViewData.projection * u_ViewData.view * vec4(position, 1.0);
}
