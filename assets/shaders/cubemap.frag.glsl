#version 460 core

#include "lighting.glsl"

layout(location = 0) out vec4 out_color;

layout(location = 0) in VS_OUT {
    vec3 tex_coords;
} OUT;

void main() {
    out_color = texture(reflection_map, OUT.tex_coords);
}
