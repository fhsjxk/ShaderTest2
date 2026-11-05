// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/prelude.glsl"
#include "/lib/universal/buffers.glsl"

uniform sampler2D {{RT_HDR}};
uniform sampler2D {{RT_BLOOM1}};

#ifdef DEBUG_VIEW
uniform sampler2D {{RT_ALBEDO}};
uniform sampler2D {{RT_NORMAL}};
uniform sampler2D {{RT_LIGHTMAP}};
#endif

in vec2 texcoord;
layout(location = 0) out vec4 color;

// Radial vignette: clear inside VIGNETTE_START, fully dark at VIGNETTE_END
// (distance is measured in screen UV units from the centre).
const float VIGNETTE_START = 0.3;
const float VIGNETTE_END   = 1.7;

// ACES filmic approximation (Narkowicz fit).
vec3 aces(vec3 x)
{
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

// GT7 (Gran Turismo 7): a rational shoulder that only starts compressing at 0.76,
// plus a highlight desaturation towards white. Below the shoulder the curve is
// linear, so mid-tones keep their contrast; the toe offset subtracts a small
// parabola under 0.08, which deepens the shadows.
vec3 gt7(vec3 c)
{
    const float startCompression = 0.8 - 0.04;   // 0.76
    const float desaturation     = 0.15;

    float x      = min(c.r, min(c.g, c.b));
    float offset = (x < 0.08) ? (x - 6.25 * x * x) : 0.04;
    c -= offset;

    float peak = max(c.r, max(c.g, c.b));
    if (peak < startCompression)
    {
        return c;
    }

    const float d = 1.0 - startCompression;
    float newPeak = 1.0 - d * d / (peak + d - startCompression);
    c *= newPeak / peak;

    float g = 1.0 - 1.0 / (desaturation * (peak - newPeak) + 1.0);
    return mix(c, vec3(newPeak), g);
}

// TONEMAP_OPERATOR selects between them (options.glsl).
vec3 toneMap(vec3 c)
{
    #if TONEMAP_OPERATOR == 1
    // The toe subtraction can push a dark pixel below zero, and the caller raises
    // the result to 1/gamma: a negative base would come out NaN and bloom would
    // smear it across the frame.
    return max(gt7(c * 1.5), 0.0);
    #else
    return aces(c);
    #endif
}

void main()
{
    ivec2 pixelCoordinate = ivec2(gl_FragCoord.xy);

    // Scene radiance in colour units, converted to display-referred space by the
    // auto-exposure. Bloom is already in that space and was accumulated from the
    // same exposure, so it is added rather than scaled again.
    vec3 hdr = texelFetch({{RT_HDR}}, pixelCoordinate, 0).rgb * exposureBlock.exposure;

    vec3 bloom = texture({{RT_BLOOM1}}, texcoord).rgb;

    #if BLOOM_MODE == 0
    hdr = mix(hdr, bloom, BLOOM_STRENGTH);
    #elif BLOOM_MODE == 1
    hdr += bloom * BLOOM_STRENGTH;
    #endif

    // hdr = mix(hdr, texture({{RT_BLOOM1}}, texcoord).rgb, BLOOM_STRENGTH);

    color.rgb = pow(toneMap(hdr), vec3(1.0 / GAMMA));

    float vignetteMask = 1.0 - smoothstep(VIGNETTE_START, VIGNETTE_END, distance(texcoord, vec2(0.5, 0.5))) * VIGNETTE_AMOUNT;
    color.rgb *= vignetteMask * vignetteMask;

    #ifdef DEBUG_VIEW
    vec2 viewCoordinate = fract(texcoord * 2.0);

    if (texcoord.x < 0.5 && texcoord.y >= 0.5)
    {
        color.rgb = pow(toneMap(texelFetch({{RT_HDR}}, ivec2(texcoord * vec2(textureSize({{RT_HDR}}, 0))), 0).rgb * exposureBlock.exposure), vec3(1.0 / GAMMA));
    }
    else if (texcoord.x >= 0.5 && texcoord.y >= 0.5)
    {
        color.rgb = texture({{RT_ALBEDO}}, viewCoordinate).rgb;
    }
    else if (texcoord.x < 0.5 && texcoord.y < 0.5)
    {
        color.rgb = texture({{RT_NORMAL}}, viewCoordinate).rgb;
    }
    else
    {
        color.rgb = texture({{RT_LIGHTMAP}}, viewCoordinate).rgb;
    }

    // Dot in each quadrant centre so the split is easy to read.
    const float DOT_SIZE = 0.001;
    vec2 localCoordinate = fract(texcoord * 2.0) - 0.5;
    float dotMask = 1.0 - smoothstep(DOT_SIZE, DOT_SIZE + 0.001, length(localCoordinate));
    color.rgb = mix(color.rgb, vec3(1.0), dotMask);
    #endif

    color.a = 1.0;
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
