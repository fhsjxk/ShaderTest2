#version 330 core

layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;

uniform sampler2D starstex;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

// from VS
in vec4 vColor[];
in vec2 vTexcoord[];

out vec2 texcoord;
out vec3 color;

void main() {

    // 1. triangle center
    vec3 p0 = gl_in[0].gl_Position.xyz;
    vec3 p1 = gl_in[1].gl_Position.xyz;
    vec3 p2 = gl_in[2].gl_Position.xyz;

    vec3 center = (p0 + p1 + p2) / 3.0;

    // 2. stable star ID
    float h = dot(floor(center * 10.0), vec3(12.9898, 78.233, 37.719));
    int starID = int(mod(h, 1540.0));

    vec3 starData = texelFetch(starstex, ivec2(starID, 0), 0).rgb * 2.0 - 1.0;

    vec3 dir = normalize(starData);

    // 3. billboard basis (view-facing)
    vec3 worldPos = dir * 1000.0;
    vec4 viewPos = gbufferModelView * vec4(worldPos, 1.0);

    float size = 5;

    vec2 offsets[3] = vec2[](
        vec2(0,  0.577),
        vec2(-0.5, -0.288),
        vec2(0.5, -0.288)
    );

    for (int i = 0; i < 3; i++) {

        vec4 p = viewPos;
        p.xy += offsets[i] * size * p.w;

        gl_Position = gbufferProjection * p;

        texcoord = vTexcoord[0];
        color = vec3(1.0);

        EmitVertex();
    }

    EndPrimitive();
}