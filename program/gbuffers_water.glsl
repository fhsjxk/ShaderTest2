// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/common.glsl"
#include "/lib/math.glsl"
#include "/lib/brdf.glsl"
#include "/lib/atmosphere.glsl"

uniform vec3 sunDirection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform sampler2D {{RT_BACK}};
uniform sampler2D {{IMG_SKYVIEW_SAMPLER}};

in vec2 texcoord;
in vec3 color;
in vec3 worldPos;
in vec3 worldNormal;
in vec2 lightLevel;

/* RENDERTARGETS: {RT_BACK} */
layout(location = 0) out vec4 outColor;

void main()
{
    vec3 N = normalize(worldNormal);

    // ── Per-pixel view direction (camera → world pos) ────────
    vec3 cameraPos = gbufferModelViewInverse[3].xyz;
    vec3 V = normalize(worldPos - cameraPos);
    float NdotV = max(-dot(N, V), 0.0);

    vec3 back = texelFetch({{RT_BACK}}, ivec2(gl_FragCoord.xy), 0).rgb;

    // ── Reflection direction ──────────────────────────────────
    vec3 R = reflect(-V, N); // world-space reflection direction

    // ── Convert to atmosphere space for skyview sampling ──────
    vec3 RAtm = R.xzy * vec3(-1,-1,1); // Minecraft world → atmosphere coords (Z-up)

    // ── Sample sky reflection from skyview LUT ────────────────
    vec3 skyRefl = sampleSkyViewLUT({{IMG_SKYVIEW_SAMPLER}}, -RAtm, 0.0);

    // ── Sample backbuffer for screen-space reflection ─────────

    // ── Fresnel blend ─────────────────────────────────────────
    float fresnel = fresnelSchlickF0(NdotV, 0.02); // water F0 ≈ 0.02

    vec3 water = mix(back, skyRefl, fresnel);

    outColor = vec4(water, 1.0);
}
#endif

// {{SHADER_VERT}}
#ifdef {{SHADER_VERT}}
#include "/lib/common.glsl"

uniform mat4 gbufferModelViewInverse;

out vec2 texcoord;
out vec3 color;
out vec3 worldPos;
out vec3 worldNormal;
out vec2 lightLevel;

void main()
{
    gl_Position = ftransform();

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    color    = gl_Color.rgb;

    worldPos    = (gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex)).xyz;
    worldNormal = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal);

    lightLevel = pow(gl_MultiTexCoord1.xy / 240.0, vec2(2.2));
}
#endif
