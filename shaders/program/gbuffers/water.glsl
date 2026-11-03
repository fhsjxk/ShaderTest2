// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/prelude.glsl"
#include "/lib/lighting/brdf.glsl"
#include "/lib/atmosphere/all.glsl"

uniform vec3 sunDirection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform sampler2D {{RT_HDR}};
uniform sampler2D {{IMG_SKYVIEW_SAMPLER}};

in vec3 worldPos;
in vec3 worldNormal;

/* RENDERTARGETS: {{RT_HDR_SLOT}} */
layout(location = 0) out vec4 outColor;

// Water reflectance at normal incidence.
const float WATER_F0 = 0.02;

void main()
{
    vec3 N = normalize(worldNormal);

    vec3 cameraPos = gbufferModelViewInverse[3].xyz;
    vec3 V = normalize(worldPos - cameraPos);
    float NdotV = max(-dot(N, V), 0.0);

    vec3 back = texelFetch({{RT_HDR}}, ivec2(gl_FragCoord.xy), 0).rgb;

    // World-space reflection direction, remapped into atmosphere space
    // (Minecraft's world Z is mirrored w.r.t. the atmosphere convention).
    vec3 R = reflect(-V, N) * vec3(1.0, -1.0, 1.0);

    vec3 skyRefl = sampleSkyViewLUT({{IMG_SKYVIEW_SAMPLER}}, R, MIN_ALTITUDE_KM);

    float fresnel = fresnelSchlickF0(NdotV, WATER_F0);

    outColor = vec4(mix(back, skyRefl, fresnel), 1.0);
}
#endif

// {{SHADER_VERT}}
#ifdef {{SHADER_VERT}}
#include "/lib/prelude.glsl"

uniform mat4 gbufferModelViewInverse;

out vec3 worldPos;
out vec3 worldNormal;

void main()
{
    gl_Position = ftransform();

    worldPos    = (gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex)).xyz;
    worldNormal = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal);
}
#endif
