#version 450

#include "common.glsl"

layout(binding = 0) uniform Uniform_Block {
    View_Data view_data;
    Scene_Data scene_data;
};

layout(location = 0) in vec3 inPosition;

layout(location = 0) out vec3 fragTexCoord;

void main() {
    fragTexCoord = inPosition;
    gl_Position = view_data.proj * view_data.view * vec4(inPosition, 1.0);
}
