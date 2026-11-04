// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/prelude.glsl"

uniform sampler2D gtexture;

#ifdef GBUFFER_ENTITIES
uniform vec4 entityColor;
#endif

in vec2 texcoord;
in vec3 color;
in vec3 normal;
in vec4 lighting;
in float sunLighting;

/* RENDERTARGETS: {{RT_ALBEDO_SLOT}},{{RT_NORMAL_SLOT}},{{RT_LIGHTMAP_SLOT}} */

layout(location = 0) out vec4 outBaseColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outLighting0;

// 非常多临时代码，所以在多次重构，这里部分是规范的部分是临时的

// 顶线到像素的变量的这名字也是随便起的
// in vec2 texcoord;
// in vec3 color;
// in vec3 normal;
// in vec4 lighting;
// in float sunLighting;



void main()
{
    #if defined GBUFFER_WEATHER || defined GBUFFER_WATER || defined GBUFFER_HAND_WATER || defined GBUFFER_ENTITIES_TRANSLUCENT || defined GBUFFER_SKYBASIC || defined GBUFFER_SKYTEXTURED
    discard;
    #endif

    vec4 baseColor = texture(gtexture, texcoord);

    if (baseColor.a < ALPHA_TEST_THRESHOLD)
    {
        discard;
    }

    baseColor = baseColor * vec4(color, 1.0);

    #ifdef GBUFFER_ENTITIES
        baseColor.rgb = mix(baseColor.rgb, entityColor.rgb, entityColor.a);
    #endif

    // Vanilla textures are authored in sRGB; the lighting model works in linear.
    baseColor.rgb = pow(baseColor.rgb, vec3(2.2));

    outBaseColor = baseColor;
    outNormal.rgb = normal;
    outNormal.a = sunLighting;
    outLighting0 = lighting;
}
#endif

// {{SHADER_VERT}}
#ifdef {{SHADER_VERT}}
#include "/lib/prelude.glsl"

uniform mat4 gbufferModelViewInverse;

uniform sampler2D lightmap;

uniform vec3 sunDirection;

in vec2 vaUV2;

out vec2 texcoord;
out vec3 color;
out vec3 normal;
out vec4 lighting;
out float sunLighting;

void main()
{
    #if defined GBUFFER_WEATHER || defined GBUFFER_WATER || defined GBUFFER_HAND_WATER || defined GBUFFER_ENTITIES_TRANSLUCENT || defined GBUFFER_SKYBASIC || defined GBUFFER_SKYTEXTURED
    return;
    #endif

    gl_Position = ftransform();

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    color = gl_Color.rgb;
    normal = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal);

    lighting.rg = pow(gl_MultiTexCoord1.xy / 240.0, vec2(2.2));
    lighting.b = pow(gl_Color.a, 2.2);
    lighting.a = 1.0;

    sunLighting = saturate(dot(normalize(normal), sunDirection));
    normal = normal * 0.5 + 0.5;
}
#endif