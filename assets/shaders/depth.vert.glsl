#version 460 core

uniform mat4 model;
uniform mat4 light_space;

layout(location = 0) in vec3 position;
/* layout(location = 1) in vec3 normal;
layout(location = 2) in vec2 uv;
layout(location = 3) in vec3 color; */

void main() {
    gl_Position = light_space * model * vec4(position, 1.0);
}

