#version 460 core

#include "common.glsl"
#include "lighting.glsl"

layout(location = 0) out vec4 out_color;

struct VertexOutput {
    vec3 tex_coords;
};

layout(location = 0) in VertexOutput Out;

void main() {
    // Sky color from scene data (ambient color)
    vec3 skyColor = u_SceneData.ambient_color.rgb;

    // Simulate sun disk using the direction of the directional light
    vec3 sunDirection = normalize(u_LightData.directional.direction.xyz);
    vec3 sunColor = u_LightData.directional.color.rgb;
    float sunIntensity = 1.5; // Intensity of the sun's color
    float sunRadius = 0.08; // Radius of the sun disk

    // Normalize and flip texture coordinates for rendering inside the cube
    vec2 normalizedTexCoords = Out.tex_coords.xy;
    normalizedTexCoords.y = 1.0 - normalizedTexCoords.y;

    // Calculate distance to the sun using normalized texture coordinates
    float distanceToSun = length(normalizedTexCoords - sunDirection.xy);

    // Render the sun disk
    float sunAlpha = smoothstep(sunRadius, sunRadius + 0.01, distanceToSun); // Soft edge for the sun
    vec3 finalColor = mix(skyColor, sunColor * sunIntensity, sunAlpha);


    out_color = vec4(finalColor, 1.0);
}
