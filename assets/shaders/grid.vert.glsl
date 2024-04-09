#version 450 core

#include "common.glsl"

struct VertexOutput {
    vec3 near_point;
    vec3 far_point;
    mat4 projection;
    mat4 view;
};

layout(location = 0) out VertexOutput Out;

vec3 plane[6] = vec3[](
    vec3(-1, -1, 0), vec3(1, -1, 0), vec3(-1, 1, 0),
    vec3(-1, 1, 0), vec3(1, -1, 0), vec3(1, 1, 0)
);

vec3 unproject_point(float x, float y, float z, mat4 view, mat4 projection) {
    mat4 viewInv = inverse(view);
    mat4 projInv = inverse(projection);
    vec4 unprojectedPoint =  viewInv * projInv * vec4(x, y, z, 1.0);
    return unprojectedPoint.xyz / unprojectedPoint.w;
}

void main() {
    vec3 p = plane[gl_VertexIndex].xyz;

    Out.projection = u_ViewData.projection;
    Out.view = u_ViewData.view;

    Out.near_point = unproject_point(p.x, p.y, -1.0, u_ViewData.view, u_ViewData.projection).xyz;
    Out.far_point  = unproject_point(p.x, p.y,  1.0, u_ViewData.view, u_ViewData.projection).xyz;

    gl_Position = vec4(p, 1.0);
}
