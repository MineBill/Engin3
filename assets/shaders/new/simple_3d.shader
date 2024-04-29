#version 450 core
#include "new/common.glsl"

layout(std140, set = GLOBAL_SET, binding = 0) uniform ViewData {
    mat4 projection;
    mat4 view;
    vec2 screen_size;
} u_ViewData;

layout(std140, set = OBJECT_SET, binding = 0) uniform Material {
    vec4 albedo_color;
    float metallic;
    float roughness;
} u_Material;

/* layout(std140, set = 1, binding = 0) uniform PerObjectData {
    mat4 model;

#ifdef EDITOR
    int entity_id;
#endif
} u_PerObjectData; */

struct VertexOutput {
    vec3 frag_color;
    vec2 frag_uv;
    vec3 frag_pos;
    vec3 normal;
};

#pragma type: vertex

layout(location = 0) in vec3 a_Position;
layout(location = 1) in vec3 a_Normal;
layout(location = 2) in vec3 a_Tangent;
layout(location = 3) in vec2 a_UV;
layout(location = 4) in vec3 a_Color;

layout(push_constant) uniform PushConstants {
    mat4 model;
} u_PushConstants;

layout(location = 0) out VertexOutput Out;
void Vertex() {
    Out.frag_color = a_Color;
    Out.frag_uv = a_UV;

    gl_Position = u_ViewData.projection * u_ViewData.view * u_PushConstants.model * vec4(a_Position, 1.0);
    /* mat3 normal_matrix = transpose(inverse(mat3(u_PerObjectData.model)));

    vec3 N = normalize(normal_matrix * a_Normal);

    gl_Position = u_ViewData.projection * u_ViewData.view * u_PerObjectData.model * vec4(a_Position, 1.0);
    Out.frag_pos = vec3(u_PerObjectData.model * vec4(a_Position, 1.0));

    Out.normal = N; */
}

#pragma type: fragment

layout(location = 0) out vec4 o_Color;
/* layout(location = 1) out vec4 o_BrightColor;
#ifdef EDITOR
layout(location = 2) out int o_ID;
#endif */

layout(location = 0) in VertexOutput In;
void Fragment() {
    vec3 Lo = vec3(0.0);

    // Lo += do_directional_light();
    // Lo += u_Material.albedo_color.rgb;
    Lo += u_Material.albedo_color.rgb;

    /* for (int i = 0; i < u_LightData.num_point_lights; i++) {
        Lo += do_point_light(u_LightData.pointlights[i]);
    } */

    o_Color = vec4(Lo, 1.0);

    /* float brightness = dot(o_Color.rgb, vec3(0.2126, 0.7152, 0.0722));
    if (brightness > 1.0) {
        o_BrightColor = vec4(o_Color.rgb, 1.0);
    } else {
        o_BrightColor = vec4(0.0, 0.0, 0.0, 1.0);
    }

#ifdef EDITOR
    o_ID = u_PerObjectData.entity_id;
#endif */
}

// vim:ft=glsl
