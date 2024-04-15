#version 450 core

#include "common.glsl"

struct VertexOutput {
    vec3 frag_color;
    vec2 frag_uv;
    vec3 frag_pos;
    vec3 normal;

    vec3 tangent_light_dir;
    vec3 tangent_view_pos;
    vec3 tangent_frag_pos;

    vec4 pos_light_space[4];
};

layout(location = 0) in VertexOutput In;

layout(location = 0) out vec4 o_Position;
layout(location = 1) out vec4 o_Normal;

void main() {
    o_Position = u_ViewData.view * vec4(In.frag_pos, 1.0);
    o_Normal = u_ViewData.view * vec4(normalize(In.normal), 1.0);
}
