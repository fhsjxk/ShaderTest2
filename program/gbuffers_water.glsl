// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/common.glsl"

uniform sampler2D gtexture;

in vec2 texcoord;
in vec3 color;
in vec3 viewPos;
in vec3 worldNormal;

/* RENDERTARGETS: {RT_BACK} */
layout(location = 0) out vec4 fragColor;

void main()
{
    vec4 baseColor = texture(gtexture, texcoord);

    // ── Fresnel ───────────────────────────────────────────────
    vec3 viewDir = normalize(-viewPos);
    float NdotV = abs(dot(normalize(worldNormal), viewDir));
    NdotV = clamp(NdotV, 0.0, 1.0);

    // Schlick Fresnel: F0 ≈ 0.02 for water
    float F0 = 0.02;
    float fresnel = F0 + (1.0 - F0) * pow(1.0 - NdotV, 5.0);

    vec3 shallowColor = vec3(0.15, 0.45, 0.75);
    vec3 deepColor    = vec3(0.03, 0.12, 0.35);
    vec3 waterColor   = mix(shallowColor, deepColor, fresnel);

    baseColor.rgb = baseColor.rgb * color;
    baseColor.rgb = mix(baseColor.rgb, waterColor, 0.75);

    float alpha = mix(0.35, 0.75, fresnel);

    fragColor = vec4(pow(baseColor.rgb, vec3(2.2)), alpha);
}
#endif

// {{SHADER_VERT}}
#ifdef {{SHADER_VERT}}
#include "/lib/common.glsl"

uniform mat4 gbufferModelViewInverse;

out vec2 texcoord;
out vec3 color;
out vec3 viewPos;
out vec3 worldNormal;

void main()
{
    gl_Position = ftransform();

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    color    = gl_Color.rgb;

    // 视图空间位置（用于计算视线方向）
    vec4 viewPos4 = gl_ModelViewMatrix * gl_Vertex;
    viewPos = viewPos4.xyz;

    // 世界空间法线（用于 Fresnel 计算）
    worldNormal = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal);
}
#endif
