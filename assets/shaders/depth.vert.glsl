#version 460 core

#define DEPTH_PER_OBJECT_BINDING 0

layout(std140, binding = DEPTH_PER_OBJECT_BINDING) uniform PerObjectData {
    mat4 model;
    mat4 light_space;
} u_PerObjectData;

layout(location = 0) in vec3 position;

void main() {
    gl_Position = u_PerObjectData.light_space * u_PerObjectData.model * vec4(position, 1.0);
}

