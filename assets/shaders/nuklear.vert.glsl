#version 450 core

layout(std140, binding = 5) uniform NuklearData {
    mat4 ProjMtx;
};

layout(location = 0) in vec2 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 2) in vec4 Color;

struct VertexOutput {
    vec2 Frag_UV;
    vec4 Frag_Color;
};

layout(location = 0) out VertexOutput Out;

void main() {
   Out.Frag_UV = TexCoord;
   Out.Frag_Color = vec4(Color[0]/255.0, Color[1]/255.0, Color[2]/255.0, Color[3]/255.0);
   gl_Position = ProjMtx * vec4(Position.xy, 0, 1);
}
