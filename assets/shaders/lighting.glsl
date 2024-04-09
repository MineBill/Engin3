#ifndef LIGHTOUTG_H
#define LIGHTOUTG_H

#define LIGHT_DATA_BINDING_INDEX 3
#define MAX_SPOTLIGHTS  10
#define MAX_POOUTTLIGHTS 10

struct Directional_Light {
    vec4 direction;
    vec4 color;

    mat4 light_space_matrix[4];
};

struct Spot_Light {
    float _;
};

struct PointLight {
    vec4 color;
    vec3 position;

    float constant;
    float linear;
    float quadratic;
    float padding;
};

layout(std140, binding = LIGHT_DATA_BINDING_INDEX) uniform LightData {
    Directional_Light directional;

    PointLight pointlights[MAX_POOUTTLIGHTS];
    Spot_Light spotlights[MAX_SPOTLIGHTS];

    vec4 shadow_split_distances;
} u_LightData;

layout(binding = 0) uniform sampler2D albedo_map;
layout(binding = 1) uniform sampler2D normal_map;
layout(binding = 2) uniform sampler2DArray shadow_map;
layout(binding = 6) uniform samplerCube reflection_map;

#endif
