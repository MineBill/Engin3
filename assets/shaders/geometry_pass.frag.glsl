#version 450 core

#include "common.glsl"

struct VertexOutput {
    vec3 frag_pos;
    vec3 normal;
};

layout(location = 0) in VertexOutput In;

layout(location = 0) out vec4 o_Position;
layout(location = 1) out vec4 o_Normal;

void main() {
    o_Position = vec4(In.frag_pos, 1.0);
    o_Normal = vec4(normalize(In.normal), 1.0);
}
