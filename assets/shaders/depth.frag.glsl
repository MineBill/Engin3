#version 460 core

layout(location = 0) out vec4 color;

float LinearizeDepth(float depth, float near, float far) {
    float z = depth * 2.0 - 1.0; // Convert depth from [0,1] to [-1,1]
    return (2.0 * near * far) / (far + near - z * (far - near)); // Linearize depth
}

void main () {
    float z = LinearizeDepth(gl_FragCoord.z, 0.1, 1000.0);
    // color = material.albedo_color;
    color = vec4(z, z, z, 1.0);
}
