#version 450

layout(std140, binding = 0) uniform ViewData {
    mat4 projection;
    mat4 view;
} u_ViewData;

struct VertexOutput {
    vec4 color;
    float thickness;
};

#pragma type: vertex

layout(location = 0) in vec3 position;
layout(location = 1) in float thickness;
layout(location = 2) in vec4 color;

layout(location = 0) out VertexOutput Out;
void Vertex() {
    Out.color = color;
    Out.thickness = thickness;
    gl_Position = u_ViewData.projection * u_ViewData.view * vec4(position, 1.0);
}

#pragma type: fragment

layout(location = 0) out vec4 o_Color;

layout(location = 0) in VertexOutput In;
void Fragment() {
    o_Color = In.color;
}
// vim:ft=glsl
