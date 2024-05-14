#version 450 core

#include "new/global.glsl"

layout(push_constant) uniform PushConstants {
    mat4 model;
    int object_id;
} u_PushConstants;

#pragma type: vertex

layout(location = 0) in vec3 a_Position;

layout(location = 1) in vec3 a_Normal;
layout(location = 2) in vec3 a_Tangent;
layout(location = 3) in vec2 a_UV;
layout(location = 4) in vec3 a_Color;

void Vertex() {
    gl_Position =
        u_ViewData.projection *
        u_ViewData.view *
        u_PushConstants.model *
        vec4(a_Position, 1.0);
}

#pragma type: fragment

layout(location = 0) out int o_ObjectID;

void Fragment() {
    o_ObjectID = u_PushConstants.object_id;
}