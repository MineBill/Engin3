#version 450 core

#include "new/lighting.glsl"
#include "new/global.glsl"

struct VertexOutput {
    vec3 position;
    vec3 fsun;
};

#pragma type: vertex

layout(location = 0) out VertexOutput Out;

// vec3 cube[36] = vec3[](
//     vec3(-1.0f,  1.0f, -1.0f),
//     vec3(-1.0f, -1.0f, -1.0f),
//     vec3( 1.0f, -1.0f, -1.0f),
//     vec3( 1.0f, -1.0f, -1.0f),
//     vec3( 1.0f,  1.0f, -1.0f),
//     vec3(-1.0f,  1.0f, -1.0f),

//     vec3(-1.0f, -1.0f,  1.0f),
//     vec3(-1.0f, -1.0f, -1.0f),
//     vec3(-1.0f,  1.0f, -1.0f),
//     vec3(-1.0f,  1.0f, -1.0f),
//     vec3(-1.0f,  1.0f,  1.0f),
//     vec3(-1.0f, -1.0f,  1.0f),

//     vec3( 1.0f, -1.0f, -1.0f),
//     vec3( 1.0f, -1.0f,  1.0f),
//     vec3( 1.0f,  1.0f,  1.0f),
//     vec3( 1.0f,  1.0f,  1.0f),
//     vec3( 1.0f,  1.0f, -1.0f),
//     vec3( 1.0f, -1.0f, -1.0f),

//     vec3(-1.0f, -1.0f,  1.0f),
//     vec3(-1.0f,  1.0f,  1.0f),
//     vec3( 1.0f,  1.0f,  1.0f),
//     vec3( 1.0f,  1.0f,  1.0f),
//     vec3( 1.0f, -1.0f,  1.0f),
//     vec3(-1.0f, -1.0f,  1.0f),

//     vec3(-1.0f,  1.0f, -1.0f),
//     vec3( 1.0f,  1.0f, -1.0f),
//     vec3( 1.0f,  1.0f,  1.0f),
//     vec3( 1.0f,  1.0f,  1.0f),
//     vec3(-1.0f,  1.0f,  1.0f),
//     vec3(-1.0f,  1.0f, -1.0f),

//     vec3(-1.0f, -1.0f, -1.0f),
//     vec3(-1.0f, -1.0f,  1.0f),
//     vec3( 1.0f, -1.0f, -1.0f),
//     vec3( 1.0f, -1.0f, -1.0f),
//     vec3(-1.0f, -1.0f,  1.0f),
//     vec3( 1.0f, -1.0f,  1.0f)
// );

const vec2 positions[4] = vec2[](
    vec2(-1.0,  1.0), vec2(-1.0, -1.0),
    vec2( 1.0,  1.0), vec2( 1.0, -1.0)
);

void Vertex() {
    gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
    Out.position = transpose(mat3(u_ViewData.view)) * (inverse(u_ViewData.projection) * gl_Position).xyz;
    Out.fsun = vec3(0.0, 0.05, 0);
}

#pragma type: fragment
#line 10

layout(location = 0) out vec4 o_Color;

const float Br = 0.0025; // Rayleigh coefficient
const float Bm = 0.0003; // Mie coefficient
const float g =  0.9800; // Mie scattering direction. Should be ALMOST 1.0f

const vec3 nitrogen = vec3(0.650, 0.570, 0.475);
const vec3 Kr = Br / pow(nitrogen, vec3(4.0));
const vec3 Km = Bm / pow(nitrogen, vec3(0.84));

float mod289(float x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 mod289(vec4 x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 perm(vec4 x){return mod289(((x * 34.0) + 1.0) * x);}

float noise(vec3 p){
    vec3 a = floor(p);
    vec3 d = p - a;
    d = d * d * (3.0 - 2.0 * d);

    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy);
    vec4 k2 = perm(k1.xyxy + b.zzww);

    vec4 c = k2 + a.zzzz;
    vec4 k3 = perm(c);
    vec4 k4 = perm(c + 1.0);

    vec4 o1 = fract(k3 * (1.0 / 41.0));
    vec4 o2 = fract(k4 * (1.0 / 41.0));

    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

    return o4.y * d.y + o4.x * (1.0 - d.y);
}

const mat3 m = mat3(0.0, 1.60,  1.20, -1.6, 0.72, -0.96, -1.2, -0.96, 1.28);

float fbm(vec3 p) {
    float f = 0.0;
    f += noise(p) / 2; p = m * p * 1.1;
    f += noise(p) / 4; p = m * p * 1.2;
    f += noise(p) / 6; p = m * p * 1.3;
    f += noise(p) / 12; p = m * p * 1.4;
    f += noise(p) / 24;
    return f;
}

const float cirrus = 0.5;
const float cumulus = 0.8;

layout(location = 0) in VertexOutput In;

void Fragment() {
    if (In.position.y < 0)
        discard;
    float mu = dot(normalize(In.position), normalize(u_LightData.directional.direction.xyz));
    float rayleigh = 3.0 / (8.0 * 3.14) * (1.0 + mu * mu);
    vec3 mie = (Kr + Km * (1.0 - g * g) / (2.0 + g * g) / pow(1.0 + g * g - 2.0 * g * mu, 1.5)) / (Br + Bm);

    vec3 day_extinction = exp(-exp(-((In.position.y + u_LightData.directional.direction.xyz.y * 4.0) * (exp(-In.position.y * 16.0) + 0.1) / 80.0) / Br) * (exp(-In.position.y * 16.0) + 0.1) * Kr / Br) * exp(-In.position.y * exp(-In.position.y * 8.0 ) * 4.0) * exp(-In.position.y * 2.0) * 4.0;
    vec3 night_extinction = vec3(1.0 - exp(u_LightData.directional.direction.y)) * 0.2;
    vec3 extinction = mix(day_extinction, night_extinction, -u_LightData.directional.direction.y * 0.2 + 0.5);
    o_Color.rgb = rayleigh * mie * extinction;

    // // Cirrus Clouds
    float density = smoothstep(1.0 - cirrus, 1.0, fbm(In.position.xyz / In.position.y * 1.0 + u_GlobalData.time * 0.01)) * 0.3;
    o_Color.rgb = mix(o_Color.rgb, extinction * 10.0, density * max(In.position.y, 0.0));

    // // Cumulus Clouds
    // for (int i = 0; i < 2; i++)
    // {
    //   float density = smoothstep(1.0 - cumulus, 1.0, fbm((0.7 + float(i) * 0.01) * In.position.xyz / In.position.y + u_GlobalData.time * 0.01));
    //   o_Color.rgb = mix(o_Color.rgb, extinction * density * 5.0, min(density, 1.0) * max(In.position.y, 0.0));
    // }

    // Dithering Noise
    // o_Color.rgb += noise(In.position * 10) * 0.01;
    o_Color.a = 1.0;
    o_Color.rgb = pow(1.0 - exp(-1.3 * o_Color.rgb), vec3(1.3));
}