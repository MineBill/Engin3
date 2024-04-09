#version 450 core

layout(location = 0) in VS_OUT {
    vec2 uv;
} OUT;

layout(binding = 0) uniform usampler2D stencil_texture;

layout(location = 0) out vec4 out_color;

void main() {
    // http://www.geoffprewett.com/blog/software/opengl-outline/index.html
    vec2 pixelSize = vec2(1.0 / textureSize(stencil_texture, 0));
    const int WIDTH = 3;
    bool isInside = false;
    int count = 0;
    float coverage = 0.0;
    float dist = 1e6;
    for (int y = -WIDTH;  y <= WIDTH;  ++y) {
        for (int x = -WIDTH;  x <= WIDTH;  ++x) {
            vec2 dUV = vec2(float(x) * pixelSize.x, float(y) * pixelSize.y);
            float mask = texture(stencil_texture, OUT.uv + dUV).r;
            coverage += mask;
            if (mask >= 0.5) {
                dist = min(dist, sqrt(float(x * x + y * y)));
            }
            if (x == 0 && y == 0) {
                isInside = (mask > 0.5);
            }
            count += 1;
        }
    }
    coverage /= float(count);
    float a;
    if (isInside) {
        a = min(1.0, (1.0 - coverage) / 0.75);
    } else {
        const float solid = 0.3 * float(WIDTH);
        const float fuzzy = float(WIDTH) - solid;
        a = 1.0 - min(1.0, max(0.0, dist - solid) / fuzzy);
    }
    out_color.rgb = vec3(0.5, 1.0, 0.5);
    out_color.a = a;
}
