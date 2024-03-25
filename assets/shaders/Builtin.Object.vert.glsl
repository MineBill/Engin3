#version 450

#include "common.glsl"

layout(binding = 0) uniform Uniform_Block {
    View_Data view_data;
    Scene_Data scene_data;
};

layout(push_constant) uniform constants {
    mat4 model;
};

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec3 inColor;
layout(location = 3) in vec2 inTexCoord;

layout(location = 0) out VS_OUT {
    vec3 fragColor;
    vec2 fragTexCoord;
    vec3 fragNormal;
    vec3 fragPos;

    vec4 pos_light_space;
} OUT;

const mat4 biasMat = mat4(
    0.5, 0.0, 0.0, 0.0,
    0.0, 0.5, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.5, 0.5, 0.0, 1.0 );

void main() {
    gl_Position = view_data.proj * view_data.view * model * vec4(inPosition, 1.0);
    OUT.fragColor = inColor;
    OUT.fragTexCoord = inTexCoord;
    OUT.fragNormal = mat3(transpose(inverse(model))) * inNormal;
    // fragNormal = inNormal;
    OUT.fragPos = vec3(model * vec4(inPosition, 1.0));
    OUT.pos_light_space = biasMat * scene_data.main_light.light_space_matrix * vec4(OUT.fragPos, 1.0);
}
