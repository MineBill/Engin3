#ifndef GLOBAL_SET_H
#define GLOBAL_SET_H

#define GLOBAL_SET 0

layout(std140, set = GLOBAL_SET, binding = 0) uniform ViewData {
    mat4 projection;
    mat4 view;
    vec2 screen_size;
} u_ViewData;

layout(std140, set = GLOBAL_SET, binding = 1) uniform DebugOptions {
    bool shadow_cascade_boxes;
    bool shadow_cascade_colors;
} u_DebugOptions;

#endif