#version 450

#include "common.glsl"

/* layout(binding = 0) uniform Uniform_Block {
    View_Data view_data;
    Scene_Data scene_data;
}; */

layout(location = 0) in vec3 a_position;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec3 inColor;
layout(location = 3) in vec2 inTexCoord;

layout(push_constant) uniform constants {
    mat4 model_matrix;
    mat4 light_space_matrix;
};

layout(location = 0) out vec3 in_color;
void main() {
    in_color = inColor;
    gl_Position = light_space_matrix * model_matrix * vec4(a_position, 1.0);
}
