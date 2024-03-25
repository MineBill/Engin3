#version 450

#include "common.glsl"
#include "lighting.glsl"

uniform mat4 model;

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec3 tangent;
layout(location = 3) in vec2 uv;
layout(location = 4) in vec3 color;

layout(location = 0) out VS_OUT {
    vec3 frag_color;
    vec2 frag_uv;
    vec3 frag_pos;
    vec3 normal;

    vec3 tangent_light_dir;
    vec3 tangent_view_pos;
    vec3 tangent_frag_pos;

    vec4 pos_light_space;
} OUT;

const mat4 biasMat = mat4(
    0.5, 0.0, 0.0, 0.0,
    0.0, 0.5, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.5, 0.5, 0.0, 1.0 );

void main() {
    OUT.frag_color = color;
    OUT.frag_uv = uv;

    mat3 normal_matrix = transpose(inverse(mat3(model)));

    vec3 T = normalize(normal_matrix * tangent);
    vec3 N = normalize(normal_matrix * normal);
    T = normalize(T - dot(T, N) * N);
    vec3 B = cross(N, T);
    mat3 TBN = transpose(mat3(T, B, N));

    gl_Position = view_data.projection * view_data.view * model * vec4(position, 1.0);
    OUT.frag_pos = vec3(model * vec4(position, 1.0));

    OUT.normal = N;
    OUT.tangent_light_dir = TBN * lights.directional.direction;
    OUT.tangent_view_pos  = TBN * scene_data.view_position.xyz;
    OUT.tangent_frag_pos  = TBN * OUT.frag_pos;

    OUT.pos_light_space = lights.directional.light_space_matrix * vec4(OUT.frag_pos, 1.0);
}
