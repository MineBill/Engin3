#version 450 core
#include "new/common.glsl"
#include "new/lighting.glsl"
const float PI = 3.14159265359;

layout(std140, set = GLOBAL_SET, binding = 0) uniform ViewData {
    mat4 projection;
    mat4 view;
    vec2 screen_size;
} u_ViewData;

layout(std140, set = SCENE_SET, binding = 0) uniform SceneData {
    vec4 view_position;
    vec4 view_direction;
    vec4 ambient_color;
} u_SceneData;

layout(std140, set = OBJECT_SET, binding = 0) uniform Material {
    vec4 albedo_color;
    float metallic;
    float roughness;
} u_Material;

layout(set = OBJECT_SET, binding = 1) uniform sampler2D albedo_map;
layout(set = OBJECT_SET, binding = 2) uniform sampler2D normal_map;

layout(push_constant) uniform PushConstants {
    mat4 model;
#ifdef EDITOR
    int local_id;
#endif
} u_PushConstants;

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

    vec3 tangent_light_dir;
    vec3 tangent_view_pos;
    vec3 tangent_frag_pos;
    mat3 TBN;
};

#pragma type: vertex

layout(location = 0) in vec3 a_Position;
layout(location = 1) in vec3 a_Normal;
layout(location = 2) in vec3 a_Tangent;
layout(location = 3) in vec2 a_UV;
layout(location = 4) in vec3 a_Color;


const mat4 biasMat = mat4(
    0.5, 0.0, 0.0, 0.0,
    0.0, 0.5, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.5, 0.5, 0.0, 1.0 );

layout(location = 0) out VertexOutput Out;
void Vertex() {
    Out.frag_color = a_Color;
    Out.frag_uv = a_UV;

    mat3 normal_matrix = transpose(inverse(mat3(u_PushConstants.model)));
    vec3 T = normalize(normal_matrix * a_Tangent);
    vec3 N = normalize(normal_matrix * a_Normal);
    T = normalize(T - dot(T, N) * N);
    vec3 B = cross(N, T);
    mat3 tbn = transpose(mat3(T, B, N));
    Out.TBN = tbn;

    gl_Position = u_ViewData.projection * u_ViewData.view * u_PushConstants.model * vec4(a_Position, 1.0);
    Out.frag_pos = vec3(u_PushConstants.model * vec4(a_Position, 1.0));

    Out.normal = N;
    Out.tangent_light_dir = tbn * u_LightData.directional.direction.xyz;
    Out.tangent_view_pos  = tbn * u_SceneData.view_position.xyz;
    Out.tangent_frag_pos  = tbn * Out.frag_pos;
    /* mat3 normal_matrix = transpose(inverse(mat3(u_PerObjectData.model)));

    vec3 N = normalize(normal_matrix * a_Normal);

    gl_Position = u_ViewData.projection * u_ViewData.view * u_PerObjectData.model * vec4(a_Position, 1.0);
    Out.frag_pos = vec3(u_PerObjectData.model * vec4(a_Position, 1.0));

    Out.normal = N; */
}

#pragma type: fragment

layout(location = 0) out vec4 o_Color;
#ifdef EDITOR
layout(location = 1) out int o_ID;
#endif

layout(location = 0) in VertexOutput In;
/* layout(location = 1) out vec4 o_BrightColor; */
// f0:  Surface reflection at zero iradiance, when looking at the fragment directly.
//      Usually hardcoded as vec3(0.04) for non-metallic surfaces.
//      For metals, it's the 'tint'.
vec3 FrenselSchlick(float cos_theta, vec3 f0) {
    return f0 + (1 - f0) * pow(clamp(1 - cos_theta, 0.0, 1.0), 5.0);
}

float DistributionGGX(vec3 N, vec3 H, float roughness) {
    float a      = roughness*roughness;
    float a2     = a*a;
    float NdotH  = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;

    float num   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return num / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;

    float num   = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return num / denom;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2  = GeometrySchlickGGX(NdotV, roughness);
    float ggx1  = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

vec3 do_directional_light() {
    // vec3 N = normalize(In.normal);
    vec3 N = texture(normal_map, In.frag_uv).rgb;
    N = normalize(N * 2.0 - 1);
    // vec3 V = normalize(u_SceneData.view_position.xyz - In.frag_pos);
    vec3 V = normalize(In.tangent_view_pos.xyz - In.tangent_frag_pos);

    vec3 L = normalize(In.tangent_light_dir);
    vec3 H = normalize(V + L);

    vec3 radiance = u_LightData.directional.color.rgb;

    vec3 F0 = vec3(0.04);
    vec3 albedo = texture(albedo_map, In.frag_uv).rgb;
    // vec3 albedo = vec3(1, 1, 1);
    F0 = mix(F0, u_Material.albedo_color.rgb * albedo, u_Material.metallic);

    vec3 F = FrenselSchlick(max(dot(H, V), 0.0), F0);
    float NDF = DistributionGGX(N, H, u_Material.roughness);
    float G = GeometrySmith(N, V, L, u_Material.roughness);

    vec3 numerator = NDF * G * F;
    float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
    vec3 specular = numerator / denominator;

    vec3 ks = F;
    vec3 kd = vec3(1.0) - ks;
    kd *= 1.0 - u_Material.metallic;

    vec3 I = In.frag_pos - u_SceneData.view_position.xyz;
    vec3 R = reflect(I, normalize(In.normal));
    // vec3 reflection = texture(reflection_map, R).rgb;
    vec3 reflection = vec3(1, 1, 1);

    float NdotL = max(dot(N, L), 0.0);

    // float shadow = ShadowCalculation();
    float shadow = 1.0;

    /* vec2 frag_coords = In.frag_pos.xy / In.frag_pos.w;
    vec2 screen_uv = frag_color * 0.5 + 0.5; */
    // float occlusion = texture(s_SSAO,  gl_FragCoord.xy / u_ViewData.screen_size).r;
    float occlusion = 1.0;

    vec3 ambient = u_SceneData.ambient_color.rgb * albedo * u_Material.albedo_color.rgb * 0.1;
    ambient *= occlusion;
    return ambient + (kd * u_Material.albedo_color.rgb * albedo / PI + specular + reflection * u_Material.metallic * ks) * radiance * NdotL * shadow * occlusion;
}

void Fragment() {
    vec3 Lo = vec3(0.0);

    Lo += do_directional_light();
    // Lo += u_Material.albedo_color.rgb;
    // Lo += u_SceneData.ambient_color.rgb * u_Material.albedo_color.rgb;

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
    */

#ifdef EDITOR
    o_ID = u_PushConstants.local_id;
#endif
}

// vim:ft=glsl
