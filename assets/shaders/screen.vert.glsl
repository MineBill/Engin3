#version 450 core

vec4 plane[6] = vec4[](
    vec4(-1.0,  1.0,  0.0, 1.0),
    vec4(-1.0, -1.0,  0.0, 0.0),
    vec4( 1.0, -1.0,  1.0, 0.0),

    vec4(-1.0,  1.0,  0.0, 1.0),
    vec4( 1.0, -1.0,  1.0, 0.0),
    vec4( 1.0,  1.0,  1.0, 1.0)
);

struct VertexOutput {
    vec2 uv;
};

layout(location = 0) out VertexOutput Out;

void main() {
    Out.uv = plane[gl_VertexIndex].zw;
    vec2 p = plane[gl_VertexIndex].xy;
    gl_Position = vec4(p, 0.0, 1.0);
}
