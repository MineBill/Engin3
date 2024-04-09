#version 450 core

layout(push_constant) uniform constants {
    vec4 shadow_split_distances;
    int num_point_lights;
};

struct VertexOutput {
    int a;
};

layout(location = 0) out VertexOutput OUT;

void main() {
    OUT.a = num_point_lights;
}
