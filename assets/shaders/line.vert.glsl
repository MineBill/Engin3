#version 460 core

layout(std140, binding = 0) uniform View_Data {
    mat4 projection;
    mat4 view;
};

layout(location = 0) in vec3 position;
layout(location = 1) in float thickness;
layout(location = 2) in vec4 color;

layout(location = 0) out VS_OUT {
    vec4 color;
    float thickness;
} OUT;

void main() {
    OUT.color = color;
    OUT.thickness = thickness;
    gl_Position = projection * view * vec4(position, 1.0);
}
