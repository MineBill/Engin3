#ifndef SHADOW_H
#define SHADOW_H

float SampleShadow(sampler2D map, vec2 coords, float compare) {
    return step(compare, texture(map, coords).r);
}

float SampleShadowLinear(sampler2D map, vec2 coords, float compare, vec2 texel_size) {
    vec2 pp = coords / texel_size + vec2(0.5);
    vec2 fraction = fract(pp);
    vec2 texel = (pp - fraction) * texel_size;

    float a = SampleShadow(map, texel, compare);
    float b = SampleShadow(map, texel + vec2(1.0, 0.0) * texel_size, compare);
    float c = SampleShadow(map, texel + vec2(0.0, 1.0) * texel_size, compare);
    float d = SampleShadow(map, texel + vec2(1.0, 1.0) * texel_size, compare);

    float aa = mix(a, c, fraction.y);
    float bb = mix(b, d, fraction.y);

    return mix(aa, bb, fraction.x);
}

float ShadowCalculation(vec4 fragPosLightSpace) {
    float shadow = 0.0;
    vec3 shadowCoords = (fragPosLightSpace.xyz / fragPosLightSpace.w);
    shadowCoords = shadowCoords * 0.5 + 0.5;

    if (shadowCoords.z > 1.0)
        return 1.0;
    float bias = max((1.0/4096.0) * (1.0 - dot(OUT.normal, normalize(lights.directional.direction.xyz))), 0.003);
    vec2 texel_size = 1.0 / textureSize(shadow_map, 0);

    const float SAMPLES = 3;
    const float SAMPLES_START = (SAMPLES - 1) / 2;
    const float SAMPLES_SQUARED = SAMPLES * SAMPLES;
    for (float x = -SAMPLES_START; x <= SAMPLES_START; x++) {
        for (float y = -SAMPLES_START; y <= SAMPLES_START; y++) {
            shadow += SampleShadowLinear(shadow_map, shadowCoords.xy + vec2(x, y) * texel_size, shadowCoords.z - bias, texel_size);
        }
    }

    return shadow / SAMPLES_SQUARED;
}

#endif
