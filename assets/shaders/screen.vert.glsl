#version 460 core

vec4 plane[6] = vec4[](
    vec4(-1.0,  1.0,  0.0, 1.0),
    vec4(-1.0, -1.0,  0.0, 0.0),
    vec4( 1.0, -1.0,  1.0, 0.0),

    vec4(-1.0,  1.0,  0.0, 1.0),
    vec4( 1.0, -1.0,  1.0, 0.0),
    vec4( 1.0,  1.0,  1.0, 1.0)
);

layout(location = 0) out VS_OUT {
    vec2 uv;
} OUT;

void main() {
    OUT.uv = plane[gl_VertexID].zw;
    vec2 p = plane[gl_VertexID].xy;
    gl_Position = vec4(p, 0.0, 1.0);
}
