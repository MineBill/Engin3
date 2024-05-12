#ifndef OBJECT_SET_H
#define OBJECT_SET_H

#define OBJECT_SET 2

layout(std140, set = OBJECT_SET, binding = 0) uniform Material {
    vec4 albedo_color;
    float metallic;
    float roughness;
} u_Material;

#endif