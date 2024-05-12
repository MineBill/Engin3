#ifndef SCENE_SET_H
#define SCENE_SET_H

#define SCENE_SET  1

layout(std140, set = SCENE_SET, binding = 0) uniform SceneData {
    vec4 view_position;
    vec4 view_direction;
    vec4 ambient_color;
} u_SceneData;

#endif