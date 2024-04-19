#version 450 core

#include "common.glsl"

layout(location = 0) in vec3 a_Position;
layout(location = 1) in vec3 a_Normal;
layout(location = 2) in vec3 a_Tangent;
layout(location = 3) in vec2 a_UV;
layout(location = 4) in vec3 a_Color;

struct VertexOutput {
    vec3 frag_pos;
    vec3 normal;
};

layout(location = 0) out VertexOutput Out;

void main() {
    gl_Position = u_ViewData.projection * u_ViewData.view * u_PerObjectData.model * vec4(a_Position, 1.0);
    Out.frag_pos = vec3(u_ViewData.view * u_PerObjectData.model * vec4(a_Position, 1.0));

    mat3 normal_matrix = transpose(inverse(mat3(u_ViewData.view * u_PerObjectData.model)));
    Out.normal = normalize(normal_matrix * a_Normal);
}
