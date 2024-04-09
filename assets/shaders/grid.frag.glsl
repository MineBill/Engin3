#version 460 core

struct VertexOutput {
    vec3 near_point;
    vec3 far_point;
    mat4 projection;
    mat4 view;
};

layout(location = 0) in VertexOutput In;

layout(location = 0) out vec4 out_color;

vec4 grid(vec3 frag_pos, float scale) {
    vec2 coord = frag_pos.xz * scale;
    vec2 derivative = fwidth(coord);
    vec2 grid = abs(fract(coord - 0.5) - 0.5) / derivative;
    
    float line = min(grid.x, grid.y);
    float minz = min(derivative.y, 1);
    float minx = min(derivative.x, 1);

    vec4 color = vec4(0.2, 0.2, 0.2, 1.0 - min(line, 1.0));

    if (frag_pos.x > -0.5 * minx && frag_pos.x < 0.5 * minx)
        color.z = 1.0;

    if (frag_pos.z > -0.5 * minz && frag_pos.z < 0.5 * minz)
        color.x = 1.0;

    return color;
}

const float near = 0.1;
const float far = 1000;

float compute_depth(vec3 pos) {
    vec4 clip_space_pos = In.projection * In.view * vec4(pos.xyz, 1.0);
    float t = (clip_space_pos.z / clip_space_pos.w);
    return (t);
}

float compute_linear_depth(vec3 pos) {
    vec4 clip_space_pos = In.projection * In.view * vec4(pos.xyz, 1.0);
    float clip_space_depth = (clip_space_pos.z / clip_space_pos.w) * 2.0 - 1.0; // put back between -1 and 1
    float linearDepth = (2.0 * near * far) / (far + near - clip_space_depth * (far - near)); // get linear value between 0.01 and 100
    return linearDepth / far; // normalize
}

void main() {
    float t = (0-In.near_point.y) / (In.far_point.y - In.near_point.y);

    vec3 frag_pos = In.near_point + (t) * (In.far_point - In.near_point);

    float d = compute_depth(frag_pos);
    // gl_FragDepth =  (((1 - 0) * d) + (1 + 0)) / 2.0;
    gl_FragDepth = (d + 1.0) / 2.0;

    float linear_depth = compute_linear_depth(frag_pos);
    float fading = max(0, (0.5 - linear_depth));

    out_color = (grid(frag_pos, 1) + grid(frag_pos, 0.1)) * float(t > 0);
    out_color.a *= fading;
}
