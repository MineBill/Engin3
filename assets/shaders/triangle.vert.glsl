#version 450 core

#include "common.glsl"
#include "lighting.glsl"

layout(location = 0) in vec3 a_Position;
layout(location = 1) in vec3 a_Normal;
layout(location = 2) in vec3 a_Tangent;
layout(location = 3) in vec2 a_UV;
layout(location = 4) in vec3 a_Color;

struct VertexOutput {
    vec3 frag_color;
    vec2 frag_uv;
    vec3 frag_pos;
    vec3 normal;

    vec3 tangent_light_dir;
    vec3 tangent_view_pos;
    vec3 tangent_frag_pos;
    mat3 TBN;

    vec4 pos_light_space[4];
};

layout(location = 0) out VertexOutput Out;

#ifdef VULKAN
const mat4 biasMat = mat4(
    0.5, 0.0, 0.0, 0.0,
    0.0, 0.5, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.5, 0.5, 0.0, 1.0 );
#endif

void main() {
    Out.frag_color = a_Color;
    Out.frag_uv = a_UV;

    mat3 normal_matrix = transpose(inverse(mat3(u_PerObjectData.model)));

    vec3 T = normalize(normal_matrix * a_Tangent);
    vec3 N = normalize(normal_matrix * a_Normal);
    T = normalize(T - dot(T, N) * N);
    vec3 B = cross(N, T);
    mat3 tbn = transpose(mat3(T, B, N));
    Out.TBN = tbn;

    gl_Position = u_ViewData.projection * u_ViewData.view * u_PerObjectData.model * vec4(a_Position, 1.0);
    Out.frag_pos = vec3(u_PerObjectData.model * vec4(a_Position, 1.0));

    Out.normal = N;
    Out.tangent_light_dir = tbn * u_LightData.directional.direction.xyz;
    Out.tangent_view_pos  = tbn * u_SceneData.view_position.xyz;
    Out.tangent_frag_pos  = tbn * Out.frag_pos;

    for (int i = 0; i < 4; i++) {
        Out.pos_light_space[i] = u_LightData.directional.light_space_matrix[i] * vec4(Out.frag_pos, 1.0);
    }
}
