#ifndef LIGHTING_H
#define LIGHTING_H

#define MAX_SPOTLIGHTS  10
#define MAX_POINTLIGHTS 10

struct Directional_Light {
    vec3 direction;
    vec4 color;

    mat4 light_space_matrix;
};

struct Spot_Light {
    float a;
};

struct PointLight {
    vec4 color;
    vec3 position;

    float constant;
    float linear;
    float quadratic;
    float padding;
};

layout(std140, binding = 3) uniform Lights {
    Directional_Light directional;

    PointLight pointlights[MAX_POINTLIGHTS];
    Spot_Light spotlights[MAX_SPOTLIGHTS];
} lights;

layout(binding = 0) uniform sampler2D albedo_map;
layout(binding = 1) uniform sampler2D normal_map;
layout(binding = 2) uniform sampler2D shadow_map;

layout(binding = 6) uniform samplerCube reflection_map;

uniform int num_point_lights;
#endif
