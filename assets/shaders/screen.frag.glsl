#version 460 core

layout(location = 0) in VS_IN {
    vec2 uv;
} IN;

layout(binding = 0) uniform sampler2D screen_texture;

layout(location = 0) out vec4 out_color;

void main() {
    out_color = texture(screen_texture, IN.uv);
    out_color.rgb = pow(out_color.rgb, vec3(1.0 / 2.2));
}
