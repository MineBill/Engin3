#version 460 core

layout(std140, binding = 0) uniform View_Data {
    mat4 projection;
    mat4 view;
};

layout(location = 0) out VS_OUT {
    vec3 near_point;
    vec3 far_point;
    mat4 projection;
    mat4 view;
} OUT;

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
    // gl_Position = projection * view * vec4(plane[gl_VertexID].xyz, 1.0);

    vec3 p = plane[gl_VertexID].xyz;

    OUT.projection = projection;
    OUT.view = view;

    OUT.near_point = unproject_point(p.x, p.y, -1.0, view, projection).xyz;
    OUT.far_point = unproject_point(p.x, p.y, 1.0, view, projection).xyz;

    gl_Position = vec4(p, 1.0);
}
