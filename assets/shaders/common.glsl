#ifndef COMMON_H
#define COMMON_H

#define PER_OBJECT_BINDING 0
#define VIEW_DATA_BINDING_INDEX 1
#define SCENE_DATA_BINDING_INDEX 2
#define MATERIAL_BINDING_INDEX 10
#define SSAO_BINDING_INDEX 11

layout(std140, binding = PER_OBJECT_BINDING) uniform PerObjectData {
    mat4 model;

#ifdef EDITOR
    int entity_id;
#endif
} u_PerObjectData;

layout(std140, binding = VIEW_DATA_BINDING_INDEX) uniform ViewData {
    mat4 projection;
    mat4 view;
    vec2 screen_size;
} u_ViewData;

layout(std140, binding = SCENE_DATA_BINDING_INDEX) uniform SceneData {
    vec4 view_position;
    vec4 view_direction;
    vec4 ambient_color;
} u_SceneData;

layout(std140, binding = MATERIAL_BINDING_INDEX) uniform Material {
    vec4 albedo_color;
    float metallic;
    float roughness;
} u_MaterialData;

#endif
