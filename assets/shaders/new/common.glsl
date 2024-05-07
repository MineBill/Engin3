#ifndef COMMON_H
#define COMMON_H
const float PI = 3.14159265359;

#define GLOBAL_SET 0
#define SCENE_SET  1
#define OBJECT_SET 2

layout(std140, set = GLOBAL_SET, binding = 0) uniform ViewData {
    mat4 projection;
    mat4 view;
    vec2 screen_size;
} u_ViewData;

layout(std140, set = GLOBAL_SET, binding = 1) uniform DebugOptions {
    bool shadow_cascade_boxes;
    bool shadow_cascade_colors;
} u_DebugOptions;

layout(std140, set = SCENE_SET, binding = 0) uniform SceneData {
    vec4 view_position;
    vec4 view_direction;
    vec4 ambient_color;
} u_SceneData;

layout(std140, set = OBJECT_SET, binding = 0) uniform Material {
    vec4 albedo_color;
    float metallic;
    float roughness;
} u_Material;

#endif // COMMON_H
