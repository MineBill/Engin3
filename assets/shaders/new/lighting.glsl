#ifndef LIGHTOUTG_H
#define LIGHTOUTG_H

#include "new/common.glsl"

#define MAX_SPOTLIGHTS  10
#define MAX_POOUTTLIGHTS 10

struct Directional_Light {
    vec4 direction;
    vec4 color;

    mat4 light_space_matrix[4];
};

struct SpotLight {
    vec4 _padding;
};

struct PointLight {
    vec4 color;
    vec4 position;

    float constant;
    float linear;
    float quadratic;
    float _padding;
};

layout(std140, set = SCENE_SET, binding = 1) uniform LightData {
    Directional_Light directional;

    PointLight pointlights[MAX_POOUTTLIGHTS];
    SpotLight spotlights[MAX_SPOTLIGHTS];

    vec4 shadow_split_distances;
} u_LightData;

layout(set = SCENE_SET,  binding = 2) uniform sampler2DArray shadow_map;

layout(set = OBJECT_SET, binding = 1) uniform sampler2D albedo_map;
layout(set = OBJECT_SET, binding = 2) uniform sampler2D normal_map;
layout(set = OBJECT_SET, binding = 3) uniform sampler2D ambient_occlusion_map;
layout(set = OBJECT_SET, binding = 4) uniform sampler2D emissive_map;
layout(set = OBJECT_SET, binding = 5) uniform sampler2D metallic_roughness_map;

#endif
