#ifndef COMMON_H
#define COMMON_H

layout(std140, binding = 1) uniform Scene_Data {
    vec4 view_position;
    vec4 ambient_color;
} scene_data;

layout(std140, binding = 0) uniform View_Data {
    mat4 projection;
    mat4 view;
} view_data;

layout(std140, binding = 2) uniform Material {
    vec4 albedo_color;
    float metallic;
    float roughness;
} material;

#endif
