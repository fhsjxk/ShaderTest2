// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"
#include "/lib/tonemap.glsl"

uniform sampler2D {{RT_BACK}};
//uniform sampler2D {{RT_SKY_TEST}};
uniform sampler2D {{RT_BLOOM}};
//uniform sampler2D {{IMG_SKYVIEW}};
//uniform sampler2D {{IMG_BLOOM_SAMPLER}};$
uniform sampler2D colortex15;
uniform sampler2D starcoltex;
uniform sampler2D stardirtex;

uniform sampler2D vignettetex;

#ifdef DEBUG_VIEW
uniform sampler2D {{RT_BASE_COLOR}};
uniform sampler2D {{RT_NORMAL}};
uniform sampler2D {{RT_LIGHTING0}};
#endif

in vec2 texcoord;

layout(location = 0) out vec4 color;

// LOCAL SETTINGS


vec3 aces(vec3 x)
//vec3 aces(vec3 x) { ... }$
{
    const float a = 2.6;
    const float b = 0.7;
    const float c = 2.62;
    const float d = 0.4;
    const float e = 1.2;
    return (x * (a * x + b)) / (x * (c * x + d) + e);
}

void main()
{
    ivec2 pixelCoordinate = ivec2(gl_FragCoord.xy);
    //ivec2 pixelCoord = ivec2(gl_FragCoord.xy);$
    //float value = texelFetch({{IMG_LIGHTING_LUT_SAMPLER}}, ivec2({{POS_LIGHTING_LUT_VALUE}}), 0).r;
    //color.rgb = pow(aces(texelFetch({{RT_BACK}}, pixelCoordinate, 0).rgb / mix(value, 1.0, 0.03) / 2.0), vec3(1.0/2.2));
    //color.rgb = pow(aces(texelFetch({{RT_BACK}}, pixelCoordinate, 0).rgb), vec3(1.0/2.2));
    color.rgb = pow(rdr2Tonemap(texelFetch({{RT_BACK}}, pixelCoordinate, 0).rgb), vec3(1.0/2.2));
    //color.rgb = pow(gt7ToneMap(texelFetch({{RT_BACK}}, pixelCoordinate, 0).rgb, 0, 0, false), vec3(1.0/2.2));
    //color.rgb = texture({{RT_BACK}}, texcoord).rgb;
    #if defined VIGNETTE_AMOUNT && VIGNETTE_AMOUNT != 0.0
    //float vignetteMask = texture(vignettetex, texcoord).r * VIGNETTE_AMOUNT + (1.0 - VIGNETTE_AMOUNT);
    //color.rgb *= vignetteMask * vignetteMask;
    #endif

    float vignetteMask = texture(vignettetex, texcoord).r * 0.1 + 0.9;
    color.rgb *= vignetteMask * vignetteMask;

    //color.rgb = texelFetch(stardirtex, pixelCoordinate, 0).rgb;
    //color.rgb = color.rgb + texelFetch({{RT_BLOOM}}, pixelCoordinate, 0).rgb;
    //color.rgb = color.rgb + texelFetch({{IMG_BLOOM_SAMPLER}}, pixelCoordinate, 0).rgb;$

    #ifdef DEBUG_VIEW
    vec2 viewCoordinate = fract(texcoord * 2.0);
    //vec2 viewCoord = fract(texcoord * 2.0);$

    if (texcoord.x < 0.5 && texcoord.y >= 0.5)
    {
        color.rgb = pow(aces(texture({{RT_BACK}}, viewCoordinate).rgb), vec3(1.0/2.2));
    }
    else if (texcoord.x >= 0.5 && texcoord.y >= 0.5)
    {
        color.rgb = texture({{RT_BASE_COLOR}}, viewCoordinate).rgb;
    }
    else if (texcoord.x < 0.5 && texcoord.y < 0.5)
    {
        color.rgb = texture({{RT_NORMAL}}, viewCoordinate).rgb;
    }
    else
    {
        color.rgb = texture({{RT_LIGHTING0}}, viewCoordinate).rgb;
    }

    color.a = 1.0;

    vec2 localCoordinate = fract(texcoord * 2.0);
    //vec2 localCoord = fract(texcoord * 2.0);$
    vec2 diff = (localCoordinate - 0.5);

    float distanceValue = length(diff);
    float dotSize = 0.001;
    float dotMask = 1.0 - smoothstep(dotSize, dotSize + 0.001, distanceValue);
    //float dot = 1.0 - smoothstep(dotSize, dotSize + 0.001, dist);$
    color.rgb = mix(color.rgb, vec4(1.0, 1.0, 1.0, 1.0).rgb, dotMask);
    #endif

    // Bloom atlas visualization — scaled to bottom half of screen.
    // Atlas: 2× viewWidth wide, viewHeight tall, mips laid out horizontally.
    //if (texcoord.y < 0.5)
    //{
    //    // Scale atlas down: atlas is 2× screen width, so map x∈[0,2] → [0,1]
    //    vec2 atlasUV = vec2(texcoord.x * 2.0, texcoord.y * 2.0);
    //    vec3 bloom = texture({{RT_BLOOM}}, atlasUV).rgb;
    //    //vec3 bloom = texture({{IMG_BLOOM_SAMPLER}}, atlasUV).rgb;$
    //    // Boost for visibility
    //    color.rgb = bloom * 5.0;
    //}
    vec3 bloom = texture({{RT_BLOOM}}, texcoord).rgb;
    //vec3 bloom = texture({{IMG_BLOOM_SAMPLER}}, texcoord).rgb;$
    //color.rgb = bloom * 5.0;
    //#endif
}
#endif

// {{SHADER_VERT}}
#ifdef {{SHADER_VERT}}
out vec2 texcoord;

void main()
{
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
#endif