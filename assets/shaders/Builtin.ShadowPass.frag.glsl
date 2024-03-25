#version 450

#include "common.glsl"

layout(location = 0) out vec4 color;

/* layout(set = 0, binding = 0) uniform Material_Block {
    Material material;
}; */

layout(location = 0) in vec3 in_color;

void main() {
    // float z = pow(gl_FragCoord.z, 32);
    float z = gl_FragCoord.z;
    // color = material.albedo_color;
    color = vec4(z, z, z, 1.0);
}
