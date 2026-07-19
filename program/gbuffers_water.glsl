// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/common.glsl"
#include "/lib/math.glsl"
#include "/lib/brdf.glsl"

uniform sampler2D gtexture;
uniform sampler2D wave11;
uniform sampler2D wave12;
uniform sampler2D wave21;
uniform sampler2D wave22;
uniform float frameTimeCounter;
uniform vec3 sunDirection;
uniform mat4 gbufferModelViewInverse;

in vec2 texcoord;
in vec3 color;
in vec3 viewPos;
in vec3 worldNormal;
in vec3 worldPos;

/* RENDERTARGETS: {RT_BACK} */
layout(location = 0) out vec4 fragColor;

vec3 perturbNormal(vec3 baseWorldNormal, vec2 uv)
{
    // ── 大尺度水波 (wave_1)：正弦混合缓慢振荡 ────────────────
    float blendLarge = sin(frameTimeCounter * 0.25) * 0.5 + 0.5;
    vec3 n1a = texture(wave11, uv * 2.0 * 0.01 - 0.01 * frameTimeCounter).rgb * 2.0 - 1.0;
    vec3 n1b = texture(wave12, uv * 2.0 * 0.01 + 0.02 * frameTimeCounter).rgb * 2.0 - 1.0;
    vec3 nLarge = normalize(mix(n1a, n1b, blendLarge));

    // ── 小尺度水波 (wave_2)：较快混合 ────────────────────────
    float blendSmall = sin(frameTimeCounter * 0.45 + 1.3) * 0.5 + 0.5;
    vec3 n2a = texture(wave21, uv * 8.0 * 0.01 + 0.05 * frameTimeCounter).rgb * 2.0 - 1.0;
    vec3 n2b = texture(wave22, uv * 8.0 * 0.01 - 0.04 * frameTimeCounter).rgb * 2.0 - 1.0;
    vec3 nSmall = normalize(mix(n2a, n2b, blendSmall));

    vec3 tn = normalize(nLarge * 0.55 + nSmall * 0.45);

    //return tn * 2.0 - 1.0;

    // TBN：从世界空间法线构建切线
    vec3 N = normalize(baseWorldNormal);
    vec3 up = abs(N.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 T = normalize(cross(up, N));
    vec3 B = cross(N, T);
    return normalize(T * tn.x + B * tn.y + N * tn.z);
}

void main()
{
    vec4 baseColor = texture(gtexture, texcoord);

    // ── 法线扰动（世界坐标 XZ 作为 UV，不随玩家滑动）────────
    vec3 N = normalize(mix(perturbNormal(worldNormal, worldPos.xz), vec3(0.0, 1.0, 0.0), 0.25));
    //N = vec3(0.0, 1.0, 0.0); // 禁用扰动，便于调试

    // ── 太阳镜面反射（仅太阳）─────────────────────────────────
    vec3 V = mat3(gbufferModelViewInverse) * normalize(-viewPos);
    vec3 L = normalize(sunDirection);
    vec3 H = normalize(V + L);
    float NoH = max(dot(N, H), 0.0);
    float spec = specularGGX(NoH, 0.1);

    float NdotV = abs(dot(N, V));
    NdotV = clamp(NdotV, 0.0, 1.0);
    float fresnel = 0.02 + 0.98 * pow(1.0 - NdotV, 5.0);
    
    vec3 sunSpec = vec3(spec * fresnel);

    vec3 shallow = vec3(0.15, 0.45, 0.75);
    vec3 deep    = vec3(0.03, 0.12, 0.35);
    vec3 water   = mix(shallow, deep, fresnel);

    baseColor.rgb = baseColor.rgb * color;
    baseColor.rgb = mix(baseColor.rgb, water, 0.75);
    baseColor.rgb += sunSpec;

    float alpha = mix(0.35, 0.75, fresnel);

    fragColor = vec4(pow(baseColor.rgb*0.01, vec3(2.2)), alpha);
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
out vec3 worldPos;

void main()
{
    gl_Position = ftransform();

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    color    = gl_Color.rgb;

    vec4 viewPos4 = gl_ModelViewMatrix * gl_Vertex;
    viewPos = viewPos4.xyz;
    vec3 cameraPos = gbufferModelViewInverse[3].xyz;
    worldPos = -cameraPos + mat3(gbufferModelViewInverse) * viewPos;

    worldNormal = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal);
}
#endif
