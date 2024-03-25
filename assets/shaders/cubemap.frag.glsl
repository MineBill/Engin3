#version 460 core

#include "lighting.glsl"

layout(location = 0) out vec4 out_color;

layout(location = 0) in VS_IN {
    vec3 tex_coords;
} IN;

void main() {
    out_color = texture(reflection_map, IN.tex_coords);
}
